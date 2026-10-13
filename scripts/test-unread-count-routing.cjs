// Node >= 24 host witness; no build, SDK, native TDLib, device or account actions.
// Actual TdObject -> ChatNormalizer -> combined reducer -> scoped AppStore -> root selector.
// Only hilog is replaced on that path; real invariants run in devMode. Separate router-only
// tests use reducer spies (not evidence of their domain behavior). The routing audit
// now rejects omissions; history reset also has a real store/jump-coordinator witness.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '../entry/src/main/ets');
const sources = new Map();
function read(p) {
  const source = fs.readFileSync(path.join(root, p), 'utf8');
  if (sources.has(p)) assert.equal(source, sources.get(p), `source changed during run: ${p}`);
  sources.set(p, source);
  return source;
}
function load(p, deps = {}) {
  const source = read(p);
  const names = [...source.matchAll(/^export\s+(?:async\s+)?(?:class|function|enum|const)\s+(\w+)/gm)].map(m => m[1]);
  const js = stripTypeScriptTypes(source.replace(/^import[\s\S]*?;\s*/gm, '')
    .replace(/^export\s+default\s+\w+;?\s*/gm, '').replace(/^export\s+/gm, ''),
  { mode: 'transform', sourceUrl: p });
  return new Function(...Object.keys(deps), js + `\nreturn {${names.join(',')}};`)(...Object.values(deps));
}
const errors = [];
const hilog = { info() {}, warn() {}, debug() {}, error(...args) { errors.push(args); } };
const A = load('core/model/AppState.ets'), C = load('core/model/AppCommand.ets');
const { TdObject } = load('models/td/common/index.ets');
const access = load('core/utils/tdAccessors.ets', { TdObject });
const group = load('core/model/dto/GroupAccessDto.ets', access);
const dto = load('core/model/dto/ChatDto.ets', { ...access, ...C, hilog });
const E = load('core/model/AppEvent.ets', { ...dto, ...group });
const clone = load('core/utils/stateClone.ets', { ...A, ...group });
const reply = load('core/utils/replyMessageKey.ets');
const reducers = {};
for (const name of ['authReducer', 'chatsReducer', 'messagesReducer', 'usersReducer', 'filesReducer', 'accentColorsReducer']) {
  reducers[name] = load(`core/reducers/${name}.ets`, { ...A, ...E, ...clone, ...access, ...reply,
    ChatDto: dto.ChatDto, DtoChatType: dto.ChatType, hilog })[name];
}
const { appReducer } = load('core/reducers/index.ets', reducers);
const invariants = load('core/invariants/assertInvariants.ets', { ...A, ...access, hilog });
const { AppStore } = load('core/store/AppStore.ets', { ...A, ...invariants, hilog });
const { registerChatHandlers } = load('core/events/normalizers/ChatNormalizer.ets', { ...E, ...dto, ...group, ...access, hilog });
const { selectTotalUnreadCount } = load('domain/selectors/chatSelectors.ets', A);
const handlers = new Map();
registerChatHandlers(handlers);
function normalize(update) {
  const handler = handlers.get(update['@type']);
  assert.ok(handler, `actual normalizer handler registered: ${update['@type']}`);
  const events = [];
  handler(events, TdObject.fromJSON(JSON.stringify(update)));
  return events;
}
function unread(list, count, unmuted) {
  return { '@type': 'updateUnreadMessageCount', chat_list: { '@type': list },
    unread_count: count, unread_unmuted_count: unmuted };
}
const main = (count, unmuted) => unread('chatListMain', count, unmuted);
const archive = (count, unmuted) => unread('chatListArchive', count, unmuted);
function counts(state) {
  const c = state.chats;
  return [c.mainUnreadMessageCount, c.mainUnreadUnmutedMessageCount,
    c.archiveUnreadMessageCount, c.archiveUnreadUnmutedMessageCount];
}
function fixture() {
  const rootStore = new AppStore(appReducer, undefined, true);
  const store = rootStore.createScope(), badges = [];
  rootStore.subscribe(state => badges.push(selectTotalUnreadCount(state)));
  return { rootStore, store, badges,
    state: () => store.getState(), badge: () => store.select(selectTotalUnreadCount),
    emit: (...updates) => store.dispatchBatch(updates.flatMap(normalize)) };
}
function newChat(id, list, count, muteFor) {
  return { '@type': 'updateNewChat', chat: { '@type': 'chat', id, title: `Fixture ${id}`,
    type: { '@type': 'chatTypePrivate', user_id: id }, unread_count: count,
    notification_settings: { '@type': 'chatNotificationSettings', mute_for: muteFor },
    positions: [{ '@type': 'chatPosition', list: { '@type': list }, order: String(1000 - id), is_pinned: false }] } };
}
async function loadedFixture() {
  const f = fixture();
  await f.emit(newChat(1, 'chatListMain', 5, 3600), newChat(2, 'chatListMain', 2, 0),
    newChat(3, 'chatListArchive', 9, 0));
  assert.deepEqual(f.state().chats.orderedChatIds, [1, 2]);
  assert.deepEqual(f.state().chats.archivedChatIds, [3]);
  assert.equal(f.state().chats.chats.get(1).muteForSeconds, 3600);
  assert.equal(f.state().chats.chats.get(2).muteForSeconds, 0);
  assert.equal(f.badge(), 7, 'prime the real selector fallback/memo before aggregate arrival');
  return f;
}
const tests = [];
const test = (name, run) => tests.push({ name, run });

test('actual normalizer emits typed main/archive total and unmuted counts', () => {
  for (const [update, list, count, unmuted] of [[main(37, 11), 'main', 37, 11], [archive(91, 29), 'archive', 91, 29]]) {
    const events = normalize(update);
    assert.equal(events.length, 1);
    assert.ok(events[0] instanceof E.ChatListUnreadMessageCountChangedEvent);
    assert.equal(events[0].type, 'chatListUnreadMessageCountChanged');
    assert.equal(events[0].chatListType, list);
    assert.equal(events[0].unreadCount, count);
    assert.equal(events[0].unreadUnmutedCount, unmuted);
  }
});
test('main aggregate reaches root selector with NO loaded chats and preserves other slices', async () => {
  const f = fixture(), before = f.state();
  assert.equal(f.badge(), 0);
  await f.emit(main(37, 11));
  const after = f.state();
  assert.equal(f.badge(), 37, 'aggregate must replace zero fallback, not use unmuted count 11');
  assert.deepEqual(counts(after), [37, 11, -1, -1]);
  assert.equal(after.chats.chats.size, 0);
  assert.equal(after.chats.orderedChatIds.length, 0);
  assert.notEqual(after, before);
  assert.notEqual(after.chats, before.chats);
  assert.deepEqual(counts(before), [-1, -1, -1, -1], 'old snapshot immutable');
  assert.equal(after.version, before.version + 1);
  assert.equal(after.lastEvent.type, 'chatListUnreadMessageCountChanged');
  for (const key of ['auth', 'connection', 'messages', 'users', 'files', 'accentColors']) assert.equal(after[key], before[key], key);
  assert.equal(f.rootStore.getState(), after);
  assert.deepEqual(f.badges, [37]);
});
test('archive aggregate works before main with NO loaded chats, without entering root badge', async () => {
  const f = fixture();
  await f.emit(archive(91, 29));
  assert.deepEqual(counts(f.state()), [-1, -1, 91, 29]);
  assert.equal(f.badge(), 0);
  assert.equal(f.state().chats.chats.size, 0);
  await f.emit(main(37, 11));
  assert.deepEqual(counts(f.state()), [37, 11, 91, 29]);
  assert.deepEqual(f.badges, [0, 37]);
});
test('scoped batch keeps main/archive and muted/unmuted separate with one notification', async () => {
  const f = fixture();
  await f.emit(main(37, 11), archive(91, 29));
  assert.deepEqual(counts(f.state()), [37, 11, 91, 29]);
  assert.deepEqual(f.badges, [37]);
  await f.emit(main(37, 0), archive(91, 0));
  assert.deepEqual(counts(f.state()), [37, 0, 91, 0]);
  assert.equal(f.badge(), 37, 'all muted still contributes to total root count');
  await f.emit(main(37, 37), archive(91, 91));
  assert.deepEqual(counts(f.state()), [37, 37, 91, 91]);
  assert.equal(f.badge(), 37, 'all unmuted does not add archive');
});
test('pre-aggregate fallback includes muted main rows but excludes archive rows', async () => {
  const f = await loadedFixture();
  assert.deepEqual(counts(f.state()), [-1, -1, -1, -1]);
  assert.equal(f.badge(), 7);
});
test('authoritative count overrides primed fallback and later per-chat read updates', async () => {
  const f = await loadedFixture();
  await f.emit(main(37, 11));
  assert.equal(f.badge(), 37);
  await f.emit({ '@type': 'updateChatReadInbox', chat_id: 1, unread_count: 200, last_read_inbox_message_id: '10' });
  assert.equal(f.state().chats.chats.get(1).unreadCount, 200);
  assert.equal(f.badge(), 37, 'do not recompute 202 from loaded rows after authoritative update');
});
test('main zero clears nonzero badge without falling back to still-unread loaded rows', async () => {
  const f = await loadedFixture();
  await f.emit(main(37, 11), archive(91, 29));
  assert.equal(f.badge(), 37);
  await f.emit(main(0, 0));
  assert.deepEqual(counts(f.state()), [0, 0, 91, 29]);
  assert.equal(f.badge(), 0);
  assert.equal(f.state().chats.chats.get(1).unreadCount, 5);
  assert.equal(f.badges.at(-1), 0);
});
test('archive zero resets only archive counters', async () => {
  const f = fixture();
  await f.emit(main(37, 11), archive(91, 29));
  assert.deepEqual(counts(f.state()), [37, 11, 91, 29]);
  await f.emit(archive(0, 0));
  assert.deepEqual(counts(f.state()), [37, 11, 0, 0]);
  assert.equal(f.badge(), 37);
});
test('folder/unknown/missing chat-list updates emit nothing and preserve state identity', async () => {
  const f = fixture();
  const updates = [unread('chatListFolder', 999, 888), unread('futureChatList', 999, 888), main(999, 888)];
  updates[0].chat_list.chat_folder_id = 42;
  delete updates[2].chat_list;
  for (const seeded of [false, true]) {
    if (seeded) await f.emit(main(37, 11), archive(91, 29));
    const before = f.state(), notifications = f.badges.length;
    for (const update of updates) {
      assert.deepEqual(normalize(update), []);
      await f.emit(update);
      assert.equal(f.state(), before);
    }
    assert.equal(f.badges.length, notifications);
    assert.equal(f.badge(), seeded ? 37 : 0);
  }
});
test('normalizer clamps negative counts to authoritative zero, not unknown sentinel', async () => {
  const f = fixture();
  await f.emit(main(-5, -2), archive(-8, -3));
  assert.deepEqual(counts(f.state()), [0, 0, 0, 0]);
  assert.equal(f.badge(), 0);
});
test('account reset clears aggregate/memo and rejects late events from the old scope', async () => {
  const f = await loadedFixture(), oldScope = f.store, deliveries = [];
  oldScope.subscribe(state => deliveries.push(selectTotalUnreadCount(state)));
  await f.emit(main(37, 11), archive(91, 29));
  assert.equal(f.badge(), 37);
  await f.rootStore.resetStateQueued();
  assert.deepEqual(counts(f.rootStore.getState()), [-1, -1, -1, -1]);
  assert.equal(f.rootStore.select(selectTotalUnreadCount), 0);
  assert.equal(oldScope.select(selectTotalUnreadCount), 0);
  assert.equal(f.rootStore.getState().chats.chats.size, 0);
  const fresh = f.rootStore.createScope();
  await fresh.dispatchBatch([newChat(4, 'chatListMain', 3, 0)].flatMap(normalize));
  assert.equal(fresh.select(selectTotalUnreadCount), 3, 'new account has its own fallback, not old memo');
  await fresh.dispatchBatch([main(8, 6), archive(4, 1)].flatMap(normalize));
  const after = f.rootStore.getState();
  await oldScope.dispatch(normalize(main(999, 888))[0]);
  await oldScope.dispatchBatch(normalize(archive(999, 888)));
  assert.equal(f.rootStore.getState(), after);
  assert.deepEqual(counts(after), [8, 6, 4, 1]);
  assert.equal(fresh.select(selectTotalUnreadCount), 8);
  assert.equal(oldScope.select(selectTotalUnreadCount), 0);
  assert.deepEqual(deliveries, [37]);
  assert.deepEqual(f.badges, [7, 37, 0, 3, 8]);
});
test('account reset barrier rejects already-queued stale batch before fresh aggregate', async () => {
  const f = fixture();
  await f.emit(main(37, 11));
  assert.equal(f.badge(), 37);
  const queued = f.emit(main(999, 888), archive(999, 888));
  const reset = f.rootStore.resetStateQueued();
  const fresh = f.rootStore.createScope();
  const next = fresh.dispatchBatch([main(8, 6), archive(4, 1)].flatMap(normalize));
  await Promise.all([queued, reset, next]);
  assert.deepEqual(counts(f.rootStore.getState()), [8, 6, 4, 1]);
  assert.equal(fresh.select(selectTotalUnreadCount), 8);
  assert.deepEqual(f.badges, [37, 0, 8], 'no stale 999 notification');
});
test('executed selector is the actual AppStoreBridge -> MainTabsPage badge source', () => {
  const bridge = read('app/bridge/AppStoreBridge.ets'), tabs = read('ui/pages/MainTabsPage.ets');
  assert.match(bridge, /import\s*\{\s*selectTotalUnreadCount\s*\}\s*from\s*'\.\.\/\.\.\/domain\/selectors\/chatSelectors'/);
  assert.match(bridge, /const totalUnread = selectTotalUnreadCount\(state\);/);
  assert.match(bridge, /chatsUIState\.totalUnreadCount = totalUnread;/);
  assert.match(tabs, /TgRootTabUnreadBadge\(\{ count: this\.chatsState\.totalUnreadCount \}\)/);
});

// Fixed independent expectations: deriving expected routes from index.ets would hide deletions.
const existingRoutes = {
  authReducer: ['authStateChanged', 'myUserResolved', 'connectionStateChanged'],
  chatsReducer: ['groupAccessUpdated', 'newChat', 'chatUpdated', 'chatReadInbox', 'chatReadOutbox',
    'chatsLoadStateChanged', 'chatAction', 'chatFullInfo', 'chatActiveStoriesUpdated'],
  messagesReducer: ['newMessage', 'replyMessageHydrated', 'messageUpdated', 'messageContentUpdated',
    'messageSendSucceeded', 'messageSendFailed', 'messagesDeleted'],
  usersReducer: ['userUpdated', 'userStatusChanged', 'userFullInfo'],
  filesReducer: ['fileDownloaded', 'fileTransferUpdated'],
  accentColorsReducer: ['accentColorsUpdated']
};
function routeProbe() {
  const calls = [], result = {}, spies = {};
  for (const name of Object.keys(reducers)) spies[name] = (state, action) => { calls.push({ name, state, action }); return result; };
  return { ...load('core/reducers/index.ets', spies), calls, result };
}
for (const [name, types] of Object.entries(existingRoutes)) for (const type of types) {
  test(`unchanged route ${type} -> ${name} exactly once`, () => {
    const probe = routeProbe(), state = {}, action = { type };
    assert.equal(probe.appReducer(state, action), probe.result);
    assert.deepEqual(probe.calls, [{ name, state, action }]);
  });
}
test('history reset reaches combined reducer and preserves other chats and the previous snapshot', () => {
  const state = A.createInitialAppState(), event = new E.ChatMessagesResetEvent();
  event.chatId = -100123;
  for (const id of [-100123, 7]) {
    const message = Object.assign(new A.Message(), { id: '91', chatId: id });
    state.messages.messages.set(id, new Map([['91', message]]));
  }
  const next = appReducer(state, event);
  assert.equal(next.messages.messages.has(-100123), false);
  assert.equal(next.messages.messages.get(7).get('91'), state.messages.messages.get(7).get('91'));
  assert.equal(state.messages.messages.has(-100123), true);
});
test('actual loadAroundMessage resets the old window before requesting the new one', async () => {
  const { LoadChatHistoryUseCase } = load('domain/usecases/loadChatHistory.ets', {
    ...E, ...C, ...access, ...load('core/model/AppError.ets'), TdObject, hilog,
    // This witness checks reset/transport ordering; normalization has its own suite.
    getEventNormalizer: () => ({ normalize: () => [] })
  });
  const state = A.createInitialAppState();
  const message = Object.assign(new A.Message(), { id: '91', chatId: -100123 });
  state.messages.messages.set(-100123, new Map([['91', message]]));
  const store = new AppStore(appReducer, state, false);
  let calls = 0;
  // Keep the whole coordinator, including execute, real. Observe at the external
  // transport boundary so moving reset into the owned reservation remains valid.
  const gateway = { send: async command => {
    calls++;
    assert.equal(store.getState().messages.messages.has(-100123), false);
    assert.equal(command.type, 'getChatHistory');
    assert.equal(command.payload.chatId, -100123);
    assert.equal(command.payload.fromMessageId, '950');
    assert.equal(command.payload.offset, -20);
    assert.equal(command.payload.limit, 40);
    return TdObject.fromJSON('{"@type":"messages","total_count":0,"messages":[]}');
  } };
  const useCase = new LoadChatHistoryUseCase(store.createScope(), gateway);
  assert.equal(await useCase.loadAroundMessage(-100123, '950', 40), true);
  assert.equal(calls, 1);
  assert.equal(state.messages.messages.has(-100123), true);
});
test('old scope history reset cannot clear a reused chat ID after account reset', async () => {
  const rootStore = new AppStore(appReducer, undefined, false), old = rootStore.createScope();
  await rootStore.resetStateQueued();
  const state = rootStore.getState(), event = new E.ChatMessagesResetEvent();
  event.chatId = 7;
  const current = Object.assign(new A.Message(), { id: '99', chatId: 7 });
  state.messages.messages.set(7, new Map([['99', current]]));
  await old.dispatch(event);
  assert.equal(rootStore.getState().messages.messages.get(7).get('99'), current);
});
test('unknown route is identity with no reducer calls', () => {
  const probe = routeProbe(), state = {};
  assert.equal(probe.appReducer(state, { type: 'unreadRoutingUnknownFixture' }), state);
  assert.deepEqual(probe.calls, []);
});
function auditRouting() {
  const omissions = [], misroutes = [];
  let handled = 0;
  for (const name of Object.keys(reducers)) {
    const source = read(`core/reducers/${name}.ets`);
    const types = new Set([...source.matchAll(/\b(?:action\.)?type\s*(?:===|!==)\s*'([^']+)'|case '([^']+)':/g)]
      .map(m => m[1] || m[2]));
    for (const type of types) {
      handled++;
      const probe = routeProbe();
      probe.appReducer({}, { type });
      if (probe.calls.length === 0) omissions.push({ type, reducer: name });
      else if (probe.calls.length !== 1 || probe.calls[0].name !== name) misroutes.push({ type, reducer: name });
    }
  }
  console.log('ROUTING_AUDIT', JSON.stringify({ handled, omissions, misroutes }));
  return { handled, omissions, misroutes };
}
test('all declared sub-reducer event cases route to exactly one matching reducer', () => {
  const audit = auditRouting();
  assert.ok(audit.handled > 0, 'routing audit must inspect actual sub-reducer source');
  assert.deepEqual(audit.omissions, []);
  assert.deepEqual(audit.misroutes, []);
});
async function run() {
  let failed = 0;
  for (const { name, run } of tests) {
    const priorErrors = errors.length;
    try {
      await run();
      assert.deepEqual(errors.slice(priorErrors), [], 'no swallowed reducer/store/listener errors');
      console.log(`PASS ${name}`);
    } catch (error) {
      failed++;
      console.error(`FAIL ${name}: ${error.stack}`);
      if (errors.length > priorErrors) console.error('STORE_ERRORS', JSON.stringify(errors.slice(priorErrors)));
    }
  }
  if (process.argv.includes('--audit-routing')) auditRouting();
  for (const p of sources.keys()) read(p);
  console.log('SOURCES', JSON.stringify(Object.fromEntries([...sources].map(([p, s]) => [p, createHash('sha256').update(s).digest('hex')]))));
  console.log(`UNREAD_ROUTING ${tests.length - failed}/${tests.length} PASS; ${failed} FAIL; ${errors.length} swallowed errors`);
  process.exitCode = failed ? 1 : 0;
}
let completed = false;
run().then(() => { completed = true; }, error => {
  completed = true; console.error('HARNESS_ERROR', error); process.exitCode = 2;
});
process.on('beforeExit', () => {
  if (!completed) { console.error('FAIL incomplete unread routing run'); process.exitCode = 2; }
});

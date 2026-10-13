// Node >=24: actual TD objects, normalizer, chat reducer/router, scoped store,
// hydration/controller and page capability methods. Transport/UI only are fixtures.
const { readChatSource } = require("./chat-screen-source.cjs");
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '../entry/src/main/ets');
// Slow-mode imports execute real production code; only the SDK uptime service is a fixture.
const slowmodeFixtureDeps = (() => {
  const etsRoot = path.resolve(__dirname, '../entry/src/main/ets');
  function module(file, deps = {}) {
    const source = fs.readFileSync(path.join(etsRoot, file), 'utf8');
    const names = [...source.matchAll(/^export\s+(?:class|function)\s+(\w+)/gm)].map(match => match[1]);
    const js = stripTypeScriptTypes(source.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, ''), { mode: 'transform' });
    return new Function(...Object.keys(deps), js + `; return {${names.join(',')}};`)(...Object.values(deps));
  }
  const clock = module('core/utils/SlowmodeClock.ets', { systemDateTime: { TimeType: { STARTUP: 0 }, getUptime: () => 0 } });
  return { ...clock, ...module('ui/pages/chat/ChatSlowmodeController.ets', {
    ...clock, navigationUIState: { applicationForeground: true }
  }) };
})();
Object.assign(globalThis, slowmodeFixtureDeps);

const sources = {};
const mutant = process.argv.find(x => x.startsWith('--mutant='))?.slice(9);
const mutations = {
  individual: ['ui/pages/chat/ChatInputPanelPolicy.ets', "const individualAllowed = access.role !== 'restricted' || permitsKind(access.permissions, kinds[i]);", 'const individualAllowed = true;'],
  booster: ['ui/pages/chat/ChatInputPanelPolicy.ets', 'boosts.myBoostCount >= boosts.unrestrictBoostCount', 'false'],
  page: ['ui/pages/chat/TgChatScreenPage.ets', 'isEditing, sendKind, state.chats.supergroupBoosts.get(chat.supergroupId)', 'isEditing, sendKind'],
  live: ['domain/usecases/loadChatAccess.ets', 'this.store.getState().chats.supergroupBoosts.get(groupId) === captured', 'true'],
  clone: ['core/utils/stateClone.ets', 'newChats.supergroupBoosts = new Map<number, SupergroupBoostsDto>(chats.supergroupBoosts);', ''],
  subscription: ['ui/pages/chat/TgChatScreenPage.ets', "    if (chat?.type === 'supergroup' && newState.chats.supergroupBoosts.get(chat.supergroupId) !==\n      prevState.chats.supergroupBoosts.get(chat.supergroupId)) return true;", ''],
  'retry-ui': ['ui/pages/chat/TgChatScreenPage.ets', 'if (this.composerAccessRetryVisible) this.chatAccessController?.retry();', 'return;']
};
assert.ok(!mutant || mutations[mutant]);
let mutationCount = 0;
function read(file) {
  let s = readChatSource(path.join(root, file), 'utf8').replaceAll('\r\n', '\n');
  sources[file] = createHash('sha256').update(s).digest('hex');
  const m = mutations[mutant];
  if (m && m[0] === file) { assert.ok(s.includes(m[1]), 'mutation must engage'); s = s.replace(m[1], m[2]); mutationCount++; }
  return s;
}
function load(file, deps = {}) {
  const s = read(file);
  const names = [...s.matchAll(/^export\s+(?:default\s+)?(?:class|function|const|enum)\s+(\w+)/gm)].map(m => m[1]);
  const js = stripTypeScriptTypes(s.replace(/^import[\s\S]*?;\s*/gm, '')
    .replace(/^export\s+(?:default\s+)?/gm, ''), { mode: 'transform', sourceUrl: file });
  return new Function(...Object.keys(deps), `${js}\nreturn {${names.join(',')}};`)(...Object.values(deps));
}
const hilog = { info() {}, warn() {}, error() {}, debug() {} };
const A = load('core/model/AppState.ets'), C = load('core/model/AppCommand.ets');
const td = load('models/td/common/index.ets');
const accessors = load('core/utils/tdAccessors.ets', td);
const G = load('core/model/dto/GroupAccessDto.ets', accessors);
const D = load('core/model/dto/ChatDto.ets', { ...accessors, ...C, ...G, hilog });
const E = load('core/model/AppEvent.ets', { ...D, ...G });
const clones = load('core/utils/stateClone.ets', { ...A, ...G });
const { chatsReducer } = load('core/reducers/chatsReducer.ets', { ...A, ...E, ...G, ...clones, ...accessors, DtoChatType: D.ChatType });
const noop = state => state;
const { appReducer } = load('core/reducers/index.ets', { chatsReducer, authReducer: noop, messagesReducer: noop, usersReducer: noop, filesReducer: noop, accentColorsReducer: noop });
const { AppStore } = load('core/store/AppStore.ets', { ...A, hilog });
const P = load('ui/pages/chat/ChatInputPanelPolicy.ets', G);
const { LoadChatAccessUseCase } = load('domain/usecases/loadChatAccess.ets', { ...C, ...E, ...G, ...D, ...td });
const { ChatAccessController } = load('ui/pages/chat/ChatAccessController.ets', P);
const { registerChatHandlers } = load('core/events/normalizers/ChatNormalizer.ets', { ...E, ...D, ...G, ...accessors, hilog });
const { serializeCommand } = load('infra/td/serialization/CommandSerializer.ets', { ...C, ...td, hilog });
const handlers = new Map(); registerChatHandlers(handlers);
const raw = value => td.TdObject.fromJSON(JSON.stringify(value));
function normalize(value) { const events = []; assert.ok(handlers.has(value['@type']), 'handler exists'); handlers.get(value['@type'])(events, raw(value)); return events; }
const page = read('ui/pages/chat/TgChatScreenPage.ets');
const methods = ['canUseComposer', 'canSendNewMessages', 'getSendUseCase', 'getSendMediaUseCase', 'shouldReactToStoreChange', 'deriveChatBottomBar'];
if (page.includes('  private retryChatAccess(')) methods.push('retryChatAccess');
const bodies = methods.map(name => {
  const m = new RegExp(`^  (?:(?:private|public|protected)\\s+)?${name}\\(`, 'm').exec(page);
  assert.ok(m, name); const end = page.indexOf('\n  }', m.index); assert.ok(end > m.index);
  return page.slice(m.index, end + 4);
});
const Page = new Function('selectChatInputPanel', 'needsSupergroupBoosts', stripTypeScriptTypes(`class Page {
  slowmodeController = new globalThis.ChatSlowmodeController();
  composerSlowmodeSeconds = 0;\n${bodies.join('\n')}\n}`, { mode: 'transform' }) + '\nreturn Page;')(P.selectChatInputPanel, P.needsSupergroupBoosts);
const tick = () => new Promise(resolve => setImmediate(resolve));
const perms = (...allowed) => Object.assign(new G.GroupSendPermissionsDto(), Object.fromEntries(allowed.map(key => [key, true])));
const boost = (my = 3, threshold = 3, groupId = 77) => ({ groupId, myBoostCount: my, unrestrictBoostCount: threshold });
const full = (my = 3, threshold = 3) => ({ '@type': 'supergroupFullInfo', my_boost_count: my, unrestrict_boost_count: threshold });
const update = (my = 3, threshold = 3, id = 77) => ({ '@type': 'updateSupergroupFullInfo', supergroup_id: id, supergroup_full_info: full(my, threshold) });
function fixture() {
  const state = A.createInitialAppState();
  const chat = Object.assign(new A.Chat(), { id: -77, type: 'supergroup', supergroupId: 77, canSendBasicMessages: false, sendPermissions: perms() });
  const access = Object.assign(new G.GroupAccessDto(), { groupId: 77, kind: 'supergroup', role: 'member', isMember: true });
  state.chats.chats.set(chat.id, chat); state.chats.supergroupAccess.set(77, access);
  const store = new AppStore(appReducer, state, false), requests = [];
  const gateway = { send(command) { return new Promise((resolve, reject) => requests.push({ command, resolve, reject })); } };
  const p = Object.assign(new Page(), { accountStore: store.createScope(), activeChatId: chat.id, editingMessageId: '0', isEditingMessage: false, sendUseCase: {}, sendMediaUseCase: {}, chatAccessUnavailable: false });
  const uc = new LoadChatAccessUseCase(store, gateway);
  return { chat, access, store, requests, p, uc, emit: value => store.dispatchBatch(normalize(value)) };
}
function panel(f, kind = '', boosts) { return P.selectChatInputPanel(f.chat, f.access, false, kind, boosts); }
const tests = []; function test(name, run) { tests.push({ name, run }); }
test('DTO strict fullinfo values and clone', () => {
  assert.equal(typeof G.createSupergroupBoostsDtoFromTd, 'function');
  const b = G.createSupergroupBoostsDtoFromTd(raw(full()), 77); assert.deepEqual([b.groupId, b.myBoostCount, b.unrestrictBoostCount], [77, 3, 3]);
  const copy = b.clone(); b.myBoostCount = 0; assert.equal(copy.myBoostCount, 3);
  for (const invalid of [full('3', 3), full(-1, 3), full(1.1, 3), full(3, 2147483648), { '@type': 'supergroupFullInfo', nested: full() }, { ...full(), '@type': 'chat' }]) assert.equal(G.createSupergroupBoostsDtoFromTd(raw(invalid), 77), undefined);
  for (const id of [0, -77, '77', NaN, 9007199254740992]) assert.equal(G.createSupergroupBoostsDtoFromTd(raw(full()), id), undefined);
});
test('ordinary default media preserves composer without permitting text', () => {
  const f = fixture(); f.chat.sendPermissions = perms('canSendPhotos');
  assert.equal(panel(f), 'composer'); assert.equal(panel(f, 'photo'), 'composer'); assert.equal(panel(f, 'text', boost(0, 0)), 'restricted');
});
test('known booster overrides defaults but not individual restrictions', () => {
  const f = fixture(); f.access.role = 'restricted'; f.access.permissions = perms('canSendBasicMessages');
  assert.equal(panel(f, 'text', boost()), 'composer'); assert.equal(panel(f, 'photo', boost()), 'restricted');
  assert.equal(panel(f, 'text', boost(2, 3)), 'restricted'); assert.equal(panel(f, 'text', boost(99, 0)), 'restricted');
});
test('unknown boosts are not absent internal TDLib cache or known zero', () => {
  const f = fixture(); assert.equal(panel(f, 'text'), 'unknown'); assert.equal(panel(f, 'text', boost(0, 0)), 'restricted');
  assert.equal(panel(f, 'text', boost(3, 3, 78)), 'unknown');
  f.chat.sendPermissions = undefined; assert.equal(panel(f, 'text'), 'unknown'); assert.equal(panel(f, 'text', boost()), 'composer');
});
test('membership and role precede booster privilege', () => {
  const f = fixture(); f.access.role = 'banned'; assert.equal(panel(f, 'text', boost()), 'banned');
  f.access.role = 'left'; f.access.isMember = false; assert.equal(panel(f, 'text', boost()), 'join');
  f.access.role = 'administrator'; f.access.isMember = true; assert.equal(panel(f, 'text'), 'composer');
  f.access.groupId = 78; assert.equal(panel(f, 'text', boost()), 'unknown');
});
test('boost updates precede newChat, route through combined reducer and detach producer', async () => {
  const store = new AppStore(appReducer, undefined, false); const events = normalize(update());
  assert.equal(events.length, 1); assert.equal(events[0].type, 'supergroupBoostsUpdated'); await store.dispatchBatch(events);
  const saved = store.getState().chats.supergroupBoosts.get(77); assert.equal(saved.myBoostCount, 3);
  events[0].boosts.myBoostCount = 0; assert.equal(saved.myBoostCount, 3);
  const prev = store.getState(); await store.dispatch(E.createChatUpdatedEvent(-77, new D.ChatUpdateDto()));
  assert.equal(store.getState().chats.supergroupBoosts.get(77), saved); assert.notEqual(store.getState().chats.supergroupBoosts, prev.chats.supergroupBoosts);
});
test('outer ID and nested permissions do not synthesize a valid boost update', () => {
  for (const bad of [{ ...update(), supergroup_id: '77' }, { '@type': 'updateSupergroupFullInfo', nested: update() }, { ...update(), supergroup_full_info: { '@type': 'supergroupFullInfo', nested: full() } }]) assert.equal(normalize(bad).length, 0);
});
test('fresh boosts change real page text capability and reactive snapshot', async () => {
  const f = fixture(); assert.equal(f.p.getSendUseCase(), undefined); const previous = f.store.getState();
  await f.emit(update()); assert.equal(f.p.shouldReactToStoreChange(f.store.getState(), previous), true);
  assert.equal(f.p.getSendUseCase(), f.p.sendUseCase); f.p.deriveChatBottomBar(f.chat, f.store.getState()); assert.ok(f.p.composerAllowedKinds.includes('text'));
  await f.emit(update(0, 3)); assert.equal(f.p.getSendUseCase(), undefined); f.p.deriveChatBottomBar(f.chat, f.store.getState()); assert.deepEqual(f.p.composerAllowedKinds, []);
});
test('media-only real page never exposes text; individual live revocation wins', async () => {
  const f = fixture(); f.chat.sendPermissions = perms('canSendPhotos'); assert.equal(f.p.getSendUseCase(), undefined); assert.equal(f.p.getSendMediaUseCase('photo'), f.p.sendMediaUseCase);
  await f.emit(update()); const prev = f.store.getState(); const access = Object.assign(new G.GroupAccessDto(), f.access, { role: 'restricted', permissions: perms('canSendBasicMessages') });
  await f.store.dispatch(E.createGroupAccessUpdatedEvent(access)); assert.ok(f.p.shouldReactToStoreChange(f.store.getState(), prev));
  assert.equal(f.p.getSendMediaUseCase('photo'), undefined); assert.equal(f.p.getSendUseCase(), f.p.sendUseCase);
});
test('unrelated boost update does not wake active page', async () => {
  const f = fixture(); const prev = f.store.getState(); await f.emit(update(3, 3, 78)); assert.equal(f.p.shouldReactToStoreChange(f.store.getState(), prev), false);
});
test('FullInfo request is exact serialized supergroup ID and singleflight', async () => {
  const f = fixture(); const pending = f.uc.loadBoosts(77); assert.equal(f.uc.loadBoosts(77), pending); await tick(); assert.equal(f.requests.length, 1);
  const wire = serializeCommand(f.requests[0].command); assert.equal(wire.method, 'getSupergroupFullInfo'); assert.deepEqual(JSON.parse(wire.params.toJSON()), { supergroup_id: 77 });
  f.requests[0].resolve(raw(full())); await pending; assert.equal(f.store.getState().chats.supergroupBoosts.get(77).myBoostCount, 3);
  await f.uc.loadBoosts(77); assert.equal(f.requests.length, 1);
});
test('queued live FullInfo beats late request response at reducer dequeue', async () => {
  const f = fixture(); const pending = f.uc.loadBoosts(77); await tick(); const live = f.emit(update(0, 3)); f.requests[0].resolve(raw(full())); await Promise.all([live, pending]);
  assert.equal(f.store.getState().chats.supergroupBoosts.get(77).myBoostCount, 0);
});
test('unrelated group update does not discard this group hydration', async () => {
  const f = fixture(); const pending = f.uc.loadBoosts(77); await tick(); await f.emit(update(0, 3, 78)); f.requests[0].resolve(raw(full())); await pending;
  assert.equal(f.store.getState().chats.supergroupBoosts.get(77).myBoostCount, 3); assert.equal(f.store.getState().chats.supergroupBoosts.get(78).myBoostCount, 0);
});
test('account reset fences pending FullInfo and clears snapshot', async () => {
  const f = fixture(); const pending = f.uc.loadBoosts(77); await tick(); f.store.resetState(); f.requests[0].resolve(raw(full())); await pending;
  assert.equal(f.store.getState().chats.supergroupBoosts.size, 0); assert.equal(f.p.getSendUseCase(), undefined);
});
test('malformed FullInfo rejects and singleflight can retry', async () => {
  const f = fixture(); const pending = f.uc.loadBoosts(77); await tick(); f.requests[0].resolve(raw(full('3', 3))); await assert.rejects(pending);
  const retry = f.uc.loadBoosts(77); await tick(); assert.equal(f.requests.length, 2); f.requests[1].resolve(raw(full())); await retry;
  assert.equal(f.p.getSendUseCase(), f.p.sendUseCase);
});
test('controller hydrates boosts once and requires explicit retry after failure', async () => {
  const f = fixture(); let ctl; const observe = () => ctl.observe(f.chat, f.access, f.store.getState().chats.supergroupBoosts?.get(77));
  ctl = new ChatAccessController(f.uc, observe); observe(); await tick(); assert.equal(f.requests.length, 1); assert.equal(f.requests[0].command.type, 'getSupergroupFullInfo');
  f.requests[0].reject(new Error('offline')); await tick(); await tick(); assert.equal(ctl.isUnavailable(), true); observe(); await tick(); assert.equal(f.requests.length, 1);
  ctl.retry(); await tick(); f.requests[1].resolve(raw(full())); await tick(); await tick(); assert.equal(ctl.isUnavailable(), false); assert.equal(f.p.getSendUseCase(), f.p.sendUseCase); ctl.dispose();
});
test('controller skips boosts when defaults allow all or role bypasses them', async () => {
  const f = fixture(); f.access.role = 'administrator'; const ctl = new ChatAccessController(f.uc, () => {}); ctl.observe(f.chat, f.access); await tick(); assert.equal(f.requests.length, 0); ctl.dispose();
  const g = fixture(); g.chat.sendPermissions = perms(...Object.keys(new G.GroupSendPermissionsDto()));
  const other = new ChatAccessController(g.uc, () => {}); other.observe(g.chat, g.access); await tick(); assert.equal(g.requests.length, 0); other.dispose();
});
test('all nine kinds independently obey default rights', () => {
  const f = fixture(); const kinds = ['text', 'audio', 'document', 'photo', 'video', 'videoNote', 'voice', 'poll', 'other'];
  const bits = ['canSendBasicMessages', 'canSendAudios', 'canSendDocuments', 'canSendPhotos', 'canSendVideos', 'canSendVideoNotes', 'canSendVoiceNotes', 'canSendPolls', 'canSendOtherMessages'];
  for (let i = 0; i < bits.length; i++) { f.chat.sendPermissions = perms(bits[i]); assert.equal(panel(f), 'composer'); for (let j = 0; j < kinds.length; j++) assert.equal(panel(f, kinds[j], boost(0, 0)), i === j ? 'composer' : 'restricted'); }
});
test('invalid snapshot cannot become a booster by coercion', () => {
  const f = fixture(); for (const bad of [boost('3', 3), boost(3, '3'), boost(-1, 3), boost(2147483648, 3), boost(3, NaN)]) assert.equal(panel(f, 'text', bad), 'unknown');
});
test('reducer rejects malformed producer and retains last valid snapshot', async () => {
  const f = fixture(); await f.emit(update()); const before = f.store.getState();
  const invalid = Object.assign(new G.SupergroupBoostsDto(), boost(-1, 3)); await f.store.dispatch(E.createSupergroupBoostsUpdatedEvent(invalid)); assert.equal(f.store.getState(), before);
});
test('controller progresses membership then defaults then boosts without a loop', async () => {
  const f = fixture(); f.store.getState().chats.supergroupAccess.clear(); f.chat.sendPermissions = undefined; let ctl;
  const observe = () => { const s = f.store.getState(); ctl.observe(s.chats.chats.get(-77), s.chats.supergroupAccess.get(77), s.chats.supergroupBoosts.get(77)); };
  ctl = new ChatAccessController(f.uc, observe); observe(); await tick(); assert.equal(f.requests[0].command.type, 'getSupergroup');
  f.requests[0].resolve(raw({ '@type': 'supergroup', id: 77, status: { '@type': 'chatMemberStatusMember' } })); await tick(); await tick();
  assert.equal(f.requests[1].command.type, 'getChat'); assert.equal(f.requests[1].command.payload.chatId, -77);
  f.requests[1].resolve(raw({ '@type': 'chat', id: -77, permissions: { '@type': 'chatPermissions', can_send_basic_messages: false } })); await tick(); await tick();
  assert.equal(f.requests[2].command.type, 'getSupergroupFullInfo'); f.requests[2].resolve(raw(full())); await tick(); await tick(); observe(); await tick();
  assert.equal(f.requests.length, 3); assert.equal(f.p.getSendUseCase(), f.p.sendUseCase); assert.equal(ctl.isUnavailable(), false); ctl.dispose();
});
test('controller preserves captured group and ignores old completion after switching', async () => {
  const f = fixture(); let changes = 0; const ctl = new ChatAccessController(f.uc, () => changes++);
  ctl.observe(f.chat, f.access); await tick(); const otherChat = Object.assign(new A.Chat(), f.chat, { id: -78, supergroupId: 78 }); const otherAccess = Object.assign(new G.GroupAccessDto(), f.access, { groupId: 78 });
  ctl.observe(otherChat, otherAccess); await tick(); assert.deepEqual(f.requests.map(r => r.command.payload.supergroupId), [77, 78]);
  f.requests[0].resolve(raw(full())); await tick(); await tick(); assert.equal(changes, 0); assert.equal(f.store.getState().chats.supergroupBoosts.get(77).myBoostCount, 3);
  f.requests[1].resolve(raw(full(0, 3))); await tick(); await tick(); assert.equal(changes, 1); assert.equal(f.store.getState().chats.supergroupBoosts.get(78).myBoostCount, 0); ctl.dispose();
});
test('partial permission failure exposes wired UI retry without disabling working composer', async () => {
  const f = fixture(); f.chat.sendPermissions = perms('canSendBasicMessages'); f.p.composerDraftText = 'keep draft'; let ctl;
  const observe = () => { const s = f.store.getState(); ctl.observe(f.chat, f.access, s.chats.supergroupBoosts.get(77)); f.p.chatAccessUnavailable = ctl.isUnavailable(); f.p.deriveChatBottomBar(f.chat, s); };
  ctl = new ChatAccessController(f.uc, observe); f.p.chatAccessController = ctl; observe(); await tick();
  f.requests[0].reject(new Error('offline')); await tick(); await tick();
  assert.equal(f.p.chatBottomBarAction, 'none'); assert.equal(f.p.getSendUseCase(), f.p.sendUseCase); assert.equal(f.p.getSendMediaUseCase('photo'), undefined);
  assert.equal(f.p.composerAccessRetryVisible, true, 'working composer needs its own discoverable retry');
  const atom = read('ui/tg_ui/atoms/TgComposerInput.ets');
  assert.match(atom, /if \(this.accessRetryVisible\)\s*\{\s*Button\(this.accessRetryLabel\)/);
  assert.match(atom, /\.onClick\(\(\): void => \{\s*this.handleAccessRetryPress\(\);/);
  assert.match(page, /accessRetryVisible: this.composerAccessRetryVisible/);
  const callback = /onAccessRetryPress: \(\): void => \{([^}]+)\}/.exec(page); assert.ok(callback, 'actual parent binding');
  const start = atom.indexOf('  private handleAccessRetryPress('), end = atom.indexOf('\n  }', start); assert.ok(start >= 0 && end > start);
  const Widget = new Function(stripTypeScriptTypes(`class Widget {${atom.slice(start, end + 4)}}`, { mode: 'transform' }) + '\nreturn Widget;')();
  const widget = Object.assign(new Widget(), { accessRetryVisible: true, isDisabled: false, onAccessRetryPress: new Function(callback[1]).bind(f.p) });
  widget.isDisabled = true; widget.handleAccessRetryPress(); await tick(); assert.equal(f.requests.length, 1); widget.isDisabled = false;
  widget.handleAccessRetryPress(); widget.handleAccessRetryPress(); await tick(); assert.equal(f.requests.length, 2, 'no duplicate retry');
  f.requests[1].resolve(raw(full())); await tick(); await tick();
  assert.equal(f.p.getSendMediaUseCase('photo'), f.p.sendMediaUseCase); assert.equal(f.p.composerAccessRetryVisible, false); assert.equal(f.p.composerDraftText, 'keep draft'); assert.equal(f.p.getSendUseCase(), f.p.sendUseCase); ctl.dispose();
});
// Execute the actual native suite bodies through a host adapter, not a device runner.
const nativeStart = tests.length;
load('../../ohosTest/ets/test/SupergroupBoosts.test.ets', {
  ...A, ...G, ...td, ...P,
  describe: (_name, body) => body(), it: (name, _flags, body) => test(`native: ${name}`, body),
  expect: value => ({ assertEqual: expected => assert.equal(value, expected), assertTrue: () => assert.equal(value, true),
    assertFalse: () => assert.equal(value, false), assertUndefined: () => assert.equal(value, undefined) })
}).supergroupBoostsTest();
assert.equal(tests.length - nativeStart, 9, 'all native suite bodies registered');
let done = false;
(async () => {
  let passed = 0, failed = 0;
  for (const t of tests) { try { await t.run(); passed++; } catch (e) { failed++; console.error('FAIL', t.name, e.message); } }
  if (mutant) assert.ok(mutationCount > 0, 'mutation engaged');
  done = true; console.log(JSON.stringify({ passed, failed, nativeBodiesThroughHost: tests.length - nativeStart, mutant, mutationCount, sources })); process.exitCode = failed ? 1 : 0;
})().catch(e => { done = true; console.error(e); process.exitCode = 2; });
process.on('beforeExit', () => { if (!done) process.exitCode = 2; });

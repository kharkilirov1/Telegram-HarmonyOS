// Actual TD parser, DTOs, all normalizer registrations, combined reducer,
// scoped store, page subscription/input policy and capability getters.
// Node >=24; native TDLib/ArkUI rendering/network are not executed.
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
function read(p) {
  const source = readChatSource(path.join(root, p), 'utf8');
  sources[p] = createHash('sha256').update(source).digest('hex');
  return source;
}
function load(p, deps = {}) {
  const source = read(p);
  const names = [...source.matchAll(/^export\s+(?:default\s+)?(?:class|function|enum|const)\s+(\w+)/gm)].map(m => m[1]);
  const js = stripTypeScriptTypes(source.replace(/^import[\s\S]*?;\s*/gm, '')
    .replace(/^export\s+default\s+\w+;\s*/gm, '').replace(/^export\s+(?:default\s+)?/gm, ''), { mode: 'transform' });
  return new Function(...Object.keys(deps), js + `;return {${names.join(',')}};`)(...Object.values(deps));
}
const loggedErrors = [];
const hilog = { info() {}, warn() {}, debug() {}, error(...args) { loggedErrors.push(args); } };
const td = load('models/td/common/index.ets');
const accessors = load('core/utils/tdAccessors.ets', td);
const C = load('core/model/AppCommand.ets'), A = load('core/model/AppState.ets');
const G = load('core/model/dto/GroupAccessDto.ets', { ...td, ...accessors });
const D = load('core/model/dto/ChatDto.ets', { ...td, ...accessors, ...C, ...G, hilog });
const E = load('core/model/AppEvent.ets', { ...D, ...G });
const clone = load('core/utils/stateClone.ets', { ...A, ...C, ...G });
const { chatsReducer } = load('core/reducers/chatsReducer.ets', {
  ...A, ...E, ...clone, ...accessors, DtoChatType: D.ChatType
});
const unused = () => { throw Error('Unexpected non-chat reducer in permission fixture'); };
const { appReducer } = load('core/reducers/index.ets', { chatsReducer, authReducer: unused,
  messagesReducer: unused, usersReducer: unused, filesReducer: unused, accentColorsReducer: unused });
const registrations = {};
for (const f of fs.readdirSync(path.join(root, 'core/events/normalizers')).filter(f => f.endsWith('.ets'))) {
  const exports = load('core/events/normalizers/' + f, { ...td, ...accessors, ...D, ...G, ...E, hilog });
  for (const [name, fn] of Object.entries(exports)) if (/^register\w+Handlers$/.test(name)) registrations[name] = fn;
}
const { EventNormalizerImpl } = load('core/events/EventNormalizer.ets', { ...registrations, ...accessors, hilog });
const { AppStore } = load('core/store/AppStore.ets', { ...A, hilog });
const { selectChatInputPanel, needsSupergroupBoosts } = load('ui/pages/chat/ChatInputPanelPolicy.ets');
const page = read('ui/pages/chat/TgChatScreenPage.ets').replaceAll('\r\n', '\n');
const methods = new Map();
for (const m of page.matchAll(/^  (?:(?:private|public|protected|async)\s+)*(\w+)\s*\(/gm)) {
  const end = page.indexOf('\n  }', m.index);
  if (end >= 0) methods.set(m[1], page.slice(m.index, end + 4));
}
const selected = ['shouldReactToStoreChange', 'deriveChatBottomBar', 'canUseComposer',
  'canSendNewMessages', 'getSendUseCase', 'getSendMediaUseCase'];
selected.forEach(name => assert.ok(methods.has(name), `Missing actual page method ${name}`));
const Page = new Function('selectChatInputPanel', 'needsSupergroupBoosts', stripTypeScriptTypes(
  `class Page {
  slowmodeController = new globalThis.ChatSlowmodeController();
  composerSlowmodeSeconds = 0;${selected.map(name => methods.get(name)).join('\n')}}`, { mode: 'transform' }) + ';return Page;'
)(selectChatInputPanel, needsSupergroupBoosts);
const raw = x => td.TdObject.fromJSON(JSON.stringify(x));
const permissions = value => ({ '@type': 'chatPermissions', can_send_basic_messages: value,
  can_send_photos: value, can_send_videos: value, can_send_documents: value, can_send_voice_notes: value });
const update = (id, value) => ({ '@type': 'updateChatPermissions', chat_id: id, permissions: permissions(value) });
const normalizer = () => new EventNormalizerImpl();
const tests = [];
function test(name, run) { tests.push({ name, run }); }
function fixture(type = 'supergroup', allowed = true) {
  const id = type === 'private' || type === 'secret' ? 7 : -100123;
  const rootStore = new AppStore(appReducer, undefined, false), store = rootStore.createScope();
  const n = normalizer();
  const p = Object.assign(new Page(), { activeChatId: id, accountStore: store, editingMessageId: '0',
    isEditingMessage: false, sendUseCase: {}, sendMediaUseCase: {} });
  let renders = 0;
  const unsubscribe = store.subscribe((next, prev) => {
    if (p.shouldReactToStoreChange(next, prev)) {
      const chat = next.chats.chats.get(id);
      if (chat) { p.deriveChatBottomBar(chat, next); renders++; }
    }
  });
  return { id, p, n, store, rootStore, unsubscribe, renders: () => renders,
    chat: () => store.getState().chats.chats.get(id),
    async emit(x) { const events = n.normalize(raw(x)); await store.dispatchBatch(events); return events; },
    async seed() {
      const tdType = type === 'group' ? { '@type': 'chatTypeBasicGroup', basic_group_id: 123 }
        : type === 'private' ? { '@type': 'chatTypePrivate', user_id: 7 }
        : type === 'secret' ? { '@type': 'chatTypeSecret', user_id: 7, secret_chat_id: 3 }
        : { '@type': 'chatTypeSupergroup', supergroup_id: 123, is_channel: type === 'channel' };
      await this.emit({ '@type': 'updateNewChat', chat: { '@type': 'chat', id, type: tdType,
        title: 'Permission fixture', permissions: permissions(allowed) } });
      if (type === 'group') await this.emit({ '@type': 'updateBasicGroup', basic_group: {
        '@type': 'basicGroup', id: 123, is_active: true, status: { '@type': 'chatMemberStatusMember' } } });
      if (type === 'supergroup') {
        await this.emit({ '@type': 'updateSupergroup', supergroup: {
          '@type': 'supergroup', id: 123, status: { '@type': 'chatMemberStatusMember' } } });
        await this.emit({ '@type': 'updateSupergroupFullInfo', supergroup_id: 123,
          supergroup_full_info: { '@type': 'supergroupFullInfo', my_boost_count: 0, unrestrict_boost_count: 0 } });
      }
    }
  };
}

for (const value of [false, true]) {
  test(`normalize explicit ${value} through actual complete registry`, () => {
    const n = normalizer(), events = n.normalize(raw(update(-100123, value)));
    assert.equal(events.length, 1);
    assert.equal(events[0].type, 'chatUpdated');
    assert.equal(events[0].chatId, -100123);
    assert.equal(events[0].updates.canSendBasicMessages, value);
    assert.equal(n.getStats().droppedUpdates, 0);
  });
  test(`DTO applyChatUpdate accepts explicit ${value} without changing the original`, () => {
    const dto = Object.assign(new D.ChatDto(), { canSendBasicMessages: !value, title: 'old' });
    const patch = Object.assign(new D.ChatUpdateDto(), { canSendBasicMessages: value });
    assert.equal(D.applyChatUpdate(dto, patch).canSendBasicMessages, value);
    assert.equal(dto.canSendBasicMessages, !value);
  });
  test(`partial reducer applies ${value} to placeholder as well as known chat`, () => {
    const state = A.createInitialAppState();
    const patch = Object.assign(new D.ChatUpdateDto(), { canSendBasicMessages: value });
    const next = appReducer(state, E.createChatUpdatedEvent(-100123, patch));
    assert.equal(next.chats.chats.get(-100123).canSendBasicMessages, value);
    assert.equal(state.chats.chats.size, 0);
  });
}
test('DTO unrelated patch preserves revoked permission', () => {
  const dto = Object.assign(new D.ChatDto(), { canSendBasicMessages: false });
  const next = D.applyChatUpdate(dto, Object.assign(new D.ChatUpdateDto(), { title: 'renamed' }));
  assert.equal(next.canSendBasicMessages, false);
  assert.equal(next.title, 'renamed');
});

for (const type of ['group', 'supergroup']) {
  test(`${type} live revoke/grant reaches actual subscription, panel and send getters`, async () => {
    const f = fixture(type); await f.seed();
    const before = f.store.getState(), renderCount = f.renders();
    assert.equal(f.p.getSendUseCase(), f.p.sendUseCase);
    await f.emit(update(f.id, false));
    assert.equal(f.chat().canSendBasicMessages, false);
    assert.equal(before.chats.chats.get(f.id).canSendBasicMessages, true);
    assert.ok(f.renders() > renderCount);
    assert.equal(f.p.chatBottomBarReason, 'restricted');
    assert.equal(f.p.getSendUseCase(), undefined);
    assert.equal(f.p.getSendMediaUseCase(), undefined);
    await f.emit({ '@type': 'updateChatTitle', chat_id: f.id, title: 'Renamed while restricted' });
    assert.equal(f.chat().canSendBasicMessages, false);
    assert.equal(f.p.getSendUseCase(), undefined);
    await f.emit(update(f.id, true));
    assert.equal(f.chat().canSendBasicMessages, true);
    assert.equal(f.p.chatBottomBarAction, 'none');
    assert.equal(f.p.chatBottomBarRestricted, false);
    assert.equal(f.p.getSendUseCase(), f.p.sendUseCase);
    assert.equal(f.p.getSendMediaUseCase(), f.p.sendMediaUseCase);
    f.unsubscribe();
  });
}
for (const type of ['private', 'secret']) {
  test(`${type} default group permission does not replace peer composer`, async () => {
    const f = fixture(type); await f.seed(); await f.emit(update(f.id, false));
    assert.equal(f.chat().canSendBasicMessages, false);
    assert.equal(f.p.getSendUseCase(), f.p.sendUseCase);
    f.unsubscribe();
  });
}
test('broadcast default permission update cannot grant member posting or revoke creator posting', async () => {
  const f = fixture('channel'); await f.seed();
  await f.emit({ '@type': 'updateSupergroup', supergroup: { '@type': 'supergroup', id: 123,
    status: { '@type': 'chatMemberStatusMember' } } });
  await f.emit(update(f.id, true));
  assert.equal(f.p.getSendUseCase(), undefined);
  await f.emit({ '@type': 'updateSupergroup', supergroup: { '@type': 'supergroup', id: 123,
    status: { '@type': 'chatMemberStatusCreator', is_member: true } } });
  await f.emit(update(f.id, false));
  assert.equal(f.p.getSendUseCase(), f.p.sendUseCase);
  f.unsubscribe();
});

const malformed = [
  ...[0, 1.5, -100123.5, '7', '-100123', null, Number.MAX_SAFE_INTEGER + 1].map(id => update(id, false)),
  { '@type': 'updateChatPermissions', nested: { chat_id: -100123 }, permissions: permissions(false) },
  ...[undefined, null, [], '', false, {}].map(p => ({ '@type': 'updateChatPermissions', chat_id: -100123, permissions: p })),
  ...[undefined, null, 0, 1, 'true', 'false', {}, []].map(v => update(-100123, v)),
  { '@type': 'updateChatPermissions', chat_id: -100123, nested: { permissions: permissions(false) } },
  { '@type': 'updateChatPermissions', chat_id: -100123, permissions: {
    '@type': 'chatPermissions', nested: { can_send_basic_messages: false } } }
];
malformed.forEach((payload, i) => test(`malformed ${i} cannot change known permission`, () => {
  assert.equal(normalizer().normalize(raw(payload)).length, 0);
}));
test('nested lookalikes cannot shadow explicit top-level permissions or booleans', () => {
  const events = normalizer().normalize(raw({ '@type': 'updateChatPermissions', chat_id: -100123,
    nested: { permissions: permissions(false) }, permissions: { '@type': 'chatPermissions',
      nested: { can_send_basic_messages: false }, can_send_basic_messages: true } }));
  assert.equal(events.length, 1);
  assert.equal(events[0].updates.canSendBasicMessages, true);
});
test('queued old-scope permissions cannot survive account reset', async () => {
  const f = fixture('group'); await f.seed();
  const event = normalizer().normalize(raw(update(f.id, false)));
  assert.equal(event.length, 1);
  const pending = f.store.dispatchBatch(event);
  const resetting = f.rootStore.resetStateQueued();
  await Promise.all([pending, resetting]);
  assert.equal(f.rootStore.getState().chats.chats.size, 0);
  await f.store.dispatchBatch(event);
  assert.equal(f.rootStore.getState().chats.chats.size, 0);
  f.unsubscribe();
});
// Execute the registered native suite's actual test bodies with an explicit
// Hypium host adapter as well; device execution remains a separate gate.
const { liveChatPermissionsTest } = load('../../ohosTest/ets/test/LiveChatPermissions.test.ets', {
  ...A, ...D, ...td, EventNormalizerImpl, appReducer, AppStore, selectChatInputPanel,
  describe: (_name, run) => run(), it: (name, _flags, run) => test('ohosTest: ' + name, run),
  expect: actual => ({ assertEqual: expected => assert.equal(actual, expected) })
});
liveChatPermissionsTest();
let finished = false;
process.on('beforeExit', () => { if (!finished) { console.error('Harness ended with unresolved work'); process.exitCode = 1; } });
(async () => {
  let passed = 0, failed = 0;
  for (const t of tests) {
    try { await t.run(); passed++; }
    catch (e) { failed++; console.error('FAIL', t.name, e.message); }
  }
  if (loggedErrors.length) { failed++; console.error('FAIL unexpected normalizer/reducer errors', loggedErrors); }
  finished = true;
  console.log(JSON.stringify({ passed, failed, sources }));
  process.exitCode = failed ? 1 : 0;
})().catch(e => { finished = true; console.error(e); process.exitCode = 1; });

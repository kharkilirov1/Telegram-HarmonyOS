// Actual parser/normalizer/events/reducer/scoped store/use case/controller/page policy.
// Transport is a deferred port fixture; ArkUI rendering and account actions are not executed.
const { readChatSource } = require("./chat-screen-source.cjs");
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
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

function load(p, deps = {}) {
  const source = readChatSource(path.join(root, p), 'utf8');
  const names = [...source.matchAll(/^export\s+(?:async\s+)?(?:class|function|enum|const)\s+(\w+)/gm)].map(m => m[1]);
  const js = stripTypeScriptTypes(source.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+default\s+\w+;?\s*/gm, '').replace(/^export\s+/gm, ''), { mode: 'transform' });
  return new Function(...Object.keys(deps), js + `; return {${names.join(',')}};`)(...Object.values(deps));
}
const hilog = { info() {}, warn() {}, error() {}, debug() {} };
const A = load('core/model/AppState.ets'), C = load('core/model/AppCommand.ets');
const { TdObject } = load('models/td/common/index.ets');
const access = load('core/utils/tdAccessors.ets', { TdObject });
const group = load('core/model/dto/GroupAccessDto.ets', access);
const dto = load('core/model/dto/ChatDto.ets', { ...access, ...C, ...group, hilog });
const E = load('core/model/AppEvent.ets', { ...dto, ...group });
const clone = load('core/utils/stateClone.ets', { ...A, ...group });
const { chatsReducer } = load('core/reducers/chatsReducer.ets', { ...A, ...E, ...clone, ...access,
  ChatDto: dto.ChatDto, DtoChatType: dto.ChatType });
const unusedReducer = () => { throw new Error('unexpected reducer routing in this fixture'); };
const { appReducer } = load('core/reducers/index.ets', { chatsReducer, authReducer: unusedReducer,
  messagesReducer: unusedReducer, usersReducer: unusedReducer, filesReducer: unusedReducer, accentColorsReducer: unusedReducer });
const { AppStore } = load('core/store/AppStore.ets', { ...A, hilog, assertInvariants() {} });
const { registerChatHandlers } = load('core/events/normalizers/ChatNormalizer.ets', { ...E, ...dto, ...group, ...access, hilog });
const { LoadChatAccessUseCase } = load('domain/usecases/loadChatAccess.ets', { ...C, ...E, ...group, TdObject });
const { ChatAccessController } = load('ui/pages/chat/ChatAccessController.ets');
const policy = load('ui/pages/chat/ChatInputPanelPolicy.ets');
const raw = x => TdObject.fromJSON(JSON.stringify(x));
const tick = () => new Promise(resolve => setImmediate(resolve));
const member = role => ({ '@type': 'chatMemberStatus' + role });
const creator = () => ({ ...member('Creator'), is_member: true });
const admin = post => ({ ...member('Administrator'), rights: { '@type': 'chatAdministratorRights',
  can_post_messages: post, can_edit_messages: true } });
const groupUpdate = (id, status) => ({ '@type': 'updateSupergroup', supergroup: { '@type': 'supergroup', id, status } });
const newChat = (id, groupId) => ({ '@type': 'updateNewChat', chat: { '@type': 'chat', id, title: 'Fixture channel',
  type: { '@type': 'chatTypeSupergroup', is_channel: true, supergroup_id: groupId },
  permissions: { '@type': 'chatPermissions', can_send_basic_messages: false } } });
const page = readChatSource(path.join(root, 'ui/pages/chat/TgChatScreenPage.ets'), 'utf8');
function methodBlock(a, b) { const i = page.indexOf(a), j = page.indexOf(b, i); assert.ok(i >= 0 && j > i); return page.slice(i, j); }
const Panel = new Function('selectChatInputPanel', stripTypeScriptTypes(`class Panel {
  slowmodeController = new globalThis.ChatSlowmodeController();
  composerSlowmodeSeconds = 0;
${methodBlock('  private deriveChatBottomBar(', '\n  private bottomBarActionLabel(')}
${methodBlock('  private shouldReactToStoreChange(', '\n  private scheduleLifecycleTask(')}
}`, { mode: 'transform' }) + '; return Panel;')(policy.selectChatInputPanel);

function fixture(chatId = -100123) {
  const rootStore = new AppStore(appReducer, undefined, false), store = rootStore.createScope();
  const requests = [], renders = [];
  const gateway = { send(command) { return new Promise((resolve, reject) => requests.push({ command, resolve, reject })); } };
  const handlers = new Map(); registerChatHandlers(handlers);
  const panel = Object.assign(new Panel(), { activeChatId: chatId, editingMessageId: '0' });
  const controller = new ChatAccessController(new LoadChatAccessUseCase(store, gateway), render);
  function render() {
    const state = store.getState(), chat = state.chats.chats.get(panel.activeChatId);
    if (!chat) return;
    controller.observe(chat, state.chats.supergroupAccess.get(chat.supergroupId));
    panel.chatAccessUnavailable = controller.isUnavailable();
    panel.deriveChatBottomBar(chat, state);
    renders.push(kind());
  }
  function kind() { return panel.chatBottomBarReason || (panel.chatBottomBarAction === 'none' ? 'composer' : panel.chatBottomBarAction); }
  store.subscribe((next, previous) => { if (panel.shouldReactToStoreChange(next, previous)) render(); });
  return { rootStore, store, requests, renders, panel, controller, render, kind,
    async emit(update) { const events = []; const h = handlers.get(update['@type']); assert.ok(h); h(events, raw(update)); await store.dispatchBatch(events); await tick(); } };
}

async function main() {
  const f = fixture();
  await f.emit(newChat(-100123, 123));
  assert.equal(f.kind(), 'unknown'); assert.equal(f.requests.length, 1);
  const initial = f.requests[0];
  assert.equal(initial.command.type, 'getSupergroup');
  await f.emit(groupUpdate(123, member('Member')));
  assert.equal(f.kind(), 'mute');
  initial.resolve(raw({ '@type': 'supergroup', id: 123, status: creator() })); await tick();
  assert.equal(f.kind(), 'mute', 'older query cannot overwrite the live member update');
  await f.emit(groupUpdate(123, admin(true))); assert.equal(f.kind(), 'composer');
  await f.emit({ '@type': 'updateChatPosition', chat_id: -100123,
    position: { '@type': 'chatPosition', list: { '@type': 'chatListMain' }, order: '0', is_pinned: false } });
  assert.equal(f.kind(), 'composer', 'leaving main list is not leaving membership');
  await f.emit(groupUpdate(123, admin(false))); assert.equal(f.kind(), 'mute');
  f.panel.editingMessageId = '5'; f.render(); assert.equal(f.kind(), 'composer');
  f.panel.editingMessageId = '0'; f.render(); assert.equal(f.kind(), 'mute');
  await f.emit(groupUpdate(123, member('Banned'))); assert.equal(f.kind(), 'banned');
  f.controller.dispose();
  console.log('PASS actual live status grant/revoke/banned and stale hydration reach page gate/policy', JSON.stringify(f.renders));

  const early = fixture();
  await early.emit(groupUpdate(123, creator()));
  await early.emit(newChat(-100123, 123));
  assert.equal(early.kind(), 'composer'); assert.equal(early.requests.length, 0, 'group update before chat avoids unnecessary hydration');
  early.controller.dispose();
  console.log('PASS updateSupergroup before newChat survives actual parser/reducer');

  const retry = fixture();
  await retry.emit(newChat(-100123, 123));
  retry.requests[0].reject(new Error('fixture offline')); await tick();
  assert.equal(retry.kind(), 'retry');
  retry.render(); assert.equal(retry.requests.length, 1, 'no retry loop from unrelated render');
  retry.controller.retry(); await tick(); assert.equal(retry.requests.length, 2);
  retry.requests[1].resolve(raw({ '@type': 'supergroup', id: 123, status: creator() })); await tick();
  assert.equal(retry.kind(), 'composer');
  retry.controller.dispose();
  console.log('PASS unknown -> failure -> explicit retry -> authoritative composer');

  const reset = fixture();
  await reset.emit(newChat(-100123, 123));
  const old = reset.store;
  reset.controller.dispose();
  await reset.rootStore.resetStateQueued();
  reset.requests[0].resolve(raw({ '@type': 'supergroup', id: 123, status: creator() })); await tick();
  assert.equal(reset.rootStore.getState().chats.supergroupAccess.size, 0);
  assert.equal(old.getState().chats.supergroupAccess.size, 0);
  console.log('PASS account reset rejects old access hydration');
  console.log('4/4 channel access integration scenarios PASS');
}
let completed = false;
main().then(() => { completed = true; }, error => { completed = true; console.error('FAIL', error); process.exitCode = 1; });
process.on('beforeExit', () => { if (!completed) { console.error('FAIL incomplete integration run'); process.exitCode = 2; } });

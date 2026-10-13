#!/usr/bin/env node
// Node >=24. Actual caller methods + canonical params + real AppStore scopes.
// Native UI, runtime lookup, timers, unrelated use cases and gateway transport
// are explicit fixture boundaries. No native build/device/network/account I/O.
// Real lease construction and parent route factory; lease balance is a separate suite.
// --mutant=scope|deferred-snapshot|rollback-token changes executed code in memory only.
const { readChatSource } = require("./chat-screen-source.cjs");
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '../entry/src/main/ets');
const snapshots = new Map(), methods = {}, tests = [];
const mutant = process.argv.find(arg => arg.startsWith('--mutant='))?.slice(9);
assert.ok(!mutant || ['scope', 'deferred-snapshot', 'rollback-token'].includes(mutant));
const mutationSites = new Set();
const hash = s => createHash('sha256').update(s).digest('hex');
function read(file) {
  if (!snapshots.has(file)) snapshots.set(file, readChatSource(path.join(root, file), 'utf8'));
  let source = snapshots.get(file);
  let from;
  if (mutant === 'scope' && file === 'ui/pages/chat/ChatScreenRouteParams.ets') from = 'this.accountScope.isScopeCurrent()';
  if (mutant === 'rollback-token' && ['ui/pages/chatlist/ChatListPage.ets', 'ui/pages/chatlist/TgArchivedChatsPage.ets',
    'ui/pages/chat/ChatMessageActionsController.ets'].includes(file)) from = 'navigationUIState.activeChatOwnerToken === params.navigationToken';
  if (from) {
    assert.equal(source.split(from).length - 1, 1, `one engaged mutation site: ${file}`);
    source = source.replace(from, 'true'); mutationSites.add(file);
  }
  return source;
}
function evaluate(source, deps, result) {
  const code = source.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, '');
  return new Function(...Object.keys(deps), stripTypeScriptTypes(code, { mode: 'transform' }) +
    `\nreturn ${result};`)(...Object.values(deps));
}
function load(file, deps = {}) {
  const source = read(file);
  const names = [...source.matchAll(/^export\s+(?:class|function|const|enum)\s+(\w+)/gm)].map(m => m[1]);
  return evaluate(source, deps, `{${names.join(',')}}`);
}
function page(file, names, deps, includePreamble = true) {
  const source = read(file);
  const actual = names.filter(name => new RegExp(`^  (?:private )?${name}\\(`, 'm').test(source)).map(name => {
    const start = source.search(new RegExp(`^  (?:private )?${name}\\(`, 'm'));
    const end = source.indexOf('\n  }', start);
    assert.ok(end > start, `complete actual method ${name}`);
    let method = source.slice(start, end + 4);
    if (mutant === 'deferred-snapshot' && name === 'scheduleDeferredOpen') {
      const from = 'this.openChatRoute(params);';
      assert.equal(method.split(from).length - 1, 1, 'deferred mutation engages');
      method = method.replace(from, 'this.openChatRoute(new ChatScreenRouteParams(chatId, title, params.accountStore, params.gateway));');
      mutationSites.add(`${file}:${name}`);
    }
    methods[`${file}:${name}`] = hash(method);
    return method;
  });
  // Retain pre-Wave17 local DTO classes too: baseline must execute, not fail on missing mocks.
  const classes = includePreamble ? source.slice(0, source.indexOf('\n@ComponentV2')).replace(/^import[\s\S]*?;\s*/gm, '') : '';
  return evaluate(`${classes}\nclass Page {${actual.join('\n')}}`, deps, 'Page');
}
const platform = { hilog: { info() {}, warn() {}, error() {} }, localized: (_id, value) => value, $r: id => ({ id }) };
const state = load('core/model/AppState.ets');
const { AppStore } = load('core/store/AppStore.ets', { ...state, ...platform, assertInvariants() {} });
const commands = load('core/model/AppCommand.ets');
const td = load('models/td/common/index.ets');
const lease = load('domain/usecases/ChatOpenLease.ets', { ...commands, ...td });
const { ChatScreenRouteParams } = load('ui/pages/chat/ChatScreenRouteParams.ets', lease);
const unread = load('ui/pages/chat/PendingChatUnreadSnapshot.ets');
const tick = () => new Promise(resolve => setImmediate(resolve));
const test = (name, run) => tests.push({ name, run });
function owner() {
  const s = new AppStore(value => value, state.createInitialAppState(), false);
  for (const id of [7, 9]) {
    const chat = new state.Chat(); chat.id = id; chat.title = `A${id}`;
    chat.unreadCount = 6; chat.lastReadInboxMessageId = '1048576';
    s.getState().chats.chats.set(id, chat);
  }
  return s;
}
class ChatItemVO { chatId = 0; title = ''; unreadCount = 0; }
const item = (chatId = 7) => Object.assign(new ChatItemVO(), { chatId, title: `route${chatId}`, unreadCount: 999 });
function fixture(kind = 'list', options = {}) {
  const sent = [], a = owner(), b = owner();
  const ga = { name: 'A', send: command => { sent.push(['A', command]); return Promise.resolve(); } };
  const gb = { name: 'B', send: command => { sent.push(['B', command]); return Promise.resolve(); } };
  const live = { store: a, gateway: ga, gatewayReads: 0 }, pushes = [], timers = new Map(), factories = [], opens = [];
  const nav = { activeChatId: 42, activeChatTitle: 'prior', activeChatOwnerToken: 81,
    chatScreenVisible: false, chatNavLockUntil: 0 };
  const chatUIState = { activeChatId: 42, activeChatTitle: 'prior' };
  const storage = new Map(Object.entries({ ACTIVE_CHAT_ID: 42, ACTIVE_CHAT_TITLE: 'prior', CHAT_SCREEN_VISIBLE: false, CHAT_NAV_LOCK_UNTIL: 0 }));
  const StorageKeys = Object.fromEntries([...storage.keys()].map(k => [k, k]));
  let timerId = 0;
  const factory = name => (...args) => { factories.push({ name, args }); return { execute: (...args) => { if (name === 'createOpenChatUseCase') opens.push(args); return Promise.resolve(); } }; };
  const deps = { ...platform, ...unread, ChatScreenRouteParams, ChatItemVO, navigationUIState: nav, chatUIState,
    StorageKeys, AppStorage: { set: (k, v) => storage.set(k, v), get: k => storage.get(k) },
    getAppCoreRuntime: () => ({ getStore: () => live.store }),
    getTdGatewayAdapter: () => { live.gatewayReads++; return live.gateway; },
    setTimeout: fn => { timers.set(++timerId, fn); return timerId; }, clearTimeout: id => timers.delete(id),
    TgUiTokens: { STATUS_BAR_FALLBACK_INSET: 24 }, TgUiFeatureFlags: { USE_TG_CHAT_V2: true },
    removeWindowSizeListener() {}, ComposeRouteParams: class {},
    buildChatItemVO: chat => Object.assign(new ChatItemVO(), { chatId: chat.id, title: chat.title, unreadCount: chat.unreadCount }) };
  for (const name of ['createLoadChatsUseCase', 'createLoadArchiveChatsUseCase', 'createLoadActiveStoriesUseCase',
    'createOpenChatUseCase', 'createSetChatMuteUseCase', 'createToggleChatPinnedUseCase', 'createMoveChatToListUseCase',
    'createDeleteChatHistoryUseCase', 'createToggleChatUnreadUseCase']) deps[name] = factory(name);
  const names = ['aboutToAppear', 'aboutToDisappear', 'onPageShow', 'openChat', 'openChatRoute',
    'createChatRouteParams', 'isCurrentAccountOwner', 'requestOpenChatData', 'clearDeferredOpen',
    'scheduleDeferredOpen', 'isCurrentDeferredOpenCallback', 'openComposePicker', 'setChatDestinationVisible',
    'clearActiveChatContext', 'clearRebuildTimer', 'onIslandOpenChatRequested'];
  const file = kind === 'list' ? 'ui/pages/chatlist/ChatListPage.ets' : 'ui/pages/chatlist/TgArchivedChatsPage.ets';
  const Page = page(file, names, deps), p = new Page();
  const stack = { pushPathByName: (...args) => { pushes.push(args); options.push?.(args, nav, p); } };
  Object.assign(p, { pageLifecycleToken: 0, composePickerGeneration: 0, deferredOpenTimerId: -1,
    deferredOpenChatId: 0, deferredOpenChatTitle: '', rebuildTimerId: -1, pageStack: stack, chatDetailStack: stack,
    isComposePickerOpen: false, bindNavigationStack: () => stack, computeSafeInsets() {}, bindWindowSizeListener() {},
    rebuildList() {}, maybeLoadInitialChats() {}, maybeLoadInitialArchive() {}, maybeLoadInitialStories() {},
    loadMoreArchiveChats() {}, onSearchDeactivate: () => options.search?.(live), onKeyboardVisibilityChange() {},
    getUIContext: () => ({ getPromptAction: () => ({ showToast() {} }) }) });
  p.aboutToAppear();
  return { p, a, b, ga, gb, live, pushes, nav, timers, factories, opens, storage, deps, sent,
    switchAccount() { live.store = b; live.gateway = gb; } };
}
test('canonical params require owner, unique tokens and immutable entry snapshot', () => {
  const a = owner(), b = owner(), gateway = {};
  const p = new ChatScreenRouteParams(7, 'title', a, gateway), q = new ChatScreenRouteParams(7, 'title', a, gateway);
  assert.equal(p.accountStore, a); assert.equal(p.gateway, gateway);
  assert.ok(q.navigationToken > p.navigationToken); assert.notEqual(p.openLease, q.openLease);
  assert.equal(p.openLease.gateway, gateway); assert.equal(p.openLease.chatId, 7);
  assert.equal(p.entryUnreadCount, 6); assert.equal(p.entryLastReadInboxMessageId, '1048576');
  a.getState().chats.chats.get(7).unreadCount = 0;
  assert.equal(p.entryUnreadCount, 6); assert.equal(p.isCurrentAccount(a), true); assert.equal(p.isCurrentAccount(b), false);
  a.invalidateScopes(); assert.equal(p.isCurrentAccount(a), false, 'root identity cannot revive captured scope');
});
test('missing reducer chat preserves undefined snapshot, not synthetic zero', () => {
  const store = owner(), p = new ChatScreenRouteParams(99, 'created', store, {});
  assert.equal(p.entryUnreadCount, undefined); assert.equal(p.entryLastReadInboxMessageId, undefined);
  assert.equal(p.isCurrentAccount(store), true, 'valid new chat does not require reducer presence');
});
for (const id of [0, NaN, Infinity, -Infinity, 1.5, -1.5, Number.MAX_SAFE_INTEGER + 1]) {
  test(`canonical invalid ID ${id} is rejected before route activation`, () => {
    const store = owner(), p = new ChatScreenRouteParams(id, 'invalid', store, {});
    assert.equal(p.isCurrentAccount(store), false);
  });
  for (const kind of ['list', 'archive']) test(`${kind}: invalid ID ${id} has no navigation or account effects`, async () => {
    const f = fixture(kind), before = { ...f.nav }, stored = [...f.storage];
    f.p.openChat(item(id)); await tick();
    assert.equal(f.pushes.length, 0); assert.deepEqual(f.nav, before);
    assert.deepEqual([...f.storage], stored); assert.deepEqual(f.sent, []); assert.deepEqual(f.opens, []);
  });
}
test('route fields are readonly and owner arguments have no global/default fallback', () => {
  const source = read('ui/pages/chat/ChatScreenRouteParams.ets');
  for (const name of ['chatId', 'chatTitle', 'accountStore', 'gateway', 'navigationToken', 'openLease',
    'entryUnreadCount', 'entryLastReadInboxMessageId']) assert.match(source, new RegExp(`readonly ${name}\\??:`));
  assert.match(source, /constructor\(chatId: number, chatTitle: string, store: AppStore, gateway: TdGatewayPort\)/);
  assert.doesNotMatch(source, /getAppCoreRuntime|getTdGatewayAdapter|PendingChatUnreadSnapshot/);
});
for (const kind of ['list', 'archive']) {
  test(`${kind}: appear captures gateway once, normal route is canonical and unopened`, async () => {
    let pushedToken;
    const f = fixture(kind, { push: ([name, params], nav) => { if (name === 'TgChatScreenPage') pushedToken = nav.activeChatOwnerToken; } });
    f.p.openChat(item()); const params = f.pushes[0]?.[1];
    assert.ok(params instanceof ChatScreenRouteParams); assert.equal(params.accountStore, f.a); assert.equal(params.gateway, f.ga);
    assert.equal(pushedToken, params.navigationToken); assert.equal(f.live.gatewayReads, 1);
    assert.equal(params.entryUnreadCount, 6, 'owner state wins over stale list item');
    assert.deepEqual(f.opens, []); assert.equal(params.openLease.isOpen(), false);
    await tick(); assert.deepEqual(f.sent, [], 'real lease stays dormant in caller');
  });
  test(`${kind}: gateway lookup changes cannot replace captured gateway`, () => {
    const f = fixture(kind); f.live.gateway = f.gb; f.p.openChat(item());
    assert.equal(f.pushes[0][1].gateway, f.ga); assert.equal(f.live.gatewayReads, 1);
  });
  for (const boundary of ['switch', 'revoke', 'disappear']) test(`${kind}: ${boundary} blocks new account route`, () => {
    const f = fixture(kind);
    if (boundary === 'switch') f.switchAccount();
    if (boundary === 'revoke') f.a.invalidateScopes();
    if (boundary === 'disappear') f.p.aboutToDisappear();
    const before = { ...f.nav }; f.p.openChat(item());
    assert.equal(f.pushes.length, 0); assert.deepEqual(f.nav, before); assert.deepEqual(f.opens, []);
  });
  for (const replacement of [false, true]) test(`${kind}: push failure rollback ${replacement ? 'cannot clobber same-chat successor' : 'restores previous owner'}`, () => {
    const f = fixture(kind, { push: (_args, nav) => { if (replacement) { nav.activeChatOwnerToken = 12345; nav.activeChatTitle = 'successor'; nav.chatScreenVisible = true; } throw new Error('push failed'); } });
    Object.assign(f.nav, { activeChatId: 7, activeChatTitle: 'prior', activeChatOwnerToken: 81, chatScreenVisible: true });
    f.p.openChat(item());
    assert.equal(f.nav.activeChatOwnerToken, replacement ? 12345 : 81);
    assert.equal(f.nav.activeChatTitle, replacement ? 'successor' : 'prior'); assert.equal(f.nav.chatScreenVisible, true);
  });
}
test('deferred open captures snapshot and owner before timer, despite later state changes', () => {
  const f = fixture(); f.p.scheduleDeferredOpen(7, 'delayed', 20);
  f.a.getState().chats.chats.get(7).unreadCount = 0;
  f.a.getState().chats.chats.get(7).lastReadInboxMessageId = '2097152';
  [...f.timers.values()][0]();
  const params = f.pushes[0]?.[1]; assert.ok(params instanceof ChatScreenRouteParams);
  assert.equal(params.entryUnreadCount, 6); assert.equal(params.entryLastReadInboxMessageId, '1048576');
  assert.equal(params.accountStore, f.a); assert.deepEqual(f.opens, []);
});
for (const id of [7, 99]) test(`delayed A route ${id} cannot dispatch on B`, () => {
  const f = fixture(); f.p.scheduleDeferredOpen(id, 'A', 20); const fire = [...f.timers.values()][0];
  f.switchAccount(); const before = { ...f.nav }; fire();
  assert.equal(f.pushes.length, 0); assert.deepEqual(f.nav, before);
});
test('old timer cannot act after disappear/reappear on another account', () => {
  const f = fixture(); f.p.scheduleDeferredOpen(7, 'A', 20); const fire = [...f.timers.values()][0];
  f.p.aboutToDisappear(); f.switchAccount(); f.p.aboutToAppear(); fire(); assert.equal(f.pushes.length, 0);
});
test('list rechecks ownership after search deactivation callback', () => {
  const f = fixture('list', { search: live => { live.store = owner(); } });
  const before = { ...f.nav }; f.p.openChat(item()); assert.equal(f.pushes.length, 0); assert.deepEqual(f.nav, before);
});
test('Compose cancellation restores visibility once without claiming a chat route', () => {
  const f = fixture(); f.p.openComposePicker(); const callback = f.pushes[0][2];
  callback({ result: undefined }); assert.equal(f.nav.chatScreenVisible, false);
  callback({ result: { chatId: 7, chatTitle: 'late' } }); assert.equal(f.pushes.length, 1);
});
test('Compose result cannot overwrite a newer navigation owner', () => {
  const f = fixture(); f.p.openComposePicker(); f.nav.activeChatOwnerToken = 872;
  const before = { ...f.nav }; f.pushes[0][2]({ result: { chatId: 7, chatTitle: 'late' } });
  assert.equal(f.pushes.length, 1); assert.deepEqual(f.nav, before);
});
for (const id of [7, 99]) test(`Compose ${id}: captures source owner and preserves missing-chat contract`, () => {
  const f = fixture(); f.p.openComposePicker(); const callback = f.pushes[0][2];
  f.p.onPageShow(); // Real ordering: page show may precede picker result.
  callback({ result: { chatId: id, chatTitle: 'created', failedMemberCount: 0 } });
  const p = f.pushes.find(([name]) => name === 'TgChatScreenPage')?.[1];
  assert.ok(p instanceof ChatScreenRouteParams); assert.equal(p.accountStore, f.a); assert.equal(p.gateway, f.ga);
  assert.equal(p.entryUnreadCount, id === 7 ? 6 : undefined); assert.deepEqual(f.opens, []);
  callback({ result: { chatId: id, chatTitle: 'duplicate', failedMemberCount: 0 } });
  assert.equal(f.pushes.filter(([name]) => name === 'TgChatScreenPage').length, 1);
});
for (const boundary of ['switch', 'revoke', 'reappear']) test(`Compose result ignores ${boundary} without restoring stale globals`, () => {
  const f = fixture(); f.p.openComposePicker(); const callback = f.pushes[0][2];
  if (boundary === 'revoke') f.a.invalidateScopes(); else f.switchAccount();
  if (boundary === 'reappear') { f.p.aboutToDisappear(); f.p.aboutToAppear(); }
  f.nav.activeChatOwnerToken = 765; const before = { ...f.nav };
  callback({ result: { chatId: 7, chatTitle: 'stale', failedMemberCount: 0 } });
  assert.equal(f.pushes.length, 1); assert.deepEqual(f.nav, before);
});
function forwardFixture(options = {}) {
  const f = fixture(), pushes = [], feedback = [];
  const transfer = load('ui/pages/chat/PendingForwardTransfer.ets').pendingForwardTransfer;
  const transferCalls = { arm: [], consumeFor: [], clear: [] };
  for (const name of Object.keys(transferCalls)) {
    const actual = transfer[name].bind(transfer);
    transfer[name] = (...args) => { transferCalls[name].push(args); return actual(...args); };
  }
  const current = { active: true, lifecycle: 1, sourceChatId: 7 };
  const useCase = { prepare: input => ({ ...input, messageIds: [...new Set(input.messageIds)] }),
    getSourceAvailability: () => options.availability ?? Promise.resolve({ ordinaryTargets: true, secretTargets: false }) };
  class ForwardMessagesParams {}
  const { ChatMessageActionsController } = load('ui/pages/chat/ChatMessageActionsController.ets', {
    ...f.deps, pendingForwardTransfer: transfer, ForwardMessagesParams,
    ForwardTargetPickerRouteParams: class { constructor(sourceChatId) { this.sourceChatId = sourceChatId; } } });
  const Parent = page('ui/pages/chat/TgChatScreenPage.ets', ['createChatRouteParams', 'isRouteContextCurrent', 'getChatRouteToken'], f.deps, false);
  const parent = new Parent(); parent.routeContext = new ChatScreenRouteParams(7, 'source', f.a, f.ga);
  Object.assign(f.nav, { activeChatOwnerToken: parent.routeContext.navigationToken, activeChatId: 7,
    activeChatTitle: 'source', chatScreenVisible: true });
  const host = { getActiveChatId: () => current.sourceChatId, getLifecycleToken: () => current.lifecycle,
    getChatRouteToken: () => parent.getChatRouteToken(),
    hasActiveChatState: () => current.active && f.live.store === f.a && f.a.isScopeCurrent(),
    getSourceForwardUseCase: () => useCase,
    createChatRouteParams: (id, title) => parent.createChatRouteParams(id, title),
    bindNavigationStack: () => ({ pushPathByName: (...args) => { pushes.push(args); options.push?.(args, f.nav, transfer); } }),
    getChatUIContext: () => ({ getPromptAction: () => ({ showToast: args => feedback.push(args) }) }),
    clearReplyMode() {}, clearEditMode() {}, clearForwardMode() {}, setForwardMode: (...args) => { current.forward = args; },
    requestOpenChatData: (...args) => f.opens.push(args) };
  return { ...f, controller: new ChatMessageActionsController(), host, pushes, current, feedback, parent, transfer, transferCalls };
}
test('forward target uses host canonical capability and no caller-open', async () => {
  const f = forwardFixture(); f.controller.openForwardTargetPicker(['1048576'], 'author', 'preview', f.host); await tick();
  assert.equal(f.pushes[0][1].allowOrdinaryTargets, true); assert.equal(f.pushes[0][1].allowSecretTargets, false);
  f.pushes[0][2]({ result: { chatId: 9, chatTitle: 'target' } });
  const p = f.pushes[1]?.[1]; assert.ok(p instanceof ChatScreenRouteParams); assert.equal(p.accountStore, f.a);
  assert.equal(p.gateway, f.ga); assert.equal(f.nav.activeChatOwnerToken, p.navigationToken); assert.deepEqual(f.opens, []);
  f.pushes[0][2]({ result: { chatId: 9, chatTitle: 'duplicate' } }); assert.equal(f.pushes.length, 2);
  await tick(); assert.deepEqual(f.sent, []);
});
test('actual parent factory cannot replace an A capability with global B', () => {
  const f = forwardFixture(); f.switchAccount();
  assert.equal(f.host.createChatRouteParams(9, 'target'), undefined);
});
test('forward factory rejection cannot arm transfer or mutate navigation', async () => {
  const f = forwardFixture(); f.host.createChatRouteParams = () => undefined;
  f.controller.openForwardTargetPicker(['1048576'], 'author', 'preview', f.host); await tick(); const before = { ...f.nav };
  f.pushes[0][2]({ result: { chatId: 9, chatTitle: 'target' } });
  assert.equal(f.pushes.length, 1); assert.deepEqual(f.nav, before); assert.equal(f.transfer.hasPendingFor(9), false);
});
test('Wave13 forward current guard rejects stale result; same-chat result stays in place', async () => {
  const f = forwardFixture(); f.controller.openForwardTargetPicker(['1048576'], 'author', 'preview', f.host); await tick();
  f.switchAccount(); f.pushes[0][2]({ result: { chatId: 9, chatTitle: 'target' } }); assert.equal(f.pushes.length, 1);
  const same = forwardFixture(); same.controller.openForwardTargetPicker(['1048576'], 'author', 'preview', same.host); await tick();
  same.pushes[0][2]({ result: { chatId: 7, chatTitle: 'same' } }); assert.equal(same.pushes.length, 1); assert.ok(same.current.forward);
});
test('Wave13 pending availability rejects superseded lifecycle', async () => {
  let resolve; const f = forwardFixture({ availability: new Promise(r => { resolve = r; }) });
  f.controller.openForwardTargetPicker(['1048576'], 'author', 'preview', f.host); f.current.lifecycle++;
  resolve({ ordinaryTargets: true, secretTargets: false }); await tick(); assert.equal(f.pushes.length, 0);
});
for (const replacement of [false, true]) test(`forward rollback ${replacement ? 'preserves same-chat successor and transfer' : 'restores previous token'}`, async () => {
  const f = forwardFixture({ push: ([name], nav, transfer) => { if (name !== 'TgChatScreenPage') return;
    if (replacement) { nav.activeChatOwnerToken = 54321; nav.activeChatTitle = 'successor'; transfer.arm(9, 9, ['2097152'], 'new', 'new', 54321); }
    throw new Error('push failed'); } });
  const previousOwnerToken = f.nav.activeChatOwnerToken;
  f.controller.openForwardTargetPicker(['1048576'], 'author', 'preview', f.host); await tick();
  f.pushes[0][2]({ result: { chatId: 9, chatTitle: 'target' } });
  assert.equal(f.nav.activeChatOwnerToken, replacement ? 54321 : previousOwnerToken);
  assert.equal(f.transfer.hasPendingFor(9, replacement ? 54321 : f.pushes[1][1].navigationToken), replacement);
});
test('forward arm carries the actual target route token, not the source token', async () => {
  const f = forwardFixture(); f.controller.openForwardTargetPicker(['1048576'], 'author', 'preview', f.host); await tick();
  f.pushes[0][2]({ result: { chatId: 9, chatTitle: 'target' } });
  const token = f.pushes[1][1].navigationToken;
  assert.ok(token > 0); assert.notEqual(token, f.host.getChatRouteToken());
  assert.equal(f.transferCalls.arm[0][5], token);
});
test('forward consume passes host route token and still applies matching draft once', () => {
  const f = forwardFixture(), token = f.host.getChatRouteToken();
  f.transfer.arm(7, 9, ['1048576'], 'author', 'preview', token);
  f.controller.applyPendingForwardTransferIfNeeded(f.host);
  assert.deepEqual(f.transferCalls.consumeFor[0], [7, token]); assert.ok(f.current.forward);
  f.current.forward = undefined; f.controller.applyPendingForwardTransferIfNeeded(f.host); assert.equal(f.current.forward, undefined);
});
test('forward failed push clears only its target route token', async () => {
  const f = forwardFixture({ push: ([name]) => { if (name === 'TgChatScreenPage') throw new Error('failed push'); } });
  f.controller.openForwardTargetPicker(['1048576'], 'author', 'preview', f.host); await tick();
  f.pushes[0][2]({ result: { chatId: 9, chatTitle: 'target' } });
  assert.deepEqual(f.transferCalls.clear, [[f.pushes[1][1].navigationToken]]);
});
for (const recipient of ['new-account', 'same-account-new-route', 'legacy-zero']) {
  test(`armed A forward draft cannot be consumed by ${recipient} with the same chat ID`, async () => {
    const f = forwardFixture(); f.controller.openForwardTargetPicker(['1048576'], 'A author', 'A preview', f.host); await tick();
    f.pushes[0][2]({ result: { chatId: 9, chatTitle: 'A target' } });
    const targetA = f.pushes[1][1];
    if (recipient === 'new-account') { f.switchAccount(); assert.equal(targetA.isCurrentAccount(f.b), false); }
    const target = new ChatScreenRouteParams(9, 'later target', recipient === 'new-account' ? f.b : f.a, f.live.gateway);
    const targetPage = new f.parent.constructor();
    targetPage.routeContext = recipient === 'legacy-zero' ? undefined : target;
    const targetHost = { ...f.host, getActiveChatId: () => 9, getChatRouteToken: () => targetPage.getChatRouteToken() };
    assert.equal(targetHost.getChatRouteToken(), recipient === 'legacy-zero' ? 0 : target.navigationToken);
    f.controller.applyPendingForwardTransferIfNeeded(targetHost);
    assert.equal(f.current.forward, undefined, 'different route must not receive the A draft');
    assert.ok(f.transfer.consumeFor(9, targetA.navigationToken), 'mismatching consume must not discard the owned handoff');
  });
}
test('failed old push cannot clear a newer transfer even before navigation token changes', async () => {
  const f = forwardFixture({ push: ([name], _nav, transfer) => {
    if (name === 'TgChatScreenPage') {
      transfer.arm(9, 9, ['2097152'], 'new', 'new', 456789);
      throw new Error('old push failed after newer handoff');
    }
  } });
  f.controller.openForwardTargetPicker(['1048576'], 'old', 'old', f.host); await tick();
  f.pushes[0][2]({ result: { chatId: 9, chatTitle: 'target' } });
  const remaining = f.transfer.consumeFor(9, 456789);
  assert.ok(remaining); assert.deepEqual(remaining.messageIds, ['2097152']);
});
for (const targetId of [7, 9]) test(`late source picker result ${targetId} cannot replace a newer same-account route`, async () => {
  const f = forwardFixture(); f.controller.openForwardTargetPicker(['1048576'], 'source', 'source', f.host); await tick();
  const newer = new ChatScreenRouteParams(9, 'newer', f.a, f.ga);
  Object.assign(f.nav, { activeChatOwnerToken: newer.navigationToken, activeChatId: 9, activeChatTitle: 'newer' });
  const before = { ...f.nav };
  f.pushes[0][2]({ result: { chatId: targetId, chatTitle: 'late' } });
  assert.equal(f.pushes.length, 1); assert.deepEqual(f.nav, before);
  assert.equal(f.current.forward, undefined); assert.equal(f.transferCalls.arm.length, 0);
});
test('picker availability cannot push over a newer same-account route', async () => {
  let resolve; const f = forwardFixture({ availability: new Promise(r => { resolve = r; }) });
  f.controller.openForwardTargetPicker(['1048576'], 'source', 'source', f.host);
  f.nav.activeChatOwnerToken = new ChatScreenRouteParams(9, 'newer', f.a, f.ga).navigationToken;
  resolve({ ordinaryTargets: true, secretTargets: false }); await tick(); assert.equal(f.pushes.length, 0);
});
test('target dispatch rechecks source navigation owner after host factory returns', async () => {
  const f = forwardFixture(); f.controller.openForwardTargetPicker(['1048576'], 'source', 'source', f.host); await tick();
  const actual = f.host.createChatRouteParams;
  f.host.createChatRouteParams = (id, title) => {
    const params = actual(id, title);
    f.nav.activeChatOwnerToken = new ChatScreenRouteParams(9, 'newer', f.a, f.ga).navigationToken;
    return params;
  };
  f.pushes[0][2]({ result: { chatId: 9, chatTitle: 'late' } });
  assert.equal(f.pushes.length, 1); assert.equal(f.transferCalls.arm.length, 0);
});
test('failed A push clears own handoff after account switch without rolling back B globals', async () => {
  const f = forwardFixture({ push: ([name]) => {
    if (name !== 'TgChatScreenPage') return;
    f.switchAccount();
    Object.assign(f.nav, { activeChatOwnerToken: 987654, activeChatId: 9, activeChatTitle: 'B' });
    throw new Error('A push failed after account switch');
  } });
  f.controller.openForwardTargetPicker(['1048576'], 'source', 'source', f.host); await tick();
  f.pushes[0][2]({ result: { chatId: 9, chatTitle: 'A target' } });
  assert.equal(f.transfer.consumeFor(9, f.pushes[1][1].navigationToken), undefined);
  assert.equal(f.nav.activeChatOwnerToken, 987654); assert.equal(f.nav.activeChatTitle, 'B');
});
(async () => {
  let failed = 0;
  for (const { name, run } of tests) {
    try { await run(); console.log(`PASS ${name}`); }
    catch (error) { failed++; console.log(`FAIL ${name}: ${error.message.slice(0, 350)}`); }
  }
  for (const [file, source] of snapshots) assert.equal(readChatSource(path.join(root, file), 'utf8'), source, `source changed during witness: ${file}`);
  if (mutant) assert.equal(mutationSites.size, mutant === 'rollback-token' ? 3 : 1, 'all mutation sites engaged');
  console.log(JSON.stringify({ passed: tests.length - failed, failed,
    mutant, mutationSites: [...mutationSites], sources: Object.fromEntries([...snapshots].map(([file, s]) => [file, hash(s)])), methods }));
  process.exitCode = failed ? 1 : 0;
})().catch(error => { console.error('HARNESS_ERROR', error); process.exitCode = 2; });

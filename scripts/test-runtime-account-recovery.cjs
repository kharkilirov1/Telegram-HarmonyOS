// Node >=24. Actual runtime/store/adapter/auth side effect/auth parser+reducer.
// Native gateway, history/network and platform UI/context are explicit fixture boundaries.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const root = path.resolve(__dirname, '../entry/src/main/ets');
function load(relative, deps = {}) {
  const source = fs.readFileSync(path.join(root, relative), 'utf8');
  const names = [...source.matchAll(/^export\s+(?:async\s+)?(?:class|function|enum|const)\s+(\w+)/gm)].map(m => m[1]);
  const js = stripTypeScriptTypes(source.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, ''), { mode: 'transform' });
  return new Function(...Object.keys(deps), `${js}\nreturn {${names.join(',')}};`)(...Object.values(deps));
}
const A = load('core/model/AppState.ets');
const C = load('core/model/AppCommand.ets');
const E = load('core/model/AppEvent.ets');
const errors = load('core/model/AppError.ets');
const port = load('domain/ports/TdGatewayPort.ets', errors);
const clone = load('core/utils/stateClone.ets', A);
const { TdObject } = load('models/td/common/index.ets');
const access = load('core/utils/tdAccessors.ets', { TdObject });
const hilog = { info() {}, warn() {}, error() {}, debug() {} };
const { AppStore } = load('core/store/AppStore.ets', { ...A, hilog, assertInvariants() {} });
const { authReducer } = load('core/reducers/authReducer.ets', { ...A, ...clone });
const authHandlers = load('core/events/normalizers/AuthNormalizer.ets', { ...E, ...access, hilog });
const tick = () => new Promise(resolve => setImmediate(resolve));
const raw = value => TdObject.fromJSON(JSON.stringify(value));

async function fixture(transport) {
  const initial = A.createInitialAppState();
  initial.auth.userId = 123;
  initial.users.users.set(123, Object.assign(new A.User(), { id: 123, firstName: 'Account A' }));
  initial.chats.chats.set(7, Object.assign(new A.Chat(), { id: 7, title: 'Private A' }));
  initial.messages.messages.set(7, new Map([['1', Object.assign(new A.Message(), { id: '1', chatId: 7 })]]));
  initial.files.transfers.set(7, Object.assign(new A.FileTransfer(), { fileId: 7, localPath: '/data/account-a' }));
  initial.files.aliases.set('account-a', [7]);
  class TestStore extends AppStore { constructor() { super(authReducer, initial, false); } }
  const handlers = new Map();
  authHandlers.registerAuthHandlers(handlers);
  const normalizer = { normalize(update) {
    const events = [];
    const handler = handlers.get(update.getType());
    if (handler) handler(events, update);
    return events;
  } };
  let generation = 0, ready = false, hooks;
  const listeners = new Set(), requests = [], resets = [], watchers = [];
  const gateway = transport ? transport.gateway : {
    getClientGeneration: () => generation, getState: () => ready ? 'ready' : 'idle', isReady: () => ready,
    setClientRecoveryHooks(value) { hooks = value; },
    subscribeUpdates(fn) { listeners.add(fn); return () => listeners.delete(fn); },
    async initialize() { ready = true; }, async destroy() { ready = false; generation++; },
    send(method) { return new Promise((resolve, reject) => requests.push({ method, generation, resolve, reject })); },
    async retryClosedClient() {
      assert.ok(hooks, 'runtime configured recovery hooks');
      await hooks.beforeRestart(); ready = true; hooks.afterRestart();
    },
    isDrainCongested: () => false
  };
  const adapters = load('infra/td/adapter/TdGatewayAdapter.ets', { ...errors, ...port, hilog,
    getTdGateway: () => gateway, serializeCommand: command => ({ method: command.type, params: new TdObject() }) });
  const sideEffects = load('core/sideeffects/AuthSideEffect.ets', { ...E, ...C, ...errors, ...adapters, hilog,
    TdObject, getTdGateway: () => gateway,
    TELEGRAM_API_ID: 1, TELEGRAM_API_HASH: 'fixture-not-a-real-credential', USE_TEST_DC: true,
    getAppContext: () => ({ databaseDir: '/fixture/db', filesDir: '/fixture/files' }),
    deviceInfo: { brand: 'Fixture', marketName: 'Host', osFullName: 'No device' },
    createLoadChatsUseCase: () => ({ async warmup() {} })
  });
  const runtimeModule = load('app/bootstrap/AppCoreRuntime.ets', {
    ...errors, ...E, ...adapters, ...sideEffects, ...access, hilog, TdObject,
    getTdGateway: () => gateway, getEventNormalizer: () => normalizer,
    TdGatewayImpl: { getInstance: () => gateway },
    AppStore: TestStore, appReducer: authReducer,
    createLoadChatHistoryUseCase: store => ({ async hydrateUsersIfMissing() {}, store }),
    LoadChatHistoryUseCase: { resetState: () => resets.push('history') },
    getMainThreadDispatcher: () => transport ? transport.dispatcher : ({ subscribeUpdates() {}, unsubscribe() {} }),
    initAppStoreBridge() {}, resetAppStoreBridge() {},
    resetAccountNavigationContext: () => resets.push('navigation'),
    resetDownloadAvatarsUseCase: () => resets.push('avatars'),
    resetDownloadMessageMediaUseCase: () => resets.push('media'),
    resetMessageCacheManager: () => resets.push('messages'), resetLoadChatsUseCase: () => resets.push('chats'),
    createDownloadAvatarsUseCase: store => ({ start: () => watchers.push(store) }),
    createDownloadMessageMediaUseCase: store => ({ start: () => watchers.push(store) })
  });
  const runtime = new runtimeModule.AppCoreRuntime();
  await runtime.initialize();
  const emit = state => {
    const update = raw({ '@type': 'updateAuthorizationState', authorization_state: { '@type': 'authorizationState' + state } });
    for (const fn of [...listeners]) if (listeners.has(fn)) fn(update);
  };
  return { runtime, requests, resets, watchers, emit, adapters, gateway, hooks: () => hooks,
    async close() {
      assert.ok(hooks, 'runtime must configure recovery hooks, not just initialize gateway');
      ready = false; generation++; emit('Closed');
      await hooks.beforeRestart();
    },
    restart() { ready = true; hooks.afterRestart(); }
  };
}

async function main() {
  const tests = [
    ['late media completion keeps its captured account store, not a newly fetched scope', async () => {
      const events = [];
      const rootStore = new AppStore((state, event) => { events.push(event.type); return state; }, undefined, false);
      let current = rootStore.createScope();
      let resolveDownload;
      const controllerModule = load('ui/pages/chat/ChatMediaDownloadController.ets', { ...C, ...E, hilog,
        getTdGatewayAdapter: () => ({ send: () => new Promise(resolve => { resolveDownload = resolve; }) }),
        getAppCoreRuntime: () => ({ getStore: () => current })
      });
      const controller = new controllerModule.ChatMediaDownloadController();
      controller.requestMediaDownload(7, 1);
      assert.equal(typeof resolveDownload, 'function');
      await rootStore.resetStateQueued();
      current = rootStore.createScope();
      resolveDownload(raw({ '@type': 'file', local: { '@type': 'localFile', is_downloading_completed: true, path: '/data/account-a' } }));
      await tick();
      assert.deepEqual(events, [], 'an A response must never enqueue a file event into B');
    }],
    ['account navigation reset clears account fields but preserves glass preference', async () => {
      const values = new Map();
      const navigation = { activeChatId: 123, activeChatTitle: 'A', mainTabIndex: 1,
        activeChatOwnerToken: 47, chatScreenVisible: true, chatNavLockUntil: 999, glassMode: 'high' };
      const chat = { activeChatId: 123, activeChatTitle: 'A' };
      const bridge = load('app/bridge/AppStoreBridge.ets', {
        AppStorage: { setOrCreate: (key, value) => values.set(key, value) },
        navigationUIState: navigation, chatUIState: chat
      });
      const K = bridge.StorageKeys;
      values.set(K.ACTIVE_CHAT_ID, 123);
      values.set(K.ACTIVE_CHAT_TITLE, 'Account A');
      values.set(K.CHAT_SCREEN_VISIBLE, true);
      values.set(K.CHAT_NAV_LOCK_UNTIL, 999);
      values.set(K.MAIN_TAB_INDEX, 1);
      values.set(K.GLASS_MODE, 'high');
      bridge.resetAccountNavigationContext();
      assert.equal(values.get(K.ACTIVE_CHAT_ID), 0);
      assert.equal(values.get(K.ACTIVE_CHAT_TITLE), '');
      assert.equal(values.get(K.CHAT_SCREEN_VISIBLE), false);
      assert.equal(values.get(K.CHAT_NAV_LOCK_UNTIL), 0);
      assert.equal(values.get(K.MAIN_TAB_INDEX), 2);
      assert.equal(values.get(K.GLASS_MODE), 'high');
      assert.deepEqual(navigation, { activeChatId: 0, activeChatTitle: '', mainTabIndex: 2,
        activeChatOwnerToken: 0, chatScreenVisible: false, chatNavLockUntil: 0, glassMode: 'high' });
      assert.deepEqual(chat, { activeChatId: 0, activeChatTitle: '' });
    }],
    ['runtime wires recovery and isolates all old store writes/reads', async () => {
      const f = await fixture();
      assert.ok(f.hooks(), 'recovery hooks installed');
      const old = f.runtime.getStore();
      const rootStore = f.runtime.getLifecycleStore();
      let notices = 0;
      rootStore.subscribe(() => notices++);
      const closing = f.close();
      assert.equal(f.runtime.getStore().getState().auth.userId, 0, 'no new account scope before reset barrier');
      await closing;
      assert.equal(f.runtime.getLifecycleStore(), rootStore);
      assert.notEqual(f.runtime.getStore(), old);
      const state = rootStore.getState();
      assert.equal(state.auth.userId, 0);
      assert.equal(state.auth.status, 'closed');
      assert.equal(state.users.users.size + state.chats.chats.size + state.messages.messages.size + state.files.transfers.size + state.files.aliases.size, 0);
      assert.ok(notices > 0);
      f.restart();
      await old.dispatch(E.createMyUserResolvedEvent(999));
      assert.equal(rootStore.getState().auth.userId, 0);
      await f.runtime.getStore().dispatch(E.createMyUserResolvedEvent(456));
      assert.equal(rootStore.getState().auth.userId, 456);
      assert.equal(old.getState().auth.userId, 0, 'old scope cannot read B');
      for (const name of ['history', 'avatars', 'media', 'messages', 'chats', 'navigation']) assert.ok(f.resets.includes(name), name);
      assert.equal(f.watchers.at(-1), f.runtime.getStore(), 'watchers use new account scope');
      await f.runtime.shutdown();
    }],
    ['late getMe and params continuation cannot restore account A or block bootstrap B', async () => {
      const f = await fixture();
      assert.ok(f.hooks(), 'recovery hooks installed');
      f.emit('Ready'); await tick();
      const oldMe = f.requests.find(q => q.method === 'getMe');
      const oldParams = f.requests.find(q => q.method === 'setTdlibParameters');
      assert.ok(oldMe && oldParams);
      await f.close(); f.restart();
      assert.equal(f.requests.filter(q => q.method === 'setTdlibParameters').length, 2);
      oldMe.resolve(raw({ '@type': 'user', id: 123 }));
      oldParams.resolve(raw({ '@type': 'ok' }));
      await tick();
      assert.equal(f.runtime.getStore().getState().auth.userId, 0);
      f.emit('Ready'); await tick();
      const newMe = f.requests.filter(q => q.method === 'getMe').at(-1);
      assert.notEqual(newMe, oldMe);
      newMe.resolve(raw({ '@type': 'user', id: 456 }));
      await tick();
      assert.equal(f.runtime.getStore().getState().auth.userId, 456);
      await f.runtime.shutdown();
    }],
    ['recovery failure is visible without changing to fake phone state', async () => {
      const f = await fixture();
      assert.ok(f.hooks(), 'recovery hooks installed');
      await f.close();
      f.hooks().onFailure(new errors.AppError(errors.AppErrorKind.NETWORK, 'fixture-restart-failed'));
      await tick();
      assert.equal(f.runtime.getStore().getState().auth.status, 'closed');
      assert.ok(f.runtime.getStore().getState().auth.error.length > 0);
      await f.runtime.retryClientRecovery();
      assert.equal(f.runtime.getStore().getState().auth.error, '');
      await f.runtime.shutdown();
    }],
    ['bootstrap failure revokes live scopes and stops account work before reporting error', async () => {
      const f = await fixture();
      await f.close(); f.restart();
      const expired = f.runtime.getStore();
      const resetCount = f.resets.length;
      const requestCount = f.requests.length;
      f.hooks().onFailure(new errors.AppError(errors.AppErrorKind.NETWORK, 'fixture-bootstrap-error'));
      await expired.dispatch(E.createMyUserResolvedEvent(999));
      await tick();
      const state = f.runtime.getLifecycleStore().getState();
      assert.equal(state.auth.userId, 0, 'failed client scope cannot mutate root');
      assert.equal(state.auth.status, 'closed');
      assert.ok(state.auth.error.length > 0);
      assert.ok(f.resets.length > resetCount, 'failure stops watchers and resets caches immediately');
      assert.equal(f.requests.length, requestCount, 'failure does not auto-start another client');
      await f.runtime.shutdown();
    }],
    ['shutdown detaches recovery and late afterRestart cannot restart side effects', async () => {
      const f = await fixture();
      assert.ok(f.hooks(), 'recovery hooks installed');
      const hooks = f.hooks();
      const count = f.requests.length;
      await f.runtime.shutdown();
      assert.equal(f.hooks(), undefined);
      hooks.afterRestart();
      await tick();
      assert.equal(f.requests.length, count);
    }]
  ];
  let failed = 0;
  for (const [name, run] of tests) {
    try { await run(); console.log('PASS', name); }
    catch (error) { if (error.code !== 'ERR_ASSERTION') throw error; failed++; console.log('FAIL', name, error.message); }
  }
  console.log(`${tests.length - failed}/${tests.length} PASS`);
  process.exitCode = failed ? 1 : 0;
}
module.exports = { fixture, load };
if (require.main === module) require('./host-test-completion.cjs').guardSuite(main()).catch(error => { console.error('HARNESS_ERROR', error); process.exitCode = 2; });

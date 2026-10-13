// Node >= 24. Executes current ArkTS runtime/store/reducers/hydrator without native TDLib.
// Normalizer is an explicit fixture mapper; this is ordering/lifecycle, not parser/UI coverage.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const root = path.resolve(__dirname, '../entry/src/main/ets');
function load(relative, deps = {}) {
  const source = fs.readFileSync(path.join(root, relative), 'utf8');
  const names = [...source.matchAll(/^export\s+(?:async\s+)?(?:class|function|const|enum)\s+(\w+)/gm)].map(m => m[1]);
  const js = stripTypeScriptTypes(source.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, ''),
    { mode: 'transform', sourceUrl: relative });
  return new Function(...Object.keys(deps), `${js}\nreturn {${names.join(',')}};`)(...Object.values(deps));
}
const errors = [];
const hilog = { info() {}, debug() {}, warn() {}, error(...args) { errors.push(args); } };
const A = load('core/model/AppState.ets');
const clone = load('core/utils/stateClone.ets', A);
const appErrors = load('core/model/AppError.ets');
const { TdObject } = load('models/td/common/index.ets');
const accessors = load('core/utils/tdAccessors.ets', { TdObject });
const M = load('core/model/dto/MessageDto.ets', { TdObject, ...accessors });
const E = load('core/model/AppEvent.ets', M);
const replyKeys = load('core/utils/replyMessageKey.ets');
const { messagesReducer } = load('core/reducers/messagesReducer.ets', { ...A, ...clone, ...replyKeys });
const { usersReducer } = load('core/reducers/usersReducer.ets', { ...A, ...clone });
const { AppStore } = load('core/store/AppStore.ets', { ...A, hilog, assertInvariants() {} });
const reduce = (state, event) => usersReducer(messagesReducer(state, event), event);
const tick = () => new Promise(resolve => setImmediate(resolve));
const raw = value => TdObject.fromJSON(JSON.stringify(value));
const newMessage = (senderId = 5, id = 101) => raw({ '@type': 'updateNewMessage', message: {
  '@type': 'message', chat_id: 7, id, sender_id: { '@type': 'messageSenderUser', user_id: senderId }
} });
const edit = () => raw({ '@type': 'updateMessageContent', chat_id: 7, message_id: 101 });

async function fixture(cachedUser = false) {
  const listeners = new Set(), order = [], requests = [];
  const initial = A.createInitialAppState();
  if (cachedUser) initial.users.users.set(5, Object.assign(new A.User(), { id: 5 }));
  class TestStore extends AppStore { constructor() { super(reduce, initial, false); } }
  const normalizer = { normalize(update) {
    const type = update.getType();
    order.push(type);
    if (type === 'user') return [{ type: 'userUpdated', userId: update.getNumber('id'),
      userData: Object.assign(new A.User(), { id: update.getNumber('id'), firstName: 'Hydrated' }) }];
    if (type === 'updateNewMessage') {
      const event = new E.NewMessageEvent();
      event.chatId = 7;
      event.messageId = String(update.getObject('message').getNumber('id'));
      Object.assign(event.messageData, { id: event.messageId, chatId: 7, senderId: 5 });
      event.messageData.content.type = 'text';
      event.messageData.content.text = 'original';
      return [event];
    }
    if (type === 'updateMessageContent') {
      const event = new E.MessageContentUpdatedEvent();
      Object.assign(event, { chatId: 7, messageId: '101' });
      event.newContent.type = 'text';
      event.newContent.text = 'edited';
      return [event];
    }
    return [];
  } };
  let gatewayState = 'idle';
  const gateway = {
    subscribeUpdates(fn) { listeners.add(fn); return () => listeners.delete(fn); },
    setClientRecoveryHooks() {},
    async initialize() { gatewayState = 'ready'; },
    async destroy() { gatewayState = 'idle'; },
    isReady: () => gatewayState === 'ready', getState: () => gatewayState
  };
  const adapter = { send(command) {
    return new Promise((resolve, reject) => requests.push({ command, resolve, reject }));
  } };
  const history = load('domain/usecases/loadChatHistory.ets', { ...appErrors, ...accessors, TdObject, hilog,
    getEventNormalizer: () => normalizer, createGetUserCommand: userId => ({ type: 'getUser', userId }) });
  const { AppCoreRuntime } = load('app/bootstrap/AppCoreRuntime.ets', {
    ...appErrors, ...accessors, ...M, ...history, hilog, TdObject,
    getTdGateway: () => gateway, getTdGatewayAdapter: () => adapter, getEventNormalizer: () => normalizer,
    AppStore: TestStore, appReducer: reduce,
    getMainThreadDispatcher: () => ({ subscribeUpdates() {}, unsubscribe() {} }),
    initAppStoreBridge() {}, setAuthSideEffectStore() {}, startAuthSideEffect() {}, stopAuthSideEffect() {},
    resetAppStoreBridge() {}, resetDownloadAvatarsUseCase() {}, resetDownloadMessageMediaUseCase() {},
    resetMessageCacheManager() {}, resetLoadChatsUseCase() {}, resetTdGatewayAdapter() {},
    createDownloadAvatarsUseCase: () => ({ start() {} }), createDownloadMessageMediaUseCase: () => ({ start() {} }),
    ChatUpdateDto: class {}, extractLastMessage: () => ({}), createChatUpdatedEvent: () => ({ type: 'chatUpdated' })
  });
  const runtime = new AppCoreRuntime();
  await runtime.initialize();
  return { runtime, order, requests, listeners, emit(update) { for (const fn of listeners) fn(update); },
    text() { return runtime.getLifecycleStore().getState().messages.messages.get(7)?.get('101')?.content.text; } };
}

async function main() {
  const tests = [
    ['cached sender: creation and edit keep receive order', async () => {
      const f = await fixture(true);
      f.emit(newMessage()); f.emit(edit());
      await tick();
      assert.deepEqual(f.order, ['updateNewMessage', 'updateMessageContent']);
      assert.equal(f.text(), 'edited');
      assert.equal(f.requests.length, 0);
      await f.runtime.shutdown();
    }],
    ['missing sender: pending network hydration cannot block or reorder updates', async () => {
      const f = await fixture();
      f.emit(newMessage()); f.emit(edit()); f.emit(newMessage(5, 102));
      await tick();
      assert.deepEqual(f.order, ['updateNewMessage', 'updateMessageContent', 'updateNewMessage']);
      assert.equal(f.text(), 'edited');
      assert.equal(f.requests.length, 1, 'real hydrator deduplicates same sender');
      assert.deepEqual(f.requests[0].command, { type: 'getUser', userId: 5 });
      f.requests[0].resolve(raw({ '@type': 'user', id: 5 }));
      await tick();
      assert.equal(f.runtime.getStore().getState().users.users.get(5).firstName, 'Hydrated');
      assert.equal(f.text(), 'edited');
      await f.runtime.shutdown();
    }],
    ['hydration rejection cannot discard the incoming message', async () => {
      const f = await fixture();
      f.emit(newMessage()); f.emit(edit());
      await tick();
      assert.equal(f.text(), 'edited', 'message is visible before hydration settles');
      assert.equal(f.requests.length, 1);
      f.requests[0].reject(new Error('fixture-offline'));
      await tick();
      assert.equal(f.text(), 'edited');
      await f.runtime.shutdown();
    }],
    ['shutdown invalidates pending hydration and detached update callbacks', async () => {
      const f = await fixture();
      const oldListener = [...f.listeners][0];
      f.emit(newMessage());
      await tick();
      assert.equal(f.text(), 'original');
      assert.equal(f.requests.length, 1);
      await f.runtime.shutdown();
      f.requests[0].resolve(raw({ '@type': 'user', id: 5 }));
      oldListener(edit());
      await tick();
      assert.equal(f.runtime.getStore().getState().users.users.has(5), false);
      assert.equal(f.text(), 'original');
      assert.deepEqual(f.order, ['updateNewMessage']);
    }],
    ['shutdown before first dispatch continuation does not start hydration', async () => {
      const f = await fixture();
      let stoppedDeliveries = 0;
      f.runtime.getStore().subscribe(() => {
        if (!f.runtime.isPipelineRunning()) stoppedDeliveries++;
      });
      f.emit(newMessage());
      await f.runtime.shutdown();
      await tick();
      assert.equal(f.requests.length, 0);
      assert.equal(f.text(), undefined, 'queued raw events must not mutate a stopped runtime');
      assert.equal(stoppedDeliveries, 0);
    }],
    ['store checks batch and single-event guards at dequeue without poisoning following work', async () => {
      const events = [];
      const store = new AppStore((state, event) => { events.push(event.type); return state; }, undefined, false);
      let active = true;
      const guard = () => active;
      const single = store.dispatchBatch([{ type: 'stale-single' }], guard);
      const batch = store.dispatchBatch([{ type: 'stale-a' }, { type: 'stale-b' }], guard);
      active = false;
      await Promise.all([single, batch]);
      assert.deepEqual(events, []);
      await store.dispatchBatch([{ type: 'unguarded' }]);
      active = true;
      await store.dispatchBatch([{ type: 'current-a' }, { type: 'current-b' }], guard);
      assert.deepEqual(events, ['unguarded', 'current-a', 'current-b']);
    }]
  ];
  let failed = 0;
  for (const [name, run] of tests) {
    try { await run(); console.log(`PASS ${name}`); }
    catch (error) {
      if (error.code !== 'ERR_ASSERTION') throw error;
      failed++; console.log(`FAIL ${name}: ${error.message}`);
    }
  }
  assert.deepEqual(errors, [], 'no swallowed runtime errors');
  console.log(`${tests.length - failed}/${tests.length} PASS`);
  process.exitCode = failed ? 1 : 0;
}
require('./host-test-completion.cjs').guardSuite(main()).catch(error => { console.error('HARNESS_ERROR', error); process.exitCode = 2; });

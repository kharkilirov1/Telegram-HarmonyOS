// Read-only source harness. Node.js >= 24. No SDK, network, native library or account access.
// FAIL means a reviewed contract is violated, not that this harness expects broken behavior.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const sourceRoot = path.join(root, 'entry/src/main/ets');
const sources = new Map();
const results = [];
const hilog = { info() {}, warn() {}, error() {}, debug() {} };

function source(relative) {
  const value = fs.readFileSync(path.join(sourceRoot, relative), 'utf8');
  sources.set(relative, createHash('sha256').update(value).digest('hex'));
  return value;
}

// Evaluate the current source, not copied implementations. Only import/export wiring
// and TS annotations are removed. Platform dependencies are injected explicitly.
function load(relative, deps = {}, names) {
  let text = source(relative);
  names ??= [...text.matchAll(/^export\s+(?:class|function|const|enum)\s+(\w+)/gm)].map(m => m[1]);
  text = text.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, '');
  const js = stripTypeScriptTypes(text, { mode: 'transform', sourceUrl: relative });
  return new Function(...Object.keys(deps), `${js}\nreturn {${names.join(',')}};`)(...Object.values(deps));
}

async function test(name, run) {
  try {
    const evidence = await run();
    results.push({ name, status: 'PASS', evidence });
  } catch (error) {
    if (error.code !== 'ERR_ASSERTION') throw error; // Harness failures must not masquerade as product defects.
    results.push({ name, status: 'FAIL', actual: error.actual, expected: error.expected, message: error.message });
  }
}

async function main() {
  const A = load('core/model/AppState.ets');
  const clone = load('core/utils/stateClone.ets', A);
  const M = load('core/model/dto/MessageDto.ets');
  const E = load('core/model/AppEvent.ets', M);
  const { filesReducer } = load('core/reducers/filesReducer.ets', { ...A, ...clone, hilog });
  const seed = () => {
    const state = A.createInitialAppState();
    const message = new A.Message();
    Object.assign(message, { id: '10', chatId: 101, replyToChatId: 202, replyToMessageId: '20' });
    message.content.type = 'photo';
    message.content.photoFileId = 77;
    state.messages.messages.set(101, new Map([['10', message]]));
    return state;
  };
  const downloaded = id => Object.assign(new E.FileDownloadedEvent(), {
    fileId: id, localPath: '/data/mock/photo', isComplete: true, uniqueId: ''
  });
  await test('CONTROL: unrelated download preserves cross-chat reply', () => {
    const next = filesReducer(seed(), downloaded(78));
    assert.equal(next.messages.messages.get(101).get('10').replyToChatId, 202);
  });
  await test('R3: matching download preserves cross-chat reply', () => {
    const next = filesReducer(seed(), downloaded(77));
    const message = next.messages.messages.get(101).get('10');
    assert.equal(message.content.photoPath, '/data/mock/photo', 'Intended reducer branch must engage');
    assert.equal(message.replyToChatId, 202);
  });
  await test('CONTROL: ordinary chat clone preserves id and title', () => {
    const chat = Object.assign(new A.Chat(), { id: 101, title: 'Fixture' });
    assert.equal(clone.cloneChat(chat).title, 'Fixture');
    assert.equal(clone.cloneChat(chat).id, 101);
  });
  await test('R4: cloneChat preserves revoked sending permission', () => {
    const chat = Object.assign(new A.Chat(), { id: 101, type: 'supergroup', canSendBasicMessages: false });
    assert.equal(clone.cloneChat(chat).canSendBasicMessages, false);
  });

  const deferred = [];
  const { ChatMediaDownloadController } = load('ui/pages/chat/ChatMediaDownloadController.ets', {
    ...E, hilog,
    createDownloadFileCommand: fileId => ({ type: 'downloadFile', fileId }),
    createCancelDownloadFileCommand: fileId => ({ type: 'cancelDownloadFile', fileId }),
    getTdGatewayAdapter: () => ({ send: () => new Promise((resolve, reject) => deferred.push({ resolve, reject })) }),
    getAppCoreRuntime: () => ({ getStore: () => ({ dispatch: async () => {} }) })
  });
  await test('R5: cancelled attempt failure cannot invalidate retry', async () => {
    const controller = new ChatMediaDownloadController();
    controller.requestMediaDownload(77, 1);
    controller.cancelMediaDownload(77);
    controller.requestMediaDownload(77, 1);
    deferred[0].reject(new Error('old-request-failed'));
    await new Promise(resolve => setImmediate(resolve));
    const actual = { pending: controller.isDownloadPending(77), failed: controller.isDownloadFailed(77) };
    deferred[1].resolve({}); // cancelDownloadFile response
    deferred[2].resolve({ getObject: () => ({ getBool: () => false, getString: () => '' }) });
    assert.deepEqual(actual, { pending: true, failed: false });
  });

  // Extract only the pure panel dispatcher, not ArkUI rendering or component decorators.
  const page = source('ui/pages/chat/TgChatScreenPage.ets');
  const start = page.indexOf('  private deriveChatBottomBar(');
  const end = page.indexOf('\n  private bottomBarActionLabel(', start);
  if (start < 0 || end < 0) throw new Error('Panel dispatcher extraction boundary changed');
  const panelJS = stripTypeScriptTypes(`class Panel {\n${page.slice(start, end)}\n}`, { mode: 'transform' });
  const policy = load('ui/pages/chat/ChatInputPanelPolicy.ets');
  const groupAccess = load('core/model/dto/GroupAccessDto.ets');
  const Panel = new Function('selectChatInputPanel', `${panelJS}\nreturn Panel;`)(policy.selectChatInputPanel);
  await test('R6: channel with posting rights exposes composer', () => {
    // R6 now has an authoritative access model. Seed actual creator membership,
    // not default permissions as an implicit role. The expected composer is unchanged.
    const channel = Object.assign(new A.Chat(), { id: -100123, supergroupId: 123,
      type: 'channel', order: '99', canSendBasicMessages: false });
    const state = A.createInitialAppState();
    state.chats.supergroupAccess.set(123, Object.assign(new groupAccess.GroupAccessDto(),
      { groupId: 123, kind: 'supergroup', role: 'creator', isMember: true }));
    const panel = new Panel();
    panel.editingMessageId = '0';
    panel.deriveChatBottomBar(channel, state);
    assert.equal(panel.chatBottomBarAction, 'none');
    assert.equal(panel.chatBottomBarRestricted, false, 'composer must not be replaced by a disabled info panel');
  });

  const { TdObject } = load('models/td/common/index.ets');
  const errors = load('core/model/AppError.ets');
  const { MainThreadDispatcher } = load('infra/threading/MainThreadDispatcher.ets', { hilog });
  const dispatcher = new MainThreadDispatcher();
  let timerId = 0;
  const timers = new Map(), callbacks = [], sends = [];
  let createdClients = 0;
  const { TdGatewayImpl } = load('infra/td/gateway/TdGateway.ets', {
    ...errors, TdObject, hilog,
    tdlib: {
      createClient: () => ++createdClients,
      startReceiveLoop: callback => callbacks.push(callback),
      stopReceiveLoop() {},
      send: (id, json) => sends.push({ id, request: JSON.parse(json) })
    },
    getMainThreadDispatcher: () => dispatcher,
    setTimeout: (fn, ms) => { const id = ++timerId; timers.set(id, { fn, ms }); return id; },
    clearTimeout: id => timers.delete(id)
  }, ['TdGatewayImpl']);
  const gateway = TdGatewayImpl.getInstance();
  dispatcher.subscribeUpdates(raw => gateway.handleUpdateOnMainThread(raw));
  await gateway.initialize();
  const authUpdates = [];
  gateway.subscribeUpdates(update => authUpdates.push(update.getObject('authorization_state').getType()));
  callbacks[0](JSON.stringify([{ '@type': 'updateAuthorizationState', '@client_id': 1,
    authorization_state: { '@type': 'authorizationStateClosed' } }]));
  for (const [id, timer] of [...timers]) {
    if (timer.ms === 2) { timers.delete(id); timer.fn(); }
  }
  await test('R2: initialize after Closed creates a new native client', async () => {
    assert.deepEqual(authUpdates, ['authorizationStateClosed'], 'Closed must reach actual gateway');
    await gateway.initialize();
    assert.equal(createdClients, 2, `state=${gateway.getState()}, createdClients=${createdClients}`);
  });

  // Actual AppCoreRuntime + cached-user hydration + AppStore + messagesReducer.
  // The normalizer is a fixture mapper: parsing itself is NOT under test here.
  const replyKeys = load('core/utils/replyMessageKey.ets');
  const { messagesReducer } = load('core/reducers/messagesReducer.ets', { ...A, ...clone, ...replyKeys });
  const { AppStore } = load('core/store/AppStore.ets', { ...A, hilog, assertInvariants() {} });
  const initialState = A.createInitialAppState();
  initialState.users.users.set(5, Object.assign(new A.User(), { id: 5 }));
  class TestStore extends AppStore {
    constructor() { super(messagesReducer, initialState, false); }
  }
  const { createLoadChatHistoryUseCase } = load('domain/usecases/loadChatHistory.ets', { ...errors, hilog, TdObject });
  const listeners = [], order = [];
  const fakeGateway = { subscribeUpdates: fn => { listeners.push(fn); return () => {}; }, setClientRecoveryHooks() {}, async initialize() {}, isReady: () => true };
  const newEvent = new E.NewMessageEvent();
  newEvent.chatId = 7;
  newEvent.messageId = '101';
  Object.assign(newEvent.messageData, { id: '101', chatId: 7, senderId: 5 });
  newEvent.messageData.content.type = 'text';
  newEvent.messageData.content.text = 'original';
  const editEvent = new E.MessageContentUpdatedEvent();
  editEvent.chatId = 7;
  editEvent.messageId = '101';
  editEvent.newContent.type = 'text';
  editEvent.newContent.text = 'edited';
  const { AppCoreRuntime } = load('app/bootstrap/AppCoreRuntime.ets', {
    ...errors, hilog, TdObject,
    getTdGateway: () => fakeGateway, getTdGatewayAdapter: () => ({}),
    getEventNormalizer: () => ({ normalize: update => {
      order.push(update.getType());
      return [update.getType() === 'updateNewMessage' ? newEvent : editEvent];
    } }),
    AppStore: TestStore, appReducer: messagesReducer, createLoadChatHistoryUseCase,
    getMainThreadDispatcher: () => ({ subscribeUpdates() {} }),
    initAppStoreBridge() {}, setAuthSideEffectStore() {}, startAuthSideEffect() {},
    createDownloadAvatarsUseCase: () => ({ start() {} }),
    createDownloadMessageMediaUseCase: () => ({ start() {} }),
    tdGetObject: (o, key) => o.getObject(key), tdGetString: (o, key) => o.getString(key), tdGetNumber: (o, key) => o.getNumber(key),
    ChatUpdateDto: class {}, extractLastMessage: () => ({}), createChatUpdatedEvent: () => ({ type: 'chatUpdated' })
  });
  const runtime = new AppCoreRuntime();
  await runtime.initialize();
  const input = [
    { '@type': 'updateNewMessage', message: { '@type': 'message', chat_id: 7, id: 101, sender_id: { '@type': 'messageSenderUser', user_id: 5 } } },
    { '@type': 'updateMessageContent', chat_id: 7, message_id: 101 }
  ];
  for (const update of input) for (const listener of listeners) listener(TdObject.fromJSON(JSON.stringify(update)));
  await new Promise(resolve => setImmediate(resolve));
  await test('R1: update creation then edit preserves final edited text', () => {
    const text = runtime.getStore().getState().messages.messages.get(7)?.get('101')?.content.text;
    assert.deepEqual({ order, text }, { order: ['updateNewMessage', 'updateMessageContent'], text: 'edited' });
  });
  for (const result of results) console.log(JSON.stringify(result));
  console.log(JSON.stringify({ summary: { passed: results.filter(r => r.status === 'PASS').length, failed: results.filter(r => r.status === 'FAIL').length }, sources: Object.fromEntries(sources) }));
  process.exitCode = results.some(r => r.status === 'FAIL') ? 1 : 0;
}

main().catch(error => { console.error('HARNESS_ERROR', error); process.exitCode = 2; });

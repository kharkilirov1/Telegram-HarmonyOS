// Node >=24. Actual DTO/auth/adapter/classifier modules; synthetic platform/transport only.
// Breaks caught: payload logging, duplicate fallthrough/resend, malformed catch failure,
// lost typed cause metadata, and any processing of silent 406 details.
const { assert, load: actualLoad, run } = require('./stabilization-harness.cjs');
const mutation = process.argv.find(arg => arg.startsWith('--privacy-mutant='))?.slice(17);
const mutations = {
  'chat-payload-log': ['core/model/dto/ChatDto.ets', '  return chatDto;',
    "  hilog.info(0, 'ChatDto', 'id=%{public}d title=%{public}s', chatDto.id, chatDto.title);\n  return chatDto;"],
  'avatar-payload-log': ['core/model/dto/UserDto.ets', '  return photo;',
    "  hilog.info(0, 'UserDto', 'file=%{public}d path=%{public}s', photo.smallFileId, photo.small);\n  return photo;"],
  'duplicate-catch-fallthrough': ['core/sideeffects/AuthSideEffect.ets',
    "        hilog.info(DOMAIN, TAG, 'Duplicate setTdlibParameters ignored (already accepted by TDLib)');\n        return;\n      }\n      hilog.error",
    "        hilog.info(DOMAIN, TAG, 'Duplicate setTdlibParameters ignored (already accepted by TDLib)');\n      }\n      hilog.error"],
  'adapter-raw-detail': ['infra/td/adapter/TdGatewayAdapter.ets',
    'serialized.method, err.kind, err.tdlibCode);', 'serialized.method, err.userMessage, err.tdlibCode);'],
  'auth-silent-diagnostic': ['core/sideeffects/AuthSideEffect.ets',
    '      if (isSilentTdlibError(error)) return;', '      if (false) return;'],
  'returned406-detail-read': ['core/sideeffects/AuthSideEffect.ets',
    "        if (code === 406) return;\n        const err: AppError = classifyTdlibError(code, response.getString('message'));",
    "        const message: string = response.getString('message');\n        if (code === 406) return;\n        const err: AppError = classifyTdlibError(code, message);"],
  'normalization-loses-type': ['core/model/AppError.ets', '  if (error instanceof AppError) return error;', ''],
  'dispatcher-stringifies-error': ['infra/threading/MainThreadDispatcher.ets',
    '          this.handlerErrorCount);', '          this.handlerErrorCount, String(error));']
};
assert.ok(!mutation || mutations[mutation], 'Named privacy mutation required');
let mutationsApplied = 0;
function load(relative, deps = {}) {
  return actualLoad(relative, deps, source => {
    if (!mutation || mutations[mutation][0] !== relative) return source;
    const [, before, after] = mutations[mutation];
    source = source.replaceAll('\r\n', '\n'); assert.ok(source.includes(before), 'Exact loaded production mutation anchor');
    mutationsApplied++; return source.replace(before, after);
  });
}
const app = load('core/model/AppError.ets');
const td = load('models/td/common/index.ets');
const access = load('core/utils/tdAccessors.ets', td);
const commands = load('core/model/AppCommand.ets');
const events = load('core/model/AppEvent.ets');
const port = load('domain/ports/TdGatewayPort.ets', app);
const serializer = load('infra/td/serialization/CommandSerializer.ets', td);
const permissions = load('core/model/dto/GroupAccessDto.ets', access);
const secret = 'SYNTHETIC_PRIVATE_%{public}s_%s_%d';
const chatId = 987654321012;
const fileId = 987654322;
const raw = value => td.TdObject.fromJSON(JSON.stringify(value));
function logger() {
  const logs = [];
  const hilog = Object.fromEntries(['info', 'debug', 'warn', 'error'].map(level =>
    [level, (...args) => logs.push({ level, args })]));
  return { logs, hilog };
}
function privateAbsent(logs, forbidden = [secret]) {
  for (const entry of logs) for (const arg of entry.args) for (const value of forbidden) {
    assert.ok(!String(arg).includes(String(value)), 'Private payload reached HiLog format/args: ' + entry.level);
  }
}
function safeFailure(logs, code, kind) {
  privateAbsent(logs);
  const failures = logs.filter(entry => entry.level === 'error' || entry.level === 'warn');
  assert.equal(failures.length, 1, 'One safe failure diagnostic');
  assert.ok(failures[0].args.slice(3).includes(code), 'Numeric code stays outside constant format');
  assert.ok(failures[0].args.slice(3).includes(kind), 'Useful safe cause classification');
  assert.ok(failures[0].args[2].includes('%{public}d'), 'Constant format has numeric code placeholder');
}
function authFixture(send, warmup = async () => {}, context = { databaseDir: '/fixture/db', filesDir: '/fixture/files' }) {
  const sink = logger(), requests = [], dispatched = [];
  const gateway = { send: async (method, params) => { requests.push(method); return send(method, params); } };
  const adapters = { getTdGatewayAdapter: () => ({ send: async command => {
    const request = serializer.serializeCommand(command); requests.push(request.method); return send(request.method, request.params);
  } }) };
  const auth = load('core/sideeffects/AuthSideEffect.ets', {
    ...app, ...td, ...commands, ...events, ...adapters, hilog: sink.hilog,
    getTdGateway: () => gateway, getAppContext: () => context,
    TELEGRAM_API_ID: 1, TELEGRAM_API_HASH: 'synthetic-not-a-credential', USE_TEST_DC: true,
    deviceInfo: { brand: 'Fixture', marketName: 'Host', osFullName: 'Host' },
    createLoadChatsUseCase: () => ({ warmup })
  });
  auth.setAuthSideEffectStore({ dispatch: async event => dispatched.push(event) });
  const owner = auth.getAuthSideEffect(); owner.isRunning = true; owner.lifecycleToken = 1;
  return { ...sink, owner, requests, dispatched };
}
function adapterFixture(error) {
  const sink = logger();
  const gateway = { getClientGeneration: () => 7, isReady: () => true, send: async () => { throw error; } };
  const adapters = load('infra/td/adapter/TdGatewayAdapter.ets', {
    ...app, ...port, ...td, ...serializer, hilog: sink.hilog, getTdGateway: () => gateway
  });
  return { ...sink, adapter: adapters.getTdGatewayAdapter() };
}
async function caught(promise) { try { await promise; } catch (error) { return error; } assert.fail('Expected rejection'); }
const rejected = error => async () => { throw error; };
function silentError() {
  const error = new app.AppError(app.AppErrorKind.TDLIB_ERROR, '', '', 406, false, true);
  for (const field of ['message', 'userMessage', 'technicalMessage']) Object.defineProperty(error, field, {
    get() { assert.fail('Silent 406 detail getter read: ' + field); }
  });
  return error;
}
function silentResponse() {
  const response = raw({ '@type': 'error', code: 406 });
  const getString = response.getString.bind(response);
  response.getString = key => { if (key === 'message') assert.fail('Silent 406 response message read'); return getString(key); };
  return response;
}
const tests = [
  ['getMe preserves user dispatch while keeping identity out of diagnostics', async () => {
    const f = authFixture(async () => raw({ '@type': 'user', id: chatId })); await f.owner.resolveCurrentUser(1);
    assert.equal(f.dispatched.length, 1); assert.equal(f.dispatched[0].userId, chatId); privateAbsent(f.logs, [chatId]);
  }],
  ['invalid getMe identity reports constant failure without identity payload', async () => {
    const id = -chatId, f = authFixture(async () => raw({ '@type': 'user', id })); await f.owner.resolveCurrentUser(1);
    assert.deepEqual(f.dispatched, []); assert.equal(f.logs.filter(e => e.level === 'error').length, 1); privateAbsent(f.logs, [id]);
  }],
  ['invalid parameter paths report constant failure without path payload', async () => {
    const f = authFixture(async () => assert.fail('Invalid paths must not send'), async () => {}, { databaseDir: '', filesDir: secret });
    await f.owner.sendTdlibParameters(1); assert.deepEqual(f.requests, []);
    assert.equal(f.logs.filter(e => e.level === 'error').length, 1); privateAbsent(f.logs);
  }],
  ['chat DTO retains parsed identity/title/avatar without logging private data', async () => {
    const sink = logger();
    const dto = load('core/model/dto/ChatDto.ets', { ...access, ...commands, ...permissions, hilog: sink.hilog });
    const chat = dto.createChatDtoFromTd(raw({ '@type': 'chat', id: chatId, title: secret,
      type: { '@type': 'chatTypePrivate', user_id: 42 }, unread_count: 3,
      photo: { '@type': 'chatPhotoInfo', small: { '@type': 'file', id: fileId, local: { '@type': 'localFile', path: '/fixture/' + secret } }, big: { '@type': 'file', id: fileId + 1, local: { '@type': 'localFile', path: '/fixture/big' } } },
      positions: [{ list: { '@type': 'chatListMain' }, order: '99', is_pinned: true }] }));
    assert.equal(chat.id, chatId); assert.equal(chat.title, secret); assert.equal(chat.peerUserId, 42);
    assert.equal(chat.unreadCount, 3); assert.equal(chat.order, '99'); assert.equal(chat.isPinned, true);
    assert.equal(chat.photo.small, '/fixture/' + secret); assert.equal(chat.photo.smallFileId, fileId);
    privateAbsent(sink.logs, [secret, chatId, fileId]);
  }],
  ['user DTO retains avatar paths/file ids without logging private data', async () => {
    const sink = logger();
    const dto = load('core/model/dto/UserDto.ets', { ...access, hilog: sink.hilog });
    const user = dto.createUserDtoFromTd(raw({ '@type': 'user', id: 42, first_name: secret,
      profile_photo: { '@type': 'userProfilePhoto', small: { '@type': 'file', id: fileId, local: { '@type': 'localFile', path: '/fixture/' + secret } },
        big: { '@type': 'file', id: fileId + 1, local: { '@type': 'localFile', path: '/fixture/big' } } } }));
    assert.equal(user.id, 42); assert.equal(user.firstName, secret); assert.equal(user.photo.small, '/fixture/' + secret);
    assert.equal(user.photo.smallFileId, fileId); assert.equal(user.photo.bigFileId, fileId + 1);
    privateAbsent(sink.logs, [secret, fileId]);
  }],
  ['classified duplicate 400 accepts once, reports info, clears in-flight without error fallthrough', async () => {
    const f = authFixture(rejected(app.classifyTdlibError(400, 'Unexpected setTdlibParameters ' + secret)));
    await assert.doesNotReject(f.owner.sendTdlibParameters(1));
    assert.equal(f.owner.tdlibParamsAccepted, true); assert.equal(f.owner.tdlibParamsInFlight, false);
    assert.equal(f.logs.filter(e => e.level === 'error').length, 0, 'Accepted duplicate must exit catch');
    assert.ok(f.logs.some(e => e.level === 'info' && /Duplicate/.test(e.args[2])));
    await f.owner.sendTdlibParameters(1); assert.deepEqual(f.requests, ['setTdlibParameters']); privateAbsent(f.logs);
  }],
  ['returned duplicate 400 accepts once and exits without error fallthrough', async () => {
    const f = authFixture(async () => raw({ '@type': 'error', code: 400, message: 'Unexpected setTdlibParameters ' + secret }));
    await f.owner.sendTdlibParameters(1); assert.equal(f.owner.tdlibParamsAccepted, true);
    assert.equal(f.owner.tdlibParamsInFlight, false); assert.equal(f.logs.filter(e => e.level === 'error').length, 0);
    await f.owner.sendTdlibParameters(1); assert.deepEqual(f.requests, ['setTdlibParameters']); privateAbsent(f.logs);
  }],
  ['ordinary Error already short-circuits duplicate check without secondary throw (baseline fact)', async () => {
    const f = authFixture(rejected(new Error(secret)));
    await assert.doesNotReject(f.owner.sendTdlibParameters(1));
    assert.equal(f.owner.tdlibParamsAccepted, false); assert.equal(f.owner.tdlibParamsInFlight, false);
    assert.deepEqual(f.requests, ['setTdlibParameters']);
  }],
  ['ordinary Error uses safe UNKNOWN diagnostics instead of raw detail', async () => {
    const f = authFixture(rejected(new Error(secret))); await f.owner.sendTdlibParameters(1);
    safeFailure(f.logs, 0, app.AppErrorKind.UNKNOWN);
  }],
  ['classified nonduplicate 400 remains an error with safe code/classification', async () => {
    const f = authFixture(rejected(app.classifyTdlibError(400, secret))); await f.owner.sendTdlibParameters(1);
    assert.equal(f.owner.tdlibParamsAccepted, false); assert.equal(f.owner.tdlibParamsInFlight, false);
    assert.deepEqual(f.requests, ['setTdlibParameters']); safeFailure(f.logs, 400, app.AppErrorKind.TDLIB_ERROR);
  }],
  ['returned nonduplicate 400 remains an error with safe code/classification', async () => {
    const f = authFixture(async () => raw({ '@type': 'error', code: 400, message: secret })); await f.owner.sendTdlibParameters(1);
    assert.equal(f.owner.tdlibParamsAccepted, false); assert.equal(f.owner.tdlibParamsInFlight, false);
    safeFailure(f.logs, 400, app.AppErrorKind.TDLIB_ERROR);
  }],
  ['getMe returned error uses safe diagnostics', async () => {
    const f = authFixture(async () => raw({ '@type': 'error', code: 401, message: secret })); await f.owner.resolveCurrentUser(1);
    safeFailure(f.logs, 401, app.AppErrorKind.AUTH); assert.deepEqual(f.dispatched, []);
  }],
  ['getMe typed catch uses safe diagnostics', async () => {
    const f = authFixture(rejected(app.classifyTdlibError(429, secret))); await f.owner.resolveCurrentUser(1);
    safeFailure(f.logs, 429, app.AppErrorKind.RATE_LIMIT);
  }]
];
for (const method of ['declareSessionOnline', 'ensureServiceChatKnown', 'warmChatsCache']) tests.push([
  method + ' typed catch reports safe classification without payload', async () => {
    const error = app.classifyTdlibError(503, secret), f = authFixture(rejected(error), rejected(error));
    await f.owner[method](1); safeFailure(f.logs, 503, app.AppErrorKind.NETWORK);
  }
]);
for (const value of [null, undefined, secret, { tdlibCode: 400 }]) tests.push([
  'malformed auth catch safely exits: ' + (value === null ? 'null' : typeof value), async () => {
    const f = authFixture(rejected(value)); await assert.doesNotReject(f.owner.sendTdlibParameters(1));
    assert.equal(f.owner.tdlibParamsInFlight, false); assert.equal(f.owner.tdlibParamsAccepted, false);
    safeFailure(f.logs, 0, app.AppErrorKind.UNKNOWN); assert.deepEqual(f.requests, ['setTdlibParameters']);
  }
]);
for (const method of ['sendTdlibParameters', 'resolveCurrentUser', 'declareSessionOnline', 'ensureServiceChatKnown', 'warmChatsCache']) tests.push([
  method + ' silent406 exits before any detail getter', async () => {
    const error = silentError(), f = authFixture(rejected(error), rejected(error));
    await assert.doesNotReject(f.owner[method](1)); assert.equal(f.logs.filter(e => e.level === 'error' || e.level === 'warn').length, 0);
    if (method === 'sendTdlibParameters') assert.equal(f.owner.tdlibParamsInFlight, false);
  }
]);
for (const method of ['sendTdlibParameters', 'resolveCurrentUser']) tests.push([
  method + ' returned406 skips message getter and diagnostics', async () => {
    const f = authFixture(async () => silentResponse()); await assert.doesNotReject(f.owner[method](1));
    assert.equal(f.logs.filter(e => e.level === 'error' || e.level === 'warn').length, 0);
  }
]);
tests.push(['adapter silent406 preserves identity without reading details', async () => {
  const error = silentError(), f = adapterFixture(error), result = await caught(f.adapter.send(commands.createLoadChatsCommand(20)));
  assert.equal(result, error); assert.equal(result.tdlibCode, 406); assert.equal(result.requestRejected, true);
  assert.equal(f.logs.filter(e => e.level === 'error').length, 0);
}]);
for (const [code, kind, retryable] of [[400, 'TDLIB_ERROR', false], [401, 'AUTH', false], [429, 'RATE_LIMIT', true], [503, 'NETWORK', true]]) tests.push([
  'adapter preserves classified cause/identity and safely logs code ' + code, async () => {
    const error = app.classifyTdlibError(code, secret), f = adapterFixture(error);
    assert.equal(await caught(f.adapter.send(commands.createLoadChatsCommand(20))), error);
    assert.equal(error.kind, kind); assert.equal(error.tdlibCode, code); assert.equal(error.retryable, retryable);
    assert.equal(error.requestRejected, true); assert.equal(error.technicalMessage, secret); safeFailure(f.logs, code, kind);
  }
]);
tests.push(['adapter ordinary Error preserves legacy wrapping while logging only classification', async () => {
  const f = adapterFixture(new Error(secret)), error = await caught(f.adapter.send(commands.createLoadChatsCommand(20)));
  assert.ok(error instanceof port.GatewayError); assert.equal(error.code, port.GatewayErrorCode.CONNECTION_FAILED);
  assert.equal(error.userMessage, secret); assert.equal(error.technicalMessage, 'loadChats');
  assert.equal(error.retryable, true); assert.equal(error.requestRejected, false); safeFailure(f.logs, 0, app.AppErrorKind.UNKNOWN);
}]);
tests.push(['adapter malformed rejection becomes GatewayError rather than secondary TypeError', async () => {
  const f = adapterFixture(null), error = await caught(f.adapter.send(commands.createLoadChatsCommand(20)));
  assert.ok(error instanceof port.GatewayError); assert.equal(error.code, port.GatewayErrorCode.CONNECTION_FAILED);
  assert.equal(error.retryable, true); assert.equal(error.requestRejected, false); safeFailure(f.logs, 0, app.AppErrorKind.UNKNOWN);
}]);
for (const [subscribe, dispatch] of [['subscribeUpdates', 'dispatchUpdate'], ['subscribeResponses', 'dispatchResponse']]) {
  for (const error of [new Error(secret), { toString() { assert.fail('Dispatcher must not stringify caught value'); } }]) tests.push([
    dispatch + ' contains handler failure, preserves dispatch/counters without raw error processing: ' + (error instanceof Error ? 'Error' : 'malformed'), async () => {
      const sink = logger(), { MainThreadDispatcher } = load('infra/threading/MainThreadDispatcher.ets', { hilog: sink.hilog });
      const dispatcher = new MainThreadDispatcher(), delivered = [];
      dispatcher[subscribe](data => { delivered.push(data); throw error; });
      assert.doesNotThrow(() => dispatcher[dispatch]('fixture-raw-' + secret));
      assert.deepEqual(delivered, ['fixture-raw-' + secret]);
      const stats = dispatcher.getStats(); assert.equal(stats.dispatched, 1); assert.equal(stats.dropped, 0);
      assert.equal(stats.handlerErrors, 1); assert.equal(stats.isSubscribed, true); privateAbsent(sink.logs);
      dispatcher.unsubscribe(); dispatcher[dispatch]('fixture-dropped');
      assert.equal(dispatcher.getStats().dispatched, 2); assert.equal(dispatcher.getStats().dropped, 1);
      assert.equal(dispatcher.getStats().handlerErrors, 1);
    }
  ]);
}
if (mutation) tests.push(['named negative control engages real loaded production source', async () => {
  assert.ok(mutationsApplied > 0); console.log('NEGATIVE_CONTROL ' + mutation + ' engaged=' + mutationsApplied);
}]);
require('./host-test-completion.cjs').guardSuite(run('privacy/error real-module boundary', tests)).catch(error => {
  console.error('HARNESS_ERROR', error); process.exitCode = 2;
});

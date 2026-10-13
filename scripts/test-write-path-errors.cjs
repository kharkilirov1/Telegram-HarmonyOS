#!/usr/bin/env node
// Actual unchanged Hypium callbacks plus actual gateway/native-boundary pipeline.
// No network, account action or real delivery. Only transport, timers, platform
// presentation/file preparation and bootstrap are explicit fixtures.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '..');
const option = name => { const i = process.argv.indexOf(name); return i < 0 ? undefined : process.argv[i + 1]; };
const baseline = option('--baseline-dir'), mutation = option('--mutation'), output = option('--json');
const expectRed = process.argv.includes('--expect-red');
assert.ok(!expectRed || baseline || mutation);
assert.ok(!(baseline && mutation));
const main = 'entry/src/main/ets/';
const sdkFile = 'entry/src/ohosTest/ets/test/WritePathErrors.test.ets';
const hashes = {}, logs = [];
const hilog = Object.fromEntries(['info', 'warn', 'debug', 'error'].map(level => [level, (...args) => logs.push({ level, args })]));
const platform = { hilog, localized: (_id, fallback) => fallback, $r: id => ({ id }), TgUiTokens: {} };
let mutationCount = 0;
const errorFile = main + 'core/model/AppError.ets', textOwner = main + 'ui/pages/chat/ChatTextSendController.ets';
const mutants = {
  'typed-code-lost': [[errorFile, 'typed?.tdlibCode ?? 0', '0']],
  'typed-kind-lost': [[errorFile, 'silent ? AppErrorKind.TDLIB_ERROR : typed?.kind ?? AppErrorKind.UNKNOWN', 'AppErrorKind.UNKNOWN']],
  'typed-detail-lost': [[errorFile, "silent ? '' : typed?.technicalMessage ?? (error instanceof Error ? error.message : 'Write request failed')", "''"]],
  '406-classifier-unguarded': [[errorFile, "  if (code === 406) return tdlibRejectedError(AppErrorKind.TDLIB_ERROR, '', '', code, false);", '']],
  '406-gateway-read': [[main + 'infra/td/gateway/TdGateway.ets', "code === 406 ? '' : response.getString('message')", "response.getString('message')"]],
  '406-normalizer-read': [[main + 'core/events/normalizers/MessageNormalizer.ets', "errorCode === 406 ? '' : tdGetString(errorObj, 'message')", "tdGetString(errorObj, 'message')"]],
  'forward-unknown-replayed': [[main + 'ui/pages/chat/ChatMessageActionsController.ets', 'unknown ? [] : messageIds', 'messageIds']],
  'retired-client-called-rejected': [[main + 'infra/td/adapter/TdGatewayAdapter.ets', 'error.requestRejected = requestRejected;', 'error.requestRejected = true;']],
  'text-confirmation-skipped': [[textOwner, 'if (this.hasTextConsumption(chatId, lifecycleToken, useCase, key))', 'if (false && this.hasTextConsumption(chatId, lifecycleToken, useCase, key))']],
  'text-cancel-called-confirmed': [[textOwner, 'return result.index === 1;', 'return true;']],
  'text-confirmation-input-unguarded': [[textOwner, 'host.getComposerInputRevision() !== inputRevision', 'false']],
  'text-restoration-revision-unguarded': [[textOwner, 'submitted && host.getComposerInputRevision() === clearedRevision', 'submitted && true']],
  'text-reply-cleared-on-submit': [[textOwner, '      clearedRevision = host.getComposerInputRevision();', '      host.clearReplyMode();\n      clearedRevision = host.getComposerInputRevision();']],
  'text-original-caret-lost': [[textOwner, 'host.setDraftSelection(originalSelectionStart, originalSelectionEnd);', 'host.setDraftSelection(0, 0);']],
  'text-original-draft-lost': [[textOwner, 'host.setDraftText(originalDraft);', 'host.setDraftText(sentText);']],
  'text-response-chat-unchecked': [[main + 'domain/usecases/sendMessage.ets', "response.getTopLevelNumberStrict('chat_id') !== params.chatId", 'false']],
  'media-response-chat-unchecked': [[main + 'domain/usecases/sendMediaMessage.ets', "response.getTopLevelNumberStrict('chat_id') !== params.chatId", 'false']]
};
assert.ok(!mutation || mutants[mutation], 'Named supported behavioral mutation required');
function read(relative) {
  const filename = path.join(baseline && relative.startsWith(main) ? path.resolve(baseline) : root, relative);
  let value = fs.readFileSync(filename, 'utf8'); hashes[filename] = createHash('sha256').update(value).digest('hex');
  value = value.replaceAll('\r\n', '\n');
  if (mutation) for (const [target, before, after] of mutants[mutation]) {
    if (target !== relative) continue;
    assert.ok(value.includes(before), 'Behavioral mutation anchor must engage: ' + target);
    value = value.replace(before, after); mutationCount++;
  }
  return value;
}
function load(relative, deps = {}) {
  const source = read(relative), names = [...source.matchAll(/^(?:export\s+(?:default\s+)?)?(?:async\s+)?(?:class|function|const|enum)\s+(\w+)/gm)].map(m => m[1]);
  const filtered = Object.fromEntries(Object.entries(deps).filter(([name]) => !names.includes(name)));
  const js = stripTypeScriptTypes(source.replace(/^import[\s\S]*?;\s*/gm, '')
    .replace(/^export\s+\{[\s\S]*?\}\s*(?:from\s*'[^']*')?;?\s*/gm, '')
    .replace(/^export\s+default\s+\w+;?\s*$/gm, '').replace(/^export\s+(?:default\s+)?/gm, ''),
    { mode: 'transform', sourceUrl: relative });
  return new Function(...Object.keys(filtered), js + '\nreturn {' + names.join(',') + '};')(...Object.values(filtered));
}
const commands = load(main + 'core/model/AppCommand.ets');
const app = load(main + 'core/model/AppError.ets');
const td = load(main + 'models/td/common/index.ets');
const accessors = load(main + 'core/utils/tdAccessors.ets', td);
const events = load(main + 'core/model/AppEvent.ets', accessors);
const state = load(main + 'core/model/AppState.ets');
const clones = load(main + 'core/utils/stateClone.ets', state);
const reply = load(main + 'core/utils/replyMessageKey.ets');
const reducer = load(main + 'core/reducers/messagesReducer.ets', { ...state, ...events, ...clones, ...reply });
const normalizer = load(main + 'core/events/normalizers/MessageNormalizer.ets', { ...events, ...td, ...accessors, ...platform });
const port = load(main + 'domain/ports/TdGatewayPort.ets', app);
const dependencies = { ...commands, ...app, ...td, ...accessors, ...platform };
const text = load(main + 'domain/usecases/sendMessage.ets', dependencies);
const album = load(main + 'domain/usecases/sendMediaAlbum.ets', dependencies);
const media = load(main + 'domain/usecases/sendMediaMessage.ets', { ...dependencies, ...album });
const forward = load(main + 'domain/usecases/forwardMessages.ets', dependencies);
const photo = load(main + 'ui/pages/chat/ChatPhotoAlbumController.ets', { ...dependencies, ...media, ...album });
const preparer = load(main + 'ui/pages/chat/ChatAttachmentFilePreparer.ets', {
  ...platform, fileIo: { unlinkSync() {}, accessSync: () => true }, fileUri: { getUriFromPath: value => 'file://' + value }
});
const emoji = load(main + 'ui/tg_ui/utils/TgCustomEmojiDraftPolicy.ets', commands);
const textControllerFile = main + 'ui/pages/chat/ChatTextSendController.ets';
const textController = fs.existsSync(path.join(baseline ? path.resolve(baseline) : root, textControllerFile))
  ? load(textControllerFile, { ...dependencies, ...text, ...emoji }) : {};
const sequentialFile = main + 'ui/pages/chat/ChatSequentialMediaController.ets';
const sequential = fs.existsSync(path.join(baseline ? path.resolve(baseline) : root, sequentialFile))
  ? load(sequentialFile, { ...dependencies, ...media }) : {};
const composer = load(main + 'ui/pages/chat/ChatComposerController.ets', { ...dependencies, ...text, ...media, ...photo, ...preparer, ...emoji, ...textController, ...sequential });
const actions = load(main + 'ui/pages/chat/ChatMessageActionsController.ets', { ...dependencies, ...text, ...forward });
const tests = [];
const hypium = { describe: (_name, body) => body(), it: (name, _flags, run) => tests.push({ name, run, scope: 'actual unchanged Hypium callback' }),
  expect: value => ({ assertEqual: other => assert.strictEqual(value, other), assertTrue: () => assert.strictEqual(value, true), assertFalse: () => assert.strictEqual(value, false) }) };
const sdk = load(sdkFile, { ...dependencies, ...state, ...reducer, ...events, ...normalizer, ...text, ...media, ...album, ...forward, ...composer, ...actions, ...hypium });
sdk.writePathErrorsTest();
const nativeCount = tests.length;
const serializer = load(main + 'infra/td/serialization/CommandSerializer.ets', dependencies);
function pipeline() {
  const requests = [], timers = new Map(); let sequence = 0;
  const raw = load(main + 'infra/td/gateway/TdGateway.ets', {
    ...app, ...td, hilog, getMainThreadDispatcher: () => { throw new Error('Native bootstrap forbidden'); },
    setTimeout: (callback, delay) => { timers.set(++sequence, { callback, delay }); return sequence; }, clearTimeout: id => timers.delete(id),
    tdlib: { send: (client, json) => requests.push({ client, json: JSON.parse(json) }) }
  });
  const gateway = raw.TdGatewayImpl.getInstance(); gateway.state = 'ready'; gateway.clientId = 7; gateway.clientGeneration = 1;
  const adapters = load(main + 'infra/td/adapter/TdGatewayAdapter.ets', { ...dependencies, ...port, ...serializer, getTdGateway: () => gateway });
  const adapter = adapters.getTdGatewayAdapter();
  return { gateway, adapter, requests, timers,
    reply: (code, message, client = 7) => { const request = requests.at(-1); assert.ok(request); gateway.handleResponseOnMainThread(JSON.stringify({
      '@type': 'error', '@client_id': client, '@extra': request.json['@extra'], code, message })); },
    timeout: () => { const timer = [...timers.values()][0]; assert.ok(timer); timer.callback(); } };
}
const add = (name, run) => tests.push({ name, run, scope: 'host actual gateway/serializer/adapter integration' });
async function failure(promise) { try { await promise; } catch (error) { assert.ok(error instanceof app.AppError); return error; } assert.fail('Expected typed rejection'); }
add('actual gateway+adapter 406 rejection exposes no raw payload or log', async () => {
  const f = pipeline(), before = logs.length; const promise = f.adapter.send(commands.createSendMessageCommand(42, 'fixture text', '0', []));
  assert.equal(f.requests.length, 1); assert.equal(f.requests[0].json['@type'], 'sendMessage');
  f.reply(406, 'FLOOD_WAIT_99 PRIVATE_406_SECRET'); const error = await failure(promise);
  assert.equal(error.tdlibCode, 406); assert.equal(error.message, ''); assert.equal(error.technicalMessage, ''); assert.equal(error.retryable, false);
  assert.equal(f.timers.size, 0); assert.equal(f.gateway.pendingRequests.size, 0);
  assert.ok(!JSON.stringify(logs.slice(before)).includes('PRIVATE_406_SECRET'), 'No 406 payload in gateway/adapter logs');
});
add('actual gateway 406 branch never asks TdObject for message field', async () => {
  const f = pipeline(); const promise = f.adapter.send(commands.createSendMessageCommand(42, 'fixture text', '0', []));
  const original = td.TdObject.prototype.getString; let reads = 0;
  td.TdObject.prototype.getString = function(key, ...args) { if (key === 'message') { reads++; throw new Error('Poisoned 406 message accessor'); } return original.call(this, key, ...args); };
  let thrown;
  try { f.reply(406, 'POISON_406'); } catch (error) { thrown = error; }
  finally { td.TdObject.prototype.getString = original; }
  assert.equal(reads, 0, '406 must skip message accessor entirely'); assert.equal(thrown, undefined);
  const error = await failure(promise); assert.equal(error.tdlibCode, 406);
});
add('send-failed 406 update never reads nested message accessor', () => {
  const handlers = new Map(); normalizer.registerMessageHandlers(handlers);
  const update = td.TdObject.fromJSON('{"@type":"updateMessageSendFailed","old_message_id":100,"message":{"@type":"message","id":101,"chat_id":42},"error":{"@type":"error","code":406,"message":"UPDATE_SECRET"}}');
  const original = td.TdObject.prototype.getString; let reads = 0, thrown, results = [];
  td.TdObject.prototype.getString = function(key, ...args) {
    if (key === 'message' && this.getNumber('code') === 406) { reads++; throw new Error('Poisoned nested 406 message'); }
    return original.call(this, key, ...args);
  };
  try { handlers.get('updateMessageSendFailed')(results, update); } catch (error) { thrown = error; }
  finally { td.TdObject.prototype.getString = original; }
  assert.equal(reads, 0, 'Nested 406 must skip message processing'); assert.equal(thrown, undefined);
  assert.equal(results.length, 1); assert.equal(results[0].errorMessage, ''); assert.equal(results[0].errorCode, 406);
});
add('stale-client 406 envelope cannot settle or log current write', async () => {
  const f = pipeline(), before = logs.length; const promise = f.adapter.send(commands.createSendMessageCommand(42, 'fixture', '0', []));
  f.reply(406, 'STALE_406_SECRET', 6); assert.equal(f.gateway.pendingRequests.size, 1); assert.equal(f.timers.size, 1);
  assert.ok(!JSON.stringify(logs.slice(before)).includes('STALE_406_SECRET')); f.reply(400, 'CHAT_WRITE_FORBIDDEN');
  const error = await failure(promise); assert.equal(error.tdlibCode, 400); assert.equal(f.timers.size, 0);
});
add('late 406 after timeout cannot turn uncertain write into success or replay', async () => {
  const f = pipeline(), before = logs.length; const promise = f.adapter.send(commands.createSendMessageCommand(42, 'fixture', '0', []));
  f.timeout(); const error = await failure(promise); assert.equal(error.tdlibCode, 0); assert.equal(error.kind, app.AppErrorKind.NETWORK);
  f.reply(406, 'LATE_406_SECRET'); assert.equal(f.requests.length, 1); assert.equal(f.gateway.pendingRequests.size, 0);
  assert.ok(!JSON.stringify(logs.slice(before)).includes('LATE_406_SECRET'));
});
add('retired adapter after submitted text keeps outcome unknown without mutating original cause', async () => {
  const f = pipeline(), useCase = new text.SendMessageUseCase(f.adapter);
  const params = Object.assign(new text.SendMessageParams(), { chatId: 42, text: 'retired write' });
  const promise = useCase.execute(params); assert.equal(f.requests.length, 1);
  f.reply(400, 'CHAT_WRITE_FORBIDDEN'); f.gateway.clientGeneration++;
  const error = await failure(promise); assert.equal(error.kind, app.AppErrorKind.NETWORK);
  assert.equal(error.writeOutcomeUnknown, true, 'Retirement after native send is not a definite rejection'); assert.equal(error.requestRejected, false);
  assert.equal(f.requests.length, 1);
});
function dialogFixture() {
  const host = new sdk.WriteHost(), controller = new composer.ChatComposerController(), dialogs = [], toasts = [];
  host.getChatUIContext = () => ({
    getHostContext: () => ({ resourceManager: { getColorByNameSync: () => 0xff0088cc } }),
    getPromptAction: () => ({ showToast: args => toasts.push(args), showDialog: args => new Promise(resolve => dialogs.push({ args, resolve })) })
  });
  host.setDraftText('ambiguous text'); host.reply = '55'; host.entities = [new commands.CustomEmojiTextEntity(0, 2, '123')];
  return { host, controller, dialogs, toasts };
}
async function ambiguousFirst(f, malformed = false) {
  f.controller.handleSendMessage(f.host.draft, f.host); await sdk.settleWrites(); assert.equal(f.host.gateway.requests.length, 1);
  if (malformed) f.host.gateway.requests[0].resolve(td.TdObject.fromJSON('{"@type":"ok"}'));
  else f.host.gateway.requests[0].reject(new Error('Synthetic transport timeout'));
  await sdk.settleWrites(); assert.equal(f.host.busy, false); assert.equal(f.host.draft, 'ambiguous text');
}
add('native-dialog boundary Cancel then Send again permits exactly one repeat text request', async () => {
  const f = dialogFixture(); await ambiguousFirst(f); const beforeDraft = f.host.draft, beforeReply = f.host.reply;
  f.controller.handleSendMessage(f.host.draft, f.host); await sdk.settleWrites(); assert.equal(f.dialogs.length, 1); assert.equal(f.host.gateway.requests.length, 1);
  assert.equal(f.host.busy, true); f.controller.handleSendMessage(f.host.draft, f.host); await sdk.settleWrites(); assert.equal(f.dialogs.length, 1);
  f.dialogs[0].resolve({ index: 0 }); await sdk.settleWrites(); assert.equal(f.host.busy, false); assert.equal(f.host.gateway.requests.length, 1);
  assert.equal(f.host.draft, beforeDraft); assert.equal(f.host.reply, beforeReply); assert.equal(f.host.entities.length, 1);
  f.controller.handleSendMessage(f.host.draft, f.host); await sdk.settleWrites(); assert.equal(f.dialogs.length, 2);
  f.dialogs[1].resolve({ index: 1 }); await sdk.settleWrites(); assert.equal(f.host.gateway.requests.length, 2);
  const command = f.host.gateway.requests[1].command; assert.equal(command.payload.text, 'ambiguous text'); assert.equal(command.payload.replyToMessageId, '55');
  assert.equal(command.payload.customEmojiEntities.length, 1); assert.equal(command.payload.customEmojiEntities[0].customEmojiId, '123');
  f.host.gateway.requests[1].resolve(td.TdObject.fromJSON('{"@type":"message","id":901,"chat_id":42}')); await sdk.settleWrites();
  assert.equal(f.host.busy, false); assert.equal(f.host.draft, ''); assert.equal(f.host.reply, '0'); assert.equal(f.host.entities.length, 0);
});
for (const boundary of ['permission', 'account', 'lifecycle', 'route', 'operation', 'draft-ABA', 'edit', 'attachment', 'forward']) {
  add('pending Send again cannot outlive changed composer ' + boundary, async () => {
    const f = dialogFixture(); await ambiguousFirst(f); f.controller.handleSendMessage(f.host.draft, f.host); await sdk.settleWrites(); assert.equal(f.dialogs.length, 1);
    if (boundary === 'permission') f.host.allowed = false;
    if (boundary === 'account') f.host.active = false;
    if (boundary === 'lifecycle') f.host.lifecycle++;
    if (boundary === 'route') f.host.chatId = 43;
    if (boundary === 'operation') f.host.setSendingMessage(true);
    if (boundary === 'draft-ABA') { f.host.setDraftText('new draft'); f.host.setDraftText('ambiguous text'); }
    if (boundary === 'edit') f.host.setEditMode('99', 'new edit');
    if (boundary === 'attachment') f.host.attachments = ['fixture:new'];
    if (boundary === 'forward') f.host.setForwardMode(['90'], 88, 'new source', 'new preview');
    const draft = f.host.draft, reply = f.host.reply, operation = f.host.operation;
    f.dialogs[0].resolve({ index: 1 }); await sdk.settleWrites(); assert.equal(f.host.gateway.requests.length, 1);
    assert.equal(f.host.draft, draft); assert.equal(f.host.reply, reply);
    if (['lifecycle', 'route', 'operation'].includes(boundary)) assert.equal(f.host.operation, operation);
    else assert.equal(f.host.busy, false);
  });
}
add('malformed fulfilled text uses same repeat-confirmation policy as timeout', async () => {
  const f = dialogFixture(); await ambiguousFirst(f, true); assert.equal(f.host.scrolls, 0);
  f.controller.handleSendMessage(f.host.draft, f.host); await sdk.settleWrites(); assert.equal(f.dialogs.length, 1); assert.equal(f.host.gateway.requests.length, 1);
  f.dialogs[0].resolve({ index: 0 }); await sdk.settleWrites(); assert.equal(f.host.busy, false);
});
let completed = false;
async function mainRun() {
  const receipts = []; let passed = 0, failed = 0, assertionFailures = 0;
  for (const test of tests) {
    try { await test.run(); passed++; receipts.push({ name: test.name, scope: test.scope, passed: true }); }
    catch (error) { failed++; const assertion = error instanceof assert.AssertionError; if (assertion) assertionFailures++;
      receipts.push({ name: test.name, scope: test.scope, passed: false, assertion, error: String(error), stack: error.stack }); console.error('FAIL', test.name, String(error)); }
  }
  assert.ok(!mutation || mutationCount > 0, 'Mutation must engage actual code');
  const result = { passed, failed, assertionFailures, nativeCount, hostCount: tests.length - nativeCount, baseline, mutation, mutationCount, hashes, receipts };
  if (output) fs.writeFileSync(path.resolve(output), JSON.stringify(result, null, 2));
  console.log(JSON.stringify({ passed, failed, assertionFailures, nativeCount, hostCount: tests.length - nativeCount, baseline, mutation, mutationCount }));
  completed = true;
  process.exitCode = expectRed ? (failed > 0 && failed === assertionFailures ? 0 : 1) : (failed ? 1 : 0);
}
mainRun().catch(error => { completed = true; console.error('HARNESS_ERROR', error); process.exitCode = 2; });
process.on('beforeExit', () => { if (!completed) { console.error('Incomplete write error witness'); process.exitCode = 2; } });

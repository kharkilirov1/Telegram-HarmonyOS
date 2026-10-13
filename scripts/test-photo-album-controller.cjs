// Actual coordinator and Context setters; gateway/files/native dialogs are port mocks.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { stripTypeScriptTypes } = require('node:module');
const root = path.resolve(__dirname, '../entry/src/main/ets');
function load(file, names, globals = {}) {
  const source = fs.readFileSync(path.join(root, file), 'utf8')
    .replace(/^import[\s\S]*?from\s+['"][^'"]+['"];?\s*$/gm, '')
    .replace(/^export /gm, '');
  const code = stripTypeScriptTypes(source, { mode: 'transform', disableExperimentalWarning: true });
  return vm.runInNewContext(`${code}\n({${names.join(',')}})`, globals, { filename: file });
}
const errors = load('core/model/AppError.ets', ['AppError', 'AppErrorKind', 'isSilentTdlibError', 'isWriteOutcomeUnknown', 'asWriteRequestError'], { Error });
const { SendMediaAlbumError } = load('domain/usecases/sendMediaAlbum.ets', ['SendMediaAlbumError'],
  { ...errors });
const { ChatPhotoAlbumController } = load('ui/pages/chat/ChatPhotoAlbumController.ets', ['ChatPhotoAlbumController'], {
  ...errors,
  SendMediaAlbumError, SendMediaAlbumParams: class {}, SendMediaMessageParams: class {}, localized: (_id, fallback) => fallback,
  $r: id => ({ id }), TgUiTokens: { COLOR_TEXT_TITLE_RESOURCE_NAME: 'text_primary', COLOR_ICON_PRIMARY_RESOURCE_NAME: 'telegram_blue' }
});
const { ChatScreenContext } = load('ui/pages/chat/ChatScreenContext.ets', ['ChatScreenContext']);
// Only the native boundary is a fixture. The extracted allocator/copy/ownership
// implementation is loaded from its actual production owner.
const namedFixtureFiles = new Set();
const { ChatAttachmentFilePreparer } = load('ui/pages/chat/ChatAttachmentFilePreparer.ets', ['ChatAttachmentFilePreparer'], {
  Date: { now: () => 42 }, hilog: { warn() {} },
  fileIo: { OpenMode: { READ_ONLY: 0 }, accessSync: path => namedFixtureFiles.has(path),
    mkdirSync: path => namedFixtureFiles.add(path), openSync: () => ({ fd: 1 }),
    copyFileSync: (_fd, path) => namedFixtureFiles.add(path), closeSync() {}, unlinkSync: path => namedFixtureFiles.delete(path) }
});
const { ChatComposerController } = load('ui/pages/chat/ChatComposerController.ets', ['ChatComposerController'], {
  ...errors, ChatTextSendController: load('ui/pages/chat/ChatTextSendController.ets', ['ChatTextSendController'], { ...errors }).ChatTextSendController,
  ChatSequentialMediaController: load('ui/pages/chat/ChatSequentialMediaController.ets', ['ChatSequentialMediaController'], { ...errors }).ChatSequentialMediaController,
  ChatPhotoAlbumController, ChatAttachmentFilePreparer, Date: { now: () => 42 }, SendMediaMessageParams: class {}
});
const tick = () => new Promise(resolve => setImmediate(resolve));
async function settle() { for (let i = 0; i < 8; i++) await tick(); }
function deferred() { let resolve, reject; const promise = new Promise((a, b) => { resolve = a; reject = b; }); return { promise, resolve, reject }; }
function fixture() {
  const calls = [], copies = [], discarded = [], dialogs = [], toasts = [];
  const state = { chat: -100123, lifecycle: 1, operation: 0, revision: 1, uris: ['uri/a', 'uri/b'],
    kind: 'photo', text: 'caption', reply: '91', active: true, permitted: true, edit: false, forward: false,
    busy: false, scroll: 0, clears: 0 };
  const send = deferred();
  const owner = { getPhotoAlbumUseCase: () => ({ execute: params => { calls.push(params); return send.promise; } }) };
  const responses = [];
  const host = {
    canSendNewMessages: () => state.permitted,
    getActiveChatId: () => state.chat, getLifecycleToken: () => state.lifecycle,
    getSendMediaUseCase: () => state.permitted ? owner : undefined,
    isSendingMessage: () => state.busy,
    setSendingMessage: value => { state.busy = value; state.operation++; },
    getSendOperationToken: () => state.operation, getComposerInputRevision: () => state.revision,
    hasActiveChatState: () => state.active, isEditModeActive: () => state.edit, isForwardModeActive: () => state.forward,
    getDraftText: () => state.text, setDraftText: value => { state.text = value; state.revision++; },
    setDraftSelection: () => {}, setCustomEmojiEntities: () => {}, setEmojiPanelVisible: () => {},
    getReplyToMessageId: () => state.reply, clearReplyMode: () => { state.reply = '0'; state.revision++; },
    getPendingAttachmentUris: () => state.uris, getPendingAttachmentKind: () => state.kind,
    clearPendingAttachmentState: () => { state.uris = []; state.kind = ''; state.clears++; state.revision++; },
    isNearBottom: () => true, scrollToBottomSoon: () => state.scroll++,
    getChatUIContext: () => ({
      getHostContext: () => ({ resourceManager: { getColorByNameSync: name => name === 'text_primary' ? 0xffffffff : 0xff3390ec } }),
      getPromptAction: () => ({
      showDialog: options => { dialogs.push(options); return responses.shift() ?? Promise.resolve({ index: 0 }); },
      showToast: options => { toasts.push(options); }
    }) })
  };
  const controller = new ChatPhotoAlbumController();
  const prepare = uri => { copies.push(uri); return Promise.resolve(`/owned/${uri}`); };
  const start = (prepareOverride = prepare) => controller.handleSend('caption', host, prepareOverride, p => discarded.push(p));
  return { state, calls, copies, discarded, dialogs, toasts, responses, send, owner, host, controller, start };
}
const cases = [];
function test(name, run) { cases.push({ name, run }); }
test('actual composer routes multiple photos to album coordinator', async () => {
  const f = fixture(), composer = new ChatComposerController();
  composer.attachmentFiles.prepare = (_kind, uri) => Promise.resolve(`/owned/${uri}`);
  composer.attachmentFiles.discard = p => f.discarded.push(p);
  composer.handleSendMessage('caption', f.host); await settle(); assert.equal(f.calls.length, 1);
  assert.equal(f.calls[0].localPaths.length, 2); f.send.resolve(); await settle(); assert.equal(f.state.clears, 1);
});
test('same-clock/same-name preparation names remain unique across composer instances', async () => {
  const a = new ChatComposerController(), b = new ChatComposerController();
  const context = { filesDir: '/fixture' };
  const names = [await a.attachmentFiles.prepare('photo', 'uri/a/image.jpg', context),
    await a.attachmentFiles.prepare('photo', 'uri/b/image.jpg', context), await b.attachmentFiles.prepare('photo', 'uri/c/image.jpg', context)];
  assert.equal(new Set(names).size, 3); assert.ok(names.every(n => n.endsWith('.jpg')));
});
test('two selected photos prepare in order before exactly one album mutation', async () => {
  const f = fixture(); const first = deferred(); f.start(uri => { f.copies.push(uri); return uri === 'uri/a' ? first.promise : Promise.resolve('/b'); });
  await settle(); assert.equal(f.calls.length, 0); assert.deepEqual(f.copies, ['uri/a']);
  first.resolve('/a'); await settle(); assert.equal(f.calls.length, 1);
  assert.deepEqual(Array.from(f.calls[0].localPaths), ['/a', '/b']); assert.equal(f.calls[0].caption, 'caption');
  assert.equal(f.calls[0].replyToMessageId, '91'); assert.equal(f.calls[0].chatId, -100123);
  f.send.resolve(); await settle(); assert.equal(f.state.clears, 1); assert.equal(f.state.text, '');
  assert.equal(f.state.reply, '0'); assert.equal(f.state.busy, false); assert.equal(f.state.scroll, 1);
  assert.equal(f.discarded.length, 0, 'accepted files remain available for TDLib upload');
});
test('ten photos form one ordered mutation', async () => {
  const f = fixture(); f.state.uris = Array.from({ length: 10 }, (_, i) => `uri/${i}`); f.start(); await settle();
  assert.equal(f.calls.length, 1); assert.equal(f.calls[0].localPaths.length, 10);
  assert.deepEqual(Array.from(f.calls[0].localPaths), f.state.uris.map(uri => `/owned/${uri}`)); f.send.resolve(); await settle();
});
for (const [name, change] of [
  ['permission revoked', f => { f.state.permitted = false; }],
  ['account/route invalidated', f => { f.state.lifecycle++; f.state.active = false; f.state.busy = false; }],
  ['same-chat roundtrip/new operation', f => { f.state.lifecycle += 2; f.state.operation += 2; f.state.busy = true; }],
  ['draft edit', f => { f.state.text = 'new caption'; f.state.revision++; }],
  ['draft ABA restored', f => { f.state.revision += 2; }],
  ['selection replacement', f => { f.state.uris = ['uri/c', 'uri/d']; f.state.revision++; }],
  ['reply changed', f => { f.state.reply = '92'; f.state.revision++; }],
  ['edit mode entered', f => { f.state.edit = true; }],
  ['forward mode entered', f => { f.state.forward = true; }]
]) {
  test(`copy await: ${name} prevents mutation and discards this unsubmitted copy`, async () => {
    const f = fixture(), copy = deferred(); f.start(() => copy.promise); await settle(); change(f);
    const busy = f.state.busy; copy.resolve('/owned/first'); await settle();
    assert.equal(f.calls.length, 0); assert.deepEqual(f.discarded, ['/owned/first']);
    assert.equal(f.state.clears, 0); if (name.includes('roundtrip')) assert.equal(f.state.busy, busy);
    else if (name !== 'account/route invalidated') assert.equal(f.state.busy, false);
  });
}
test('second copy failure retains input and discards first copy without a backend request', async () => {
  const f = fixture(); f.start(uri => uri === 'uri/a' ? Promise.resolve('/owned/first') : Promise.reject(new Error('copy failed')));
  await settle(); assert.equal(f.calls.length, 0); assert.deepEqual(f.discarded, ['/owned/first']);
  assert.equal(f.state.text, 'caption'); assert.equal(f.state.uris.length, 2); assert.equal(f.state.busy, false);
  assert.equal(f.toasts.length, 1); assert.equal(f.dialogs.length, 0);
});
test('accepted response preserves newly edited input, including ABA revision', async () => {
  const f = fixture(); f.start(); await settle(); f.state.revision += 2; f.send.resolve(); await settle();
  assert.equal(f.state.clears, 0); assert.equal(f.state.text, 'caption'); assert.equal(f.state.busy, false);
  f.start(); await settle(); assert.equal(f.calls.length, 1); assert.equal(f.dialogs.length, 1);
  assert.match(f.dialogs[0].message, /duplicates/);
});
test('accepted selection retained during permission revoke requires confirmation after restore', async () => {
  const f = fixture(); f.start(); await settle(); f.state.permitted = false; f.send.resolve(); await settle();
  assert.equal(f.state.clears, 0); assert.equal(f.state.busy, false);
  f.state.permitted = true; f.start(); await settle(); assert.equal(f.calls.length, 1);
  assert.equal(f.dialogs.length, 1); assert.match(f.dialogs[0].message, /duplicates/);
});
test('old completion cannot release a new operation', async () => {
  const f = fixture(); f.start(); await settle(); f.state.operation += 2; f.state.busy = true;
  f.send.resolve(); await settle(); assert.equal(f.state.busy, true); assert.equal(f.state.clears, 0);
});
test('unknown outcome retains input/files, second ordinary tap requires confirmation', async () => {
  const f = fixture(); f.start(); await settle(); f.send.reject(new SendMediaAlbumError(true, 'timeout')); await settle();
  assert.equal(f.calls.length, 1); assert.equal(f.dialogs.length, 1); assert.equal(f.state.clears, 0);
  assert.equal(f.discarded.length, 0); assert.equal(f.state.busy, false);
  const confirm = deferred(); f.responses.push(confirm.promise); f.start(); await settle();
  assert.equal(f.dialogs.length, 2); assert.match(f.dialogs[1].message, /duplicates/);
  assert.equal(f.calls.length, 1); f.start(); await settle(); assert.equal(f.dialogs.length, 2, 'one busy dialog owner');
  confirm.resolve({ index: 0 }); await settle(); assert.equal(f.calls.length, 1); assert.equal(f.state.busy, false);
});
test('explicit resend confirmation allows one additional attempt', async () => {
  const f = fixture(); f.start(); await settle(); f.send.reject(new Error('lost reply')); await settle();
  f.responses.push(Promise.resolve({ index: 1 })); f.start(); await settle(); assert.equal(f.calls.length, 2);
});
test('permission change during confirmation prevents resend', async () => {
  const f = fixture(); f.start(); await settle(); f.send.reject(new SendMediaAlbumError(true, 'unknown')); await settle();
  const confirm = deferred(); f.responses.push(confirm.promise); f.start(); await settle(); f.state.permitted = false;
  confirm.resolve({ index: 1 }); await settle(); assert.equal(f.calls.length, 1); assert.equal(f.state.busy, false);
});
test('pre-dispatch validation error has ordinary retry, no unknown confirmation', async () => {
  const f = fixture(); f.start(); await settle(); f.send.reject(new SendMediaAlbumError(false, 'invalid caption')); await settle();
  assert.equal(f.dialogs.length, 0); assert.equal(f.toasts.length, 1); assert.equal(f.discarded.length, 2);
  assert.equal(f.state.clears, 0); f.start(); await settle(); assert.equal(f.calls.length, 2);
});
test('native feedback failures still release busy ownership', async () => {
  const f = fixture(); f.host.getChatUIContext = () => ({ getPromptAction: () => ({ showDialog: () => Promise.reject(new Error('UI gone')), showToast: () => { throw new Error('UI gone'); } }) });
  f.start(); await settle(); f.send.reject(new Error('unknown')); await settle(); assert.equal(f.state.busy, false);
  f.start(); await settle(); assert.equal(f.calls.length, 1); assert.equal(f.state.busy, false);
});
test('actual Context setters increment revision across ABA and entities/reply/selection changes', () => {
  const context = Object.create(ChatScreenContext.prototype);
  context.view = { composer: { composerDraftText: 'a', pendingAttachmentKind: 'photo', pendingAttachmentUris: ['a','b'], replyToMessageId: '1' } };
  context.composerInputRevision = 0;
  context.composerDraftText = 'b'; context.composerDraftText = 'a'; assert.equal(context.composerInputRevision, 2);
  context.customEmojiDraftEntities = []; context.replyToMessageId = '2'; context.pendingAttachmentUris = ['a','b'];
  assert.equal(context.composerInputRevision, 5);
});
async function main() {
  let failed = 0;
  for (const item of cases) { try { await item.run(); console.log(`PASS ${item.name}`); } catch (e) { failed++; console.error(`FAIL ${item.name}`, e); } }
  console.log(JSON.stringify({ cases: cases.length, passed: cases.length - failed, failed }));
  if (failed) process.exitCode = 1;
}
main().catch(e => { console.error(e); process.exitCode = 1; });

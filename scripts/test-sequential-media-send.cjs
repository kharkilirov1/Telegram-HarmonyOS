#!/usr/bin/env node
// Run the actual SDK callback bodies on actual source. Native file preparation,
// presentation and transport are explicit seams; no TDLib/account/network action.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '..');
const option = name => { const index = process.argv.indexOf(name); return index < 0 ? undefined : process.argv[index + 1]; };
const baseline = option('--baseline-dir'), output = option('--json'), mutation = option('--mutation');
const expectRed = process.argv.includes('--expect-red');
assert.ok(!expectRed || baseline || mutation); assert.ok(!(baseline && mutation));
const main = 'entry/src/main/ets/', sdkFile = 'entry/src/ohosTest/ets/test/SequentialMediaSend.test.ets';
const hashes = {}, logs = [], tests = []; let mutationCount = 0;
const pickerRequests = [];
function pickRequest(kind, options) {
  const value = { kind, options };
  pickerRequests.push(value); return new Promise((resolve, reject) => { value.resolve = resolve; value.reject = reject; });
}
const picker = { DocumentSelectOptions: class {}, DocumentViewPicker: class { select(options) { return pickRequest('document', options); } } };
const cameraPicker = { PickerMediaType: { PHOTO: 'photo', VIDEO: 'video' }, pick(_context, types) { return pickRequest('camera', types); } };
const camera = { CameraPosition: { CAMERA_POSITION_BACK: 'back' } };
const photoAccessHelper = { PhotoViewMIMETypes: { IMAGE_TYPE: 'image/*', VIDEO_TYPE: 'video/*' }, PhotoViewPicker: class { select(options) { return pickRequest('photo', options); } } };
const sequentialOwner = main + 'ui/pages/chat/ChatSequentialMediaController.ets';
const mutants = {
  'accepted-prefix-not-retired': [[sequentialOwner, 'replacePendingSelection(remaining);', 'replacePendingSelection(attempt.uris);']],
  'original-caption-not-consumed': [[sequentialOwner, "host.setDraftText('');", 'host.setDraftText(attempt.draftText);']],
  'owned-revision-not-rebased': [[sequentialOwner,
    'attempt.inputRevision = host.getComposerInputRevision();\n        if (!this.canSubmit(host, attempt)) return;',
    'if (!this.canSubmit(host, attempt)) return;']],
  'uncertain-confirmation-skipped': [[sequentialOwner, 'if (this.hasConsumedSelection(attempt))', 'if (false && this.hasConsumedSelection(attempt))']],
  'Cancel-treated-as-confirmation': [[sequentialOwner, 'return result.index === 1;', 'return true;']],
  'input-revision-unguarded': [[sequentialOwner, 'host.getComposerInputRevision() === attempt.inputRevision', 'true']],
  'caret-unguarded': [[sequentialOwner,
    'host.getDraftSelectionStart() === attempt.selectionStart && host.getDraftSelectionEnd() === attempt.selectionEnd', 'true']],
  'operation-unguarded': [[sequentialOwner, 'host.getSendOperationToken() === attempt.operation &&', 'true &&']],
  'known-rejection-erases-older-taint': [[sequentialOwner,
    'if (count <= 1) this.consumedUriCounts.delete(mark.uri);\n      else this.consumedUriCounts.set(mark.uri, count - 1);',
    'this.consumedUriCounts.delete(mark.uri);']],
  'submitted-copies-discarded': [[sequentialOwner,
    "if (!submitted && typeof path === 'string' && path.length > 0)", "if (typeof path === 'string' && path.length > 0)"]],
  'silent406-feedback-published': [[sequentialOwner, ' || isSilentTdlibError(error)', '']],
  'forward-ABA-revision-not-advanced': [[main + 'ui/pages/chat/ChatScreenContext.ets',
    'if (this.view.composer.isForwardingMessages !== value) this.composerInputRevision++;', '']],
  'camera-picker-closure-unguarded': [[main + 'ui/pages/chat/ChatComposerController.ets',
    "      host.getSendMediaUseCase('photo') === photoUseCase && host.getSendMediaUseCase('video') === videoUseCase &&\n      host.getComposerInputRevision() === inputRevision && !host.isSendingMessage() &&\n      !host.isEditModeActive() && !host.isForwardModeActive();", '      true;']]
};
assert.ok(!mutation || mutants[mutation], 'Supported activated behavioral mutation required');
const hilog = Object.fromEntries(['info', 'warn', 'debug', 'error'].map(level => [level, (...args) => logs.push({ level, args })]));
const platform = { hilog, localized: (_id, fallback) => fallback, $r: id => ({ id }), TgUiTokens: {} };
function exists(relative) { return fs.existsSync(path.join(baseline && relative.startsWith(main) ? path.resolve(baseline) : root, relative)); }
function read(relative) {
  const filename = path.join(baseline && relative.startsWith(main) ? path.resolve(baseline) : root, relative);
  let value = fs.readFileSync(filename, 'utf8'); hashes[filename] = createHash('sha256').update(value).digest('hex');
  value = value.replaceAll('\r\n', '\n');
  if (mutation) for (const [target, before, after] of mutants[mutation]) {
    if (target !== relative) continue;
    assert.ok(value.includes(before), 'Mutation anchor must engage: ' + target);
    value = value.replace(before, after); mutationCount++;
  }
  return value;
}
function load(relative, deps = {}) {
  const source = read(relative), names = [...source.matchAll(/^(?:export\s+(?:default\s+)?)?(?:async\s+)?(?:class|function|const|enum)\s+(\w+)/gm)].map(match => match[1]);
  const filtered = Object.fromEntries(Object.entries(deps).filter(([name]) => !names.includes(name)));
  const js = stripTypeScriptTypes(source.replace(/^import[\s\S]*?;\s*/gm, '')
    .replace(/@ObservedV2\s*/g, '').replace(/@Trace\s*/g, '')
    .replace(/^export\s+\{[\s\S]*?\}\s*(?:from\s*'[^']*')?;?\s*/gm, '')
    .replace(/^export\s+default\s+\w+;?\s*$/gm, '').replace(/^export\s+(?:default\s+)?/gm, ''),
    { mode: 'transform', sourceUrl: relative });
  return new Function(...Object.keys(filtered), js + '\nreturn {' + names.join(',') + '};')(...Object.values(filtered));
}
const commands = load(main + 'core/model/AppCommand.ets'), app = load(main + 'core/model/AppError.ets');
const td = load(main + 'models/td/common/index.ets');
const accessors = load(main + 'core/utils/tdAccessors.ets', td);
const dependencies = { ...commands, ...app, ...td, ...accessors, ...platform };
const text = load(main + 'domain/usecases/sendMessage.ets', dependencies);
const album = load(main + 'domain/usecases/sendMediaAlbum.ets', dependencies);
const media = load(main + 'domain/usecases/sendMediaMessage.ets', { ...dependencies, ...album });
const forward = load(main + 'domain/usecases/forwardMessages.ets', dependencies);
const photo = load(main + 'ui/pages/chat/ChatPhotoAlbumController.ets', { ...dependencies, ...media, ...album });
const preparer = load(main + 'ui/pages/chat/ChatAttachmentFilePreparer.ets', {
  ...platform, fileIo: { unlinkSync() {}, accessSync: () => true }
});
const emoji = load(main + 'ui/tg_ui/utils/TgCustomEmojiDraftPolicy.ets', commands);
const textController = load(main + 'ui/pages/chat/ChatTextSendController.ets', { ...dependencies, ...text, ...emoji });
const sequentialFile = main + 'ui/pages/chat/ChatSequentialMediaController.ets';
// No candidate-source fallback: the baseline Composer has no new dependency.
const sequential = exists(sequentialFile) ? load(sequentialFile, { ...dependencies, ...media, ...emoji }) : {};
const composer = load(main + 'ui/pages/chat/ChatComposerController.ets', { ...dependencies, ...text, ...media, ...photo, ...preparer, ...emoji, ...textController, ...sequential, picker, cameraPicker, camera, photoAccessHelper });
const actions = load(main + 'ui/pages/chat/ChatMessageActionsController.ets', { ...dependencies, ...text, ...forward });
const barSource = read(main + 'ui/tg_ui/atoms/TgChatTopBar.ets');
const barEnums = ['TgChatTopBarSubtitleMode', 'TgChatTopBarTrailingAction'];
const enumCode = barEnums.map(name => {
  const match = barSource.match(new RegExp('export enum ' + name + ' \\{[\\s\\S]*?\\}'));
  assert.ok(match, 'Actual native UI enum must exist: ' + name); return match[0].replace('export ', '');
}).join('\n');
const nativeUiEnums = new Function(stripTypeScriptTypes(enumCode, { mode: 'transform' }) + '\nreturn {' + barEnums.join(',') + '};')();
const slices = {};
for (const name of ['ChatChromeState', 'ChatComposerState', 'ChatPanelsState', 'ChatTimelineViewState', 'ChatMediaViewState', 'ChatPinnedSearchState']) {
  Object.assign(slices, load(main + 'ui/pages/chat/' + name + '.ets', { ...platform, ...nativeUiEnums, NavPathStack: class {} }));
}
const view = load(main + 'ui/pages/chat/ChatScreenViewState.ets', slices);
const context = load(main + 'ui/pages/chat/ChatScreenContext.ets', {
  ...composer, ...actions, ...view, ChatTimelineDataSource: class {}, Scroller: class {},
  ReplyHydrationCoordinator: class {}, ChatMediaDownloadController: class {}, PendingMediaOpenIntent: class {},
  ChatVoiceRecordingController: class {}, ChatForwardSourceController: class {}, ChatSearchController: class {}, ChatStickerSearchController: class {},
  ChatSlowmodeController: class {}
});
const adapters = load(main + 'ui/pages/chat/ChatComposerHostAdapters.ets');
const actionAdapters = load(main + 'ui/pages/chat/ChatMessageActionHostAdapters.ets', actions);
const popup = load(main + 'ui/pages/chat/ChatMessagePopupCoordinator.ets', actions);
const hypium = { describe: (_name, body) => body(), it: (name, _flags, run) => tests.push({ name, run, scope: 'actual unchanged SDK callback' }),
  expect: value => ({ assertEqual: other => assert.strictEqual(value, other), assertTrue: () => assert.strictEqual(value, true), assertFalse: () => assert.strictEqual(value, false) }) };
const write = load('entry/src/ohosTest/ets/test/WritePathErrors.test.ets', { ...dependencies, ...text, ...media, ...album, ...forward, ...composer, ...actions, ...hypium });
const sdk = load(sdkFile, { ...dependencies, ...text, ...media, ...composer, ...write, ...context, ...view, ...hypium });
sdk.sequentialMediaSendTest();
const nativeCount = tests.length;
function dialogFixture(kind = 'document', uris = ['file:///a', 'file:///b']) {
  const host = sdk.createSequentialHost(kind, uris), controller = new sdk.SequentialMediaComposer(), dialogs = [], toasts = [];
  host.getChatUIContext = () => ({ getHostContext: () => ({ resourceManager: { getColorByNameSync: () => 0xff0088cc } }),
    getPromptAction: () => ({ showToast: args => toasts.push(args), showDialog: args => new Promise((resolve, reject) => dialogs.push({ args, resolve, reject })) }) });
  return { host, controller, dialogs, toasts };
}
const add = (name, run, scope = 'host actual Composer/picker integration') => tests.push({ name, run, scope });
function changePickerOwner(host, boundary) {
  if (boundary === 'busy') host.setSendingMessage(true);
  else sdk.changeSequentialOwner(host, boundary);
}
for (const kind of ['document', 'camera']) {
  const open = fixture => fixture.controller.handleAttachmentMenuItemPress(kind === 'document' ? 2 : 1, fixture.host);
  for (const boundary of ['busy', 'edit', 'forward', 'permission']) add(kind + ' picker never opens for prohibited initial owner ' + boundary, async () => {
    const f = dialogFixture(), before = pickerRequests.length; changePickerOwner(f.host, boundary);
    open(f); await write.settleWrites(); assert.equal(pickerRequests.length, before, 'No native picker construction/request for prohibited owner');
  });
  for (const outcome of ['result', 'error']) for (const boundary of ['draft', 'draft-ABA', 'reply', 'entities', 'pending-cancel', 'selection-replace', 'busy', 'permission', 'account', 'inactive', 'edit', 'forward', 'navigation', 'lifecycle']) {
    add(kind + ' late picker ' + outcome + ' preserves changed owner ' + boundary, async () => {
      const f = dialogFixture(), before = pickerRequests.length; open(f); await write.settleWrites();
      assert.equal(pickerRequests.length, before + 1); const request = pickerRequests.at(-1);
      changePickerOwner(f.host, boundary);
      const snapshot = { draft: f.host.draft, reply: f.host.reply, kind: f.host.kind, uris: f.host.attachments.join('|'), revision: f.host.revision };
      const feedback = f.toasts.length, logged = logs.length;
      if (outcome === 'error') request.reject(new Error('STALE_PICKER_SECRET'));
      else if (kind === 'document') request.resolve(['file:///picked-document']);
      else request.resolve({ resultCode: 0, resultUri: 'file:///picked-video', mediaType: cameraPicker.PickerMediaType.VIDEO });
      await write.settleWrites();
      assert.deepEqual({ draft: f.host.draft, reply: f.host.reply, kind: f.host.kind, uris: f.host.attachments.join('|'), revision: f.host.revision }, snapshot);
      assert.equal(f.toasts.length, feedback, 'Stale picker cannot present owner feedback');
      assert.ok(!JSON.stringify(logs.slice(logged)).includes('STALE_PICKER_SECRET'), 'Stale picker error detail is not processed/logged');
    });
  }
  add(kind + ' latest picker result is accepted while preceding generation is discarded', async () => {
    const f = dialogFixture(), before = pickerRequests.length; open(f); await write.settleWrites(); open(f); await write.settleWrites();
    assert.equal(pickerRequests.length, before + 2); const first = pickerRequests[before], second = pickerRequests[before + 1];
    const result = uri => kind === 'document' ? [uri] : { resultCode: 0, resultUri: uri, mediaType: cameraPicker.PickerMediaType.VIDEO };
    first.resolve(result('file:///stale')); await write.settleWrites(); assert.equal(f.host.attachments.join('|'), 'file:///a|file:///b');
    second.resolve(result('file:///current')); await write.settleWrites(); assert.equal(f.host.attachments.join('|'), 'file:///current');
    assert.equal(f.host.kind, kind === 'document' ? 'document' : 'video');
  });
}
async function rejectFirstUnknown(f, value = new Error('Synthetic post-dispatch timeout')) {
  f.controller.handleSendMessage(f.host.draft, f.host); await write.settleWrites(); assert.equal(f.host.gateway.requests.length, 1);
  f.host.gateway.requests[0].reject(value); await write.settleWrites(); assert.equal(f.host.busy, false);
}
for (const kind of ['document', 'video']) {
  add(kind + ' native confirmation boundary cancels with zero preparation then confirms only the uncertain tail', async () => {
    const f = dialogFixture(kind); f.controller.handleSendMessage(f.host.draft, f.host); await write.settleWrites();
    f.host.gateway.requests[0].resolve(sdk.acceptedMedia()); await write.settleWrites();
    assert.equal(f.host.attachments.join('|'), 'file:///b'); assert.equal(f.host.gateway.requests.length, 2);
    f.host.gateway.requests[1].reject(new Error('Synthetic post-dispatch timeout')); await write.settleWrites();
    const snapshot = { uris: f.host.attachments.join('|'), draft: f.host.draft, reply: f.host.reply, entities: f.host.entities.length, start: f.host.selectionStart, end: f.host.selectionEnd };
    f.controller.handleSendMessage(f.host.draft, f.host); await write.settleWrites(); assert.equal(f.dialogs.length, 1);
    assert.equal(f.host.gateway.requests.length, 2); assert.equal(f.controller.preparations.length, 2); assert.equal(f.host.busy, true);
    f.controller.handleSendMessage(f.host.draft, f.host); await write.settleWrites(); assert.equal(f.dialogs.length, 1);
    f.dialogs[0].resolve({ index: 0 }); await write.settleWrites(); assert.equal(f.host.busy, false);
    assert.equal(f.host.gateway.requests.length, 2); assert.equal(f.controller.preparations.length, 2);
    assert.deepEqual({ uris: f.host.attachments.join('|'), draft: f.host.draft, reply: f.host.reply, entities: f.host.entities.length, start: f.host.selectionStart, end: f.host.selectionEnd }, snapshot);
    f.controller.handleSendMessage(f.host.draft, f.host); await write.settleWrites(); assert.equal(f.dialogs.length, 2);
    f.dialogs[1].resolve({ index: 1 }); await write.settleWrites(); assert.equal(f.host.gateway.requests.length, 3);
    assert.deepEqual(f.controller.preparations.map(value => value.uri), ['file:///a', 'file:///b', 'file:///b']);
    assert.equal(sdk.capturedMedia(f.host, 2).payload.caption, ''); assert.equal(sdk.capturedMedia(f.host, 2).payload.replyToMessageId, '0');
    f.host.gateway.requests[2].resolve(sdk.acceptedMedia(903)); await write.settleWrites();
    assert.equal(f.host.busy, false); assert.equal(f.host.attachments.length, 0); assert.equal(f.host.draft, ''); assert.equal(f.host.reply, '0');
    assert.equal(f.controller.discarded.length, 0, 'Accepted or uncertain submitted copies are retained');
  }, 'host actual Composer/native confirmation boundary');
}
for (const boundary of ['draft', 'draft-ABA', 'reply', 'entities', 'selection', 'pending-cancel', 'selection-replace', 'kind', 'permission', 'account', 'inactive', 'edit', 'forward', 'navigation', 'lifecycle', 'operation']) {
  add('confirmed dialog cannot dispatch or clear changed composer owner ' + boundary, async () => {
    const f = dialogFixture('document', ['file:///a']); await rejectFirstUnknown(f);
    f.controller.handleSendMessage(f.host.draft, f.host); await write.settleWrites(); assert.equal(f.dialogs.length, 1);
    sdk.changeSequentialOwner(f.host, boundary);
    const snapshot = { uris: f.host.attachments.join('|'), kind: f.host.kind, draft: f.host.draft, reply: f.host.reply, emoji: f.host.entities[0].customEmojiId,
      start: f.host.selectionStart, end: f.host.selectionEnd, operation: f.host.operation };
    f.dialogs[0].resolve({ index: 1 }); await write.settleWrites();
    assert.equal(f.host.gateway.requests.length, 1); assert.equal(f.controller.preparations.length, 1);
    assert.deepEqual({ uris: f.host.attachments.join('|'), kind: f.host.kind, draft: f.host.draft, reply: f.host.reply, emoji: f.host.entities[0].customEmojiId,
      start: f.host.selectionStart, end: f.host.selectionEnd, operation: f.host.operation },
      { ...snapshot, operation: ['operation', 'navigation', 'lifecycle'].includes(boundary) ? snapshot.operation : snapshot.operation + 1 });
    assert.equal(f.host.busy, ['operation', 'navigation', 'lifecycle'].includes(boundary));
  }, 'host actual Composer/native confirmation boundary');
}
for (const result of [{ index: -1 }, { index: 2 }, {}, null, 'reject']) add('duplicate confirmation rejects invalid or unavailable presentation ' + JSON.stringify(result), async () => {
  const f = dialogFixture('document', ['file:///a']); await rejectFirstUnknown(f);
  f.controller.handleSendMessage(f.host.draft, f.host); await write.settleWrites(); assert.equal(f.dialogs.length, 1);
  if (result === 'reject') f.dialogs[0].reject(new Error('Synthetic native dialog canceled')); else f.dialogs[0].resolve(result);
  await write.settleWrites(); assert.equal(f.host.gateway.requests.length, 1); assert.equal(f.controller.preparations.length, 1); assert.equal(f.host.busy, false);
  assert.equal(f.host.attachments.join('|'), 'file:///a'); assert.equal(f.host.draft, '\uD83D\uDE00 caption'); assert.equal(f.host.reply, '55');
}, 'host actual Composer/native confirmation boundary');
add('explicitly rejected later retry cannot erase an older unknown URI consumption mark', async () => {
  const f = dialogFixture('document', ['file:///a']); await rejectFirstUnknown(f);
  f.controller.handleSendMessage(f.host.draft, f.host); await write.settleWrites(); assert.equal(f.dialogs.length, 1);
  f.dialogs[0].resolve({ index: 1 }); await write.settleWrites(); assert.equal(f.host.gateway.requests.length, 2);
  f.host.gateway.requests[1].reject(app.classifyTdlibError(400, 'CHAT_WRITE_FORBIDDEN')); await write.settleWrites();
  assert.equal(f.controller.discarded.join('|'), f.controller.preparations[1].path);
  f.controller.handleSendMessage(f.host.draft, f.host); await write.settleWrites(); assert.equal(f.dialogs.length, 2);
  assert.equal(f.host.gateway.requests.length, 2); f.dialogs[1].resolve({ index: 0 }); await write.settleWrites(); assert.equal(f.host.busy, false);
}, 'host actual Composer/native confirmation boundary');
for (const change of ['subset', 'reorder', 'kind']) add('unknown URI mark survives replacement selection ' + change, async () => {
  const f = dialogFixture('document', ['file:///a', 'file:///b']); await rejectFirstUnknown(f);
  const uris = change === 'subset' ? ['file:///a'] : change === 'reorder' ? ['file:///b', 'file:///a'] : ['file:///a'];
  f.host.setPendingAttachmentState(change === 'kind' ? 'video' : 'document', 'new', 'new', uris);
  f.controller.handleSendMessage(f.host.draft, f.host); await write.settleWrites(); assert.equal(f.dialogs.length, 1);
  assert.equal(f.host.gateway.requests.length, 1); assert.equal(f.controller.preparations.length, 1);
  f.dialogs[0].resolve({ index: 0 }); await write.settleWrites(); assert.equal(f.host.attachments.join('|'), uris.join('|')); assert.equal(f.host.busy, false);
}, 'host actual Composer/native confirmation boundary');
add('canceling an in-flight unknown attachment preserves its taint when the URI is reselected', async () => {
  const f = dialogFixture('document', ['file:///a']); f.controller.handleSendMessage(f.host.draft, f.host); await write.settleWrites();
  f.host.clearPendingAttachmentState(); f.host.setDraftText('new draft');
  f.host.gateway.requests[0].reject(new Error('Synthetic post-cancel timeout')); await write.settleWrites(); assert.equal(f.host.busy, false);
  assert.equal(f.host.draft, 'new draft'); f.host.setPendingAttachmentState('document', 'new', 'new', ['file:///a']);
  f.controller.handleSendMessage(f.host.draft, f.host); await write.settleWrites(); assert.equal(f.dialogs.length, 1); assert.equal(f.host.gateway.requests.length, 1);
  f.dialogs[0].resolve({ index: 0 }); await write.settleWrites(); assert.equal(f.host.draft, 'new draft');
}, 'host actual Composer/native confirmation boundary');
add('actual preparer discards canceled unsubmitted copy while borrowed source and submitted file survive', async () => {
  const files = new Set(['/borrowed/source.bin', '/borrowed/other.bin']), deleted = [], opened = [], closed = [];
  const boundary = { OpenMode: { READ_ONLY: 1 }, accessSync: value => files.has(value), mkdirSync: value => files.add(value),
    openSync: value => { opened.push(value); return { fd: 77 }; }, copyFileSync: (_fd, value) => files.add(value),
    closeSync: value => closed.push(value.fd), unlinkSync: value => { deleted.push(value); files.delete(value); } };
  const actual = load(main + 'ui/pages/chat/ChatAttachmentFilePreparer.ets', { ...platform, fileIo: boundary });
  const preparerOwner = new actual.ChatAttachmentFilePreparer(), f = dialogFixture('document', ['/borrowed/source.bin']);
  f.controller.preparePickedAttachmentLocalPath = (_kind, uri) => preparerOwner.prepare('document', uri, { filesDir: '/fixture/app' });
  f.controller.discardPreparedAttachment = value => preparerOwner.discard(value);
  f.controller.handleSendMessage(f.host.draft, f.host); await write.settleWrites(); assert.equal(f.host.gateway.requests.length, 1);
  const submitted = sdk.capturedMedia(f.host, 0).payload.localPath; assert.ok(files.has(submitted));
  f.host.gateway.requests[0].reject(new Error('Synthetic post-submit timeout')); await write.settleWrites();
  assert.ok(files.has(submitted)); assert.equal(deleted.length, 0, 'Uncertain submitted copy must be retained');
  preparerOwner.discard('/borrowed/source.bin'); preparerOwner.discard('/borrowed/other.bin'); assert.equal(deleted.length, 0);
  const canceled = await preparerOwner.prepare('document', '/borrowed/other.bin', { filesDir: '/fixture/app' });
  preparerOwner.discard(canceled); assert.deepEqual(deleted, [canceled]); assert.ok(files.has(submitted));
  assert.ok(files.has('/borrowed/source.bin')); assert.ok(files.has('/borrowed/other.bin')); assert.deepEqual(opened, ['/borrowed/source.bin', '/borrowed/other.bin']); assert.deepEqual(closed, [77, 77]);
}, 'host actual preparer/Composer/transport ownership integration');
add('bounded URI ledger saturation requires conservative confirmation for a fresh selection', async () => {
  const f = dialogFixture('document', ['file:///taint-0']);
  for (let index = 0; index < 129; index++) {
    f.host.setPendingAttachmentState('document', 'taint', 'taint', ['file:///taint-' + index]);
    f.controller.handleSendMessage(f.host.draft, f.host); await write.settleWrites();
    assert.equal(f.host.gateway.requests.length, index + 1, 'A newly selected URI dispatches once before saturation');
    f.host.gateway.requests[index].reject(new Error('Synthetic unique URI timeout')); await write.settleWrites(); assert.equal(f.host.busy, false);
  }
  f.host.setPendingAttachmentState('document', 'fresh', 'fresh', ['file:///fresh-after-saturation']);
  f.controller.handleSendMessage(f.host.draft, f.host); await write.settleWrites(); assert.equal(f.dialogs.length, 1); assert.equal(f.host.gateway.requests.length, 129);
  f.dialogs[0].resolve({ index: 0 }); await write.settleWrites(); assert.equal(f.host.busy, false);
  assert.equal(f.host.attachments.join('|'), 'file:///fresh-after-saturation');
}, 'host actual bounded consumption ledger integration');
(async () => {
  const failures = []; let passed = 0;
  for (const test of tests) {
    try { await test.run(); passed++; } catch (error) {
      failures.push({ name: test.name, type: error.constructor.name, message: error.message, scope: test.scope });
    }
  }
  if (mutation) assert.ok(mutationCount > 0, 'Mutation must activate in actual executed source');
  const assertionFailures = failures.filter(value => value.type === 'AssertionError').length;
  const receipt = { passed, failed: failures.length, assertionFailures, nativeCount, hostCount: tests.length - nativeCount,
    baseline, mutation, mutationCount, hashes, failures };
  if (output) fs.writeFileSync(path.resolve(output), JSON.stringify(receipt, null, 2) + '\n');
  console.log(JSON.stringify({ passed, failed: failures.length, assertionFailures, nativeCount, hostCount: tests.length - nativeCount, baseline, mutation, mutationCount }));
  if (expectRed) assert.ok(failures.length > 0 && failures.length === assertionFailures, 'RED must contain behavioral assertions only');
  else assert.equal(failures.length, 0, failures.map(value => value.name + ': ' + value.message).join('\n'));
})().catch(error => { console.error(error.stack); process.exitCode = 1; });

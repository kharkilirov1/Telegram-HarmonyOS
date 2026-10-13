// Node >=24. Same SDK callback bodies; actual normalizer, reducer, scoped store,
// policy and selected actual Session delegates. Transport and platform only are fixtures.
const fs = require('node:fs'), path = require('node:path'), assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module'), { createHash } = require('node:crypto');
const args = process.argv.slice(2), value = flag => args[args.indexOf(flag) + 1];
const baseline = args.includes('--baseline-dir') ? path.resolve(value('--baseline-dir')) : undefined;
const output = args.includes('--json') ? path.resolve(value('--json')) : undefined;
const expectRed = args.includes('--expect-red');
const mutant = args.includes('--mutant') ? value('--mutant') : undefined;
const mutations = {
  'dispatch-gate': ['ui/pages/chat/ChatPermissionCoordinator.ets', 'currentSlowmodeSeconds(state, host.activeChatId) === 0', 'true'],
  'zero-boost-threshold': ['ui/pages/chat/ChatSlowmodeController.ets', 'boosts.unrestrictBoostCount > 0', 'boosts.unrestrictBoostCount >= 0'],
  'fractional-floor': ['ui/pages/chat/ChatSlowmodeController.ets', 'return Math.ceil(remainingSlowmodeMs(', 'return Math.floor(remainingSlowmodeMs('],
  'receipt-reanchor': ['ui/pages/chat/ChatSlowmodeController.ets', 'Math.max(0, nowMs - slowmode.receivedElapsedMs)', '0'],
  'disable-invalidation': ['core/reducers/chatsReducer.ets', 'newState.chats.supergroupSlowmode.delete(access.groupId);', 'void access.groupId;'],
  'missing-enabled-bit': ['core/reducers/chatsReducer.ets', 'copy.isSlowModeEnabled = registry.get(access.groupId)?.isSlowModeEnabled;', 'copy.isSlowModeEnabled = undefined;'],
  'normalizer-metadata': ['core/events/normalizers/ChatNormalizer.ets', 'if (slowmode !== undefined) events.push(createSupergroupSlowmodeUpdatedEvent(slowmode));', 'void slowmode;'],
  'photo-await-gate': ['ui/pages/chat/ChatPhotoAlbumController.ets', "!host.canSendNewMessages('photo')", 'false', true],
  'sequential-await-gate': ['ui/pages/chat/ChatSequentialMediaController.ets', '!host.canSendNewMessages(attempt.kind)', 'false', true],
  'text-dialog-gate': ['ui/pages/chat/ChatTextSendController.ets', "!host.canSendNewMessages('text')", 'false', true],
  'owner-timer-cleanup': ['ui/pages/chat/ChatSlowmodeController.ets', 'if (this.hasSameHost() && this.host !== undefined) this.host.composerSlowmodeSeconds = 0;', 'if (this.host !== undefined) this.host.composerSlowmodeSeconds = 0;'],
  'hydration-ABA-refresh': ['domain/usecases/loadChatAccess.ets', 'if (error instanceof SupersededFullInfoError && canRefresh())', 'if (false)'],
  'atom-gesture-gate': ['ui/tg_ui/atoms/TgComposerInput.ets', 'return !this.showEditSnippet && this.slowmodeSeconds > 0;', 'return false;']
};
const activatedMutations = [];
const root = baseline || path.resolve(__dirname, '..'), main = path.join(root, 'entry/src/main/ets');
const hashes = {}, tests = [];
function read(relative) {
  const file = path.join(main, relative); const bytes = fs.readFileSync(file); hashes[file] = createHash('sha256').update(bytes).digest('hex');
  let source = bytes.toString('utf8').replaceAll('\r\n', '\n'); const change = mutant ? mutations[mutant] : undefined;
  if (change && relative === change[0]) {
    const count = source.split(change[1]).length - 1;
    assert.ok(count > 0 && (change[3] || count === 1), 'Mutation anchor must match actual source: ' + mutant);
    source = source.replaceAll(change[1], change[2]); activatedMutations.push({ mutant, relative, count });
  }
  return source;
}
function compile(source, deps, label) {
  const exports = [...source.matchAll(/^export\s+(?:default\s+)?(?:async\s+)?(?:class|function|const|enum)\s+(\w+)/gm)].map(x => x[1]);
  const code = stripTypeScriptTypes(source.replace(/^import[\s\S]*?;\s*/gm, '')
    .replace(/@ObservedV2\s*/g, '').replace(/@Trace\s*/g, '').replace(/^export\s+(?:default\s+)?/gm, ''), { mode: 'transform', sourceUrl: label });
  return new Function(...Object.keys(deps), code + '\nreturn {' + exports.join(',') + '};')(...Object.values(deps));
}
function load(relative, deps = {}) { return compile(read(relative), deps, relative); }
const hilog = { info() {}, warn() {}, error() {}, debug() {} }, localized = (_id, fallback) => fallback;
const resources = { $r: name => ({ id: name }), localized, hilog };
let elapsedMs = 100000;
const clockPath = 'core/utils/SlowmodeClock.ets';
const clock = fs.existsSync(path.join(main, clockPath)) ? load(clockPath, {
  systemDateTime: { TimeType: { STARTUP: 0, ACTIVE: 1 }, getUptime: (kind, nanoseconds) => {
    assert.equal(kind, 0, 'Sleep-aware native STARTUP clock required'); assert.equal(nanoseconds, false);
    return elapsedMs;
  } }
}) : {};
const A = load('core/model/AppState.ets'), C = load('core/model/AppCommand.ets'), errors = load('core/model/AppError.ets');
const td = load('models/td/common/index.ets'), accessors = load('core/utils/tdAccessors.ets', td);
const G = load('core/model/dto/GroupAccessDto.ets', { ...accessors, ...clock }), D = load('core/model/dto/ChatDto.ets', { ...accessors, ...C, ...G, hilog });
const E = load('core/model/AppEvent.ets', { ...D, ...G });
const clones = load('core/utils/stateClone.ets', { ...A, ...G });
const { chatsReducer } = load('core/reducers/chatsReducer.ets', { ...A, ...E, ...G, ...clones, ...accessors, DtoChatType: D.ChatType });
const noop = state => state;
const { appReducer } = load('core/reducers/index.ets', { chatsReducer, authReducer: noop, messagesReducer: noop, usersReducer: noop, filesReducer: noop, accentColorsReducer: noop });
const { AppStore } = load('core/store/AppStore.ets', { ...A, hilog });
const P = load('ui/pages/chat/ChatInputPanelPolicy.ets', { ...G, ...clock });
const uiState = load('core/model/UIStateModels.ets');
const slowmodePath = 'ui/pages/chat/ChatSlowmodeController.ets';
const slowmode = fs.existsSync(path.join(main, slowmodePath)) ? load(slowmodePath, { ...A, ...G, ...clock, ...uiState }) : {};
const permission = load('ui/pages/chat/ChatPermissionCoordinator.ets', { ...A, ...P, ...G, ...clock, ...slowmode, ...resources });
const adapters = load('ui/pages/chat/ChatComposerHostAdapters.ets', { ...resources });
const { registerChatHandlers } = load('core/events/normalizers/ChatNormalizer.ets', { ...E, ...D, ...G, ...accessors, ...clock, hilog });
const sends = load('domain/usecases/sendMessage.ets', { ...C, ...errors, ...accessors, ...td, hilog });
const albums = load('domain/usecases/sendMediaAlbum.ets', { ...C, ...errors, ...accessors, ...td, hilog });
const media = load('domain/usecases/sendMediaMessage.ets', { ...C, ...errors, ...accessors, ...td, ...albums, hilog });
const forward = load('domain/usecases/forwardMessages.ets', { ...C, ...errors, ...accessors, ...td, hilog });
const emoji = load('ui/tg_ui/utils/TgCustomEmojiDraftPolicy.ets', C);
const tokens = { TgUiTokens: { COLOR_TEXT_TITLE_RESOURCE_NAME: 'text', COLOR_ICON_PRIMARY_RESOURCE_NAME: 'icon' } };
const platform = { ...resources, ...tokens, abilityAccessCtrl: {}, picker: {}, camera: {}, cameraPicker: {}, photoAccessHelper: {} };
const dependencies = { ...C, ...errors, ...accessors, ...td, ...platform, ...clock };
const photo = load('ui/pages/chat/ChatPhotoAlbumController.ets', { ...dependencies, ...media, ...albums });
const sequential = load('ui/pages/chat/ChatSequentialMediaController.ets', { ...dependencies, ...media, ...emoji });
const textOwner = load('ui/pages/chat/ChatTextSendController.ets', { ...dependencies, ...sends, ...emoji });
const preparer = load('ui/pages/chat/ChatAttachmentFilePreparer.ets', { ...platform, fileIo: {} });
const composer = load('ui/pages/chat/ChatComposerController.ets', { ...dependencies, ...sends, ...media, ...photo, ...sequential, ...textOwner, ...preparer, ...emoji });
const actions = load('ui/pages/chat/ChatMessageActionsController.ets', { ...dependencies, ...sends, ...forward });
const barSource = read('ui/tg_ui/atoms/TgChatTopBar.ets'), enums = ['TgChatTopBarSubtitleMode', 'TgChatTopBarTrailingAction'];
const enumCode = enums.map(name => { const match = barSource.match(new RegExp('export enum ' + name + ' \\{[\\s\\S]*?\\}')); assert.ok(match); return match[0].replace('export ', ''); }).join('\n');
const barEnums = new Function(stripTypeScriptTypes(enumCode, { mode: 'transform' }) + '\nreturn {' + enums.join(',') + '};')();
const slices = {};
for (const name of ['ChatChromeState', 'ChatComposerState', 'ChatPanelsState', 'ChatTimelineViewState', 'ChatMediaViewState', 'ChatPinnedSearchState']) Object.assign(slices,
  load('ui/pages/chat/' + name + '.ets', { ...platform, ...barEnums, NavPathStack: class {} }));
const view = load('ui/pages/chat/ChatScreenViewState.ets', slices);
const context = load('ui/pages/chat/ChatScreenContext.ets', { ...view, ...composer, ...actions, ChatTimelineDataSource: class {}, Scroller: class {},
  ReplyHydrationCoordinator: class {}, ChatMediaDownloadController: class {}, PendingMediaOpenIntent: class {}, ChatVoiceRecordingController: class {},
  ChatForwardSourceController: class {}, ChatSearchController: class {}, ChatStickerSearchController: class {},
  ChatSlowmodeController: slowmode.ChatSlowmodeController || class {} });
const sessionSource = read('ui/pages/chat/ChatScreenSession.ets');
const names = ['canUseComposer', 'canSendNewMessages', 'composerCanSubmit', 'getSendUseCase', 'getSendMediaUseCase',
  ...Object.keys(adapters).filter(name => sessionSource.includes('  ' + name + '(') && !['getSendUseCase', 'getSendMediaUseCase'].includes(name))];
const delegates = { delegateCanUseComposer: permission.canUseComposer, delegateCanSendNewMessages: permission.canSendNewMessages,
  delegateComposerCanSubmit: permission.composerCanSubmit, delegateGetSendUseCase: adapters.getSendUseCase, delegateGetSendMediaUseCase: adapters.getSendMediaUseCase };
for (const [name, fn] of Object.entries(adapters)) delegates['delegate' + name[0].toUpperCase() + name.slice(1)] = fn;
const bodies = names.map(name => {
  const start = sessionSource.indexOf('  ' + name + '('); assert.ok(start >= 0, 'Existing Session entry must exist: ' + name);
  let pos = sessionSource.indexOf('{', start), depth = 1, end = pos + 1;
  while (depth && end < sessionSource.length) { if (sessionSource[end] === '{') depth++; if (sessionSource[end] === '}') depth--; end++; }
  assert.equal(depth, 0); return sessionSource.slice(start, end);
});
const { ChatScreenSession } = compile('export class ChatScreenSession extends ChatScreenContext {\n' + bodies.join('\n') +
  '\nresetEmojiSearchState() {}\nisNearBottom() { return true; }\nscrollToBottomSoon() {}\n}', { ...context, ...delegates }, 'actual selected Session methods');
const describe = (_name, callback) => callback(), it = (name, _flags, callback) => tests.push({ name, run: callback });
const expect = actual => ({ assertEqual: expected => assert.equal(actual, expected), assertTrue: () => assert.equal(actual, true), assertFalse: () => assert.equal(actual, false) });
// Existing controlled SDK transport class; no networking or accounts.
const prior = path.resolve(__dirname, '../entry/src/ohosTest/ets/test/WritePathErrors.test.ets');
const priorBytes = fs.readFileSync(prior); hashes[prior] = createHash('sha256').update(priorBytes).digest('hex');
const write = compile(priorBytes.toString('utf8'), { ...A, ...C, ...errors, ...td, ...sends, ...media, ...albums, ...forward, ...actions, describe, it, expect }, prior);
const source = path.resolve(__dirname, '../entry/src/ohosTest/ets/test/Slowmode.test.ets'), bytes = fs.readFileSync(source);
hashes[source] = createHash('sha256').update(bytes).digest('hex');
const sdk = compile(bytes.toString('utf8'), { ...A, ...C, ...E, ...G, ...td, ...sends, ...media,
  ...composer, ...forward, appReducer, AppStore, registerChatHandlers, ChatScreenSession, ...view, WriteGateway: write.WriteGateway,
  settleWrites: write.settleWrites, describe, it, expect }, source);
sdk.slowmodeTest();
const baselineEntryCount = tests.length;
if (!baseline) {
  const hydration = load('domain/usecases/loadChatAccess.ets', { ...C, ...E, ...D, ...G, ...td, AppStore });
  const accessOwner = load('ui/pages/chat/ChatAccessController.ets', { ...P, ...G, ...hydration });
  const policySource = path.resolve(__dirname, '../entry/src/ohosTest/ets/test/SlowmodePolicy.test.ets');
  const policyBytes = fs.readFileSync(policySource); hashes[policySource] = createHash('sha256').update(policyBytes).digest('hex');
  const policySdk = compile(policyBytes.toString('utf8'), { ...A, ...E, ...G, ...td, ...clock, ...uiState, ...slowmode,
    ...accessOwner, ...hydration, ...sdk, settleWrites: write.settleWrites, describe, it, expect }, policySource);
  policySdk.slowmodePolicyTest();
}
const nativeCount = tests.length;
if (!baseline) {
  const add = (name, run) => tests.push({ name, run });
  const dialogFixture = () => {
    const dialogs = [], toasts = [];
    const ui = { getHostContext: () => ({ filesDir: '/fixture', resourceManager: { getColorByNameSync: () => 0xff0088cc } }),
      getPromptAction: () => ({ showToast: value => toasts.push(value), showDialog: options =>
        new Promise((resolve, reject) => dialogs.push({ options, resolve, reject })) }) };
    const f = new sdk.SlowmodeFixture('member', 'supergroup', new view.ChatScreenViewState(), () => ui);
    return { f, dialogs, toasts };
  };
  const accepted = id => td.TdObject.fromJSON('{"@type":"message","id":' + id + ',"chat_id":42}');
  for (const kind of ['photo', 'document', 'video']) add(kind + ' countdown arriving during controlled preparation prevents mutation and preserves original input', async () => {
    const { f } = dialogFixture(); f.composer.deferPreparation = true;
    f.page.setPendingAttachmentState(kind, 'Selected', 'Original', ['fixture:a']);
    if (kind === 'photo') {
      new photo.ChatPhotoAlbumController().handleSend(f.page.composerDraftText, f.page, uri => {
        const item = new sdk.SlowmodePreparation('photo', uri, f.composer.preparations.length); f.composer.preparations.push(item);
        return new Promise(resolve => { item.resolve = resolve; });
      }, prepared => f.composer.discarded.push(prepared));
    } else f.composer.handleSendMessage(f.page.composerDraftText, f.page);
    await write.settleWrites();
    assert.equal(f.composer.preparations.length, 1, 'positive prepare control must enter actual media owner');
    await f.updateFullInfo('30'); f.composer.preparations[0].resolve(f.composer.preparations[0].path); await write.settleWrites();
    assert.equal(f.gateway.requests.length, 0); assert.deepEqual(f.composer.discarded, [f.composer.preparations[0].path]);
    assert.deepEqual(f.page.pendingAttachmentUris, ['fixture:a']); assert.equal(f.page.isSending, false); sdk.expectSlowmodeInputPreserved(f);
  });
  for (const kind of ['document', 'video']) add(kind + ' accepted prefix retires during new countdown and stops remaining dispatch without reusing caption', async () => {
    const { f } = dialogFixture(); f.page.setPendingAttachmentState(kind, 'Selected', 'Original', ['fixture:a', 'fixture:b']);
    f.composer.handleSendMessage(f.page.composerDraftText, f.page); await write.settleWrites();
    assert.equal(f.gateway.requests.length, 1); await f.updateFullInfo('30'); f.gateway.requests[0].resolve(accepted(901)); await write.settleWrites();
    assert.equal(f.gateway.requests.length, 1); assert.equal(f.composer.preparations.length, 1);
    assert.deepEqual(f.page.pendingAttachmentUris, ['fixture:b']); assert.equal(f.page.composerDraftText, '');
    assert.equal(f.page.replyToMessageId, '0'); assert.equal(f.page.customEmojiDraftEntities.length, 0);
    assert.equal(f.page.composerSelectionStart, 0); assert.equal(f.page.composerSelectionEnd, 0); assert.equal(f.page.isSending, false);
    await f.updateFullInfo('0'); assert.equal(f.gateway.requests.length, 1, 'expiry never auto-sends remaining selection');
    f.composer.handleSendMessage('', f.page); await write.settleWrites(); assert.equal(f.gateway.requests.length, 2);
    assert.equal(f.gateway.requests[1].command.payload.caption, ''); assert.equal(f.gateway.requests[1].command.payload.replyToMessageId, '0');
    f.gateway.requests[1].resolve(accepted(902)); await write.settleWrites(); assert.deepEqual(f.page.pendingAttachmentUris, []);
  });
  add('accepted photo during countdown completes owned cleanup without preserving a replayable upload', async () => {
    const { f } = dialogFixture(); f.page.setPendingAttachmentState('photo', 'Selected', 'Original', ['fixture:a']);
    new photo.ChatPhotoAlbumController().handleSend(f.page.composerDraftText, f.page,
      () => Promise.resolve('/fixture/photo'), prepared => f.composer.discarded.push(prepared));
    await write.settleWrites(); assert.equal(f.gateway.requests.length, 1);
    await f.updateFullInfo('30'); f.gateway.requests[0].resolve(accepted(901)); await write.settleWrites();
    assert.deepEqual(f.page.pendingAttachmentUris, []); assert.equal(f.page.replyToMessageId, '0'); assert.equal(f.page.composerDraftText, '');
    assert.deepEqual(f.composer.discarded, []); assert.equal(f.page.isSending, false);
  });
  for (const kind of ['text', 'document', 'video']) add(kind + ' uncertain retry confirmation rechecks countdown and retains uncertainty until a later explicit confirmation', async () => {
    const { f, dialogs } = dialogFixture(); if (kind !== 'text') f.page.setPendingAttachmentState(kind, 'Selected', 'Original', ['fixture:a']);
    f.composer.handleSendMessage(f.page.composerDraftText, f.page); await write.settleWrites(); assert.equal(f.gateway.requests.length, 1);
    f.gateway.requests[0].reject(new Error('Controlled unknown write')); await write.settleWrites();
    f.composer.handleSendMessage(f.page.composerDraftText, f.page); await write.settleWrites(); assert.equal(dialogs.length, 1);
    await f.updateFullInfo('30'); dialogs[0].resolve({ index: 1 }); await write.settleWrites();
    assert.equal(f.gateway.requests.length, 1); assert.equal(f.page.isSending, false);
    assert.equal(f.page.composerDraftText, '\uD83D\uDE00 preserved draft'); assert.equal(f.page.replyToMessageId, '55');
    assert.equal(f.page.composerSelectionStart, 2); assert.equal(f.page.composerSelectionEnd, 4); assert.equal(f.page.customEmojiDraftEntities.length, 1);
    await f.updateFullInfo('0'); assert.equal(f.gateway.requests.length, 1);
    f.composer.handleSendMessage(f.page.composerDraftText, f.page); await write.settleWrites(); assert.equal(dialogs.length, 2);
    dialogs[1].resolve({ index: 0 }); await write.settleWrites(); assert.equal(f.gateway.requests.length, 1);
    f.composer.handleSendMessage(f.page.composerDraftText, f.page); await write.settleWrites(); assert.equal(dialogs.length, 3);
    dialogs[2].resolve({ index: 1 }); await write.settleWrites(); assert.equal(f.gateway.requests.length, 2);
    f.gateway.requests[1].resolve(accepted(902)); await write.settleWrites(); assert.equal(f.page.isSending, false);
  });
  // Actual atom gesture methods, with only UI events/text controller as ports.
  // Builders/rendering are exercised separately on the native mounted Dock.
  const atomSource = read('ui/tg_ui/atoms/TgComposerInput.ets');
  const atomNames = ['hasText', 'hasPendingForward', 'hasPendingAttachment', 'hasSendIntent', 'canSend', 'isSlowmodeActive',
    'isVoiceRecordingActive', 'handleSend', 'handleActionPress', 'beginVoiceRecordingGesture', 'handleAttachPress'];
  const atomMethods = atomNames.map(name => {
    const start = atomSource.indexOf('  private ' + name + '('); assert.ok(start >= 0);
    let pos = atomSource.indexOf('{', start), depth = 1, end = pos + 1;
    while (depth && end < atomSource.length) { if (atomSource[end] === '{') depth++; if (atomSource[end] === '}') depth--; end++; }
    assert.equal(depth, 0); return atomSource.slice(start, end);
  });
  const { ActualAtom } = compile('export class ActualAtom {\n' + atomMethods.join('\n') + '\n}', {}, 'Actual TgComposerInput gesture bodies');
  function atomFixture() {
    const events = [];
    const atom = Object.assign(new ActualAtom(), { text: 'preserved input', sendEnabled: true, isDisabled: false,
      slowmodeSeconds: 11, showEditSnippet: false, showForwardSnippet: false, showAttachmentSnippet: false,
      voiceEnabled: true, voiceRecordingState: 'idle', voiceClickSuppressionUntil: 0, attachmentMenuOpen: false,
      textController: { stopEditing() { events.push('stopEditing'); } }, onSendPress: value => events.push(['send', value]),
      onVoicePress: () => events.push('voice'), onVoiceRecordStart: () => events.push('record'), onBotMenuOpenChange: value => events.push(['bot', value]),
      onAttachmentMenuOpenChange: value => events.push(['menu', value]), onAttachPress: () => events.push('attach') });
    return { atom, events };
  }
  add('actual atom trailing action and submit are blocked while populated draft countdown is active', async () => {
    const { atom, events } = atomFixture(); assert.equal(atom.canSend(), false); atom.handleActionPress(); atom.handleSend();
    assert.deepEqual(events, []); assert.equal(atom.text, 'preserved input');
    atom.slowmodeSeconds = 0; assert.deepEqual(events, [], 'expiry has no event'); atom.handleActionPress();
    assert.deepEqual(events, [['send', 'preserved input']]);
  });
  add('actual atom attachment handler leaves the menu closed and does not dismiss text during countdown', async () => {
    const { atom, events } = atomFixture(); atom.handleAttachPress(); assert.equal(atom.attachmentMenuOpen, false); assert.deepEqual(events, []);
    atom.slowmodeSeconds = 0; atom.handleAttachPress(); assert.equal(atom.attachmentMenuOpen, true);
    assert.deepEqual(events, ['stopEditing', ['bot', false], ['menu', true], 'attach']);
  });
  add('actual atom hold gesture is blocked during countdown and expiry requires another explicit gesture', async () => {
    const { atom, events } = atomFixture(); atom.text = ''; atom.beginVoiceRecordingGesture(); assert.deepEqual(events, []);
    atom.slowmodeSeconds = 0; assert.deepEqual(events, []); atom.beginVoiceRecordingGesture(); assert.deepEqual(events, ['stopEditing', 'record']);
  });
  add('actual atom edit-message send and attachment bypass only its new-message countdown gate', async () => {
    const { atom, events } = atomFixture(); atom.showEditSnippet = true; assert.equal(atom.canSend(), true); atom.handleActionPress();
    assert.deepEqual(events, [['send', 'preserved input']]); atom.handleAttachPress(); assert.equal(atom.attachmentMenuOpen, true);
    atom.isDisabled = true; const before = events.length; atom.handleActionPress(); atom.handleAttachPress(); assert.equal(events.length, before);
  });
}
require('./host-test-completion.cjs').guardSuite((async () => {
  const failures = []; let passed = 0;
  for (const test of tests) { try { await test.run(); passed++; } catch (error) { failures.push({ name: test.name, type: error.constructor.name, message: error.message }); } }
  const assertionFailures = failures.filter(x => x.type === 'AssertionError').length;
  const receipt = { passed, failed: failures.length, assertionFailures, nativeCount, baselineEntryCount,
    additiveNativeCount: nativeCount - baselineEntryCount, hostCount: tests.length - nativeCount, baseline, mutant,
    activatedMutations, hashes, failures };
  if (output) fs.writeFileSync(output, JSON.stringify(receipt, null, 2) + '\n');
  console.log(JSON.stringify({ passed, failed: failures.length, assertionFailures, nativeCount, hostCount: tests.length - nativeCount, baseline, mutant }));
  if (mutant) assert.ok(activatedMutations.length > 0, 'Mutation route must be activated');
  if (expectRed) assert.ok(failures.length > 0 && failures.length === assertionFailures, 'RED must contain behavior assertions only');
  else assert.equal(failures.length, 0, failures.map(x => x.name + ': ' + x.message).join('\n'));
})()).catch(error => { console.error(error.stack); process.exitCode = 1; });

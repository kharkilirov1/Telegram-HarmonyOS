// Node >=24. Actual page guards, composer controller, text/media use cases,
// commands, reducer and scoped store. No SDK/build, network or account actions.
// Only transport, native file I/O and presentation-only effects are fixtures.
// All sends enter through the real page callback: no private media-loop calls
// or copied ownership logic (including its evolving operation parameter).
const { readChatSource } = require("./chat-screen-source.cjs");
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
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

const sources = {};
const mutant = process.argv.find(arg => arg.startsWith('--mutant='))?.slice(9);
assert.ok(!mutant || ['no-dispatch-guards', 'permission-cleanup', 'shared-owner', 'account-restore'].includes(mutant));
let mutations = 0;
function read(relative) {
  let source = readChatSource(path.join(root, relative), 'utf8');
  sources[relative] = createHash('sha256').update(source).digest('hex');
  source = source.replaceAll('\r\n', '\n');
  if (relative === 'ui/pages/chat/ChatMessageActionsController.ets') {
    if (mutant === 'no-dispatch-guards') {
      const block = /        if \(!this\.ownsForwardOperation\([^]*?throw new Error\('Forward context changed (?:before dispatch|after comment)'\);\n        }\n/g;
      const matches = [...source.matchAll(block)];
      assert.equal(matches.length, 2, 'dispatch mutation must engage both request boundaries');
      source = source.replace(block, ''); mutations += 2;
    }
    if (mutant === 'permission-cleanup') {
      const before = '.finally(() => {\n        if (!this.ownsForwardOperation(host, lifecycleToken, targetChatId, operation)) {';
      assert.ok(source.includes(before), 'cleanup mutation did not engage');
      source = source.replace(before, '.finally(() => {\n        if (!this.isForwardContextActive(host, lifecycleToken, forwardUseCase, sendUseCase, targetChatId)) {');
      mutations++;
    }
  }
  if (['ui/pages/chat/ChatMessageActionsController.ets', 'ui/pages/chat/ChatComposerController.ets'].includes(relative)) {
    const before = mutant === 'shared-owner' ? 'operation === host.getSendOperationToken() && ' : 'host.hasActiveChatState() && ';
    if (mutant === 'shared-owner' || mutant === 'account-restore') {
      assert.ok(source.includes(before), 'ownership mutation did not engage: ' + relative);
      source = source.replace(before, ''); mutations++;
    }
  }
  return source;
}
function load(relative, deps = {}) {
  const source = read(relative);
  const names = [...source.matchAll(/^export\s+(?:default\s+)?(?:class|function|const|enum)\s+(\w+)/gm)].map(m => m[1]);
  const code = source.replace(/^import[\s\S]*?;\s*/gm, '')
    .replace(/^export\s+\{[^}]*\};?\s*/gm, '')
    .replace(/^export\s+default\s+\w+;\s*$/gm, '').replace(/^export\s+(?:default\s+)?/gm, '');
  const js = stripTypeScriptTypes(code, { mode: 'transform', sourceUrl: relative });
  return new Function(...Object.keys(deps), `${js}\nreturn {${names.join(',')}};`)(...Object.values(deps));
}
const hilog = { info() {}, debug() {}, warn() {}, error() {} };
const platform = { hilog, localized: (_id, fallback) => fallback, $r: id => ({ id }) };
const C = load('core/model/AppCommand.ets');
const A = load('core/model/AppState.ets');
const td = load('models/td/common/index.ets');
const accessors = load('core/utils/tdAccessors.ets', td);
const G = load('core/model/dto/GroupAccessDto.ets', accessors);
const E = load('core/model/AppEvent.ets', G);
const clones = load('core/utils/stateClone.ets', { ...A, ...G });
const { chatsReducer } = load('core/reducers/chatsReducer.ets', { ...A, ...E, ...G, ...clones, ...accessors });
const { AppStore } = load('core/store/AppStore.ets', { ...A, hilog });
const errors = load('core/model/AppError.ets');
const useCaseDeps = { ...C, ...errors, ...td, ...platform };
const text = load('domain/usecases/sendMessage.ets', useCaseDeps);
const forwarding = load('domain/usecases/forwardMessages.ets', useCaseDeps);
const album = load('domain/usecases/sendMediaAlbum.ets', { ...useCaseDeps, ...accessors });
const media = load('domain/usecases/sendMediaMessage.ets', { ...useCaseDeps, ...album });
const photoAlbum = load('ui/pages/chat/ChatPhotoAlbumController.ets', { ...errors, ...media, ...album, ...platform });
const emoji = load('ui/tg_ui/utils/TgCustomEmojiDraftPolicy.ets', C);
const sequentialMedia = load('ui/pages/chat/ChatSequentialMediaController.ets', { ...errors, ...media, ...platform });
const textController = load('ui/pages/chat/ChatTextSendController.ets', { ...useCaseDeps, ...text, ...emoji });
const policy = load('ui/pages/chat/ChatInputPanelPolicy.ets');
let copiedFiles = 0;
const fileIo = {
  OpenMode: { READ_ONLY: 0 }, accessSync: file => !String(file).includes("/tg_send_"),
  openSync: () => ({ fd: 1 }), copyFileSync() { copiedFiles++; }, closeSync() {}
};
const attachmentFiles = load('ui/pages/chat/ChatAttachmentFilePreparer.ets', { ...platform, fileIo: fileIo });
const { ChatComposerController } = load('ui/pages/chat/ChatComposerController.ets', {
  ...errors, ...textController, ...sequentialMedia, ...text, ...media, ...photoAlbum, ...attachmentFiles, ...emoji, ...platform, fileIo
});
const actions = load('ui/pages/chat/ChatMessageActionsController.ets', { ...errors, ...text, ...forwarding, ...platform });
const ui = {
  setEmojiPanelVisible(value) { this.showComposerEmojiPanel = value; },
  setStickerPanelVisible(value) { this.showComposerStickerPanel = value; },
  isNearBottom() { return true; },
  scrollToBottomSoon() { this.scrolls++; },
  getChatUIContext() {
    return { getHostContext: () => ({ filesDir: '/fixture' }),
      getPromptAction: () => ({ showToast: () => { this.toasts++; } }) };
  }
};
const page = read('ui/pages/chat/TgChatScreenPage.ets').replaceAll('\r\n', '\n');
const methods = new Map();
for (const match of page.matchAll(/^  (?:(?:private|public|protected|async)\s+)*(\w+)\s*\(/gm)) {
  const end = page.indexOf('\n  }', match.index);
  if (end >= 0) methods.set(match[1], page.slice(match.index, end + 4));
}
const selected = new Map();
function include(name) {
  if (selected.has(name) || Object.hasOwn(ui, name)) return;
  const source = methods.get(name);
  assert.ok(source, `actual page method missing: ${name}`);
  selected.set(name, source);
  for (const dependency of source.matchAll(/\bthis\.(\w+)\s*\(/g)) include(dependency[1]);
}
[
  'handleSendMessage', 'getActiveChatId', 'getLifecycleToken', 'getSendUseCase', 'getSendMediaUseCase',
  'isSendingMessage', 'setSendingMessage', 'isEditModeActive', 'isForwardModeActive',
  'getComposerInputRevision', 'getDraftText', 'setDraftText', 'getDraftSelectionStart', 'getDraftSelectionEnd', 'setDraftSelection', 'getCustomEmojiEntities', 'setCustomEmojiEntities',
  'getReplyToMessageId', 'clearReplyMode', 'getPendingAttachmentUris', 'getPendingAttachmentKind',
  'setPendingAttachmentState', 'clearPendingAttachmentState', 'setEditMode', 'clearEditMode',
  'setForwardMode', 'clearForwardMode', 'submitForwardMessages', 'getForwardUseCase',
  'getForwardModeState', 'getEditingMessageId'
].forEach(include);
if (methods.has('getSendOperationToken')) include('getSendOperationToken');
if (methods.has('hasActiveChatState')) include('hasActiveChatState');
const PageProbe = new Function('selectChatInputPanel', 'ChatForwardModeState', stripTypeScriptTypes(
  `class PageProbe {
  slowmodeController = new globalThis.ChatSlowmodeController();
  composerSlowmodeSeconds = 0;\n${[...selected.values()].join('\n')}\n}`, { mode: 'transform' }) + '\nreturn PageProbe;'
)(policy.selectChatInputPanel, actions.ChatForwardModeState);
const tick = () => new Promise(resolve => setImmediate(resolve));
const fixtures = [];
function rights(groupId = 123, post = true) {
  return Object.assign(new G.GroupAccessDto(), { kind: 'supergroup', groupId,
    role: 'administrator', isMember: true, canPostMessages: post, canEditMessages: true });
}
function fixture(type = 'channel') {
  const state = A.createInitialAppState();
  const ids = type === 'private' ? [7, 8] : [-100123, -100124];
  ids.forEach((id, i) => {
    state.chats.chats.set(id, Object.assign(new A.Chat(), { id, type,
      peerUserId: type === 'private' ? id : 0, supergroupId: type === 'private' ? 0 : 123 + i }));
    state.chats.supergroupAccess.set(123 + i, rights(123 + i));
  });
  const store = new AppStore(chatsReducer, state, false);
  const requests = [];
  const trace = [];
  const gateway = { send(command) {
    trace.push(command);
    if (command.type === 'getChat') return Promise.resolve(td.TdObject.fromJSON(JSON.stringify({
      '@type': 'chat', id: command.payload.chatId,
      type: { '@type': type === 'private' ? 'chatTypePrivate' : 'chatTypeSupergroup' }
    })));
    if (command.type === 'getMessageProperties') return Promise.resolve(td.TdObject.fromJSON(
      '{"@type":"messageProperties","can_be_forwarded":true,"can_be_copied":true,"can_be_copied_to_secret_chat":true}'));
    // Preserve deferred mutation races without mistaking eligibility reads for sends.
    let resolve, reject;
    const promise = new Promise((ok, fail) => { resolve = ok; reject = fail; });
    requests.push({ command, resolve, reject, settled: false });
    return promise;
  } };
  const p = Object.assign(new PageProbe(), ui, {
    accountStore: store.createScope(), activeChatId: ids[0], pageLifecycleToken: 1,
    sendingMessageOperation: 0, isSending: false, isEditingMessage: false, isForwardingMessages: false,
    editingMessageId: '0', editingOriginalText: '', composerInputRevision: 0, composerDraftText: '',
    composerSelectionStart: 0, composerSelectionEnd: 0, composerCaretRequestRevision: 0,
    customEmojiDraftEntities: [], expectedProgrammaticCustomEmojiText: '', replyToMessageId: '0',
    pendingAttachmentUris: [], pendingAttachmentKind: '', draftDebounceTimerId: -1,
    chatAccessUnavailable: false, scrolls: 0, toasts: 0,
    composerCtrl: new ChatComposerController(), messageActionsCtrl: new actions.ChatMessageActionsController(),
    forwardUseCase: new forwarding.ForwardMessagesUseCase(gateway),
    forwardingMessageIds: [], forwardSourceChatId: 0, forwardTitle: '', forwardPreview: '',
    sendUseCase: text.createSendMessageUseCase(gateway),
    sendMediaUseCase: media.createSendMediaMessageUseCase(gateway)
  });
  const f = { p, store, requests, trace, ids, setPosting: post => store.dispatch(E.createGroupAccessUpdatedEvent(rights(123, post))) };
  fixtures.push(f);
  return f;
}
function start(f, kind, label, count = 1) {
  f.p.setDraftText(label);
  if (kind === 'media') {
    f.p.setPendingAttachmentState('document', label, label,
      Array.from({ length: count }, (_v, i) => `file:///fixture/${label}-${i}.bin`));
  } else {
    f.p.clearPendingAttachmentState();
  }
  f.p.handleSendMessage(label);
}
async function begin(f, kind, label, count = 1) {
  const before = f.requests.length;
  start(f, kind, label, count);
  await tick();
  assert.equal(f.requests.length, before + 1, `${label}: actual ${kind} command must start`);
  const request = f.requests[before];
  assert.equal(request.command.type, kind === 'text' ? 'sendMessage' : 'sendMediaMessage');
  assert.equal(request.command.payload.chatId, f.p.activeChatId);
  if (kind === 'media') assert.equal(request.command.payload.mediaKind, 'document');
  assert.equal(f.p.isSending, true, 'a command in flight must own the busy flag');
  return request;
}
async function settle(request, outcome = 'resolve') {
  assert.equal(request.settled, false, 'a transport request may settle only once');
  request.settled = true;
  if (outcome === 'reject') request.reject(new Error('fixture transport rejection'));
  else if (outcome === 'definitive-rejection') request.reject(errors.classifyTdlibError(400, 'CHAT_WRITE_FORBIDDEN'));
  else request.resolve(request.command.type === 'forwardMessages' ? td.TdObject.fromJSON(JSON.stringify({
    '@type': 'messages', messages: request.command.payload.messageIds.map((_id, i) =>
      ({ '@type': 'message', id: 900+i, chat_id: request.command.payload.chatId }))
  })) : td.TdObject.fromJSON(JSON.stringify({ '@type': 'message', id: 900, chat_id: request.command.payload.chatId })));
  await tick();
}
function switchContext(f, boundary) {
  // Reproduce host-owned context reset, not controller cleanup. Keep the SAME
  // composer instance/capabilities so token/chat/operation guards must engage.
  if (boundary === 'lifecycle' || boundary === 'both') f.p.pageLifecycleToken++;
  if (boundary === 'chat' || boundary === 'both' || boundary === 'roundtrip') f.p.activeChatId = f.ids[1];
  if (boundary === 'roundtrip') f.p.activeChatId = f.ids[0];
  f.p.isSending = false;
  f.p.clearPendingAttachmentState();
}

const tests = [];
const test = (name, run) => tests.push({ name, run });
function queueForward(f, comment = '', label = 'first') {
  f.p.clearPendingAttachmentState();
  f.p.setForwardMode(['31', '32'], 88, label, 'preview ' + label);
  f.p.setDraftText(comment);
  f.p.handleSendMessage(comment);
}
async function beginForward(f, comment = '', label = 'first') {
  const before = f.requests.length;
  const traceBefore = f.trace.length;
  queueForward(f, comment, label); await tick();
  assert.equal(f.requests.length, before + 1, 'real use-case must reach gateway');
  assert.equal(f.requests[before].command.type, comment.trim() ? 'sendMessage' : 'forwardMessages');
  const reads = ['getChat', 'getMessageProperties', 'getMessageProperties'];
  assert.deepEqual(f.trace.slice(traceBefore).map(c => c.type), comment.trim()
    ? [...reads, 'sendMessage'] : [...reads, ...reads, 'forwardMessages']);
  assert.ok(f.trace.slice(traceBefore).filter(c => c.type === 'getChat').every(c => c.payload.chatId === f.ids[0]));
  assert.deepEqual(f.trace.slice(traceBefore).filter(c => c.type === 'getMessageProperties')
    .map(c => [c.payload.chatId, c.payload.messageId]), comment.trim()
      ? [[88, '31'], [88, '32']] : [[88, '31'], [88, '32'], [88, '31'], [88, '32']]);
  assert.equal(f.p.isSending, true);
  return f.requests[before];
}
for (const comment of ['', 'comment']) {
  test('ordinary forward chain, comment=' + Boolean(comment), async () => {
    const f = fixture(); const first = await beginForward(f, comment);
    await settle(first);
    if (comment) { assert.equal(f.requests[1].command.type, 'forwardMessages'); await settle(f.requests[1]); }
    const reads = ['getChat', 'getMessageProperties', 'getMessageProperties'];
    assert.deepEqual(f.trace.map(c => c.type), [...reads, ...(comment ? ['sendMessage'] : []), ...reads, 'forwardMessages']);
    assert.equal(f.p.isSending, false); assert.equal(f.p.isForwardingMessages, false);
    assert.equal(f.p.composerDraftText, ''); assert.equal(f.p.scrolls, 1);
    const last = f.requests.at(-1).command.payload;
    assert.equal(last.chatId, f.ids[0]); assert.equal(last.fromChatId, 88);
    assert.deepEqual(last.messageIds, ['31', '32']);
  });
  for (const boundary of ['revoke', 'edit', 'chat', 'lifecycle', 'reset']) {
    test('before deferred dispatch / ' + boundary + ' / comment=' + Boolean(comment), async () => {
      const f = fixture(); queueForward(f, comment);
      if (boundary === 'revoke') f.store.getState().chats.supergroupAccess.set(123, rights(123, false));
      if (boundary === 'edit') f.p.setEditMode('5', 'new edit');
      if (boundary === 'chat') f.p.activeChatId = f.ids[1];
      if (boundary === 'lifecycle') f.p.pageLifecycleToken++;
      if (boundary === 'reset') f.store.resetState();
      await tick();
      assert.equal(f.requests.length, 0, 'nothing may be sent from obsolete deferred work');
      assert.equal(f.trace.length, 0, 'obsolete deferred work must not start reads either');
      if (boundary === 'edit') assert.equal(f.p.composerDraftText, 'new edit');
      if (['revoke', 'edit', 'reset'].includes(boundary)) assert.equal(f.p.isSending, false, 'owned busy must release');
      if (boundary === 'reset') { assert.equal(f.p.isForwardingMessages, false); assert.equal(f.p.composerDraftText, ''); }
    });
  }
}
for (const boundary of ['revoke', 'edit', 'chat', 'lifecycle', 'reset']) {
  test('after comment await / ' + boundary + ' / no forwarding', async () => {
    const f = fixture(); const comment = await beginForward(f, 'comment');
    if (boundary === 'revoke') await f.setPosting(false);
    if (boundary === 'edit') f.p.setEditMode('5', 'new edit');
    if (boundary === 'chat') f.p.activeChatId = f.ids[1];
    if (boundary === 'lifecycle') f.p.pageLifecycleToken++;
    if (boundary === 'reset') await f.store.resetStateQueued();
    await settle(comment);
    assert.equal(f.requests.length, 1, 'forward must not start after the awaited comment loses context');
    assert.deepEqual(f.trace.map(c => c.type), ['getChat', 'getMessageProperties', 'getMessageProperties', 'sendMessage']);
    if (['revoke', 'edit', 'reset'].includes(boundary)) assert.equal(f.p.isSending, false);
    if (boundary === 'edit') assert.equal(f.p.composerDraftText, 'new edit');
    if (boundary === 'reset') assert.equal(f.p.isForwardingMessages, false);
  });
}
for (const outcome of ['resolve', 'reject']) {
  for (const boundary of ['revoke', 'edit', 'fresh draft', 'fresh forward', 'fresh attachment']) {
    test('forward completion / ' + outcome + ' / ' + boundary, async () => {
      const f = fixture(); const request = await beginForward(f);
      if (boundary === 'revoke') await f.setPosting(false);
      if (boundary === 'edit') f.p.setEditMode('5', 'new edit');
      if (boundary === 'fresh draft') f.p.setDraftText('new draft');
      if (boundary === 'fresh forward') f.p.setForwardMode(['91'], 99, 'new forward', 'new preview');
      if (boundary === 'fresh attachment') f.p.setPendingAttachmentState('document', 'new file', 'new preview', ['file:///new']);
      await settle(request, outcome);
      assert.equal(f.p.isSending, false);
      if (boundary === 'edit') { assert.equal(f.p.composerDraftText, 'new edit'); assert.equal(f.p.isForwardingMessages, false); }
      if (boundary === 'fresh draft') { assert.equal(f.p.composerDraftText, 'new draft'); assert.equal(f.p.isForwardingMessages, false); }
      if (boundary === 'fresh forward') assert.deepEqual(f.p.forwardingMessageIds, ['91']);
      if (boundary === 'fresh attachment') { assert.deepEqual(f.p.pendingAttachmentUris, ['file:///new']); assert.equal(f.p.isForwardingMessages, false); }
    });
  }
}
test('required comment is not silently omitted when text capability is absent', async () => {
  const f = fixture(); f.p.sendUseCase = undefined;
  queueForward(f, 'must accompany forward'); await tick();
  assert.equal(f.requests.length, 0);
  assert.equal(f.trace.length, 0);
  assert.equal(f.p.isSending, false); assert.equal(f.p.isForwardingMessages, true);
  assert.equal(f.p.composerDraftText, 'must accompany forward');
});
test('optional empty comment needs no text capability', async () => {
  const f = fixture(); f.p.sendUseCase = undefined;
  await settle(await beginForward(f));
  assert.equal(f.p.isSending, false);
});
for (const failure of ['comment', 'forward']) test('retry preserves unsent intent without duplicating ' + failure, async () => {
  const f = fixture(); const comment = await beginForward(f, 'comment');
  if (failure === 'comment') await settle(comment, 'definitive-rejection');
  else { await settle(comment); await settle(f.requests[1], 'definitive-rejection'); }
  assert.equal(f.p.isSending, false); assert.equal(f.p.isForwardingMessages, true);
  assert.deepEqual(f.p.forwardingMessageIds, ['31', '32']);
  assert.equal(f.p.composerDraftText, failure === 'comment' ? 'comment' : '');
  const next = await beginForward(f, f.p.composerDraftText);
  assert.equal(next.command.type, failure === 'comment' ? 'sendMessage' : 'forwardMessages');
});
for (const oldKind of ['forward', 'text', 'media']) for (const newKind of ['forward', 'text', 'media']) {
  if (oldKind !== 'forward' && newKind !== 'forward') continue;
  for (const outcome of ['resolve', 'reject']) test('shared ownership / ' + oldKind + ' to ' + newKind + ' / ' + outcome, async () => {
    const f = fixture();
    const old = oldKind === 'forward' ? await beginForward(f, '', 'old') : await begin(f, oldKind, 'old', 2);
    // Page-owned cancellation, then a new operation in a DIFFERENT controller.
    f.p.setSendingMessage(false);
    const next = newKind === 'forward' ? await beginForward(f, '', 'new') : await begin(f, newKind, 'new');
    const count = f.requests.length;
    await settle(old, outcome);
    assert.equal(f.requests.length, count, 'obsolete batch cannot send another item');
    assert.equal(f.p.isSending, true, 'old finally must not release newer busy');
    assert.equal(f.p.isForwardingMessages, false, 'old catch must not resurrect forward');
    await settle(next);
    assert.equal(f.p.isSending, false);
  });
}
test('shared operation token advances for forward, text and explicit cancel', async () => {
  const f = fixture();
  assert.equal(typeof f.p.getSendOperationToken, 'function', 'page-owned send token missing');
  const first = f.p.getSendOperationToken();
  const request = await beginForward(f);
  assert.ok(f.p.getSendOperationToken() > first);
  f.p.setSendingMessage(false);
  const cancelled = f.p.getSendOperationToken();
  const next = await begin(f, 'text', 'new');
  assert.ok(f.p.getSendOperationToken() > cancelled);
  await settle(request); assert.equal(f.p.isSending, true); await settle(next);
});
test('failed text cannot become a caption on a newly selected attachment', async () => {
  const f = fixture(); const request = await begin(f, 'text', 'old text');
  f.p.setPendingAttachmentState('document', 'new file', 'new preview', ['file:///new']);
  await settle(request, 'reject');
  assert.equal(f.p.composerDraftText, '');
  assert.deepEqual(f.p.pendingAttachmentUris, ['file:///new']);
  assert.equal(f.p.isSending, false);
});
for (const kind of ['text', 'forward']) test('failed old-account ' + kind + ' cannot restore buffers after reset', async () => {
  const f = fixture();
  const request = kind === 'text' ? await begin(f, 'text', 'account A text') : await beginForward(f, 'account A comment');
  await f.store.resetStateQueued();
  await settle(request, 'reject');
  assert.equal(f.p.composerDraftText, ''); assert.equal(f.p.isForwardingMessages, false);
  assert.equal(f.p.isSending, false);
});
const { forwardSendOwnershipTest } = load('../../ohosTest/ets/test/ForwardSendOwnership.test.ets', {
  ...td, ...text, ...forwarding, ...actions,
  describe: (_name, run) => run(), it: (name, _flags, run) => test('ohosTest: ' + name, run),
  expect: actual => ({ assertEqual: expected => assert.equal(actual, expected) })
});
forwardSendOwnershipTest();
let completed = false;
async function main() {
  let passed = 0, failed = 0;
  for (const t of tests) {
    try { await t.run(); passed++; }
    catch (error) { failed++; console.error('FAIL', t.name, error.message); }
    finally {
      for (const f of fixtures.splice(0)) {
        for (let i = 0; i < f.requests.length; i++) if (!f.requests[i].settled) await settle(f.requests[i]);
      }
    }
  }
  if (mutant) assert.ok(mutations > 0, 'requested mutation never engaged');
  completed = true; console.log(JSON.stringify({ passed, failed, mutant, mutations, sources })); process.exitCode = failed ? 1 : 0;
}
main().catch(error => { completed = true; console.error(error); process.exitCode = 2; });
process.on('beforeExit', () => { if (!completed) { console.error('Incomplete forward witness'); process.exitCode = 2; } });

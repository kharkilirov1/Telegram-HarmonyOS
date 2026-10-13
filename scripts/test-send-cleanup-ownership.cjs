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
function read(relative) {
  const source = readChatSource(path.join(root, relative), 'utf8');
  sources[relative] = createHash('sha256').update(source).digest('hex');
  return source;
}
function load(relative, deps = {}) {
  const source = read(relative);
  const names = [...source.matchAll(/^export\s+(?:class|function|const|enum)\s+(\w+)/gm)].map(m => m[1]);
  const code = source.replace(/^import[\s\S]*?;\s*/gm, '')
    .replace(/^export\s+\{[^}]*\};?\s*/gm, '')
    .replace(/^export\s+default\s+\w+;?\s*/gm, '').replace(/^export\s+/gm, '');
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
  'isSendingMessage', 'setSendingMessage', 'getSendOperationToken', 'hasActiveChatState', 'isEditModeActive', 'isForwardModeActive',
  'getComposerInputRevision', 'getDraftText', 'setDraftText', 'getDraftSelectionStart', 'getDraftSelectionEnd', 'setDraftSelection', 'getCustomEmojiEntities', 'setCustomEmojiEntities',
  'getReplyToMessageId', 'clearReplyMode', 'getPendingAttachmentUris', 'getPendingAttachmentKind',
  'setPendingAttachmentState', 'clearPendingAttachmentState', 'setEditMode', 'clearEditMode',
  'setForwardMode', 'clearForwardMode'
].forEach(include);
let sessionSendMutations = 0;
const PageProbe = process.argv.includes('--actual-delegates') ? require('./chat-screen-source.cjs').compileExports(
  require('./chat-screen-source.cjs').sourceGraph(path.join(root, 'ui/pages/chat/TgChatScreenPage.ets')),
  { selectChatInputPanel: policy.selectChatInputPanel }, source => {
    if (!process.argv.includes('--mutant-session-send')) return source;
    if (source.includes('host.sendingMessageOperation++;')) {
      assert.equal(source.split('host.sendingMessageOperation++;').length - 1, 1,
        'send negative control engages one actual operation owner');
      sessionSendMutations++;
    }
    return source.replace('host.sendingMessageOperation++;', '// Negative control: lost send operation retirement.');
  }).Session : new Function('selectChatInputPanel', stripTypeScriptTypes(
  `class PageProbe {
  slowmodeController = new globalThis.ChatSlowmodeController();
  composerSlowmodeSeconds = 0;\n${[...selected.values()].join('\n')}\n}`, { mode: 'transform' }) + '\nreturn PageProbe;'
)(policy.selectChatInputPanel);
assert.equal(sessionSendMutations, process.argv.includes('--mutant-session-send') ? 1 : 0,
  'send negative control changes the actual production export');
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
  const gateway = { send(command) {
    let resolve, reject;
    const promise = new Promise((ok, fail) => { resolve = ok; reject = fail; });
    requests.push({ command, resolve, reject, settled: false });
    return promise;
  } };
  const p = Object.assign(new PageProbe(), ui, {
    slowmodeController: new slowmodeFixtureDeps.ChatSlowmodeController(), composerSlowmodeSeconds: 0,
    accountStore: store.createScope(), activeChatId: ids[0], pageLifecycleToken: 1,
    sendingMessageOperation: 0, isSending: false, isEditingMessage: false, isForwardingMessages: false,
    editingMessageId: '0', editingOriginalText: '', composerInputRevision: 0, composerDraftText: '',
    composerSelectionStart: 0, composerSelectionEnd: 0, composerCaretRequestRevision: 0,
    customEmojiDraftEntities: [], expectedProgrammaticCustomEmojiText: '', replyToMessageId: '0',
    pendingAttachmentUris: [], pendingAttachmentKind: '', draftDebounceTimerId: -1,
    chatAccessUnavailable: false, scrolls: 0, toasts: 0,
    composerCtrl: new ChatComposerController(),
    sendUseCase: text.createSendMessageUseCase(gateway),
    sendMediaUseCase: media.createSendMediaMessageUseCase(gateway)
  });
  const f = { p, store, requests, ids, setPosting: post => store.dispatch(E.createGroupAccessUpdatedEvent(rights(123, post))) };
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
  else request.resolve(td.TdObject.fromJSON(JSON.stringify({ '@type': 'message', id: 900, chat_id: request.command.payload.chatId })));
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
test('actual owner revision getter returns the current revision rather than a fixed fixture value', () => {
  const f = fixture();
  f.p.composerInputRevision = 23;
  assert.equal(f.p.getComposerInputRevision(), 23);
  f.p.composerInputRevision = 24;
  assert.equal(f.p.getComposerInputRevision(), 24);
});
for (const kind of ['text', 'media']) {
  for (const type of ['private', 'channel']) {
    for (const outcome of ['resolve', 'reject']) {
      test(`${type} ${kind} ${outcome}: baseline cleanup permits a second send`, async () => {
        const f = fixture(type), first = await begin(f, kind, 'first');
        await settle(first, outcome);
        assert.equal(f.p.isSending, false);
        const second = await begin(f, kind, 'second');
        await settle(second);
        assert.equal(f.p.isSending, false);
      });
    }
  }
  for (const transition of ['private-edit', 'channel-edit', 'channel-revoke']) {
    for (const outcome of ['resolve', 'reject']) {
      test(`${kind} ${transition} ${outcome}: permission loss cannot retain busy ownership`, async () => {
        const f = fixture(transition.startsWith('private') ? 'private' : 'channel');
        const first = await begin(f, kind, 'first');
        if (transition.endsWith('edit')) f.p.setEditMode('5', 'editing buffer');
        else await f.setPosting(false);
        assert.equal(f.p.canSendNewMessages(), false);
        assert.equal(kind === 'text' ? f.p.getSendUseCase() : f.p.getSendMediaUseCase(), undefined);
        await settle(first, outcome);
        assert.equal(f.p.isSending, false, 'settled send must release busy despite a gated getter');
        if (transition.endsWith('edit')) {
          assert.equal(f.p.composerDraftText, 'editing buffer', 'old completion must preserve active editing');
          f.p.clearEditMode(true);
        } else await f.setPosting(true);
        assert.equal(f.p.canSendNewMessages(), true);
        const second = await begin(f, kind, 'second after restored permission');
        await settle(second);
        assert.equal(f.p.isSending, false);
      });
    }
  }
  for (const boundary of ['lifecycle', 'chat', 'both', 'roundtrip']) {
    for (const outcome of ['resolve', 'reject']) {
      test(`${kind} old ${outcome} after ${boundary}: never clear a newer send or its buffer`, async () => {
        const f = fixture(), first = await begin(f, kind, 'old scope');
        switchContext(f, boundary);
        const second = await begin(f, kind, 'new scope');
        const draft = f.p.composerDraftText, uris = f.p.pendingAttachmentUris.slice();
        const scrolls = f.p.scrolls, toasts = f.p.toasts;
        await settle(first, outcome);
        assert.equal(f.p.isSending, true, 'old finally must not clear the newer operation');
        assert.equal(f.p.composerDraftText, draft, 'old failure/success must not alter the new buffer');
        assert.deepEqual(f.p.pendingAttachmentUris, uris, 'old media success must not clear new attachments');
        assert.equal(f.p.scrolls, scrolls, 'old success must not schedule new-context scrolling');
        assert.equal(f.p.toasts, toasts, 'old failure must not show a new-context toast');
        assert.equal(f.requests.length, 2);
        await settle(second);
        assert.equal(f.p.isSending, false, 'only the new operation may release its busy flag');
      });
    }
  }
}

for (const oldKind of ['text', 'media']) {
  for (const outcome of ['resolve', 'reject']) {
    test(`${oldKind} old ${outcome} after roundtrip: newer opposite send kind owns cleanup`, async () => {
      const f = fixture(), first = await begin(f, oldKind, 'old operation');
      switchContext(f, 'roundtrip');
      const nextKind = oldKind === 'text' ? 'media' : 'text';
      const second = await begin(f, nextKind, 'new opposite operation');
      const draft = f.p.composerDraftText, uris = f.p.pendingAttachmentUris.slice();
      await settle(first, outcome);
      assert.equal(f.p.isSending, true, 'text/media operations must share completion ownership');
      assert.equal(f.p.composerDraftText, draft);
      assert.deepEqual(f.p.pendingAttachmentUris, uris);
      await settle(second);
      assert.equal(f.p.isSending, false);
    });
  }
}
for (const boundary of ['lifecycle', 'chat']) {
  for (const buffer of ['', 'new context draft']) {
    test(`old text reject after ${boundary} never restores into idle buffer ${JSON.stringify(buffer)}`, async () => {
      const f = fixture(), first = await begin(f, 'text', 'old account unsent text');
      switchContext(f, boundary);
      f.p.setDraftText(buffer);
      // No replacement send: operation identity alone cannot mask a missing
      // lifecycle/chat check when deciding whether to restore an old draft.
      await settle(first, 'reject');
      assert.equal(f.p.composerDraftText, buffer);
      assert.equal(f.p.customEmojiDraftEntities.length, 0);
      assert.equal(f.requests.length, 1);
    });
  }
}

test('text reject while posting remains forbidden restores unsent draft and entities', async () => {
  const f = fixture();
  const entity = new C.CustomEmojiTextEntity(0, 2, '123');
  f.p.setCustomEmojiEntities([entity]);
  const first = await begin(f, 'text', '\uD83D\uDE00 unsent text');
  assert.equal(f.p.composerDraftText, '');
  assert.equal(f.p.customEmojiDraftEntities.length, 0);
  await f.setPosting(false);
  await settle(first, 'reject');
  assert.equal(f.p.canSendNewMessages(), false);
  assert.equal(f.p.composerDraftText, '\uD83D\uDE00 unsent text');
  assert.equal(f.p.customEmojiDraftEntities.length, 1);
  assert.equal(f.p.customEmojiDraftEntities[0].customEmojiId, '123');
  assert.equal(f.p.isSending, false);
  f.p.handleSendMessage(f.p.composerDraftText);
  await tick();
  assert.equal(f.requests.length, 1, 'restoring a draft must not authorize sending');
});
for (const mode of ['edit', 'forward', 'new-draft']) {
  for (const buffer of mode === 'new-draft' ? ['new unsent draft'] : ['', 'active buffer']) {
    test(`text reject preserves ${mode} buffer ${JSON.stringify(buffer)}`, async () => {
      const f = fixture(), first = await begin(f, 'text', 'old unsent draft');
      await f.setPosting(false);
      if (mode === 'edit') f.p.setEditMode('5', buffer);
      if (mode === 'forward') f.p.setForwardMode(['9'], 7, 'Forward title', 'Forward preview');
      f.p.setDraftText(buffer);
      await settle(first, 'reject');
      assert.equal(f.p.composerDraftText, buffer);
      assert.equal(f.p.isSending, false);
      if (mode === 'edit') assert.equal(f.p.editingMessageId, '5');
      if (mode === 'forward') assert.deepEqual(f.p.forwardingMessageIds, ['9']);
    });
  }
}

test('media roundtrip/new operation prevents an old batch from sending its next item', async () => {
  const f = fixture(), old = await begin(f, 'media', 'old batch', 2);
  switchContext(f, 'roundtrip');
  const current = await begin(f, 'media', 'current batch');
  const uris = f.p.pendingAttachmentUris.slice();
  await settle(old);
  assert.equal(f.requests.length, 2, 'old batch must not enqueue item two');
  assert.equal(f.p.isSending, true);
  assert.deepEqual(f.p.pendingAttachmentUris, uris);
  await settle(current);
  assert.equal(f.p.isSending, false);
});

test('media prepare await followed by roundtrip/new operation cannot enqueue the old item', async () => {
  const f = fixture(), beforeCopy = copiedFiles;
  // Native copy is a fixture, but the real async prepare method and its await
  // remain intact. Switch synchronously before that continuation can resume.
  start(f, 'media', 'old preparation');
  assert.equal(copiedFiles, beforeCopy + 1, 'actual prepare path must engage');
  assert.equal(f.requests.length, 0);
  switchContext(f, 'roundtrip');
  const current = await begin(f, 'text', 'current text');
  assert.equal(f.requests.length, 1, 'old prepared media must not be sent');
  assert.equal(f.p.isSending, true);
  await settle(current);
  assert.equal(f.p.isSending, false);
});

let completed = false;
async function main() {
  let passed = 0, failed = 0;
  for (const { name, run } of tests) {
    const filter = process.argv.slice(2).find(arg => !arg.startsWith('--'));
    if (filter && !name.includes(filter)) continue;
    try {
      await run();
      console.log('PASS', name);
      passed++;
    } catch (error) {
      console.error('FAIL', name, error.stack);
      failed++;
    } finally {
      // Drain owned fixture requests even on RED; no unresolved test work can
      // masquerade as success or contaminate the next scenario.
      for (const f of fixtures.splice(0)) {
        for (let i = 0; i < f.requests.length; i++) {
          if (!f.requests[i].settled) await settle(f.requests[i]);
        }
      }
    }
  }
  assert.ok(passed + failed > 0, 'No ownership tests selected');
  console.log(JSON.stringify({ passed, failed, extractedMethods: [...selected.keys()], sources }));
  completed = true;
  process.exitCode = failed ? 1 : 0;
}
main().catch(error => { completed = true; console.error('HARNESS_ERROR', error); process.exitCode = 2; });
process.on('beforeExit', () => {
  if (!completed) { console.error('FAIL incomplete ownership test run'); process.exitCode = 2; }
});

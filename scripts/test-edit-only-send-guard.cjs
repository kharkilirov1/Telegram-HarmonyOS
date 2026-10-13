// Node >=24. Actual page callbacks/helpers, policy, controllers, use cases,
// commands and scoped AppStore. No SDK/build, network, device or account actions.
// Boundaries: fake gateway, hilog/UI effects, SDK, file I/O and clock/timers.
// Method extraction keeps new page permission helpers, never stubs their answers.
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
function read(p) {
  const source = readChatSource(path.join(root, p), 'utf8');
  sources[p] = createHash('sha256').update(source).digest('hex');
  return source;
}
function load(p, deps = {}) {
  const source = read(p);
  const names = [...source.matchAll(/^export\s+(?:class|function|const|enum)\s+(\w+)/gm)].map(m => m[1]);
  const code = source.replace(/^import[\s\S]*?;\s*/gm, '')
    .replace(/^export\s+\{[^}]*\};?\s*/gm, '')
    .replace(/^export\s+default\s+\w+;?\s*/gm, '').replace(/^export\s+/gm, '');
  const js = stripTypeScriptTypes(code, { mode: 'transform', sourceUrl: p });
  return new Function(...Object.keys(deps), js + `\nreturn {${names.join(',')}};`)(...Object.values(deps));
}
const logs = [];
const hilog = { info() {}, debug() {}, warn() {}, error(...args) { logs.push(args); } };
const platform = { hilog, localized: (_id, fallback) => fallback, $r: name => ({ id: name }) };
const C = load('core/model/AppCommand.ets');
const A = load('core/model/AppState.ets');
const td = load('models/td/common/index.ets');
const accessors = load('core/utils/tdAccessors.ets', td);
const G = load('core/model/dto/GroupAccessDto.ets', { ...td, ...accessors });
const E = load('core/model/AppEvent.ets', G);
const clones = load('core/utils/stateClone.ets', { ...A, ...G });
const { chatsReducer } = load('core/reducers/chatsReducer.ets', { ...A, ...E, ...G, ...clones, ...accessors });
const { AppStore } = load('core/store/AppStore.ets', { ...A, hilog });
const appErrors = load('core/model/AppError.ets');
const useCaseDeps = { ...C, ...appErrors, ...td, ...platform };
const text = load('domain/usecases/sendMessage.ets', useCaseDeps);
const album = load('domain/usecases/sendMediaAlbum.ets', { ...useCaseDeps, ...accessors });
const media = load('domain/usecases/sendMediaMessage.ets', { ...useCaseDeps, ...album });
const photoAlbum = load('ui/pages/chat/ChatPhotoAlbumController.ets', { ...appErrors, ...media, ...album, ...platform });
const editFormatting = load('domain/usecases/EditMessageFormatting.ets', { ...C, ...td });
const edit = load('domain/usecases/editMessage.ets', { ...useCaseDeps, ...editFormatting });
const stickers = load('domain/usecases/stickerPanel.ets', useCaseDeps);
const emoji = load('ui/tg_ui/utils/TgCustomEmojiDraftPolicy.ets', C);
const sequentialMedia = load('ui/pages/chat/ChatSequentialMediaController.ets', { ...appErrors, ...media, ...platform });
const textController = load('ui/pages/chat/ChatTextSendController.ets', { ...useCaseDeps, ...text, ...emoji });
const voicePolicy = load('ui/tg_ui/utils/TgVoiceRecordingPolicy.ets');
const policy = load('ui/pages/chat/ChatInputPanelPolicy.ets');
const attachmentFiles = load('ui/pages/chat/ChatAttachmentFilePreparer.ets', { ...platform, fileIo: {} });
const { ChatComposerController } = load('ui/pages/chat/ChatComposerController.ets', { ...appErrors, ...textController, ...sequentialMedia, ...text, ...media, ...photoAlbum, ...attachmentFiles, ...emoji, ...platform });
const editUI = load('ui/pages/chat/ChatEditMessageController.ets', { ...edit, ...platform });
const { ChatMessageActionsController } = load('ui/pages/chat/ChatMessageActionsController.ets', { ...text, ...edit, ...editUI, ...platform });
let voiceFixtures = [];
function createVoiceFixture() {
  const voice = { now: 100000, permissions: 0, recorders: [], files: [], closed: [], deleted: [],
    paths: new Set(), timers: new Map(), trace: [], violations: [], releaseGate: undefined };
  voiceFixtures.push(voice);
  function check(condition, message) {
    if (!condition) voice.violations.push(message);
    assert.ok(condition, message);
  }
  const fileIo = {
    OpenMode: { READ_WRITE: 1, CREATE: 2, TRUNC: 4 },
    accessSync: p => p === '/fixture/composer_voice' || voice.paths.has(p),
    mkdirSync() {},
    openSync(p) {
      const file = { fd: voice.files.length + 1, path: p };
      voice.files.push(file); voice.paths.add(p); return file;
    },
    closeSync(file) {
      check(voice.files.includes(file) && !voice.closed.includes(file.fd), 'close requires owned open FD');
      voice.closed.push(file.fd); voice.trace.push('close');
    },
    unlinkSync(p) {
      check(voice.paths.delete(p), 'unlink requires owned path'); voice.deleted.push(p);
    }
  };
  const sdkMedia = {
    CodecMimeType: { AUDIO_AAC: 1 }, ContainerFormatType: { CFT_MPEG_4A: 1 },
    AudioSourceType: { AUDIO_SOURCE_TYPE_MIC: 1 },
    async createAVRecorder() {
      const recorder = {
        state: 'idle',
        async prepare(config) {
          check(this.state === 'idle', 'prepare requires idle');
          check(voice.files.some(f => config.url === `fd://${f.fd}` && !voice.closed.includes(f.fd)),
            'prepare requires acquired FD');
          voice.trace.push('prepare'); this.state = 'prepared';
        },
        async start() {
          check(this.state === 'prepared', 'start requires prepared');
          voice.trace.push('start'); this.state = 'started';
        },
        async stop() {
          check(this.state === 'started', 'stop requires started');
          voice.trace.push('stop'); this.state = 'stopped';
        },
        async release() {
          check(this.state !== 'released', 'duplicate release');
          voice.trace.push('release');
          if (voice.releaseGate) await voice.releaseGate.promise;
          this.state = 'released'; voice.trace.push('released');
        }
      };
      voice.recorders.push(recorder); return recorder;
    }
  };
  let timer = 0;
  const { ChatVoiceRecordingController } = load('ui/pages/chat/ChatVoiceRecordingController.ets', {
    ...media, ...voicePolicy, ...platform, media: sdkMedia, fileIo,
    abilityAccessCtrl: { createAtManager: () => ({ async requestPermissionsFromUser() {
      voice.permissions++; return { authResults: [0] };
    } }) },
    Date: { now: () => voice.now },
    setInterval(fn) { voice.timers.set(++timer, fn); return timer; },
    clearInterval(id) { voice.timers.delete(id); }
  });
  voice.controller = new ChatVoiceRecordingController();
  return voice;
}

// These UI-only methods are explicit host boundaries. Permission/send methods
// and edit-state cleanup below are always extracted from the current page.
const ui = {
  setEmojiPanelVisible(value) { this.showComposerEmojiPanel = value; },
  resetStickerSearchState() {},
  resetGifSearchState() {},
  isNearBottom() { return false; },
  scrollToBottomSoon() {},
  getChatUIContext() { return { getHostContext: () => ({ filesDir: '/fixture' }),
    getPromptAction: () => ({ showToast() {} }) }; }
};
const page = read('ui/pages/chat/TgChatScreenPage.ets').replaceAll('\r\n', '\n');
const methodSources = new Map();
for (const match of page.matchAll(/^  (?:(?:private|public|protected|async)\s+)*(\w+)\s*\(/gm)) {
  const end = page.indexOf('\n  }', match.index);
  if (end < 0) continue; // Ignore the trailing route-builder component invocation.
  methodSources.set(match[1], page.slice(match.index, end + '\n  }'.length));
}
const selected = new Map();
function include(name) {
  if (selected.has(name) || Object.hasOwn(ui, name)) return;
  const source = methodSources.get(name);
  assert.ok(source, `required actual page method missing: ${name}`);
  selected.set(name, source);
  for (const dependency of source.matchAll(/\bthis\.(\w+)\s*\(/g)) include(dependency[1]);
}
[
  'deriveChatBottomBar', 'handleStickerSelected', 'handleSendMessage',
  'handleVoiceRecordStart', 'handleVoiceRecordSend',
  'getActiveChatId', 'getLifecycleToken', 'getSendUseCase', 'getSendMediaUseCase', 'getEditUseCase', 'getForwardUseCase',
  'isSendingMessage', 'setSendingMessage', 'getSendOperationToken', 'hasActiveChatState', 'isEditModeActive', 'isForwardModeActive',
  'submitEditMessage', 'getEditingMessageId', 'getEditingOriginalText', 'rebaseEditingMessage', 'clearEditMode',
  'getComposerInputRevision', 'getDraftText', 'setDraftText', 'getDraftSelectionStart', 'getDraftSelectionEnd', 'setDraftSelection',
  'getCustomEmojiEntities', 'setCustomEmojiEntities', 'getReplyToMessageId', 'clearReplyMode', 'clearForwardMode',
  'getPendingAttachmentUris', 'setVoiceRecordingState', 'setEditMode', 'setStickerPanelVisible'
].forEach(include);
const pageJs = stripTypeScriptTypes(`class PageProbe {
  slowmodeController = new globalThis.ChatSlowmodeController();
  composerSlowmodeSeconds = 0;\n${[...selected.values()].join('\n')}\n}`, { mode: 'transform' });
const deps = { ...policy, ...stickers, ...A, ...platform };
const PageProbe = new Function(...Object.keys(deps), pageJs + '; return PageProbe;')(...Object.values(deps));
const tick = () => new Promise(resolve => setImmediate(resolve));
function deferred() {
  let resolve;
  const promise = new Promise(done => { resolve = done; });
  return { promise, resolve };
}
function access(role = 'administrator', post = true, canEdit = true) {
  return Object.assign(new G.GroupAccessDto(), { groupId: 123, kind: 'supergroup', role,
    isMember: !['left', 'banned', 'unknown'].includes(role), canPostMessages: post, canEditMessages: canEdit });
}
function fixture({ type = 'channel', rights = access(), editing = false, editContentType = 'messageText' } = {}) {
  const voice = createVoiceFixture();
  const chat = Object.assign(new A.Chat(), { id: type === 'private' ? 7 : -100123, type,
    peerUserId: type === 'private' ? 7 : 0, supergroupId: type === 'channel' ? 123 : 0,
    basicGroupId: type === 'group' ? 123 : 0, canSendBasicMessages: true,
    sendPermissions: Object.assign(new G.GroupSendPermissionsDto(), Object.fromEntries(Object.keys(new G.GroupSendPermissionsDto()).map(k => [k, true]))) });
  const initial = A.createInitialAppState();
  initial.chats.chats.set(chat.id, chat);
  if (rights) initial.chats.supergroupAccess.set(123, rights);
  if (type === 'group') initial.chats.basicGroupAccess.set(123, Object.assign(new G.GroupAccessDto(), {
    kind: 'basicGroup', groupId: 123, role: 'member', isMember: true, isActive: true }));
  const store = new AppStore(chatsReducer, initial, false);
  const sent = [];
  const gateway = { send(command) {
    sent.push(command);
    if (command.type === 'getMessageProperties') return Promise.resolve(td.TdObject.fromJSON('{"@type":"messageProperties","can_be_edited":true}'));
    if (['getMessage', 'editMessageText', 'editMessageCaption'].includes(command.type)) return Promise.resolve(td.TdObject.fromJSON(JSON.stringify({
      '@type':'message', id:Number(command.payload.messageId), chat_id:command.payload.chatId,
      content:editContentType === 'messageText'
        ? {'@type':'messageText',text:{'@type':'formattedText',text:command.type === 'getMessage' ? 'original post' : command.payload.text,entities:[]},link_preview_options:null}
        : {'@type':editContentType,caption:{'@type':'formattedText',text:command.type === 'getMessage' ? 'original post' : command.payload.caption,entities:[]},show_caption_above_media:true}
    })));
    return Promise.resolve(td.TdObject.fromJSON(JSON.stringify({ '@type': 'message', id: 900, chat_id: command.payload.chatId })));
  } };
  const p = Object.assign(new PageProbe(), ui, {
    accountStore: store.createScope(), activeChatId: chat.id, pageLifecycleToken: 1,
    isEditingMessage: editing, editingMessageId: editing ? '5' : '0', editingOriginalText: 'original post',
    isForwardingMessages: false, sendingMessageOperation: 0, isSending: false, composerInputRevision: 0, composerDraftText: 'updated post',
    composerSelectionStart: 0, composerSelectionEnd: 12, composerCaretRequestRevision: 0,
    customEmojiDraftEntities: [], expectedProgrammaticCustomEmojiText: '', replyToMessageId: '0',
    pendingAttachmentUris: [], draftDebounceTimerId: -1, chatAccessUnavailable: false,
    composerCtrl: new ChatComposerController(), messageActionsCtrl: new ChatMessageActionsController(),
    voiceRecordingCtrl: voice.controller,
    sendUseCase: text.createSendMessageUseCase(gateway),
    sendMediaUseCase: media.createSendMediaMessageUseCase(gateway),
    editUseCase: edit.createEditMessageUseCase(gateway),
    forwardUseCase: { execute() { throw new Error('unexpected forwarding in this fixture'); } },
    stickerPanelUseCase: stickers.createStickerPanelUseCase(gateway)
  });
  p.deriveChatBottomBar(chat, p.accountStore.getState());
  return { p, store, sent, chat, voice, recordingStarts: () => voice.recorders.length,
    update: value => store.dispatch(E.createGroupAccessUpdatedEvent(value)) };
}
const cell = { remoteFileId: 'fixture-file', width: 64, height: 64, duration: 1, emoji: '', inlineQueryId: '0', inlineResultId: '' };
const actions = [
  ['sticker', f => f.p.handleStickerSelected({ ...cell, isGif: false }), 'sendSticker'],
  ['GIF', f => f.p.handleStickerSelected({ ...cell, isGif: true }), 'sendAnimation'],
  ['inline GIF', f => f.p.handleStickerSelected({ ...cell, isGif: true, inlineQueryId: '99', inlineResultId: 'gif' }), 'sendInlineQueryResult']
];
const newText = ['text', f => f.p.handleSendMessage('updated post'), 'sendMessage'];
async function prepareVoice(f) {
  // Enter through the actual page callback -> public begin -> real startup path.
  f.p.handleVoiceRecordStart(); await tick();
  assert.equal(f.p.voiceRecordingState, 'recording');
  assert.equal(f.voice.permissions, 1);
  assert.equal(f.voice.recorders.length, 1);
  assert.deepEqual(f.voice.trace, ['prepare', 'start']);
  f.voice.now += 1500;
}
const tests = [];
const test = (name, run) => tests.push({ name, run });
for (const [name, run] of actions) {
  test(`edit-only ${name}: no new send while editing`, async () => {
    const f = fixture({ rights: access('administrator', false, true), editing: true });
    assert.equal(f.p.chatBottomBarAction, 'none');
    assert.equal(f.p.chatBottomBarRestricted, false, 'edit-only text composer must remain available');
    run(f); await tick();
    assert.deepEqual(f.sent, [], 'edit permission must not grant new-message capability');
    assert.equal(f.p.editingMessageId, '5');
  });
}
test('edit-only text: successful edit stays editMessageText, never new send', async () => {
  const f = fixture({ rights: access('administrator', false, true), editing: true });
  f.p.handleSendMessage('updated post'); await tick();
  assert.deepEqual(f.sent.map(command => command.type), ['getMessage', 'getMessageProperties', 'editMessageText']);
  assert.equal(f.sent[2].payload.messageId, '5');
  assert.equal(f.sent[2].payload.text, 'updated post');
  assert.equal(f.p.isEditingMessage, false);
  assert.equal(f.p.chatBottomBarAction, 'mute');
});
test('edit-only text after cancelling edit: no new send or draft loss', async () => {
  const f = fixture({ rights: access('administrator', false, true), editing: true });
  f.p.clearEditMode(false);
  f.p.handleSendMessage('updated post'); await tick();
  assert.deepEqual(f.sent, []);
  assert.equal(f.p.composerDraftText, 'updated post');
});
test('actual setEditMode closes sticker panel and prevents reopening until ordinary composing', () => {
  const f = fixture();
  f.p.setStickerPanelVisible(true); assert.equal(f.p.showComposerStickerPanel, true);
  f.p.setEditMode('5', 'original post'); assert.equal(f.p.showComposerStickerPanel, false);
  f.p.setStickerPanelVisible(true); assert.equal(f.p.showComposerStickerPanel, false);
  assert.equal(f.p.getForwardUseCase(), undefined);
  f.p.clearEditMode(false);
  f.p.setStickerPanelVisible(true); assert.equal(f.p.showComposerStickerPanel, true);
  assert.equal(f.p.getForwardUseCase(), f.p.forwardUseCase);
});
for (const role of ['member', 'left', 'banned', 'unknown']) {
  for (const [name, run] of [...actions.slice(0, 2), newText]) {
    test(`${role} ${name}: captured callback cannot issue a new send`, async () => {
      const f = fixture({ rights: role === 'unknown' ? null : access(role, false, false) });
      run(f); await tick(); assert.deepEqual(f.sent, []);
    });
  }
}
for (const type of ['channel', 'private', 'group']) {
  for (const [name, run, command] of [...actions, newText]) {
    test(`${type} permitted ${name}: normal new-send path stays engaged`, async () => {
      const f = fixture({ type }); run(f); await tick();
      assert.deepEqual(f.sent.map(value => value.type), [command]);
      assert.equal(f.sent[0].payload.chatId, f.chat.id);
    });
  }
}
for (const [name, run] of [...actions, newText]) {
  test(`permission revoked before delayed ${name} callback: reread store, not cached composer`, async () => {
    const f = fixture();
    assert.equal(f.p.chatBottomBarAction, 'none');
    await f.update(access('administrator', false, false));
    // Deliberately do not derive the panel again: the rendered frame is stale.
    assert.equal(f.p.chatBottomBarAction, 'none');
    await tick(); run(f); await tick(); assert.deepEqual(f.sent, []);
  });
  test(`account reset before ${name} callback: stale scope cannot grant send`, async () => {
    const f = fixture(); f.store.resetState();
    run(f); await tick(); assert.deepEqual(f.sent, []);
  });
}
test('edit rights revoked before text callback: no edit or new send', async () => {
  const f = fixture({ rights: access('administrator', false, true), editing: true });
  await f.update(access('administrator', false, false));
  f.p.handleSendMessage('updated post'); await tick(); assert.deepEqual(f.sent, []);
});
for (const type of ['channel', 'private']) {
  test(`${type} permitted voice: actual voice controller reaches sendMediaMessage`, async () => {
    const f = fixture({ type }); await prepareVoice(f); f.p.handleVoiceRecordSend(); await tick();
    assert.deepEqual(f.sent.map(command => command.type), ['sendMediaMessage']);
    assert.equal(f.sent[0].payload.mediaKind, 'voice');
    assert.equal(f.sent[0].payload.localPath, f.voice.files[0].path);
    assert.deepEqual(f.voice.trace, ['prepare', 'start', 'stop', 'release', 'released', 'close']);
    assert.equal(f.p.voiceRecordingState, 'idle');
  });
}
test('edit-only voice start: no recorder preparation', async () => {
  const f = fixture({ rights: access('administrator', false, true), editing: true });
  f.p.handleVoiceRecordStart(); await tick(); assert.equal(f.recordingStarts(), 0);
  assert.equal(f.voice.permissions, 0); assert.equal(f.voice.files.length, 0);
});
test('edit-only captured voice-send callback: no new voice message', async () => {
  const f = fixture(); await prepareVoice(f);
  // A captured send callback survives the change from permitted recording to edit-only.
  await f.update(access('administrator', false, true));
  f.p.setEditMode('5', 'original post');
  f.p.handleVoiceRecordSend(); await tick(); assert.deepEqual(f.sent, []);
  assert.equal(f.voice.recorders[0].state, 'released'); assert.equal(f.voice.deleted.length, 1);
});
test('rights revoked during recorder release: fresh media accessor prevents late send', async () => {
  const f = fixture(); await prepareVoice(f);
  const release = deferred(); f.voice.releaseGate = release;
  f.p.handleVoiceRecordSend(); await tick();
  assert.deepEqual(f.voice.trace, ['prepare', 'start', 'stop', 'release']);
  assert.deepEqual(f.voice.closed, []); assert.deepEqual(f.sent, []);
  await f.update(access('administrator', false, false));
  release.resolve(); await tick(); assert.deepEqual(f.sent, []);
  assert.equal(f.voice.recorders[0].state, 'released'); assert.equal(f.voice.deleted.length, 1);
});
const atomSource = read('ui/tg_ui/atoms/TgComposerInput.ets').replaceAll('\r\n', '\n');
const atomMethods = new Map();
function includeAtom(name) {
  if (atomMethods.has(name) || ['onSendPress', 'onVoicePress', 'onVoiceRecordStart'].includes(name)) return;
  const match = new RegExp(`^  private ${name}\\(`, 'm').exec(atomSource);
  assert.ok(match, `required actual atom method missing: ${name}`);
  const end = atomSource.indexOf('\n  }', match.index);
  assert.ok(end > match.index);
  const source = atomSource.slice(match.index, end + '\n  }'.length);
  atomMethods.set(name, source);
  for (const dependency of source.matchAll(/\bthis\.(\w+)\s*\(/g)) includeAtom(dependency[1]);
}
['handleActionPress', 'beginVoiceRecordingGesture'].forEach(includeAtom);
const Atom = new Function(stripTypeScriptTypes(`class Atom {\n${[...atomMethods.values()].join('\n')}\n}`, { mode: 'transform' }) + ';return Atom;')();
function atomFixture(overrides = {}) {
  const calls = [];
  const atom = Object.assign(new Atom(), { text: '', isDisabled: false, sendEnabled: true, voiceEnabled: true, showEditSnippet: false,
    showForwardSnippet: false, showAttachmentSnippet: false, voiceRecordingState: 'idle',
    voiceClickSuppressionUntil: 0, textController: { stopEditing() { calls.push('stopEditing'); } },
    onSendPress(text) { calls.push(['send', text]); }, onVoicePress() { calls.push('voiceClick'); },
    onVoiceRecordStart() { calls.push('voiceStart'); }, ...overrides });
  return { atom, calls };
}
for (const value of ['', '   ']) {
  for (const method of ['handleActionPress', 'beginVoiceRecordingGesture']) {
    test(`actual atom ${method}: empty edit ${JSON.stringify(value)} never starts microphone`, () => {
      const f = atomFixture({ showEditSnippet: true, text: value });
      f.atom[method](); assert.deepEqual(f.calls, []);
    });
  }
}
test('actual atom: nonempty edit still invokes text send callback', () => {
  const f = atomFixture({ showEditSnippet: true, text: ' updated post ' });
  f.atom.handleActionPress(); assert.deepEqual(f.calls, [['send', 'updated post']]);
});
test('actual atom: empty caption edit submits removal and never starts voice', () => {
  const f = atomFixture({ showEditSnippet: true, allowEmptyEdit: true, text: '' });
  f.atom.handleActionPress(); f.atom.beginVoiceRecordingGesture();
  assert.deepEqual(f.calls, [['send', '']]);
});
test('actual caption menu → page binding → atom → page/composer/helper → caption mutation', async () => {
  const f = fixture({ rights: access('administrator', false, true), editContentType: 'messagePhoto' });
  f.p.messageActionsCtrl.handleMessageActionPress('edit', { message: {
    messageId:'5',isOutgoing:true,text:'',caption:'original post',contentType:'photo',senderName:''
  } }, f.p);
  assert.equal(f.p.editingAllowsEmpty, true);
  assert.match(page, /allowEmptyEdit: this\.editingAllowsEmpty/);
  f.p.setDraftText('');
  const a = atomFixture({ showEditSnippet:f.p.isEditingMessage,allowEmptyEdit:f.p.editingAllowsEmpty,
    text:f.p.getDraftText(),onSendPress:text => f.p.handleSendMessage(text) });
  a.atom.handleActionPress(); await tick();
  assert.deepEqual(f.sent.map(c => c.type), ['getMessage','getMessageProperties','editMessageCaption']);
  assert.equal(f.sent[2].payload.caption, '');
  assert.equal(f.sent[2].payload.showCaptionAboveMedia, true);
  assert.equal(f.p.isEditingMessage, false);
  assert.equal(f.p.editingAllowsEmpty, false);
  assert.equal(f.p.isSending, false);
});
test('actual atom: ordinary empty composer still supports voice click and hold', () => {
  const click = atomFixture(); click.atom.handleActionPress(); assert.deepEqual(click.calls, ['voiceClick']);
  const hold = atomFixture(); hold.atom.beginVoiceRecordingGesture(); assert.deepEqual(hold.calls, ['stopEditing', 'voiceStart']);
});
test('actual atom: disabled composer never sends or starts microphone', () => {
  for (const text of ['', 'draft']) {
    const f = atomFixture({ isDisabled: true, text });
    f.atom.handleActionPress(); f.atom.beginVoiceRecordingGesture(); assert.deepEqual(f.calls, []);
  }
});
let completed = false;
async function main() {
  let failed = 0;
  for (const { name, run } of tests) {
    voiceFixtures = [];
    try {
      await run();
      for (const voice of voiceFixtures) {
        assert.deepEqual(voice.violations, [], 'production catch must not hide SDK assertion failures');
        assert.equal(voice.timers.size, 0, 'voice timer leaked');
      }
      console.log('PASS', name);
    }
    catch (error) { failed++; console.error('FAIL', name, error.stack); }
  }
  console.log(JSON.stringify({ passed: tests.length - failed, failed, extractedMethods: [...selected.keys()], atomMethods: [...atomMethods.keys()], sources }));
  completed = true;
  process.exitCode = failed ? 1 : 0;
}
main().catch(error => { completed = true; console.error('HARNESS_ERROR', error); process.exitCode = 2; });
process.on('beforeExit', () => { if (!completed) { console.error('FAIL incomplete test run'); process.exitCode = 2; } });

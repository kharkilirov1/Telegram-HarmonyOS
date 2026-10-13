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
const mutantSpecs={
 transport:['core/events/normalizers/ChatNormalizer.ets','updates.sendPermissions = GroupSendPermissionsDto.fromTd(permissions);','updates.sendPermissions = new GroupSendPermissionsDto();'],
 selection:['ui/pages/chat/ChatInputPanelPolicy.ets','permitsKind(chat.sendPermissions, kinds[i])','true'],
 dispatch:['ui/pages/chat/TgChatScreenPage.ets',"this.canUseComposer(false, mediaKind || 'media')","this.canUseComposer(false)"],
 batch:['ui/pages/chat/ChatComposerController.ets','host.getSendMediaUseCase(mediaKind) === useCase','host.getSendMediaUseCase() === useCase'],
 hydration:['domain/usecases/loadChatAccess.ets','current !== undefined && current.sendPermissions === undefined','current !== undefined'],
 picker:['ui/pages/chat/ChatComposerController.ets','return generation === this.pickerGeneration && lifecycleToken === host.getLifecycleToken() &&\n      chatId === host.getActiveChatId() && host.hasActiveChatState();','return true;'],
 voice:['ui/tg_ui/atoms/TgComposerInput.ets','!this.voiceEnabled || ','']
};
assert.ok(!mutant||mutantSpecs[mutant]);let mutations=0;
function read(relative){let s=readChatSource(path.join(root,relative),'utf8').replaceAll('\r\n','\n');sources[relative]=createHash('sha256').update(s).digest('hex');const spec=mutantSpecs[mutant];if(spec&&spec[0]===relative){assert.ok(s.includes(spec[1]),'mutation target must engage');s=s.replace(spec[1],spec[2]);mutations++;}return s;}

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
const D = load('core/model/dto/ChatDto.ets', { ...C, ...G, ...accessors, hilog });
const E = load('core/model/AppEvent.ets', { ...G, ...D });
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
const pickerRequests=[];
function pickRequest(kind,options){return new Promise(resolve=>pickerRequests.push({kind,options,resolve}));}
const photoAccessHelper={PhotoViewMIMETypes:{IMAGE_TYPE:'image/*',VIDEO_TYPE:'video/*'},PhotoViewPicker:class{select(options){return pickRequest('gallery',options)}}};
const cameraPicker={PickerMediaType:{PHOTO:'photo',VIDEO:'video'},pick(_context,types){return pickRequest('camera',types)}};
const camera={CameraPosition:{CAMERA_POSITION_BACK:1}};
const picker={DocumentSelectOptions:class{},DocumentViewPicker:class{select(options){return pickRequest('document',options)}}};
const attachmentFiles = load('ui/pages/chat/ChatAttachmentFilePreparer.ets', { ...platform, fileIo: fileIo });
const { ChatComposerController } = load('ui/pages/chat/ChatComposerController.ets', {
  ...errors, ...textController, ...sequentialMedia, ...text, ...media, ...photoAlbum, ...attachmentFiles, ...emoji, ...platform, fileIo,photoAccessHelper,cameraPicker,camera,picker
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
  'getForwardModeState', 'getEditingMessageId', 'shouldReactToStoreChange'
].forEach(include);
if (methods.has('composerCanSubmit')) include('composerCanSubmit');
if (methods.has('composerAllows')) include('composerAllows');
if (methods.has('getSendOperationToken')) include('getSendOperationToken');
if (methods.has('hasActiveChatState')) include('hasActiveChatState');
const PageProbe = new Function('selectChatInputPanel', 'ChatForwardModeState', 'needsSupergroupBoosts', stripTypeScriptTypes(
  `class PageProbe {
  slowmodeController = new globalThis.ChatSlowmodeController();
  composerSlowmodeSeconds = 0;\n${[...selected.values()].join('\n')}\n}`, { mode: 'transform' }) + '\nreturn PageProbe;'
)(policy.selectChatInputPanel, actions.ChatForwardModeState, policy.needsSupergroupBoosts);
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
  const store = new AppStore(appReducer, state, false);
  const requests = [];
  const trace = [];
  const gateway = { forwardReads: false, send(command) {
    trace.push(command);
    // Only the forwarding fixture opts in; loadPermissions tests still defer getChat.
    if (this.forwardReads && command.type === 'getChat') return Promise.resolve(raw({
      '@type': 'chat', id: command.payload.chatId, type: { '@type': 'chatTypeBasicGroup' }
    }));
    if (this.forwardReads && command.type === 'getMessageProperties') return Promise.resolve(raw({
      '@type': 'messageProperties', can_be_forwarded: true, can_be_copied: true, can_be_copied_to_secret_chat: true
    }));
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
  const f = { p, store, requests, trace, ids, gateway, setPosting: post => store.dispatch(E.createGroupAccessUpdatedEvent(rights(123, post))) };
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
  else request.resolve(request.command.type === 'forwardMessages' ? td.TdObject.fromJSON(JSON.stringify({
    '@type': 'messages', messages: request.command.payload.messageIds.map((_id, i) =>
      ({ '@type': 'message', id: 900+i, chat_id: request.command.payload.chatId }))
  })) : {});
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



const unused=()=>{throw Error('unexpected domain reducer');};
const {appReducer}=load('core/reducers/index.ets',{chatsReducer,authReducer:unused,messagesReducer:unused,filesReducer:unused,usersReducer:unused,accentColorsReducer:unused});
const regs={};
for(const file of fs.readdirSync(path.join(root,'core/events/normalizers')).filter(f=>f.endsWith('.ets'))){
 const exp=load('core/events/normalizers/'+file,{...C,...td,...accessors,...D,...G,...E,hilog});
 for(const [key,value] of Object.entries(exp)) if(/^register\w+Handlers$/.test(key))regs[key]=value;
}
const {EventNormalizerImpl}=load('core/events/EventNormalizer.ets',{...regs,...accessors,hilog});
const {LoadChatAccessUseCase}=load('domain/usecases/loadChatAccess.ets',{...C,...G,...D,...E,...td});
const {ChatAccessController}=load('ui/pages/chat/ChatAccessController.ets');
const normalizer=new EventNormalizerImpl();
const raw=v=>td.TdObject.fromJSON(JSON.stringify(v));
function group(role='Member',active,fields={}){return {'@type':'basicGroup',id:123,is_active:arguments.length<2?true:active,status:{'@type':'chatMemberStatus'+role,...fields}};}
function basic(){
 const f=fixture('group');const chat=f.store.getState().chats.chats.get(f.p.activeChatId);chat.basicGroupId=123;
 f.chat=chat;return f;
}
async function live(f,g){const events=normalizer.normalize(raw({'@type':'updateBasicGroup',basic_group:g}));assert.equal(events.length,1,'actual normalizer must produce a live event');await f.store.dispatchBatch(events);}
function panel(f){const state=f.store.getState();f.p.deriveChatBottomBar(state.chats.chats.get(f.p.activeChatId),state);return f.p.chatBottomBarReason||(f.p.chatBottomBarRestricted?'restricted':f.p.chatBottomBarAction==='none'?'composer':f.p.chatBottomBarAction);}

const tests=[];const test=(name,run)=>tests.push({name,run});
const bits={can_send_basic_messages:'canSendBasicMessages',can_send_audios:'canSendAudios',can_send_documents:'canSendDocuments',can_send_photos:'canSendPhotos',can_send_videos:'canSendVideos',can_send_video_notes:'canSendVideoNotes',can_send_voice_notes:'canSendVoiceNotes',can_send_polls:'canSendPolls',can_send_other_messages:'canSendOtherMessages'};
const kinds={text:'can_send_basic_messages',audio:'can_send_audios',document:'can_send_documents',photo:'can_send_photos',video:'can_send_videos',videoNote:'can_send_video_notes',voice:'can_send_voice_notes',poll:'can_send_polls',other:'can_send_other_messages'};
const perms=(overrides={})=>({'@type':'chatPermissions',...Object.fromEntries(Object.keys(bits).map(k=>[k,false])),...overrides});
async function defaults(f,overrides){const events=normalizer.normalize(raw({'@type':'updateChatPermissions',chat_id:f.p.activeChatId,permissions:perms(overrides)}));assert.equal(events.length,1,'live default permissions must normalize');await f.store.dispatchBatch(events);}
async function ready(overrides={can_send_basic_messages:true}){const f=basic();await live(f,group());await defaults(f,overrides);return f;}
for(const [key,field] of Object.entries(bits)){
 test('initial/live/clone preserve independent '+key,async()=>{
  const tdChat=raw({'@type':'chat',id:-123,type:{'@type':'chatTypeBasicGroup',basic_group_id:123},permissions:perms({[key]:true})});
  const dto=D.createChatDtoFromTd(tdChat);assert.equal(dto.sendPermissions?.[field],true);
  const f=await ready({[key]:true});const chat=f.store.getState().chats.chats.get(f.p.activeChatId);assert.equal(chat.sendPermissions?.[field],true);
  const copy=clones.cloneChat(chat);assert.notEqual(copy.sendPermissions,chat.sendPermissions);assert.equal(copy.sendPermissions[field],true);
  const partial=D.applyChatUpdate(dto,Object.assign(new D.ChatUpdateDto(),{title:'unrelated'}));assert.equal(partial.sendPermissions[field],true);assert.notEqual(partial.sendPermissions,dto.sendPermissions);
 });
}
for(const [kind,key] of Object.entries(kinds))test(kind+'-only permits exactly that message kind and keeps composer',async()=>{
 const f=await ready({[key]:true});assert.equal(panel(f),'composer');
 const chat=f.store.getState().chats.chats.get(f.p.activeChatId),access=f.store.getState().chats.basicGroupAccess.get(123);
 for(const k of Object.keys(kinds))assert.equal(policy.selectChatInputPanel(chat,access,false,k)==='composer',k===kind,'unexpected '+k+' permission');
 assert.equal(f.p.getSendUseCase()!==undefined,kind==='text');
 for(const k of ['photo','video','document','voice'])assert.equal(f.p.getSendMediaUseCase(k)!==undefined,k===kind,'actual page getter '+k);
});
test('all denied is restricted; admin bypasses all sending defaults',async()=>{
 const f=await ready({});assert.equal(panel(f),'restricted');await live(f,group('Administrator'));assert.equal(panel(f),'composer');
 const chat=f.store.getState().chats.chats.get(f.p.activeChatId),access=f.store.getState().chats.basicGroupAccess.get(123);
 for(const kind of Object.keys(kinds))assert.equal(policy.selectChatInputPanel(chat,access,false,kind),'composer');
});
test('individual restriction intersects defaults per media bit',async()=>{
 const f=await ready({can_send_basic_messages:true,can_send_photos:true,can_send_videos:true});
 await live(f,group('Restricted',true,{is_member:true,permissions:perms({can_send_photos:true})}));
 assert.equal(panel(f),'composer');assert.equal(f.p.getSendUseCase(),undefined);assert.ok(f.p.getSendMediaUseCase('photo'));assert.equal(f.p.getSendMediaUseCase('video'),undefined);
});
test('denied photo never enters native file preparation or gateway while text remains available',async()=>{
 const f=await ready({can_send_basic_messages:true});f.p.setPendingAttachmentState('photo','photo','photo',['file:///a']);const before=copiedFiles;
 f.p.handleSendMessage('caption');await tick();assert.equal(f.requests.length,0);assert.equal(copiedFiles,before);assert.equal(f.p.pendingAttachmentUris.length,1);
});
test('photo-only chat sends a captioned photo, not a text message',async()=>{
 const f=await ready({can_send_photos:true});f.p.setPendingAttachmentState('photo','photo','photo',['file:///a']);f.p.handleSendMessage('caption');await tick();
 assert.equal(f.requests.length,1);assert.equal(f.requests[0].command.type,'sendMediaMessage');assert.equal(f.requests[0].command.payload.mediaKind,'photo');assert.equal(f.requests[0].command.payload.caption,'caption');
});
test('revoking document permission stops remaining sequential documents even when text permission survives',async()=>{
 // Photo multi-select now uses one album request; this legacy batch guard must
 // still stop the next separately sent document when its own permission is lost.
 const f=await ready({can_send_basic_messages:true,can_send_photos:true,can_send_documents:true});f.p.setPendingAttachmentState('document','document','document',['file:///a','file:///b']);f.p.handleSendMessage('caption');await tick();assert.equal(f.requests.length,1);
 assert.equal(f.requests[0].command.payload.mediaKind,'document');
 await defaults(f,{can_send_basic_messages:true,can_send_photos:true});await settle(f.requests[0]);assert.equal(f.requests.length,1);assert.equal(f.p.isSending,false);assert.ok(f.p.getSendUseCase());assert.ok(f.p.getSendMediaUseCase('photo'));assert.equal(f.p.getSendMediaUseCase('document'),undefined);
});
test('unknown defaults are not a fabricated all-media grant',async()=>{
 const f=basic();await live(f,group());assert.equal(panel(f),'unknown');assert.equal(f.p.getSendUseCase(),undefined);assert.equal(f.p.getSendMediaUseCase('photo'),undefined);
});
for(const kind of ['photo','video','voice','document'])test('live '+kind+' revoke changes actual capability without waiting for unrelated UI',async()=>{
 const f=await ready({[kinds[kind]]:true,can_send_basic_messages:true});assert.ok(f.p.getSendMediaUseCase(kind));await defaults(f,{can_send_basic_messages:true});assert.equal(f.p.getSendMediaUseCase(kind),undefined);
});
function composerProbe(){
 const s=read('ui/tg_ui/atoms/TgComposerInput.ets'),names=['hasText','hasPendingForward','hasPendingAttachment','hasSendIntent','canSend','isSlowmodeActive','isVoiceRecordingActive','handleSend','handleActionPress','beginVoiceRecordingGesture'];
 const parts=[];for(const name of names){const re=new RegExp('  private '+name+'\\(');const m=re.exec(s);if(m){const end=s.indexOf('\n  }',m.index);parts.push(s.slice(m.index,end+4));}}
 const Probe=new Function(stripTypeScriptTypes('class Probe {\n'+parts.join('\n')+'\n}',{mode:'transform'})+';return Probe;')();
 return Object.assign(new Probe(),{text:'',showForwardSnippet:false,showAttachmentSnippet:false,showEditSnippet:false,isDisabled:false,sendEnabled:true,voiceEnabled:true,voiceRecordingState:'idle',voiceClickSuppressionUntil:0,textController:{stopEditing(){}},sent:0,voice:0,recorded:0,onSendPress(){this.sent++},onVoicePress(){this.voice++},onVoiceRecordStart(){this.recorded++}});
}
test('disabled text intent cannot turn into send or microphone action',()=>{const c=composerProbe();c.text='draft';c.sendEnabled=false;c.handleActionPress();c.beginVoiceRecordingGesture();assert.equal(c.sent,0);assert.equal(c.voice,0);assert.equal(c.recorded,0);});
test('voice flag blocks click and recording gesture',()=>{const c=composerProbe();c.voiceEnabled=false;c.handleActionPress();c.beginVoiceRecordingGesture();assert.equal(c.voice,0);assert.equal(c.recorded,0);});
test('enabled media caption and ordinary voice retain their actions',()=>{const c=composerProbe();c.showAttachmentSnippet=true;c.text='caption';c.handleActionPress();assert.equal(c.sent,1);c.showAttachmentSnippet=false;c.text='';c.handleActionPress();assert.equal(c.voice,1);});
let done=false;
const {basicGroupMediaTest}=load('../../ohosTest/ets/test/BasicGroupMedia.test.ets',{
 ...td,...G,...D,...E,...A,...clones,EventNormalizerImpl,appReducer,AppStore,...policy,
 describe:(_name,run)=>run(),it:(name,_flags,run)=>test('ohosTest: '+name,run),
 expect:actual=>({assertEqual:expected=>assert.equal(actual,expected)})
});
basicGroupMediaTest();
test('recent forbidden photo cannot become attachment in text-only chat',async()=>{
 const f=await ready();f.p.composerCtrl.handleRecentAttachmentPress({uri:'file:///a',isVideo:false},f.p);assert.equal(f.p.pendingAttachmentUris.length,0);
});
test('video-only gallery requests videos and accepts only a current result',async()=>{
 const f=await ready({can_send_videos:true});f.p.composerCtrl.handleAttachmentMenuItemPress(0,f.p);await tick();
 const req=pickerRequests.pop();assert.equal(req.options.MIMEType,'video/*');req.resolve({photoUris:['file:///v']});await tick();
 assert.equal(f.p.pendingAttachmentKind,'video');assert.equal(f.p.pendingAttachmentUris.length,1);
});
for(const boundary of ['revoke','chat','lifecycle'])test('pending picker result cannot cross '+boundary,async()=>{
 const f=await ready({can_send_photos:true});f.p.composerCtrl.handleAttachmentMenuItemPress(0,f.p);await tick();const req=pickerRequests.pop();assert.ok(req);
 if(boundary==='revoke')await defaults(f,{});else switchContext(f,boundary);
 req.resolve({photoUris:['file:///old']});await tick();assert.equal(f.p.pendingAttachmentUris.length,0);
});
test('camera requests only allowed video and rejected document never opens native picker',async()=>{
 const f=await ready({can_send_videos:true});f.p.composerCtrl.handleAttachmentMenuItemPress(1,f.p);await tick();const req=pickerRequests.pop();assert.deepEqual(req.options,['video']);req.resolve({resultCode:0,resultUri:'file:///v',mediaType:'video'});await tick();assert.equal(f.p.pendingAttachmentKind,'video');
 const before=pickerRequests.length;f.p.composerCtrl.handleAttachmentMenuItemPress(2,f.p);await tick();assert.equal(pickerRequests.length,before);
});
function source(f,kind){f.gateway.forwardReads=true;const m=Object.assign(new A.Message(),{id:'11',chatId:7,content:Object.assign(new A.MessageContent(),{type:kind})});f.store.getState().messages.messages.set(7,new Map([['11',m]]));f.p.setForwardMode(['11'],7,'source','preview');}
test('photo-only forwards photo but never text or unknown source',async()=>{
 const f=await ready({can_send_photos:true});source(f,'unknown');assert.equal(f.p.getForwardUseCase(),undefined);source(f,'text');assert.equal(f.p.getForwardUseCase(),undefined);
 source(f,'photo');assert.ok(f.p.getForwardUseCase());f.p.handleSendMessage('');await tick();assert.equal(f.requests.length,1);assert.equal(f.requests[0].command.type,'forwardMessages');
 assert.deepEqual(f.trace.map(c=>c.type),['getChat','getMessageProperties','getChat','getMessageProperties','forwardMessages']);
 assert.deepEqual(f.trace.filter(c=>c.type==='getChat').map(c=>c.payload.chatId),[f.p.activeChatId,f.p.activeChatId]);
 assert.deepEqual(f.trace.filter(c=>c.type==='getMessageProperties').map(c=>[c.payload.chatId,c.payload.messageId]),[[7,'11'],[7,'11']]);
});
test('captured forward kind is rechecked after comment before forwarding',async()=>{
 const f=await ready({can_send_basic_messages:true,can_send_photos:true});source(f,'photo');f.p.handleSendMessage('comment');await tick();assert.equal(f.requests.length,1);assert.equal(f.requests[0].command.type,'sendMessage');
 assert.deepEqual(f.trace.map(c=>c.type),['getChat','getMessageProperties','sendMessage']);
 await defaults(f,{can_send_basic_messages:true});await settle(f.requests[0]);assert.equal(f.requests.length,1);assert.equal(f.p.isSending,false);
 assert.deepEqual(f.trace.map(c=>c.type),['getChat','getMessageProperties','sendMessage']);
});
test('empty pending media kind cannot fall through to document transport',async()=>{
 const f=await ready({can_send_photos:true});const before=copiedFiles;f.p.setPendingAttachmentState('','bad','bad',['file:///a']);f.p.handleSendMessage('caption');await tick();assert.equal(f.requests.length,0);assert.equal(copiedFiles,before);
});
test('latest picker owns the result even in the same chat',async()=>{
 const f=await ready({can_send_photos:true});f.p.composerCtrl.handleAttachmentMenuItemPress(0,f.p);await tick();const first=pickerRequests.pop();
 f.p.composerCtrl.handleAttachmentMenuItemPress(0,f.p);await tick();const second=pickerRequests.pop();second.resolve({photoUris:['file:///new']});await tick();first.resolve({photoUris:['file:///old']});await tick();assert.deepEqual(f.p.pendingAttachmentUris,['file:///new']);
});
test('live per-kind UI snapshot changes even when panel stays composer',async()=>{
 const f=await ready({can_send_basic_messages:true,can_send_photos:true});panel(f);
 assert.equal(f.p.composerAllows('photo'),true);const previous=f.p.composerAllowedKinds;
 await defaults(f,{can_send_basic_messages:true});panel(f);assert.equal(f.p.composerAllows('photo'),false);
 assert.equal(f.p.composerAllows('text'),true);assert.notEqual(f.p.composerAllowedKinds,previous);
 assert.match(page,/@Trace composerAllowedKinds: string\[\]/);
});
test('unrelated title update does not discard pending default hydration',async()=>{
 const f=basic();await live(f,group());const uc=new LoadChatAccessUseCase(f.store,f.gateway);const pending=uc.loadPermissions(f.p.activeChatId);await tick();
 await f.store.dispatch(E.createChatUpdatedEvent(f.p.activeChatId,Object.assign(new D.ChatUpdateDto(),{title:'renamed'})));
 const req=f.requests[0];req.settled=true;req.resolve(raw({'@type':'chat',id:f.p.activeChatId,permissions:perms({can_send_photos:true})}));await pending;assert.ok(f.p.getSendMediaUseCase('photo'));assert.equal(f.store.getState().chats.chats.get(f.p.activeChatId).title,'renamed');
});
test('unknown defaults hydrate exact getChat and retain live updates over late response',async()=>{
 const f=basic();await live(f,group());const uc=new LoadChatAccessUseCase(f.store,f.gateway);
 const pending=uc.loadPermissions(f.p.activeChatId);assert.equal(uc.loadPermissions(f.p.activeChatId),pending);await tick();
 assert.equal(f.requests.length,1);const req=f.requests[0];assert.equal(req.command.type,'getChat');assert.equal(req.command.payload.chatId,f.p.activeChatId);
 await defaults(f,{can_send_photos:true});req.settled=true;req.resolve(raw({'@type':'chat',id:f.p.activeChatId,permissions:perms({can_send_basic_messages:true})}));await pending;
 assert.equal(f.p.getSendUseCase(),undefined);assert.ok(f.p.getSendMediaUseCase('photo'));
});
test('unknown defaults resolve through status then permissions stage without auto retry loop',async()=>{
 const f=basic();const uc=new LoadChatAccessUseCase(f.store,f.gateway);let ctl;let changes=0;
 const observe=()=>{changes++;const state=f.store.getState();ctl.observe(state.chats.chats.get(f.p.activeChatId),state.chats.basicGroupAccess.get(123));};
 ctl=new ChatAccessController(uc,observe);observe();await tick();assert.equal(f.requests[0].command.type,'getBasicGroup');
 f.requests[0].settled=true;f.requests[0].resolve(raw(group()));await tick();await tick();
 assert.equal(f.requests.length,2);assert.equal(f.requests[1].command.type,'getChat');
 f.requests[1].settled=true;f.requests[1].resolve(raw({'@type':'chat',id:f.p.activeChatId,permissions:perms({can_send_photos:true})}));await tick();await tick();
 assert.equal(panel(f),'composer');assert.equal(ctl.isUnavailable(),false);observe();await tick();assert.equal(f.requests.length,2);ctl.dispose();
});
test('malformed permissions hydration fails visibly and explicit retry can recover',async()=>{
 const f=basic();await live(f,group());const uc=new LoadChatAccessUseCase(f.store,f.gateway);let ctl;
 const observe=()=>{const state=f.store.getState();ctl.observe(state.chats.chats.get(f.p.activeChatId),state.chats.basicGroupAccess.get(123));};
 ctl=new ChatAccessController(uc,observe);observe();await tick();assert.equal(f.requests.length,1);
 f.requests[0].settled=true;f.requests[0].resolve(raw({'@type':'chat',id:f.p.activeChatId,permissions:{can_send_basic_messages:'true'}}));await tick();await tick();
 assert.equal(ctl.isUnavailable(),true);observe();await tick();assert.equal(f.requests.length,1);
 ctl.retry();await tick();assert.equal(f.requests.length,2);f.requests[1].settled=true;f.requests[1].resolve(raw({'@type':'chat',id:f.p.activeChatId,permissions:perms({can_send_videos:true})}));await tick();await tick();assert.equal(ctl.isUnavailable(),false);assert.ok(f.p.getSendMediaUseCase('video'));ctl.dispose();
});
(async()=>{let passed=0,failed=0;for(const t of tests){try{await t.run();passed++;}catch(e){failed++;console.error('FAIL',t.name,e.message);}finally{for(const f of fixtures.splice(0)){for(const request of f.requests)if(!request.settled){request.settled=true;request.resolve({});}await tick();}}}if(mutant)assert.ok(mutations>0,'mutant must engage actual source');done=true;console.log(JSON.stringify({passed,failed,mutant,mutations,sources}));process.exitCode=failed?1:0;})().catch(e=>{done=true;console.error(e);process.exitCode=2});
process.on('beforeExit',()=>{if(!done)process.exitCode=2});

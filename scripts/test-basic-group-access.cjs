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
assert.ok(!mutant || ['ignore-activity','wrong-map','no-subscription','channel-hydration','drop-activity-clone','relax-active-parser'].includes(mutant));
let mutations=0;
function read(relative){
  let source=readChatSource(path.join(root,relative),'utf8').replaceAll('\r\n','\n');
  sources[relative]=createHash('sha256').update(source).digest('hex');let from,to;
  if(relative==='ui/pages/chat/ChatInputPanelPolicy.ets' && mutant==='ignore-activity'){from='!access.isActive || ';to='';}
  if(relative==='ui/pages/chat/TgChatScreenPage.ets'){
    if(mutant==='wrong-map'){from='state.chats.basicGroupAccess';to='state.chats.supergroupAccess';}
    if(mutant==='no-subscription'){from="    if (chat?.type === 'group' && newState.chats.basicGroupAccess.get(chat.basicGroupId) !==\n      prevState.chats.basicGroupAccess.get(chat.basicGroupId)) return true;";to='';}
  }
  if(relative==='ui/pages/chat/ChatAccessController.ets' && mutant==='channel-hydration'){from='this.useCase.load(groupKind, groupId)';to="this.useCase.load('supergroup', groupId)";}
  if(relative==='core/utils/stateClone.ets' && mutant==='drop-activity-clone'){from='  copy.isActive = access.isActive;';to='';}
  if(relative==='core/model/dto/GroupAccessDto.ets' && mutant==='relax-active-parser'){from="td.getTopLevelBooleanStrict('is_active')";to="td.getBool('is_active')";}
  if(from){assert.ok(source.includes(from),'mutation must engage '+mutant);mutations+=(source.split(from).length-1);source=source.replaceAll(from,to);}
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
  'getForwardModeState', 'getEditingMessageId', 'shouldReactToStoreChange'
].forEach(include);
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
  const gateway = { send(command) {
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
  const f = { p, store, requests, ids, gateway, setPosting: post => store.dispatch(E.createGroupAccessUpdatedEvent(rights(123, post))) };
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
const {LoadChatAccessUseCase}=load('domain/usecases/loadChatAccess.ets',{...C,...G,...E,...td});
const {ChatAccessController}=load('ui/pages/chat/ChatAccessController.ets');
const normalizer=new EventNormalizerImpl();
const raw=v=>td.TdObject.fromJSON(JSON.stringify(v));
function group(role='Member',active,fields={}){return {'@type':'basicGroup',id:123,is_active:arguments.length<2?true:active,status:{'@type':'chatMemberStatus'+role,...fields}};}
function basic(){
 const f=fixture('group');const chat=f.store.getState().chats.chats.get(f.p.activeChatId);chat.basicGroupId=123;
 chat.sendPermissions=Object.assign(new G.GroupSendPermissionsDto(),Object.fromEntries(Object.keys(new G.GroupSendPermissionsDto()).map(k=>[k,true])));
 f.chat=chat;return f;
}
async function live(f,g){const events=normalizer.normalize(raw({'@type':'updateBasicGroup',basic_group:g}));assert.equal(events.length,1,'actual normalizer must produce a live event');await f.store.dispatchBatch(events);}
function panel(f){const state=f.store.getState();f.p.deriveChatBottomBar(state.chats.chats.get(f.p.activeChatId),state);return f.p.chatBottomBarReason||(f.p.chatBottomBarRestricted?'restricted':f.p.chatBottomBarAction==='none'?'composer':f.p.chatBottomBarAction);}
const tests=[];const test=(name,run)=>tests.push({name,run});
for(const [role,fields,active,basicAllowed,expected] of [
 ['Creator',{is_member:true},true,false,'composer'],['Administrator',{},true,false,'composer'],
 ['Member',{},true,true,'composer'],['Member',{},true,false,'restricted'],
 ['Left',{},true,true,'banned'],['Banned',{},true,true,'banned'],
 ['Creator',{is_member:false},true,true,'banned'],
 ['Creator',{is_member:true},false,true,'banned'],['Administrator',{},false,true,'banned'],
 ['Member',{},false,true,'banned'],
 ['Restricted',{is_member:true,permissions:{can_send_basic_messages:false}},true,true,'restricted']
]) test(role+'/'+active+'/'+basicAllowed+' panel and real action guard',async()=>{
 const f=basic();f.chat.canSendBasicMessages=basicAllowed;for(const key of Object.keys(f.chat.sendPermissions))f.chat.sendPermissions[key]=basicAllowed;await live(f,group(role,active,fields));
 assert.equal(panel(f),expected);f.p.handleSendMessage('fixture text');await tick();
 assert.equal(f.requests.length,expected==='composer'?1:0);
 assert.equal(f.p.getSendMediaUseCase()!==undefined,expected==='composer');
 assert.equal(f.p.getForwardUseCase()!==undefined,expected==='composer');
});
test('unknown basic group never borrows same-ID channel administrator access',()=>{
 const f=basic();assert.equal(panel(f),'unknown');assert.equal(f.p.getSendUseCase(),undefined);
});
for(const id of [0,-1,1.5,'123',9007199254740992])test('invalid basic id '+id+' cannot grant or expose dead retry',async()=>{
 const f=basic();await live(f,group('Creator',true,{is_member:true}));f.chat=f.store.getState().chats.chats.get(f.p.activeChatId);f.chat.basicGroupId=id;f.p.chatAccessUnavailable=true;
 assert.equal(panel(f),'unknown');assert.equal(f.p.getSendUseCase(),undefined);
});
for(const active of [true,false])test('strict activity '+active+' reaches cloned store',async()=>{
 const f=basic();const parsed=G.createGroupAccessDtoFromTd(raw(group('Member',active)),'basicGroup');
 assert.equal(parsed.isActive,active);await live(f,group('Member',active));
 const stored=f.store.getState().chats.basicGroupAccess.get(123);assert.equal(stored.isActive,active);
 const cloned=clones.cloneGroupAccess(stored);assert.equal(cloned.isActive,active);assert.notEqual(cloned,stored);
});
for(const active of [undefined,null,'true',1,[],{}])test('malformed activity '+JSON.stringify(active)+' is not authoritative',()=>{
 const value=group('Member',active);value.nested={is_active:true};
 assert.equal(G.createGroupAccessDtoFromTd(raw(value),'basicGroup'),undefined);
});
test('nested activity cannot shadow explicit false',()=>{const value={nested:{is_active:true},...group('Member',false)};assert.equal(G.createGroupAccessDtoFromTd(raw(value),'basicGroup').isActive,false);});
test('only active basic-group map entry wakes actual subscription gate',async()=>{
 const f=basic();await live(f,group());const before=f.store.getState();await live(f,{...group('Banned'),id:999});const other=f.store.getState();
 assert.equal(f.p.shouldReactToStoreChange(other,before),false);
 await live(f,group('Banned'));const after=f.store.getState();assert.equal(f.p.shouldReactToStoreChange(after,other),true);
 assert.equal(panel(f),'banned');
});
test('late member response cannot overwrite live kicked state',async()=>{
 const f=basic();const usecase=new LoadChatAccessUseCase(f.store,f.gateway);const pending=usecase.load('basicGroup',123);await tick();
 await live(f,group('Banned'));f.requests[0].settled=true;f.requests[0].resolve(raw(group()));await pending;
 assert.equal(panel(f),'banned');
});
function accessController(f){let notifications=0;const controller=new ChatAccessController(new LoadChatAccessUseCase(f.store,f.gateway),()=>{notifications++;});return {controller,get notifications(){return notifications;}};}
test('deactivation during an in-flight media batch stops the next send and releases busy',async()=>{
 const f=basic();await live(f,group());f.p.setPendingAttachmentState('document','fixture','fixture',['file:///a','file:///b']);
 f.p.handleSendMessage('caption');await tick();assert.equal(f.requests.length,1);assert.equal(f.requests[0].command.type,'sendMediaMessage');
 await live(f,group('Member',false));assert.equal(f.p.getSendMediaUseCase(),undefined);await settle(f.requests[0]);
 assert.equal(f.requests.length,1);assert.equal(f.p.isSending,false);assert.equal(panel(f),'banned');
});
test('a live inactive basic-group status consumes pending hydration UI before a late failure',async()=>{
 const f=basic();const c=accessController(f);c.controller.observe(f.chat);await tick();assert.equal(f.requests.length,1);
 await live(f,group('Member',false));c.controller.observe(f.chat,f.store.getState().chats.basicGroupAccess.get(123));
 f.requests[0].settled=true;f.requests[0].reject(new Error('old hydration failed'));await tick();
 assert.equal(c.controller.isUnavailable(),false);assert.equal(c.notifications,0);assert.equal(panel(f),'banned');
});
test('unknown basic group hydrates exact getBasicGroup once then grants member',async()=>{
 const f=basic();const c=accessController(f);
 for(let i=0;i<8;i++)c.controller.observe(f.chat);await tick();
 assert.equal(f.requests.length,1);assert.equal(f.requests[0].command.type,'getBasicGroup');assert.equal(f.requests[0].command.payload.basicGroupId,123);
 f.requests[0].settled=true;f.requests[0].resolve(raw(group()));await tick();
 assert.equal(c.notifications,1);assert.equal(panel(f),'composer');
});
test('malformed activity failure exposes bounded explicit retry',async()=>{
 const f=basic();const c=accessController(f);c.controller.observe(f.chat);await tick();assert.equal(f.requests.length,1);
 f.requests[0].settled=true;f.requests[0].resolve(raw(group('Member',undefined)));await tick();
 assert.equal(c.controller.isUnavailable(),true);f.p.chatAccessUnavailable=true;assert.equal(panel(f),'retry');
 c.controller.retry();await tick();assert.equal(f.requests.length,2);f.requests[1].settled=true;f.requests[1].resolve(raw(group()));await tick();
 assert.equal(c.controller.isUnavailable(),false);assert.equal(panel(f),'composer');
});
test('channel to basic same-number identity starts a distinct request',async()=>{
 const f=basic();const c=accessController(f);c.controller.observe({...f.chat,type:'channel',supergroupId:123});await tick();
 c.controller.observe(f.chat);await tick();assert.equal(f.requests.length,2);assert.equal(f.requests[1].command.type,'getBasicGroup');
 f.requests[0].settled=true;f.requests[0].resolve(raw({'@type':'supergroup',id:123,status:{'@type':'chatMemberStatusMember'}}));await tick();assert.equal(c.notifications,0);
 f.requests[1].settled=true;f.requests[1].resolve(raw(group()));await tick();assert.equal(c.notifications,1);
});
test('old account basic-group hydration cannot repopulate new state',async()=>{
 const f=basic();const c=accessController(f);c.controller.observe(f.chat);await tick();assert.equal(f.requests.length,1);
 await f.store.resetStateQueued();f.requests[0].settled=true;f.requests[0].resolve(raw(group()));await tick();
 assert.equal(f.store.getState().chats.basicGroupAccess.size,0);assert.equal(f.p.getSendUseCase(),undefined);
});
const {basicGroupAccessTest}=load('../../ohosTest/ets/test/BasicGroupAccess.test.ets',{
  ...td,...G,...A,...clones,EventNormalizerImpl,appReducer,AppStore,LoadChatAccessUseCase,ChatAccessController,...policy,
  describe:(_name,run)=>run(),it:(name,_flags,run)=>test('ohosTest: '+name,run),
  expect:actual=>({assertEqual:expected=>assert.equal(actual,expected)})
});
basicGroupAccessTest();
let done=false;
(async()=>{let passed=0,failed=0;for(const t of tests){try{await t.run();passed++;}catch(e){failed++;console.error('FAIL',t.name,e.message);}finally{for(const f of fixtures.splice(0)){for(const request of f.requests)if(!request.settled){request.settled=true;request.resolve(raw(group()));}await tick();}}}if(mutant)assert.ok(mutations>0);done=true;console.log(JSON.stringify({passed,failed,mutant,mutations,sources}));process.exitCode=failed?1:0;})().catch(e=>{done=true;console.error(e);process.exitCode=2;});
process.on('beforeExit',()=>{if(!done)process.exitCode=2});

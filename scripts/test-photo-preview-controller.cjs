#!/usr/bin/env node
// Actual preview/composer/coordinator/usecase/Context/preparer code. Native I/O,
// gateway, UI and preparation delays are explicit host fixtures, never SDK proof.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { createHash } = require('node:crypto');
const { stripTypeScriptTypes } = require('node:module');
const root = path.resolve(__dirname, '../entry/src/main/ets');
const mutationAt = process.argv.indexOf('--mutation');
const mutation = mutationAt >= 0 ? process.argv[mutationAt + 1] : undefined;
const sources = new Map();
const mutations = {
  'remove-noop': ['ui/pages/chat/ChatComposerController.ets', 'next.splice(index, 1);', '/* mutation: removal omitted */'],
  'direction-reversed': ['ui/pages/chat/ChatComposerController.ets', 'const target = index + direction;', 'const target = index - direction;'],
  'revision-disabled': ['ui/pages/chat/ChatScreenContext.ets', 'if (this.view.composer.pendingAttachmentUris !== value) this.composerInputRevision++;', '/* mutation: selection revision omitted */'],
  'consumption-disabled': ['ui/pages/chat/ChatPhotoAlbumController.ets', 'private isSameSubmittedSelection(attempt: PhotoAlbumAttempt): boolean {', 'private isSameSubmittedSelection(attempt: PhotoAlbumAttempt): boolean { return false;'],
  'accepted-mode-unguarded': ['ui/pages/chat/ChatPhotoAlbumController.ets', 'if (!this.canSubmit(host, attempt)) return;\n      host.setCustomEmojiEntities([]);', 'if (!this.isCurrentOwner(host, attempt) || !this.hasSameInput(host, attempt)) return;\n      host.setCustomEmojiEntities([]);'],
  'cancel-unguarded': ['ui/pages/chat/ChatComposerController.ets', "if (host.getPendingAttachmentKind() === 'photo' && !this.canEditPendingPhotos(host)) return;", '/* mutation: cancel guard omitted */'],
  'picker-snapshot-unguarded': ['ui/pages/chat/ChatComposerController.ets', 'return this.isPickerContextActive(host, lifecycleToken, chatId, generation) &&\n      host.getSendMediaUseCase(kind) === mediaUseCase && host.getComposerInputRevision() === inputRevision &&\n      !host.isSendingMessage() && !host.isEditModeActive() && !host.isForwardModeActive();', 'return this.isPickerContextActive(host, lifecycleToken, chatId, generation);']
};
if (mutation !== undefined) assert.ok(mutations[mutation], 'Known explicit mutation required');
function load(relative, dependencies = {}) {
  const file = path.join(root, relative), raw = fs.readFileSync(file, 'utf8');
  sources.set(file, raw);
  let source = raw.replaceAll('\r\n','\n');
  if (mutation !== undefined && mutations[mutation][0] === relative) {
    const [, before, after] = mutations[mutation];
    assert.ok(source.includes(before), 'Mutation must target actual source');
    source = source.replace(before, after);
  }
  const names = [...source.matchAll(/^export\s+(?:class|function|const|enum)\s+(\w+)/gm)].map(m => m[1]);
  const code = source.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+\{[^}]*\};?\s*/gm, '')
    .replace(/^export\s+/gm, '').replace(/^@ObservedV2\s*\r?\n/gm, '').replace(/^(\s*)@Trace\s+/gm, '$1');
  const js = stripTypeScriptTypes(code, { mode: 'transform', disableExperimentalWarning: true });
  return new Function(...Object.keys(dependencies), js + '\nreturn {' + names.join(',') + '};')(...Object.values(dependencies));
}
const hilog = { info() {}, debug() {}, error() {}, warn() {} };
const platform = { hilog, localized: (_id, fallback) => fallback, $r: id => ({ id }),
  TgUiTokens: { COLOR_TEXT_TITLE_RESOURCE_NAME: 'text_primary', COLOR_ICON_PRIMARY_RESOURCE_NAME: 'telegram_blue' } };
const C = load('core/model/AppCommand.ets'), td = load('models/td/common/index.ets'), errors = load('core/model/AppError.ets');
const album = load('domain/usecases/sendMediaAlbum.ets', { ...C, ...td, ...errors, hilog });
const media = load('domain/usecases/sendMediaMessage.ets', { ...C, ...td, ...errors, ...album, hilog });
const coordinator = load('ui/pages/chat/ChatPhotoAlbumController.ets', { ...errors, ...media, ...album, ...platform });
const textController = load('ui/pages/chat/ChatTextSendController.ets', { ...errors, ...platform });
const sequentialMedia = load('ui/pages/chat/ChatSequentialMediaController.ets', { ...errors, ...media, ...platform });
const { ChatScreenContext } = load('ui/pages/chat/ChatScreenContext.ets');
const { ChatComposerState } = load('ui/pages/chat/ChatComposerState.ets');
const adapters = load('ui/pages/chat/ChatComposerHostAdapters.ets');
const actionAdapters = load('ui/pages/chat/ChatMessageActionHostAdapters.ets');
const tick = () => new Promise(resolve => setImmediate(resolve));
async function settle() { for (let i = 0; i < 10; i++) await tick(); }
function deferred() { let resolve, reject; const promise = new Promise((a,b) => { resolve=a; reject=b; }); return { promise, resolve, reject }; }
function nativePortFixture() {
  const files = new Map(), directories = new Set(), handles = new Map(), opened = [], closed = [], copies = [], unlinks = [];
  let sequence = 100;
  const flags = { partialCopy: false, closeFails: false, unlinkFails: false };
  const io = {
    OpenMode: { READ_ONLY: 0 }, accessSync: p => files.has(p) || directories.has(p), mkdirSync: p => { directories.add(p); },
    openSync(uri) { if (!files.has(uri)) throw new Error('Source absent'); const file = { fd: ++sequence }; handles.set(file.fd, uri); opened.push(uri); return file; },
    copyFileSync(fd, target) {
      const source = handles.get(fd); assert.ok(source, 'copy requires open fixture fd'); copies.push({ source, target });
      const bytes = files.get(source);
      if (flags.partialCopy) { files.set(target, bytes.subarray(0,2)); flags.partialCopy=false; throw new Error('Injected partial-copy failure'); }
      files.set(target, Buffer.from(bytes));
    },
    closeSync(file) { closed.push(file.fd); if (flags.closeFails) { flags.closeFails=false; throw new Error('Injected close failure'); } handles.delete(file.fd); },
    unlinkSync(p) { unlinks.push(p); if (flags.unlinkFails) { flags.unlinkFails=false; throw new Error('Injected unlink failure'); } files.delete(p); }
  };
  return { io, files, directories, handles, opened, closed, copies, unlinks, flags };
}
function fixture(uris = ['file://media/a.jpg','file://media/b.jpg','file://media/c.jpg']) {
  const native = nativePortFixture();
  const { ChatAttachmentFilePreparer } = load('ui/pages/chat/ChatAttachmentFilePreparer.ets', { fileIo: native.io, hilog, Date: { now: () => 42 } });
  const st = { active: true, permitted: true, context: { filesDir: '/owned/A', resourceManager: { getColorByNameSync: () => 0xff3390ec } },
    copies: [], dialogs: [], responses: [], toasts: [], calls: [], transport: [], pause: undefined, cleared: 0, scrolled: 0, contextError: false,
    pickerRequests: [], pickerOptions: [], pickerConstructed: 0 };
  class DeferredNativePortPreparer extends ChatAttachmentFilePreparer {
    async prepare(kind, uri, context) {
      st.copies.push({ kind, uri, context }); const pause=st.pause; st.pause=undefined;
      if (pause) await pause.promise;
      return super.prepare(kind,uri,context);
    }
  }
  // Only the public PhotoViewPicker port is mocked; entry, snapshot and catch
  // handling are the actual production composer methods.
  const photoAccessHelper = { PhotoViewMIMETypes: { IMAGE_TYPE:'image/*', VIDEO_TYPE:'video/*' },
    PhotoViewPicker: class { constructor(){st.pickerConstructed++;} select(options){const pending=deferred();st.pickerOptions.push(options);st.pickerRequests.push(pending);return pending.promise;} } };
  const { ChatComposerController } = load('ui/pages/chat/ChatComposerController.ets', { ...errors, ...textController, ...sequentialMedia, ...coordinator, ...media, ...platform, photoAccessHelper, ChatAttachmentFilePreparer: DeferredNativePortPreparer });
  const context = Object.create(ChatScreenContext.prototype);
  context.view = { composer: new ChatComposerState(), chrome: {}, panels: {} };
  context.activeChatId=-10071; context.pageLifecycleToken=1; context.sendingMessageOperation=0;
  context.composerInputRevision=0; context.draftEmojiEntities=[]; context.composerDraftText='caption'; context.replyToMessageId='88'; context.isSending=false;
  context.setDraftSelection=(a,b)=>adapters.setDraftSelection(context,a,b);
  context.setStickerPanelVisible=value=>{context.view.panels.showComposerStickerPanel=value;};
  context.refreshChatInputPanel=()=>{};
  context.sendMediaUseCase=media.createSendMediaMessageUseCase({ send(command) {
    st.calls.push(command); const next=st.transport.shift(); if(next)return next(command);
    const paths=command.type==='sendMediaAlbum'?command.payload.localPaths:[command.payload.localPath];
    const entries=paths.map((_path,i)=>`{"@type":"message","id":${101+i},"chat_id":${command.payload.chatId}}`);
    return Promise.resolve(td.TdObject.fromJSON(command.type==='sendMediaAlbum'?`{"@type":"messages","messages":[${entries.join(',')}]}`:entries[0]));
  } });
  const host = {
    canSendNewMessages: () => st.permitted,
    getActiveChatId:()=>context.activeChatId, getLifecycleToken:()=>context.pageLifecycleToken,
    getSendMediaUseCase:()=>st.permitted?context.sendMediaUseCase:undefined, getSendUseCase:()=>undefined, hasActiveChatState:()=>st.active,
    getComposerInputRevision:()=>context.composerInputRevision, getSendOperationToken:()=>context.sendingMessageOperation,
    isSendingMessage:()=>context.isSending, setSendingMessage:value=>adapters.setSendingMessage(context,value),
    isEditModeActive:()=>context.isEditingMessage, isForwardModeActive:()=>context.isForwardingMessages,
    getDraftText:()=>context.composerDraftText, setDraftText:text=>{context.composerDraftText=text;},
    getReplyToMessageId:()=>context.replyToMessageId, clearReplyMode:()=>{context.replyToMessageId='0';},
    getCustomEmojiEntities:()=>context.customEmojiDraftEntities, setCustomEmojiEntities:value=>{context.customEmojiDraftEntities=value;},
    setDraftSelection:(a,b)=>{context.composerSelectionStart=a;context.composerSelectionEnd=b;}, setEmojiPanelVisible:value=>{context.showComposerEmojiPanel=value;},
    getPendingAttachmentUris:()=>context.pendingAttachmentUris, getPendingAttachmentKind:()=>context.pendingAttachmentKind,
    setPendingAttachmentState:(...args)=>adapters.setPendingAttachmentState(context,...args),
    clearPendingAttachmentState:()=>{st.cleared++;adapters.clearPendingAttachmentState(context);}, isNearBottom:()=>true, scrollToBottomSoon:()=>st.scrolled++,
    getChatUIContext() {
      if(st.contextError)throw new Error('Fixture UIContext gone');
      return { getHostContext:()=>st.context, getPromptAction:()=>({
        showDialog:options=>{st.dialogs.push(options);return st.responses.shift()??Promise.resolve({index:0});}, showToast:options=>st.toasts.push(options)
      }) };
    }
  };
  const composer=new ChatComposerController();
  function select(next) { for(const uri of next)if(!native.files.has(uri))native.files.set(uri,Buffer.from('photo:'+uri));adapters.setPendingAttachmentState(context,'photo','Photo','fixture selection',next.slice()); }
  select(uris);
  return { native,st,context,host,composer,select,send:()=>composer.handleSendMessage(context.composerDraftText,host),
    openPicker:()=>composer.handleAttachmentMenuItemPress(0,host),ChatAttachmentFilePreparer };
}
const tests=[],test=(name,fn)=>tests.push({name,fn});
function snapshot(f){return{uris:f.context.pendingAttachmentUris,revision:f.context.composerInputRevision,text:f.context.composerDraftText,reply:f.context.replyToMessageId,entities:f.context.customEmojiDraftEntities};}
function unchangedInput(f,before){assert.equal(f.context.composerDraftText,before.text);assert.equal(f.context.replyToMessageId,before.reply);assert.equal(f.context.customEmojiDraftEntities,before.entities);}
for(const index of[0,1,2])test('remove URI position '+index+' preserves order and input',()=>{
  const f=fixture(),before=snapshot(f);f.composer.removePendingPhoto(before.uris[index],f.host);
  assert.deepEqual(f.context.pendingAttachmentUris,before.uris.filter((_uri,i)=>i!==index));assert.notEqual(f.context.pendingAttachmentUris,before.uris);assert.equal(before.uris.length,3);
  assert.ok(f.context.composerInputRevision>before.revision);assert.equal(f.context.pendingAttachmentTitle,'Photo');assert.equal(f.context.pendingAttachmentPreview,(index===0?'b.jpg':'a.jpg')+' +1');unchangedInput(f,before);
});
test('remove sole photo clears media selection while preserving caption/reply',async()=>{
  const f=fixture(['file://media/a.jpg']),before=snapshot(f);f.composer.removePendingPhoto(before.uris[0],f.host);
  assert.deepEqual(f.context.pendingAttachmentUris,[]);assert.equal(f.context.pendingAttachmentKind,'');assert.equal(f.context.pendingAttachmentTitle,'');assert.equal(f.context.pendingAttachmentPreview,'');
  unchangedInput(f,before);f.send();await settle();assert.equal(f.st.calls.length,0);assert.equal(f.st.copies.length,0);
});
test('stale URI cannot remove another photo at the former index',()=>{
  const f=fixture(),old=f.context.pendingAttachmentUris[0];f.select(['file://media/new.jpg','file://media/b.jpg']);const before=snapshot(f);f.composer.removePendingPhoto(old,f.host);
  assert.equal(f.context.pendingAttachmentUris,before.uris);assert.equal(f.context.composerInputRevision,before.revision);
});
for(const[uri,direction,expected]of[
  ['file://media/b.jpg',-1,['file://media/b.jpg','file://media/a.jpg','file://media/c.jpg']],
  ['file://media/b.jpg',1,['file://media/a.jpg','file://media/c.jpg','file://media/b.jpg']],
  ['file://media/c.jpg',-1,['file://media/a.jpg','file://media/c.jpg','file://media/b.jpg']]
])test('move '+uri+' by '+direction+' makes fresh adjacent swap',()=>{
  const f=fixture(),before=snapshot(f);f.composer.movePendingPhoto(uri,direction,f.host);assert.deepEqual(f.context.pendingAttachmentUris,expected);assert.notEqual(f.context.pendingAttachmentUris,before.uris);
  assert.ok(f.context.composerInputRevision>before.revision);unchangedInput(f,before);
});
for(const direction of[0,2,-2,1.5,NaN,Infinity])test('invalid direction '+direction+' is no-op',()=>{
  const f=fixture(),before=snapshot(f);f.composer.movePendingPhoto(before.uris[1],direction,f.host);assert.equal(f.context.pendingAttachmentUris,before.uris);assert.equal(f.context.composerInputRevision,before.revision);
});
test('edge and missing URI moves preserve state/revision',()=>{
  const f=fixture(),before=snapshot(f);for(const[uri,d]of[[before.uris[0],-1],[before.uris[2],1],['absent',1]])f.composer.movePendingPhoto(uri,d,f.host);
  assert.equal(f.context.pendingAttachmentUris,before.uris);assert.equal(f.context.composerInputRevision,before.revision);
});
for(const[name,change]of[
  ['busy',f=>{f.context.isSending=true;}],['zero chat',f=>{f.context.activeChatId=0;}],['inactive chat',f=>{f.st.active=false;}],['revoked permission',f=>{f.st.permitted=false;}],
  ['document selection',f=>{f.context.pendingAttachmentKind='document';}],['edit',f=>{f.context.isEditingMessage=true;}],['forward',f=>{f.context.isForwardingMessages=true;}]
])for(const action of['remove','move'])test(name+' blocks '+action,()=>{
  const f=fixture();change(f);const before=snapshot(f);if(action==='remove')f.composer.removePendingPhoto(before.uris[1],f.host);else f.composer.movePendingPhoto(before.uris[1],-1,f.host);
  assert.equal(f.context.pendingAttachmentUris,before.uris);assert.equal(f.context.composerInputRevision,before.revision);unchangedInput(f,before);
});
test('remove/reorder sends exact resulting order through actual album usecase',async()=>{
  const f=fixture();f.composer.removePendingPhoto('file://media/b.jpg',f.host);f.composer.movePendingPhoto('file://media/c.jpg',-1,f.host);f.send();await settle();assert.equal(f.st.calls.length,1);
  const command=f.st.calls[0];assert.equal(command.type,'sendMediaAlbum');assert.deepEqual(f.st.copies.map(c=>c.uri),['file://media/c.jpg','file://media/a.jpg']);assert.deepEqual(command.payload.localPaths,f.native.copies.map(c=>c.target));
  assert.equal(command.payload.caption,'caption');assert.equal(command.payload.replyToMessageId,'88');assert.equal(command.payload.chatId,-10071);assert.equal(f.native.handles.size,0);assert.equal(f.context.isSending,false);assert.equal(f.st.cleared,1);
  assert.equal(f.native.files.get('file://media/a.jpg').toString(),'photo:file://media/a.jpg');
});
test('remove down to one uses actual single-message usecase once',async()=>{
  const f=fixture(['file://media/a.jpg','file://media/b.jpg']);f.composer.removePendingPhoto('file://media/a.jpg',f.host);f.send();await settle();assert.equal(f.st.calls.length,1);assert.equal(f.st.calls[0].type,'sendMediaMessage');
  assert.equal(f.st.calls[0].payload.mediaKind,'photo');assert.equal(f.st.calls[0].payload.localPath,f.native.copies[0].target);assert.deepEqual(f.st.copies.map(c=>c.uri),['file://media/b.jpg']);assert.equal(f.st.cleared,1);
});
test('photo selection de-duplicates exact URI preserving first occurrence order',()=>{
  const f=fixture();f.composer.setPendingAttachment('photo','Photo',['file://media/b.jpg','file://media/a.jpg','file://media/b.jpg'],f.host);assert.deepEqual(f.context.pendingAttachmentUris,['file://media/b.jpg','file://media/a.jpg']);
});
test('move and undo during deferred prep cannot submit old ABA snapshot',async()=>{
  const f=fixture(),pause=deferred();f.st.pause=pause;f.send();await settle();f.context.isSending=false;f.composer.movePendingPhoto('file://media/b.jpg',-1,f.host);f.composer.movePendingPhoto('file://media/b.jpg',1,f.host);
  pause.resolve();await settle();assert.equal(f.st.calls.length,0);assert.equal(f.native.copies.length,1);assert.equal(f.native.files.has(f.native.copies[0].target),false);assert.equal(f.context.pendingAttachmentUris.length,3);
});
test('captured file context cannot drift on route replacement; stale copy discarded',async()=>{
  const f=fixture(),original=f.st.context,pause=deferred();f.st.pause=pause;f.send();await settle();f.st.context={filesDir:'/owned/B',resourceManager:original.resourceManager};f.context.pageLifecycleToken++;
  pause.resolve();await settle();assert.equal(f.st.calls.length,0);assert.equal(f.st.copies[0].context,original);assert.ok(f.native.copies[0].target.startsWith('/owned/A/'));assert.equal(f.native.files.has(f.native.copies[0].target),false);
});
test('UIContext failure before dispatch does not strand busy',async()=>{
  const f=fixture();f.st.contextError=true;f.send();await settle();assert.equal(f.st.calls.length,0);assert.equal(f.context.isSending,false);assert.equal(f.st.copies.length,0);assert.equal(f.context.pendingAttachmentUris.length,3);
});
for(const count of[1,2])for(const mode of['forward','edit'])test('accepted '+count+' photo request preserves actual '+mode+' adapter input and later confirms overlap',async()=>{
  const f=fixture(count===1?['file://media/a.jpg']:['file://media/a.jpg','file://media/b.jpg']),pending=deferred();
  f.context.replyToMessageId='0';f.st.transport.push(()=>pending.promise);f.send();await settle();assert.equal(f.st.calls.length,1);
  const revision=f.context.composerInputRevision;
  if(mode==='forward')actionAdapters.setForwardMode(f.context,['901'],-10099,'Forward','forward preview');
  else actionAdapters.setEditMode(f.context,'901','edited caption');
  if(mode==='forward')assert.equal(f.context.composerInputRevision,revision+1,'actual forward adapter advances revision for the mode transition');
  const entered=snapshot(f);
  const messages=Array.from({length:count},(_v,i)=>`{"@type":"message","id":${101+i},"chat_id":-10071}`);
  pending.resolve(td.TdObject.fromJSON(count===1?messages[0]:`{"@type":"messages","messages":[${messages.join(',')}]}`));await settle();
  assert.equal(f.st.cleared,0);assert.equal(f.context.pendingAttachmentUris,entered.uris);unchangedInput(f,entered);assert.equal(f.context.isSending,false);
  if(mode==='forward')actionAdapters.clearForwardMode(f.context);else actionAdapters.clearEditMode(f.context,false);
  const copies=f.st.copies.length;f.send();await settle();assert.equal(f.st.calls.length,1);assert.equal(f.st.copies.length,copies);assert.match(f.st.dialogs.at(-1).message,/duplicates/);
});
for(const[name,change]of[
  ['busy',f=>f.host.setSendingMessage(true)],['zero chat',f=>{f.context.activeChatId=0;}],['inactive route',f=>{f.st.active=false;}],
  ['permission revoked',f=>{f.st.permitted=false;}],['edit mode',f=>actionAdapters.setEditMode(f.context,'901','caption')],
  ['forward mode',f=>actionAdapters.setForwardMode(f.context,['901'],-10099,'Forward','preview')]
])test('photo snippet Cancel cannot bypass '+name+' edit guard',()=>{
  const f=fixture();change(f);const before=snapshot(f);f.composer.clearPendingAttachment(f.host);assert.equal(f.st.cleared,0);
  assert.equal(f.context.pendingAttachmentUris,before.uris);assert.equal(f.context.composerInputRevision,before.revision);unchangedInput(f,before);
});
test('allowed photo snippet Cancel clears only media selection',()=>{
  const f=fixture(),before=snapshot(f);f.composer.clearPendingAttachment(f.host);assert.equal(f.st.cleared,1);assert.deepEqual(f.context.pendingAttachmentUris,[]);unchangedInput(f,before);
});
test('non-photo snippet Cancel retains existing clear behavior',()=>{
  const f=fixture(),before=snapshot(f);f.context.pendingAttachmentKind='document';f.composer.clearPendingAttachment(f.host);assert.equal(f.st.cleared,1);assert.deepEqual(f.context.pendingAttachmentUris,[]);unchangedInput(f,before);
});
const pickerChanges=[
  ['caption ABA',f=>{const original=f.context.composerDraftText;f.context.composerDraftText='changed';f.context.composerDraftText=original;}],
  ['selection replaced',f=>f.select(['file://media/replacement.jpg'])],
  ['usecase identity changed',f=>{f.context.sendMediaUseCase=media.createSendMediaMessageUseCase({send(){throw new Error('Unexpected replacement gateway send');}});}],
  ['busy began',f=>f.host.setSendingMessage(true)],['permission revoked',f=>{f.st.permitted=false;}],
  ['forward mode',f=>actionAdapters.setForwardMode(f.context,['901'],-10099,'Forward','preview')],
  ['edit mode',f=>actionAdapters.setEditMode(f.context,'901','edited caption')],
  ['lifecycle changed',f=>{f.context.pageLifecycleToken++;}],['chat changed',f=>{f.context.activeChatId=-10072;}],
  ['route inactive',f=>{f.st.active=false;}]
];
for(const[name,change]of pickerChanges)for(const rejects of[false,true])test('actual picker '+(rejects?'catch':'result')+' ignores '+name,async()=>{
  const f=fixture();f.openPicker();await settle();assert.equal(f.st.pickerRequests.length,1);change(f);const before=snapshot(f),toasts=f.st.toasts.length;
  if(rejects)f.st.pickerRequests[0].reject(new Error('Picker provider error'));else f.st.pickerRequests[0].resolve({photoUris:['file://media/new-a.jpg','file://media/new-b.jpg']});
  await settle();assert.equal(f.context.pendingAttachmentUris,before.uris);assert.equal(f.context.composerInputRevision,before.revision);unchangedInput(f,before);
  assert.equal(f.st.toasts.length,toasts,'stale provider errors must not publish feedback');assert.equal(f.st.calls.length,0);assert.equal(f.st.copies.length,0);
});
for(const[name,change]of[
  ['initial busy',f=>f.host.setSendingMessage(true)],['initial revoked permission',f=>{f.st.permitted=false;}],
  ['initial forward',f=>actionAdapters.setForwardMode(f.context,['901'],-10099,'Forward','preview')],['initial edit',f=>actionAdapters.setEditMode(f.context,'901','caption')]
])test(name+' never opens PhotoViewPicker',async()=>{
  const f=fixture();change(f);const before=snapshot(f);f.openPicker();await settle();assert.equal(f.st.pickerConstructed,0);assert.equal(f.st.pickerRequests.length,0);assert.equal(f.context.pendingAttachmentUris,before.uris);
});
test('current picker result keeps ordered exact-URI dedup and does not send',async()=>{
  const f=fixture();f.openPicker();await settle();assert.equal(f.st.pickerOptions[0].MIMEType,'image/*');assert.equal(f.st.pickerOptions[0].maxSelectNumber,10);
  f.st.pickerRequests[0].resolve({photoUris:['file://media/new-b.jpg','file://media/new-a.jpg','file://media/new-b.jpg']});await settle();
  assert.deepEqual(f.context.pendingAttachmentUris,['file://media/new-b.jpg','file://media/new-a.jpg']);assert.equal(f.context.pendingAttachmentPreview,'new-b.jpg +1');assert.equal(f.st.calls.length,0);assert.equal(f.st.copies.length,0);
});
test('empty native-picker result preserves existing selected photos',async()=>{
  const f=fixture(),before=snapshot(f);f.openPicker();f.st.pickerRequests[0].resolve({photoUris:[]});await settle();assert.equal(f.context.pendingAttachmentUris,before.uris);assert.equal(f.st.toasts.length,0);
});
test('current picker cancellation publishes no error toast or selection change',async()=>{
  const f=fixture(),before=snapshot(f);f.openPicker();f.st.pickerRequests[0].reject(new Error('User cancelled picker'));await settle();assert.equal(f.context.pendingAttachmentUris,before.uris);assert.equal(f.st.toasts.length,0);
});
test('current non-cancellation provider error shows one toast without changing selection',async()=>{
  const f=fixture(),before=snapshot(f);f.openPicker();f.st.pickerRequests[0].reject(new Error('Provider unavailable'));await settle();assert.equal(f.context.pendingAttachmentUris,before.uris);assert.equal(f.st.toasts.length,1);
});
test('superseded picker generation cannot publish or toast over the latest request',async()=>{
  const f=fixture(),before=snapshot(f);f.openPicker();f.openPicker();f.st.pickerRequests[0].resolve({photoUris:['file://media/old.jpg']});await settle();assert.equal(f.context.pendingAttachmentUris,before.uris);
  f.st.pickerRequests[1].resolve({photoUris:['file://media/latest.jpg']});await settle();assert.deepEqual(f.context.pendingAttachmentUris,['file://media/latest.jpg']);assert.equal(f.st.toasts.length,0);
});
async function unknown(f){f.st.transport.push(()=>Promise.reject(new Error('Fixture acceptance unknown')));f.send();await settle();}
for(const[name,next]of[['reorder',['file://media/b.jpg','file://media/a.jpg']],['subset',['file://media/b.jpg']],['overlap',['file://media/b.jpg','file://media/new.jpg']]])test('unknown '+name+' cannot silently resend consumed URI',async()=>{
  const f=fixture(['file://media/a.jpg','file://media/b.jpg']);await unknown(f);f.select(next);const copies=f.st.copies.length;f.send();await settle();assert.equal(f.st.calls.length,1);assert.equal(f.st.copies.length,copies);assert.match(f.st.dialogs.at(-1).message,/duplicates/);assert.equal(f.context.isSending,false);
});
test('Cancel on overlapping singleton copies/sends zero; explicit confirmation sends once',async()=>{
  const f=fixture(['file://media/a.jpg','file://media/b.jpg']);await unknown(f);f.select(['file://media/a.jpg']);const copies=f.st.copies.length;
  f.st.responses.push(Promise.resolve({index:0}));f.send();await settle();assert.equal(f.st.calls.length,1);assert.equal(f.st.copies.length,copies);assert.equal(f.context.pendingAttachmentUris.length,1);
  f.st.responses.push(Promise.resolve({index:1}));f.send();await settle();assert.equal(f.st.calls.length,2);assert.equal(f.st.calls[1].type,'sendMediaMessage');assert.equal(f.st.cleared,1);
});
test('two unknown disjoint batches preserve protection for earlier batch',async()=>{
  const f=fixture(['file://media/a.jpg','file://media/b.jpg']);await unknown(f);f.select(['file://media/c.jpg','file://media/d.jpg']);await unknown(f);assert.equal(f.st.calls.length,2);f.select(['file://media/a.jpg']);f.send();await settle();assert.equal(f.st.calls.length,2);assert.match(f.st.dialogs.at(-1).message,/duplicates/);
});
test('accepted response with edited input retains consumed URI protection',async()=>{
  const f=fixture(['file://media/a.jpg','file://media/b.jpg']),send=deferred();f.st.transport.push(()=>send.promise);f.send();await settle();f.context.composerDraftText='new caption';
  send.resolve(td.TdObject.fromJSON('{"@type":"messages","messages":[{"@type":"message","id":101,"chat_id":-10071},{"@type":"message","id":102,"chat_id":-10071}]}'));await settle();assert.equal(f.st.cleared,0);assert.equal(f.context.composerDraftText,'new caption');f.select(['file://media/b.jpg']);f.send();await settle();assert.equal(f.st.calls.length,1);assert.match(f.st.dialogs.at(-1).message,/duplicates/);
});
test('known rollback keeps older shared consumed URI taint',async()=>{
  const f=fixture(['file://media/a.jpg','file://media/b.jpg']);await unknown(f);f.context.sendMediaUseCase.getPhotoAlbumUseCase=()=>({execute:()=>Promise.reject(new album.SendMediaAlbumError(false,'Fixture known rejection'))});
  f.select(['file://media/a.jpg','file://media/new.jpg']);f.st.responses.push(Promise.resolve({index:1}));f.send();await settle();assert.equal(f.st.calls.length,1);f.select(['file://media/a.jpg']);f.send();await settle();assert.equal(f.st.calls.length,1);assert.match(f.st.dialogs.at(-1).message,/duplicates/);
  const dialogs=f.st.dialogs.length;f.select(['file://media/new.jpg']);f.send();await settle();assert.equal(f.st.calls.length,2);assert.equal(f.st.dialogs.length,dialogs,'known rollback frees only the new URI');
});
test('in-flight consumed URI is recorded before awaiting transport despite explicit busy reset',async()=>{
  const f=fixture(['file://media/a.jpg','file://media/b.jpg']),pending=deferred();f.st.transport.push(()=>pending.promise);f.send();await settle();
  assert.equal(f.st.calls.length,1);f.host.setSendingMessage(false);f.select(['file://media/a.jpg']);const copies=f.st.copies.length;f.send();await settle();
  assert.equal(f.st.calls.length,1);assert.equal(f.st.copies.length,copies);assert.match(f.st.dialogs.at(-1).message,/duplicates/);
  pending.resolve(td.TdObject.fromJSON('{"@type":"messages","messages":[{"@type":"message","id":101,"chat_id":-10071},{"@type":"message","id":102,"chat_id":-10071}]}'));await settle();assert.equal(f.st.cleared,0);assert.equal(f.context.pendingAttachmentUris.length,1);
});
test('bounded ledger overflow conservatively confirms every later photo send',async()=>{
  const f=fixture();for(let i=0;i<65;i++){f.select(['file://media/'+i+'a.jpg','file://media/'+i+'b.jpg']);await unknown(f);}assert.equal(f.st.calls.length,65);f.select(['file://media/brand-new.jpg']);f.send();await settle();assert.equal(f.st.calls.length,65);assert.match(f.st.dialogs.at(-1).message,/duplicates/);
});
test('new lifecycle owner can reuse URI without old owner warning',async()=>{
  const f=fixture(['file://media/a.jpg','file://media/b.jpg']);await unknown(f);const count=f.st.dialogs.length;f.context.pageLifecycleToken++;f.select(['file://media/a.jpg']);f.send();await settle();assert.equal(f.st.calls.length,2);assert.equal(f.st.dialogs.length,count);
});
test('actual preparer preserves URI/closes fixture FD and discards only owned path',async()=>{
  const f=fixture(),a=new f.ChatAttachmentFilePreparer(),b=new f.ChatAttachmentFilePreparer(),uri='file://media/a.jpg';const first=await a.prepare('photo',uri,f.st.context),second=await b.prepare('photo',uri,f.st.context);
  assert.deepEqual(f.native.opened,[uri,uri]);assert.equal(f.native.handles.size,0);assert.equal(f.native.closed.length,2);assert.notEqual(first,second);assert.deepEqual(f.native.files.get(first),f.native.files.get(uri));a.discard(uri);a.discard(second);assert.ok(f.native.files.has(uri));assert.ok(f.native.files.has(second));a.discard(first);a.discard(first);assert.equal(f.native.files.has(first),false);assert.ok(f.native.files.has(uri));
});
test('injected partial-copy failure cleans allocated target and closes fixture source',async()=>{
  const f=fixture(),preparer=new f.ChatAttachmentFilePreparer(),uri='file://media/a.jpg',source=Buffer.from(f.native.files.get(uri));f.native.flags.partialCopy=true;await assert.rejects(preparer.prepare('photo',uri,f.st.context),/Prepare picked attachment failed/);assert.equal(f.native.copies.length,1);assert.equal(f.native.files.has(f.native.copies[0].target),false);assert.equal(f.native.handles.size,0);assert.deepEqual(f.native.files.get(uri),source);
});
test('injected source close failure rejects copied success and removes target',async()=>{
  const f=fixture(),preparer=new f.ChatAttachmentFilePreparer();f.native.flags.closeFails=true;await assert.rejects(preparer.prepare('photo','file://media/a.jpg',f.st.context),/Close picked attachment source failed/);assert.equal(f.native.closed.length,1);assert.equal(f.native.files.has(f.native.copies[0].target),false);assert.ok(f.native.files.has('file://media/a.jpg'));
});
test('cleanup retry retains ownership after injected unlink failure',async()=>{
  const f=fixture(),preparer=new f.ChatAttachmentFilePreparer(),target=await preparer.prepare('photo','file://media/a.jpg',f.st.context);f.native.flags.unlinkFails=true;preparer.discard(target);assert.ok(f.native.files.has(target));preparer.discard(target);assert.equal(f.native.files.has(target),false);
});
let completed=false;
process.once('beforeExit',()=>{if(!completed){console.error('HARNESS_ERROR incomplete preview run');process.exitCode=1;}});
(async()=>{
  const results=[];for(const{name,fn}of tests){try{await fn();results.push({name,passed:true});}catch(error){results.push({name,passed:false,assertion:error instanceof assert.AssertionError,message:error.message});}}
  for(const[file,text]of sources)assert.equal(fs.readFileSync(file,'utf8'),text,'Source changed during probe');
  const failed=results.filter(r=>!r.passed);if(mutation!==undefined){assert.ok(failed.length>0,'Mutation must be RED');assert.ok(failed.every(r=>r.assertion),'Mutation must fail behavior, not harness');}
  completed=true;console.log(JSON.stringify({suite:'photo-preview-controller',checks:results.length,passed:results.length-failed.length,failed:failed.length,mutation,mutationRed:mutation!==undefined,results,
    sources:Object.fromEntries([...sources].map(([file,text])=>[path.relative(root,file),createHash('sha256').update(text).digest('hex')])),scope:{actualProductionOwners:true,actualContextRevision:true,nativeFileIO:false,nativePicker:false,gatewayFixture:true,authenticatedFlows:false}}));
  if(failed.length&&mutation===undefined)process.exitCode=1;
})().catch(error=>{completed=true;console.error(error.stack||String(error));process.exitCode=1;});

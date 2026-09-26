// Review baseline reproduction for dev@2d2f683, reviewed 2026-09-26.
// These assertions intentionally demonstrate known defects at the reviewed base.
// They are not corrected-behavior regression tests: failures after fixes can mean
// the defects have been resolved and these reproductions should be updated.
// Run with Node.js 24: node scripts/review/2026-09-26/ui_composer_repro.cjs
// Executes production ETS controller logic after TypeScript stripping; HarmonyOS
// dependencies, controllable send promises, and device file preparation are stubbed.

const fs = require('node:fs');
const path = require('node:path');
const { stripTypeScriptTypes } = require('node:module');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../../../entry/src/main/ets');
const logs = [];
const hilog = new Proxy({}, { get: () => (...args) => logs.push(args) });
const base = { hilog, localized: (_id, fallback) => fallback, $r: () => ({ id: 1 }) };
function load(relative, exports, deps = {}) {
  let source = fs.readFileSync(path.join(root, relative), 'utf8');
  source = source.replace(/^import\s[\s\S]*?from\s*['"][^'"]+['"];\s*/gm, '');
  source = stripTypeScriptTypes(source, { mode: 'transform' }).replace(/^export\s+/gm, '');
  const all = { ...base, ...deps };
  return Function(...Object.keys(all), source + `\nreturn {${exports.join(',')}};`)(...Object.values(all));
}
const cmds = load('core/model/AppCommand.ets', ['createEditMessageTextCommand']);
const errors = load('core/model/AppError.ets', ['AppError', 'AppErrorKind']);
const edit = load('domain/usecases/editMessage.ets', ['EditMessageParams', 'EditMessageUseCase'], {...cmds, ...errors});
const { ChatMessageActionsController } = load('ui/pages/chat/ChatMessageActionsController.ets', ['ChatMessageActionsController'], {
  ...edit, SendMessageParams: class {}, ForwardMessagesParams: class {}
});
const { ChatComposerController } = load('ui/pages/chat/ChatComposerController.ets', ['ChatComposerController'], {
  SendMessageParams: class {}, SendMediaMessageParams: class {},
  normalizeCustomEmojiEntitiesForSubstring: (_source, _target, entities) => entities
});
const tick = () => new Promise(resolve => setImmediate(resolve));
function pageMethod(name, deps = {}) {
  const source = fs.readFileSync(path.join(root, 'ui/pages/chat/TgChatScreenPage.ets'), 'utf8');
  const start = source.indexOf(`  ${name}(`);
  assert.ok(start >= 0, `Actual page method ${name} found`);
  const open = source.indexOf('{', start);
  let depth=1, end=open+1;
  while(depth>0) { if(source[end]==='{') depth++; if(source[end]==='}') depth--; end++; }
  const method = source.slice(start,end);
  const js = stripTypeScriptTypes(`class PageMethods {${method}}`, {mode:'transform'});
  const all = {...base,...deps};
  return Function(...Object.keys(all), `${js}; return PageMethods.prototype.${name};`)(...Object.values(all));
}
function deferred() { let resolve, reject; const promise = new Promise((a,b) => {resolve=a; reject=b;}); return {promise, resolve, reject}; }
function hostBase() {
  return {
    draft: '', sending: false, entities: [], uris: [], kind: 'photo', reply: '0', editId: '0', editing: false,
    forward: { sourceChatId: 0, messageIds: [], title: '', preview: '' },
    getActiveChatId() { return 101; }, getLifecycleToken() { return 1; },
    isSendingMessage() { return this.sending; }, setSendingMessage(v) { this.sending=v; },
    isEditModeActive() { return this.editing; }, isForwardModeActive() { return this.forward.messageIds.length>0; },
    getDraftText() { return this.draft; }, setDraftText(v) { this.draft=v; },
    getCustomEmojiEntities() { return this.entities; }, setCustomEmojiEntities(v) { this.entities=v; },
    setDraftSelection() {}, setEmojiPanelVisible() {},
    getReplyToMessageId() { return this.reply; }, clearReplyMode() { this.reply='0'; },
    getPendingAttachmentUris() { return this.uris; }, getPendingAttachmentKind() { return this.kind; },
    clearPendingAttachmentState() { this.uris=[]; },
    getSendMediaUseCase() { return this.media; }, getSendUseCase() { return this.send; },
    getForwardUseCase() { return this.forwardCase; }, getEditUseCase() { return this.editCase; },
    isNearBottom() { return false; }, scrollToBottomSoon() {},
    getForwardModeState() { return this.forward; },
    setForwardMode(messageIds,sourceChatId,title,preview) { this.forward={messageIds,sourceChatId,title,preview}; },
    clearForwardMode() { this.forward={sourceChatId:0,messageIds:[],title:'',preview:''}; },
    setEditMode(id,text) { this.editing=true; this.editId=id; this.original=text; },
    getEditingMessageId() { return this.editId; }, getEditingOriginalText() { return this.original; },
    clearEditMode(clear) { this.editing=false; this.editId='0'; if(clear) this.draft=''; },
    getChatUIContext() { return { getPromptAction() { return { showToast() {} }; } }; }
  };
}
(async () => {
  const controller = new ChatComposerController();
  // Keep production controller/sending logic; only device file preparation is substituted.
  controller.preparePickedAttachmentLocalPath = async (_kind, uri) => uri;
  const h1=hostBase(); h1.draft='caption'; h1.uris=['photo-A'];
  const pending=deferred(); h1.media={execute: () => pending.promise};
  controller.handleSendMessage(h1.draft,h1); await tick();
  h1.draft='new draft typed while send is pending'; h1.reply='777'; h1.uris=['new-photo-B'];
  pending.resolve(); await tick();
  assert.equal(h1.draft,''); assert.deepEqual(h1.uris,[]); assert.equal(h1.reply,'0');
  console.log('CONFIRMED media success overwrites later draft, reply, attachment');

  const h2=hostBase(); h2.draft='caption'; h2.uris=['A','B']; const accepted=[]; let fail=true;
  h2.media={execute: async p => { if(p.localPath==='B' && fail) throw new Error('second item rejected'); accepted.push(p.localPath); }};
  controller.handleSendMessage(h2.draft,h2); await tick();
  assert.deepEqual(accepted,['A']); assert.deepEqual(h2.uris,['A','B']);
  fail=false; controller.handleSendMessage(h2.draft,h2); await tick();
  assert.deepEqual(accepted,['A','A','B']);
  console.log('CONFIRMED partial multi-send retry duplicates accepted item:', JSON.stringify(accepted));

  const actions = new ChatMessageActionsController();
  const h3=hostBase(); h3.draft='old comment'; h3.forward={sourceChatId:55,messageIds:['44'],title:'forward',preview:'message'};
  const pendingComment=deferred(); h3.send={execute:()=>pendingComment.promise}; h3.forwardCase={execute:async()=>{}};
  actions.handleForwardMessages(h3.draft,h3); await tick();
  h3.draft='new user text'; pendingComment.reject(new Error('rejected')); await tick();
  assert.equal(h3.draft,'old comment');
  console.log('CONFIRMED rejected forwarding comment overwrites newer user text:', h3.draft);

  const commands=[]; const h4=hostBase();
  h4.editCase=new edit.EditMessageUseCase({send: async command => commands.push(command)});
  const entry={message:{isOutgoing:true,contentType:'photo',text:'',caption:'old caption',messageId:'123',senderName:''}};
  const menu=actions.buildMessageActionItems(entry); const editIndex=menu.findIndex(x=>x.id==='edit');
  assert.ok(editIndex>=0); actions.handleMessageActionPress(editIndex,entry,h4);
  actions.handleEditMessage('new caption',h4); await tick();
  assert.equal(commands[0].type,'editMessageText');
  console.log('CONFIRMED outgoing photo caption Edit dispatches:', JSON.stringify(commands[0]));

  const h5=hostBase();
  // Execute the page's real setters too, instead of mirroring their state writes.
  Object.defineProperty(h5,'draft',{get(){return this.composerDraftText;},set(v){this.composerDraftText=v;}});
  h5.setEditMode=pageMethod('setEditMode'); h5.clearEditMode=pageMethod('clearEditMode');
  h5.draftDebounceTimerId=-1; h5.draft='existing unsent draft';
  actions.startEditMessage('123','old sent message',h5); actions.cancelEditMessage(h5);
  assert.equal(h5.draft,'');
  console.log('CONFIRMED edit/cancel drops existing composer draft (actual page setEditMode/clearEditMode executed)');
})().catch(e=>{console.error(e);process.exitCode=1;});

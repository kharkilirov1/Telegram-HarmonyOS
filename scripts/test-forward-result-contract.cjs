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
assert.ok(!mutant || ['result-ignored','lexical-sort','replay-all','skip-preflight','legacy-array'].includes(mutant));
let mutations = 0;
function read(relative) {
  let source = readChatSource(path.join(root, relative), 'utf8').replaceAll('\r\n','\n');
  sources[relative] = createHash('sha256').update(source).digest('hex');
  let from, to;
  if(relative === 'domain/usecases/forwardMessages.ets') {
    if(mutant === 'result-ignored') { from='    // TDLib returns a positional Messages vector;'; to='    return;\n'+from; }
    if(mutant === 'lexical-sort') { from='Number(a) - Number(b)'; to='a.localeCompare(b)'; }
    if(mutant === 'legacy-array') { from="response.getTopLevelObjectArrayStrict('messages')"; to="response.getArray('messages')"; }
  }
  if(relative === 'ui/pages/chat/ChatMessageActionsController.ets') {
    if(mutant === 'skip-preflight') { from='prepared = forwardUseCase.prepare(input);'; to='prepared = input;'; }
    if(mutant === 'replay-all') { from='err instanceof ForwardMessagesResultError ? err.retryMessageIds : messageIds'; to='messageIds'; }
  }
  if(from) { assert.ok(source.includes(from), 'mutation path must engage '+mutant);source=source.replace(from,to);mutations++; }
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
function eligibleRead(command, chatType = 'chatTypePrivate') {
  if (command.type === 'getChat') return td.TdObject.fromJSON(JSON.stringify({
    '@type': 'chat', id: command.payload.chatId, type: { '@type': chatType }
  }));
  if (command.type === 'getMessageProperties') return td.TdObject.fromJSON(
    '{"@type":"messageProperties","can_be_forwarded":true,"can_be_copied":true,"can_be_copied_to_secret_chat":true}');
  return undefined;
}
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
    const read = eligibleRead(command, type === 'private' ? 'chatTypePrivate' : 'chatTypeSupergroup');
    if (read !== undefined) return Promise.resolve(read);
    // Only mutating sends are deferred; preflight reads remain in the full trace.
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
const raw = value => td.TdObject.fromJSON(JSON.stringify(value));
const message = (chatId = 7, id = 900) => ({ '@type': 'message', id, chat_id: chatId });
const response = values => raw({ '@type': 'messages', total_count: values.length, messages: values });
const { serializeCommand } = load('infra/td/serialization/CommandSerializer.ets', { ...C, ...td, hilog });
function direct(ids = ['2','10'], result) {
  const commands = [];
  const gateway = { send(command) {
    commands.push(command);
    const read = eligibleRead(command);
    if (read !== undefined) return Promise.resolve(read);
    assert.equal(command.type, 'forwardMessages');
    return Promise.resolve(result === undefined
      ? response(command.payload.messageIds.map((_id, i) => message(command.payload.chatId, 900+i))) : result);
  } };
  const params = Object.assign(new forwarding.ForwardMessagesParams(), { chatId: 7, fromChatId: -12, messageIds: ids });
  return { commands, params, useCase: new forwarding.ForwardMessagesUseCase(gateway) };
}
async function rejection(fn) { let error; try { await fn(); } catch(e) {error=e;} assert.ok(error, 'expected rejection'); return error; }
test('IDs sorted numerically, deduplicated, copied without mutating input', async () => {
  const ids=['10','2','10','9007199254740991']; const f=direct(ids);
  await f.useCase.execute(f.params);
  assert.deepEqual(f.commands.map(c => c.type), ['getChat', 'getMessageProperties', 'getMessageProperties', 'getMessageProperties', 'forwardMessages']);
  assert.equal(f.commands[0].payload.chatId, 7);
  assert.deepEqual(f.commands.slice(1, -1).map(c => [c.payload.chatId, c.payload.messageId]),
    [[-12, '2'], [-12, '10'], [-12, '9007199254740991']]);
  assert.deepEqual(f.commands.at(-1).payload.messageIds, ['2','10','9007199254740991']);
  assert.deepEqual(ids, ['10','2','10','9007199254740991']);
  assert.notEqual(f.commands.at(-1).payload.messageIds, ids);
});
for(const ids of [[],['0'],['-1'],['1.5'],['1e2'],['01'],[' 1'],['1 '],['9007199254740992'],['2,3'],['2]'],[2],[null],['NaN'],undefined]) {
  test('invalid IDs rejected before gateway: '+JSON.stringify(ids), async()=>{
    const f=direct(); f.params.messageIds=ids; await rejection(()=>f.useCase.execute(f.params)); assert.equal(f.commands.length,0);
  });
}
for(const field of ['chatId','fromChatId']) for(const value of [0,NaN,Infinity,1.5,'7',9007199254740992]) {
  test(field+' strict int53 '+String(value), async()=>{const f=direct();f.params[field]=value;await rejection(()=>f.useCase.execute(f.params));assert.equal(f.commands.length,0);});
}
for(const n of [1,100]) test(n+' messages accepted',async()=>{const f=direct(Array.from({length:n},(_v,i)=>String(i+1)));await f.useCase.execute(f.params);assert.equal(f.commands.at(-1).type,'forwardMessages');assert.equal(f.commands.at(-1).payload.messageIds.length,n);assert.equal(f.commands.length,n+2);});
test('101 distinct messages not silently truncated or batched',async()=>{const f=direct(Array.from({length:101},(_v,i)=>String(i+1)));await rejection(()=>f.useCase.execute(f.params));assert.equal(f.commands.length,0);});
test('partial null response preserves positional failure IDs',async()=>{const f=direct(['100','2','10'],response([message(),null,message(7,902)]));const e=await rejection(()=>f.useCase.execute(f.params));assert.equal(e.outcomeKnown,true);assert.equal(e.acceptedCount,2);assert.deepEqual(e.retryMessageIds,['10']);});
test('all null response is not success',async()=>{const f=direct(['2','10'],response([null,null]));const e=await rejection(()=>f.useCase.execute(f.params));assert.equal(e.outcomeKnown,true);assert.equal(e.acceptedCount,0);assert.deepEqual(e.retryMessageIds,['2','10']);});
for(const result of [
  {},raw({'@type':'ok'}),raw({'@type':'messages'}),raw({'@type':'messages',messages:[]}),
  response([message()]),response([message(),message(),message()]),response([message(),{}]),
  response([message(),message(8)]),response([message(),message(7,0)]),
  raw({'@type':'messages',nested:{messages:[message(),message()]}}),
  raw({'@type':'messages',messages:'bad',nested:{messages:[message(),message()]}}),
  raw({'@type':'messages',messages:[message(),42]}),
  raw({'@type':'messages',messages:[message(),[]]}),
  raw({'@type':'messages',messages:[message(),{'@type':'other',nested:message()}]})
]) test('malformed or mismatched response is uncertain, not success or full retry '+tests.length,async()=>{
  const f=direct(['2','10'],result);const e=await rejection(()=>f.useCase.execute(f.params));assert.equal(e.outcomeKnown,false);assert.deepEqual(e.retryMessageIds,[]);
});
test('copy options remain intact',async()=>{const f=direct();f.params.sendCopy=true;f.params.removeCaption=true;await f.useCase.execute(f.params);assert.equal(f.commands.at(-1).type,'forwardMessages');assert.equal(f.commands.at(-1).payload.sendCopy,true);assert.equal(f.commands.at(-1).payload.removeCaption,true);});
test('actual serializer emits numeric int53 IDs, not quoted or injected fragments',async()=>{
  const f=direct(['10','2','9007199254740991']);await f.useCase.execute(f.params);
  const serialized=serializeCommand(f.commands.at(-1));const wire=JSON.parse(serialized.params.toJSON());
  assert.equal(serialized.method,'forwardMessages');assert.deepEqual(wire.message_ids,[2,10,9007199254740991]);
  assert.equal(wire.chat_id,7);assert.equal(wire.from_chat_id,-12);
});
function queue(f,ids,comment='') {
  f.p.setForwardMode(ids,-12,'source','preview');f.p.setDraftText(comment);f.p.handleSendMessage(comment);
}
async function settleValue(request,result) {request.settled=true;request.resolve(result);await tick();}
test('invalid selection cannot send comment or clear UI before preflight',async()=>{
  const f=fixture('private');queue(f,['2,3'],'comment');await tick();
  assert.equal(f.requests.length,0);assert.equal(f.p.composerDraftText,'comment');assert.equal(f.p.isForwardingMessages,true);assert.equal(f.p.isSending,false);
  assert.equal(f.trace.length,0,'invalid input must not reach even a read');
});
test('partial forward retries only rejected IDs without repeating comment',async()=>{
  const f=fixture('private');queue(f,['100','2','10'],'comment');await tick();
  assert.deepEqual(f.trace.map(c=>c.type),['getChat','getMessageProperties','getMessageProperties','getMessageProperties','sendMessage']);
  assert.equal(f.requests[0].command.type,'sendMessage');await settle(f.requests[0]);
  assert.deepEqual(f.trace.map(c=>c.type),['getChat','getMessageProperties','getMessageProperties','getMessageProperties','sendMessage','getChat','getMessageProperties','getMessageProperties','getMessageProperties','forwardMessages']);
  assert.deepEqual(f.trace.filter(c=>c.type==='getMessageProperties').map(c=>[c.payload.chatId,c.payload.messageId]),
    [[-12,'2'],[-12,'10'],[-12,'100'],[-12,'2'],[-12,'10'],[-12,'100']]);
  assert.deepEqual(f.requests[1].command.payload.messageIds,['2','10','100']);
  await settleValue(f.requests[1],response([message(),null,message(7,902)]));
  assert.deepEqual(f.p.forwardingMessageIds,['10']);assert.equal(f.p.composerDraftText,'');assert.equal(f.p.isSending,false);
  f.p.handleSendMessage('');await tick();assert.equal(f.requests[2].command.type,'forwardMessages');assert.deepEqual(f.requests[2].command.payload.messageIds,['10']);
  assert.deepEqual(f.trace.slice(-5).map(c=>c.type),['getChat','getMessageProperties','getChat','getMessageProperties','forwardMessages']);
  assert.deepEqual(f.trace.slice(-5).filter(c=>c.type==='getMessageProperties').map(c=>[c.payload.chatId,c.payload.messageId]),[[-12,'10'],[-12,'10']]);
  await settleValue(f.requests[2],response([message()]));assert.equal(f.p.isForwardingMessages,false);
  assert.equal(f.requests.filter(r=>r.command.type==='sendMessage').length,1);
});
test('uncertain result cannot restore all accepted messages for duplicate retry',async()=>{
  const f=fixture('private');queue(f,['2','10']);await tick();await settleValue(f.requests[0],raw({'@type':'messages'}));
  assert.equal(f.p.isForwardingMessages,false);assert.equal(f.p.isSending,false);assert.equal(f.p.toasts,1);
});
for(const boundary of ['account','draft','attachment','newForward','owner']) test('partial result respects '+boundary,async()=>{
  const f=fixture('private');queue(f,['2','10']);await tick();
  if(boundary==='account') await f.store.resetStateQueued();
  if(boundary==='draft') f.p.setDraftText('new');
  if(boundary==='attachment') f.p.setPendingAttachmentState('document','new','new',['file:///new']);
  if(boundary==='newForward') f.p.setForwardMode(['90'],-20,'new','new');
  if(boundary==='owner') f.p.setSendingMessage(true);
  await settleValue(f.requests[0],response([message(),null]));
  if(boundary==='newForward') assert.deepEqual(f.p.forwardingMessageIds,['90']);
  else assert.equal(f.p.isForwardingMessages,false);
  if(boundary==='owner') assert.equal(f.p.isSending,true); else assert.equal(f.p.isSending,false);
});
const { forwardMessagesContractTest } = load('../../ohosTest/ets/test/ForwardMessagesContract.test.ets', {
  ...td, ...forwarding,
  describe: (_name, run) => run(), it: (name, _flags, run) => test('ohosTest: '+name,run),
  expect: actual => ({ assertEqual: expected => assert.equal(actual,expected) })
});
forwardMessagesContractTest();
let completed=false;
async function main() {
 let passed=0,failed=0;
 for(const t of tests){try{await t.run();passed++;}catch(e){failed++;console.error('FAIL',t.name,e.message);}
 finally{for(const f of fixtures.splice(0)){for(const r of f.requests) if(!r.settled) await settle(r);}}}
 if(mutant) assert.ok(mutations>0,'mutation never engaged');
 completed=true;console.log(JSON.stringify({passed,failed,mutant,mutations,sources}));process.exitCode=failed?1:0;
}
main().catch(e=>{completed=true;console.error(e);process.exitCode=2});
process.on('beforeExit',()=>{if(!completed)process.exitCode=2});

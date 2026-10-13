// Node >=24. Read-only source availability, real action dispatch/picker; no real UI/account/network.
const { readChatSource } = require("./chat-screen-source.cjs");
const fs = require('node:fs'), path = require('node:path'), assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '../entry/src/main/ets'), sources = {};
const mutant = process.argv.find(arg=>arg.startsWith('--mutant='))?.slice(9);
assert.ok(!mutant || ['batch-route','popup-generation','action-token','picker-gate','picker-route','render-key','dismiss-generation','intent-cancel'].includes(mutant));
const mutatedFiles = new Set();
function read(file) {
  let s = readChatSource(path.join(root, file), 'utf8').replaceAll('\r\n', '\n'); sources[file] = createHash('sha256').update(s).digest('hex');
  let from,to;
  if(file==='domain/usecases/forwardMessages.ets'&&mutant==='batch-route'){from='availability.ordinaryTargets && ordinary';to='availability.ordinaryTargets || ordinary';}
  if(file==='ui/pages/chat/ChatForwardSourceController.ets'&&mutant==='popup-generation'){from='generation === this.generation && isCurrent()';to='isCurrent()';}
  if(file==='ui/pages/chat/TgChatScreenPage.ets'){
    if(mutant==='action-token'){from='item.contextToken !== this.messageActionsGeneration || ';to='';}
    if(mutant==='render-key'){from='`${item.contextToken}:${item.sourceMessageId}:${item.id}:${item.enabled}:${item.title}`';to='item.id';}
    if(mutant==='dismiss-generation'){from='!event.isVisible && generation === this.messageActionsGeneration &&';to='!event.isVisible &&';}
  }
  if(file==='ui/pages/chat/ChatMessageActionsController.ets'&&mutant==='picker-gate'){from='!availability.ordinaryTargets && !availability.secretTargets';to='false';}
  if(file==='ui/pages/chat/ChatMessageActionsController.ets'&&mutant==='intent-cancel'){from='  cancelPendingForwardPicker(): void {\n    this.forwardPickerGeneration++;\n    this.forwardPickerOpen = false;\n  }';to='  cancelPendingForwardPicker(): void {}';}
  if(file==='ui/pages/forward/TgForwardTargetPickerPage.ets'&&mutant==='picker-route'){from="!(chat.type === 'secret' ? this.allowSecretTargets : this.allowOrdinaryTargets)";to='false';}
  if(from){assert.ok(s.includes(from),'mutation engages '+mutant);s=s.replaceAll(from,to);mutatedFiles.add(file);}return s;
}
function load(file, deps = {}) {
  const s = read(file), names = [...s.matchAll(/^export\s+(?:default\s+)?(?:class|function|const|enum)\s+(\w+)/gm)].map(m => m[1]);
  const js = stripTypeScriptTypes(s.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+(?:default\s+)?/gm, ''), { mode: 'transform', sourceUrl: file });
  return new Function(...Object.keys(deps), `${js}\nreturn {${names.join(',')}};`)(...Object.values(deps));
}
const platform = { hilog: { info() {}, error() {}, warn() {} }, localized: (_id, fallback) => fallback, $r: id => ({ id }) };
const C = load('core/model/AppCommand.ets'), td = load('models/td/common/index.ets'), E = load('core/model/AppError.ets');
const F = load('domain/usecases/forwardMessages.ets', { ...C, ...td, ...E, ...platform });
const stateModel = load('core/model/AppState.ets');
const { AppStore } = load('core/store/AppStore.ets', { ...stateModel, ...platform });
const { ChatOpenLease } = load('domain/usecases/ChatOpenLease.ets', { ...C, ...td });
const { ChatScreenRouteParams } = load('ui/pages/chat/ChatScreenRouteParams.ets', { ChatOpenLease });
class PickerRoute { constructor(sourceChatId) { this.sourceChatId = sourceChatId; } }
const navigationUIState = {}, { pendingForwardTransfer: transfer } = load('ui/pages/chat/PendingForwardTransfer.ets');
const A = load('ui/pages/chat/ChatMessageActionsController.ets', { ...F, ...platform, ForwardTargetPickerRouteParams: PickerRoute,
  navigationUIState, pendingForwardTransfer: transfer, StorageKeys: { CHAT_SCREEN_VISIBLE: 'visible' }, AppStorage: { set() {} }, ChatScreenRouteParams });
const S = load('ui/pages/chat/ChatForwardSourceController.ets', F);
const serializer=load('infra/td/serialization/CommandSerializer.ets',{...C,...td,...platform});
const tests = []; function test(name, body) { tests.push({ name, body }); }
const tick = () => new Promise(resolve => setImmediate(resolve));
const raw = value => td.TdObject.fromJSON(JSON.stringify(value));
const entry = (id = '1048576') => ({ message: { messageId: id, text: 'text', caption: '', isOutgoing: false, senderName: 'Name', contentType: 'text' } });
function fixture(options = {}) {
  const commands = [], pushes = [], feedback = [];
  const gateway = { send(command) { commands.push(command); if (options.send) return options.send(command, commands); return Promise.resolve(raw({ '@type': 'messageProperties', can_be_forwarded: false, can_be_copied: false, can_be_copied_to_secret_chat: false })); } };
  const useCase = new F.ForwardMessagesUseCase(gateway);
  const store = new AppStore(s => s, stateModel.createInitialAppState(), false).createScope();
  const route = new ChatScreenRouteParams(-12, 'source', store, gateway);
  Object.assign(navigationUIState, { activeChatOwnerToken: route.navigationToken,
    activeChatId: route.chatId, activeChatTitle: route.chatTitle, chatScreenVisible: true });
  const live = { chatId: -12, lifecycle: 1, active: true, useCase, forward: undefined };
  const host = { getActiveChatId: () => live.chatId, getChatRouteToken: () => route.navigationToken,
    createChatRouteParams: (id, title) => live.active ? new ChatScreenRouteParams(id, title, store, gateway) : undefined,
    getLifecycleToken: () => live.lifecycle, hasActiveChatState: () => live.active, getSourceForwardUseCase: () => live.active ? live.useCase : undefined,
    bindNavigationStack: () => ({ pushPathByName: (...args) => { if (options.push) options.push(...args); pushes.push(args); } }), getChatUIContext: () => ({ getPromptAction: () => ({ showToast: ({ message }) => feedback.push(message) }) }),
    clearReplyMode() {}, clearEditMode() {}, clearForwardMode() {},setReplyMode:(...args)=>{live.reply=args;},setEditMode:(...args)=>{live.edit=args;},setDraftText:value=>{live.draft=value;},setForwardMode: (...args) => { live.forward = args; } };
  return { controller: new A.ChatMessageActionsController(), host, live, useCase, commands, pushes, feedback };
}
test('forward menu is not actionable until source check completes', () => {
  const f = fixture(), item = f.controller.buildMessageActionItems(entry(), 'loading').find(i => i.id === 'forward'); assert.ok(item); assert.equal(item.enabled, false);
});
test('stable action ID dispatch does not reinterpret a rendered action as an index', () => {
  const f = fixture(); let copied = '';
  f.controller.copyMessageText = value => { copied = value; }; // external clipboard boundary only
  f.controller.handleMessageActionPress('copy', entry(), f.host); assert.equal(copied, 'text');
});
test('denied source cannot open forward target picker', async () => {
  const f = fixture(); f.controller.openForwardTargetPicker(['1048576'], 'Name', 'text', f.host); await tick();
  assert.equal(f.pushes.length, 0); assert.equal(f.commands[0]?.type, 'getMessageProperties'); assert.equal(f.feedback.length, 1);
});
const props = (f, c, s) => raw({ '@type': 'messageProperties', can_be_forwarded: f, can_be_copied: c, can_be_copied_to_secret_chat: s });
for (const [name, ids, p, ordinary, secret] of [
  ['server forward only', ['1048576'], props(true, false, false), true, false],
  ['server copy alone is not default forwarding', ['1048576'], props(false, true, false), false, false],
  ['secret-only route', ['1048576'], props(false, true, true), false, true],
  ['local cannot substitute F', ['1048578'], props(true, false, false), false, false],
  ['local copy route', ['1048578'], props(false, true, false), true, false],
  ['large server ID exact', ['2251799812636672'], props(true, false, false), true, false],
]) test(name, async () => {
  const f = fixture({ send: () => Promise.resolve(p) }); const a = await f.useCase.getSourceAvailability(-12, ids);
  assert.equal(a.ordinaryTargets, ordinary); assert.equal(a.secretTargets, secret); assert.equal(f.commands.length, 1); assert.equal(f.commands[0].payload.chatId, -12); assert.equal(f.commands[0].payload.messageId, ids[0]);
});
test('selection intersects routes, not per-message OR', async () => {
  const f = fixture({ send: c => Promise.resolve(c.payload.messageId === '1048576' ? props(true, false, false) : props(false, true, true)) });
  const a = await f.useCase.getSourceAvailability(-12, ['2097152', '1048576']); assert.equal(a.ordinaryTargets || a.secretTargets, false);
});
for (const payload of [props('true', true, false), props(true, true, undefined), raw({ '@type': 'messageProperties', nested: { can_be_forwarded: true, can_be_copied_to_secret_chat: false } }), raw({ '@type': 'error', code: 400 }), { '@type': 'messageProperties', can_be_forwarded: true, can_be_copied_to_secret_chat: false }]) test('malformed required availability fields reject, not known deny', async () => {
  const f = fixture({ send: () => Promise.resolve(payload) }); await assert.rejects(f.useCase.getSourceAvailability(-12, ['1048576']));
});
test('invalid source selection rejected before transport', async () => {
  const f = fixture(); for (const [chat, ids] of [[0,['1048576']],[-12,[]],[-12,['1e6']],[-12,Array.from({length:101},(_,i)=>String(i+1))]]) await assert.rejects(f.useCase.getSourceAvailability(chat, ids)); assert.equal(f.commands.length, 0);
});
test('source snapshot copies/deduplicates/sorts IDs before await', async () => {
  let release; const f = fixture({ send: (_c, all) => all.length === 1 ? new Promise(resolve => { release = resolve; }) : Promise.resolve(props(true, true, true)) });
  const ids = ['2097152','1048576','2097152']; const pending = f.useCase.getSourceAvailability(-12, ids); ids.splice(0, ids.length, '3145728'); release(props(true,true,true)); await pending;
  assert.deepEqual(f.commands.map(c=>c.payload.messageId), ['1048576','2097152']);
});
test('popup controller reports retry and retries only on explicit load', async () => {
  const f = fixture({ send: (_c, all) => all.length === 1 ? Promise.reject(new Error('unavailable')) : Promise.resolve(props(true,true,false)) }); const ctl = new S.ChatForwardSourceController(), states=[];
  ctl.load(f.useCase,-12,['1048576'],()=>true,s=>states.push(s)); await tick(); assert.deepEqual(states,['loading','unavailable']); await tick(); assert.equal(f.commands.length,1);
  ctl.load(f.useCase,-12,['1048576'],()=>true,s=>states.push(s)); await tick(); assert.deepEqual(states,['loading','unavailable','loading','allowed']);
});
for (const boundary of ['cancel','current','supersede']) test(`popup response ignores ${boundary}`, async () => {
  const held=[]; const f=fixture({send:()=>new Promise(resolve=>held.push(resolve))}); const ctl=new S.ChatForwardSourceController(),states=[];let current=true;
  ctl.load(f.useCase,-12,['1048576'],()=>current,s=>states.push(s));
  if(boundary==='cancel')ctl.cancel(); if(boundary==='current')current=false;
  if(boundary==='supersede') {ctl.load(f.useCase,-12,['2097152'],()=>current,s=>states.push(s)); held[1](props(true,true,false)); await tick();}
  held[0](props(false,false,false)); await tick(); assert.deepEqual(states,boundary==='supersede'?['loading','loading','allowed']:['loading']);
});
for(const boundary of ['chatId','lifecycle','active','useCase'])test(`picker check ignores changed ${boundary}`,async()=>{
  let release;const f=fixture({send:()=>new Promise(resolve=>release=resolve)}); f.controller.openForwardTargetPicker(['1048576'],'Name','preview',f.host);
  f.live[boundary]=boundary==='chatId'?-13:boundary==='lifecycle'?2:boundary==='active'?false:new F.ForwardMessagesUseCase({send(){throw new Error('not used')}});
  release(props(true,true,false));await tick();assert.equal(f.pushes.length,0);assert.equal(f.feedback.length,0);
});
test('picker receives batch route flags and source snapshot',async()=>{
  const f=fixture({send:()=>Promise.resolve(props(false,true,true))});f.controller.openForwardTargetPicker(['1048576'],'Name','preview',f.host);await tick();
  assert.equal(f.pushes.length,1);assert.equal(f.pushes[0][1].sourceChatId,-12);assert.equal(f.pushes[0][1].allowOrdinaryTargets,false);assert.equal(f.pushes[0][1].allowSecretTargets,true);
});
test('only latest pending picker intent can open, duplicate open suppressed and cancel allows retry',async()=>{
  const held=[];const f=fixture({send:()=>new Promise(resolve=>held.push(resolve))});
  f.controller.openForwardTargetPicker(['1048576'],'first','preview',f.host);f.controller.openForwardTargetPicker(['2097152'],'second','preview',f.host);
  held[0](props(true,true,false));await tick();assert.equal(f.pushes.length,0);held[1](props(true,true,false));await tick();assert.equal(f.pushes.length,1);
  f.controller.openForwardTargetPicker(['1048576'],'third','preview',f.host);assert.equal(f.commands.length,2);
  f.pushes[0][2]({result:{chatId:0}});f.controller.openForwardTargetPicker(['1048576'],'third','preview',f.host);assert.equal(f.commands.length,3);
  held[2](props(true,true,false));await tick();assert.equal(f.pushes.length,2);
});
test('failed navigation does not lock later picker retry',async()=>{
  let fail=true;const f=fixture({send:()=>Promise.resolve(props(true,true,false)),push:()=>{if(fail)throw new Error('nav failed')}});
  f.controller.openForwardTargetPicker(['1048576'],'Name','preview',f.host);await tick();assert.equal(f.pushes.length,0);fail=false;
  f.controller.openForwardTargetPicker(['1048576'],'Name','preview',f.host);await tick();assert.equal(f.pushes.length,1);
});
test('duplicate-open fence is scoped to account use-case identity',async()=>{
  const f=fixture({send:()=>Promise.resolve(props(true,true,false))});f.controller.openForwardTargetPicker(['1048576'],'Name','preview',f.host);await tick();assert.equal(f.pushes.length,1);
  f.live.useCase=new F.ForwardMessagesUseCase({send:()=>Promise.resolve(props(true,true,false))});f.controller.openForwardTargetPicker(['1048576'],'Name','preview',f.host);await tick();assert.equal(f.pushes.length,2);
  f.pushes[0][2]({result:{chatId:-12}});assert.equal(f.live.forward,undefined,'old account picker cannot start forward mode');
});
test('picker source rechecks after menu availability changes',async()=>{
  const f=fixture({send:(_c,all)=>Promise.resolve(all.length===1?props(true,true,false):props(false,false,false))});const ctl=new S.ChatForwardSourceController(),states=[];
  ctl.load(f.useCase,-12,['1048576'],()=>true,s=>states.push(s));await tick();assert.equal(states.at(-1),'allowed');
  f.controller.openForwardTargetPicker(['1048576'],'Name','preview',f.host);await tick();assert.equal(f.pushes.length,0);assert.equal(f.feedback.length,1);
});
for(const action of ['reply','edit','cancelForward'])test(`new ${action} intent cancels pending picker`,async()=>{
  let release;const f=fixture({send:()=>new Promise(resolve=>release=resolve)});f.controller.openForwardTargetPicker(['1048576'],'old','preview',f.host);
  if(action==='reply')f.controller.startReply('2097152','new','preview',false,f.host);
  if(action==='edit')f.controller.startEditMessage('2097152','new text',f.host);
  if(action==='cancelForward')f.controller.cancelForwardMessages(f.host);
  release(props(true,true,false));await tick();assert.equal(f.pushes.length,0);
});
test('replacement reply ignores result from an already-open older picker',async()=>{
  const f=fixture({send:()=>Promise.resolve(props(true,true,false))});f.controller.openForwardTargetPicker(['1048576'],'old','preview',f.host);await tick();assert.equal(f.pushes.length,1);
  f.controller.startReply('2097152','new','preview',false,f.host);f.pushes[0][2]({result:{chatId:-12}});assert.equal(f.live.forward,undefined);assert.equal(f.live.reply[0],'2097152');
});
test('picker result is consumed once even before source page lifecycle advances',async()=>{
  const f=fixture({send:()=>Promise.resolve(props(true,true,false))});f.controller.openForwardTargetPicker(['1048576'],'Name','preview',f.host);await tick();const onPop=f.pushes[0][2];
  onPop({result:{chatId:7,chatTitle:'target'}});onPop({result:{chatId:7,chatTitle:'target'}});
  assert.equal(f.pushes.filter(x=>x[0]==='TgChatScreenPage').length,1);
});
// Extract actual page methods; native rendering/presentation is not emulated.
function pageClass(file,names,deps){const s=read(file);const methods=names.map(name=>{const m=new RegExp(`^  (?:(?:private|public|async)\\s+)?${name}\\(`,'m').exec(s);assert.ok(m,name);const end=s.indexOf('\n  }',m.index);return s.slice(m.index,end+4)});return new Function(...Object.keys(deps),stripTypeScriptTypes(`class Page {${methods.join('\n')}}`,{mode:'transform'})+'\nreturn Page;')(...Object.values(deps));}
const chatPageSource=read('ui/pages/chat/TgChatScreenPage.ets');
const Page=pageClass('ui/pages/chat/TgChatScreenPage.ets',['getSourceForwardUseCase','showMessageActions','closeMessageActions','refreshForwardActionAvailability','messageActionItems','handleMessageActionPress',...(chatPageSource.includes('  private messageActionsPopupStateHandler(')?['messageActionsPopupStateHandler']:[])],{});
function pageFixture(options={}){const f=fixture(options);const p=Object.assign(new Page(),{activeChatId:-12,messageActionsGeneration:0,messageActionsOpenId:'',messageActionsForwardState:'loading',forwardUseCase:f.useCase,forwardSourceCtrl:new S.ChatForwardSourceController(),messageActionsCtrl:f.controller,hasActiveChatState:()=>f.live.active,getLifecycleToken:()=>f.live.lifecycle});return {...f,p};}
test('source capability does not depend on target send rights',()=>{const f=pageFixture();f.p.canSendNewMessages=()=>false;assert.equal(f.p.getSourceForwardUseCase(),f.useCase);f.live.active=false;assert.equal(f.p.getSourceForwardUseCase(),undefined);});
test('real page retry callback keeps popup and retries then enables forward',async()=>{
  const f=pageFixture({send:(_c,all)=>all.length===1?Promise.reject(new Error('offline')):Promise.resolve(props(true,true,false))});f.p.showMessageActions(entry());assert.equal(f.p.messageActionItems().find(x=>x.id==='forward').enabled,false);await tick();
  const retry=f.p.messageActionItems().find(x=>x.id==='forwardRetry');assert.ok(retry?.enabled);f.p.handleMessageActionPress(retry);assert.equal(f.p.messageActionsOpenId,'1048576');await tick();
  assert.equal(f.p.messageActionItems().find(x=>x.id==='forward').enabled,true);assert.equal(f.commands.length,2);
});
test('real page stale action object cannot affect reopened same-message menu',async()=>{
  const f=pageFixture({send:()=>Promise.resolve(props(true,true,false))});let copied=0;f.controller.copyMessageText=()=>copied++;
  f.p.showMessageActions(entry());await tick();const old=f.p.messageActionItems().find(x=>x.id==='copy');f.p.closeMessageActions();f.p.showMessageActions(entry());await tick();
  f.p.handleMessageActionPress(old);assert.equal(copied,0);assert.equal(f.p.messageActionsOpenId,'1048576');f.p.handleMessageActionPress(f.p.messageActionItems().find(x=>x.id==='copy'));assert.equal(copied,1);
});
test('real page response from different message cannot overwrite current menu',async()=>{
  const held=[];const f=pageFixture({send:()=>new Promise(resolve=>held.push(resolve))});f.p.showMessageActions(entry());f.p.showMessageActions(entry('2097152'));held[1](props(true,true,false));await tick();held[0](props(false,false,false));await tick();assert.equal(f.p.messageActionsForwardState,'allowed');assert.equal(f.p.messageActionsOpenId,'2097152');
});
test('late dismiss callback cannot close reopened same-message popup',async()=>{
  const f=pageFixture({send:()=>Promise.resolve(props(true,true,false))});f.p.showMessageActions(entry());await tick();
  let old;
  if(f.p.messageActionsPopupStateHandler)old=f.p.messageActionsPopupStateHandler('1048576');
  else {const start=chatPageSource.indexOf('onStateChange: (event) => {',chatPageSource.indexOf('.bindPopup(this.messageActionsOpenId'));assert.ok(start>=0);const bodyStart=chatPageSource.indexOf('{',start)+1,end=chatPageSource.indexOf('\n      }\n    })',bodyStart);assert.ok(end>bodyStart);const callback=new Function('event','entry',chatPageSource.slice(bodyStart,end));old=event=>callback.call(f.p,event,entry());}
  f.p.closeMessageActions();f.p.showMessageActions(entry());await tick();old({isVisible:false});assert.equal(f.p.messageActionsOpenId,'1048576');
});
for(const boundary of ['account','chat','lifecycle','capability'])test(`rendered page action cannot outlive ${boundary}`,async()=>{
  const f=pageFixture({send:()=>Promise.resolve(props(true,true,false))});let copied=0;f.controller.copyMessageText=()=>copied++;
  f.p.showMessageActions(entry());await tick();const item=f.p.messageActionItems().find(x=>x.id==='copy');
  if(boundary==='account')f.live.active=false;if(boundary==='chat')f.p.activeChatId=-13;if(boundary==='lifecycle')f.live.lifecycle++;if(boundary==='capability')f.p.forwardUseCase=new F.ForwardMessagesUseCase({send(){throw new Error('not used')}});
  f.p.handleMessageActionPress(item);assert.equal(copied,0);assert.equal(f.p.messageActionsOpenId,'');
});
test('popup render wiring uses stable item and enabled state, not index',()=>{const s=read('ui/pages/chat/TgChatScreenPage.ets');assert.match(s,/this\.handleMessageActionPress\(item\);/);assert.match(s,/\.enabled\(item\.enabled\)/);assert.doesNotMatch(s,/this\.handleMessageActionPress\(index\)/);assert.ok(s.includes('`${item.contextToken}:${item.sourceMessageId}:${item.id}:${item.enabled}:${item.title}`'),'render key must replace ordinary class snapshots when state changes');assert.ok(s.includes('onStateChange: this.messageActionsPopupStateHandler(entry.message.messageId)'),'callback captures opening identity at bind, not event delivery');});
const pickerSource=read('ui/pages/forward/TgForwardTargetPickerPage.ets');
const Picker=pageClass('ui/pages/forward/TgForwardTargetPickerPage.ets',['rebuildChats','matchesSearch','handleChatSelect'],{ForwardTargetPickerMode:{Forward:'forward',Compose:'compose'},buildChatItemVO:chat=>({chatId:chat.id,title:chat.title??'chat'}),getAppCoreRuntime:()=>({getStore:()=>({getState:()=>pickerState})}),ForwardTargetPickerResult:class{constructor(chatId,title){this.chatId=chatId;this.chatTitle=title;}},...platform});
let pickerState;
for(const [mode,ordinary,secret,expected]of[['forward',true,false,[-12,7]],['forward',false,true,[9]],['forward',false,false,[]],['compose',false,false,[-12,7,9]]])test(`picker routes ${mode}/${ordinary}/${secret}`,()=>{
  pickerState={chats:{orderedChatIds:[-12,7,9],chats:new Map([[-12,{id:-12,type:'channel'}],[7,{id:7,type:'private'}],[9,{id:9,type:'secret'}]])}};const pops=[];const p=Object.assign(new Picker(),{mode,allowOrdinaryTargets:ordinary,allowSecretTargets:secret,searchQuery:'',canPopPageStack:()=>true,pageStack:{pop:r=>pops.push(r)}});
  p.rebuildChats(pickerState);assert.deepEqual(p.filteredChats.map(x=>x.chatId),expected);p.handleChatSelect({chatId:9,title:'secret'});assert.equal(pops.length,expected.includes(9)?1:0);
});
test('picker readiness accepts negative chat ID and rebuilds after reading flags',()=>{assert.match(pickerSource,/Number\.isSafeInteger\(params\.sourceChatId\) && params\.sourceChatId !== 0/);const ready=pickerSource.slice(pickerSource.indexOf('.onReady('));assert.ok(ready.indexOf('this.allowSecretTargets = params.allowSecretTargets === true')<ready.indexOf('this.rebuildChats('));});
const nativeStart=tests.length;
load('../../ohosTest/ets/test/ForwardSourceActions.test.ets',{
  ...C,...td,...F,...S,...serializer,describe:(_name,body)=>body(),it:(name,_flags,body)=>test('native: '+name,body),
  expect:value=>({assertEqual:expected=>assert.equal(value,expected)})
}).forwardSourceActionsTest();
assert.equal(tests.length-nativeStart,12,'all native bodies registered');
let done = false;
(async () => { let passed = 0, failed = 0;
  for (const t of tests) { let timeout; try { await Promise.race([Promise.resolve().then(t.body), new Promise((_resolve, reject) => { timeout = setTimeout(() => reject(new Error('Test timeout 3000ms')), 3000); })]); passed++; } catch (e) { failed++; console.error('FAIL', t.name, e.message); } finally { clearTimeout(timeout); } }
  done = true; if(mutant)assert.ok(mutatedFiles.size>0);console.log(JSON.stringify({ passed, failed, nativeBodiesThroughHost:tests.length-nativeStart,mutant, mutations:mutatedFiles.size, sources })); process.exitCode = failed ? 1 : 0;
})().catch(e => { done = true; console.error(e); process.exitCode = 2; });
process.on('beforeExit', () => { if (!done) process.exitCode = 2; });

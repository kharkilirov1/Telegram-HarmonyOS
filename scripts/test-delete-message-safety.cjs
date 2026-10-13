// Node >=24: actual delete use case + controller; fake transport and confirmation only.
// Never initializes TDLib or deletes real messages.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {stripTypeScriptTypes}=require('node:module');const {createHash}=require('node:crypto');
const root=path.resolve(__dirname,'../entry/src/main/ets'),sources={};
const mutant=process.argv.find(arg=>arg.startsWith('--mutant='))?.slice(9);assert.ok(!mutant||['confirmation','mode-scope','result-ok','flow-context','old-cleanup','cancel-index','dispatch-guard','forward-intent'].includes(mutant));const mutated=new Set();
function read(file){let s=fs.readFileSync(path.join(root,file),'utf8').replaceAll('\r\n','\n');sources[file]=createHash('sha256').update(s).digest('hex');let from,to;
  if(file==='domain/usecases/deleteMessages.ets'){
    if(mutant==='mode-scope'){from='params.revoke ? availability.forEveryone : availability.forSelf';to='availability.forSelf || availability.forEveryone';}
    if(mutant==='result-ok'){from="!(response instanceof TdObject) || response.getTopLevelStringStrict('@type') !== 'ok'";to='false';}
    if(mutant==='dispatch-guard'){from='if (!canContinue())';to='if (false)';assert.ok(s.includes('if (!canDispatch() ||'));s=s.replace('if (!canDispatch() ||','if (false ||');}
  }
  if(file==='ui/pages/chat/ChatDeleteMessageController.ets'){
    if(mutant==='confirmation'){from='await this.confirmation.confirm(availability, host, current)';to='true';}
    if(mutant==='cancel-index'){from='const modes: (boolean | undefined)[] = [undefined];';to='const modes: (boolean | undefined)[] = [true];';}
    if(mutant==='old-cleanup'){from='if (generation !== this.generation) return;';to='';}
    if(mutant==='flow-context'){from='generation === this.generation && host.hasActiveChatState() &&\n      host.getActiveChatId() === chatId && host.getLifecycleToken() === lifecycle && host.getDeleteUseCase() === useCase';to='true';}
  }
  if(file==='ui/pages/chat/ChatMessageActionsController.ets'&&mutant==='forward-intent'){from='this.deleteController?.cancel();\n    this.editController?.cancel();\n    if (this.forwardPickerOpen';to='this.editController?.cancel();\n    if (this.forwardPickerOpen';}
  if(from){assert.ok(s.includes(from),'mutation engages '+mutant);s=s.replaceAll(from,to);mutated.add(file);}return s;}
function load(file,deps={}){const s=read(file),names=[...s.matchAll(/^export\s+(?:default\s+)?(?:class|function|const|enum)\s+(\w+)/gm)].map(m=>m[1]);const js=stripTypeScriptTypes(s.replace(/^import[\s\S]*?;\s*/gm,'').replace(/^export\s+(?:default\s+)?/gm,''),{mode:'transform',sourceUrl:file});return new Function(...Object.keys(deps),`${js}\nreturn {${names.join(',')}};`)(...Object.values(deps));}
const platform={hilog:{info(){},warn(){},error(){}},localized:(_id,fallback)=>fallback,$r:id=>({id})};
const C=load('core/model/AppCommand.ets'),td=load('models/td/common/index.ets'),E=load('core/model/AppError.ets');
const D=load('domain/usecases/deleteMessages.ets',{...C,...td,...E,...platform});
const F=load('domain/usecases/forwardMessages.ets',{...C,...td,...E,...platform});
const UI=load('ui/pages/chat/ChatDeleteMessageController.ets',{...D,...platform,TgUiTokens:{COLOR_TEXT_TITLE:'primary',COLOR_TEXT_ERROR:'error'}});
const A=load('ui/pages/chat/ChatMessageActionsController.ets',{...D,...F,...UI,...platform});
const serializer=load('infra/td/serialization/CommandSerializer.ets',{...C,...td,...platform});
const raw=value=>td.TdObject.fromJSON(JSON.stringify(value));const tick=()=>new Promise(resolve=>setImmediate(resolve));
const props=(self=true,all=true)=>raw({'@type':'messageProperties',can_be_deleted_only_for_self:self,can_be_deleted_for_all_users:all});
const params=(ids=['1048576'],revoke=false)=>Object.assign(new D.DeleteMessagesParams(),{chatId:-12,messageIds:ids,revoke});
function fixture(options={}){
  const commands=[],dialogs=[],feedback=[],confirmations=[];
  const gateway={send(command){commands.push(command);if(options.send){const value=options.send(command,commands);if(value!==undefined)return value;}if(command.type==='getMessageProperties')return Promise.resolve(props());if(command.type==='deleteMessages')return Promise.resolve(raw({'@type':'ok'}));throw new Error('unexpected command '+command.type);}};
  const useCase=new D.DeleteMessagesUseCase(gateway);const live={chatId:-12,lifecycle:1,active:true,useCase};
  const host={getActiveChatId:()=>live.chatId,getLifecycleToken:()=>live.lifecycle,hasActiveChatState:()=>live.active,getDeleteUseCase:()=>live.active?live.useCase:undefined,getChatUIContext:()=>({getPromptAction:()=>({showDialog:dialog=>{dialogs.push(dialog);if(options.dialog)return options.dialog(dialog);return new Promise(resolve=>{confirmations.push(resolve);});},showToast:options=>feedback.push(options)})}),clearEditMode(){},clearForwardMode(){},clearReplyMode(){},setReplyMode(){},setEditMode(){},setDraftText(){}};
  return{commands,dialogs,feedback,host,live,useCase,controller:new A.ChatMessageActionsController(),confirm:(value,index=confirmations.length-1)=>{assert.equal(typeof confirmations[index],'function');confirmations[index](value);},mutations:()=>commands.filter(c=>c.type==='deleteMessages')};
}
const tests=[];function test(name,body){tests.push({name,body});}
test('delete waits for explicit confirmation before mutating transport',async()=>{const f=fixture();f.controller.handleDeleteMessage('1048576',f.host);await tick();assert.equal(f.mutations().length,0);assert.equal(f.dialogs.length,1);});
test('unsafe ID input cannot reach delete transport',async()=>{const f=fixture();await assert.rejects(f.useCase.execute(params(['1,2'])));assert.equal(f.commands.length,0);});
test('fulfilled error response cannot be reported as deletion success',async()=>{const f=fixture({send:c=>c.type==='deleteMessages'?Promise.resolve(raw({'@type':'error',code:400,message:'Denied'})):undefined});await assert.rejects(f.useCase.execute(params()));});
test('for-everyone mode is refused when only self deletion is allowed',async()=>{const f=fixture({send:c=>c.type==='getMessageProperties'?Promise.resolve(props(true,false)):undefined});await assert.rejects(f.useCase.execute(params(['1048576'],true)));assert.equal(f.mutations().length,0);});
test('default delete mode never silently escalates to everyone',()=>{assert.equal(new D.DeleteMessagesParams().revoke,false);assert.equal(C.createDeleteMessagesCommand(-12,['1048576']).payload.revoke,false);});
for(const [self,all,index,expected] of [[true,true,1,false],[true,true,2,true],[true,false,1,false],[false,true,1,true]])test(`confirmation maps permitted modes ${self}/${all} index${index}`,async()=>{
  const f=fixture({send:c=>c.type==='getMessageProperties'?Promise.resolve(props(self,all)):undefined});f.controller.handleDeleteMessage('1048576',f.host);await tick();
  assert.deepEqual(f.dialogs[0].buttons.map(b=>b.text),['Cancel',...(self?['Delete for me']:[]),...(all?['Delete for everyone']:[])]);
  assert.equal(f.mutations().length,0);f.confirm({index});await tick();assert.equal(f.mutations().length,1);assert.equal(f.mutations()[0].payload.revoke,expected);
  assert.deepEqual(f.commands.map(c=>c.type),['getMessageProperties','getMessageProperties','deleteMessages']);
});
for(const result of [{index:0},{},{index:-1},{index:3},{index:1.5},{index:'1'},{index:NaN},null,undefined])test(`cancel or invalid native result ${JSON.stringify(result)} never deletes`,async()=>{
  const f=fixture();f.controller.handleDeleteMessage('1048576',f.host);await tick();f.confirm(result);await tick();assert.equal(f.mutations().length,0);
  f.controller.handleDeleteMessage('1048576',f.host);await tick();assert.equal(f.dialogs.length,2,'cancel releases flow for explicit retry');
});
test('unavailable dialog does not delete or auto-retry',async()=>{const f=fixture({dialog:()=>Promise.reject(new Error('cancel or unavailable UI'))});f.controller.handleDeleteMessage('1048576',f.host);await tick();assert.equal(f.mutations().length,0);assert.equal(f.commands.length,1);});
test('known no delete mode gives feedback without confirmation',async()=>{const f=fixture({send:c=>c.type==='getMessageProperties'?Promise.resolve(props(false,false)):undefined});f.controller.handleDeleteMessage('1048576',f.host);await tick();assert.equal(f.dialogs.length,0);assert.equal(f.mutations().length,0);assert.equal(f.feedback.length,1);});
for(const input of [[],['0'],['-1'],['01'],[' 1'],['1 '],['1.5'],['1e6'],['9007199254740992'],[1],[null],undefined])test('invalid IDs before any read: '+JSON.stringify(input),async()=>{const f=fixture(),p=params();p.messageIds=input;await assert.rejects(f.useCase.execute(p));assert.equal(f.commands.length,0);});
for(const value of [0,NaN,Infinity,1.5,'7',false,9007199254740992])test('invalid chat ID '+String(value),async()=>{const f=fixture(),p=params();p.chatId=value;await assert.rejects(f.useCase.execute(p));assert.equal(f.commands.length,0);});
for(const value of ['false',0,null,undefined])test('revoke must be explicit boolean '+String(value),async()=>{const f=fixture(),p=params();p.revoke=value;await assert.rejects(f.useCase.execute(p));assert.equal(f.commands.length,0);});
test('delete supports >100 unsorted source IDs without forward contract leakage',async()=>{
  const f=fixture();const ids=Array.from({length:101},(_,i)=>String((102-i)*1048576));ids.push(ids[0]);await f.useCase.execute(params(ids));assert.deepEqual(f.mutations()[0].payload.messageIds,ids.slice(0,101));assert.equal(f.commands.length,102);assert.equal(ids.length,102);
});
test('IDs/chat/mode are captured before properties await',async()=>{
  let release;const f=fixture({send:(c,all)=>c.type==='getMessageProperties'&&all.length===1?new Promise(resolve=>release=resolve):undefined});const p=params(['2097152','1048576','2097152'],false);const pending=f.useCase.execute(p);p.chatId=7;p.messageIds.splice(0,p.messageIds.length,'3145728');p.revoke=true;release(props());await pending;assert.deepEqual(f.mutations()[0].payload.messageIds,['2097152','1048576']);assert.equal(f.mutations()[0].payload.chatId,-12);assert.equal(f.mutations()[0].payload.revoke,false);
});
for(const payload of [raw({'@type':'error',code:400}),raw({'@type':'messageProperties',can_be_deleted_only_for_self:'true',can_be_deleted_for_all_users:true}),raw({'@type':'messageProperties',nested:{can_be_deleted_only_for_self:true,can_be_deleted_for_all_users:true}}),raw({'@type':'messageProperties',can_be_deleted_only_for_self:true}),{'@type':'messageProperties',can_be_deleted_only_for_self:true,can_be_deleted_for_all_users:true}])test('missing/malformed properties cannot grant deletion',async()=>{const f=fixture({send:c=>c.type==='getMessageProperties'?Promise.resolve(payload):undefined});await assert.rejects(f.useCase.execute(params()));assert.equal(f.mutations().length,0);});
for(const revoke of [false,true])test(`batch deletion intersects chosen mode ${revoke}`,async()=>{const f=fixture({send:c=>c.type==='getMessageProperties'?Promise.resolve(c.payload.messageId==='1048576'?props(true,false):props(false,true)):undefined});await assert.rejects(f.useCase.execute(params(['1048576','2097152'],revoke)));assert.equal(f.mutations().length,0);});
test('source-only local deletion follows properties, not a blanket negative-chat forced revoke rule',async()=>{const f=fixture({send:c=>c.type==='getMessageProperties'?Promise.resolve(props(true,false)):undefined});await f.useCase.execute(params(['1048578'],false));assert.equal(f.mutations()[0].payload.revoke,false);assert.equal(f.commands.some(c=>c.type==='getChat'),false);});
test('chosen global mode is not downgraded after permission revocation during dialog',async()=>{
  let reads=0;const f=fixture({send:c=>c.type==='getMessageProperties'?Promise.resolve(props(true,++reads===1)):undefined});f.controller.handleDeleteMessage('1048576',f.host);await tick();f.confirm({index:2});await tick();assert.equal(f.mutations().length,0);assert.equal(f.feedback.length,1);assert.equal(f.dialogs.length,1);
});
test('chosen self mode is never escalated when only everyone remains allowed',async()=>{let reads=0;const f=fixture({send:c=>c.type==='getMessageProperties'?Promise.resolve(props(++reads===1,true)):undefined});f.controller.handleDeleteMessage('1048576',f.host);await tick();f.confirm({index:1});await tick();assert.equal(f.mutations().length,0);assert.equal(f.feedback.length,1);});
for(const timing of ['before-read','during-read'])test(`domain dispatch guard ${timing}`,async()=>{let release,active=timing!=='before-read';const f=fixture({send:c=>c.type==='getMessageProperties'?new Promise(resolve=>release=resolve):undefined});const pending=f.useCase.execute(params(),()=>active);const rejected=assert.rejects(pending);if(timing==='during-read'){active=false;release(props());}await rejected;assert.equal(f.mutations().length,0);assert.equal(f.commands.length,timing==='before-read'?0:1);});
for(const boundary of ['active','chatId','lifecycle','useCase'])test(`confirmation cannot outlive ${boundary}`,async()=>{
  const f=fixture();f.controller.handleDeleteMessage('1048576',f.host);await tick();f.live[boundary]=boundary==='active'?false:boundary==='chatId'?-13:boundary==='lifecycle'?2:new D.DeleteMessagesUseCase({send(){throw new Error('unused')}});f.confirm({index:2});await tick();assert.equal(f.mutations().length,0);assert.equal(f.feedback.length,0);
});
for(const phase of ['pre-dialog','post-dialog'])test(`source read fence during ${phase}`,async()=>{
  let release,reads=0;const f=fixture({send:c=>c.type==='getMessageProperties'&&(++reads===(phase==='pre-dialog'?1:2))?new Promise(resolve=>release=resolve):undefined});f.controller.handleDeleteMessage('1048576',f.host);await tick();
  if(phase==='post-dialog'){f.confirm({index:1});await tick();}f.live.active=false;release(props());await tick();assert.equal(f.mutations().length,0);assert.equal(f.dialogs.length,phase==='pre-dialog'?0:1);
});
test('duplicate taps while confirming/deleting never multiply dialogs or requests',async()=>{
  let release;const f=fixture({send:c=>c.type==='deleteMessages'?new Promise(resolve=>release=resolve):undefined});f.controller.handleDeleteMessage('1048576',f.host);f.controller.handleDeleteMessage('1048576',f.host);await tick();assert.equal(f.dialogs.length,1);f.controller.handleDeleteMessage('2097152',f.host);assert.equal(f.dialogs.length,1);
  f.confirm({index:1});await tick();f.controller.handleDeleteMessage('1048576',f.host);await tick();assert.equal(f.mutations().length,1);assert.equal(f.dialogs.length,1);release(raw({'@type':'ok'}));await tick();
});
test('latest loading source wins before a dialog has opened',async()=>{
  const held=[];const f=fixture({send:c=>c.type==='getMessageProperties'?new Promise(resolve=>held.push(resolve)):undefined});f.controller.handleDeleteMessage('1048576',f.host);f.controller.handleDeleteMessage('2097152',f.host);held[0](props());await tick();assert.equal(f.dialogs.length,0);held[1](props());await tick();assert.equal(f.dialogs.length,1);f.confirm({index:0});await tick();
});
test('old confirmation cleanup cannot unlock the new account flow',async()=>{
  const f=fixture();f.controller.handleDeleteMessage('1048576',f.host);await tick();f.live.chatId=-13;f.controller.handleDeleteMessage('2097152',f.host);await tick();assert.equal(f.dialogs.length,2);f.confirm({index:2},0);await tick();f.controller.handleDeleteMessage('2097152',f.host);await tick();assert.equal(f.dialogs.length,2);f.confirm({index:1},1);await tick();assert.equal(f.mutations().length,1);assert.equal(f.mutations()[0].payload.chatId,-13);
});
for(const action of ['reply','edit','cancel'])test(`replacing ${action} invalidates delete confirmation`,async()=>{
  const f=fixture();f.controller.handleDeleteMessage('1048576',f.host);await tick();if(action==='reply')f.controller.startReply('2097152','Name','preview',false,f.host);if(action==='edit')f.controller.startEditMessage('2097152','text',f.host);if(action==='cancel')f.controller.cancelPendingMessageActions();f.confirm({index:2});await tick();assert.equal(f.mutations().length,0);
});
for(const response of [raw({}),raw({'@type':'messages'}),raw({nested:{'@type':'ok'}}),{'@type':'ok'},new td.TdObject(),undefined])test('only received strict Ok confirms the mutation',async()=>{const f=fixture({send:c=>c.type==='deleteMessages'?Promise.resolve(response):undefined});await assert.rejects(f.useCase.execute(params()),e=>e instanceof D.DeleteMessagesOutcomeError&&e.retryable===false);assert.equal(f.mutations().length,1);});
test('transport failure does not auto-retry or change revoke scope',async()=>{const f=fixture({send:c=>c.type==='deleteMessages'?Promise.reject(new Error('connection lost')):undefined});f.controller.handleDeleteMessage('1048576',f.host);await tick();f.confirm({index:2});await tick();assert.equal(f.mutations().length,1);assert.equal(f.mutations()[0].payload.revoke,true);assert.equal(f.feedback.length,1);await tick();assert.equal(f.mutations().length,1);});
test('preflight failure is reported as unavailable, not as a possibly dispatched deletion',async()=>{const f=fixture({send:()=>Promise.reject(new Error('properties unavailable'))});f.controller.handleDeleteMessage('1048576',f.host);await tick();assert.equal(f.mutations().length,0);assert.equal(f.feedback[0].message,'This message cannot be deleted now.');});
test('wire request uses exact numeric IDs and explicitly selected revoke',()=>{const c=C.createDeleteMessagesCommand(-12,['2251799812636672','1048578'],false);const s=serializer.serializeCommand(c),j=serializer.buildTdlibRequestJson(s.method,s.params);assert.deepEqual(JSON.parse(j),{'@type':'deleteMessages',chat_id:-12,message_ids:[2251799812636672,1048578],revoke:false});});
for(const stage of ['loading','confirming','rechecking'])test(`direct channel-share Forward cancels pending delete during ${stage}`,async()=>{
  let release,reads=0,forwardCalls=0;
  const f=fixture({send:c=>c.type==='getMessageProperties'&&++reads===(stage==='loading'?1:stage==='rechecking'?2:0)?new Promise(resolve=>release=resolve):undefined});
  const forward={prepare:input=>({messageIds:input.messageIds.slice()}),getSourceAvailability(){forwardCalls++;return new Promise(()=>{});}};
  f.host.getSourceForwardUseCase=()=>forward;
  f.controller.handleDeleteMessage('1048576',f.host);await tick();
  if(stage==='rechecking'){f.confirm({index:2});await tick();}
  f.controller.openForwardTargetPicker(['2097152'],'Author','preview',f.host);assert.equal(forwardCalls,1);
  if(stage==='confirming')f.confirm({index:2});else release(props());await tick();
  assert.equal(f.dialogs.length,stage==='loading'?0:1);assert.equal(f.mutations().length,0);assert.equal(f.feedback.length,0);
});
// Execute the exact Hypium test bodies, with only the assertion/registration and
// platform boundary adapted to Node. This is not native-device execution.
let nativeBodiesThroughHost=0;
const hypium={describe:(_name,body)=>body(),it:(name,_flags,body)=>{nativeBodiesThroughHost++;test('Hypium: '+name,body);},expect:value=>({assertEqual:expected=>assert.strictEqual(value,expected),assertTrue:()=>assert.strictEqual(value,true),assertFalse:()=>assert.strictEqual(value,false)})};
load('../../ohosTest/ets/test/DeleteMessagesSafety.test.ets',{...C,...td,...E,...D,...UI,...hypium}).deleteMessagesSafetyTest();
const album=load('domain/usecases/sendMediaAlbum.ets',{...C,...td,...E,...platform});
const useCases={...D,...F,...album};
const editFormatting=load('domain/usecases/EditMessageFormatting.ets',{...C,...td});
for(const file of ['editMessage','sendMessage','sendMediaMessage'])Object.assign(useCases,load(`domain/usecases/${file}.ets`,{...C,...td,...E,...album,...editFormatting,...platform}));
load('../../ohosTest/ets/test/UseCases.test.ets',{...C,...td,...E,...useCases,...hypium}).useCasesTest();
assert.equal(nativeBodiesThroughHost,20,'all 14 deletion and 6 compatibility bodies registered');
let done=false;
(async()=>{let passed=0,failed=0;for(const t of tests){let timeout;try{await Promise.race([Promise.resolve().then(t.body),new Promise((_resolve,reject)=>{timeout=setTimeout(()=>reject(new Error('Test timeout3000ms')),3000);})]);passed++;}catch(e){failed++;console.error('FAIL',t.name,e.message);}finally{clearTimeout(timeout);}}done=true;if(mutant)assert.ok(mutated.size>0);console.log(JSON.stringify({passed,failed,mutant,mutations:mutated.size,nativeBodiesThroughHost,sources}));process.exitCode=failed?1:0;})().catch(e=>{done=true;console.error(e);process.exitCode=2;});
process.on('beforeExit',()=>{if(!done)process.exitCode=2;});

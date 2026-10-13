// Actual TdObject -> MessageDto -> MessageNormalizer -> messagesReducer.
// Native transport and hilog are explicit boundaries. These are no delivery tests.
const H = require('./stabilization-harness.cjs');
const {assert,load,run,methods,read} = H;
const td = load('models/td/common/index.ets');
const ac = load('core/utils/tdAccessors.ets',td);
const A = load('core/model/AppState.ets');
const dto = load('core/model/dto/MessageDto.ets',{...td,...ac});
const E = load('core/model/AppEvent.ets',dto);
const clone = load('core/utils/stateClone.ets',A);
const reply = load('core/utils/replyMessageKey.ets');
const R = load('core/reducers/messagesReducer.ets',{...A,...clone,...reply,...dto});
const logs=[];
const N = load('core/events/normalizers/MessageNormalizer.ets',{...E,...dto,...td,...ac,hilog:{error:(...a)=>logs.push(a),warn:(...a)=>logs.push(a),info(){},debug(){}}});
const handlers=new Map(); N.registerMessageHandlers(handlers);
const raw=value=>td.TdObject.fromJSON(JSON.stringify(value));
const msg=(id,chat_id=42,sending_state=null,text='draft',sender={'@type':'messageSenderUser',user_id:7})=>({
  '@type':'message',id,sender_id:sender,chat_id,sending_state,is_outgoing:true,date:1700000000,
  content:{'@type':'messageText',text:{'@type':'formattedText',text,entities:[]}}
});
const pending={'@type':'messageSendingStatePending',sending_id:3};
const failed=(code=429,message='SLOWMODE_WAIT_7')=>({'@type':'messageSendingStateFailed',error:{'@type':'error',code,message},can_retry:true,retry_after:7});
function apply(state,type,data) { const events=[]; handlers.get(type)(events,raw({'@type':type,...data})); for(const e of events)state=R.messagesReducer(state,e); return {state,events}; }
function add(message,state=A.createInitialAppState()) { return apply(state,'updateNewMessage',{message}); }
const row=(s,chat=42,id='100')=>s.messages.messages.get(chat)?.get(id);
const tests=[]; const test=(name,fn)=>tests.push([name,fn]);
test('ordinary Message reaches the actual reducer',()=>assert.equal(row(add(msg(100)).state).content.text,'draft'));
test('pending Message has authoritative isPending',()=>assert.equal(row(add(msg(100,42,pending)).state).isPending,true));
test('pending Message has pending display status',()=>assert.equal(row(add(msg(100,42,pending)).state).sendStatus,'pending'));
test('null sending_state is not pending',()=>assert.equal(row(add(msg(100)).state).isPending,false));
test('new Message failed sending_state survives normalizer and reducer',()=>assert.equal(row(add(msg(100,42,failed())).state).sendStatus,'failed'));
test('hydrated failure preserves safe error code',()=>assert.equal(row(add(msg(100,42,failed())).state).sendErrorCode,429));
test('hydrated failure preserves allowed error text',()=>assert.equal(row(add(msg(100,42,failed())).state).sendErrorMessage,'SLOWMODE_WAIT_7'));
function sendFail(state=add(msg(100,42,pending)).state,newId=101,code=429,body='server-normalized') { return apply(state,'updateMessageSendFailed',{message:msg(newId,42,failed(code,code===406?'DO_NOT_READ_SECRET':'SLOWMODE_WAIT_7'),body),old_message_id:100,error:{'@type':'error',code,message:code===406?'DO_NOT_READ_SECRET':'SLOWMODE_WAIT_7'}}); }
test('sendFailed normalizer preserves new authoritative id',()=>assert.equal(sendFail().events[0].messageId,'101'));
test('sendFailed atomically retires temporary id',()=>{const s=sendFail().state;assert.equal(s.messages.messages.get(42).has('100'),false);assert.equal(s.messages.messages.get(42).has('101'),true);});
test('sendFailed installs authoritative changed body',()=>assert.equal(row(sendFail().state,42,'101')?.content.text,'server-normalized'));
test('sendFailed installs failed status at new identity',()=>assert.equal(row(sendFail().state,42,'101')?.sendStatus,'failed'));
test('permanent delete by authoritative failure id leaves no ghost',()=>{const s=apply(sendFail().state,'updateDeleteMessages',{chat_id:42,message_ids:[101],is_permanent:true,from_cache:false}).state;assert.equal(s.messages.messages.get(42)?.size||0,0);});
test('failure without a visible pending row still publishes authoritative Message',()=>assert.equal(row(sendFail(A.createInitialAppState()).state,42,'101')?.content.text,'server-normalized'));
test('same-id failure remains deterministic',()=>{const s=sendFail(undefined,100).state;assert.equal(s.messages.messages.get(42).size,1);assert.equal(row(s).sendStatus,'failed');});
test('repeated failure updates keep exactly one canonical row',()=>{const f=sendFail();const repeated=sendFail(f.state);assert.deepEqual([...repeated.state.messages.messages.get(42).keys()],['101']);});
test('failure reduction never mutates original pending snapshot',()=>{const old=add(msg(100,42,pending)).state;sendFail(old);assert.equal(row(old).content.text,'draft');assert.equal(row(old).isPending,true);assert.equal(old.messages.messages.get(42).has('101'),false);});
test('reload of failed authority keeps one failed row',()=>{const f=sendFail();const reloaded=add(msg(101,42,failed(),'server-normalized'),f.state).state;assert.deepEqual([...reloaded.messages.messages.get(42).keys()],['101']);assert.equal(row(reloaded,42,'101').sendStatus,'failed');});
test('success retires pending identity and clears pending status',()=>{const s=apply(add(msg(100,42,pending)).state,'updateMessageSendSucceeded',{message:msg(201,42,null,'accepted'),old_message_id:100}).state;assert.deepEqual([...s.messages.messages.get(42).keys()],['201']);assert.equal(row(s,42,'201').isPending,false);assert.equal(row(s,42,'201').sendStatus,'sent');});
for(const [type,extra] of [['updateNewMessage',{}],['updateMessageSendSucceeded',{old_message_id:100}],['updateMessageSendFailed',{old_message_id:100,error:{'@type':'error',code:400,message:'FAILED'}}]]) {
  test(type+' uses target-chat identity after nested sender chat',()=>{const m=msg(200,-100200,type==='updateMessageSendFailed'?failed(400,'FAILED'):null,'linked discussion',{'@type':'messageSenderChat',chat_id:-100100});const f=apply(A.createInitialAppState(),type,{message:m,...extra});assert.equal(f.events[0].chatId,-100200);assert.equal(f.state.messages.messages.has(-100100),false);assert.ok(f.state.messages.messages.get(-100200)?.has('200'));});
}
test('sender chat identity is preserved separately',()=>{const f=add(msg(200,-100200,null,'linked discussion',{'@type':'messageSenderChat',chat_id:-100100}));assert.equal(f.events[0].messageData.senderChatId,-100100);});
test('identity routing is independent of top-level field ordering',()=>{const m=msg(200,-100200,null,'reverse',{'@type':'messageSenderChat',chat_id:-100100});const reverse=Object.fromEntries(Object.entries(m).reverse());assert.equal(add(reverse).events[0].chatId,-100200);});
test('hydrated 406 omits application error text',()=>{const s=add(msg(100,42,failed(406,'DO_NOT_READ_SECRET'))).state;assert.equal(row(s).sendStatus,'failed');assert.equal(row(s).sendErrorCode,406);assert.equal(row(s).sendErrorMessage,'');assert.equal(JSON.stringify(s.messages.messages.get(42).get('100')).includes('DO_NOT_READ_SECRET'),false);});
test('live 406 keeps safe new identity and omits error text',()=>{const f=sendFail(undefined,101,406);assert.equal(row(f.state,42,'101')?.sendErrorCode,406);assert.equal(row(f.state,42,'101')?.sendErrorMessage,'');assert.equal(JSON.stringify(f.events).includes('DO_NOT_READ_SECRET'),false);});
test('independent target messages survive replacement and delete',()=>{let s=add(msg(900,42,null,'unrelated')).state;s=add(msg(100,42,pending),s).state;s=sendFail(s).state;s=apply(s,'updateDeleteMessages',{chat_id:42,message_ids:[101],is_permanent:true,from_cache:false}).state;assert.deepEqual([...s.messages.messages.get(42).keys()],['900']);});
test('actual messages history handler retains pending and failed state',()=>{const f=apply(A.createInitialAppState(),'messages',{total_count:2,messages:[msg(100,42,pending),msg(101,42,failed())]});assert.equal(f.events.length,2);assert.equal(row(f.state).sendStatus,'pending');assert.equal(row(f.state,42,'101').sendStatus,'failed');});
test('actual messages history handler routes channel sender to target chat',()=>{const f=apply(A.createInitialAppState(),'messages',{total_count:1,messages:[msg(200,-100200,pending,'history',{'@type':'messageSenderChat',chat_id:-100100})]});assert.equal(f.events[0].chatId,-100200);assert.equal(f.events[0].messageData.senderChatId,-100100);assert.equal(f.state.messages.messages.has(-100100),false);});
for(const [field,value] of [['chat_id',undefined],['chat_id','-100200'],['chat_id',0],['chat_id',false],['chat_id',1.25],['id',undefined],['id',false],['id',1.5]])test('containing-object '+field+'='+String(value)+' cannot borrow nested identity',()=>{const m=msg(200,-100200,pending,'invalid',{'@type':'messageSenderChat',chat_id:-100100});m.reply_to={'@type':'messageReplyToMessage',chat_id:-100300,message_id:600};if(value===undefined)delete m[field];else m[field]=value;const f=add(m);assert.equal(f.events.length,0);assert.equal(f.state.messages.messages.size,0);});
test('applyMessageUpdate DTO clone preserves failed discriminator and sanitized error',()=>{const before=dto.createMessageDtoFromTd(raw(msg(100,42,failed(400,'FAILED'))));const update=new dto.MessageUpdateDto();update.editDate=33;const after=dto.applyMessageUpdate(before,update);assert.equal(after.sendingState,'failed');assert.equal(after.sendErrorCode,400);assert.equal(after.sendErrorMessage,'FAILED');assert.equal(after.editDate,33);assert.notEqual(after,before);});
const fileReducer=load('core/reducers/filesReducer.ets',{...A,...clone,...E,hilog:{info(){},warn(){},error(){},debug(){}}});
for(const sending of [pending,failed()])test('actual file completion clone retains '+sending['@type'],()=>{let s=add(msg(100,42,sending)).state;row(s).content.documentFileId=77;const event=new E.FileDownloadedEvent();event.fileId=77;event.localPath='/fixture/download';event.isComplete=true;const next=fileReducer.filesReducer(s,event);assert.equal(row(next).content.documentPath,'/fixture/download');assert.equal(row(next).sendStatus,sending===pending?'pending':'failed');assert.equal(row(next).sendErrorCode,sending===pending?0:429);assert.equal(row(s).content.documentPath,'');});
const meta=read('ui/tg_ui/atoms/TgMessageMeta.ets').match(/export enum TgMessageSendStatus\s*\{[\s\S]*?\n\}/)[0];
const statuses=new Function(require('node:module').stripTypeScriptTypes(meta.replace('export ',''),{mode:'transform'})+'\nreturn TgMessageSendStatus;')();
const selectors=load('domain/selectors/messageSelectors.ets',{...A,...ac});
const VO=load('ui/pages/chat/ChatTimelineVO.ets',{...A,...ac,...selectors,...reply,TgMessageSendStatus:statuses,getString:()=>'',fileUri:{getUriFromPath:p=>'file://'+p},hilog:{info(){},warn(){},error(){}}},source=>source+'\nexport const actualResolveMessageSendStatus=resolveMessageSendStatus;\n');
for(const sending of [pending,failed()])test('actual VO displays '+sending['@type']+' instead of false Sent',()=>{const s=add(msg(100,42,sending)).state;const chat=Object.assign(new A.Chat(),{id:42});assert.equal(VO.actualResolveMessageSendStatus(row(s),chat),sending===pending?statuses.Sending:statuses.Failed);});
const chatDto=load('core/model/dto/ChatDto.ets',{...td,...ac,hilog:{info(){},warn(){},error(){}}});
const syntheticEvents=load('core/model/AppEvent.ets',{...dto,...chatDto});
const Synthetic=methods('app/bootstrap/AppCoreRuntime.ets',['appendSyntheticChatUpdateForLiveMessage'],{...td,...ac,...dto,...syntheticEvents,...chatDto});
test('actual AppCoreRuntime synthetic lastMessage routes target instead of nested sender',()=>{const f=new Synthetic(),events=[];f.appendSyntheticChatUpdateForLiveMessage(raw({'@type':'updateNewMessage',message:msg(200,-100200,null,'live',{'@type':'messageSenderChat',chat_id:-100100})}),events);assert.equal(events.length,1);assert.equal(events[0].chatId,-100200);assert.equal(events[0].updates.lastMessage.id,'200');});
function errorReads(callback){let reads=0;const original=new Map();for(const key of ['getString','getTopLevelStringStrict']){original.set(key,td.TdObject.prototype[key]);td.TdObject.prototype[key]=function(field){if(field==='message'&&this.getType()==='error')reads++;return original.get(key).call(this,field);};}try{callback();return reads;}finally{for(const [key,fn]of original)td.TdObject.prototype[key]=fn;}}
test('hydrated406 never invokes any error message getter',()=>assert.equal(errorReads(()=>add(msg(100,42,failed(406,'DO_NOT_READ_SECRET')))),0));
test('live406 never invokes update or nested error message getter',()=>assert.equal(errorReads(()=>sendFail(undefined,101,406)),0));
test('update406 suppresses nested non406 error getter too',()=>assert.equal(errorReads(()=>apply(A.createInitialAppState(),'updateMessageSendFailed',{message:msg(101,42,failed(400,'NESTED_SECRET')),old_message_id:100,error:{'@type':'error',code:406,message:'UPDATE_SECRET'}})),0));
test('update400 reads allowed text while nested406 stays silent',()=>{let updateReads=0,nestedReads=0;const original=td.TdObject.prototype.getTopLevelStringStrict;td.TdObject.prototype.getTopLevelStringStrict=function(key){if(key==='message'&&this.getType()==='error'){if(this.getTopLevelNumberStrict('code')===406)nestedReads++;else updateReads++;}return original.call(this,key);};try{const f=apply(A.createInitialAppState(),'updateMessageSendFailed',{message:msg(101,42,failed(406,'NESTED_SECRET')),old_message_id:100,error:{'@type':'error',code:400,message:'ALLOWED'}});assert.equal(nestedReads,0);assert.equal(updateReads,1);assert.equal(f.events[0].errorMessage,'ALLOWED');}finally{td.TdObject.prototype.getTopLevelStringStrict=original;}});
for(const code of [undefined,'406',406.5])test('malformed error code '+String(code)+' never reads error text',()=>{const state=failed();state.error.code=code;assert.equal(errorReads(()=>add(msg(100,42,state))),0);});
test('non406 getter spy positive control is engaged',()=>assert.ok(errorReads(()=>sendFail(undefined,101,400))>=1));
run('stabilization messages',tests).catch(error=>{console.error(error.stack);process.exitCode=1;});
module.exports={msg,failed,pending};

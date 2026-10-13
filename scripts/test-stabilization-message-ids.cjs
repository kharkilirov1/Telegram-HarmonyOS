// Preserve internal opaque decimal Message IDs losslessly. TDLib wire int53
// bounds remain narrower; these are local parser compatibility/fencing tests.
const H=require('./stabilization-harness.cjs'),{assert,load,run}=H;
const td=load('models/td/common/index.ets'),ac=load('core/utils/tdAccessors.ets',td),A=load('core/model/AppState.ets');
const D=load('core/model/dto/MessageDto.ets',{...td,...ac}),E=load('core/model/AppEvent.ets',D);
const clone=load('core/utils/stateClone.ets',A),reply=load('core/utils/replyMessageKey.ets');
const R=load('core/reducers/messagesReducer.ets',{...A,...clone,...reply,...D});
const N=load('core/events/normalizers/MessageNormalizer.ets',{...E,...D,...td,...ac,hilog:{error(){},warn(){},info(){},debug(){}}});
const handlers=new Map();N.registerMessageHandlers(handlers);
const BIG='9223372036854775001',NEXT='9223372036854775002';
function message(literal,sending='null',body='exact identity'){
 return '{"@type":"message","id":'+literal+',"sender_id":{"@type":"messageSenderUser","user_id":7},"chat_id":42,"sending_state":'+sending+',"is_outgoing":true,"date":1700000000,"content":{"@type":"messageText","text":{"@type":"formattedText","text":'+JSON.stringify(body)+',"entities":[]}}}';
}
const pending='{"@type":"messageSendingStatePending","sending_id":1}';
const failed='{"@type":"messageSendingStateFailed","error":{"@type":"error","code":406,"message":"CONTROLLED_SECRET"}}';
function ingest(type,json,state=A.createInitialAppState()){
 const events=[];handlers.get(type)(events,td.TdObject.fromJSON(json));for(const e of events)state=R.messagesReducer(state,e);return{state,events};
}
const update=m=>'{"@type":"updateNewMessage","message":'+m+'}';
const tests=[],test=(name,fn)=>tests.push([name,fn]);
for(const quoted of [false,true]){
 const form=quoted?'quoted':'raw',literal=quoted?JSON.stringify(BIG):BIG,next=quoted?JSON.stringify(NEXT):NEXT;
 test(form+' large Message ID retains exact DTO decimal',()=>assert.equal(D.createMessageDtoFromTd(td.TdObject.fromJSON(message(literal))).id,BIG));
 test(form+' rounded legacy getter cache cannot poison strict Message ID',()=>{const obj=td.TdObject.fromJSON(message(literal));obj.getNumber('id');assert.equal(D.createMessageDtoFromTd(obj).id,BIG);});
 test(form+' builder cache cannot override received Message ID',()=>{const obj=td.TdObject.fromJSON(message(literal));obj.setNumber('id',100);assert.equal(D.createMessageDtoFromTd(obj).id,BIG);});
 for(const type of ['updateNewMessage','messages','updateMessageSendSucceeded','updateMessageSendFailed'])test(form+' exact large identity survives actual '+type+' handler',()=>{
  const m=message(literal,type==='updateMessageSendFailed'?failed:null);
  const json=type==='messages'?'{"@type":"messages","messages":['+m+']}':'{"@type":'+JSON.stringify(type)+',"old_message_id":100,"message":'+m+',"error":{"@type":"error","code":406,"message":"CONTROLLED_SECRET"}}';
  const f=ingest(type,json);assert.equal(f.events.length,1);assert.equal(f.state.messages.messages.get(42)?.has(BIG),true);assert.equal(f.state.messages.messages.get(42)?.has('9223372036854775000'),false);
 });
 test(form+' adjacent opaque large IDs never collapse into rounded key',()=>{let f=ingest('updateNewMessage',update(message(literal)));f=ingest('updateNewMessage',update(message(next)),f.state);assert.deepEqual([...(f.state.messages.messages.get(42)?.keys()??[])],[BIG,NEXT]);});
 test(form+' failed rekey exact old/new IDs then authoritative delete leaves no ghost',()=>{
  let f=ingest('updateNewMessage',update(message(literal,pending)));
  f=ingest('updateMessageSendFailed','{"@type":"updateMessageSendFailed","old_message_id":'+literal+',"message":'+message(next,failed,'authoritative')+',"error":{"@type":"error","code":406,"message":"CONTROLLED_SECRET"}}',f.state);
  assert.equal(f.events.length,1);assert.equal(f.events[0].oldMessageId,BIG);assert.deepEqual([...f.state.messages.messages.get(42).keys()],[NEXT]);assert.equal(f.state.messages.messages.get(42).get(NEXT).content.text,'authoritative');
  f=ingest('updateDeleteMessages','{"@type":"updateDeleteMessages","chat_id":42,"message_ids":['+next+'],"is_permanent":true,"from_cache":false}',f.state);assert.equal(f.state.messages.messages.get(42)?.size??0,0);
 });
}
for(const literal of ['9007199254740991','"9007199254740991"','-9007199254740993','"-9007199254740993"'])test('canonical signed decimal '+literal+' is preserved without Number conversion',()=>assert.equal(D.createMessageDtoFromTd(td.TdObject.fromJSON(message(literal))).id,literal.replace(/"/g,'')));
for(const literal of ['100.0','1e2','1E+2','"100.0"','"1e2"','true','false','null','{}','[100]','"0100"','"+100"','"-0"','"0"','0','-0','100xyz','100,'])test('malformed/noncanonical literal '+literal+' never becomes a Message ID',()=>{
 const m=message(literal);assert.equal(D.createMessageDtoFromTd(td.TdObject.fromJSON(m)).id,'0');const f=ingest('updateNewMessage',update(m));assert.equal(f.events.length,0);assert.equal(f.state.messages.messages.size,0);
});
for(const nested of ['"sender_id":{"@type":"messageSenderUser","user_id":7,"id":'+BIG+'}', '"reply_to":{"@type":"messageReplyToMessage","id":'+BIG+'}', '"extra":[{"id":'+BIG+'}]'])test('missing containing ID cannot borrow '+nested.split(':')[0],()=>{
 const m=message('100').replace('"id":100,','').replace('"chat_id":42','"chat_id":42,'+nested);const obj=td.TdObject.fromJSON(m);obj.getNumber('id');const f=ingest('updateNewMessage',update(m));assert.equal(f.events.length,0);assert.equal(f.state.messages.messages.size,0);
});
test('duplicate containing ID is rejected rather than selecting an ambiguous identity',()=>{const m=message('100').replace('"id":100','"id":100,"id":101');assert.equal(D.createMessageDtoFromTd(td.TdObject.fromJSON(m)).id,'0');assert.equal(ingest('updateNewMessage',update(m)).events.length,0);});
for(const prefix of ['"other":"id",','"other":{"id":101},','"other":["id",{"id":101}],'])test('containing ID remains authoritative after decoy '+prefix,()=>{const m=message('42').replace('"id":42',prefix+'"id":42');assert.equal(D.createMessageDtoFromTd(td.TdObject.fromJSON(m)).id,'42');assert.equal(ingest('updateNewMessage',update(m)).events.length,1);});
test('escaped containing property key retains exact decimal identity',()=>{const m=message(BIG).replace('"id":','"\\u0069d":');assert.equal(D.createMessageDtoFromTd(td.TdObject.fromJSON(m)).id,BIG);});
test('escaped duplicate identity key remains ambiguous and rejected',()=>{const m=message('100').replace('"id":100','"id":100,"\\u0069d":101');assert.equal(D.createMessageDtoFromTd(td.TdObject.fromJSON(m)).id,'0');assert.equal(ingest('updateNewMessage',update(m)).events.length,0);});
run('stabilization exact message IDs',tests).catch(error=>{console.error(error.stack);process.exitCode=1;});

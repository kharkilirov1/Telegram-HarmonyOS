// Review reproduction for dev@2d2f683 (2026-09-26); requires Node.js 24.
// Success confirms known defects on the reviewed baseline. These are NOT
// acceptance tests for corrected behavior; fixes may make these assertions fail.
// Loads actual ETS source with TypeScript stripping. Platform/network boundaries
// are stubbed; no HarmonyOS device, native TDLib, or Telegram account is accessed.
const fs = require('node:fs');
const nodePath = require('node:path');
const { stripTypeScriptTypes } = require('node:module');
const assert = require('node:assert/strict');
const repoRoot = nodePath.resolve(__dirname, '../../../');
const root = nodePath.join(repoRoot, 'entry/src/main/ets/');
const hilog = { info(){}, warn(){}, error(){}, debug(){} };
function load(path, names, deps={}) {
  const source = fs.readFileSync(root+path, 'utf8').replace(/^import\s[\s\S]*?;\s*/gm, '').replace(/^export\s*\{[^}]*\};?\s*/gm, '').replace(/^export\s+/gm, '');
  return new Function(...Object.keys(deps), stripTypeScriptTypes(source,{mode:'transform'})+'\nreturn {'+names.join(',')+'};')(...Object.values(deps));
}
const {TdObject} = load('models/td/common/index.ets',['TdObject']);
const accessors = load('core/utils/tdAccessors.ets',['tdGetString','tdGetNumber','tdGetBoolean','tdGetInt64','tdGetObject','tdGetArray','tdHasKeys','compareInt64'], {TdObject});
const dto = load('core/model/dto/ChatDto.ets',['ChatDto','ChatType','createChatDtoFromTd'], {...accessors,TdObject,hilog});
const errors = load('core/model/AppError.ets',['AppError','AppErrorKind']);
const commands = load('core/model/AppCommand.ets',['createGetChatHistoryCommand','createGetUserCommand','createGetChatCommand','createNewBasicGroupChatCommand','createNewSupergroupChatCommand','createToggleChatIsMarkedAsUnreadCommand']);
const basic = load('domain/usecases/createBasicGroupChat.ets',['CreateBasicGroupChatUseCase','parseCreatedBasicGroupChatResponse'],{...dto,...commands,TdObject});
const channel = load('domain/usecases/createChannelChat.ets',['CreateChannelChatUseCase','parseCreatedChannelChat'],{...dto,...commands,TdObject});
class ChatMessagesResetEvent {chatId=0;}
const history = load('domain/usecases/loadChatHistory.ets',['LoadChatHistoryUseCase','LoadChatHistoryParams'],{...commands,...errors,...accessors,TdObject,hilog,ChatMessagesResetEvent,getEventNormalizer:()=>({normalize:r=>r.getArray('messages').map(m=>({chatId:m.getNumber('chat_id'),id:m.getInt64String('id')}))})});
const toggle = load('domain/usecases/toggleChatUnread.ets',['ToggleChatUnreadUseCase'],{...commands,...errors,hilog});
const td = value => TdObject.fromJSON(JSON.stringify(value));
const result = ids => td({'@type':'messages',messages:ids.map(id=>({'@type':'message',id,chat_id:1}))});
const tick = () => new Promise(resolve=>setImmediate(resolve));
function setupHistory() {
  history.LoadChatHistoryUseCase.resetState();
  const state = { chats:{chats:new Map([[1,{lastMessage:{id:'2000'}}]])}, messages:{messages:new Map([[1,new Map()]])},users:{users:new Map()} };
  const store = {getState:()=>state,dispatch:async event=>{state.messages.messages.set(event.chatId,new Map())},dispatchBatch:async events=>{for(const event of events)state.messages.messages.get(event.chatId).set(event.id,event)}};
  const pending=[];
  const gateway={send:command=>new Promise((resolve,reject)=>pending.push({command,resolve,reject}))};
  return {state,pending,uc:new history.LoadChatHistoryUseCase(store,gateway)};
}
(async()=>{
  let groupCommands=[];
  const createdGroup=td({'@type':'createdBasicGroupChat',chat_id:-7001,failed_to_add_members:{'@type':'failedToAddMembers',failed_to_add_members:[]}});
  await assert.rejects(new basic.CreateBasicGroupChatUseCase({send:async cmd=>{groupCommands.push(cmd.type);return createdGroup}}).execute([42],'Group'),/Group creation failed/);
  assert.equal(groupCommands.length,1);
  const createdChannel=td({'@type':'chat',id:-1000000008100,title:'Channel',type:{'@type':'chatTypeSupergroup',supergroup_id:8100,is_channel:true}});
  assert.equal(dto.createChatDtoFromTd(createdChannel).id,-1000000008100);
  await assert.rejects(new channel.CreateChannelChatUseCase({send:async()=>createdChannel}).execute('Channel'),/Channel creation failed/);
  console.log('CONFIRMED: committed negative group and channel IDs both rejected as creation failure');

  let h=setupHistory();
  const initial=new history.LoadChatHistoryParams();initial.chatId=1;initial.limit=12;
  const first=h.uc.execute(initial);
  assert.equal(h.pending.length,1);
  const jumpResult=await h.uc.loadAroundMessage(1,'100',4);
  assert.equal(jumpResult,false);assert.equal(h.pending.length,1);
  h.pending[0].resolve(result(Array.from({length:12},(_,i)=>1000+i)));await first;
  assert.equal(h.state.messages.messages.get(1).has('100'),false);
  console.log('CONFIRMED: jump during initial load resets timeline but issues no target request and returns false');

  h=setupHistory();
  const old=new history.LoadChatHistoryParams();old.chatId=1;old.direction='older';old.fromMessageId='1000';
  const oldPromise=h.uc.execute(old);
  const newPromise=h.uc.loadAroundMessage(1,'100',4);await tick();
  assert.equal(h.pending.length,2);
  h.pending[1].resolve(result([90,100,110]));await newPromise;
  assert.equal(h.uc.getNewestMessageId(1),'110');
  h.pending[0].resolve(result([950,960,970]));await oldPromise;
  assert.equal(h.uc.getNewestMessageId(1),'970');
  assert.equal(h.uc.getOldestMessageId(1),'90');
  assert.equal(h.state.messages.messages.get(1).size,6);
  console.log('CONFIRMED: pre-jump older response joins disjoint range and advances newest cursor 110 -> 970, skipping gap');

  const toggleCommands=[];
  await new toggle.ToggleChatUnreadUseCase({send:async cmd=>toggleCommands.push(cmd)}).markAsRead(1);
  assert.equal(toggleCommands.length,1);assert.equal(toggleCommands[0].type,'toggleChatIsMarkedAsUnread');
  console.log('CONFIRMED: chat-list Mark Read use case sends only manual-unread toggle; no viewMessages command');
})().catch(error=>{console.error(error);process.exitCode=1});

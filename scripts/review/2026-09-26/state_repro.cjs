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
const hilog={info(){},warn(){},error(){},debug(){}};
function load(file,deps={}) {
 const original=fs.readFileSync(root+file,'utf8');
 const names=[...original.matchAll(/^export\s+(?:class|function|enum|const|let)\s+(\w+)/gm)].map(m=>m[1]);
 const source=original.replace(/^import\s[\s\S]*?;\s*/gm,'').replace(/^export\s+default\s+.*$/gm,'').replace(/^export\s+/gm,'');
 const js=stripTypeScriptTypes(source,{mode:'transform'});
 return new Function(...Object.keys(deps),js+'\nreturn {'+names.join(',')+'};')(...Object.values(deps));
}
const model=load('core/model/AppState.ets');
const commands=load('core/model/AppCommand.ets');
const tdCommon=load('models/td/common/index.ets');
const access=load('core/utils/tdAccessors.ets',tdCommon);
const stories=load('core/model/dto/StoryDto.ets');
const chatDto=load('core/model/dto/ChatDto.ets',{...access,...commands,hilog});
const msgDto=load('core/model/dto/MessageDto.ets',access);
const usersDto=load('core/model/dto/UserDto.ets',access);
const events=load('core/model/AppEvent.ets',{...chatDto,...msgDto,...usersDto,...stories});
const clones=load('core/utils/stateClone.ets',{...model,...commands});
const reply=load('core/utils/replyMessageKey.ets');
const deps={...model,...clones,...events,...access,...reply,hilog,DtoChatType:chatDto.ChatType};
const reducers={};
for(const name of ['auth','chats','messages','users','files','accentColors']) Object.assign(reducers,load(`core/reducers/${name}Reducer.ets`,deps));
const {appReducer}=load('core/reducers/index.ets',reducers);
const invariant=load('core/invariants/assertInvariants.ets',{...model,...access,hilog});
const {AppStore}=load('core/store/AppStore.ets',{...model,...invariant,hilog});
const selectors=load('domain/selectors/chatSelectors.ets',model);
const {registerChatHandlers}=load('core/events/normalizers/ChatNormalizer.ets',{...events,...chatDto,...access,hilog});
async function runReproductions(){
 let state=new model.AppState(); const chat=new model.Chat(); chat.id=7; chat.order='100'; chat.unreadCount=2;
 state.chats.chats.set(7,chat); state.chats.orderedChatIds=[7];
 const message=new model.Message(); message.id='10';message.chatId=7;state.messages.messages.set(7,new Map([['10',message]]));
 const store=new AppStore(appReducer,state,false);
 const handlers=new Map(); registerChatHandlers(handlers);
 const normalized=[]; handlers.get('updateUnreadMessageCount')(normalized,tdCommon.TdObject.fromJSON(JSON.stringify({'@type':'updateUnreadMessageCount',chat_list:{'@type':'chatListMain'},unread_count:150,unread_unmuted_count:99})));
 assert.equal(normalized[0].type,'chatListUnreadMessageCountChanged');
 await store.dispatchBatch(normalized);
 assert.equal(store.getState().chats.mainUnreadMessageCount,-1);
 assert.equal(selectors.selectTotalUnreadCount(store.getState()),2);
 assert.equal(reducers.chatsReducer(state,normalized[0]).chats.mainUnreadMessageCount,150);
 const reset=new events.ChatMessagesResetEvent();reset.chatId=7;await store.dispatch(reset);
 assert.equal(store.getState().messages.messages.get(7).size,1);
 assert.equal(reducers.messagesReducer(state,reset).messages.messages.has(7),false);
 console.log('CONFIRMED router: normalized aggregate 150 produces badge 2; reset retains old message 10 (leaf reducers correct)');
 const update=new events.ChatUpdatedEvent();update.chatId=7;update.updates.order='0';await store.dispatch(update);
 assert.deepEqual(store.getState().chats.orderedChatIds,[7]);
 console.log('CONFIRMED chat position order=0 archiveOrder=0 retains chat 7 in main list');
 const withReply=new model.Message();withReply.id='11';withReply.chatId=7;withReply.replyToChatId=-10055;withReply.replyToMessageId='22';withReply.content.type='photo';withReply.content.photoFileId=33;
 const replyState=new model.AppState();replyState.chats.chats.set(7,chat);replyState.messages.messages.set(7,new Map([['11',withReply]]));
 const fileEvent=new events.FileDownloadedEvent();fileEvent.fileId=33;fileEvent.localPath='/tmp/photo.jpg';fileEvent.isComplete=true;
 const next=appReducer(replyState,fileEvent);assert.equal(next.messages.messages.get(7).get('11').replyToChatId,0);
 console.log('CONFIRMED fileDownloaded: media reply target changes from -10055 to 0 although reply message id stays 22');
}
if (require.main === module) {
 runReproductions().catch(error=>{console.error(error);process.exitCode=1;});
}
module.exports={load,model,events,reducers,appReducer,AppStore,access,tdCommon,msgDto,clones};

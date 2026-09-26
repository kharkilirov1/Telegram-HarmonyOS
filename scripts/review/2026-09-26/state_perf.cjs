// Review reproduction for dev@2d2f683 (2026-09-26); requires Node.js 24.
// Success confirms known defects on the reviewed baseline. These are NOT
// acceptance tests for corrected behavior; fixes may make these assertions fail.
// Loads actual ETS source with TypeScript stripping. Platform/network boundaries
// are stubbed; no HarmonyOS device, native TDLib, or Telegram account is accessed.
const {performance}=require('node:perf_hooks');
const {model,events,AppStore,appReducer}=require('./state_repro.cjs');
(async()=>{
 const state=new model.AppState(); const n=30000; const perChat=300;
 for(let c=1;c<=n/perChat;c++) { const chat=new model.Chat();chat.id=c;chat.order=String(c);state.chats.chats.set(c,chat);state.chats.orderedChatIds.push(c);const map=new Map();for(let i=1;i<=perChat;i++){const message=new model.Message();message.id=String(i);message.chatId=c;message.timestamp=i;map.set(message.id,message)}state.messages.messages.set(c,map); }
 let visits=0; for(const map of state.messages.messages.values()) { const original=map.forEach; map.forEach=function(cb){return original.call(this,(...args)=>{visits++;return cb(...args)})} }
 const store=new AppStore(appReducer,state);visits=0;const start=performance.now();
 for(let i=1;i<=100;i++){const event=new events.FileTransferUpdatedEvent();event.fileId=1;event.downloadedSize=i;await store.dispatch(event)}
 console.log(JSON.stringify({storedMessages:n,events:100,messageVisits:visits,elapsedMs:Math.round(performance.now()-start),devDefault:store.devMode}));
})().catch(error=>{console.error(error);process.exitCode=1;});

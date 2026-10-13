// Execute the actual UI helper against a viewport boundary: a found button does
// not imply that the confirmation labels below it are visible.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {stripTypeScriptTypes} = require('node:module');
const arg = process.argv.find(x=>x.startsWith('--source='));
const file = arg ? path.resolve(arg.slice(9)) : path.resolve(__dirname,'../entry/src/ohosTest/ets/test/WriteResendDialog.test.ets');
const source = fs.readFileSync(file,'utf8');
function portion(start,end) {const a=source.indexOf(start),b=source.indexOf(end,a);assert(a>=0&&b>a);return source.slice(a,b);}
const body=portion('async function requireResendText(', 'async function clickResendText(')+portion('async function clickTextFixture(', 'async function absentResendText(');
function harness({missingTail=false,missingButton=false}={}) {
 let bottom=900,clicks=0;const state={mutations:0,busy:false};
 const ids={'write-resend-fixture-send':[1000,1040],'write-resend-fixture-mutations':[1045,1065],'write-resend-fixture-busy':[1070,1090],'write-resend-fixture-entities':[1120,1140]};
 const visible=id=>ids[id]&&ids[id][0]>=bottom-400&&ids[id][1]<=bottom;
 const button={click:async()=>{assert(visible('write-resend-fixture-send'),'click stays in the viewport');clicks++;state.mutations++;}};
 const component=id=>id==='write-resend-fixture-send'?(missingButton?undefined:button):id==='write-resend-fixture-entities'&&missingTail?undefined:{};
 const scroll={scrollSearch:async selector=>{assert.equal(selector.kind,'id');const node=component(selector.value);if(!node)return undefined;assert(ids[selector.value]);bottom=ids[selector.value][1];return node;}};
 const find=selector=>{
  if(selector.kind==='id')return selector.value==='chat-test-fixture-scroll'?scroll:visible(selector.value)?component(selector.value):undefined;
  const id=selector.value==='text busy:false'?'write-resend-fixture-busy':selector.value==='text mutations:1'?'write-resend-fixture-mutations':undefined;
  return id&&visible(id)?{}:undefined;
 };
 const driver={waitForComponent:async selector=>find(selector),assertComponentExist:async selector=>assert(find(selector),'native confirmation must actually be visible')};
 const expect=value=>({assertFalse:()=>assert.equal(value,false)});
 const api=new Function('ON','expect','WriteResendFixture','console',stripTypeScriptTypes(body,{mode:'transform'})+';return {clickTextFixture,requireResendText};')({id:value=>({kind:'id',value}),text:value=>({kind:'text',value})},expect,{state},{info:()=>{}});
 return {driver,api,clicks:()=>clicks};
}
async function main(){
 const ready=harness();await ready.api.clickTextFixture(ready.driver);
 await ready.api.requireResendText(ready.driver,'text busy:false');
 await ready.api.requireResendText(ready.driver,'text mutations:1');
 assert.equal(ready.clicks(),1,'visibility preparation must never replay a send');
 for(const options of [{missingTail:true},{missingButton:true}]){
  const blocked=harness(options);await assert.rejects(blocked.api.clickTextFixture(blocked.driver));assert.equal(blocked.clicks(),0);
 }
 console.log('PASS native fixture labels visible before one send; missing tail/button blocks with zero clicks');
}
let timer;
Promise.race([main(),new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error('fixture visibility regression unfinished')),3000);})])
 .catch(error=>{console.error(error);process.exitCode=1;}).finally(()=>clearTimeout(timer));

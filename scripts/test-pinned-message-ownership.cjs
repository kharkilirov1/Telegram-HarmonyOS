#!/usr/bin/env node
// Actual ETS callbacks and production owners. Transport/runtime registry/Hypium
// are explicit fixtures; no SDK, native TDLib, app bootstrap or account action.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { createHash } = require('node:crypto');
const { stripTypeScriptTypes } = require('node:module');
const root = path.resolve(__dirname, '..');
function option(name) { const i=process.argv.indexOf(name); return i<0?undefined:process.argv[i+1]; }
const preimages = option('--preimage-dir');
const mutation = option('--mutation');
const expectRed = process.argv.includes('--expect-red');
assert.ok(!preimages || !mutation, 'Preimage and mutation witnesses are separate');
assert.ok(!expectRed || preimages || mutation, 'RED mode must name actual preimages or one mutation');
const pinFile = 'entry/src/main/ets/ui/pages/chat/ChatPinnedMessagesCoordinator.ets';
const usecaseFile = 'entry/src/main/ets/domain/usecases/loadPinnedMessage.ets';
const sessionFile = 'entry/src/main/ets/ui/pages/chat/ChatScreenSession.ets';
const mutations = {
  'account-unfenced': [[pinFile, 'host.isRouteContextCurrent(route);', 'true;']],
  'fallback-unfenced': [[pinFile,
    'if (!isPinnedOwnerCurrent(host, route, chatId, lifecycleToken) ||\n          requestId !== host.pinnedMessageRequestId)',
    'if (lifecycleToken !== host.pageLifecycleToken || chatId !== host.activeChatId ||\n          requestId !== host.pinnedMessageRequestId)'], [pinFile,
    'if (isPinnedOwnerCurrent(host, route, chatId, lifecycleToken) &&\n          requestId === host.pinnedMessageRequestId)',
    'if (lifecycleToken === host.pageLifecycleToken && chatId === host.activeChatId &&\n          requestId === host.pinnedMessageRequestId)']],
  'refresh-unfenced': [[pinFile,
    "host.pinnedMessagesListRequestId++;\n    host.pinnedMessagesListLoading = false;\n    host.pinnedMessagesNextFromMessageId = '0';",
    '/* mutation: refreshed base retains old page generation and cursor */'], [pinFile,
    'baseRequestId !== host.pinnedMessageRequestId || requestId !== host.pinnedMessagesListRequestId',
    'requestId !== host.pinnedMessagesListRequestId'], [pinFile,
    'baseRequestId === host.pinnedMessageRequestId && requestId === host.pinnedMessagesListRequestId',
    'requestId === host.pinnedMessagesListRequestId']],
  'gateway-rebound': [[pinFile, 'createLoadPinnedMessagesUseCase(route.gateway)', 'createLoadPinnedMessagesUseCase(getTdGatewayAdapter())']],
  'session-fallback-disconnected': [[sessionFile,
    'loadSinglePinnedMessageFallback(chatId: number, lifecycleToken: number, requestId: number): void { delegateLoadSinglePinnedMessageFallback(this, chatId, lifecycleToken, requestId); }',
    'loadSinglePinnedMessageFallback(chatId: number, lifecycleToken: number, requestId: number): void { delegateResetPinnedMessageState(this); }']]
};
if (mutation) assert.ok(mutations[mutation], 'Explicit known mutation required');
const sources = new Map();
sources.set(__filename,fs.readFileSync(__filename,'utf8'));
function read(relative) {
  const file = preimages && [pinFile,usecaseFile].includes(relative)
    ? path.resolve(preimages, path.basename(relative)) : path.join(root,relative);
  const raw=fs.readFileSync(file,'utf8'); sources.set(file,raw);
  let text=raw.replaceAll('\r\n','\n');
  if(mutation) for(const [target,before,after] of mutations[mutation]) {
    if(target!==relative) continue;
    assert.ok(text.includes(before),'Mutation anchor must be present in actual source: '+target);
    text = mutation==='gateway-rebound' ? text.replaceAll(before,after) : text.replace(before,after);
  }
  return text;
}
function load(relative, deps={}, extraNames=[]) {
  const text=read(relative);
  const names=[...text.matchAll(/^export\s+(?:default\s+)?(?:async\s+)?(?:class|function|enum|const)\s+(\w+)/gm)].map(m=>m[1]);
  const code=text.replace(/^import[\s\S]*?;\s*/gm,'').replace(/^export\s+\{[^}]*\};?\s*/gm,'')
    .replace(/^export\s+(?:default\s+)?/gm,'').replace(/^@ObservedV2\s*\n/gm,'').replace(/^(\s*)@Trace\s+/gm,'$1');
  const js=stripTypeScriptTypes(code,{mode:'transform',sourceUrl:relative});
  return new Function(...Object.keys(deps),js+'\nreturn {'+[...names,...extraNames].join(',')+'};')(...Object.values(deps));
}
const hilog={info(){},warn(){},debug(){},error(){}};
const platform={hilog,localized:(_id,fallback)=>fallback,$r:id=>({id}),curves:{},TgUiTokens:{}};
const main='entry/src/main/ets/';
const td=load(main+'models/td/common/index.ets');
const access=load(main+'core/utils/tdAccessors.ets',td);
const commands=load(main+'core/model/AppCommand.ets');
const state=load(main+'core/model/AppState.ets');
const invariants=load(main+'core/invariants/assertInvariants.ets',{...state,...access,hilog});
const store=load(main+'core/store/AppStore.ets',{...state,...invariants,hilog});
const dto=load(main+'core/model/dto/MessageDto.ets',{...access,...td});
const lease=load(main+'domain/usecases/ChatOpenLease.ets',{...commands,...td});
const route=load(main+'ui/pages/chat/ChatScreenRouteParams.ets',{...store,...lease});
let sdk, registryGatewayOverride;
function currentFixture(){assert.ok(sdk.PinnedFixture.latest,'Real test fixture registration required');return sdk.PinnedFixture.latest;}
function getTdGatewayAdapter(){const f=currentFixture();return registryGatewayOverride || (f.currentStore===f.storeA?f.gatewayA:f.gatewayB);}
const pinned=load(usecaseFile,{...commands,...td,...access,...dto,getTdGatewayAdapter});
const coordinator=load(pinFile,{...pinned,...route,...platform,getTdGatewayAdapter});
const tests=[];
const expect=value=>({assertEqual(expected){assert.equal(value,expected);},assertTrue(){assert.equal(value,true);},assertFalse(){assert.equal(value,false);}});
sdk=load('entry/src/ohosTest/ets/test/PinnedMessageOwnership.test.ets',{
  ...td,...state,...store,...route,...pinned,...coordinator,expect,
  describe:(_name,run)=>run(),it:(name,_flag,run)=>tests.push({name,run,scope:'actual SDK callback'})
},['PinnedFixture','pageResponse','messageResponse','settlePinned']);
sdk.pinnedMessageOwnershipTest();
assert.ok(tests.length>0,'Must execute actual registered ETS callbacks');
const sdkCaseCount=tests.length;
const registry=read('entry/src/ohosTest/ets/test/List.test.ets');
assert.equal((registry.match(/^import pinnedMessageOwnershipTest from '\.\/PinnedMessageOwnership\.test';$/gm)||[]).length,1);
assert.equal((registry.match(/^  pinnedMessageOwnershipTest\(\);$/gm)||[]).length,1,'Native registry must call the actual suite');

// Exercise the real production predicate and Session forwarding without app
// bootstrap. Constructor/resource initialization is outside this host witness;
// the real Context accessors write to the real pinned @Trace model instance.
const ownership=load(main+'ui/pages/chat/ChatRouteOwnershipCoordinator.ets',{
  ...route,...platform,getAppCoreRuntime:()=>({getStore:()=>currentFixture().currentStore})
});
const context=load(main+'ui/pages/chat/ChatScreenContext.ets');
const model=load(main+'ui/pages/chat/ChatPinnedSearchState.ets',pinned);
const sessionDeps={...context};
const sessionText=read(sessionFile);
for(const [moduleName,exports] of [['ChatPinnedMessagesCoordinator',coordinator],['ChatRouteOwnershipCoordinator',ownership]]) {
  const block=[...sessionText.matchAll(/import\s*\{([\s\S]*?)\}\s*from\s*'\.\/([^']+)';/g)].find(m=>m[2]===moduleName);
  assert.ok(block,'Actual Session import required: '+moduleName);
  for(const entry of block[1].split(',')) {
    const m=entry.trim().match(/^(\w+)\s+as\s+(\w+)$/);
    if(!m) continue;
    assert.equal(typeof exports[m[1]],'function','Actual exported delegate must exist: '+m[1]);
    sessionDeps[m[2]]=exports[m[1]];
  }
}
const {ChatScreenSession}=load(sessionFile,sessionDeps);
function realSession(fixture) {
  const session=Object.create(ChatScreenSession.prototype);
  Object.assign(session,{view:{pinnedSearch:new model.ChatPinnedSearchState(),chrome:{activeChatId:42}},
    routeContext:fixture.routeContext,routeActivated:true,pageLifecycleToken:1,pinnedMessageRequestId:0,
    pinnedMessagesListRequestId:0,pinnedMessageDismissedId:'0'});
  return session;
}
function hostTest(name,run){tests.push({name,run,scope:'actual Session/Context/route predicate integration'});}
hostTest('actual Session delegates empty search fallback through captured route gateway despite a different global adapter',async()=>{
  const f=new sdk.PinnedFixture(),session=realSession(f);
  registryGatewayOverride=f.gatewayB;
  try {
    assert.equal(session.isRouteContextCurrent(f.routeContext),true);
    session.loadPinnedMessage();assert.equal(f.gatewayA.requests.length,1);assert.equal(f.gatewayB.requests.length,0);
    f.gatewayA.requests[0].succeed(sdk.pageResponse([]));await sdk.settlePinned();
    assert.equal(f.gatewayA.requests.length,2);assert.equal(f.gatewayB.requests.length,0);
    f.gatewayA.requests[1].succeed(sdk.messageResponse('112'));await sdk.settlePinned();
    assert.equal(session.pinnedMessageId,'112');assert.equal(session.view.pinnedSearch.pinnedMessages[0].messageId,'112');
  }finally{registryGatewayOverride=undefined;}
});
hostTest('actual Session route predicate revokes only the real AppStore scope with lifecycle and chat unchanged',async()=>{
  const f=new sdk.PinnedFixture(),session=realSession(f),captured=f.routeContext;
  session.loadPinnedMessage();assert.equal(f.gatewayA.requests.length,1);
  f.storeA.invalidateScopes();assert.equal(captured.isCurrentAccount(f.storeA),false);
  assert.equal(session.isRouteContextCurrent(captured),false);assert.equal(session.activeChatId,42);assert.equal(session.pageLifecycleToken,1);
  const replacement=new pinned.PinnedMessageInfo();replacement.isAvailable=true;replacement.messageId='900';replacement.preview='new owner';
  session.pinnedMessages=[replacement];
  session.pinnedMessageId='900';session.pinnedMessagePreview='new owner';session.pinnedMessagesListLoading=true;
  f.gatewayA.requests[0].fail();await sdk.settlePinned();
  assert.equal(f.gatewayA.requests.length,1);assert.equal(f.gatewayB.requests.length,0);
  assert.equal(session.pinnedMessageId,'900');assert.equal(session.pinnedMessagePreview,'new owner');assert.equal(session.pinnedMessagesListLoading,true);
});
hostTest('actual Session same-chat route replacement and store ABA keep obsolete completion inert',async()=>{
  const f=new sdk.PinnedFixture(),session=realSession(f),old=f.routeContext;
  session.loadPinnedMessage();
  session.routeContext=new route.ChatScreenRouteParams(42,'Replacement',f.storeA,f.gatewayA);
  assert.equal(session.isRouteContextCurrent(old),false);f.storeA.invalidateScopes();f.currentStore=f.storeB;f.currentStore=f.storeA;
  session.pinnedMessageId='900';session.pinnedMessagePreview='replacement';
  f.gatewayA.requests[0].succeed(sdk.pageResponse(['111'],'100'));await sdk.settlePinned();
  assert.equal(session.pinnedMessageId,'900');assert.equal(session.pinnedMessagePreview,'replacement');
  assert.equal(f.gatewayA.requests.length,1);assert.equal(f.gatewayB.requests.length,0);
});

let completed=false;
process.once('beforeExit',()=>{if(!completed){console.error('HARNESS_ERROR: unfinished pinned test run');process.exitCode=2;}});
(async()=>{
  const results=[];
  for(const {name,run,scope} of tests){
    let error;try{await run();}catch(e){error=e;}
    results.push({name,scope,passed:error===undefined,error:error?{type:error.name,message:error.message}:undefined});
    console.log((error?'FAIL ':'PASS ')+name+(error?' '+error.message:''));
  }
  const failures=results.filter(r=>!r.passed);
  if(expectRed){
    assert.ok(failures.length>0,'RED witness must fail actual behavior assertions');
    assert.ok(failures.every(r=>r.error.type==='AssertionError'),'No loader/TypeError/SyntaxError failure may count as RED');
  }
  for(const [file,text] of sources)assert.equal(fs.readFileSync(file,'utf8'),text,'Source drift: '+file);
  completed=true;
  console.log(JSON.stringify({suite:'pinned-message-ownership',checks:results.length,sdkCaseCount,
    passed:results.length-failures.length,failed:failures.length,expectedRed:expectRed,mutation,preimages,
    sourceHashes:Object.fromEntries([...sources].map(([file,text])=>[path.relative(root,file),createHash('sha256').update(text).digest('hex')])),
    results,scope:{actualSDKCallbacks:true,realAppStoreScopes:true,realRouteLease:true,actualSessionDelegates:true,
      actualSessionConstructor:false,actualRoutePredicateIntegration:true,gatewayFixture:true,nativeSends:false,
      appBootstrap:false,authenticatedAccountOrdering:false,nativeSDKRuntime:false}}));
  process.exitCode=failures.length&&!expectRed?1:0;
})().catch(error=>{completed=true;console.error(error.stack||String(error));process.exitCode=2;});

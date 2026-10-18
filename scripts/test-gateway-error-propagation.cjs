#!/usr/bin/env node
// Executes the unchanged registered Hypium callbacks and actual ETS owners.
// Host-only integration also executes the real gateway JSON response/timeout
// pipeline, serializer and adapter. Native TDLib, dispatcher/bootstrap, timers
// for that pipeline and Hypium are explicit fixtures. No network/account/SDK.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '..');
const option = name => { const i=process.argv.indexOf(name); return i<0?undefined:process.argv[i+1]; };
const preimages = option('--preimage-dir'), mutation = option('--mutation'), output = option('--json');
const expectRed = process.argv.includes('--expect-red');
assert.ok(!(preimages && mutation) || mutation==='v1-minimal-retirement');
assert.ok(!expectRed || preimages || mutation);
const main = 'entry/src/main/ets/';
const portFile=main+'domain/ports/TdGatewayPort.ets', adapterFile=main+'infra/td/adapter/TdGatewayAdapter.ets';
const chatsFile=main+'domain/usecases/loadChats.ets', historyFile=main+'domain/usecases/loadChatHistory.ets';
const retryFile=main+'ui/pages/chat/ChatInitialHistoryCoordinator.ets';
const changes = [portFile,adapterFile,chatsFile,historyFile,retryFile];
const hash = value => createHash('sha256').update(value).digest('hex');
const mutations = {
  'adapter-loses-type': [[adapterFile,'if (error instanceof AppError) {\n        throw error;\n      }','']],
  'chats-loses-detail': [[chatsFile,'err.technicalMessage || err.message,','err.message,']],
  'history-loses-type': [[historyFile,'if (error instanceof AppError) {\n        throw error;\n      }','']],
  'retry-gate-removed': [[retryFile,'if (error instanceof AppError && (!error.retryable || error.kind === AppErrorKind.AUTH ||\n          error.kind === AppErrorKind.RATE_LIMIT)) {','if (false) {']],
  'auth-kind-ignored': [[retryFile,'!error.retryable || error.kind === AppErrorKind.AUTH ||','!error.retryable ||']],
  'rate-kind-ignored': [[retryFile,' ||\n          error.kind === AppErrorKind.RATE_LIMIT','']],
  'invalid-retryable': [[portFile,'0, code !== GatewayErrorCode.INVALID_COMMAND);','0, true);']],
  'adapter-stale-error-unfenced': [[adapterFile,'} catch (error) {\n      if (!this.isCurrentClient()) {\n        throw this.expiredClientError();\n      }','} catch (error) {']],
  'history-stale-error-unfenced': [[historyFile,'} catch (error) {\n      if (!this.isCurrentRequest(chatId, bucketReservation, generation)) {\n        return false;\n      }','} catch (error) {']],
  'v1-minimal-retirement': [[retryFile,
    'error.kind === AppErrorKind.RATE_LIMIT)) {\n          return;',
    'error.kind === AppErrorKind.RATE_LIMIT)) {\n          host.initialHistoryFallbackRequested = false;\n' +
    '          if (host.historyFallbackTimerId >= 0) {\n            clearTimeout(host.historyFallbackTimerId);\n' +
    '            host.historyFallbackTimerId = -1;\n          }\n          return;']],
  'correction-intent-unconsumed': [[retryFile,'          host.initialHistoryFallbackRequested = false;\n','']],
  'terminal-timer-uncancelled': [[retryFile,
    '          if (host.historyFallbackTimerId >= 0) {\n            clearTimeout(host.historyFallbackTimerId);\n            host.historyFallbackTimerId = -1;\n          }\n','']],
  'terminal-before-owner': [[retryFile,'      .catch((error: Object) => {',
    '      .catch((error: Object) => {\n' +
    '        if (error instanceof AppError && (!error.retryable || error.kind === AppErrorKind.AUTH || error.kind === AppErrorKind.RATE_LIMIT)) {\n' +
    '          host.initialHistoryFallbackRequested = false;\n' +
    '          if (host.historyFallbackTimerId >= 0) { clearTimeout(host.historyFallbackTimerId); host.historyFallbackTimerId = -1; }\n        }']],
  'operation-success-unfenced': [[retryFile,
    "        if (requestIdentity === '' || requestIdentity === previousRequestIdentity ||\n          !historyUseCase.isRequestIdentityCurrent(chatId, 'initial', requestIdentity)) {\n          return;\n        }\n",'']],
  'operation-error-unfenced': [[retryFile,
    "        if (requestIdentity === '' || requestIdentity === previousRequestIdentity ||\n          !historyUseCase.isRequestIdentityCurrent(chatId, 'initial', requestIdentity)) {\n          return;\n        }\n        hilog.warn",
    '        hilog.warn']]
};
assert.ok(!mutation || mutations[mutation], 'Named mutation required');
const sources = new Map();
function read(relative) {
  const file = preimages && changes.includes(relative) ? path.resolve(preimages,path.basename(relative)) : path.join(root,relative);
  const raw = fs.readFileSync(file,'utf8'); sources.set(file,raw);
  let source = raw.replaceAll('\r\n','\n');
  if (mutation) for(const [target,before,after] of mutations[mutation]) {
    if(target!==relative) continue;
    assert.ok(source.includes(before),'Exact mutation anchor in actual owner: '+target);
    source=source.replace(before,after);
  }
  return source;
}
function compiled(source,relative) {
  return stripTypeScriptTypes(source.replace(/^import[\s\S]*?;\s*/gm,'')
    .replace(/^export\s+\{[\s\S]*?\}\s*(?:from\s*'[^']*')?;\s*/gm,'')
    .replace(/^export\s+default\s+\w+\s*;\s*/gm,'').replace(/^export\s+(?:default\s+)?/gm,''),
  {mode:'transform',sourceUrl:relative});
}
function execute(source,relative,deps) {
  const names=[...source.matchAll(/^(?:export\s+(?:default\s+)?)?(?:async\s+)?(?:class|function|enum|const)\s+(\w+)/gm)].map(m=>m[1]);
  const imports=Object.fromEntries(Object.entries(deps).filter(([name])=>!names.includes(name)));
  return new Function(...Object.keys(imports),compiled(source,relative)+'\nreturn {'+names.join(',')+'};')(...Object.values(imports));
}
const tests=[];
const hypium={describe:(_name,body)=>body(),it:(name,_flags,run)=>tests.push({name,run,scope:'unchanged native Hypium callback'}),
  expect:value=>({assertEqual:other=>assert.strictEqual(value,other),assertTrue:()=>assert.strictEqual(value,true),
    assertFalse:()=>assert.strictEqual(value,false)})};
const hilog={info(){},warn(){},debug(){},error(){}};
const cache=new Map();
function resolveImport(from,target) {
  const base=path.posix.normalize(path.posix.join(path.posix.dirname(from),target));
  for(const candidate of [base+'.ets',base+'/index.ets']) if(fs.existsSync(path.join(root,candidate))) return candidate;
  throw new Error('Missing actual local module: '+from+' -> '+target);
}
function load(relative) {
  if(cache.has(relative)) return cache.get(relative);
  const source=read(relative);
  if(relative===main+'models/TdTypes.ets') {
    // TdObject and common exports are the actual re-exported parser owner.
    const result=load(main+'models/td/common/index.ets'); cache.set(relative,result); return result;
  }
  const js=compiled(source,relative), deps={};
  for(const match of source.matchAll(/^import\s+([\s\S]*?)\s+from\s*'([^']+)';/gm)) {
    const spec=match[1], target=match[2];
    const entries=spec.trim().startsWith('{') ? spec.replace(/[{}]/g,'').split(',').map(s=>s.trim()).filter(Boolean) : [spec.trim()];
    for(const entry of entries) {
      const [original,alias] = entry.split(/\s+as\s+/), name=alias||original;
      if(!new RegExp('\\b'+name+'\\b').test(js)) continue; // erased types do not bootstrap modules
      let exports;
      if(target==='@ohos/hypium') exports=hypium;
      else if(target==='@kit.PerformanceAnalysisKit') exports={hilog};
      else if(target==='@kit.BasicServicesKit') exports={systemDateTime:{TimeType:{STARTUP:0},getUptime:()=>0}};
      else if(target==='@kit.CoreFileKit') exports={fileUri:{getUriFromPath:p=>'file://'+p}};
      else if(target.startsWith('.')) exports=load(resolveImport(relative,target));
      else throw new Error('Unapproved external runtime import '+relative+' -> '+target+':'+name);
      assert.ok(original in exports,'Actual runtime export '+target+':'+original);
      deps[name]=exports[original];
    }
  }
  const result=execute(source,relative,deps); cache.set(relative,result); return result;
}
const sdkFile='entry/src/ohosTest/ets/test/GatewayErrorPropagation.test.ets';
const sdk=load(sdkFile); sdk.gatewayErrorPropagationTest();
assert.equal(tests.length,60,'Native registry callback count');
const app=load(main+'core/model/AppError.ets'), port=load(portFile);
const td=load(main+'models/td/common/index.ets'), commands=load(main+'core/model/AppCommand.ets');
const serializer=load(main+'infra/td/serialization/CommandSerializer.ets');
const history=load(historyFile), chats=load(chatsFile);
function pipeline(options={}) {
  const timers=new Map(), requests=[]; let sequence=0,gateway,origin;
  const raw=execute(read(main+'infra/td/gateway/TdGateway.ets'),main+'infra/td/gateway/TdGateway.ets',{
    ...app,...td,hilog,
    systemDateTime: { TimeType: { STARTUP: 0 }, getUptime: () => performance.now() },
    classifyTdlibError:(code,detail)=>{origin=app.classifyTdlibError(code,detail);return origin;},
    getMainThreadDispatcher:()=>{throw new Error('Native dispatcher/bootstrap forbidden');},
    setTimeout:(callback,delay)=>{timers.set(++sequence,{callback,delay});return sequence;},clearTimeout:id=>timers.delete(id),
    tdlib:{send:(client,json)=>{requests.push({client,json:JSON.parse(json)});if(options.nativeThrow)throw new Error('Synthetic native error');}}
  });
  gateway=raw.TdGatewayImpl.getInstance(); gateway.state='ready'; gateway.clientId=7;gateway.clientGeneration=1;
  const adapters=execute(read(adapterFile),adapterFile,{...app,...port,...td,...serializer,hilog,getTdGateway:()=>gateway});
  const adapter=adapters.getTdGatewayAdapter();
  return {gateway,adapter,requests,timers,origin:()=>origin,
    retire:()=>gateway.clientGeneration++,
    reply:(code,detail,success=false)=>{const request=requests.at(-1);assert.ok(request);gateway.handleResponseOnMainThread(JSON.stringify({
      '@type':success?'ok':'error','@client_id':request.client,'@extra':request.json['@extra'],code,message:detail}));},
    timeout:()=>{const timer=[...timers.values()][0];assert.ok(timer);timer.callback();}};
}
const add=(name,run)=>tests.push({name,run,scope:'host actual native-boundary/gateway/serializer/adapter integration'});
async function failure(promise) { try{await promise;}catch(error){assert.ok(error instanceof app.AppError);return error;}assert.fail('Expected rejection'); }
for(const [code,detail] of [[401,'SESSION_EXPIRED'],[403,'CHAT_ACCESS_DENIED'],[400,'CHAT_NOT_FOUND'],[429,'FLOOD_WAIT_37'],[503,'Synthetic service unavailable']]) {
  add('actual JSON response -> adapter retains same typed error: '+code,async()=>{
    const f=pipeline();const p=f.adapter.send(commands.createGetChatHistoryCommand(42,'0',0,50,false));
    assert.equal(f.requests.length,1);assert.equal(f.requests[0].json['@type'],'getChatHistory');
    f.reply(code,detail);const error=await failure(p);assert.equal(error,f.origin());assert.equal(error.technicalMessage,detail);
    assert.equal(error.tdlibCode,code);assert.equal(f.timers.size,0);
  });
}
add('actual gateway timeout -> adapter preserves original retryable timeout',async()=>{
  const f=pipeline();const p=f.adapter.send(commands.createLoadChatsCommand(20));f.timeout();const error=await failure(p);
  assert.equal(error.kind,app.AppErrorKind.NETWORK);assert.equal(error.retryable,true);assert.equal(error.tdlibCode,0);
  assert.match(error.userMessage,/Request loadChats timed out after 15000ms/);assert.equal(error.technicalMessage,'');
});
add('actual gateway typed UNKNOWN native-send error is preserved by adapter',async()=>{
  const f=pipeline({nativeThrow:true});const p=f.adapter.send(commands.createLoadChatsCommand(20));const error=await failure(p);
  assert.equal(error.kind,app.AppErrorKind.UNKNOWN);assert.equal(error.retryable,true);
  assert.equal(error.technicalMessage,'Error: Synthetic native error');assert.equal(f.requests.length,1);
});
add('adapter preserves legacy wrapping for an untyped transport error',async()=>{
  const f=pipeline();f.gateway.send=async()=>{throw new Error('Synthetic legacy transport error');};
  const error=await failure(f.adapter.send(commands.createLoadChatsCommand(20)));
  assert.ok(error instanceof port.GatewayError);assert.equal(error.code,port.GatewayErrorCode.CONNECTION_FAILED);
  assert.equal(error.kind,app.AppErrorKind.NETWORK);assert.equal(error.retryable,true);
  assert.equal(error.technicalMessage,'loadChats');assert.equal(error.userMessage,'Synthetic legacy transport error');
  assert.equal(f.requests.length,0);
});
for(const outcome of ['success','typed-error']) add('adapter stale generation overrides late '+outcome,async()=>{
  const f=pipeline();const p=f.adapter.send(commands.createLoadChatsCommand(20));
  // Native response is correlated in the original generation; retire before the
  // adapter await continuation. The actual stale-client catch must win.
  f.reply(429,'FLOOD_WAIT_37',outcome==='success');f.retire();const error=await failure(p);
  assert.ok(error instanceof port.GatewayError);assert.equal(error.code,port.GatewayErrorCode.NOT_INITIALIZED);
  assert.equal(error.retryable,false);assert.notEqual(error,f.origin());assert.equal(f.requests.length,1);
});
add('actual adapter warming and invalid-command preflight keep distinct retry semantics',async()=>{
  const f=pipeline();f.gateway.state='idle';const warming=await failure(f.adapter.send(commands.createLoadChatsCommand(20)));
  assert.equal(warming.kind,app.AppErrorKind.NETWORK);assert.equal(warming.retryable,true);assert.equal(f.requests.length,0);
  f.gateway.state='ready';const adapters=execute(read(adapterFile),adapterFile,{...app,...port,...td,hilog,
    getTdGateway:()=>f.gateway,serializeCommand:()=>({method:'',params:new td.TdObject()})});
  const invalid=await failure(adapters.getTdGatewayAdapter().send(commands.createLoadChatsCommand(20)));
  assert.equal(invalid.kind,app.AppErrorKind.UNKNOWN);assert.equal(invalid.retryable,false);assert.equal(f.requests.length,0);
});
add('actual gateway+adapter+loadChats 404 releases loading and exhausts without retry',async()=>{
  const f=pipeline(),state=new sdk.ReadFixture();const uc=new chats.LoadChatsUseCase(state.store.createScope(),f.adapter);
  const p=uc.execute();await sdk.settleReads();assert.equal(f.requests.length,1);f.reply(404,'No more chats');
  let error;try{await p;}catch(e){error=e;}assert.equal(error,undefined,'404 must exhaust, without throwing');
  assert.equal(state.store.getState().chats.isLoading,false);assert.equal(state.store.getState().chats.hasMore,false);
  await uc.execute();assert.equal(f.requests.length,1);
});
add('actual gateway+adapter+history retains flood metadata and releases current bucket',async()=>{
  const f=pipeline(),state=new sdk.ReadFixture();const uc=new history.LoadChatHistoryUseCase(state.store.createScope(),f.adapter);
  const p=uc.execute(state.params());assert.equal(uc.isLoading(42),true);f.reply(429,'FLOOD_WAIT_37');const error=await failure(p);
  assert.equal(error,f.origin());assert.equal(error.kind,app.AppErrorKind.RATE_LIMIT);assert.equal(error.retryable,true);
  assert.equal(error.tdlibCode,429);assert.equal(error.technicalMessage,'FLOOD_WAIT_37');assert.equal(uc.isLoading(42),false);
});
let completed=false;
process.once('beforeExit',()=>{if(!completed){console.error('HARNESS_ERROR: unfinished test run');process.exitCode=2;}});
(async()=>{
  const results=[];
  for(const test of tests){
    let error; const domainOutcomes=[];
    const completedOwner=test.name.includes('newer same-route completed correction owner');
    const oldSuccess=test.name.startsWith('obsolete success cannot replace');
    const lateSuccess=test.name.startsWith('success retains a real late correction');
    const freshSuccess=test.name.startsWith('a current rejected history bucket can accept');
    const skipped=test.name.startsWith('an execution skipped by a retired Domain');
    const observe=completedOwner||oldSuccess||lateSuccess||freshSuccess||skipped;
    const originalExecute=history.LoadChatHistoryUseCase.prototype.execute;
    if(observe) history.LoadChatHistoryUseCase.prototype.execute=function(params){
      const index=domainOutcomes.length;domainOutcomes.push({state:'pending'});
      const actualPromise=originalExecute.call(this,params);
      actualPromise.then(value=>{domainOutcomes[index]={state:'fulfilled',value};},cause=>{
        domainOutcomes[index]={state:'rejected',error:{name:cause.name,kind:cause.kind,message:cause.message}};});
      return actualPromise; // The production promise and its settlement are unchanged.
    };
    try{
      await test.run();
      if(observe){
        const successIndexes=oldSuccess?[0,1]:completedOwner||freshSuccess?[1]:[0];
        for(const index of successIndexes)assert.deepEqual(domainOutcomes[index],{state:'fulfilled',value:true},
          'Host outcome oracle: actual Domain success must resolve true, not swallow a fixture error');
        if(skipped)assert.deepEqual(domainOutcomes[1],{state:'fulfilled',value:false},'Skipped Domain owns no success/request');
      }
    }catch(e){error=e;}finally{if(observe)history.LoadChatHistoryUseCase.prototype.execute=originalExecute;}
    results.push({name:test.name,scope:test.scope,passed:!error,hostDomainOutcomeOracle:observe?domainOutcomes:undefined,
      error:error?{type:error.name,message:error.message}:undefined});
    console.log((error?'FAIL ':'PASS ')+test.name+(error?' '+error.message:''));}
  const failures=results.filter(r=>!r.passed);
  if(expectRed){assert.ok(failures.length>0,'RED requires behavior assertion failures');
    assert.ok(failures.every(r=>r.error.type==='AssertionError'),'No syntax/type/loader failure may count as RED');}
  for(const [file,raw] of sources)assert.equal(fs.readFileSync(file,'utf8'),raw,'Source drift: '+file);
  const evidence={mode:preimages?'baseline':mutation?'mutant':'candidate',mutation,preimages,
    total:results.length,passed:results.length-failures.length,failed:failures.length,results,
    sources:[...sources].map(([file,text])=>({file,sha256:hash(text)})),
    boundaries:['60 real registered SDK callbacks; 13 additional host pipeline/adapter callbacks',
      'Synthetic native send and readiness, owned fixture timers; actual gateway response/timeout parser',
      'Host-only observer additionally asserts real Domain success=true for native fixture completion callbacks, returning original promises unchanged',
      'No app/native bootstrap, network, account action, device or SDK run; empty-history normalizer exercises no fileUri']};
  if(output)fs.writeFileSync(path.resolve(output),JSON.stringify(evidence,null,2)+'\n');
  completed=true;console.log(`${evidence.passed}/${evidence.total} PASS; ${failures.length} failures`);
  process.exitCode=failures.length&&!expectRed?1:0;
})().catch(error=>{completed=true;console.error('HARNESS_ERROR',error.stack);process.exitCode=2;});

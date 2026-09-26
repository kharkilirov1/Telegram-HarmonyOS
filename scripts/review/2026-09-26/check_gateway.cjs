// Audit reproduction: assertions confirm known defects at dev@2d2f683.
// This is not a corrected-behavior acceptance suite; native/platform APIs are mocked.
const fs = require('node:fs');
const { stripTypeScriptTypes } = require('node:module');
const assert = require('node:assert/strict');
const root = require('node:path').resolve(__dirname, '../../../entry/src/main/ets') + '/';
const hilog = {info(){}, warn(){}, error(){}};
function load(path, names, deps = {}) {
  const source = fs.readFileSync(root + path, 'utf8').replace(/^import\s[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, '');
  const js = stripTypeScriptTypes(source, {mode:'transform'});
  return new Function(...Object.keys(deps), js + '\nreturn {' + names.join(',') + '};')(...Object.values(deps));
}
const {TdObject} = load('models/td/common/index.ets', ['TdObject']);
const errors = load('core/model/AppError.ets', ['AppError','AppErrorKind','classifyTdlibError']);
const ports = load('domain/ports/TdGatewayPort.ets', ['GatewayError','GatewayErrorCode'], errors);
const dispatch = load('infra/threading/MainThreadDispatcher.ets', ['getMainThreadDispatcher'], {hilog});
const callbacks = [];
const closed = new Set();
const sent = [];
let creates = 0;
let activeCallback;
let suppressClose = false;
const closedUpdate = id => ({'@type':'updateAuthorizationState', '@client_id':id, authorization_state:{'@type':'authorizationStateClosed'}});
const tdlib = {
  createClient(){return ++creates;},
  startReceiveLoop(cb){callbacks.push(cb); activeCallback=cb;},
  stopReceiveLoop(){activeCallback=null;},
  send(id, text){
    const req = JSON.parse(text); sent.push({id, method:req['@type']});
    if (suppressClose && req['@type']==='close') return;
    const cb = activeCallback;
    const alreadyClosed = closed.has(id);
    const response = alreadyClosed ? {'@type':'error',code:500,message:'Client is closed'} : {'@type':'ok'};
    const batch = [{...response,'@client_id':id,'@extra':req['@extra']}];
    if (!alreadyClosed && (req['@type']==='close' || req['@type']==='logOut')) { closed.add(id); batch.push(closedUpdate(id)); }
    queueMicrotask(()=>cb(JSON.stringify(batch)));
  }
};
const gateway = load('infra/td/gateway/TdGateway.ets', ['getTdGateway','TdGatewayImpl'], {
  ...errors, TdObject, ...dispatch, hilog, tdlib,
  // Accelerate only the 10-second close request watchdog; preserve drain scheduling.
  setTimeout:(fn,ms)=>setTimeout(fn,ms===10000?10:ms)
});
const adapter = load('infra/td/adapter/TdGatewayAdapter.ets', ['getTdGatewayAdapter','resetTdGatewayAdapter'], {
  ...ports, ...errors, ...gateway, TdObject, hilog,
  serializeCommand: command => ({method:command.type, params:new TdObject()})
});
const {LoginController} = load('ui/controllers/LoginController.ets', ['LoginController'], {
  ...adapter, hilog, createSetPhoneNumberCommand:()=>({type:'setAuthenticationPhoneNumber'})
});
const {AuthSideEffect} = load('core/sideeffects/AuthSideEffect.ets', ['AuthSideEffect'], {
  ...gateway, ...adapter, ...errors, TdObject, hilog
});
const pause = () => new Promise(resolve=>setTimeout(resolve,20));
const dispatcher = dispatch.getMainThreadDispatcher();
function wireUpdates(){dispatcher.subscribeUpdates(raw=>gateway.TdGatewayImpl.getInstance().handleUpdateOnMainThread(raw));}
(async()=>{
  wireUpdates();
  const oldGateway=gateway.getTdGateway();
  await oldGateway.initialize();
  const effect=new AuthSideEffect();
  // Exercise the actual closed-state handler without starting platform-dependent initialization.
  effect.isRunning=true;
  effect.tdlibParamsAccepted=true;
  oldGateway.subscribeUpdates(update=>effect.handleUpdate(update,effect.lifecycleToken));
  await oldGateway.send('logOut');
  await pause();
  assert.equal(creates,1);
  assert.equal(oldGateway.getState(),'ready');
  assert.equal(effect.tdlibParamsAccepted,false);
  console.log('CONFIRMED: authorizationStateClosed resets flags but creates no new client; gateway still ready');
  await assert.rejects(oldGateway.send('getAuthorizationState'));
  await oldGateway.destroy();
  adapter.resetTdGatewayAdapter();
  wireUpdates();
  const timeoutGateway=gateway.getTdGateway();
  await timeoutGateway.initialize();
  const oldCallback=callbacks[1];
  const controller=LoginController.getInstance();
  suppressClose=true;
  await timeoutGateway.destroy();
  suppressClose=false;
  assert.equal(closed.has(2),false);
  adapter.resetTdGatewayAdapter();
  wireUpdates();
  const newGateway=gateway.getTdGateway();
  await newGateway.initialize();
  const accepted=[];
  newGateway.subscribeUpdates(update=>accepted.push(update.getNumber('@client_id')));
  // Replay a batch already queued by the old native TSFN at the time of stop.
  oldCallback(JSON.stringify([{'@type':'updateConnectionState','@client_id':2,state:{'@type':'connectionStateReady'}}]));
  await pause();
  assert.deepEqual(accepted,[2]);
  console.log('CONFIRMED: after close timeout, old callback for client 2 delivered update to new gateway for client 3');
  const before=sent.length;
  const result=await controller.sendPhoneNumber('+000000000');
  assert.equal(result.success,false);
  assert.equal(sent.length,before);
  assert.equal(newGateway.isReady(),true);
  assert.notEqual(controller.gateway,adapter.getTdGatewayAdapter());
  console.log('CONFIRMED: cached LoginController rejects phone submission before native send after gateway reset');
  await newGateway.destroy();
  console.log('3 controlled source-level reproductions completed; platform/native behavior mocked, no Telegram access');
})().catch(error=>{console.error(error);process.exitCode=1;});

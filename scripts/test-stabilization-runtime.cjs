// Actual AppCoreRuntime + stable AppStore/authReducer + LoginRouter methods.
// Transport, dispatcher/native/bridge/watchers and AppStorage are explicit fixtures.
const H=require('./stabilization-harness.cjs');
const {assert,load,methods,read,tick,deferred,run}=H;
const A=load('core/model/AppState.ets'),E=load('core/model/AppEvent.ets'),errors=load('core/model/AppError.ets');
const td=load('models/td/common/index.ets'),ac=load('core/utils/tdAccessors.ets',td);
const clone=load('core/utils/stateClone.ets',A);
const {authReducer}=load('core/reducers/authReducer.ets',{...A,...clone});
const hilog={info(){},warn(){},error(){},debug(){}};
const {AppStore}=load('core/store/AppStore.ets',{...A,hilog,assertInvariants(){}});
function fixture() {
 let state='idle',generation=0,hooks;const listeners=new Set(),initializations=[],destroys=[],bridge=[],navigation=[];
 let initCalls=0,destroyCalls=0;
 const gateway={getState:()=>state,isReady:()=>state==='ready',getClientGeneration:()=>generation,setClientRecoveryHooks:h=>{hooks=h;},subscribeUpdates:fn=>{listeners.add(fn);return()=>listeners.delete(fn);},
   async initialize(){initCalls++;const next=initializations.shift();state='connecting';if(next)await next.promise;state='ready';},
   async destroy(){destroyCalls++;state='destroying';const next=destroys.shift();if(next)await next.promise;state='idle';generation++;},
   isDrainCongested:()=>false,handleUpdateOnMainThread(){},send(){throw new Error('No transport requests are allowed in runtime fixture');},retryClosedClient(){throw new Error('Closed recovery is a distinct path');}};
 const dispatcher={subscribeUpdates(){},unsubscribe(){},getStats:()=>({})};
 const runtimeDeps={...A,...E,...errors,...td,...ac,hilog,AppStore:class extends AppStore{constructor(){super(authReducer,undefined,false);}},
   appReducer:authReducer,getTdGateway:()=>gateway,getEventNormalizer:()=>({normalize:()=>[],getStats:()=>({})}),NormalizerStats:class{},
   getTdGatewayAdapter:()=>({send(){throw new Error('No adapter request allowed');}}),resetTdGatewayAdapter(){},getMainThreadDispatcher:()=>dispatcher,TdGatewayImpl:{getInstance:()=>gateway},
   initAppStoreBridge:s=>bridge.push(s),resetAppStoreBridge(){},resetAccountNavigationContext:()=>navigation.push('reset'),
   setAuthSideEffectStore(){},startAuthSideEffect(){},stopAuthSideEffect(){},
   createLoadChatHistoryUseCase:()=>({hydrateUsersIfMissing:async()=>{}}),LoadChatHistoryUseCase:{resetState(){}},resetLoadChatsUseCase(){},
   createDownloadAvatarsUseCase:()=>({start(){}}),resetDownloadAvatarsUseCase(){},createDownloadMessageMediaUseCase:()=>({start(){}}),resetDownloadMessageMediaUseCase(){},resetMessageCacheManager(){}};
 const R=load('app/bootstrap/AppCoreRuntime.ets',runtimeDeps);const runtime=R.getAppCoreRuntime();
 const source=read('ui/pages/login/LoginRouter.ets');
 const names=['isCurrentRouterContinuation','retryRecovery','hasRecoveryFailure','syncFromAppStorage','resetLocalActions','aboutToAppear','aboutToDisappear'];
 const Router=methods('ui/pages/login/LoginRouter.ets',names,{getAppCoreRuntime:()=>runtime,hilog,$r:name=>({id:1,name}),StorageKeys:{},AppStorage:{get(){return undefined;}}});
 const router=new Router();Object.assign(router,{runtimeProvider:()=>runtime,authStatus:'notInitialized',authError:'',localError:undefined,forceBackInFlight:false,recoveryInFlight:false,pageLifecycleToken:0,recoveryRequestSerial:0,forceBackRequestSerial:0});
 const writes=[];
 const Entry=methods('entryability/EntryAbility.ets',['onCreate','onDestroy'],{hilog,DOMAIN:0,TAG:'EntryAbility',getAppCoreRuntime:()=>R.getAppCoreRuntime(),resetAppCoreRuntime:()=>R.resetAppCoreRuntime(),setAppContext(){},AppStorage:{setOrCreate:(key,value)=>writes.push([key,value])},StorageKeys:{GLASS_MODE:'glassMode'},ConfigurationConstant:{ColorMode:{COLOR_MODE_LIGHT:1}}});
 const entry=new Entry();Object.assign(entry,{abilityLifecycleToken:0,context:{config:{colorMode:1}}});
 return {R,runtime,router,entry,writes,gateway,initializations,destroys,bridge,navigation,get initCalls(){return initCalls;},get destroyCalls(){return destroyCalls;},state:()=>state,holdInit(){const d=deferred();initializations.push(d);return d;},holdDestroy(){const d=deferred();destroys.push(d);return d;}};
}
const failCause=()=>new errors.AppError(errors.AppErrorKind.NETWORK,'Startup unavailable','fixture detail',503,true);
async function failStart(f,mounted=false,holdCleanup=false) {
 const pending=f.holdInit();const cleanup=holdCleanup?f.holdDestroy():undefined;
 if(mounted)f.router.aboutToAppear();
 const start=f.runtime.initialize();await tick();pending.reject(failCause());
 if(cleanup){await tick();cleanup.reject(new errors.AppError(errors.AppErrorKind.NETWORK,'Retirement pending','fixture',0,true));}
 await assert.rejects(start);await tick();
}
const tests=[];const test=(name,fn)=>tests.push([name,fn]);
for(const mounted of [false,true])test('actual EntryAbility.onCreate failure '+(mounted?'after':'before')+' root mount retains retry owner',async()=>{const f=fixture();const owner=f.runtime.getLifecycleStore();const pending=f.holdInit();const create=f.entry.onCreate();if(mounted)f.router.aboutToAppear();await tick();pending.reject(failCause());await create;await tick();await tick();if(!mounted)f.router.aboutToAppear();assert.equal(f.R.getAppCoreRuntime(),f.runtime,'EntryAbility rejection must retain the mounted runtime');assert.equal(f.router.hasRecoveryFailure(),true);assert.equal(f.runtime.getLifecycleStore(),owner);f.router.aboutToDisappear();await f.entry.onDestroy();});
test('actual EntryAbility.onDestroy is awaitable and blocks late startup side effects',async()=>{const f=fixture();const pending=f.holdInit();const creation=f.entry.onCreate();await tick();const cleanup=f.holdDestroy();let destroyed=false;const destroying=f.entry.onDestroy().then(()=>{destroyed=true;});await tick();assert.equal(destroyed,false,'onDestroy must wait for pending initialization and retirement');pending.resolve();await creation;await tick();await tick();assert.equal(f.writes.some(([key])=>key==='glassMode'),false);cleanup.resolve();await destroying;assert.equal(f.runtime.isPipelineRunning(),false);});
for(const mounted of [false,true])test('startup rejection '+(mounted?'after':'before')+' root mount publishes visible retry on stable store',async()=>{const f=fixture();const owner=f.runtime.getLifecycleStore();await failStart(f,mounted);if(!mounted)f.router.aboutToAppear();assert.equal(f.runtime.getLifecycleStore(),owner,'router/runtime retain the same stable store owner');assert.equal(f.router.authStatus,'notInitialized');assert.equal(f.router.hasRecoveryFailure(),true,'initial startup failure must render explicit Retry');f.router.aboutToDisappear();await f.R.resetAppCoreRuntime();});
test('initial Retry reaches actual initialize, duplicate Retry joins one request',async()=>{const f=fixture();await failStart(f);f.router.aboutToAppear();const gate=f.holdInit();const first=f.router.retryRecovery();const duplicate=f.router.retryRecovery();await tick();assert.equal(f.initCalls,2,'explicit Retry must retry initial startup');assert.equal(f.router.recoveryInFlight,true);assert.equal(f.runtime.getLifecycleStore().getState().auth.error,'','old marker must clear while current attempt runs');gate.resolve();await Promise.all([first,duplicate]);assert.equal(f.initCalls,2);assert.equal(f.router.recoveryInFlight,false);assert.equal(f.runtime.isPipelineRunning(),true);f.router.aboutToDisappear();await f.R.resetAppCoreRuntime();});
test('rejected retirement on Retry blocks any new client initialization',async()=>{const f=fixture();await failStart(f,false,true);f.router.aboutToAppear();const cleanup=f.holdDestroy();const retry=f.router.retryRecovery();await tick();assert.equal(f.initCalls,1,'no initialize while former retirement owns transport');assert.equal(f.destroyCalls,2,'explicit Retry must retry retirement');cleanup.reject(new errors.AppError(errors.AppErrorKind.NETWORK,'Still retiring','fixture',0,true));await retry;assert.equal(f.initCalls,1);assert.equal(f.router.hasRecoveryFailure(),true);f.router.aboutToDisappear();await f.R.resetAppCoreRuntime();});
test('teardown during Retry retirement makes late completion inert',async()=>{const f=fixture();await failStart(f,false,true);f.router.aboutToAppear();const cleanup=f.holdDestroy();const retry=f.router.retryRecovery();await tick();const resetting=f.R.resetAppCoreRuntime();f.router.aboutToDisappear();cleanup.resolve();await Promise.all([retry,resetting]);await tick();assert.equal(f.initCalls,1,'late cleanup must never bootstrap after owner teardown');assert.equal(f.runtime.isPipelineRunning(),false);});
test('root mount/disappear suppresses old retry finally',async()=>{const f=fixture();await failStart(f);f.router.aboutToAppear();const gate=f.holdInit();const retry=f.router.retryRecovery();await tick();assert.equal(f.initCalls,2);f.router.aboutToDisappear();const serial=f.router.recoveryRequestSerial;f.router.recoveryInFlight=true;gate.reject(failCause());await retry;assert.equal(f.router.recoveryRequestSerial,serial);assert.equal(f.router.recoveryInFlight,true,'old finally cannot clear a newer lifecycle busy state');await f.R.resetAppCoreRuntime();});
test('successful runtime startup uses one stable store and bridge owner',async()=>{const f=fixture();const owner=f.runtime.getLifecycleStore();const first=f.runtime.initialize();const duplicate=f.runtime.initialize();await Promise.all([first,duplicate]);assert.equal(f.initCalls,1);assert.equal(f.runtime.getLifecycleStore(),owner);assert.deepEqual(f.bridge,[owner]);await f.R.resetAppCoreRuntime();});
run('stabilization runtime',tests).catch(error=>{console.error(error.stack);process.exitCode=1;});

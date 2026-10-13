// Actual profile usecases, store/reducer and original members async methods.
// Controlled gateway, row presentation sink, resources and debounce clock only.
const H=require('./stabilization-harness.cjs');
const {assert,load,methods,read,run,tick,deferred}=H;
const A=load('core/model/AppState.ets'); const C=load('core/model/AppCommand.ets');
const E=load('core/model/AppEvent.ets'); const errors=load('core/model/AppError.ets');
const td=load('models/td/common/index.ets'); const ac=load('core/utils/tdAccessors.ets',td);
const clone=load('core/utils/stateClone.ets',A);
const hilog={info(){},debug(){},warn(){},error(){}};
const {AppStore}=load('core/store/AppStore.ets',{...A,hilog,assertInvariants(){}});
const {usersReducer}=load('core/reducers/usersReducer.ets',{...A,...clone,...E});
const raw=value=>td.TdObject.fromJSON(JSON.stringify(value));
function profileFixture(responseType='userFullInfo') {
  const initial=A.createInitialAppState();initial.auth.userId=123;
  initial.users.users.set(7,Object.assign(new A.User(),{id:7,firstName:'A',bio:'cached bio'}));
  const events=[];
  const store=new AppStore((state,e)=>{events.push(e);return usersReducer(state,e);},initial,false);
  let current=store.createScope();const response=deferred(),requests=[];
  const gateway={send(command){requests.push(command);return response.promise;}};
  const runtime={getStore:()=>current};
  const P=load('domain/usecases/loadProfileInfo.ets',{...C,...E,...errors,...td,...ac,hilog,AppStore,getTdGatewayAdapter:()=>gateway,getAppCoreRuntime:()=>runtime});
  return {P,store,events,response,requests,gateway,get current(){return current;},revoke(){store.invalidateScopes();current=store.createScope();},reply(extra={}){response.resolve(raw({'@type':responseType,...extra}));}};
}
const tests=[];const test=(name,fn)=>tests.push([name,fn]);
test('formattedText user bio reaches actual User reducer exactly',async()=>{const f=profileFixture();const task=f.P.loadUserFullInfo(7);f.reply({bio:{'@type':'formattedText',text:'Expected bio 😀',entities:[]}});await task;await tick();assert.equal(f.store.getState().users.users.get(7).bio,'Expected bio 😀');});
for(const bio of [null,{'@type':'formattedText',text:'',entities:[]}])test('genuine empty/null bio clears prior cache '+JSON.stringify(bio),async()=>{const f=profileFixture();const task=f.P.loadUserFullInfo(7);f.reply({bio});await task;await tick();assert.equal(f.store.getState().users.users.get(7).bio,'');});
for(const [fn,args,type] of [['loadUserFullInfo',[7],'userFullInfo'],['loadSupergroupFullInfo',[-42,77],'supergroupFullInfo'],['loadBasicGroupFullInfo',[-42,88],'basicGroupFullInfo']]) {
 test(fn+' cannot publish old completion into new account scope',async()=>{const f=profileFixture(type);const task=f.P[fn](...args);assert.equal(f.requests.length,1);f.revoke();f.reply({bio:{'@type':'formattedText',text:'Account A secret',entities:[]},description:'A secret',members:[]});await task;await tick();assert.equal(f.events.length,0,'captured A response must never dispatch into B');});
 test(fn+' current completion dispatches exactly once',async()=>{const f=profileFixture(type);const task=f.P[fn](...args);f.reply({bio:{'@type':'formattedText',text:'current',entities:[]},description:'current',members:[]});await task;await tick();assert.equal(f.events.length,1);});
 test(fn+' preserves typed unavailable cause for explicit UI retry',async()=>{const f=profileFixture(type);const cause=new errors.AppError(errors.AppErrorKind.NETWORK,'Network unavailable','test-only',503,true);const task=f.P[fn](...args);f.response.reject(cause);const result=await task;assert.equal(result?.status,'unavailable');assert.equal(result?.cause,cause);assert.equal(f.events.length,0);});
}
function memberFixture() {
  const original=read('ui/pages/profile/TgProfileMembersPage.ets');
  const allNames=[...original.matchAll(/^  (?:private |public |protected )?(?:async )?(\w+)\(/gm)].map(match=>match[1]);
  const necessary=['loadMembers','mergeDescriptors','scheduleSearch','cancelSearchTimer','closeSearch','aboutToDisappear','handleBackPress'];
  // Pull new guard/helper methods too, without importing ArkUI builders/row widgets.
  for(const name of allNames)if(/Current|Request|invalidate|Intent|retryMembers|clear|reset|Scope|Unavailable|releaseRoute/.test(name)&&!necessary.includes(name))necessary.push(name);
  const timers=new Map();let timerSeq=0;
  const initial=A.createInitialAppState();initial.auth.userId=123;const root=new AppStore((s)=>s,initial,false);let current=root.createScope();
  const pending=[],useCase={execute(...args){const d=deferred();pending.push({...d,args});return d.promise;}};
  const gateway={send(){throw new Error('host members must use explicit controlled usecase');}};
  const P=load('domain/usecases/loadProfileInfo.ets',{...C,...E,...errors,...td,...ac,hilog,AppStore,getTdGatewayAdapter:()=>gateway,getAppCoreRuntime:()=>({getStore:()=>current})});
  const Actual=methods('ui/pages/profile/TgProfileMembersPage.ets',necessary,{...A,...P,AppStore,getAppCoreRuntime:()=>({getStore:()=>current}),getTdGatewayAdapter:()=>gateway,createChatMembersUseCase:()=>useCase,PAGE_SIZE:100,SEARCH_DEBOUNCE_MS:240,DOMAIN:0x35,TAG:'Members',hilog,localized:(_id,text)=>text,$r:()=>({id:1}),setTimeout:fn=>{const id=++timerSeq;timers.set(id,fn);return id;},clearTimeout:id=>timers.delete(id)});
  const p=new Actual();Object.assign(p,{useCase,chatId:-42,supergroupId:77,filterKind:'all',searchQuery:'',isSearchMode:false,searchTimer:-1,requestGeneration:0,isClosing:false,isActive:true,requestPending:false,loadMoreFailed:false,loadError:undefined,isLoading:false,isLoadingMore:false,canLoadMore:false,errorText:'',rowCount:0,totalCount:0,descriptors:[],nextOffset:0,pageLifecycleToken:1,routeContext:P.ProfileLoadContext?new P.ProfileLoadContext(current,gateway):{store:current,gateway,isCurrent:()=>current.isScopeCurrent()},pageStack:{pop(){p.popped=(p.popped||0)+1;}},dataSource:{replace(rows){p.rows=rows;}},rebuildRows(state){p.rows=p.descriptors.map(d=>d.stableKey());p.rowCount=p.rows.length;p.lastRowState=state;}});
  return {p,pending,timers,root,revoke(){root.invalidateScopes();current=root.createScope();},flushTimer(){const entry=timers.entries().next().value;assert.ok(entry,'actual debounce must be armed');timers.delete(entry[0]);entry[1]();},reply(index,keys,total=100,canLoadMore=true,rawCount=keys.length){pending[index].resolve({members:keys.map(key=>({stableKey:()=>key,senderUserId:7})),totalCount:total,canLoadMore,rawCount,nextOffset:pending[index].args[4]+rawCount});}};
}
test('member query intent rejects old success before debounce runs',async()=>{const f=memberFixture();f.p.searchQuery='old';const task=f.p.loadMembers(true);f.p.scheduleSearch('new');f.reply(0,['old-result']);await task;assert.equal(f.p.searchQuery,'new');assert.equal(f.p.rows?.includes('old-result')||false,false);});
test('member query intent rejects old error and finally before debounce runs',async()=>{const f=memberFixture();f.p.searchQuery='old';const task=f.p.loadMembers(true);f.p.scheduleSearch('new');f.pending[0].reject(new Error('old offline'));await task;assert.equal(f.p.errorText,'');assert.equal(f.p.searchQuery,'new');});
test('rapid A-B-A is a new intent, not identity equality',async()=>{const f=memberFixture();f.p.searchQuery='A';const task=f.p.loadMembers(true);f.p.scheduleSearch('B');f.p.scheduleSearch('A');f.reply(0,['old-A']);await task;assert.equal(f.p.rows?.includes('old-A')||false,false);assert.equal(f.timers.size,1);});
test('search debounce delays transport while revoking earlier page request',async()=>{const f=memberFixture();f.p.canLoadMore=true;f.p.scheduleSearch('new');const accidental=f.p.loadMembers(false);assert.equal(f.pending.length,0,'pagination must not fetch an old cursor under pending query');await accidental;f.flushTimer();assert.equal(f.pending.length,1);assert.equal(f.pending[0].args[3],'new');assert.equal(f.pending[0].args[4],0);f.reply(0,['new-result']);await tick();assert.deepEqual(f.p.rows,['new-result']);});
test('member Back immediately fences pending success before disappear callback',async()=>{const f=memberFixture();const task=f.p.loadMembers(true);f.p.handleBackPress();f.reply(0,['late-back']);await task;assert.equal(f.p.popped,1);assert.equal(f.p.rows?.includes('late-back')||false,false);});
test('member disappearance cancels debounce and stale completion',async()=>{const f=memberFixture();const task=f.p.loadMembers(true);f.p.scheduleSearch('pending');f.p.aboutToDisappear();f.reply(0,['late']);await task;assert.equal(f.timers.size,0);assert.equal(f.p.rows?.includes('late')||false,false);});
test('member account revocation suppresses publication',async()=>{const f=memberFixture();const task=f.p.loadMembers(true);f.revoke();f.reply(0,['account-A']);await task;assert.equal(f.p.rows?.includes('account-A')||false,false);});
test('member page failure preserves rows and cursor',async()=>{const f=memberFixture();const task=f.p.loadMembers(true);f.reply(0,['retained'],100,true);await task;const before=f.p.nextOffset;const page=f.p.loadMembers(false);f.pending[1].reject(new Error('page offline'));await page;assert.deepEqual(f.p.rows,['retained']);assert.equal(f.p.nextOffset,before);assert.ok(f.p.errorText.length>0);});
test('member page failure blocks incidental automatic scroll retries',async()=>{const f=memberFixture();const task=f.p.loadMembers(true);f.reply(0,['retained'],100,true);await task;const page=f.p.loadMembers(false);f.pending[1].reject(new Error('page offline'));await page;const accidental=f.p.loadMembers(false);assert.equal(f.pending.length,2,'only explicit page Retry may repeat the failed cursor');await accidental;});
test('member duplicate pagination request is single flight',async()=>{const f=memberFixture();const task=f.p.loadMembers(true);f.reply(0,['retained'],100,true);await task;const page=f.p.loadMembers(false);const duplicate=f.p.loadMembers(false);assert.equal(f.pending.length,2);f.reply(1,['next']);await Promise.all([page,duplicate]);assert.deepEqual(f.p.rows,['retained','next']);});
test('member explicit Retry preserves failed cursor and current query',async()=>{const f=memberFixture();f.p.searchQuery='';const initial=f.p.loadMembers(true);f.reply(0,['retained'],100,true,3);await initial;const page=f.p.loadMembers(false);const cursor=f.pending[1].args[4];f.pending[1].reject(new Error('offline'));await page;assert.equal(typeof f.p.retryMembers,'function','page error requires an explicit Retry action');f.p.retryMembers();f.p.retryMembers();assert.equal(f.pending.length,3);assert.equal(f.pending[2].args[4],cursor);assert.equal(f.pending[2].args[3],'');f.reply(2,['next'],100,true);await tick();assert.deepEqual(f.p.rows,['retained','next']);assert.equal(f.p.errorText,'');});
test('member cursor counts raw members rather than deduplicated display rows',async()=>{const f=memberFixture();const initial=f.p.loadMembers(true);f.reply(0,['same','same'],100,true,3);await initial;assert.deepEqual(f.p.rows,['same']);const page=f.p.loadMembers(false);assert.equal(f.pending[1].args[4],3);f.reply(1,['next'],100,true);await page;});
test('member no-progress page stops incidental load loop',async()=>{const f=memberFixture();const initial=f.p.loadMembers(true);f.reply(0,['same'],100,true);await initial;const page=f.p.loadMembers(false);f.reply(1,['same'],100,true);await page;assert.equal(f.p.canLoadMore,false);const accidental=f.p.loadMembers(false);assert.equal(f.pending.length,2);await accidental;});
test('close member search replaces pending request without stale spinner cleanup',async()=>{const f=memberFixture();f.p.searchQuery='old';f.p.isSearchMode=true;const old=f.p.loadMembers(true);f.p.closeSearch();assert.equal(f.pending.length,2);f.reply(0,['old-result']);await old;assert.equal(f.p.isLoading,true,'old finally must not clear replacement loading');f.reply(1,['current-result']);await tick();assert.deepEqual(f.p.rows,['current-result']);assert.equal(f.p.searchQuery,'');assert.equal(f.p.isSearchMode,false);});
test('queued profile dispatch is revoked before actual store dequeue',async()=>{const f=profileFixture();const queue=deferred();f.store.pendingPromise=queue.promise;const task=f.P.loadUserFullInfo(7);f.reply({bio:{'@type':'formattedText',text:'queued account A',entities:[]}});await tick();f.revoke();queue.resolve();await task;await tick();assert.equal(f.events.length,0);});
function profilePageFixture(f=profileFixture()) {
 const source=read('ui/pages/profile/TgProfilePage.ets');const boundary=source.search(/^@ComponentV2/m);assert.ok(boundary>0);const prefix=source.slice(0,boundary);
 const funcs=[...prefix.matchAll(/^function (\w+)\(/gm)].map(m=>m[1]);
 const deps={...A,...f.P,AppStore,getAppCoreRuntime:()=>({getStore:()=>f.current}),getTdGatewayAdapter:()=>f.gateway,hilog,DOMAIN:0x30,TAG:'Profile',localized:(_id,text)=>text,$r:()=>({id:1}),TgUiTokens:{AVATAR_COLOR_5:'gray'},fileUri:{getUriFromPath:p=>'file://'+p}};
 const prefixModule=load('ui/pages/profile/TgProfilePage.ets',deps,()=>prefix+funcs.map(name=>'\nexport const actual_'+name+'='+name+';').join(''));
 for(const [key,value]of Object.entries(prefixModule))if(key.startsWith('actual_'))deps[key.slice(7)]=value;
 const allNames=[...source.matchAll(/^  (?:private |public |protected )?(?:async )?(\w+)\(/gm)].map(m=>m[1]);
 const names=['applyState','loadUserProfile','loadProfile','aboutToDisappear'];
 for(const name of allNames)if(/bindProfile|ownsProfile|requestFullInfo|retryProfile|clearPresentation|releaseProfile|accountUnavailable/.test(name)&&!names.includes(name))names.push(name);
 const Page=methods('ui/pages/profile/TgProfilePage.ets',names,deps);const p=new Page();
 Object.assign(p,{chatId:0,profileUserId:7,isActive:true,isClosing:false,pageLifecycleToken:1,requestGeneration:0,requestPending:false,routeContext:f.P.ProfileLoadContext?new f.P.ProfileLoadContext(f.current,f.gateway):undefined,title:'',bio:'',phoneNumber:'',username:'',avatarImageSrc:'',hasPeer:false,loadState:'loading',errorText:''});
 return {f,p,params:prefixModule.ProfileRouteParams};
}
test('actual profile applyState clears old details when peer disappears',()=>{const {f,p}=profilePageFixture();p.applyState(f.current.getState());assert.equal(p.title,'A');const absent=A.createInitialAppState();p.applyState(absent);assert.equal(p.title,'');assert.equal(p.bio,'');assert.equal(p.avatarImageSrc,'');});
test('profile push context rejects delayed onReady after account replacement',async()=>{const {f,p,params}=profilePageFixture();const route=new params(0,7);f.revoke();p.routeContext=route.context;p.loadUserProfile(7);await tick();assert.equal(f.requests.length,0,'an A-owned delayed route must not acquire B transport');assert.equal(p.title,'');});
test('actual profile page failure exposes Retry and preserves current peer',async()=>{const {f,p}=profilePageFixture();p.loadUserProfile(7);f.response.reject(new errors.AppError(errors.AppErrorKind.NETWORK,'offline','fixture',503,true));await tick();assert.equal(p.loadState,'unavailable');assert.ok(p.errorText.length>0);assert.equal(p.title,'A');assert.equal(typeof p.retryProfile,'function');p.aboutToDisappear();});
run('stabilization profiles',tests).catch(error=>{console.error(error.stack);process.exitCode=1;});

// Actual scoped signal, actual route class and actual profile/nav callbacks.
// NavPathStack is the sole controlled platform boundary; its bottom-first
// popToName and indexed methods implement the official SDK contract.
const H=require('./stabilization-harness.cjs');
const {assert,load,methods,run}=H;
const A=load('core/model/AppState.ets'),C=load('core/model/AppCommand.ets'),E=load('core/model/AppEvent.ets');
const td=load('models/td/common/index.ets'),ac=load('core/utils/tdAccessors.ets',td),errors=load('core/model/AppError.ets');
const hilog={info(){},debug(){},warn(){},error(){}};
const {AppStore}=load('core/store/AppStore.ets',{...A,hilog,assertInvariants(){}});
const {ChatOpenLease}=load('domain/usecases/ChatOpenLease.ets',{...C,...td});
const {ChatScreenRouteParams}=load('ui/pages/chat/ChatScreenRouteParams.ets',{AppStore,ChatOpenLease});
const gateway={send(){throw new Error('search intent fixture forbids transport');}};
function store(){const state=A.createInitialAppState();state.auth.userId=123;return new AppStore(s=>s,state,false);}
function fixture(){
 const account=store(),other=store();
 const {PendingChatSearchSignal:S}=load('ui/pages/chat/PendingChatSearchSignal.ets',{AppStore});
 const P=load('domain/usecases/loadProfileInfo.ets',{...C,...E,...errors,...td,...ac,hilog,AppStore,getTdGatewayAdapter:()=>gateway,getAppCoreRuntime:()=>({getStore:()=>account})});
 const Page=methods('ui/pages/profile/TgProfilePage.ets',['openChatSearch'],{PendingChatSearchSignal:S,ChatScreenRouteParams,hilog,DOMAIN:0x30,TAG:'Profile'});
 const p=new Page();const context=P.ProfileLoadContext?new P.ProfileLoadContext(account,gateway):{accountStore:account,store:account.createScope(),isCurrent(){return this.store.isScopeCurrent();}};
 const entries=[],targets=[];let onPop,lookup;
 const stack={getAllPathName(){return entries.map(e=>e.name);},getParamByIndex(index){lookup?.(index);return entries[index]?.param;},popToIndex(index){targets.push(index);onPop?.(index);},popToName(name){const index=entries.findIndex(e=>e.name===name);targets.push(index);onPop?.(index);return index;}};
 Object.assign(p,{chatId:-42,hasPeer:true,isActive:true,isClosing:false,pageLifecycleToken:1,routeContext:context,pageStack:stack});
 const route=(chat=-42,owner=account)=>new ChatScreenRouteParams(chat,'Controlled chat',owner,gateway);
 const add=(chat=-42,owner=account)=>{const r=route(chat,owner);entries.push({name:'TgChatScreenPage',param:r});return r;};
 const nav=load('ui/pages/chat/ChatScreenViewEventHandlers.ets',{PendingChatSearchSignal:S,ChatScreenRouteParams,PendingSharedMediaActionSignal:{consume(){return undefined;}},PendingJumpSignal:{consume(){return '0';}}});
 return {account,other,S,p,entries,targets,route,add,nav,set onPop(fn){onPop=fn;},set lookup(fn){lookup=fn;}};
}
const tests=[],test=(name,fn)=>tests.push([name,fn]);
test('same account search signal consumes exactly once',()=>{const f=fixture();f.S.set(-42,f.account,f.account.createScope());assert.equal(f.S.consume(-42,f.account),true);assert.equal(f.S.consume(-42,f.account),false);});
test('different chat in same account preserves target intent',()=>{const f=fixture();f.S.set(-42,f.account,f.account.createScope());assert.equal(f.S.consume(-43,f.account),false);assert.equal(f.S.consume(-42,f.account),true);});
test('account B same chat cannot consume account A intent',()=>{const f=fixture();f.S.set(-42,f.account,f.account.createScope());assert.equal(f.S.consume(-42,f.other),false);assert.equal(f.S.consume(-42,f.account),false,'account mismatch retires the stale intent');});
test('account revocation and A-B-A epoch cannot revive old intent',()=>{const f=fixture();f.S.set(-42,f.account,f.account.createScope());f.account.invalidateScopes();assert.equal(f.S.consume(-42,f.account),false);});
test('missing owner cannot consume a chat-id-only intent',()=>{const f=fixture();f.S.set(-42,f.account,f.account.createScope());assert.equal(f.S.consume(-42,undefined),false);});
test('profile returns ChatA -> ChatB -> ProfileB to ChatB',()=>{const f=fixture();f.add(-41);f.add(-42);f.entries.push({name:'TgProfilePage',param:{chatId:-42}});f.p.openChatSearch();assert.deepEqual(f.targets,[1]);assert.equal(f.S.consume(-42,f.account),true);});
test('profile chooses nearest live matching route among duplicate names',()=>{const f=fixture();f.add(-42);f.add(-41);f.add(-42);f.p.openChatSearch();assert.deepEqual(f.targets,[2]);});
test('same chat id ancestor in another account is never a target',()=>{const f=fixture();f.add(-42);f.add(-42,f.other);f.p.openChatSearch();assert.deepEqual(f.targets,[0]);assert.equal(f.S.consume(-42,f.account),true);});
test('only wrong-account ancestor installs no signal or navigation',()=>{const f=fixture();f.add(-42,f.other);f.p.openChatSearch();assert.deepEqual(f.targets,[]);assert.equal(f.S.consume(-42,f.account),false);});
test('missing matching chat route installs no signal or navigation',()=>{const f=fixture();f.add(-41);f.entries.push({name:'TgProfilePage',param:{chatId:-42}});f.p.openChatSearch();assert.deepEqual(f.targets,[]);assert.equal(f.S.consume(-42,f.account),false);});
test('a plain id record cannot impersonate an owned chat route',()=>{const f=fixture();f.entries.push({name:'TgChatScreenPage',param:{chatId:-42,accountStore:f.account}});f.p.openChatSearch();assert.deepEqual(f.targets,[]);assert.equal(f.S.consume(-42,f.account),false);});
test('revoked route with same ids does not revive on account ABA',()=>{const f=fixture();f.add(-42);f.account.invalidateScopes();f.p.routeContext.store=f.account.createScope();f.p.routeContext.isCurrent=()=>true;f.p.openChatSearch();assert.deepEqual(f.targets,[]);assert.equal(f.S.consume(-42,f.account),false);});
test('navigation failure cancels only its own pending intent',()=>{const f=fixture();f.add();f.onPop=()=>{throw new Error('Controlled pop failure');};f.p.openChatSearch();assert.equal(f.S.consume(-42,f.account),false);assert.equal(f.p.isClosing,false);});
test('navigation failure cannot cancel a replacement intent',()=>{const f=fixture();f.add();f.onPop=()=>{f.S.set(-43,f.account,f.account.createScope());throw new Error('Controlled replacement pop failure');};f.p.openChatSearch();assert.equal(f.S.consume(-43,f.account),true);assert.equal(f.S.consume(-42,f.account),false);});
test('repeated profile search taps perform a single navigation',()=>{const f=fixture();f.add();f.p.openChatSearch();f.p.openChatSearch();assert.deepEqual(f.targets,[0]);assert.equal(f.S.consume(-42,f.account),true);assert.equal(f.S.consume(-42,f.account),false);});
test('route replacement during target lookup fences navigation',()=>{const f=fixture();f.add();let called=false;f.lookup=()=>{if(!called){called=true;f.entries[0]={name:'TgChatScreenPage',param:f.route(-41)};}};f.p.openChatSearch();assert.deepEqual(f.targets,[]);assert.equal(f.S.consume(-42,f.account),false);});
for(const flag of ['hasPeer','isActive'])test('profile '+flag+' false blocks search',()=>{const f=fixture();f.add();f.p[flag]=false;f.p.openChatSearch();assert.deepEqual(f.targets,[]);assert.equal(f.S.consume(-42,f.account),false);});
function host(f,owner=f.account,route=f.route(-42,owner)){return{activeChatId:-42,accountStore:owner,routeContext:route,opens:0,showOwnedChatRoute:()=>true,beginSharedMediaAction(){},jumpToMessageId(){},openSearch(){this.opens++;}};}
test('actual nav shown consumes current route intent once',()=>{const f=fixture(),h=host(f);f.S.set(-42,f.account,f.account.createScope());f.nav.handleNavShown(h);f.nav.handleNavShown(h);assert.equal(h.opens,1);});
test('actual nav shown refuses account B same chat intent',()=>{const f=fixture(),h=host(f,f.other);f.S.set(-42,f.account,f.account.createScope());f.nav.handleNavShown(h);assert.equal(h.opens,0);});
test('actual nav shown rejects mismatched route owner',()=>{const f=fixture(),h=host(f,f.account,f.route(-42,f.other));f.S.set(-42,f.account,f.account.createScope());f.nav.handleNavShown(h);assert.equal(h.opens,0);});
test('actual nav shown rejects missing route context',()=>{const f=fixture(),h=host(f);h.routeContext=undefined;f.S.set(-42,f.account,f.account.createScope());f.nav.handleNavShown(h);assert.equal(h.opens,0);});
test('actual nav shown rejects route for another chat',()=>{const f=fixture(),h=host(f,f.account,f.route(-41));f.S.set(-42,f.account,f.account.createScope());f.nav.handleNavShown(h);assert.equal(h.opens,0);});
test('owned-route visibility gate leaves a valid signal for later show',()=>{const f=fixture(),h=host(f);h.showOwnedChatRoute=()=>false;f.S.set(-42,f.account,f.account.createScope());f.nav.handleNavShown(h);assert.equal(h.opens,0);h.showOwnedChatRoute=()=>true;f.nav.handleNavShown(h);assert.equal(h.opens,1);});
run('stabilization search intent',tests).catch(error=>{console.error(error.stack);process.exitCode=1;});

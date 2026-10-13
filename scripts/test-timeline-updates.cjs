#!/usr/bin/env node
// Executes the registered native pure callbacks against actual ETS owners.
// Native List/UiTest geometry is intentionally a separate, mandatory SDK gate.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { createHash } = require('node:crypto');
const { stripTypeScriptTypes } = require('node:module');
const root = path.resolve(__dirname, '..');
const value = name => { const i=process.argv.indexOf(name); return i<0?undefined:process.argv[i+1]; };
const preimage = value('--preimage');
const preimageDir = value('--preimage-dir');
const mutation = value('--mutation');
const expectRed = process.argv.includes('--expect-red');
assert.ok(!(preimage && preimageDir), 'Choose file or baseline directory');
assert.ok(!((preimage || preimageDir) && mutation), 'Preimage and mutation are independent witnesses');
assert.ok(!expectRed || preimage || preimageDir || mutation, 'RED requires an explicit original source or mutation');
const dsPath='entry/src/main/ets/ui/pages/chat/ChatTimelineDataSource.ets';
const transactionPath='entry/src/main/ets/ui/pages/chat/ChatTimelineTransactionCoordinator.ets';
const activationPath='entry/src/main/ets/ui/pages/chat/ChatRouteActivationCoordinator.ets';
const sources=new Map();
const mutations={
  'forced-reload': ['this.reconcileOrderedKeys(oldItems, newItems, newIndices);', 'this.items = newItems; this.notifyDataReloaded();'],
  'absolute-shift': ['Math.max(0, nextIndex - i)', 'Math.max(0, nextIndex)'],
  'skip-delete': ['this.items.splice(i, 1);', '/* mutant: retained removed item */'],
  'wrong-delete-index': ['this.notifyDataDelete(i);', 'this.notifyDataDelete(i + 1);'],
  'skip-change': ['this.notifyDataChange(i);', '/* mutant: no changed-row notification */'],
  'notify-before-add': ['this.items.splice(i, 0, next);\n        this.notifyDataAdd(i);', 'this.notifyDataAdd(i);\n        this.items.splice(i, 0, next);'],
  'duplicate-plan': ['!this.hasUniqueKeys(oldItems) || !this.hasUniqueKeys(newItems) ||\n      !this.hasConsistentRenderKeyOwners(oldItems, newItems)', 'false'],
  'render-owner-plan': ['!this.hasConsistentRenderKeyOwners(oldItems, newItems)', 'false'],
  'reorder-plan': ['if (nextIndex <= previousIndex) {', 'if (false) {'],
  'skip-add-notification': ['this.notifyDataAdd(i);', '/* mutant: silent insertion */'],
  'anchor-guard-disabled': ['if (anchorPrefixChanged || (prependCount > 0 && prevCount > 0 && anchorStableKey)) {',
    'if (prependCount > 0 && prevCount > 0 && anchorStableKey) {'],
  'anchor-rekey-fragile': ['entry.stableKey === anchorStableKey', 'entry.key === anchorStableKey'],
  'timer-unfenced': ['if (lifecycleToken !== host.pageLifecycleToken || !host.transientTimerIds.has(timerId)) {', 'if (false) {'],
  'anchor-prefix-net-zero': ['if (nextAnchorIndex >= 0 && !anchorPrefixChanged) {', 'if (false) {'],
  'append-post-count-bottom': ['newCount > prevCount && wasNearBottom)', 'newCount > prevCount && host.isNearBottom())'],
  'append-start-boundary': ['prevCount - 1 - savedEndIndex <= TIMELINE_BOTTOM_VISIBLE_GAP', 'prevCount - savedStartIndex < 15'],
  'append-expanded-range-rejected': ['host.lastVisibleEndIndex >= savedEndIndex;', 'host.lastVisibleEndIndex === savedEndIndex;'],
  'append-user-intent-disabled': [
    ['if (host.lastVisibleStartIndex < savedStartIndex || host.lastVisibleEndIndex < savedEndIndex) {', 'if (false) {'],
    ['if (!sameVisibleRange && !stillAtBottom) {', 'if (false) {']
  ]
};
const mutationTargets={'anchor-guard-disabled':transactionPath,'anchor-rekey-fragile':transactionPath,
  'anchor-prefix-net-zero':transactionPath,'timer-unfenced':activationPath,
  'append-post-count-bottom':transactionPath,'append-start-boundary':transactionPath,
  'append-expanded-range-rejected':transactionPath,'append-user-intent-disabled':transactionPath};
if(mutation) assert.ok(mutations[mutation], 'Only named in-memory mutations are allowed');
function read(relative) {
  const file=preimageDir && [dsPath,transactionPath].includes(relative) ? path.resolve(preimageDir,relative)
    : relative===dsPath && preimage ? path.resolve(preimage) : path.join(root,relative);
  const raw=fs.readFileSync(file,'utf8'); sources.set(file,raw);
  let text=raw.replaceAll('\r\n','\n');
  if(mutation && relative===(mutationTargets[mutation]||dsPath)) {
    const pairs=Array.isArray(mutations[mutation][0])?mutations[mutation]:[mutations[mutation]];
    for(const [before,after]of pairs){
      assert.ok(text.includes(before), 'Mutation anchor must exist in actual owner');
      text=text.replaceAll(before,after);
    }
  }
  return text;
}
function load(relative,deps={},enumOnly=false) {
  let text=read(relative);
  if(enumOnly) {
    const match=text.match(/export enum TgMessageSendStatus \{[\s\S]*?\n\}/);
    assert.ok(match,'Actual enum declaration required'); text=match[0];
  }
  const names=[...text.matchAll(/^export\s+(?:default\s+)?(?:async\s+)?(?:class|function|enum|const)\s+(\w+)/gm)].map(m=>m[1]);
  const code=text.replace(/^import[\s\S]*?;\s*/gm,'').replace(/^export\s+(?:default\s+)?/gm,'')
    .replace(/^@ObservedV2\s*\n/gm,'').replace(/^(\s*)@Trace\s+/gm,'$1');
  return new Function(...Object.keys(deps),stripTypeScriptTypes(code,{mode:'transform',sourceUrl:relative})+
    '\nreturn {'+names.join(',')+'};')(...Object.values(deps));
}
const checks=[];
const expect=actual=>({assertEqual(expected){assert.equal(actual,expected);},
  assertTrue(){assert.equal(actual,true);},assertFalse(){assert.equal(actual,false);}});
const hilog={info(){},debug(){},warn(){},error(){}};
const main='entry/src/main/ets/';
const meta=load(main+'ui/tg_ui/atoms/TgMessageMeta.ets',{},true);
const state=load(main+'core/model/AppState.ets');
const td=load(main+'models/td/common/index.ets');
const access=load(main+'core/utils/tdAccessors.ets',td);
const selectors=load(main+'domain/selectors/messageSelectors.ets',{...state,...access});
const reply=load(main+'core/utils/replyMessageKey.ets');
const platform={hilog,$r:id=>({id}),getString:()=>'',localized:(_id,fallback)=>fallback,
  ScrollState:{Idle:0,Scroll:1,Fling:2},
  fileUri:{getUriFromPath(){throw new Error('No native file URI operation is expected in text-only host fixtures');}}};
const vo=load(main+'ui/pages/chat/ChatTimelineVO.ets',{...meta,...state,...selectors,...access,...reply,...platform});
const ds=load(dsPath,{...vo,hilog});
const inputs=load('entry/src/ohosTest/ets/testability/TimelineUpdateInputs.ets',{...vo,...ds,expect});
const tests=load('entry/src/ohosTest/ets/test/TimelineUpdateDataSource.test.ets',{
  ...vo,...inputs,expect,describe:(_name,run)=>run(),it:(name,_flag,run)=>checks.push({name,run,scope:'actual SDK callback'})
});
tests.timelineUpdateDataSourceTest();
assert.equal(checks.length,28,'Frozen native pure registry count');
function actualEnum(relative,name) {
  const text=read(relative); const match=text.match(new RegExp('export enum '+name+' \\{[\\s\\S]*?\\n\\}'));
  assert.ok(match,'Actual enum '+name);
  const js=stripTypeScriptTypes(match[0].replace('export ',''),{mode:'transform'});
  return new Function(js+';return '+name+';')();
}
const barFile=main+'ui/tg_ui/atoms/TgChatTopBar.ets';
const bars={TgChatTopBarSubtitleMode:actualEnum(barFile,'TgChatTopBarSubtitleMode'),
  TgChatTopBarTrailingAction:actualEnum(barFile,'TgChatTopBarTrailingAction')};
const pending=load(main+'ui/pages/chat/PendingMediaOpenIntent.ets',vo);
const viewport=load(main+'ui/pages/chat/ChatTimelineViewportCoordinator.ets',{
  ...platform,ChatScrollPositionCache:{positions:new Map()},ScrollAlign:{START:0,END:2}
});
const events=load(main+'ui/pages/chat/ChatScreenViewEventHandlers.ets');
const transaction=load(main+'ui/pages/chat/ChatTimelineTransactionCoordinator.ets',{
  ...vo,...platform,...bars,StorageKeys:{ACTIVE_CHAT_TITLE:'fixture'},
  navigationUIState:{activeChatId:0},chatUIState:{},AppStorage:{set(){}}
});
const fixture=load('entry/src/ohosTest/ets/testability/TimelineTransactionFixture.ets',{
  ...state,...ds,...vo,...pending,...bars,...viewport,...events,...transaction,...inputs,...platform,
  Scroller:class{constructor(){this.calls=[];}scrollToIndex(...args){this.calls.push(args);}},ScrollAlign:{START:0,END:2}
});
const ownership=load('entry/src/ohosTest/ets/test/TimelineUpdateOwnership.test.ets',{
  ...fixture,...platform,expect,describe:(_name,run)=>run(),it:(name,_flag,run)=>checks.push({name,run,scope:'actual SDK callback / explicit transaction fixture'})
});
ownership.timelineUpdateOwnershipTest();
// Native wiring assertions remain unconditional; authored native callbacks are
// not simulated or claimed as passed by this SDK-free runner.
const registry=read('entry/src/ohosTest/ets/test/List.test.ets');
for(const [suite,callback]of [['TimelineUpdateDataSource','timelineUpdateDataSourceTest'],
  ['TimelineUpdateOwnership','timelineUpdateOwnershipTest'],['TimelineUpdateNative','timelineUpdateNativeTest']]){
  assert.equal((registry.match(new RegExp('^import '+callback+" from '\\./"+suite+"\\.test';$",'gm'))||[]).length,1);
  assert.equal((registry.match(new RegExp('^  '+callback+'\\(\\);$','gm'))||[]).length,1);
}
const nativeUI=read('entry/src/ohosTest/ets/testability/components/TimelineUpdateFixture.ets');
const nativeTest=read('entry/src/ohosTest/ets/test/TimelineUpdateNative.test.ets');
const indexSource=read('entry/src/ohosTest/ets/testability/pages/Index.ets');
assert.match(nativeUI,/LazyForEach\(this\.fixture\.dataSource,[\s\S]*entry\.key\)/);
assert.match(nativeUI,/\.maintainVisibleContentPosition\(true\)/);
assert.match(nativeUI,/\.onScrollIndex\([\s\S]*this\.fixture\.onScrollIndex\(start, end\)/);
assert.match(indexSource,/name === TIMELINE_UPDATE_ROUTE[\s\S]*TimelineUpdateFixtureView\(\)/);
assert.match(indexSource,/TimelineUpdateFixture\.prepare\(\);\s*this\.pageStack\.pushPath\(\{ name: TIMELINE_UPDATE_ROUTE \}/);
assert.equal((nativeTest.match(/\bit\(/g)||[]).length,3,'Three native-only callbacks require real SDK execution');
// Supplemental actual transaction + production lifecycle-scheduler witnesses.
// Only the timer service and native Scroller are deterministic host boundaries;
// no callback implementation or transaction algorithm is mirrored here.
const timerTasks=new Map(); let nextTimer=1;
const timerService={setTimeout(task,delay){const id=nextTimer++;timerTasks.set(id,{task,delay});return id;},
  clearTimeout(id){timerTasks.delete(id);}};
const lifecycle=load(activationPath,timerService);
function appendFixture(atBottom=true) {
  timerTasks.clear();
  const f=new fixture.TimelineTransactionFixture();
  const ids=Array.from({length:80},(_,index)=>(index+1)*10);
  f.apply(ids);f.mounted=true;f.lastVisibleStartIndex=atBottom?75:30;f.lastVisibleEndIndex=atBottom?80:36;
  f.transientTimerIds=new Set();
  f.scheduleLifecycleTask=(delay,task)=>lifecycle.scheduleLifecycleTask(f,delay,task);
  return {f,ids};
}
function runTimers(){const pending=[...timerTasks];timerTasks.clear();for(const [,entry]of pending)entry.task();}
function extra(name,run){checks.push({name,run,scope:'host-only actual transaction/lifecycle scheduler; timer/Scroller fixture'});}
extra('at-bottom one-row append executes the actual 16ms follow once',()=>{
  const {f,ids}=appendFixture();f.apply([...ids,810]);
  assert.deepEqual([...timerTasks.values()].map(x=>x.delay),[16]);runTimers();
  assert.equal(f.bottomCalls,1);assert.equal(f.transientTimerIds.size,0);f.dispose();
});
extra('away-from-bottom append does not schedule follow',()=>{
  const {f,ids}=appendFixture(false);f.apply([...ids,810]);
  assert.equal(timerTasks.size,0);assert.equal(f.bottomCalls,0);f.dispose();
});
extra('user index movement before actual append callback preserves newer intent',()=>{
  const {f,ids}=appendFixture();f.apply([...ids,810]);assert.equal(timerTasks.size,1);
  f.onScrollIndex(30,36);assert.equal(f.lastVisibleStartIndex,30);runTimers();
  assert.equal(f.bottomCalls,0);f.dispose();
});
extra('lifecycle replacement rejects an old actual append callback',()=>{
  const {f,ids}=appendFixture();f.apply([...ids,810]);assert.equal(timerTasks.size,1);
  f.pageLifecycleToken++;runTimers();assert.equal(f.bottomCalls,0);f.dispose();
});
extra('removed timer membership rejects an old actual append callback',()=>{
  const {f,ids}=appendFixture();f.apply([...ids,810]);assert.equal(timerTasks.size,1);
  f.transientTimerIds.clear();runTimers();assert.equal(f.bottomCalls,0);f.dispose();
});
extra('lifecycle ABA cannot revive an old actual append callback',()=>{
  const {f,ids}=appendFixture();f.apply([...ids,810]);assert.equal(timerTasks.size,1);
  f.pageLifecycleToken++;f.activeChatId=702;f.pageLifecycleToken++;f.activeChatId=701;
  runTimers();assert.equal(f.bottomCalls,0);f.dispose();
});
extra('large append remembers that the viewport was at bottom before the diff',()=>{
  const {f,ids}=appendFixture();assert.equal(f.isNearBottom(),true);
  f.apply([...ids,...Array.from({length:20},(_,index)=>810+index*10)]);
  runTimers();assert.equal(f.bottomCalls,1);f.dispose();
});
extra('visible end outside the established three-row bottom policy does not follow',()=>{
  const {f,ids}=appendFixture();f.lastVisibleStartIndex=70;f.lastVisibleEndIndex=74;
  assert.equal(f.isNearBottom(),true);assert.equal(f.dataSource.totalCount()-1-f.lastVisibleEndIndex,6);
  f.apply([...ids,810]);runTimers();assert.equal(f.bottomCalls,0);f.dispose();
});
extra('two appends before callbacks retain current bottom intent and target latest tail',()=>{
  const {f,ids}=appendFixture();f.apply([...ids,810]);f.apply([...ids,810,820]);
  assert.equal(timerTasks.size,2);runTimers();assert.ok(f.bottomCalls>=1);
  assert.equal(f.listScroller.calls.at(-1)[0],f.dataSource.totalCount()-1);f.dispose();
});
extra('native expanded end with unchanged start preserves captured large-append intent',()=>{
  const {f,ids}=appendFixture();f.apply([...ids,...Array.from({length:20},(_,index)=>810+index*10)]);
  f.onScrollIndex(75,82);assert.equal(f.lastVisibleStartIndex,75);
  assert.ok(f.dataSource.totalCount()-1-f.lastVisibleEndIndex>3);
  runTimers();assert.equal(f.bottomCalls,1);f.dispose();
});
async function mainRun() {
  const results=[];
  for(const check of checks) {
    try { await check.run(); results.push({name:check.name,scope:check.scope,passed:true}); }
    catch(error) {
      if(!(error instanceof assert.AssertionError)) throw error;
      results.push({name:check.name,scope:check.scope,passed:false,failureKind:'AssertionError',
        actual:error.actual,expected:error.expected,message:error.message});
    }
  }
  for(const [file,before] of sources) assert.equal(fs.readFileSync(file,'utf8'),before,'Sources preserved');
  const failed=results.filter(r=>!r.passed).length;
  console.log(JSON.stringify({project:root,preimage:preimage||null,mutation:mutation||null,
    preimageDir:preimageDir||null,passed:results.length-failed,failed,checks:results,
    sources:Object.fromEntries([...sources].map(([file,text])=>[path.relative(root,file),createHash('sha256').update(text).digest('hex')])),
    sourcePreserved:true,boundaries:['Actual registered Hypium callbacks and complete actual production VO/enum/DataSource',
      'Synthetic input records and Hypium/listener fixture; native UI geometry is NOT executed by this host runner',
      'No transport, account, bootstrap, SDK, build or device operation']},null,2));
  if(expectRed) assert.ok(failed>0,'Mutation/preimage must fail a behavioral assertion');
  else if(failed) process.exitCode=1;
}
mainRun().catch(error=>{console.error('HARNESS_ERROR',error.stack);process.exitCode=2;});

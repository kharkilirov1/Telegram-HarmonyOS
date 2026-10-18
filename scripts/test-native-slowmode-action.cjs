// Actual native action helper; only platform/fixture boundaries are modeled.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {stripTypeScriptTypes}=require('node:module'),{createHash}=require('node:crypto');
const args=process.argv.slice(2),arg=name=>args.find(x=>x.startsWith(name+'='))?.slice(name.length+1);
const root=path.resolve(arg('--root')||path.join(__dirname,'..'));
const testPath=path.join(root,'entry/src/ohosTest/ets/test/SlowmodeNative.test.ets');
const atomPath=path.join(root,'entry/src/main/ets/ui/tg_ui/atoms/TgComposerInput.ets');
const raw=fs.readFileSync(testPath),atomRaw=fs.readFileSync(atomPath);
const source=raw.toString().replace(/\r\n/g,'\n'),atom=atomRaw.toString().replace(/\r\n/g,'\n');
const sha=b=>createHash('sha256').update(b).digest('hex');
const start=source.indexOf('async function clickCurrentSlowmodeAction('),end=source.indexOf('async function prepareNativeInput(',start);
assert.ok(start>=0&&end>start,'Actual native action helper is required');
const helper=source.slice(start,end);
class Selector {
  constructor(id){this.identifier=id;}
  inWindow(bundle){this.bundle=bundle;return this;}
  within(parent){this.ancestor=parent;return this;}
}
function environment(options={}) {
  const calls=[],logs=[];let fixtureGeneration=1,depth=1,stageId=42,currentAbility,activeFixture,clicked=0;
  const expected='synthetic.validation',rect={left:0,top:0,width:1308,height:2880};
  const page={isSending:false,composerSlowmodeSeconds:0,composerCanSubmit:()=>true};
  const fixture={page};activeFixture=fixture;
  const state={page};
  const properties=()=>({id:stageId,windowRect:rect});
  const ability={context:{abilityInfo:{name:'TestAbility',bundleName:expected},currentHapModuleInfo:{name:'entry'},
    windowStage:{getMainWindowSync:()=>({getWindowProperties:properties})}}};
  currentAbility=ability;
  const control={calls,logs,page,fixture,state,ability,rect,
    changeFixture:()=>{activeFixture={page};},changeGeneration:()=>{fixtureGeneration++;},changeDepth:()=>{depth=0;},
    changeStage:()=>{stageId++;},changeAbility:()=>{currentAbility={...ability};},
    originalError:Object.assign(new Error('SDK action failure'),{code:17000004})};
  const rpc=async(name,fn)=>{
    calls.push(name);
    if(options.throwAt===name)throw control.originalError;
    const value=fn();if(options.afterRpc)options.afterRpc(name,control);return value;
  };
  const dock={id:'slowmode-fixture-dock',bundle:expected,
    getBounds:()=>rpc('dock.bounds',()=>options.dockBounds||{left:50,top:900,right:1250,bottom:2100})};
  const target={id:'tg_composer_action',bundle:expected,parent:dock,
    isEnabled:()=>rpc('target.enabled',()=>options.enabled!==false),
    isClickable:()=>rpc('target.clickable',()=>options.clickable!==false),
    getBounds:()=>rpc('target.bounds',()=>options.targetBounds||{left:1070,top:1747,right:1188,bottom:1865}),
    click:()=>rpc('target.click',()=>{clicked++;if(options.clickError)throw control.originalError;if(options.onClick)options.onClick(control);})};
  const foreignDock={...dock,bundle:'foreign.app'},foreignTarget={...target,bundle:'foreign.app',parent:foreignDock};
  let docks=options.docks??[dock],targets=options.targets??[target];
  if(options.duplicateDock)docks=[dock,{...dock}];
  if(options.duplicateTarget)targets=[target,{...target}];
  if(options.foreignOnly){docks=[foreignDock];targets=[foreignTarget];}
  if(options.wrongParent)targets=[{...target,parent:{...dock,id:'another-dock'}}];
  if(options.withDecoys){docks.push(foreignDock);targets.push(foreignTarget,{...target,id:'emoji-icon'});}
  const match=(node,selector)=>node.id===selector.identifier&&(!selector.bundle||node.bundle===selector.bundle)&&(!selector.ancestor||(node.parent&&match(node.parent,selector.ancestor)));
  const fixtureApi={fixture:()=>activeFixture,state,routeGeneration:()=>fixtureGeneration,navigationDepth:()=>depth};
  let focusCount=0;
  const driver={
    findWindow:filter=>rpc('focus.'+(++focusCount),()=>{
      const windows=[{bundleName:'foreign.app',focused:true},{bundleName:expected,focused:true}];
      if(options.noFocusAt===focusCount)windows.pop();
      return windows.find(w=>(filter.bundleName===undefined||w.bundleName===filter.bundleName)&&(filter.focused===undefined||w.focused===filter.focused));
    }),
    findComponents:selector=>rpc(selector.identifier==='slowmode-fixture-dock'?'lookup.dock':'lookup.target',()=>[...docks,...targets].filter(n=>match(n,selector))),
    click:async(x,y)=>{calls.push('coordinate.click');control.coordinate=[x,y];clicked++;}
  };
  const deps={abilityDelegatorRegistry:{getArguments:()=>({bundleName:options.noBundle?'':expected}),getAbilityDelegator:()=>({getCurrentTopAbility:()=>rpc('ability',()=>currentAbility)})},
    $r:()=>({moduleName:options.noModule?'':'entry'}),SlowmodeNativeFixture:fixtureApi,
    window:{getLastWindow:()=>rpc('window.last',()=>({getWindowProperties:()=>({id:options.lastWindowId??stageId,windowRect:rect})}))},
    ON:{id:id=>new Selector(id)},slowmodeResendLog:message=>{if(options.loggerError)throw new Error('logger');logs.push(message);},
    slowmodeResendPhase:()=>{},};
  if(options.setup)options.setup(control);
  return {...control,driver,deps,get clicked(){return clicked;}};
}
async function invoke(options={},text=helper){
  const env=environment(options);
  const fn=new Function(...Object.keys(env.deps),stripTypeScriptTypes(text,{mode:'transform'})+'\nreturn clickCurrentSlowmodeAction;')(...Object.values(env.deps));
  try{await fn(env.driver,{x:1130,y:1806});}catch(error){env.error=error;}
  return env;
}
async function nativeFirstCase(text, moved, expiresDuringBlocked=false, observation={}) {
  let expired=false;const gestures=[],cases=[];
  const send=r=>{r.state.mutations=1;r.fixture.gateway.requests.push({});r.fixture.composer.preparations.push({});
    r.page.pendingAttachmentUris=[];r.page.composerDraftText='';r.page.replyToMessageId='0';};
  const r=environment({targetBounds:{left:1070,top:moved?1447:1747,right:1188,bottom:moved?1565:1865},onClick:owner=>{gestures.push('current-target');send(owner);}});
  Object.assign(r.page,{composerDraftText:'😀 preserved draft',pendingAttachmentUris:['fixture:slowmode-document'],replyToMessageId:'55',
    customEmojiDraftEntities:[{customEmojiId:'123'}],composerSelectionStart:2,composerSelectionEnd:2});
  r.fixture.gateway={requests:[]};r.fixture.composer={preparations:[],recentLoads:0};r.state.mutations=0;
  r.driver.click=async(x,y)=>{
    gestures.push({x,y,expired});
    if(expiresDuringBlocked&&gestures.length===1)r.page.composerSlowmodeSeconds=0;
    if(expired&&!moved&&x===1130&&y===1806)send(r);
  };
  r.driver.waitForComponent=async(selector,timeout)=>{
    assert.equal(timeout,5000);assert.equal(selector.text,'slowmode mutations:1');
    if(observation.labelError)throw r.originalError;
    return r.state.mutations===1&&!observation.labelMissing?{}:undefined;
  };
  r.driver.screenCap=async name=>{if(observation.screenshotError&&name.includes('mutation-label-failed'))throw new Error('diagnostic screenshot');return true;};
  r.driver.delayMs=async()=>{throw new Error('Unexpected modeled retry');};
  Object.assign(r.deps.SlowmodeNativeFixture,{cooldown:async seconds=>{r.page.composerSlowmodeSeconds=Number(seconds);},screenshotPath:name=>'synthetic/'+name});
  r.deps.ON.text=text=>({text});
  const stubs={slowmodeNativeReady:async()=>{},prepareNativeInput:async()=>{},attachmentPoint:async()=>({x:70,y:1806}),
    requireInputSetupSealed:()=>{},slowmodeAction:async()=>({x:1130,y:1806}),
    waitSlowmode:async(_driver,wanted)=>{assert.equal(wanted,true);expired=true;r.page.composerSlowmodeSeconds=0;},
    closeNativeRoute:async(_driver,completed)=>{r.cleanup=completed;}};
  const deps={...r.deps,stubs,console:{info(text){
    if(observation.loggerError&&text.includes('resendPhase=mutation-label-failed'))throw new Error('diagnostic logger');
    r.logs.push(text);
  }},Driver:{create:()=>r.driver},
    describe:(_name,fn)=>fn(),it:(name,_flags,fn)=>cases.push({name,fn}),
    expect:value=>({assertEqual:expected=>assert.deepEqual(value,expected),assertTrue:()=>assert.equal(value,true),assertFalse:()=>assert.equal(value,false)})};
  let code=text.replace(/^import[^\n]+\n/gm,'').replace('export default function','function');
  code+='\n'+Object.keys(stubs).map(k=>`${k}=stubs.${k};`).join('\n')+'\nslowmodeNativeTest();';
  new Function(...Object.keys(deps),stripTypeScriptTypes(code,{mode:'transform'}))(...Object.values(deps));
  assert.equal(cases.length,3);assert.ok(cases[0].name.startsWith('mounted actual Dock'));
  try{await cases[0].fn();}catch(error){r.error=error;}
  return {error:r.error,originalError:r.originalError,mutations:r.state.mutations,gatewayRequests:r.fixture.gateway.requests.length,
    cleanup:r.cleanup,gestures,calls:r.calls,logs:r.logs};
}
const tests=[],mutants=[];
async function check(name,fn){await fn();tests.push({name,passed:true});}
async function reject(name,options,pattern){await check(name,async()=>{const r=await invoke(options);assert.match(r.error?.message||'',pattern);assert.equal(r.clicked,0);});}
async function main(){
  let baselineRed;
  await check('API24 selector contract uses within(On), never API26 withinComponent',async()=>{
    assert.equal(helper.includes('withinComponent'),false);
    assert.equal(helper.split("ON.id('tg_composer_action').inWindow(bundleName).within(dockSelector)").length-1,1);
  });
  const baselinePath=arg('--baseline');
  if(baselinePath){
    const bytes=fs.readFileSync(path.resolve(baselinePath)),old=bytes.toString().replace(/\r\n/g,'\n');
    const steady=await nativeFirstCase(old,false),moved=await nativeFirstCase(old,true);
    assert.equal(steady.error,undefined);assert.equal(steady.mutations,1);
    assert.equal(moved.error?.message,'Slowmode mutation count did not reach 1');assert.equal(moved.mutations,0);
    baselineRed={path:path.resolve(baselinePath),sha256:sha(bytes),stablePass:true,movedFailure:moved.error.message,
      limitation:'Injected movement in actual old callback; not a device-causality claim.'};
  }
  for(const moved of [false,true])await check('actual first native case preserves all assertions with '+(moved?'moved':'stable')+' target',async()=>{
    const r=await nativeFirstCase(source,moved);assert.equal(r.error,undefined);assert.equal(r.mutations,1);assert.equal(r.cleanup,true);
    assert.equal(r.gestures.length,3);assert.equal(r.gestures.filter(x=>x==='current-target').length,1);
  });
  await check('expired blocked-click interval is inconclusive, never accepted',async()=>{
    const r=await nativeFirstCase(source,false,true);assert.match(r.error?.message||'',/inconclusive: cooldown expired during click/);
    assert.equal(r.mutations,0);assert.equal(r.cleanup,false);assert.equal(r.gestures.length,1);
  });
  await check('native label absence is distinguished from actual mutation success',async()=>{
    const r=await nativeFirstCase(source,false,false,{labelMissing:true});
    assert.equal(r.error?.message,'Slowmode mutation count did not reach 1');assert.equal(r.mutations,1);assert.equal(r.gatewayRequests,1);
    assert.equal(r.gestures.length,3);assert.equal(r.cleanup,false);
    assert.ok(r.logs.some(x=>x.includes('resendPhase=mutation-label-failed-1')&&x.includes('mutations=1 gatewayRequests=1')));
  });
  await check('native label RPC failure retains exact error object',async()=>{
    const r=await nativeFirstCase(source,false,false,{labelError:true});assert.equal(r.error,r.originalError);
    assert.equal(r.mutations,1);assert.equal(r.gestures.length,3);
  });
  await check('failed label diagnostic logging cannot replace original missing-label error',async()=>{
    const r=await nativeFirstCase(source,false,false,{labelMissing:true,loggerError:true});
    assert.equal(r.error?.message,'Slowmode mutation count did not reach 1');assert.equal(r.gestures.length,3);
  });
  await check('failed label screenshot cannot replace original missing-label error',async()=>{
    const r=await nativeFirstCase(source,false,false,{labelMissing:true,screenshotError:true});
    assert.equal(r.error?.message,'Slowmode mutation count did not reach 1');assert.equal(r.gestures.length,3);
    assert.ok(r.logs.includes('[SlowmodeNative] mutationFailure screenshot-unavailable'));
  });
  await check('fresh unique owned native target clicks once',async()=>{const r=await invoke();assert.equal(r.error,undefined);assert.equal(r.clicked,1);assert.equal(r.calls.filter(x=>x==='coordinate.click').length,0);assert.ok(r.logs.some(x=>x.includes('captured=1130,1806')&&x.includes('freshBounds=1070,1747,1188,1865')));});
  await check('moved current native target replaces historical point',async()=>{const r=await invoke({targetBounds:{left:1070,top:1447,right:1188,bottom:1565}});assert.equal(r.error,undefined);assert.equal(r.clicked,1);assert.equal(r.calls.includes('coordinate.click'),false);assert.ok(r.logs.some(x=>x.includes('freshCenter=1129,1506')));});
  await check('foreign and different-ID decoys cannot be selected',async()=>{const r=await invoke({withDecoys:true});assert.equal(r.error,undefined);assert.equal(r.clicked,1);});
  for(const [name,options,pattern]of[
    ['missing Dock',{docks:[]},/Dock is not unique/],['duplicate Dock',{duplicateDock:true},/Dock is not unique/],
    ['missing action',{targets:[]},/target is not unique/],['duplicate action',{duplicateTarget:true},/target is not unique/],
    ['foreign-only IDs',{foreignOnly:true},/Dock is not unique/],['action outside current Dock',{wrongParent:true},/target is not unique/],
    ['disabled action',{enabled:false},/not enabled/],['nonclickable action',{clickable:false},/not enabled/],
    ['empty action bounds',{targetBounds:{left:100,top:100,right:100,bottom:110}},/invalid bounds/],
    ['NaN action bounds',{targetBounds:{left:NaN,top:100,right:110,bottom:110}},/invalid bounds/],
    ['clipped in Dock',{targetBounds:{left:20,top:1000,right:100,bottom:1050}},/clipped/],
    ['outside current window',{dockBounds:{left:0,top:0,right:2000,bottom:3000},targetBounds:{left:1400,top:1000,right:1450,bottom:1100}},/clipped/],
    ['missing bundle',{noBundle:true},/expected bundle/],['missing module',{noModule:true},/expected bundle/],
    ['wrong ability name',{setup:r=>r.ability.context.abilityInfo.name='Foreign'},/ability owner/],
    ['wrong ability bundle',{setup:r=>r.ability.context.abilityInfo.bundleName='foreign.app'},/ability owner/],
    ['wrong ability module',{setup:r=>r.ability.context.currentHapModuleInfo.name='other'},/ability owner/],
    ['nonpositive main-window ID',{lastWindowId:0},/window identity/],['last-window Stage mismatch',{lastWindowId:99},/window identity/],
    ['missing initial owned focus',{noFocusAt:1},/owned focused window/],['lost first post-lookup owned focus',{noFocusAt:2},/owned focused window/],
    ['lost second post-lookup owned focus',{noFocusAt:3},/owned focused window/],
    ['fixture replacement after lookup',{afterRpc:(n,r)=>{if(n==='lookup.target')r.changeFixture();}},/fixture owner/],
    ['generation change after bounds',{afterRpc:(n,r)=>{if(n==='target.bounds')r.changeGeneration();}},/fixture owner/],
    ['route popped after enabled',{afterRpc:(n,r)=>{if(n==='target.enabled')r.changeDepth();}},/fixture owner/],
    ['state page replacement',{afterRpc:(n,r)=>{if(n==='lookup.dock')r.state.page={};}},/fixture owner/],
    ['Stage changes during await',{afterRpc:(n,r)=>{if(n==='target.clickable')r.changeStage();}},/Stage owner/],
    ['Ability instance changes before action',{afterRpc:(n,r)=>{if(n==='dock.bounds')r.changeAbility();}},/ability owner/],
    ['model becomes busy',{setup:r=>r.page.isSending=true},/model is not ready/],
    ['renewed cooldown',{setup:r=>r.page.composerSlowmodeSeconds=3},/model is not ready/],
    ['permission no longer allows send',{setup:r=>r.page.composerCanSubmit=()=>false},/model is not ready/]
  ])await reject(name,options,pattern);
  for(const operation of ['lookup.target','target.bounds'])await check('SDK '+operation+' failure preserves same error, no retry',async()=>{const r=await invoke({throwAt:operation});assert.equal(r.error,r.originalError);assert.equal(r.clicked,0);assert.equal(r.calls.filter(x=>x===operation).length,1);});
  await check('click error preserves identity and does not replay',async()=>{const r=await invoke({clickError:true});assert.equal(r.error,r.originalError);assert.equal(r.clicked,1);});
  await check('lost focus after action fails after exactly one click',async()=>{const r=await invoke({noFocusAt:4});assert.match(r.error?.message||'',/lost owned focus/);assert.equal(r.clicked,1);});
  await check('two fresh ownership samples follow all target property lookups',async()=>{
    const r=await invoke();assert.equal(r.error,undefined);
    const lastBounds=r.calls.indexOf('target.bounds'),first=r.calls.indexOf('focus.2'),second=r.calls.indexOf('focus.3'),click=r.calls.indexOf('target.click');
    assert.ok(lastBounds<first&&first<second&&second<click);
  });
  await check('owner change inside issued click is detected without replay',async()=>{const r=await invoke({afterRpc:(n,r)=>{if(n==='target.click')r.changeGeneration();}});assert.match(r.error?.message||'',/fixture owner/);assert.equal(r.clicked,1);});
  await check('both actual atom branches are mutually exclusive',async()=>{
    const a=atom.indexOf('  private buildActionButton()'),b=atom.indexOf('\n  @Builder',a);assert.ok(a>0&&b>a);
    const code='class Choice { '+atom.slice(a,b)+' }';
    for(const api of [false,true])for(const canSend of [false,true])for(const mode of ['nativeImmersive','fallback']){
      const Choice=new Function('deviceInfo',stripTypeScriptTypes(code,{mode:'transform'})+'\nreturn Choice;')({apiAvailable:()=>api});
      const c=new Choice(),seen=[];c.canSend=()=>canSend;c.materialMode=()=>mode;c.buildNativeActionButton=()=>seen.push('native');c.buildFallbackActionButton=()=>seen.push('fallback');c.buildActionButton();
      assert.deepEqual(seen,[api&&!canSend&&mode==='nativeImmersive'?'native':'fallback']);
    }
    assert.equal((atom.match(/\.id\('tg_composer_action'\)/g)||[]).length,2);
    for(const name of ['buildNativeActionButton','buildFallbackActionButton']){
      const begin=atom.indexOf('private '+name+'()'),end=atom.indexOf('\n  @Builder',begin+1);assert.ok(atom.slice(begin,end<0?undefined:end).includes(".id('tg_composer_action')"));
    }
  });
  const variations=[
    ['no-target-uniqueness','targets.length !== 1','targets.length < 1',{duplicateTarget:true},r=>assert.equal(r.clicked,0)],
    ['no-dock-uniqueness','docks.length !== 1','docks.length < 1',{duplicateDock:true},r=>assert.equal(r.clicked,0)],
    ['no-enabled-gate','if (!enabled || !clickable)','if (false)',{enabled:false},r=>assert.equal(r.clicked,0)],
    ['no-clipping-gate','if (!contains(dockBounds, bounds) || !contains(ownerBounds, bounds))','if (false)',{targetBounds:{left:10,top:1000,right:100,bottom:1100}},r=>assert.equal(r.clicked,0)],
    ['no-fixture-generation','SlowmodeNativeFixture.routeGeneration() !== generation','false',{afterRpc:(n,r)=>{if(n==='target.bounds')r.changeGeneration();}},r=>assert.equal(r.clicked,0)],
    ['no-model-gate','if (fixture.page.isSending || fixture.page.composerSlowmodeSeconds !== 0 || !submitEligible)','if (false)',{setup:r=>r.page.composerSlowmodeSeconds=3},r=>assert.equal(r.clicked,0)],
    ['replay-click','await target.click(); checkOwner();','await target.click(); await target.click(); checkOwner();',{},r=>assert.equal(r.clicked,1)],
    ['old-coordinate-click','await target.click(); checkOwner();','await driver.click(capturedAction.x, capturedAction.y); checkOwner();',{},r=>assert.equal(r.calls.includes('coordinate.click'),false)]
  ];
  for(const[name,from,to,options,verify]of variations){assert.equal(helper.split(from).length-1,1,name+' anchor');const r=await invoke(options,helper.replace(from,to));assert.throws(()=>verify(r),assert.AssertionError,name+' must fail behavior');mutants.push({name,rejected:true});}
  const report={createdUtc:new Date().toISOString(),passed:tests.length,failed:0,mutantsRejected:mutants.length,
    scope:'Actual action helper and actual atom branch selector; SDK/fixture boundaries modeled. Native failure causality remains unproven.',
    inputs:[{path:testPath,sha256:sha(raw)},{path:atomPath,sha256:sha(atomRaw)}],control:{path:__filename,sha256:sha(fs.readFileSync(__filename))},baselineRed,tests,mutants};
  const output=arg('--json');if(output)fs.writeFileSync(path.resolve(output),JSON.stringify(report,null,2)+'\n',{flag:'wx'});
  console.log(JSON.stringify({passed:tests.length,failed:0,mutantsRejected:mutants.length}));
}
const guard=setTimeout(()=>{console.error('Native action controls did not settle');process.exit(1);},3000);
main().then(()=>clearTimeout(guard),error=>{clearTimeout(guard);console.error(error);process.exitCode=1;});

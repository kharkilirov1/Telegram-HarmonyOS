// Node >=24. Execute actual ETS source with explicit platform/transport boundaries.
// --source selects a frozen baseline or candidate; no source mutation is performed.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { createHash } = require('node:crypto');
const { stripTypeScriptTypes } = require('node:module');
const sourceArg = process.argv.find(arg => arg.startsWith('--source='));
const project = sourceArg ? path.resolve(sourceArg.slice(9)) : path.resolve(__dirname, '..');
const root = path.join(project, 'entry/src/main/ets');
const receipts = new Map();
const mutant=process.argv.find(arg=>arg.startsWith('--mutant='))?.slice(9);
const mutations=new Set();
const mutants={
 'message-route': ['core/model/dto/MessageDto.ets', "tdMessage.getTopLevelNumberStrict('chat_id')", "tdMessage.getNumber('chat_id')"],
 'failure-identity': ['core/reducers/messagesReducer.ets', 'chatMessages.set(failedMessage.id, failedMessage);', 'chatMessages.set(event.oldMessageId, failedMessage);'],
 'sending-state': ['core/model/dto/MessageDto.ets', 'applySendingState(messageDto, tdMessage, suppressErrorMessage);', ''],
 'parent406': ['core/events/normalizers/MessageNormalizer.ets', 'createMessageDtoFromTd(message, errorCode === 406)', 'createMessageDtoFromTd(message, false)'],
 'entry-reset-catch': ['entryability/EntryAbility.ets', "hilog.error(DOMAIN, TAG, 'Failed to initialize AppCoreRuntime: %{public}s', error.message);", "resetAppCoreRuntime();\n        hilog.error(DOMAIN, TAG, 'Failed to initialize AppCoreRuntime: %{public}s', error.message);"],
 'startup-no-error': ['app/bootstrap/AppCoreRuntime.ets', "failure.error = 'AppCore startup failed';", "failure.error = '';"],
 'profile-bio': ['domain/usecases/loadProfileInfo.ets', "tdGetString(tdGetObject(tdResponse, 'bio'), 'text')", "tdGetString(tdResponse, 'bio')"],
 'profile-context': ['domain/usecases/loadProfileInfo.ets', 'return this.store.isScopeCurrent();', 'return true;'],
 'member-aba': ['ui/pages/profile/TgProfileMembersPage.ets', 'generation === this.requestGeneration && this.chatId === chatId', 'this.chatId === chatId'],
 'member-auto-retry': ['ui/pages/profile/TgProfileMembersPage.ets', '(this.loadMoreFailed && !explicitRetry)', 'false'],
 'member-retry-reset': ['ui/pages/profile/TgProfileMembersPage.ets', 'this.loadMembers(this.rowCount === 0, true);', 'this.loadMembers(true, true);'],
 'member-raw-cursor': ['ui/pages/profile/TgProfileMembersPage.ets', 'this.nextOffset = offset + result.rawCount;', 'this.nextOffset = this.descriptors.length;'],
 'search-owner': ['ui/pages/chat/PendingChatSearchSignal.ets', 'PendingChatSearchSignal.accountStore !== accountStore ||', ''],
 'search-epoch': ['ui/pages/chat/PendingChatSearchSignal.ets', 'PendingChatSearchSignal.accountScope?.isScopeCurrent() !== true', 'false'],
 'search-clear-token': ['ui/pages/chat/PendingChatSearchSignal.ets', 'PendingChatSearchSignal.token !== token', 'false'],
 'search-route-owner': ['ui/pages/chat/ChatScreenViewEventHandlers.ets', 'route.accountStore === store && route.chatId === host.activeChatId && route.isCurrentAccount(store)', 'true'],
 'search-nearest': ['ui/pages/profile/TgProfilePage.ets', 'for (let index = names.length - 1; index >= 0; index--)', 'for (let index = 0; index < names.length; index++)'],
 'search-target-chat': ['ui/pages/profile/TgProfilePage.ets', 'route instanceof ChatScreenRouteParams && route.chatId === chatId &&', 'route instanceof ChatScreenRouteParams &&'],
 'lexical-cache': ['models/td/common/index.ets', 'return extractTopLevelInt64ValueStrict(this.rawJson, prop);', 'return this.getInt64String(prop);'],
 'lexical-rounding': ['core/model/dto/MessageDto.ets', 'const identity = tdMessage.getTopLevelInt64StringStrict(field);', 'const identity = tdMessage.getTopLevelNumberStrict(field)?.toString();'],
 'lexical-depth': ['models/td/common/index.ets', 'if (objectDepth === 1 && arrayDepth === 0)', 'if (objectDepth >= 1)', 'function extractTopLevelInt64ValueStrict('],
 'lexical-duplicate': ['models/td/common/index.ets', 'if (found) return undefined;', 'if (false) return undefined;']
};
assert.ok(!mutant||mutants[mutant],'named mutation required');
function read(relative) {
  let source = fs.readFileSync(path.join(root, relative), 'utf8');
  receipts.set(relative, createHash('sha256').update(source).digest('hex'));
  if(mutant&&mutants[mutant][0]===relative){
    const [,from,to,scope]=mutants[mutant];
    const start=scope?source.indexOf(scope):0;
    assert.ok(start>=0,'mutation function scope must engage '+mutant);
    const tail=source.slice(start);assert.ok(tail.includes(from),'mutation anchor must engage '+mutant);
    source=source.slice(0,start)+tail.replace(from,to);mutations.add(relative);
  }
  return source;
}
function load(relative, deps = {}, transform = source => source) {
  const source = transform(read(relative));
  const names = [...source.matchAll(/^export\s+(?:async\s+)?(?:class|function|enum|const)\s+(\w+)/gm)].map(match => match[1]);
  const declared=[...source.matchAll(/^(?:export\s+)?(?:async\s+)?(?:class|function|enum|const)\s+(\w+)/gm)].map(match=>match[1]);
  const injected=Object.fromEntries(Object.entries(deps).filter(([key])=>!declared.includes(key)));
  const code = source.replace(/^import[\s\S]*?;\s*/gm, '')
    .replace(/^export\s*\{[^}]*\};?\s*/gm, '').replace(/^export\s+/gm, '');
  return new Function(...Object.keys(injected), stripTypeScriptTypes(code, { mode: 'transform' }) + '\nreturn {' + names.join(',') + '};')(...Object.values(injected));
}
// Extract original page methods, including all request/ownership guards, verbatim.
// ArkUI builders are tested on SDK, not reimplemented by this host boundary.
function methods(relative, names, deps = {}) {
  const source = read(relative);
  const bodies = names.map(name => {
    const signature = new RegExp('^  (?:private |public |protected )?(?:async )?' + name + '\\(', 'm');
    const match = signature.exec(source);
    assert.ok(match, `actual method ${relative}:${name} must exist`);
    const end = source.indexOf('\n  }', match.index);
    assert.ok(end > match.index, `actual method ${name} must have a closing boundary`);
    return source.slice(match.index, end + 4).replace(/^  (?:private |public |protected )?/, '  ');
  });
  return new Function(...Object.keys(deps), stripTypeScriptTypes('class ActualPage {\n' + bodies.join('\n') + '\n}\n', { mode: 'transform' }) + '\nreturn ActualPage;')(...Object.values(deps));
}
const tick = () => new Promise(resolve => setImmediate(resolve));
function deferred() { let resolve, reject; const promise = new Promise((a,b) => { resolve=a; reject=b; }); return {promise,resolve,reject}; }
async function run(suite, tests) {
  const results = [];
  for (const [name, callback] of tests) {
    let deadline;
    try {
      await Promise.race([callback(),new Promise((_resolve,reject)=>{deadline=setTimeout(()=>reject(new Error('Unsettled test callback: '+name)),5000);})]);
      results.push({name, pass:true}); console.log('PASS ' + name);
    }
    catch (error) {
      if (error.code !== 'ERR_ASSERTION') throw error;
      results.push({name,pass:false,code:error.code,message:error.message});
      console.log('ASSERTION RED ' + name + ' :: ' + error.message);
    }
    finally { if(deadline)clearTimeout(deadline); }
  }
  const failed = results.filter(result => !result.pass).length;
  if(mutant)assert.ok(mutations.size>0,'behavioral mutation must activate actual loaded source');
  const evidence = {suite,project,sourceHashes:Object.fromEntries(receipts),mutant,mutatedFiles:[...mutations],tests:results.length,passed:results.length-failed,failed,results};
  console.log(JSON.stringify(evidence));
  const output = process.argv.find(arg => arg.startsWith('--receipt='));
  if (output) fs.writeFileSync(path.resolve(output.slice(10)), JSON.stringify(evidence,null,2)+'\n',{flag:'wx'});
  if (failed && !process.argv.includes('--expect-red')) process.exitCode=1;
  if (process.argv.includes('--expect-red')) assert.ok(failed>0,'a baseline RED run must reproduce a correct assertion failure');
  return evidence;
}
module.exports = {assert,project,root,read,load,methods,tick,deferred,run};

// Node >=24. Actual PendingForwardTransfer model, no platform/network boundaries.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
const file = path.resolve(__dirname, '../entry/src/main/ets/ui/pages/chat/PendingForwardTransfer.ets');
const source = fs.readFileSync(file, 'utf8');
const hash = s => createHash('sha256').update(s).digest('hex');
const createStore = new Function(stripTypeScriptTypes(source.replace(/^export\s+/gm, ''), {mode:'transform'}) + '\nreturn new PendingForwardTransferStore();');
const tests = [];
const test = (name, run) => tests.push({name, run});
const arm = (s, token=11) => s.arm(7, 8, ['101'], 'A', 'preview', token);
test('matching route consumes its cloned payload once', () => {
  const s=createStore(); const ids=['101']; s.arm(7,8,ids,'A','preview',11); ids.push('102');
  const result=s.consumeFor(7,11); assert.deepEqual(result.messageIds,['101']); assert.equal(result.navigationToken,11); assert.equal(s.consumeFor(7,11),undefined);
});
test('another route with same chat cannot consume', () => {
  const s=createStore(); arm(s); assert.equal(s.consumeFor(7,12),undefined); assert.ok(s.consumeFor(7,11));
});
test('route-less legacy consumer cannot consume a bound payload', () => {
  const s=createStore(); arm(s); assert.equal(s.consumeFor(7),undefined); assert.ok(s.consumeFor(7,11));
});
test('old failed push cannot clear replacement transfer', () => {
  const s=createStore(); arm(s,12); s.clear(11); assert.ok(s.consumeFor(7,12));
});
test('matching clear consumes only its own slot', () => {
  const s=createStore(); arm(s); s.clear(11); assert.equal(s.consumeFor(7,11),undefined);
});
test('invalid old arm cannot clear another route', () => {
  const s=createStore(); arm(s,12); s.arm(0,8,[],'','',11); assert.ok(s.consumeFor(7,12));
});
test('invalid navigation token never creates a consumable payload', () => {
  for(const token of [NaN,Infinity,-1,1.5]) { const s=createStore(); arm(s,token); assert.equal(s.consumeFor(7,token),undefined); }
});
test('unbound legacy helper flow remains explicit token zero', () => {
  const s=createStore(); s.arm(7,8,['101'],'A','preview'); assert.ok(s.consumeFor(7)); assert.equal(s.consumeFor(7),undefined);
});
test('wrong chat and wrong route leave the owned payload intact', () => {
  const s=createStore(); arm(s); assert.equal(s.consumeFor(9,11),undefined); assert.equal(s.hasPendingFor(7,12),false); assert.ok(s.consumeFor(7,11));
});
let failed=0;
for(const {name,run} of tests) {try{run();console.log('PASS',name);}catch(e){failed++;console.error('FAIL',name,e.message);}}
assert.equal(hash(fs.readFileSync(file,'utf8')),hash(source),'source stable during run');
console.log(JSON.stringify({passed:tests.length-failed,failed,sources:{[file]:hash(source)}}));
process.exitCode=failed?1:0;

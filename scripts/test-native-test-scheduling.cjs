// Node >=24; SDK-free test of the real native suite registry and its scheduling hook.
// The external boundary models OHOS timers: newly scheduled zero-delay callbacks
// can run inside the current uv_timer_task. Positive timers need a later turn.
// This checks our registration/wait contract, not native EventHandler fairness.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
const projectArg = process.argv.find(arg => arg.startsWith('--source='));
const project = projectArg ? path.resolve(projectArg.slice(9)) : path.resolve(__dirname, '..');
const sourcePath = path.join(project, 'entry/src/ohosTest/ets/test/List.test.ets');
const source = fs.readFileSync(sourcePath, 'utf8');
const mutant = process.argv.find(arg => arg.startsWith('--mutant='))?.slice(9);
const mutations = {
  'removed-hook': ['  beforeEachIt(async () => {\n    await new Promise<void>((resolve) => { setTimeout(resolve, 16); });\n  });', ''],
  'non-inherited-hook': ['beforeEachIt(async', 'beforeEach(async'],
  'zero-delay': ['setTimeout(resolve, 16)', 'setTimeout(resolve, 0)'],
  'unawaited-timer': ['await new Promise<void>', 'new Promise<void>'],
  'resolved-promise': ['await new Promise<void>((resolve) => { setTimeout(resolve, 16); });', 'await Promise.resolve();']
};
let testedSource = source.replace(/\r\n/g, '\n');
if (mutant) {
  assert.ok(mutations[mutant], 'known mutation is required');
  const [from, to] = mutations[mutant];
  assert.ok(testedSource.includes(from), 'mutation must engage actual loaded source: ' + mutant);
  testedSource = testedSource.replace(from, to);
}

async function main() {
  const suiteNames = [...source.matchAll(/^import (\w+) from ['"]\.\//gm)].map(match => match[1]);
  assert.ok(suiteNames.length > 0, 'read the real nonempty suite registry');
  const calledSuites = [];
  const hooks = [];
  const localHooks = [];
  const pendingTimers = [];
  let time = 0;
  let sequence = 0;
  const injected = {
    beforeEachIt: callback => hooks.push(callback),
    beforeEach: callback => localHooks.push(callback),
    setTimeout: (callback, delay = 0) => {
      const timer = { callback, due: time + Math.max(0, delay), id: ++sequence };
      pendingTimers.push(timer);
      return timer.id;
    }
  };
  for (const name of suiteNames) injected[name] = () => calledSuites.push(name);
  const code = testedSource.replace(/^import[^;]+;\s*/gm, '').replace('export default function', 'function');
  const registry = new Function(...Object.keys(injected),
    stripTypeScriptTypes(code, { mode: 'transform' }) + '\nreturn testsuite;')(...Object.values(injected));
  registry();
  assert.deepEqual([...calledSuites].sort(), [...suiteNames].sort(),
    'pacing must retain every imported suite exactly once');
  assert.equal(hooks.length, 1, 'every nested suite needs one inherited beforeEachIt hook');
  assert.equal(localHooks.length, 0, 'root-only beforeEach cannot pace child suites');

  // Flush JS continuations without treating Node's own turn as a modeled OHOS turn.
  const flushPromises = () => new Promise(resolve => setImmediate(resolve));
  async function drainCurrentTimerTurn() {
    await flushPromises();
    for (let safety = 0; safety < 20; safety++) {
      const next = pendingTimers.findIndex(timer => timer.due <= time);
      if (next < 0) return;
      pendingTimers.splice(next, 1)[0].callback();
      await flushPromises();
    }
    assert.fail('test hook created an unbounded due-timer chain');
  }

  // Reuse the actual callback for consecutive cases. A positive timer must keep
  // each body pending until the simulated platform gets another event opportunity.
  const order = [];
  for (let index = 0; index < 3; index++) {
    let bodyRan = false;
    const pending = hooks[0]().then(() => { bodyRan = true; order.push('case-' + index); });
    await drainCurrentTimerTurn();
    assert.equal(bodyRan, false, 'case body resumed inside the same timer turn');
    assert.equal(pendingTimers.length, 1, 'one pending future timer must own the wait');
    assert.ok(pendingTimers[0].due > time, 'the timer must be due in a later turn');
    order.push('platform-' + index);
    time = pendingTimers[0].due;
    await drainCurrentTimerTurn();
    await pending;
    assert.equal(bodyRan, true, 'a later turn must release the case body');
    assert.equal(pendingTimers.length, 0, 'the completed hook must not leak timers');
  }
  assert.deepEqual(order, ['platform-0', 'case-0', 'platform-1', 'case-1', 'platform-2', 'case-2']);
  console.log(JSON.stringify({ suite: 'native-test-scheduling', passed: true, registeredSuites: calledSuites.length,
    cases: 3, sourceSha256: createHash('sha256').update(source).digest('hex'), mutant: mutant ?? null }));
}
let deadline;
Promise.race([main(), new Promise((resolve, reject) => {
  deadline = setTimeout(() => reject(new Error('Native scheduling regression did not settle')), 3000);
})]).catch(error => { console.error(error); process.exitCode = 1; })
  .finally(() => clearTimeout(deadline));

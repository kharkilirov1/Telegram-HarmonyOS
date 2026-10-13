// Execute the real pure coordinator and native pressure callback. The clock
// models a delayed first timer turn, not native wall-clock performance.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { stripTypeScriptTypes } = require('node:module');
const rootArg = process.argv.find(arg => arg.startsWith('--source='));
const root = rootArg ? path.resolve(rootArg.slice(9)) : path.resolve(__dirname, '..');
const testPath = 'entry/src/ohosTest/ets/test/SharedMediaThumbnailCoordinator.test.ets';
const productionPath = 'entry/src/main/ets/ui/pages/profile/SharedMediaThumbnailCoordinator.ets';
const originalTest = fs.readFileSync(path.join(root, testPath), 'utf8');
const originalProduction = fs.readFileSync(path.join(root, productionPath), 'utf8');
const compile = text => stripTypeScriptTypes(text.replace(/^import[\s\S]*?;\s*/gm, '')
  .replace('export default function', 'function').replace(/^export\s+/gm, ''), { mode: 'transform' });
const name = 'keeps TDLib thumbnail pressure within the configured bound';

async function execute(testSource, productionSource, stall) {
  const Coordinator = new Function(compile(productionSource) + '; return SharedMediaThumbnailCoordinator;')();
  const specs = []; const assertions = []; const timers = []; let now = 0; let timerCount = 0;
  const expect = actual => ({ assertEqual(expected) {
    assertions.push([actual, expected]); assert.equal(actual, expected);
  } });
  const timeout = (run, delay) => { timers.push({ run, due: now + delay, id: ++timerCount }); return timerCount; };
  new Function('describe', 'it', 'expect', 'setTimeout', 'SharedMediaThumbnailCoordinator',
    compile(testSource) + '; sharedMediaThumbnailCoordinatorTest();')(
    (_name, run) => run(), (title, flags, run) => { assert.equal(flags, 0); specs.push({ title, run }); },
    expect, timeout, Coordinator);
  assert.equal(specs.length, 5, 'all original native cases remain registered');
  const selected = specs.filter(spec => spec.title === name);
  assert.equal(selected.length, 1, 'execute the real pressure case');
  let done = false; let failure;
  Promise.resolve().then(selected[0].run).then(() => { done = true; }, error => { failure = error; done = true; });
  let first = true;
  for (let turn = 0; turn < 30 && !done; turn++) {
    await new Promise(resolve => setImmediate(resolve));
    if (done) break;
    assert.ok(timers.length > 0, 'pressure callback must settle after controlled completions');
    timers.sort((a, b) => a.due - b.due || a.id - b.id);
    const timer = timers.shift();
    now = Math.max(now, timer.due, first && stall ? 100 : 0); first = false;
    timer.run();
  }
  if (failure) {
    failure.assertionTrace = assertions;
    failure.timerScenario = stall ? 'first timer turn delayed to 100ms' : 'on-time timers';
    throw failure;
  }
  assert.equal(done, true, 'pressure callback completes');
  assert.ok(assertions.some(([actual, expected]) => actual === 2 && expected === 2), 'retain the exact bound assertion');
  assert.ok(assertions.some(([actual, expected]) => actual === 'file://14' && expected === 'file://14'), 'retain the last URI assertion');
  return { assertions: assertions.length, timerCount, modeledClock: now, trace: assertions };
}

require('./host-test-completion.cjs').guardSuite((async () => {
  const normal = await execute(originalTest, originalProduction, false);
  const delayed = await execute(originalTest, originalProduction, true);
  const contract = [[2, 2], ['11,12', '11,12'], [2, 2], ['11,12,13', '11,12,13'],
    [2, 2], ['11,12,13,14', '11,12,13,14'], [0, 0], [2, 2], ['file://14', 'file://14']];
  assert.deepEqual(normal.trace, contract, 'retain slot replacement, drain, exact peak and publication assertions');
  assert.deepEqual(delayed.trace, contract, 'delayed scheduling must check the same contract');
  const mutations = [
    ['exceeds-bound', 'this.activeCount < this.maxConcurrent', 'this.activeCount <= this.maxConcurrent'],
    ['drops-publication', 'request.targets[i].thumbUri = uri;', '/* broken publication */'],
    ['serializes-everything', 'this.maxConcurrent = Math.max(1, Math.floor(maxConcurrent));', 'this.maxConcurrent = 1;']
  ];
  for (const [label, from, to] of mutations) {
    assert.ok(originalProduction.includes(from), 'production mutation engages: ' + label);
    await assert.rejects(execute(originalTest, originalProduction.replace(from, to), true),
      { code: 'ERR_ASSERTION' }, 'the unchanged contract must detect ' + label);
  }
  console.log(JSON.stringify({ passed: true, normal, delayed, negativeControls: mutations.map(row => row[0]) }));
})()).catch(error => { console.error(error); process.exitCode = 1; });

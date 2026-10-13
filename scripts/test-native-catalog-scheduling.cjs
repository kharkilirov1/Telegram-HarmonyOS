// Execute the real SDK callback and complete catalog. Model the OHOS timer
// boundary: newly queued zero-delay timers can remain in the same uv_timer_task.
// This checks bounded assertion batches, not native EventHandler fairness.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
const argv = process.argv.slice(2);
const value = key => argv[argv.indexOf(key) + 1];
const root = argv.includes('--baseline-dir') ? path.resolve(value('--baseline-dir')) : path.resolve(__dirname, '..');
const testPath = 'entry/src/ohosTest/ets/test/TgUnicodeEmojiCatalog.test.ets';
const dataPath = 'entry/src/main/ets/ui/tg_ui/data/TgUnicodeEmojiCatalog.ets';
function loadCatalog() {
  const text = fs.readFileSync(path.join(root, dataPath), 'utf8').replace(/^export\s+/gm, '');
  return new Function(stripTypeScriptTypes(text, { mode: 'transform' }) + '; return {UNICODE_EMOJI_CATEGORIES,UNICODE_EMOJI_COUNT,UNICODE_EMOJI_VERSION};')();
}
const catalog = loadCatalog();
const original = fs.readFileSync(path.join(root, testPath), 'utf8');
async function execute(text) {
  const tests = []; const trace = []; let current = ''; let inside = false; let scheduledYields = 0;
  const timers = []; let clock = 0; let futureTurns = 0;
  let assertionsAtTurn = 0; let maxAssertionsInTurn = 0;
  const expectation = actual => ({
    assertEqual(expected) { trace.push([current, 'equal', actual, expected]); assert.equal(actual, expected); },
    assertTrue() { trace.push([current, 'true', actual]); assert.equal(actual, true); },
    assertFalse() { trace.push([current, 'false', actual]); assert.equal(actual, false); }
  });
  const js = stripTypeScriptTypes(text.replace(/^import[\s\S]*?;\s*/gm, '').replace('export default function', 'function'), { mode: 'transform' });
  new Function('describe', 'it', 'expect', 'setTimeout', ...Object.keys(catalog), js + ';tgUnicodeEmojiCatalogTest();')(
    (name, run) => { assert.equal(name, 'TgUnicodeEmojiCatalog'); run(); },
    (name, flags, run) => { assert.equal(flags, 0); tests.push({ name, run }); }, expectation,
    (run, ms) => {
      assert.ok(Number.isFinite(ms) && ms >= 0, 'valid timer delay');
      if (inside) scheduledYields++;
      timers.push({ run, due: clock + ms });
      return timers.length;
    }, ...Object.values(catalog));
  async function runWithTimerBoundary(run) {
    let done = false; let failure;
    Promise.resolve().then(run).then(() => { done = true; }, error => { done = true; failure = error; });
    // Flush JS continuations without counting Node's own turn as an OHOS turn.
    const flush = () => new Promise(resolve => setImmediate(resolve));
    for (let guard = 0; guard < 100 && !done; guard++) {
      await flush();
      if (done) break;
      assert.ok(timers.length > 0, 'catalog callback must settle or await its timer');
      timers.sort((a, b) => a.due - b.due);
      const timer = timers.shift();
      if (timer.due > clock) {
        if (inside) {
          futureTurns++;
          maxAssertionsInTurn = Math.max(maxAssertionsInTurn, trace.length - assertionsAtTurn);
          assertionsAtTurn = trace.length;
        }
        clock = timer.due;
      }
      timer.run();
    }
    assert.equal(done, true, 'catalog callback must finish with bounded scheduling');
    if (failure) throw failure;
    assert.equal(timers.length, 0, 'catalog callback must not leak timers');
  }
  let neutralTrace = []; let fair = false;
  for (const spec of tests) {
    current = spec.name; const start = trace.length;
    const neutral = current === 'contains the complete neutral base catalog without skin-tone duplicates';
    inside = neutral; assertionsAtTurn = trace.length;
    await runWithTimerBoundary(spec.run);
    if (neutral) {
      maxAssertionsInTurn = Math.max(maxAssertionsInTurn, trace.length - assertionsAtTurn);
      fair = futureTurns > 0; neutralTrace = trace.slice(start);
    }
    inside = false;
  }
  assert.equal(tests.length, 3);
  assert.deepEqual(tests.map(t => t.name), ['keeps the nine CLDR keyboard groups in Telegram order',
    'contains the complete neutral base catalog without skin-tone duplicates', 'does not collapse people gestures or flags to a sample row']);
  const count = catalog.UNICODE_EMOJI_CATEGORIES.reduce((sum, category) => sum + category.emojis.length, 0);
  assert.equal(count, catalog.UNICODE_EMOJI_COUNT); assert.equal(count, 1914);
  assert.equal(neutralTrace.length, count * 5 + 2, 'all9570 skin-tone and2 final count assertions remain');
  assert(neutralTrace.slice(0, count * 5).every(row => row[1] === 'false' && row[2] === false));
  assert.deepEqual(neutralTrace.slice(-2).map(row => row.slice(1)), [['equal', count, count], ['true', true]]);
  return { fair, scheduledYields, futureTurns, maxAssertionsInTurn, callbacks: tests.length, assertions: trace.length,
    neutralAssertions: neutralTrace.length, assertionTraceSha256: createHash('sha256').update(JSON.stringify(trace)).digest('hex') };
}
require('./host-test-completion.cjs').guardSuite((async () => {
  const result = await execute(original);
  if (argv.includes('--expect-red')) {
    assert.equal(result.fair, false, 'baseline must fail the event-loop fairness contract');
    assert.equal(result.futureTurns, 0);
    assert.equal(result.maxAssertionsInTurn, result.neutralAssertions);
    console.log(JSON.stringify({ baselineRed: true, ...result }));
  } else {
    assert.equal(result.fair, true, 'the heavy callback needs a future timer turn before completing');
    assert(result.maxAssertionsInTurn <= 640, 'no timer turn may retain more than 128 emoji checks');
    assert(result.scheduledYields >= 14 && result.scheduledYields <= 30, 'bounded complete-catalog batches');
    const yieldLine = 'await new Promise<void>((resolve) => { setTimeout(() => resolve(), 16); });';
    assert.equal(original.split(yieldLine).length - 1, 1);
    for (const replacement of ['', 'await Promise.resolve();', yieldLine.replace(', 16)', ', 0)')]) {
      const mutant = await execute(original.replace(yieldLine, replacement));
      assert.equal(mutant.fair, false, 'missing, microtask-only and zero-delay yields must retain one timer turn');
      assert.equal(mutant.maxAssertionsInTurn, mutant.neutralAssertions);
      assert.equal(mutant.assertionTraceSha256, result.assertionTraceSha256, 'negative controls preserve every assertion and order');
    }
    console.log(JSON.stringify({ green: true, negativeControls: 3, ...result }));
  }
})()).catch(error => { console.error(error); process.exitCode = 1; });

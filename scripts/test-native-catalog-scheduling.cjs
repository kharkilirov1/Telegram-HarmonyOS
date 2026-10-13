// Execute the real SDK callback and complete catalog. Verify event-loop fairness
// without replacing, sampling, or dropping any existing catalog assertions.
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
  const expectation = actual => ({
    assertEqual(expected) { trace.push([current, 'equal', actual, expected]); assert.equal(actual, expected); },
    assertTrue() { trace.push([current, 'true', actual]); assert.equal(actual, true); },
    assertFalse() { trace.push([current, 'false', actual]); assert.equal(actual, false); }
  });
  const js = stripTypeScriptTypes(text.replace(/^import[\s\S]*?;\s*/gm, '').replace('export default function', 'function'), { mode: 'transform' });
  new Function('describe', 'it', 'expect', 'setTimeout', ...Object.keys(catalog), js + ';tgUnicodeEmojiCatalogTest();')(
    (name, run) => { assert.equal(name, 'TgUnicodeEmojiCatalog'); run(); },
    (name, flags, run) => { assert.equal(flags, 0); tests.push({ name, run }); }, expectation,
    (run, ms) => { assert.equal(ms, 0); if (inside) scheduledYields++; return setTimeout(run, ms); }, ...Object.values(catalog));
  let neutralTrace = []; let fair = false;
  for (const spec of tests) {
    current = spec.name; const start = trace.length;
    const neutral = current === 'contains the complete neutral base catalog without skin-tone duplicates';
    let observed = false;
    const probe = neutral ? new Promise(resolve => setTimeout(() => { observed = inside; resolve(); }, 0)) : Promise.resolve();
    inside = neutral; await spec.run(); inside = false; await probe;
    if (neutral) { fair = observed; neutralTrace = trace.slice(start); }
  }
  assert.equal(tests.length, 3);
  assert.deepEqual(tests.map(t => t.name), ['keeps the nine CLDR keyboard groups in Telegram order',
    'contains the complete neutral base catalog without skin-tone duplicates', 'does not collapse people gestures or flags to a sample row']);
  const count = catalog.UNICODE_EMOJI_CATEGORIES.reduce((sum, category) => sum + category.emojis.length, 0);
  assert.equal(count, catalog.UNICODE_EMOJI_COUNT); assert.equal(count, 1914);
  assert.equal(neutralTrace.length, count * 5 + 2, 'all9570 skin-tone and2 final count assertions remain');
  assert(neutralTrace.slice(0, count * 5).every(row => row[1] === 'false' && row[2] === false));
  assert.deepEqual(neutralTrace.slice(-2).map(row => row.slice(1)), [['equal', count, count], ['true', true]]);
  return { fair, scheduledYields, callbacks: tests.length, assertions: trace.length,
    neutralAssertions: neutralTrace.length, assertionTraceSha256: createHash('sha256').update(JSON.stringify(trace)).digest('hex') };
}
require('./host-test-completion.cjs').guardSuite((async () => {
  const result = await execute(original);
  if (argv.includes('--expect-red')) {
    assert.equal(result.fair, false, 'baseline must fail the event-loop fairness contract');
    assert.equal(result.scheduledYields, 0);
    console.log(JSON.stringify({ baselineRed: true, preservedAssertions: result.neutralAssertions, callbacks: result.callbacks }));
  } else {
    assert.equal(result.fair, true, 'a native event-loop turn must happen before the heavy callback completes');
    assert(result.scheduledYields >= 14 && result.scheduledYields <= 30, 'bounded complete-catalog batches');
    const yieldLine = 'await new Promise<void>((resolve) => { setTimeout(() => resolve(), 0); });';
    assert.equal(original.split(yieldLine).length - 1, 1);
    for (const replacement of ['', 'await Promise.resolve();']) {
      const mutant = await execute(original.replace(yieldLine, replacement));
      assert.equal(mutant.fair, false, 'no-yield and microtask-only mutations must lose native fairness');
      assert.equal(mutant.assertionTraceSha256, result.assertionTraceSha256, 'negative controls preserve every assertion and order');
    }
    console.log(JSON.stringify({ green: true, negativeControls: 2, ...result }));
  }
})()).catch(error => { console.error(error); process.exitCode = 1; });

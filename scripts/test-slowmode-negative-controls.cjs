// In-memory production mutations. A control counts only if its source branch
// was activated and the actual callback bodies fail by behavior assertions.
const assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), os = require('node:os');
const { spawnSync } = require('node:child_process');
const names = ['dispatch-gate', 'zero-boost-threshold', 'fractional-floor', 'receipt-reanchor',
  'disable-invalidation', 'missing-enabled-bit', 'normalizer-metadata', 'photo-await-gate',
  'sequential-await-gate', 'text-dialog-gate', 'owner-timer-cleanup', 'hydration-ABA-refresh', 'atom-gesture-gate'];
const results = [], args = process.argv.slice(2);
for (const name of names) {
  const receipt = path.join(os.tmpdir(), 'tg-slowmode-mutant-' + process.pid + '-' + name + '.json');
  const run = spawnSync(process.execPath, ['--disable-warning=ExperimentalWarning', path.join(__dirname, 'test-slowmode.cjs'),
    '--mutant', name, '--expect-red', '--json', receipt], { encoding: 'utf8', timeout: 15000 });
  assert.equal(run.status, 0, name + ': control did not reach assertion RED\n' + run.stdout + run.stderr);
  const value = JSON.parse(fs.readFileSync(receipt, 'utf8')); fs.unlinkSync(receipt);
  assert.ok(value.activatedMutations.length > 0, name + ': no activated actual route');
  assert.ok(value.failed > 0 && value.failed === value.assertionFailures, name + ': behavioral assertions required');
  results.push({ name, activated: value.activatedMutations, passed: value.passed, assertionFailures: value.assertionFailures,
    rejectedBy: value.failures.map(x => x.name), hashes: value.hashes });
}
const voiceReceipt = path.join(os.tmpdir(), 'tg-slowmode-voice-mutant-' + process.pid + '.json');
const voiceRun = spawnSync(process.execPath, ['--disable-warning=ExperimentalWarning', path.join(__dirname, 'test-slowmode-voice.cjs'),
  '--mutant-preview-discard', '--expect-red', '--json', voiceReceipt], { encoding: 'utf8', timeout: 15000 });
assert.equal(voiceRun.status, 0, 'Voice preview mutation must reach behavior RED: ' + voiceRun.stdout + voiceRun.stderr);
const voice = JSON.parse(fs.readFileSync(voiceReceipt, 'utf8')); fs.unlinkSync(voiceReceipt);
assert.ok(voice.activatedMutant && voice.failed > 0 && voice.failed === voice.assertionFailures);
results.push({ name: 'voice-preview-discard', activated: true, assertionFailures: voice.assertionFailures, rejectedBy: voice.failures.map(x => x.name), sha256: voice.sha256 });
const summary = { controls: results.length, rejected: results.length, survived: 0, errors: 0, results };
if (args.includes('--json')) fs.writeFileSync(path.resolve(args[args.indexOf('--json') + 1]), JSON.stringify(summary, null, 2) + '\n');
console.log(JSON.stringify({ controls: results.length, rejected: results.length, survived: 0, errors: 0 }));

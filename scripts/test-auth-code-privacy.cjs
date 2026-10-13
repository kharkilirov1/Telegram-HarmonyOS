// Node >= 24. Invoke actual LoginController.checkCode with actual AppCommand.
// Synthetic input only; gateway/log sinks are captured, never a live login/session.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const root = path.resolve(__dirname, '../entry/src/main/ets');
function load(relative, names, deps = {}) {
  const source = fs.readFileSync(path.join(root, relative), 'utf8')
    .replace(/^import\s[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, '');
  const js = stripTypeScriptTypes(source, { mode: 'transform', sourceUrl: relative });
  return new Function(...Object.keys(deps), `${js}\nreturn {${names.join(',')}};`)(...Object.values(deps));
}
const commands = load('core/model/AppCommand.ets', ['createCheckAuthCodeCommand', 'CheckAuthCodeCommand']);
function fixture(error) {
  const logs = [], sent = [];
  const hilog = Object.fromEntries(['info', 'warn', 'error', 'debug', 'fatal'].map(level =>
    [level, (...args) => { logs.push({ level, args }); }]));
  const consoleSink = Object.fromEntries(['log', 'info', 'warn', 'error', 'debug'].map(level =>
    [level, (...args) => { logs.push({ level: `console.${level}`, args }); }]));
  let adapterReads = 0;
  const controller = load('ui/controllers/LoginController.ets',
    ['LoginController', 'CheckCodeSuccess', 'CheckCodeFailure', 'LoginError'], {
      ...commands, hilog, console: consoleSink,
      getTdGatewayAdapter: () => {
        adapterReads++;
        return { send: async command => { sent.push(command); if (error) throw error; } };
      }
    });
  return { ...controller, logs, sent, reads: () => adapterReads };
}
function checkSubmission(f, code) {
  assert.equal(f.reads(), 1, 'one current adapter per submit');
  assert.equal(f.sent.length, 1, 'no duplicated auth send');
  assert.ok(f.sent[0] instanceof commands.CheckAuthCodeCommand);
  assert.equal(f.sent[0].type, 'checkAuthCode');
  assert.equal(f.sent[0].payload.code, code, 'exact synthetic code is sent, not redacted/truncated');
}
function checkPrivacy(f, code) {
  // Inspect raw arguments BEFORE platform public/private masking; never print them.
  const text = JSON.stringify(f.logs);
  assert.ok(!text.includes(code), 'submitted credential must never enter any log sink');
  if (code.length >= 2) {
    assert.ok(!text.includes(code.slice(0, 2)), 'credential prefix must never enter any log sink');
  }
  assert.ok(f.logs.every(entry => entry.args.length === 3),
    'auth logs must not receive credential, masked prefix, length or raw error as variadic arguments');
}
const tests = [];
const test = (name, run) => tests.push([name, run]);
for (const [name, code] of [
  ['numeric', '12345'], ['leading-zero', '098765'], ['one-character', '7'],
  ['word', 'synthetic-otp-word'], ['phrase', 'synthetic auth phrase']
]) {
  test(`${name} submit preserves success/payload and logs no credential material`, async () => {
    const f = fixture();
    const result = await f.LoginController.getInstance().checkCode(code);
    checkSubmission(f, code);
    assert.ok(result instanceof f.CheckCodeSuccess);
    assert.equal(result.success, true);
    assert.equal(result.nextStep, 'ready');
    checkPrivacy(f, code);
  });
}
for (const [name, message, expectedCode, retryAfter] of [
  ['invalid echoed OTP', 'PHONE_CODE_INVALID code: 400; synthetic submitted=12345', 'CODE_INVALID', 0],
  ['expired', 'PHONE_CODE_EXPIRED code: 400', 'CODE_EXPIRED', 0],
  ['rate limit', 'FLOOD_WAIT_30 code: 403', 'FLOOD_WAIT', 30],
  ['network echoed OTP', 'NETWORK_TIMEOUT synthetic submitted=12345', 'NETWORK_ERROR', 0],
  ['unknown echoed OTP', 'synthetic rejected value=12345', 'UNKNOWN', 0]
]) {
  test(`${name}: failure result preserved without logging error/OTP`, async () => {
    const f = fixture(new Error(message));
    const result = await f.LoginController.getInstance().checkCode('12345');
    checkSubmission(f, '12345');
    assert.ok(result instanceof f.CheckCodeFailure);
    assert.ok(result.error instanceof f.LoginError);
    assert.equal(result.success, false);
    assert.equal(result.error.code, expectedCode);
    assert.equal(result.error.retryAfter, retryAfter);
    checkPrivacy(f, '12345');
    assert.ok(!JSON.stringify(f.logs).includes(message), 'raw exception must not enter logs');
  });
}
test('successful logs do not depend on OTP value or length', async () => {
  const a = fixture(), b = fixture();
  await a.LoginController.getInstance().checkCode('12345');
  await b.LoginController.getInstance().checkCode('0987654321');
  assert.ok(JSON.stringify(a.logs) === JSON.stringify(b.logs), 'logs must be independent of credential material');
});
async function main() {
  let passed = 0;
  for (const [name, run] of tests) {
    try { await run(); passed++; console.log(`PASS ${name}`); }
    catch (error) { console.error(`FAIL ${name}\n${error.stack}`); }
  }
  console.log(`${passed}/${tests.length} PASS; ${tests.length - passed} FAIL (production login submit, synthetic-only)`);
  if (passed !== tests.length) process.exitCode = 1;
}
let finished = false;
process.on('beforeExit', () => {
  if (!finished) { console.error('FAIL incomplete test run'); process.exitCode = 1; }
});
main().then(() => { finished = true; }).catch(error => {
  finished = true; console.error(error); process.exitCode = 1;
});

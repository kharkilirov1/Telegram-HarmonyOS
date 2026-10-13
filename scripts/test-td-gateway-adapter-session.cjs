// Node >=24. Actual adapter; gateway and command serialization are explicit test boundaries.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const root = path.resolve(__dirname, '../entry/src/main/ets');
function load(relative, deps = {}) {
  const source = fs.readFileSync(path.join(root, relative), 'utf8');
  const names = [...source.matchAll(/^export\s+(?:async\s+)?(?:class|function|enum|const)\s+(\w+)/gm)].map(m => m[1]);
  const js = stripTypeScriptTypes(source.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, ''), { mode: 'transform' });
  return new Function(...Object.keys(deps), `${js}\nreturn {${names.join(',')}};`)(...Object.values(deps));
}
const appErrors = load('core/model/AppError.ets');
const port = load('domain/ports/TdGatewayPort.ets', appErrors);
function fixture() {
  let generation = 0;
  const pending = [];
  const gateway = { getClientGeneration: () => generation, isReady: () => true,
    getState: () => 'ready', isDrainCongested: () => false,
    send: () => new Promise((resolve, reject) => pending.push({ resolve, reject })) };
  const adapterModule = load('infra/td/adapter/TdGatewayAdapter.ets', { ...appErrors, ...port,
    getTdGateway: () => gateway,
    serializeCommand: () => ({ method: 'getMe', params: {} }),
    hilog: { info() {}, warn() {}, error() {} }
  });
  return { ...adapterModule, pending, close: () => generation++ };
}
async function main() {
  const tests = [
    ['stale adapter cannot send commands to the new account', async () => {
      const f = fixture();
      const old = f.getTdGatewayAdapter();
      f.close();
      const result = old.send({}).then(() => 'resolved', error => error.code);
      await Promise.resolve();
      assert.equal(f.pending.length, 0, 'no native send after generation change');
      assert.equal(await result, port.GatewayErrorCode.NOT_INITIALIZED);
    }],
    ['getter rotates adapter while old references stay fenced', async () => {
      const f = fixture();
      const old = f.getTdGatewayAdapter();
      assert.equal(f.getTdGatewayAdapter(), old);
      f.close();
      const current = f.getTdGatewayAdapter();
      assert.notEqual(current, old);
      const result = current.send({});
      assert.equal(f.pending.length, 1);
      f.pending[0].resolve('new-account-response');
      assert.equal(await result, 'new-account-response');
    }],
    ['late resolved response from old account is not exposed to caller', async () => {
      const f = fixture();
      const result = f.getTdGatewayAdapter().send({}).then(() => 'resolved', error => error.code);
      assert.equal(f.pending.length, 1);
      f.close();
      f.pending[0].resolve('old-account-response');
      assert.equal(await result, port.GatewayErrorCode.NOT_INITIALIZED);
    }],
    ['current generation responses keep the normal path', async () => {
      const f = fixture();
      const result = f.getTdGatewayAdapter().send({});
      assert.equal(f.pending.length, 1);
      f.pending[0].resolve('current');
      assert.equal(await result, 'current');
    }]
  ];
  let failed = 0;
  for (const [name, run] of tests) {
    try { await run(); console.log('PASS', name); }
    catch (error) { if (error.code !== 'ERR_ASSERTION') throw error; failed++; console.log('FAIL', name, error.message); }
  }
  console.log(`${tests.length - failed}/${tests.length} PASS`);
  process.exitCode = failed ? 1 : 0;
}
require('./host-test-completion.cjs').guardSuite(main()).catch(error => { console.error('HARNESS_ERROR', error); process.exitCode = 2; });

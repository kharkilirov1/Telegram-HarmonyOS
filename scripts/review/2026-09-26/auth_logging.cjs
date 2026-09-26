// Audit reproduction: confirms credential fragments in logs at dev@2d2f683.
// Synthetic input only. This is not a corrected-behavior acceptance test.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const file = path.resolve(__dirname, '../../../entry/src/main/ets/ui/controllers/LoginController.ets');
const source = fs.readFileSync(file, 'utf8')
  .replace(/^import\s[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, '');
const logs = [];
const deps = {
  getTdGatewayAdapter: () => ({ send: async () => ({}) }),
  createCheckAuthCodeCommand: () => ({}),
  hilog: { info: (...args) => logs.push(args), warn() {}, error() {} }
};
const Controller = new Function(...Object.keys(deps),
  stripTypeScriptTypes(source, { mode: 'transform' }) + '; return LoginController;')(...Object.values(deps));
(async () => {
  await Controller.getInstance().checkCode('12345');
  assert.equal(logs[0][3], '12***');
  assert.equal(logs[0][4], 5);
  assert.match(logs[0][2], /%\{public\}s/);
  console.log('CONFIRMED synthetic auth code prefix and length passed to public log: 12***, 5');
})().catch(error => { console.error(error); process.exitCode = 1; });

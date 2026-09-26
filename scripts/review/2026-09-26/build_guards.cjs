// Historical audit probes: assertions confirm known defects at dev@2d2f683.
// No Hvigor/SDK build is performed and no production files are changed.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '../../..');
const hvigor = fs.readFileSync(path.join(root, 'hvigorfile.ts'), 'utf8');
const modulePath = hvigor.match(/from\s+['"](.\/tools\/[^'"]+)['"]/)[1];
assert.equal(['', '.ts', '.js', '/index.ts'].some(suffix => fs.existsSync(path.join(root, modulePath + suffix))), false);
console.log('CONFIRMED root hvigorfile imports a missing local bootstrap module');
const smoke = fs.readFileSync(path.join(root, 'scripts/smoke-ui-phase0.sh'), 'utf8');
const pattern = smoke.match(/^HEX_PATTERN='([^']+)'/m)[1];
assert.match(smoke, /grep -n "\$HEX_PATTERN"/);
const input = ".fontColor('#FF0000')\n";
const basic = spawnSync('grep', ['-n', pattern], { input, encoding: 'utf8' });
const extended = spawnSync('grep', ['-nE', pattern], { input, encoding: 'utf8' });
if (basic.error) throw basic.error;
if (extended.error) throw extended.error;
assert.equal(basic.status, 1);
assert.equal(extended.status, 0);
console.log('CONFIRMED smoke BRE misses prohibited hex; ERE matches the same fixture');

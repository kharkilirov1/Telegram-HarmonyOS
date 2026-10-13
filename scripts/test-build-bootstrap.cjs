// Required build imports must exist AND be eligible for source control.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const entry = fs.readFileSync(path.join(root, 'hvigorfile.ts'), 'utf8');
const imports = [...entry.matchAll(/from\s+['"](\.\/[\w/.-]+)['"]/g)].map(m => `${m[1].slice(2)}.ts`);
assert.ok(imports.length > 0, 'bootstrap import guard must engage');
for (const relative of imports) {
  assert.ok(fs.existsSync(path.join(root, relative)), `missing bootstrap: ${relative}`);
  const check = spawnSync('git', ['check-ignore', '-q', '--', relative], { cwd: root, encoding: 'utf8' });
  assert.equal(check.status, 1, `required bootstrap is ignored or Git check failed: ${relative} ${check.stderr}`);
  console.log('PASS build import exists and is not ignored:', relative);
}

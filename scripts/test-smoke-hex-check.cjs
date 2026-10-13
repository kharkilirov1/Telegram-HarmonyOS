// Exercise the actual Bash smoke regex/grep, not a JavaScript substitute.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(__dirname, 'smoke-ui-phase0.sh'), 'utf8');
const pattern = source.match(/^HEX_PATTERN=(.+)$/m)?.[1].trim();
const grep = source.match(/done < <\((grep [^\n]+?) \|\| true\)/)?.[1];
assert.ok(pattern && grep, 'test must engage actual color check');
const bash = process.platform === 'win32' ? path.join(process.env.ProgramFiles || 'C:/Program Files', 'Git/bin/bash.exe') : 'bash';
for (const [literal, expected] of [['#abc', 0], ['#123456', 0], ['#A1B2C3D4', 0], ['TgUiTokens.COLOR', 1], ['#xyzz', 1]]) {
  const script = `HEX_PATTERN=${pattern}\nprintf '%s\\n' '${literal}' | ${grep.replace('"$full_path"', '/dev/stdin')}`;
  const result = spawnSync(bash, ['-c', script], { cwd: root, encoding: 'utf8' });
  assert.equal(result.status, expected, `${literal}: actual smoke grep status; ${result.stderr || result.error || ''}`);
}
console.log('PASS Bash smoke detects hardcoded colors and rejects non-colors (5 cases)');

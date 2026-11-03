// Guards the four dead controls the 2026-10-25 matrix audit found. Each one looked functional but
// was not wired to anything: a switch that only flipped a local boolean, a settings row with no
// destination, a composer label list nothing rendered, and DTOs nothing constructed.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const root = path.resolve(__dirname, '..');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8');

const profile = read('entry/src/main/ets/ui/pages/profile/TgProfilePage.ets');
assert.match(profile, /createSetChatMuteUseCase\(getTdGatewayAdapter\(\)\)/,
  'profile page must own a mute use case built from the gateway adapter');
assert.match(profile, /\.onChange\(\(isOn: boolean\)/,
  'notifications switch must react to user input');
assert.match(profile, /isOn: !this\.isMuted/,
  'switch state must derive from the chat mute flag');
assert.match(profile, /useCase\.mute\(chatId, MUTE_FOREVER\)/,
  'turning notifications off must send a real mute command');
assert.equal((profile.match(/buildSwitchRow/g) || []).length, 0,
  'the unused generic switch builder must not come back');

const settings = read('entry/src/main/ets/ui/pages/settings/SettingsPage.ets');
// The 2026-10-25 audit removed the Data and Storage row because it had no destination. The screen
// exists now (TgDataStoragePage), so the row must be present AND wired, not merely re-added.
assert.match(settings, /settings_data_storage'\)\.id/,
  'Data and Storage row is back now that a destination screen exists');
assert.match(settings, /onOpenDataStorage/,
  'the row must open the storage screen instead of being decorative');
const routeMap = JSON.parse(fs.readFileSync(
  path.join(root, 'entry/src/main/resources/base/profile/route_map.json'), 'utf8'));
assert.ok(routeMap.routerMap.some((item) => item.name === 'TgDataStoragePage'),
  'the Data and Storage destination must be a registered route');

function walk(directory) {
  const entries = fs.readdirSync(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const full = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...walk(full));
    else if (entry.name.endsWith('.ets')) files.push(full);
  }
  return files;
}

const sources = walk(path.join(root, 'entry/src/main/ets'))
  .map((file) => ({ file, text: fs.readFileSync(file, 'utf8') }));
const offenders = (needle) => sources
  .filter(({ text }) => text.includes(needle))
  .map(({ file }) => path.relative(root, file));

assert.deepEqual(offenders('attachmentMenuLabels'), [],
  'composer attachment labels are rendered from the sheet; the dead pass-through must stay deleted');
assert.deepEqual(offenders('TdAutoDownloadSettings'), [],
  'auto-download DTOs must not return without a consumer');

console.log('PASS dead-control contracts');

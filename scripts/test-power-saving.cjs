// H9: power saving — mode classification, the sampled cache, the playback gate and the ability hook.

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '../entry/src/main/ets');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8').replaceAll('\r\n', '\n');

function load(relative, names, deps = {}) {
  const source = read(relative)
    .replace(/^import\s[\s\S]*?;\s*/gm, '')
    .replace(/^export\s*\{[^}]*\};?\s*/gm, '')
    .replace(/^export\s+/gm, '');
  const js = stripTypeScriptTypes(source, { mode: 'transform', sourceUrl: relative });
  return new Function(...Object.keys(deps), js + '\nreturn {' + names.join(',') + '};')(...Object.values(deps));
}

async function main() {
  const MODE = { MODE_NORMAL: 600, MODE_POWER_SAVE: 601, MODE_PERFORMANCE: 602,
    MODE_EXTREME_POWER_SAVE: 603, MODE_CUSTOM_POWER_SAVE: 604 };
  let requestedMode = MODE.MODE_NORMAL;
  let throws = false;
  const powerApi = {
    DevicePowerMode: MODE,
    getPowerMode: () => {
      if (throws) throw new Error('unsupported');
      return requestedMode;
    }
  };
  const hilog = { info() {}, warn() {}, error() {} };
  const M = load('infra/device/PowerModeMonitor.ets',
    ['isPowerSavingMode', 'refreshPowerMode', 'isPowerSaving', 'hasSampledPowerMode',
      'setPowerSavingForTest'],
    { power: powerApi, hilog });

  // Classification ---------------------------------------------------------------------------------
  assert.equal(M.isPowerSavingMode(MODE.MODE_NORMAL), false);
  assert.equal(M.isPowerSavingMode(MODE.MODE_PERFORMANCE), false);
  assert.equal(M.isPowerSavingMode(MODE.MODE_POWER_SAVE), true);
  assert.equal(M.isPowerSavingMode(MODE.MODE_EXTREME_POWER_SAVE), true);
  assert.equal(M.isPowerSavingMode(MODE.MODE_CUSTOM_POWER_SAVE), true);
  assert.equal(M.isPowerSavingMode(0), false);
  assert.equal(M.isPowerSavingMode(Number.NaN), false);
  assert.equal(M.isPowerSavingMode(undefined), false);

  // Sampling ---------------------------------------------------------------------------------------
  assert.equal(M.hasSampledPowerMode(), false);
  assert.equal(M.isPowerSaving(), false, 'the default is the normal mode');
  assert.equal(M.refreshPowerMode(), false);
  assert.equal(M.hasSampledPowerMode(), true);
  requestedMode = MODE.MODE_POWER_SAVE;
  assert.equal(M.refreshPowerMode(), true);
  assert.equal(M.isPowerSaving(), true);
  requestedMode = MODE.MODE_EXTREME_POWER_SAVE;
  assert.equal(M.refreshPowerMode(), true);
  requestedMode = MODE.MODE_NORMAL;
  assert.equal(M.refreshPowerMode(), false, 'leaving power saving restores animation');
  assert.equal(M.isPowerSaving(), false);
  // A failing read keeps the last known value instead of flipping the policy.
  requestedMode = MODE.MODE_POWER_SAVE;
  M.refreshPowerMode();
  throws = true;
  assert.equal(M.refreshPowerMode(), true, 'a failed read is not a mode change');
  assert.equal(M.isPowerSaving(), true);
  throws = false;
  M.setPowerSavingForTest(false);
  assert.equal(M.isPowerSaving(), false);

  // Playback gate ----------------------------------------------------------------------------------
  const player = read('ui/tg_ui/atoms/TgTgsPlayer.ets');
  assert.match(player, /private static powerSaving: boolean = false;/);
  assert.match(player, /static setPowerSaving\(value: boolean\): void \{/);
  assert.match(player, /static shouldPlay\(visible: boolean, surface: TgsPlaybackSurface\): boolean \{\n    if \(TgsPlaybackPolicy\.powerSaving\) \{\n      return false;\n    \}/);
  assert.match(player, /return visible && TgsPlaybackPolicy\.allowsAnimation\(surface\);/);

  // The policy still refuses the off surfaces when power saving is off.
  // The component decorators are not valid plain TypeScript, so evaluate the policy half only.
  const playerSource = read('ui/tg_ui/atoms/TgTgsPlayer.ets');
  const policySource = playerSource.slice(0, playerSource.indexOf('@ComponentV2'))
    .replace(/^import\s[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, '');
  const POLICY_NAMES = ['TgsPlaybackPolicy', 'TgsPlaybackSurface'];
  const policyJs = stripTypeScriptTypes(policySource, { mode: 'transform' });
  const P = new Function('hilog', 'displaySync', 'tgRlottie', 'TgUiTokens', 'lottie', 'zlib', 'util', 'readFile',
    policyJs + '\nreturn {' + POLICY_NAMES.join(',') + '};')(hilog, {}, {}, { TGS_PLAYBACK_FRAME_RATE: 60 },
    {}, {}, {}, () => '');
  P.TgsPlaybackPolicy.setPowerSaving(false);
  assert.equal(P.TgsPlaybackPolicy.shouldPlay(true, P.TgsPlaybackSurface.Timeline), true);
  assert.equal(P.TgsPlaybackPolicy.shouldPlay(true, P.TgsPlaybackSurface.StickerViewer), true);
  assert.equal(P.TgsPlaybackPolicy.shouldPlay(true, P.TgsPlaybackSurface.PanelPreview), false);
  assert.equal(P.TgsPlaybackPolicy.shouldPlay(false, P.TgsPlaybackSurface.Timeline), false,
    'invisible never plays');
  P.TgsPlaybackPolicy.setPowerSaving(true);
  assert.equal(P.TgsPlaybackPolicy.shouldPlay(true, P.TgsPlaybackSurface.Timeline), false,
    'power saving stops the timeline player');
  assert.equal(P.TgsPlaybackPolicy.shouldPlay(true, P.TgsPlaybackSurface.StickerViewer), false);
  P.TgsPlaybackPolicy.setPowerSaving(false);

  // Ability hook -----------------------------------------------------------------------------------
  const ability = read('entryability/EntryAbility.ets');
  assert.match(ability, /import \{ refreshPowerMode \} from '\.\.\/infra\/device\/PowerModeMonitor';/);
  assert.match(ability, /TgsPlaybackPolicy\.setPowerSaving\(refreshPowerMode\(\)\);/);

  console.log('PASS power saving contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

// J4: interactive atoms must announce themselves.
// The three recently built tappable atoms (location map, link preview, dice) were a pile of Texts with a
// tap handler, which a screen reader reads as fragments.

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const root = path.resolve(__dirname, '..');
const read = (relative) => fs.readFileSync(path.join(root, 'entry/src/main/ets', relative), 'utf8').replaceAll('\r\n', '\n');
const readResource = (relative) => fs.readFileSync(path.join(root, 'entry/src/main/resources', relative), 'utf8').replaceAll('\r\n', '\n');

function check() {
  const location = read('ui/tg_ui/atoms/TgLocationBubble.ets');
  assert.match(location, /\.accessibilityGroup\(true\)/);
  assert.match(location, /\.accessibilityText\(this\.accessibilityLabel\(\)\)/);
  assert.match(location, /const action = localized\(\$r\('app\.string\.accessibility_open_location'\)\.id, 'Open location'\);/);
  assert.match(location, /private accessibilityLabel\(\): string \{/);

  const preview = read('ui/tg_ui/atoms/TgLinkPreviewBubble.ets');
  assert.match(preview, /\.accessibilityGroup\(true\)/);
  assert.match(preview, /\.accessibilityText\(this\.previewAccessibilityLabel\(\)\)/);
  assert.match(preview, /accessibility_open_link/);
  assert.match(preview, /const name = this\.title\.trim\(\)\.length > 0 \? this\.title/);

  const dice = read('ui/tg_ui/atoms/TgDiceBubble.ets');
  assert.match(dice, /\.accessibilityText\(this\.diceAccessibilityLabel\(\)\)/);
  assert.match(dice, /return action \+ ': ' \+ this\.value;/);

  // The labels are localized, not hardcoded English.
  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(readResource(locale + '/element/string.json')).string;
    for (const name of ['accessibility_open_location', 'accessibility_open_link', 'accessibility_dice']) {
      assert.ok(strings.find((item) => item.name === name), `${locale} ships ${name}`);
    }
  }

  console.log('PASS accessibility contract for tappable atoms');
}

check();

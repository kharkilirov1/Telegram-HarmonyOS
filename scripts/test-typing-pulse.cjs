// C2: typing indicator pulse. iOS ChatTypingActivityContentNode.swift pulses the three dots over 0.7s;
// the widget applies a pure step model so the behavior is deterministic and testable.

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '../entry/src/main/ets');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8').replaceAll('\r\n', '\n');

const { createLoader } = require('./lib/ets-load.cjs');
const load = createLoader(root);

async function main() {
  // Tokens are the single source of the timing and the visual bounds.
  const tokenSource = read('ui/tg_ui/tokens/TgUiTokens.ets');
  assert.match(tokenSource, /CHAT_TOP_BAR_TYPING_PULSE_DURATION_MS: number = 700;/);
  assert.match(tokenSource, /CHAT_TOP_BAR_TYPING_PULSE_TICK_MS: number = 70;/);
  assert.match(tokenSource, /CHAT_TOP_BAR_TYPING_PULSE_STEPS: number =/);
  assert.match(tokenSource, /CHAT_TOP_BAR_TYPING_PULSE_MIN_SCALE: number = 0\.6;/);
  assert.match(tokenSource, /CHAT_TOP_BAR_TYPING_PULSE_MIN_OPACITY: number = 0\.35;/);
  assert.match(tokenSource, /CHAT_TOP_BAR_TYPING_DOT_PHASE_STEP: number = 3;/);

  // The model itself: 700ms / 70ms = 10 steps, dots a third of a cycle apart.
  const pulse = load('ui/tg_ui/utils/TgTypingPulse.ets',
    ['typingPulseProgress', 'typingPulseScale', 'typingPulseOpacity', 'nextTypingPulseStep',
      'TYPING_PULSE_STEPS'],
    { TgUiTokens: { CHAT_TOP_BAR_TYPING_PULSE_STEPS: 10,
      CHAT_TOP_BAR_TYPING_DOT_PHASE_STEP: 3,
      CHAT_TOP_BAR_TYPING_PULSE_MIN_SCALE: 0.6,
      CHAT_TOP_BAR_TYPING_PULSE_MIN_OPACITY: 0.35 } });
  assert.equal(pulse.TYPING_PULSE_STEPS, 10);

  // Progress is normalized and wraps both ways.
  assert.equal(pulse.typingPulseProgress(0, 0), 0);
  assert.equal(pulse.typingPulseProgress(9, 0), 0.9);
  assert.equal(pulse.typingPulseProgress(0, 1), 0.3);
  assert.equal(pulse.typingPulseProgress(0, 2), 0.6);
  assert.equal(pulse.typingPulseProgress(8, 1), 0.1, 'the cycle wraps');
  assert.equal(pulse.typingPulseProgress(-1, 0), 0.9, 'negative steps normalize');

  // Scale/opacity stay inside the token bounds and peak mid-cycle for dot 0.
  for (let step = 0; step < 10; step += 1) {
    for (let dot = 0; dot < 3; dot += 1) {
      const scale = pulse.typingPulseScale(step, dot);
      const opacity = pulse.typingPulseOpacity(step, dot);
      assert.ok(scale >= 0.6 && scale <= 1.0001, `scale ${scale} in bounds`);
      assert.ok(opacity >= 0.35 && opacity <= 1.0001, `opacity ${opacity} in bounds`);
    }
  }
  assert.ok(Math.abs(pulse.typingPulseScale(5, 0) - 1) < 1e-9, 'peak scale at half cycle');
  assert.ok(Math.abs(pulse.typingPulseOpacity(5, 0) - 1) < 1e-9, 'peak opacity at half cycle');
  assert.ok(Math.abs(pulse.typingPulseScale(0, 0) - 0.6) < 1e-9, 'rest at cycle start');
  assert.ok(Math.abs(pulse.typingPulseOpacity(0, 0) - 0.35) < 1e-9);
  assert.ok(pulse.typingPulseScale(1, 0) > pulse.typingPulseScale(0, 0), 'the dot grows first');
  assert.ok(pulse.typingPulseScale(9, 0) < pulse.typingPulseScale(5, 0), 'and shrinks back');

  // Dot phases are staggered so the three dots never pulse in sync.
  assert.notEqual(pulse.typingPulseProgress(1, 0), pulse.typingPulseProgress(1, 1));
  assert.equal(pulse.typingPulseProgress(4, 2), pulse.typingPulseProgress(0, 0),
    'dot 2 at step 4 reaches the cycle start, like dot 0 at step 0');
  assert.equal(pulse.typingPulseProgress(0, 1), pulse.typingPulseProgress(7, 2),
    'dot 1 at step 0 equals dot 2 seven steps later');

  // Step advance cycles.
  assert.equal(pulse.nextTypingPulseStep(0), 1);
  assert.equal(pulse.nextTypingPulseStep(9), 0);

  // Widget wiring: dots use the model, the timer runs only while typing is visible.
  const topBar = read('ui/tg_ui/atoms/TgChatTopBar.ets');
  assert.match(topBar, /@Local private typingPulseStep: number = 0;/);
  assert.match(topBar, /private typingPulseTimer: number = -1;/);
  assert.match(topBar, /\.scale\(\{\n\s+x: typingPulseScale\(this\.typingPulseStep, dotIndex\),/);
  assert.match(topBar, /\.opacity\(typingPulseOpacity\(this\.typingPulseStep, dotIndex\)\)/);
  assert.match(topBar, /this\.buildTypingDot\(0\)\n\s+this\.buildTypingDot\(1\)\n\s+this\.buildTypingDot\(2\)/);
  assert.match(topBar, /setInterval\(\(\) => \{\n\s+this\.typingPulseStep = nextTypingPulseStep\(this\.typingPulseStep\);\n\s+\}, TgUiTokens\.CHAT_TOP_BAR_TYPING_PULSE_TICK_MS\)/);
  assert.match(topBar, /clearInterval\(this\.typingPulseTimer\)/);
  assert.match(topBar, /aboutToDisappear\(\): void \{\n\s+this\.stopTypingPulse\(\);/);
  assert.match(topBar, /@Monitor\('subtitleMode'\)/);
  assert.match(topBar, /@Monitor\('subtitle'\)/);
  assert.match(topBar, /return this\.subtitleMode === TgChatTopBarSubtitleMode\.Typing && this\.subtitle\.length > 0;/,
    'the pulse runs only for a visible typing subtitle');
  assert.match(topBar, /this\.typingPulseStep = 0;/, 'the phase resets when typing ends');

  console.log('PASS typing indicator pulse contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

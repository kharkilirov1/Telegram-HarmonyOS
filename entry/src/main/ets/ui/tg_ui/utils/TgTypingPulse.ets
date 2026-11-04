// C2: typing indicator pulse model. iOS ChatTypingActivityContentNode.swift pulses the three dots
// over 0.7s; this module turns a frame step into the scale and opacity the atom applies.
// Pure math so the widget stays dumb and the behavior is covered by a host test.

import { TgUiTokens } from '../tokens/TgUiTokens';

export const TYPING_PULSE_STEPS: number = TgUiTokens.CHAT_TOP_BAR_TYPING_PULSE_STEPS;

// 0..1 position of one dot inside the shared 0.7s cycle; dots start a third apart.
export function typingPulseProgress(step: number, dotIndex: number): number {
  const steps = TYPING_PULSE_STEPS;
  const offset = dotIndex * TgUiTokens.CHAT_TOP_BAR_TYPING_DOT_PHASE_STEP;
  const normalized = ((step + offset) % steps + steps) % steps;
  return normalized / steps;
}

// A dot grows in the first half of the cycle and shrinks in the second half.
export function typingPulseScale(step: number, dotIndex: number): number {
  const progress = typingPulseProgress(step, dotIndex);
  const wave = progress < 0.5 ? progress * 2 : (1 - progress) * 2;
  return TgUiTokens.CHAT_TOP_BAR_TYPING_PULSE_MIN_SCALE +
    (1 - TgUiTokens.CHAT_TOP_BAR_TYPING_PULSE_MIN_SCALE) * wave;
}

export function typingPulseOpacity(step: number, dotIndex: number): number {
  const progress = typingPulseProgress(step, dotIndex);
  const wave = progress < 0.5 ? progress * 2 : (1 - progress) * 2;
  return TgUiTokens.CHAT_TOP_BAR_TYPING_PULSE_MIN_OPACITY +
    (1 - TgUiTokens.CHAT_TOP_BAR_TYPING_PULSE_MIN_OPACITY) * wave;
}

export function nextTypingPulseStep(step: number): number {
  return (step + 1) % TYPING_PULSE_STEPS;
}

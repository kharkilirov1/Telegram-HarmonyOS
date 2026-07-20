export type TgVoiceRecordingState = 'idle' | 'preparing' | 'recording' | 'locked' | 'sending' | 'error';
export type TgVoiceRecordingGestureResolution = 'none' | 'cancel' | 'lock';

export const TG_VOICE_CANCEL_THRESHOLD_VP: number = -72;
export const TG_VOICE_LOCK_THRESHOLD_VP: number = -72;
export const TG_VOICE_MIN_DURATION_MS: number = 500;

export function resolveVoiceRecordingGesture(
  offsetX: number,
  offsetY: number
): TgVoiceRecordingGestureResolution {
  // Cancel wins when both axes cross their threshold. This avoids accidentally
  // locking a gesture that already travelled far enough toward iOS' cancel lane.
  if (offsetX <= TG_VOICE_CANCEL_THRESHOLD_VP) {
    return 'cancel';
  }
  if (offsetY <= TG_VOICE_LOCK_THRESHOLD_VP) {
    return 'lock';
  }
  return 'none';
}

export function formatVoiceRecordingDuration(durationMs: number): string {
  const safeMs = Math.max(0, durationMs);
  const totalSeconds = Math.floor(safeMs / 1000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
}

export function isVoiceRecordingDurationSendable(durationMs: number): boolean {
  return durationMs >= TG_VOICE_MIN_DURATION_MS;
}


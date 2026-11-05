// D21: the "send later" menu and its date/time pickers.
// Owner module for the composer scheduling UI: the composer controller keeps only the delegation, so it
// stays a readable concern and the dialogs live next to the presets they complete.

import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { localized } from '../../../core/utils/AppResource';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';

const DOMAIN = 0x0007;
const TAG = 'ScheduledSend';

export interface ChatScheduledSendHost {
  getChatUIContext(): UIContext;
  canSendNewMessages(kind?: string): boolean;
}

export type SendScheduledText = (text: string, scheduledDateSeconds: number) => void;

// [now + 1h, tomorrow 09:00 local] as Unix seconds.
export function schedulePresets(nowMs: number): number[] {
  const inHour = Math.floor(nowMs / 1000) + 3600;
  const tomorrow = new Date(nowMs);
  tomorrow.setDate(tomorrow.getDate() + 1);
  tomorrow.setHours(9, 0, 0, 0);
  return [inHour, Math.floor(tomorrow.getTime() / 1000)];
}

// System date + time dialogs; a pair that resolves into the past is rejected instead of silently scheduling.
export function pickScheduledDate(context: UIContext, text: string, send: SendScheduledText): void {
  const now = Date.now();
  context.showDatePickerDialog({
    start: new Date(now),
    end: new Date(now + 365 * 24 * 3600 * 1000),
    selected: new Date(now + 3600 * 1000),
    onDateAccept: (picked: Date): void => {
      context.showTimePickerDialog({
        selected: picked,
        useMilitaryTime: true,
        onAccept: (time: TimePickerResult): void => {
          const target = new Date(picked.getFullYear(), picked.getMonth(), picked.getDate(),
            time.hour, time.minute, 0, 0);
          const seconds = Math.floor(target.getTime() / 1000);
          if (seconds > Math.floor(Date.now() / 1000)) {
            send(text, seconds);
          }
        }
      });
    }
  });
}

// Two presets plus a custom picker, all feeding the same send path.
export function openScheduledSendMenu(host: ChatScheduledSendHost, text: string, send: SendScheduledText): void {
  const trimmed = text.trim();
  if (trimmed.length === 0 || !host.canSendNewMessages('text')) return;
  const presets: number[] = schedulePresets(Date.now());
  const normal: Resource = TgUiTokens.CHAT_TOP_BAR_ACTION_FOREGROUND;
  const b0: promptAction.Button = { text: localized($r('app.string.schedule_send_in_hour').id, 'In 1 hour'), color: normal };
  const b1: promptAction.Button = { text: localized($r('app.string.schedule_send_tomorrow').id, 'Tomorrow at 9:00'), color: normal };
  const b2: promptAction.Button = { text: localized($r('app.string.schedule_send_custom').id, 'Date and time'), color: normal };
  host.getChatUIContext().getPromptAction().showActionMenu({
    title: localized($r('app.string.schedule_send_title').id, 'Send later'),
    buttons: [b0, b1, b2]
  }).then((result: promptAction.ActionMenuSuccessResponse) => {
    if (result.index === 2) {
      pickScheduledDate(host.getChatUIContext(), trimmed, send);
      return;
    }
    const seconds = presets[result.index];
    if (seconds !== undefined && seconds > 0) {
      send(trimmed, seconds);
    }
  }).catch((error: Error) => {
    hilog.warn(DOMAIN, TAG, 'Schedule menu failed: %{public}s', error.message);
  });
}

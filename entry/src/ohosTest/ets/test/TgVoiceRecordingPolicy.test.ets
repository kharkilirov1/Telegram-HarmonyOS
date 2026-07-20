import { describe, expect, it } from '@ohos/hypium';
import {
  formatVoiceRecordingDuration,
  isVoiceRecordingDurationSendable,
  resolveVoiceRecordingGesture
} from '../../../main/ets/ui/tg_ui/utils/TgVoiceRecordingPolicy';

export default function tgVoiceRecordingPolicyTest() {
  describe('TgVoiceRecordingPolicy', () => {
    it('resolves Telegram cancel and lock drag thresholds', 0, () => {
      expect(resolveVoiceRecordingGesture(-71, 0)).assertEqual('none');
      expect(resolveVoiceRecordingGesture(-72, 0)).assertEqual('cancel');
      expect(resolveVoiceRecordingGesture(0, -72)).assertEqual('lock');
      expect(resolveVoiceRecordingGesture(-90, -90)).assertEqual('cancel');
    });

    it('formats a monotonic mm:ss recording timer', 0, () => {
      expect(formatVoiceRecordingDuration(0)).assertEqual('0:00');
      expect(formatVoiceRecordingDuration(9_999)).assertEqual('0:09');
      expect(formatVoiceRecordingDuration(61_000)).assertEqual('1:01');
    });

    it('rejects accidental recordings shorter than 500ms', 0, () => {
      expect(isVoiceRecordingDurationSendable(499)).assertFalse();
      expect(isVoiceRecordingDurationSendable(500)).assertTrue();
    });
  });
}

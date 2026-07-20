import { describe, it, expect } from '@ohos/hypium';
import {
  PendingSharedMediaAction,
  PendingSharedMediaActionSignal
} from '../../../main/ets/ui/pages/chat/PendingSharedMediaActionSignal';

export default function pendingSharedMediaActionSignalTest() {
  describe('PendingSharedMediaActionSignal', () => {
    it('keeps an action until the matching chat consumes it', 0, () => {
      PendingSharedMediaActionSignal.clear();
      PendingSharedMediaActionSignal.set(42, '9001', 'file');

      const wrongChat = PendingSharedMediaActionSignal.consume(41);
      const action: PendingSharedMediaAction | undefined = PendingSharedMediaActionSignal.consume(42);

      expect(wrongChat === undefined).assertTrue();
      expect(action !== undefined).assertTrue();
      expect(action?.messageId).assertEqual('9001');
      expect(action?.kind).assertEqual('file');
      expect(PendingSharedMediaActionSignal.consume(42) === undefined).assertTrue();
    });

    it('preserves the exact link target', 0, () => {
      PendingSharedMediaActionSignal.clear();
      PendingSharedMediaActionSignal.set(77, '88', 'link', 'https://example.com/path');

      const action: PendingSharedMediaAction | undefined = PendingSharedMediaActionSignal.consume(77);

      expect(action?.linkUrl).assertEqual('https://example.com/path');
      expect(action?.chatId).assertEqual(77);
    });
  });
}

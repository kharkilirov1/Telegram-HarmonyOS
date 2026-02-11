import { describe, it, expect } from '@ohos/hypium';
import { parseUpdateChatIsMarkedAsUnread } from '../../../main/ets/controllers/messages/TdUpdateParser';

export default function tdUpdateParserTest() {
  describe('TdUpdateParser', () => {
    it('should parse updateChatIsMarkedAsUnread payload', 0, () => {
      const update: Record<string, unknown> = {};
      update['chat_id'] = 123;
      update['is_marked_as_unread'] = true;

      const parsed = parseUpdateChatIsMarkedAsUnread(update);
      expect(parsed !== undefined).assertTrue();
      if (parsed) {
        expect(parsed.chatId).assertEqual(123);
        expect(parsed.isMarkedAsUnread).assertTrue();
      }
    });

    it('should return undefined when chat_id is invalid', 0, () => {
      const update: Record<string, unknown> = {};
      update['chat_id'] = 0;
      update['is_marked_as_unread'] = true;

      const parsed = parseUpdateChatIsMarkedAsUnread(update);
      expect(parsed === undefined).assertTrue();
    });
  });
}

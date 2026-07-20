import { describe, it, expect } from '@ohos/hypium';
import { parseRepliedMessageResponse } from '../../../main/ets/domain/usecases/loadRepliedMessage';
import { MessageDto } from '../../../main/ets/core/model/dto/MessageDto';
import { TdObject } from '../../../main/ets/models/TdTypes';

export default function loadRepliedMessageTest() {
  describe('LoadRepliedMessage', () => {
    it('parses an original message with int64 id', 0, () => {
      const response = TdObject.fromJSON(
        '{"@type":"message","id":9007199254740991,"chat_id":-100123,"date":1,' +
          '"sender_id":{"@type":"messageSenderUser","user_id":77},' +
          '"content":{"@type":"messageText","text":{"@type":"formattedText",' +
          '"text":"Original reply text","entities":[]}}}'
      );

      const message: MessageDto | undefined = parseRepliedMessageResponse(
        response,
        '9007199254740991'
      );
      expect(message !== undefined).assertTrue();
      expect(message?.id).assertEqual('9007199254740991');
      expect(message?.content.text).assertEqual('Original reply text');
    });

    it('accepts a cross-chat original but rejects the wrong target id', 0, () => {
      const response = TdObject.fromJSON(
        '{"@type":"message","id":42,"chat_id":200,"date":1,' +
          '"content":{"@type":"messageText","text":{"@type":"formattedText",' +
          '"text":"Wrong chat","entities":[]}}}'
      );

      const crossChat = parseRepliedMessageResponse(response, '42');
      expect(crossChat?.chatId).assertEqual(200);
      expect(parseRepliedMessageResponse(response, '41') === undefined).assertTrue();
    });
  });
}

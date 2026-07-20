import { describe, it, expect } from '@ohos/hypium';
import { TdObject } from '../../../main/ets/models/TdTypes';
import {
  ChatUpdateDto,
  extractCustomEmojiTextEntities
} from '../../../main/ets/core/model/dto/ChatDto';
import { CustomEmojiTextEntity } from '../../../main/ets/core/model/AppCommand';
import { createInitialAppState } from '../../../main/ets/core/model/AppState';
import { createChatUpdatedEvent } from '../../../main/ets/core/model/AppEvent';
import { chatsReducer } from '../../../main/ets/core/reducers/chatsReducer';

export default function chatDraftEntitiesTest() {
  describe('ChatDraftEntities', () => {
    it('parses only valid TDLib custom emoji entities', 0, () => {
      const formattedText = TdObject.fromJSON('{"@type":"formattedText","text":"A😀B",' +
        '"entities":[{"@type":"textEntity","offset":1,"length":2,' +
        '"type":{"@type":"textEntityTypeCustomEmoji","custom_emoji_id":9876543210123}},' +
        '{"@type":"textEntity","offset":0,"length":1,' +
        '"type":{"@type":"textEntityTypeBold"}}]}');

      const entities = extractCustomEmojiTextEntities(formattedText);
      expect(entities.length).assertEqual(1);
      expect(entities[0].offset).assertEqual(1);
      expect(entities[0].length).assertEqual(2);
      expect(entities[0].customEmojiId).assertEqual('9876543210123');
    });

    it('keeps draft custom emoji entities in chat state updates', 0, () => {
      const update = new ChatUpdateDto();
      update.draftText = '😀';
      update.draftCustomEmojiEntities = [new CustomEmojiTextEntity(0, 2, '777')];
      const state = chatsReducer(createInitialAppState(), createChatUpdatedEvent(42, update));
      const chat = state.chats.chats.get(42);

      expect(chat !== undefined).assertTrue();
      expect(chat!.draftCustomEmojiEntities.length).assertEqual(1);
      expect(chat!.draftCustomEmojiEntities[0].customEmojiId).assertEqual('777');
    });
  });
}

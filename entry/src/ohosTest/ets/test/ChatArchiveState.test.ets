import { describe, it, expect } from '@ohos/hypium';
import { createInitialAppState } from '../../../main/ets/core/model/AppState';
import { createChatUpdatedEvent } from '../../../main/ets/core/model/AppEvent';
import { ChatUpdateDto } from '../../../main/ets/core/model/dto/ChatDto';
import { chatsReducer } from '../../../main/ets/core/reducers/chatsReducer';

function archivePosition(order: string, isPinned: boolean = false): ChatUpdateDto {
  const update = new ChatUpdateDto();
  update.archiveOrder = order;
  update.isArchivePinned = isPinned;
  return update;
}

export default function chatArchiveStateTest() {
  describe('ChatArchiveState', () => {
    it('keeps archive-only chats out of main and sorts archive by TDLib order', 0, () => {
      let state = createInitialAppState();
      state = chatsReducer(state, createChatUpdatedEvent(10, archivePosition('100')));
      state = chatsReducer(state, createChatUpdatedEvent(20, archivePosition('300', true)));
      state = chatsReducer(state, createChatUpdatedEvent(30, archivePosition('200')));

      expect(state.chats.orderedChatIds.length).assertEqual(0);
      expect(state.chats.archivedChatIds.length).assertEqual(3);
      expect(state.chats.archivedChatIds[0]).assertEqual(20);
      expect(state.chats.archivedChatIds[1]).assertEqual(30);
      expect(state.chats.archivedChatIds[2]).assertEqual(10);
      expect(state.chats.chats.get(20)?.isArchivePinned).assertTrue();
    });

    it('moves a chat from archive back to main without duplicating it', 0, () => {
      let state = createInitialAppState();
      state = chatsReducer(state, createChatUpdatedEvent(10, archivePosition('100')));

      const moveToMain = new ChatUpdateDto();
      moveToMain.archiveOrder = '0';
      moveToMain.isArchivePinned = false;
      moveToMain.order = '500';
      state = chatsReducer(state, createChatUpdatedEvent(10, moveToMain));

      expect(state.chats.archivedChatIds.length).assertEqual(0);
      expect(state.chats.orderedChatIds.length).assertEqual(1);
      expect(state.chats.orderedChatIds[0]).assertEqual(10);
    });
  });
}

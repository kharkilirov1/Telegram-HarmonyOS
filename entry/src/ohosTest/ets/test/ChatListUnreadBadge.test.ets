import { describe, it, expect } from '@ohos/hypium';
import { EventNormalizerImpl } from '../../../main/ets/core/events/EventNormalizer';
import {
  ChatListUnreadMessageCountChangedEvent
} from '../../../main/ets/core/model/AppEvent';
import { Chat, createInitialAppState } from '../../../main/ets/core/model/AppState';
import { chatsReducer } from '../../../main/ets/core/reducers/chatsReducer';
import { cloneChatsState } from '../../../main/ets/core/utils/stateClone';
import { selectTotalUnreadCount } from '../../../main/ets/domain/selectors/chatSelectors';
import { TdObject } from '../../../main/ets/models/TdTypes';
import { formatTelegramCompactCount } from '../../../main/ets/ui/tg_ui/utils/TgCompactCount';

export default function chatListUnreadBadgeTest() {
  describe('ChatListUnreadBadge', () => {
    it('normalizes the exact TDLib main-list unread-message aggregate', 0, () => {
      const normalizer = new EventNormalizerImpl();
      const events = normalizer.normalize(TdObject.fromJSON(
        '{"@type":"updateUnreadMessageCount","chat_list":{"@type":"chatListMain"},' +
          '"unread_count":1250,"unread_unmuted_count":1200}'
      ));

      expect(events.length).assertEqual(1);
      const event = events[0] as ChatListUnreadMessageCountChangedEvent;
      expect(event.type).assertEqual('chatListUnreadMessageCountChanged');
      expect(event.chatListType).assertEqual('main');
      expect(event.unreadCount).assertEqual(1250);
      expect(event.unreadUnmutedCount).assertEqual(1200);
    });

    it('stores main and archive aggregates independently and clones them', 0, () => {
      let state = createInitialAppState();
      const mainEvent = new ChatListUnreadMessageCountChangedEvent();
      mainEvent.chatListType = 'main';
      mainEvent.unreadCount = 1250;
      mainEvent.unreadUnmutedCount = 1200;
      state = chatsReducer(state, mainEvent);

      const archiveEvent = new ChatListUnreadMessageCountChangedEvent();
      archiveEvent.chatListType = 'archive';
      archiveEvent.unreadCount = 7;
      archiveEvent.unreadUnmutedCount = 3;
      state = chatsReducer(state, archiveEvent);

      expect(state.chats.mainUnreadMessageCount).assertEqual(1250);
      expect(state.chats.mainUnreadUnmutedMessageCount).assertEqual(1200);
      expect(state.chats.archiveUnreadMessageCount).assertEqual(7);
      expect(state.chats.archiveUnreadUnmutedMessageCount).assertEqual(3);

      const cloned = cloneChatsState(state.chats);
      expect(cloned.mainUnreadMessageCount).assertEqual(1250);
      expect(cloned.archiveUnreadMessageCount).assertEqual(7);
    });

    it('prefers the complete aggregate and falls back to loaded main-list messages only', 0, () => {
      const aggregateState = createInitialAppState();
      aggregateState.chats.mainUnreadMessageCount = 42;
      expect(selectTotalUnreadCount(aggregateState)).assertEqual(42);

      const fallbackState = createInitialAppState();
      const mainChat = new Chat();
      mainChat.id = 1;
      mainChat.unreadCount = 5;
      const archivedChat = new Chat();
      archivedChat.id = 2;
      archivedChat.unreadCount = 7;
      fallbackState.chats.chats.set(mainChat.id, mainChat);
      fallbackState.chats.chats.set(archivedChat.id, archivedChat);
      fallbackState.chats.orderedChatIds = [mainChat.id];
      fallbackState.chats.archivedChatIds = [archivedChat.id];

      expect(selectTotalUnreadCount(fallbackState)).assertEqual(5);
    });

    it('matches Telegram iOS compactNumericCountString truncation', 0, () => {
      expect(formatTelegramCompactCount(999)).assertEqual('999');
      expect(formatTelegramCompactCount(1000)).assertEqual('1K');
      expect(formatTelegramCompactCount(2500)).assertEqual('2.5K');
      expect(formatTelegramCompactCount(999999)).assertEqual('999.9K');
      expect(formatTelegramCompactCount(1250000)).assertEqual('1.2M');
    });
  });
}

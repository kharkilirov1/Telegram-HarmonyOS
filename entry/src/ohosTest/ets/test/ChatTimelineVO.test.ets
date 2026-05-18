import { describe, it, expect } from '@ohos/hypium';
import {
  senderNameColor,
  PollOptionVO,
  ChatMessageRowVO,
  ChatTimelineEntryVO,
  ChatTimelineBuildResult,
  buildChatTimeline
} from '../../../main/ets/ui/pages/chat/ChatTimelineVO';
import { AppState, Chat, User, UsersState, ChatsState } from '../../../main/ets/core/model/AppState';
import { TgMessageSendStatus } from '../../../main/ets/ui/tg_ui/atoms/TgMessageMeta';

/**
 * Unit tests for ChatTimelineVO — view model building for chat timeline.
 */

function makeMinimalState(): AppState {
  const state = new AppState();
  return state;
}

function makeStateWithUser(userId: number, accentColorId: number): AppState {
  const state = makeMinimalState();
  const user = new User();
  user.id = userId;
  user.accentColorId = accentColorId;
  state.users.users.set(userId, user);
  return state;
}

function makeStateWithChat(chatId: number, accentColorId: number): AppState {
  const state = makeMinimalState();
  const chat = new Chat();
  chat.id = chatId;
  chat.accentColorId = accentColorId;
  state.chats.chats.set(chatId, chat);
  return state;
}

export default function chatTimelineVOTest() {
  describe('ChatTimelineVO', () => {

    // -----------------------------------------------------------------------
    // senderNameColor
    // -----------------------------------------------------------------------
    describe('senderNameColor', () => {

      it('should return a color string for sender with accentColorId 0', 0, () => {
        const state = makeStateWithUser(100, 0);
        const color = senderNameColor(100, state);
        expect(color).assertEqual('#cc5049');
      });

      it('should return a color string for sender with accentColorId 1', 0, () => {
        const state = makeStateWithUser(101, 1);
        const color = senderNameColor(101, state);
        expect(color).assertEqual('#d67722');
      });

      it('should return a color string for sender with accentColorId 2', 0, () => {
        const state = makeStateWithUser(102, 2);
        const color = senderNameColor(102, state);
        expect(color).assertEqual('#955cdb');
      });

      it('should return a color string for sender with accentColorId 3', 0, () => {
        const state = makeStateWithUser(103, 3);
        const color = senderNameColor(103, state);
        expect(color).assertEqual('#40a920');
      });

      it('should return a color string for sender with accentColorId 6', 0, () => {
        const state = makeStateWithUser(106, 6);
        const color = senderNameColor(106, state);
        expect(color).assertEqual('#c7508b');
      });

      it('should wrap around for accentColorId >= 7 (palette length)', 0, () => {
        const state = makeStateWithUser(107, 0);
        const color0 = senderNameColor(107, state);
        // accentColorId 0 wraps to index 0 = '#cc5049'
        expect(color0).assertEqual('#cc5049');
      });

      it('should fall back to senderId-based color when user has no accent', 0, () => {
        const state = makeMinimalState();
        const color = senderNameColor(7, state);
        // fallback: abs(7) % 7 = 0 => '#cc5049'
        expect(color).assertEqual('#cc5049');
      });

      it('should fall back to senderChatId color when senderId is 0', 0, () => {
        const state = makeStateWithChat(5, 4);
        const color = senderNameColor(0, state, 5);
        // chat accentColorId=4 => '#309eba'
        expect(color).assertEqual('#309eba');
      });

      it('should use user accent over fallback when user exists', 0, () => {
        const state = makeStateWithUser(200, 5);
        const color = senderNameColor(200, state);
        expect(color).assertEqual('#368ad1');
      });

      it('should return fallback color for negative accentColorId on user', 0, () => {
        const state = makeStateWithUser(300, -1);
        // negative accentColorId => no exact match, falls back to abs(senderId) % 7
        const color = senderNameColor(300, state);
        // abs(300) % 7 = 6 => '#c7508b'
        expect(color).assertEqual('#c7508b');
      });
    });

    // -----------------------------------------------------------------------
    // buildChatTimeline — empty chat
    // -----------------------------------------------------------------------
    describe('buildChatTimeline — empty chat', () => {

      it('should return empty entries for nonexistent chat', 0, () => {
        const state = makeMinimalState();
        const result = buildChatTimeline(999, state);
        expect(result.entries.length).assertEqual(0);
        expect(result.chatTitle).assertEqual('');
        expect(result.chatId).assertEqual(999);
        expect(result.unreadEntryIndex).assertEqual(-1);
      });

      it('should return chat title for existing chat with no messages', 0, () => {
        const state = makeMinimalState();
        const chat = new Chat();
        chat.id = 100;
        chat.title = 'Test Chat';
        state.chats.chats.set(100, chat);
        const result = buildChatTimeline(100, state);
        expect(result.chatTitle).assertEqual('Test Chat');
        expect(result.entries.length).assertEqual(0);
      });
    });

    // -----------------------------------------------------------------------
    // ChatMessageRowVO defaults
    // -----------------------------------------------------------------------
    describe('ChatMessageRowVO defaults', () => {

      it('should have correct default messageId', 0, () => {
        const vo = new ChatMessageRowVO();
        expect(vo.messageId).assertEqual('0');
      });

      it('should have empty default text', 0, () => {
        const vo = new ChatMessageRowVO();
        expect(vo.text).assertEqual('');
      });

      it('should default isOutgoing to false', 0, () => {
        const vo = new ChatMessageRowVO();
        expect(vo.isOutgoing).assertFalse();
      });

      it('should default isEmojiOnly to false', 0, () => {
        const vo = new ChatMessageRowVO();
        expect(vo.isEmojiOnly).assertFalse();
      });

      it('should default sendStatus to None', 0, () => {
        const vo = new ChatMessageRowVO();
        expect(vo.sendStatus).assertEqual(TgMessageSendStatus.None);
      });

      it('should default contentType to text', 0, () => {
        const vo = new ChatMessageRowVO();
        expect(vo.contentType).assertEqual('text');
      });

      it('should default showSenderName to false', 0, () => {
        const vo = new ChatMessageRowVO();
        expect(vo.showSenderName).assertFalse();
      });

      it('should default showReplySnippet to false', 0, () => {
        const vo = new ChatMessageRowVO();
        expect(vo.showReplySnippet).assertFalse();
      });

      it('should default photoFileId to 0', 0, () => {
        const vo = new ChatMessageRowVO();
        expect(vo.photoFileId).assertEqual(0);
      });

      it('should default topSpacing to 8', 0, () => {
        const vo = new ChatMessageRowVO();
        expect(vo.topSpacing).assertEqual(8);
      });

      it('should default pollOptions to empty array', 0, () => {
        const vo = new ChatMessageRowVO();
        expect(vo.pollOptions.length).assertEqual(0);
      });

      it('should default caption to empty string', 0, () => {
        const vo = new ChatMessageRowVO();
        expect(vo.caption).assertEqual('');
      });

      it('should default forceBreakAll to false', 0, () => {
        const vo = new ChatMessageRowVO();
        expect(vo.forceBreakAll).assertFalse();
      });

      it('should default pollIsAnonymous to true', 0, () => {
        const vo = new ChatMessageRowVO();
        expect(vo.pollIsAnonymous).assertTrue();
      });

      it('should default pollType to regular', 0, () => {
        const vo = new ChatMessageRowVO();
        expect(vo.pollType).assertEqual('regular');
      });
    });

    // -----------------------------------------------------------------------
    // PollOptionVO defaults
    // -----------------------------------------------------------------------
    describe('PollOptionVO defaults', () => {

      it('should have empty default text', 0, () => {
        const opt = new PollOptionVO();
        expect(opt.text).assertEqual('');
      });

      it('should default voterCount to 0', 0, () => {
        const opt = new PollOptionVO();
        expect(opt.voterCount).assertEqual(0);
      });

      it('should default votePercentage to 0', 0, () => {
        const opt = new PollOptionVO();
        expect(opt.votePercentage).assertEqual(0);
      });

      it('should default isChosen to false', 0, () => {
        const opt = new PollOptionVO();
        expect(opt.isChosen).assertFalse();
      });
    });

    // -----------------------------------------------------------------------
    // ChatTimelineEntryVO kinds
    // -----------------------------------------------------------------------
    describe('ChatTimelineEntryVO', () => {

      it('should default kind to message', 0, () => {
        const entry = new ChatTimelineEntryVO();
        expect(entry.kind).assertEqual('message');
      });

      it('should default key to empty string', 0, () => {
        const entry = new ChatTimelineEntryVO();
        expect(entry.key).assertEqual('');
      });

      it('should default dateText to empty string', 0, () => {
        const entry = new ChatTimelineEntryVO();
        expect(entry.dateText).assertEqual('');
      });

      it('should default unreadText to empty string', 0, () => {
        const entry = new ChatTimelineEntryVO();
        expect(entry.unreadText).assertEqual('');
      });

      it('should accept date kind', 0, () => {
        const entry = new ChatTimelineEntryVO();
        entry.kind = 'date';
        expect(entry.kind).assertEqual('date');
      });

      it('should accept unread kind', 0, () => {
        const entry = new ChatTimelineEntryVO();
        entry.kind = 'unread';
        expect(entry.kind).assertEqual('unread');
      });

      it('should contain a default ChatMessageRowVO', 0, () => {
        const entry = new ChatTimelineEntryVO();
        expect(entry.message.messageId).assertEqual('0');
        expect(entry.message.contentType).assertEqual('text');
      });
    });

    // -----------------------------------------------------------------------
    // ChatTimelineBuildResult defaults
    // -----------------------------------------------------------------------
    describe('ChatTimelineBuildResult defaults', () => {

      it('should default chatId to 0', 0, () => {
        const result = new ChatTimelineBuildResult();
        expect(result.chatId).assertEqual(0);
      });

      it('should default chatTitle to empty string', 0, () => {
        const result = new ChatTimelineBuildResult();
        expect(result.chatTitle).assertEqual('');
      });

      it('should default unreadEntryIndex to -1', 0, () => {
        const result = new ChatTimelineBuildResult();
        expect(result.unreadEntryIndex).assertEqual(-1);
      });

      it('should default entries to empty array', 0, () => {
        const result = new ChatTimelineBuildResult();
        expect(result.entries.length).assertEqual(0);
      });
    });
  });
}

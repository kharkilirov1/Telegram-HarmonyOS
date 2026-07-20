import { describe, it, expect } from '@ohos/hypium';
import {
  senderNameColor,
  PollOptionVO,
  ChatMessageRowVO,
  ChatTimelineEntryVO,
  ChatTimelineBuildResult,
  buildChatTimeline,
  composeChatDateSeparatorLabel,
  timelineEntryContainsMessageId
} from '../../../main/ets/ui/pages/chat/ChatTimelineVO';
import {
  PendingMediaOpenIntent,
  resolvePendingMediaOpenIntent
} from '../../../main/ets/ui/pages/chat/PendingMediaOpenIntent';
import { resolveRefreshedMediaGalleryState } from '../../../main/ets/ui/pages/chat/MediaGalleryState';
import { MediaGalleryItem } from '../../../main/ets/models/MediaGalleryItem';
import { AppState, Chat, Message, User, UsersState, ChatsState } from '../../../main/ets/core/model/AppState';
import { createAssociatedMessageKey } from '../../../main/ets/core/utils/replyMessageKey';
import { TgMessageSendStatus } from '../../../main/ets/ui/tg_ui/atoms/TgMessageMeta';
import {
  ChatUnreadEntrySnapshot,
  PendingChatUnreadSnapshot
} from '../../../main/ets/ui/pages/chat/PendingChatUnreadSnapshot';

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

function makePendingMediaEntry(messageId: string): ChatTimelineEntryVO {
  const entry = new ChatTimelineEntryVO();
  entry.kind = 'message';
  entry.message.messageId = messageId;
  return entry;
}

function makeGalleryItem(messageId: string, fileId: number, type: string = 'photo', path: string = ''): MediaGalleryItem {
  const item = new MediaGalleryItem();
  item.messageId = messageId;
  item.fileId = fileId;
  item.type = type;
  item.path = path;
  return item;
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

      it('should preserve a zero sticky unread boundary after live read fields reset', 0, () => {
        const state = makeMinimalState();
        const chat = new Chat();
        chat.id = 104;
        chat.title = 'Unread boundary';
        chat.type = 'group';
        chat.unreadCount = 0;
        chat.lastReadInboxMessageId = '1002';
        state.chats.chats.set(chat.id, chat);

        const first = new Message();
        first.id = '1001';
        first.chatId = chat.id;
        first.timestamp = 1000;
        first.content.text = 'first unread';
        const second = new Message();
        second.id = '1002';
        second.chatId = chat.id;
        second.timestamp = 1001;
        second.content.text = 'second unread';
        const messages = new Map<string, Message>();
        messages.set(first.id, first);
        messages.set(second.id, second);
        state.messages.messages.set(chat.id, messages);

        const result = buildChatTimeline(chat.id, state, '0');
        expect(result.unreadEntryIndex >= 0).assertTrue();
        expect(result.entries[result.unreadEntryIndex].kind).assertEqual('unread');
        expect(result.entries[result.unreadEntryIndex + 1].message.messageId).assertEqual('1001');
      });

      it('should not insert an unread marker without a sticky or live unread boundary', 0, () => {
        const state = makeMinimalState();
        const chat = new Chat();
        chat.id = 105;
        chat.title = 'Read chat';
        chat.type = 'group';
        chat.unreadCount = 0;
        chat.lastReadInboxMessageId = '1001';
        state.chats.chats.set(chat.id, chat);

        const message = new Message();
        message.id = '1001';
        message.chatId = chat.id;
        message.timestamp = 1000;
        message.content.text = 'already read';
        const messages = new Map<string, Message>();
        messages.set(message.id, message);
        state.messages.messages.set(chat.id, messages);

        const result = buildChatTimeline(chat.id, state);
        expect(result.unreadEntryIndex).assertEqual(-1);
      });

      it('should project link preview fields into the rendered message row', 0, () => {
        const state = makeMinimalState();
        const chat = new Chat();
        chat.id = 101;
        chat.title = 'Preview chat';
        chat.type = 'group';
        state.chats.chats.set(101, chat);

        const message = new Message();
        message.id = '1001';
        message.chatId = 101;
        message.timestamp = 1000;
        message.content.text = 'https://telegram.org';
        message.content.linkPreviewUrl = 'https://telegram.org/blog/example';
        message.content.linkPreviewSiteName = 'Telegram';
        message.content.linkPreviewTitle = 'Preview title';
        message.content.linkPreviewDescription = 'Preview description';
        message.content.linkPreviewPhotoThumbPath = '/data/files/preview.jpg';
        message.content.linkPreviewPhotoThumbFileId = 91;
        message.content.linkPreviewShowLargeMedia = true;
        const chatMessages = new Map<string, Message>();
        chatMessages.set(message.id, message);
        state.messages.messages.set(101, chatMessages);

        const result = buildChatTimeline(101, state);
        let row = new ChatMessageRowVO();
        for (const entry of result.entries) {
          if (entry.kind === 'message') {
            row = entry.message;
          }
        }
        expect(row.linkPreviewUrl).assertEqual('https://telegram.org/blog/example');
        expect(row.linkPreviewSiteName).assertEqual('Telegram');
        expect(row.linkPreviewDescription).assertEqual('Preview description');
        expect(row.linkPreviewPhotoPath).assertEqual('file:///data/files/preview.jpg');
        expect(row.linkPreviewPhotoThumbFileId).assertEqual(91);
        expect(row.linkPreviewShowLargeMedia).assertTrue();
      });

      it('should project TDLib editDate into localized message meta text', 0, () => {
        const state = makeMinimalState();
        const chat = new Chat();
        chat.id = 103;
        chat.title = 'Edited message';
        state.chats.chats.set(103, chat);

        const message = new Message();
        message.id = '1003';
        message.chatId = 103;
        message.timestamp = 1000;
        message.editDate = 1001;
        message.content.text = 'edited body';
        const chatMessages = new Map<string, Message>();
        chatMessages.set(message.id, message);
        state.messages.messages.set(103, chatMessages);

        const result = buildChatTimeline(103, state);
        let editedText = '';
        for (const entry of result.entries) {
          if (entry.kind === 'message') {
            editedText = entry.message.editedText;
          }
        }
        expect(editedText.length > 0).assertTrue();
      });

      it('should resolve a cross-chat reply from context-scoped associated storage', 0, () => {
        const state = makeMinimalState();
        const chat = new Chat();
        chat.id = 102;
        chat.title = 'Replies';
        chat.type = 'group';
        state.chats.chats.set(102, chat);

        const reply = new Message();
        reply.id = '1002';
        reply.chatId = 102;
        reply.timestamp = 1000;
        reply.replyToChatId = 102;
        reply.replyToMessageId = '42';
        reply.content.text = 'Reply body';
        const liveMessages = new Map<string, Message>();
        liveMessages.set('1002', reply);
        state.messages.messages.set(102, liveMessages);

        const placeholderResult = buildChatTimeline(102, state);
        let placeholderKey = '';
        for (const entry of placeholderResult.entries) {
          if (entry.kind === 'message') {
            placeholderKey = entry.key;
          }
        }

        const original = new Message();
        original.id = '42';
        original.chatId = 200;
        original.timestamp = 900;
        original.content.text = 'Hydrated original';
        const associated = new Map<string, Message>();
        associated.set(createAssociatedMessageKey(102, '42'), original);
        state.messages.associatedMessages.set(102, associated);

        const result = buildChatTimeline(102, state);
        let row = new ChatMessageRowVO();
        let hydratedKey = '';
        for (const entry of result.entries) {
          if (entry.kind === 'message') {
            row = entry.message;
            hydratedKey = entry.key;
          }
        }
        expect(row.replyPreview).assertEqual('Hydrated original');
        expect(hydratedKey === placeholderKey).assertFalse();
      });
    });

    describe('PendingChatUnreadSnapshot', () => {
      it('should preserve TDLib zero as a valid one-shot unread boundary', 0, () => {
        PendingChatUnreadSnapshot.set(104, '0', 12);
        const snapshot: ChatUnreadEntrySnapshot | undefined = PendingChatUnreadSnapshot.consume(104);
        expect(snapshot !== undefined).assertTrue();
        if (snapshot) {
          expect(snapshot.lastReadInboxMessageId).assertEqual('0');
          expect(snapshot.unreadCount).assertEqual(12);
        }
        expect(PendingChatUnreadSnapshot.consume(104) === undefined).assertTrue();
      });

      it('should not consume another chat unread snapshot', 0, () => {
        PendingChatUnreadSnapshot.set(105, '1001', 3);
        expect(PendingChatUnreadSnapshot.consume(106) === undefined).assertTrue();
        const snapshot: ChatUnreadEntrySnapshot | undefined = PendingChatUnreadSnapshot.consume(105);
        expect(snapshot !== undefined).assertTrue();
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

      it('should default editedText to empty', 0, () => {
        const vo = new ChatMessageRowVO();
        expect(vo.editedText).assertEqual('');
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

      it('should match every source message collapsed into an album row', 0, () => {
        const entry = new ChatTimelineEntryVO();
        entry.kind = 'message';
        entry.message.messageId = '100';
        entry.message.sourceMessageIds = ['100', '101', '102'];
        expect(timelineEntryContainsMessageId(entry, '101')).assertTrue();
        expect(timelineEntryContainsMessageId(entry, '999')).assertFalse();
      });
    });

    // -----------------------------------------------------------------------
    // Chat date separator labels
    // -----------------------------------------------------------------------
    describe('formatChatDateSeparatorLabel', () => {

      it('should use localized month and day instead of a weekday for recent dates', 0, () => {
        const label = composeChatDateSeparatorLabel(
          14, 'July', 2026, false, '{month} {day}', '{month} {day}, {year}');
        expect(label).assertEqual('July 14');
      });

      it('should include the year only when the message is from another year', 0, () => {
        const label = composeChatDateSeparatorLabel(
          14, 'July', 2025, true, '{month} {day}', '{month} {day}, {year}');
        expect(label).assertEqual('July 14, 2025');
      });

      it('should respect app-language word order and genitive month forms', 0, () => {
        const label = composeChatDateSeparatorLabel(
          14, 'июля', 2026, false, '{day} {month}', '{day} {month} {year}');
        expect(label).assertEqual('14 июля');
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

    // -----------------------------------------------------------------------
    // PendingMediaOpenIntent — download completion continuation
    // -----------------------------------------------------------------------
    describe('PendingMediaOpenIntent', () => {

      it('should stay unresolved when no local document path exists yet', 0, () => {
        const intent = new PendingMediaOpenIntent();
        intent.set('document', 42, 'm1', 'application/pdf', 100, 7);

        const entry = makePendingMediaEntry('m1');
        entry.message.documentFileId = 42;

        const resolution = resolvePendingMediaOpenIntent(intent, [entry], 100, 7);
        expect(resolution === undefined).assertTrue();
      });

      it('should resolve a downloaded document for the tapped message', 0, () => {
        const intent = new PendingMediaOpenIntent();
        intent.set('document', 42, 'm1', 'application/pdf', 100, 7);

        const entry = makePendingMediaEntry('m1');
        entry.message.documentFileId = 42;
        entry.message.documentPath = 'file://docs/report.pdf';

        const resolution = resolvePendingMediaOpenIntent(intent, [entry], 100, 7);
        expect(resolution !== undefined).assertTrue();
        if (resolution) {
          expect(resolution.kind).assertEqual('document');
          expect(resolution.fileId).assertEqual(42);
          expect(resolution.messageId).assertEqual('m1');
          expect(resolution.path).assertEqual('file://docs/report.pdf');
          expect(resolution.mimeType).assertEqual('application/pdf');
        }
      });

      it('should resolve downloaded audio with raw playback path', 0, () => {
        const intent = new PendingMediaOpenIntent();
        intent.set('audio', 77, 'song', 'audio/mpeg', 100, 7);

        const entry = makePendingMediaEntry('song');
        entry.message.audioFileId = 77;
        entry.message.audioPath = '/data/storage/song.mp3';

        const resolution = resolvePendingMediaOpenIntent(intent, [entry], 100, 7);
        expect(resolution !== undefined).assertTrue();
        if (resolution) {
          expect(resolution.kind).assertEqual('audio');
          expect(resolution.path).assertEqual('/data/storage/song.mp3');
        }
      });

      it('should resolve downloaded voice with raw playback path', 0, () => {
        const intent = new PendingMediaOpenIntent();
        intent.set('voice', 88, 'voice1', '', 100, 7);

        const entry = makePendingMediaEntry('voice1');
        entry.message.voiceFileId = 88;
        entry.message.voicePath = '/data/storage/voice.ogg';
        entry.message.mimeType = 'audio/ogg';

        const resolution = resolvePendingMediaOpenIntent(intent, [entry], 100, 7);
        expect(resolution !== undefined).assertTrue();
        if (resolution) {
          expect(resolution.kind).assertEqual('voice');
          expect(resolution.path).assertEqual('/data/storage/voice.ogg');
          expect(resolution.mimeType).assertEqual('audio/ogg');
        }
      });

      it('should ignore stale chat, lifecycle, or different message matches', 0, () => {
        const intent = new PendingMediaOpenIntent();
        intent.set('audio', 77, 'song', 'audio/mpeg', 100, 7);

        const entry = makePendingMediaEntry('other');
        entry.message.audioFileId = 77;
        entry.message.audioPath = '/data/storage/song.mp3';

        expect(resolvePendingMediaOpenIntent(intent, [entry], 100, 7) === undefined).assertTrue();
        expect(resolvePendingMediaOpenIntent(intent, [entry], 101, 7) === undefined).assertTrue();
        expect(resolvePendingMediaOpenIntent(intent, [entry], 100, 8) === undefined).assertTrue();
      });
    });

    // -----------------------------------------------------------------------
    // MediaGalleryState — open gallery refresh after download/file update
    // -----------------------------------------------------------------------
    describe('MediaGalleryState', () => {

      it('should preserve current gallery item by message and file identity after refresh', 0, () => {
        const previous = [
          makeGalleryItem('photo-1', 11),
          makeGalleryItem('video-1', 22, 'video')
        ];
        const refreshed = [
          makeGalleryItem('photo-1', 11, 'photo', '/data/photo.jpg'),
          makeGalleryItem('video-1', 22, 'video', '/data/video.mp4')
        ];

        const result = resolveRefreshedMediaGalleryState(previous, 1, refreshed);

        expect(result.shouldClose).assertFalse();
        expect(result.currentIndex).assertEqual(1);
        expect(result.sourceMessageId).assertEqual('video-1');
        expect(result.items[1].path).assertEqual('/data/video.mp4');
      });

      it('should clamp gallery index when the current item disappears', 0, () => {
        const previous = [
          makeGalleryItem('photo-1', 11),
          makeGalleryItem('video-1', 22, 'video')
        ];
        const refreshed = [
          makeGalleryItem('photo-1', 11)
        ];

        const result = resolveRefreshedMediaGalleryState(previous, 1, refreshed);

        expect(result.shouldClose).assertFalse();
        expect(result.currentIndex).assertEqual(0);
        expect(result.sourceMessageId).assertEqual('photo-1');
      });

      it('should request gallery close when refreshed media list is empty', 0, () => {
        const result = resolveRefreshedMediaGalleryState([makeGalleryItem('photo-1', 11)], 0, []);

        expect(result.shouldClose).assertTrue();
        expect(result.currentIndex).assertEqual(0);
        expect(result.sourceMessageId).assertEqual('0');
        expect(result.items.length).assertEqual(0);
      });
    });
  });
}

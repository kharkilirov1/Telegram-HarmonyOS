import { describe, it, expect } from '@ohos/hypium';
import { MessageContentType } from '../../../main/ets/models/Message';
import {
  parseMessage,
  applyContent,
  extractTextPreview,
  parseChat,
  updateChatPositions,
  decodeWaveform
} from '../../../main/ets/controllers/TdMessageParser';
import { TdMessage, TdChat } from '../../../main/ets/models/TdTypes';
import { Message } from '../../../main/ets/models/Message';
import { Chat } from '../../../main/ets/models/Chat';

/**
 * Unit tests for TdMessageParser — the pure parsing/mapping layer.
 * All functions are stateless and side-effect-free (except TdFallbackRegistry
 * logging on unknown types, which is harmless in tests).
 */

// Helper to build a minimal TdMessage-shaped Record
function makeTdMsg(overrides: Record<string, Object>): TdMessage {
  const base: Record<string, Object> = {};
  base['id'] = 1;
  base['chat_id'] = 100;
  base['date'] = 1700000000;
  base['is_outgoing'] = false;
  // Apply overrides
  const keys = Object.keys(overrides);
  for (const key of keys) {
    base[key] = overrides[key];
  }
  return base as unknown as TdMessage;
}

function makeContent(type: string, extra?: Record<string, Object>): Record<string, Object> {
  const content: Record<string, Object> = {};
  content['@type'] = type;
  if (extra) {
    const keys = Object.keys(extra);
    for (const key of keys) {
      content[key] = extra[key];
    }
  }
  return content;
}

export default function tdMessageParserTest() {
  describe('TdMessageParser', () => {

    // -----------------------------------------------------------------------
    // parseMessage
    // -----------------------------------------------------------------------
    describe('parseMessage', () => {

      it('should parse basic message fields', 0, () => {
        const raw = makeTdMsg({});
        const msg = parseMessage(raw);

        expect(msg.id).assertEqual(1);
        expect(msg.chatId).assertEqual(100);
        expect(msg.date).assertEqual(1700000000);
        expect(msg.isOutgoing).assertFalse();
      });

      it('should parse outgoing flag', 0, () => {
        const overrides: Record<string, Object> = {};
        overrides['is_outgoing'] = true;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);
        expect(msg.isOutgoing).assertTrue();
      });

      it('should parse text message content', 0, () => {
        const textObj: Record<string, Object> = {};
        textObj['text'] = 'Hello TDLib';
        const content = makeContent('messageText');
        content['text'] = textObj;
        const overrides: Record<string, Object> = {};
        overrides['content'] = content;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.contentType).assertEqual(MessageContentType.TEXT);
        expect(msg.text).assertEqual('Hello TDLib');
      });

      it('should parse photo message with caption', 0, () => {
        const caption: Record<string, Object> = {};
        caption['text'] = 'Nice view';
        const content = makeContent('messagePhoto');
        content['caption'] = caption;
        const overrides: Record<string, Object> = {};
        overrides['content'] = content;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.contentType).assertEqual(MessageContentType.PHOTO);
        expect(msg.text).assertEqual('Nice view');
      });

      it('should parse video message with duration', 0, () => {
        const video: Record<string, Object> = {};
        video['duration'] = 120;
        const caption: Record<string, Object> = {};
        caption['text'] = '';
        const content = makeContent('messageVideo');
        content['video'] = video;
        content['caption'] = caption;
        const overrides: Record<string, Object> = {};
        overrides['content'] = content;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.contentType).assertEqual(MessageContentType.VIDEO);
        expect(msg.videoDuration).assertEqual(120);
      });

      it('should parse document message with file name', 0, () => {
        const doc: Record<string, Object> = {};
        doc['file_name'] = 'report.pdf';
        const content = makeContent('messageDocument');
        content['document'] = doc;
        const overrides: Record<string, Object> = {};
        overrides['content'] = content;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.contentType).assertEqual(MessageContentType.DOCUMENT);
        expect(msg.fileName).assertEqual('report.pdf');
      });

      it('should parse voice note with duration and waveform', 0, () => {
        const voice: Record<string, Object> = {};
        voice['duration'] = 15;
        voice['waveform'] = 'AQID';
        const content = makeContent('messageVoiceNote');
        content['voice_note'] = voice;
        const overrides: Record<string, Object> = {};
        overrides['content'] = content;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.contentType).assertEqual(MessageContentType.VOICE);
        expect(msg.voiceDuration).assertEqual(15);
        expect(msg.voiceWaveform.length).assertEqual(4);
      });

      it('should parse sticker message with emoji', 0, () => {
        const sticker: Record<string, Object> = {};
        sticker['emoji'] = '\u{1F60E}';
        const content = makeContent('messageSticker');
        content['sticker'] = sticker;
        const overrides: Record<string, Object> = {};
        overrides['content'] = content;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.contentType).assertEqual(MessageContentType.STICKER);
        expect(msg.text).assertEqual('\u{1F60E}');
      });

      it('should parse animation message', 0, () => {
        const content = makeContent('messageAnimation');
        const overrides: Record<string, Object> = {};
        overrides['content'] = content;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.contentType).assertEqual(MessageContentType.ANIMATION);
        expect(msg.text).assertEqual('GIF');
      });

      it('should parse video note with dimensions', 0, () => {
        const videoNote: Record<string, Object> = {};
        videoNote['duration'] = 10;
        videoNote['length'] = 200;
        const content = makeContent('messageVideoNote');
        content['video_note'] = videoNote;
        const overrides: Record<string, Object> = {};
        overrides['content'] = content;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.contentType).assertEqual(MessageContentType.VIDEO_NOTE);
        expect(msg.videoNoteDuration).assertEqual(10);
        expect(msg.videoNoteLength).assertEqual(200);
      });

      it('should set UNSUPPORTED for unknown content types', 0, () => {
        const content = makeContent('messageLocation');
        const overrides: Record<string, Object> = {};
        overrides['content'] = content;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.contentType).assertEqual(MessageContentType.UNSUPPORTED);
        expect(msg.text).assertEqual('[Location]');
      });

      it('should parse reply_to message id', 0, () => {
        const replyTo: Record<string, Object> = {};
        replyTo['@type'] = 'messageReplyToMessage';
        replyTo['message_id'] = 42;
        const overrides: Record<string, Object> = {};
        overrides['reply_to'] = replyTo;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.replyToMessageId).assertEqual(42);
      });

      it('should parse forward info', 0, () => {
        const origin: Record<string, Object> = {};
        origin['sender_name'] = 'Alice';
        const forwardInfo: Record<string, Object> = {};
        forwardInfo['origin'] = origin;
        const overrides: Record<string, Object> = {};
        overrides['forward_info'] = forwardInfo;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.forwardedFrom).assertEqual('Alice');
      });

      it('should parse media_album_id', 0, () => {
        const overrides: Record<string, Object> = {};
        overrides['media_album_id'] = '12345';
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.mediaAlbumId).assertEqual('12345');
      });

      it('should detect view-once (self-destruct immediately)', 0, () => {
        const selfDestruct: Record<string, Object> = {};
        selfDestruct['@type'] = 'messageSelfDestructTypeImmediately';
        selfDestruct['self_destruct_time'] = 0;
        const overrides: Record<string, Object> = {};
        overrides['self_destruct_type'] = selfDestruct;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.isViewOnce).assertTrue();
      });

      it('should detect spoiler on photo content', 0, () => {
        const content = makeContent('messagePhoto');
        content['has_spoiler'] = true;
        const overrides: Record<string, Object> = {};
        overrides['content'] = content;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.hasSpoiler).assertTrue();
      });
    });

    // -----------------------------------------------------------------------
    // parseChat
    // -----------------------------------------------------------------------
    describe('parseChat', () => {

      it('should parse basic chat fields', 0, () => {
        const raw: Record<string, Object> = {};
        raw['id'] = 200;
        raw['title'] = 'Test Group';
        raw['unread_count'] = 5;
        const chat = parseChat(raw as unknown as TdChat);

        expect(chat.id).assertEqual(200);
        expect(chat.title).assertEqual('Test Group');
        expect(chat.unreadCount).assertEqual(5);
      });

      it('should detect supergroup type', 0, () => {
        const chatType: Record<string, Object> = {};
        chatType['@type'] = 'chatTypeSupergroup';
        chatType['is_channel'] = false;
        const raw: Record<string, Object> = {};
        raw['id'] = 300;
        raw['title'] = 'Big Group';
        raw['type'] = chatType;
        const chat = parseChat(raw as unknown as TdChat);

        expect(chat.isGroup).assertTrue();
        expect(chat.isChannel).assertFalse();
      });

      it('should detect channel type', 0, () => {
        const chatType: Record<string, Object> = {};
        chatType['@type'] = 'chatTypeSupergroup';
        chatType['is_channel'] = true;
        const raw: Record<string, Object> = {};
        raw['id'] = 400;
        raw['title'] = 'My Channel';
        raw['type'] = chatType;
        const chat = parseChat(raw as unknown as TdChat);

        expect(chat.isGroup).assertTrue();
        expect(chat.isChannel).assertTrue();
      });

      it('should detect muted status from notification settings', 0, () => {
        const notif: Record<string, Object> = {};
        notif['mute_for'] = 86400;
        const raw: Record<string, Object> = {};
        raw['id'] = 500;
        raw['title'] = 'Muted Chat';
        raw['notification_settings'] = notif;
        const chat = parseChat(raw as unknown as TdChat);

        expect(chat.isMuted).assertTrue();
      });

      it('should parse last message preview', 0, () => {
        const textObj: Record<string, Object> = {};
        textObj['text'] = 'Last msg';
        const content: Record<string, Object> = {};
        content['@type'] = 'messageText';
        content['text'] = textObj;
        const lastMsg: Record<string, Object> = {};
        lastMsg['content'] = content;
        lastMsg['date'] = 1700000000;
        const raw: Record<string, Object> = {};
        raw['id'] = 600;
        raw['title'] = 'Chat';
        raw['last_message'] = lastMsg;
        const chat = parseChat(raw as unknown as TdChat);

        expect(chat.lastMessage).assertEqual('Last msg');
        expect(chat.lastMessageDate).assertEqual(1700000000);
      });
    });

    // -----------------------------------------------------------------------
    // updateChatPositions
    // -----------------------------------------------------------------------
    describe('updateChatPositions', () => {

      it('should update order and pinned from chatListMain position', 0, () => {
        const chat = new Chat(1, 'Test');
        const list: Record<string, Object> = {};
        list['@type'] = 'chatListMain';
        const position: Record<string, Object> = {};
        position['list'] = list;
        position['order'] = '69175290';
        position['is_pinned'] = true;

        updateChatPositions(chat, [position as unknown as import('../../../main/ets/models/TdTypes').TdChatPosition]);

        expect(chat.order).assertEqual('69175290');
        expect(chat.isPinned).assertTrue();
      });

      it('should ignore non-main chat list positions', 0, () => {
        const chat = new Chat(1, 'Test');
        chat.order = '0';
        const list: Record<string, Object> = {};
        list['@type'] = 'chatListArchive';
        const position: Record<string, Object> = {};
        position['list'] = list;
        position['order'] = '99999';
        position['is_pinned'] = false;

        updateChatPositions(chat, [position as unknown as import('../../../main/ets/models/TdTypes').TdChatPosition]);

        expect(chat.order).assertEqual('0');
      });
    });

    // -----------------------------------------------------------------------
    // applyContent edge cases
    // -----------------------------------------------------------------------
    describe('applyContent edge cases', () => {

      it('should handle poll with all fields', 0, () => {
        const questionText: Record<string, Object> = {};
        questionText['text'] = 'Best OS?';
        const opt1Text: Record<string, Object> = {};
        opt1Text['text'] = 'HarmonyOS';
        const opt2Text: Record<string, Object> = {};
        opt2Text['text'] = 'Other';
        const opt1: Record<string, Object> = {};
        opt1['text'] = opt1Text;
        opt1['voter_count'] = 10;
        opt1['vote_percentage'] = 67;
        opt1['is_chosen'] = true;
        const opt2: Record<string, Object> = {};
        opt2['text'] = opt2Text;
        opt2['voter_count'] = 5;
        opt2['vote_percentage'] = 33;
        opt2['is_chosen'] = false;
        const pollType: Record<string, Object> = {};
        pollType['@type'] = 'pollTypeRegular';
        const poll: Record<string, Object> = {};
        poll['id'] = 'poll123';
        poll['question'] = questionText;
        poll['total_voter_count'] = 15;
        poll['is_closed'] = false;
        poll['is_anonymous'] = true;
        poll['type'] = pollType;
        poll['options'] = [opt1, opt2];

        const content: Record<string, Object> = {};
        content['@type'] = 'messagePoll';
        content['poll'] = poll;

        const msg = new Message(1, 100, 0, '', '', 0, false, false, 0, MessageContentType.TEXT, null, null);
        applyContent(msg, content as unknown as import('../../../main/ets/models/TdTypes').TdMessageContent);

        expect(msg.contentType).assertEqual(MessageContentType.POLL);
        expect(msg.pollQuestion).assertEqual('Best OS?');
        expect(msg.pollTotalVoterCount).assertEqual(15);
        expect(msg.pollOptions.length).assertEqual(2);
        expect(msg.pollOptions[0].text).assertEqual('HarmonyOS');
        expect(msg.pollOptions[0].isChosen).assertTrue();
        expect(msg.pollType).assertEqual('regular');
      });

      it('should handle quiz poll type', 0, () => {
        const questionText: Record<string, Object> = {};
        questionText['text'] = 'Quiz?';
        const pollType: Record<string, Object> = {};
        pollType['@type'] = 'pollTypeQuiz';
        const poll: Record<string, Object> = {};
        poll['id'] = 'quiz1';
        poll['question'] = questionText;
        poll['type'] = pollType;

        const content: Record<string, Object> = {};
        content['@type'] = 'messagePoll';
        content['poll'] = poll;

        const msg = new Message(1, 100, 0, '', '', 0, false, false, 0, MessageContentType.TEXT, null, null);
        applyContent(msg, content as unknown as import('../../../main/ets/models/TdTypes').TdMessageContent);

        expect(msg.pollType).assertEqual('quiz');
      });
    });
  });
}

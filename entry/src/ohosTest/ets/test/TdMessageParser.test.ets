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
import { TdMessage, TdChat, TdChatPosition, TdMessageContent } from '../../../main/ets/models/TdTypes';
import { Message } from '../../../main/ets/models/Message';
import { Chat } from '../../../main/ets/models/Chat';

/**
 * Unit tests for TdMessageParser — the pure parsing/mapping layer.
 * All functions are stateless and side-effect-free (except TdFallbackRegistry
 * logging on unknown types, which is harmless in tests).
 */

// Helper to build a minimal TdMessage-shaped Record
function makeTdMsg(overrides: Record<string, unknown>): TdMessage {
  const base: Record<string, unknown> = {};
  base['id'] = 1;
  base['chat_id'] = 100;
  base['date'] = 1700000000;
  base['is_outgoing'] = false;
  // Apply overrides
  const keys = Object.keys(overrides);
  for (const key of keys) {
    base[key] = overrides[key];
  }
  return base as TdMessage;
}

function makeContent(type: string, extra?: Record<string, unknown>): Record<string, unknown> {
  const content: Record<string, unknown> = {};
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
        const overrides: Record<string, unknown> = {};
        overrides['is_outgoing'] = true;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);
        expect(msg.isOutgoing).assertTrue();
      });

      it('should parse text message content', 0, () => {
        const textObj: Record<string, unknown> = {};
        textObj['text'] = 'Hello TDLib';
        const content = makeContent('messageText');
        content['text'] = textObj;
        const overrides: Record<string, unknown> = {};
        overrides['content'] = content;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.contentType).assertEqual(MessageContentType.TEXT);
        expect(msg.text).assertEqual('Hello TDLib');
      });

      it('should parse photo message with caption', 0, () => {
        const caption: Record<string, unknown> = {};
        caption['text'] = 'Nice view';
        const content = makeContent('messagePhoto');
        content['caption'] = caption;
        const overrides: Record<string, unknown> = {};
        overrides['content'] = content;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.contentType).assertEqual(MessageContentType.PHOTO);
        expect(msg.text).assertEqual('Nice view');
      });

      it('should parse video message with duration', 0, () => {
        const video: Record<string, unknown> = {};
        video['duration'] = 120;
        const caption: Record<string, unknown> = {};
        caption['text'] = '';
        const content = makeContent('messageVideo');
        content['video'] = video;
        content['caption'] = caption;
        const overrides: Record<string, unknown> = {};
        overrides['content'] = content;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.contentType).assertEqual(MessageContentType.VIDEO);
        expect(msg.videoDuration).assertEqual(120);
      });

      it('should parse document message with file name', 0, () => {
        const doc: Record<string, unknown> = {};
        doc['file_name'] = 'report.pdf';
        const content = makeContent('messageDocument');
        content['document'] = doc;
        const overrides: Record<string, unknown> = {};
        overrides['content'] = content;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.contentType).assertEqual(MessageContentType.DOCUMENT);
        expect(msg.fileName).assertEqual('report.pdf');
      });

      it('should parse document local path and size', 0, () => {
        const local: Record<string, unknown> = {};
        local['path'] = '/data/report.pdf';
        local['is_downloading_completed'] = true;

        const file: Record<string, unknown> = {};
        file['id'] = 3001;
        file['size'] = 2048;
        file['local'] = local;

        const doc: Record<string, unknown> = {};
        doc['file_name'] = 'report.pdf';
        doc['document'] = file;

        const content = makeContent('messageDocument');
        content['document'] = doc;

        const overrides: Record<string, unknown> = {};
        overrides['content'] = content;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.contentType).assertEqual(MessageContentType.DOCUMENT);
        expect(msg.fileId).assertEqual(3001);
        expect(msg.fileSize).assertEqual(2048);
        expect(msg.filePath).assertEqual('/data/report.pdf');
      });

      it('should parse voice note with duration and waveform', 0, () => {
        const voice: Record<string, unknown> = {};
        voice['duration'] = 15;
        voice['waveform'] = 'AQID';
        const content = makeContent('messageVoiceNote');
        content['voice_note'] = voice;
        const overrides: Record<string, unknown> = {};
        overrides['content'] = content;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.contentType).assertEqual(MessageContentType.VOICE);
        expect(msg.voiceDuration).assertEqual(15);
        expect(msg.voiceWaveform.length).assertEqual(4);
      });

      it('should parse sticker message with emoji', 0, () => {
        const sticker: Record<string, unknown> = {};
        sticker['emoji'] = '\u{1F60E}';
        const content = makeContent('messageSticker');
        content['sticker'] = sticker;
        const overrides: Record<string, unknown> = {};
        overrides['content'] = content;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.contentType).assertEqual(MessageContentType.STICKER);
        expect(msg.text).assertEqual('\u{1F60E}');
      });

      it('should parse animation message', 0, () => {
        const content = makeContent('messageAnimation');
        const overrides: Record<string, unknown> = {};
        overrides['content'] = content;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.contentType).assertEqual(MessageContentType.ANIMATION);
        expect(msg.text).assertEqual('GIF');
      });

      it('should parse animation video path and thumbnail', 0, () => {
        const localAnimation: Record<string, unknown> = {};
        localAnimation['path'] = '/data/animation.mp4';
        localAnimation['is_downloading_completed'] = true;

        const animationFile: Record<string, unknown> = {};
        animationFile['id'] = 3501;
        animationFile['size'] = 4096;
        animationFile['local'] = localAnimation;

        const localThumb: Record<string, unknown> = {};
        localThumb['path'] = '/data/animation_thumb.jpg';
        localThumb['is_downloading_completed'] = true;

        const thumbFile: Record<string, unknown> = {};
        thumbFile['id'] = 3502;
        thumbFile['local'] = localThumb;

        const thumbnail: Record<string, unknown> = {};
        thumbnail['file'] = thumbFile;

        const animation: Record<string, unknown> = {};
        animation['duration'] = 3;
        animation['animation'] = animationFile;
        animation['thumbnail'] = thumbnail;

        const content = makeContent('messageAnimation');
        content['animation'] = animation;

        const overrides: Record<string, unknown> = {};
        overrides['content'] = content;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.contentType).assertEqual(MessageContentType.ANIMATION);
        expect(msg.videoUrl).assertEqual('/data/animation.mp4');
        expect(msg.photoUrl).assertEqual('/data/animation_thumb.jpg');
        expect(msg.fileId).assertEqual(3501);
        expect(msg.fileSize).assertEqual(4096);
      });

      it('should parse video note with dimensions', 0, () => {
        const videoNote: Record<string, unknown> = {};
        videoNote['duration'] = 10;
        videoNote['length'] = 200;
        const content = makeContent('messageVideoNote');
        content['video_note'] = videoNote;
        const overrides: Record<string, unknown> = {};
        overrides['content'] = content;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.contentType).assertEqual(MessageContentType.VIDEO_NOTE);
        expect(msg.videoNoteDuration).assertEqual(10);
        expect(msg.videoNoteLength).assertEqual(200);
      });

      it('should set UNSUPPORTED for unknown content types', 0, () => {
        const content = makeContent('messageUnknownCustomType');
        const overrides: Record<string, unknown> = {};
        overrides['content'] = content;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.contentType).assertEqual(MessageContentType.UNSUPPORTED);
        expect(msg.text).assertEqual('[UnknownCustomType]');
      });

      it('should parse reply_to message id', 0, () => {
        const replyTo: Record<string, unknown> = {};
        replyTo['@type'] = 'messageReplyToMessage';
        replyTo['message_id'] = 42;
        const overrides: Record<string, unknown> = {};
        overrides['reply_to'] = replyTo;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.replyToMessageId).assertEqual(42);
      });

      it('should parse forward info', 0, () => {
        const origin: Record<string, unknown> = {};
        origin['sender_name'] = 'Alice';
        const forwardInfo: Record<string, unknown> = {};
        forwardInfo['origin'] = origin;
        const overrides: Record<string, unknown> = {};
        overrides['forward_info'] = forwardInfo;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.forwardedFrom).assertEqual('Alice');
      });

      it('should parse media_album_id', 0, () => {
        const overrides: Record<string, unknown> = {};
        overrides['media_album_id'] = '12345';
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.mediaAlbumId).assertEqual('12345');
      });

      it('should detect view-once (self-destruct immediately)', 0, () => {
        const selfDestruct: Record<string, unknown> = {};
        selfDestruct['@type'] = 'messageSelfDestructTypeImmediately';
        selfDestruct['self_destruct_time'] = 0;
        const overrides: Record<string, unknown> = {};
        overrides['self_destruct_type'] = selfDestruct;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.isViewOnce).assertTrue();
      });

      it('should detect spoiler on photo content', 0, () => {
        const content = makeContent('messagePhoto');
        content['has_spoiler'] = true;
        const overrides: Record<string, unknown> = {};
        overrides['content'] = content;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.hasSpoiler).assertTrue();
      });

      it('should parse local photo path from largest available size', 0, () => {
        const localFileA: Record<string, unknown> = {};
        localFileA['path'] = '';
        localFileA['is_downloading_completed'] = false;

        const localFileB: Record<string, unknown> = {};
        localFileB['path'] = '/data/photo_big.jpg';
        localFileB['is_downloading_completed'] = true;

        const photoFileA: Record<string, unknown> = {};
        photoFileA['id'] = 1001;
        photoFileA['local'] = localFileA;

        const photoFileB: Record<string, unknown> = {};
        photoFileB['id'] = 1002;
        photoFileB['local'] = localFileB;

        const sizeA: Record<string, unknown> = {};
        sizeA['photo'] = photoFileA;
        const sizeB: Record<string, unknown> = {};
        sizeB['photo'] = photoFileB;

        const photo: Record<string, unknown> = {};
        photo['sizes'] = [sizeA, sizeB];

        const content = makeContent('messagePhoto');
        content['photo'] = photo;

        const overrides: Record<string, unknown> = {};
        overrides['content'] = content;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.contentType).assertEqual(MessageContentType.PHOTO);
        expect(msg.photoUrl).assertEqual('/data/photo_big.jpg');
        expect(msg.photoFileId).assertEqual(1002);
      });

      it('should parse local video path and thumbnail path', 0, () => {
        const localVideo: Record<string, unknown> = {};
        localVideo['path'] = '/data/video.mp4';
        localVideo['is_downloading_completed'] = true;

        const videoFile: Record<string, unknown> = {};
        videoFile['id'] = 2001;
        videoFile['local'] = localVideo;

        const localThumb: Record<string, unknown> = {};
        localThumb['path'] = '/data/video_thumb.jpg';
        localThumb['is_downloading_completed'] = true;

        const thumbFile: Record<string, unknown> = {};
        thumbFile['id'] = 2002;
        thumbFile['local'] = localThumb;

        const thumbnail: Record<string, unknown> = {};
        thumbnail['file'] = thumbFile;

        const video: Record<string, unknown> = {};
        video['duration'] = 15;
        video['video'] = videoFile;
        video['thumbnail'] = thumbnail;

        const content = makeContent('messageVideo');
        content['video'] = video;

        const overrides: Record<string, unknown> = {};
        overrides['content'] = content;
        const raw = makeTdMsg(overrides);
        const msg = parseMessage(raw);

        expect(msg.contentType).assertEqual(MessageContentType.VIDEO);
        expect(msg.videoUrl).assertEqual('/data/video.mp4');
        expect(msg.photoUrl).assertEqual('/data/video_thumb.jpg');
      });
    });

    // -----------------------------------------------------------------------
    // parseChat
    // -----------------------------------------------------------------------
    describe('parseChat', () => {

      it('should parse basic chat fields', 0, () => {
        const raw: Record<string, unknown> = {};
        raw['id'] = 200;
        raw['title'] = 'Test Group';
        raw['unread_count'] = 5;
        const chat = parseChat(raw as TdChat);

        expect(chat.id).assertEqual(200);
        expect(chat.title).assertEqual('Test Group');
        expect(chat.unreadCount).assertEqual(5);
      });

      it('should detect supergroup type', 0, () => {
        const chatType: Record<string, unknown> = {};
        chatType['@type'] = 'chatTypeSupergroup';
        chatType['is_channel'] = false;
        const raw: Record<string, unknown> = {};
        raw['id'] = 300;
        raw['title'] = 'Big Group';
        raw['type'] = chatType;
        const chat = parseChat(raw as TdChat);

        expect(chat.isGroup).assertTrue();
        expect(chat.isChannel).assertFalse();
      });

      it('should detect channel type', 0, () => {
        const chatType: Record<string, unknown> = {};
        chatType['@type'] = 'chatTypeSupergroup';
        chatType['is_channel'] = true;
        const raw: Record<string, unknown> = {};
        raw['id'] = 400;
        raw['title'] = 'My Channel';
        raw['type'] = chatType;
        const chat = parseChat(raw as TdChat);

        expect(chat.isGroup).assertTrue();
        expect(chat.isChannel).assertTrue();
      });

      it('should detect muted status from notification settings', 0, () => {
        const notif: Record<string, unknown> = {};
        notif['mute_for'] = 86400;
        const raw: Record<string, unknown> = {};
        raw['id'] = 500;
        raw['title'] = 'Muted Chat';
        raw['notification_settings'] = notif;
        const chat = parseChat(raw as TdChat);

        expect(chat.isMuted).assertTrue();
      });

      it('should parse last message preview', 0, () => {
        const textObj: Record<string, unknown> = {};
        textObj['text'] = 'Last msg';
        const content: Record<string, unknown> = {};
        content['@type'] = 'messageText';
        content['text'] = textObj;
        const lastMsg: Record<string, unknown> = {};
        lastMsg['content'] = content;
        lastMsg['date'] = 1700000000;
        const raw: Record<string, unknown> = {};
        raw['id'] = 600;
        raw['title'] = 'Chat';
        raw['last_message'] = lastMsg;
        const chat = parseChat(raw as TdChat);

        expect(chat.lastMessage).assertEqual('Last msg');
        expect(chat.lastMessageDate).assertEqual(1700000000);
      });

      it('should parse is_marked_as_unread flag', 0, () => {
        const raw: Record<string, unknown> = {};
        raw['id'] = 601;
        raw['title'] = 'Unread marker chat';
        raw['is_marked_as_unread'] = true;

        const chat = parseChat(raw as TdChat);
        expect(chat.isMarkedAsUnread).assertTrue();
      });
    });

    // -----------------------------------------------------------------------
    // updateChatPositions
    // -----------------------------------------------------------------------
    describe('updateChatPositions', () => {

      it('should update order and pinned from chatListMain position', 0, () => {
        const chat = new Chat(1, 'Test');
        const list: Record<string, unknown> = {};
        list['@type'] = 'chatListMain';
        const position: Record<string, unknown> = {};
        position['list'] = list;
        position['order'] = '69175290';
        position['is_pinned'] = true;

        updateChatPositions(chat, [position as TdChatPosition]);

        expect(chat.order).assertEqual('69175290');
        expect(chat.isPinned).assertTrue();
      });

      it('should ignore non-main chat list positions', 0, () => {
        const chat = new Chat(1, 'Test');
        chat.order = '0';
        const list: Record<string, unknown> = {};
        list['@type'] = 'chatListArchive';
        const position: Record<string, unknown> = {};
        position['list'] = list;
        position['order'] = '99999';
        position['is_pinned'] = false;

        updateChatPositions(chat, [position as TdChatPosition]);

        expect(chat.order).assertEqual('0');
      });
    });

    // -----------------------------------------------------------------------
    // applyContent edge cases
    // -----------------------------------------------------------------------
    describe('applyContent edge cases', () => {

      it('should handle poll with all fields', 0, () => {
        const questionText: Record<string, unknown> = {};
        questionText['text'] = 'Best OS?';
        const opt1Text: Record<string, unknown> = {};
        opt1Text['text'] = 'HarmonyOS';
        const opt2Text: Record<string, unknown> = {};
        opt2Text['text'] = 'Other';
        const opt1: Record<string, unknown> = {};
        opt1['text'] = opt1Text;
        opt1['voter_count'] = 10;
        opt1['vote_percentage'] = 67;
        opt1['is_chosen'] = true;
        const opt2: Record<string, unknown> = {};
        opt2['text'] = opt2Text;
        opt2['voter_count'] = 5;
        opt2['vote_percentage'] = 33;
        opt2['is_chosen'] = false;
        const pollType: Record<string, unknown> = {};
        pollType['@type'] = 'pollTypeRegular';
        const poll: Record<string, unknown> = {};
        poll['id'] = 'poll123';
        poll['question'] = questionText;
        poll['total_voter_count'] = 15;
        poll['is_closed'] = false;
        poll['is_anonymous'] = true;
        poll['type'] = pollType;
        poll['options'] = [opt1, opt2];

        const content: Record<string, unknown> = {};
        content['@type'] = 'messagePoll';
        content['poll'] = poll;

        const msg = new Message(1, 100, 0, '', '', 0, false, false, 0, MessageContentType.TEXT, null, null);
        applyContent(msg, content as TdMessageContent);

        expect(msg.contentType).assertEqual(MessageContentType.POLL);
        expect(msg.pollQuestion).assertEqual('Best OS?');
        expect(msg.pollTotalVoterCount).assertEqual(15);
        expect(msg.pollOptions.length).assertEqual(2);
        expect(msg.pollOptions[0].text).assertEqual('HarmonyOS');
        expect(msg.pollOptions[0].isChosen).assertTrue();
        expect(msg.pollType).assertEqual('regular');
      });

      it('should handle quiz poll type', 0, () => {
        const questionText: Record<string, unknown> = {};
        questionText['text'] = 'Quiz?';
        const pollType: Record<string, unknown> = {};
        pollType['@type'] = 'pollTypeQuiz';
        const poll: Record<string, unknown> = {};
        poll['id'] = 'quiz1';
        poll['question'] = questionText;
        poll['type'] = pollType;

        const content: Record<string, unknown> = {};
        content['@type'] = 'messagePoll';
        content['poll'] = poll;

        const msg = new Message(1, 100, 0, '', '', 0, false, false, 0, MessageContentType.TEXT, null, null);
        applyContent(msg, content as TdMessageContent);

        expect(msg.pollType).assertEqual('quiz');
      });
    });
  });
}

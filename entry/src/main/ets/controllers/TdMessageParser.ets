// TdMessageParser — pure parsing/mapping layer for TDLib responses
// Extracted from MessagesController to separate parsing from state management
// Reference: Telegram iOS MessageUtils, Android MessageObject

import { Chat } from '../models/Chat';
import { Message, MessageContentType } from '../models/Message';
import { TdFallbackRegistry } from '../services/TdFallbackRegistry';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'TdMessageParser';
const DOMAIN = 0x0001;
import {
  tdType,
  TdMessage,
  TdMessageContent,
  TdMessageSender,
  TdFormattedText,
  TdVideo,
  TdDocument,
  TdVoiceNote,
  TdVideoNote,
  TdSticker,
  TdPoll,
  TdPollOption,
  TdPollType,
  TdReplyTo,
  TdForwardInfo,
  TdMessageOrigin,
  TdSchedulingState,
  TdSelfDestructType,
  TdChat,
  TdChatPosition,
  TdChatType,
  TdNotificationSettings,
  TdFile,
  PollOptionDisplay
} from '../models/TdTypes';

// --- Message parsing ---

export function parseMessage(raw: TdMessage): Message {
  const content: TdMessageContent | undefined = raw.content;
  const sender: TdMessageSender | undefined = raw.sender_id;

  const msg = new Message(
    raw.id || 0,
    raw.chat_id || 0,
    sender?.user_id || 0,
    '',
    '',
    raw.date || 0,
    raw.is_outgoing || false,
    false,
    0,
    MessageContentType.TEXT,
    null,
    null
  );

  // Reply
  const replyTo: TdReplyTo | undefined = raw.reply_to;
  if (replyTo && tdType(replyTo as unknown as Record<string, Object>) === 'messageReplyToMessage') {
    msg.replyToMessageId = replyTo.message_id || 0;
  }

  // Forward
  const forwardInfo: TdForwardInfo | undefined = raw.forward_info;
  if (forwardInfo) {
    const origin: TdMessageOrigin | undefined = forwardInfo.origin;
    if (origin) {
      msg.forwardedFrom = origin.sender_name || '';
    }
  }

  // Media album grouping
  const albumId: string | undefined = raw.media_album_id;
  if (albumId && albumId !== '0') {
    msg.mediaAlbumId = albumId;
  }

  // Scheduling state
  const scheduling: TdSchedulingState | undefined = raw.scheduling_state;
  if (scheduling) {
    const schedType: string = tdType(scheduling as unknown as Record<string, Object>);
    if (schedType === 'messageSchedulingStateSendAtDate') {
      msg.schedulingState = scheduling.send_date || 0;
    }
  }

  // Self-destruct
  const selfDestruct: TdSelfDestructType | undefined = raw.self_destruct_type;
  if (selfDestruct) {
    msg.selfDestructIn = selfDestruct.self_destruct_time || 0;
    const sdType: string = tdType(selfDestruct as unknown as Record<string, Object>);
    if (sdType === 'messageSelfDestructTypeImmediately') {
      msg.isViewOnce = true;
    }
  }

  // Spoiler + content
  if (content) {
    if (content.has_spoiler === true) {
      msg.hasSpoiler = true;
    }
    applyContent(msg, content);
  }

  return msg;
}

// --- Content type mapping ---

export function applyContent(msg: Message, content: TdMessageContent): void {
  const type: string = tdType(content as unknown as Record<string, Object>);

  switch (type) {
    case 'messageText': {
      msg.contentType = MessageContentType.TEXT;
      const textObj: TdFormattedText | undefined = content.text;
      msg.text = textObj?.text || '';
      break;
    }
    case 'messagePhoto': {
      msg.contentType = MessageContentType.PHOTO;
      const caption: TdFormattedText | undefined = content.caption;
      msg.text = caption?.text || '';
      break;
    }
    case 'messageVideo': {
      msg.contentType = MessageContentType.VIDEO;
      const video: TdVideo | undefined = content.video;
      msg.videoDuration = video?.duration || 0;
      const caption2: TdFormattedText | undefined = content.caption;
      msg.text = caption2?.text || '';
      break;
    }
    case 'messageDocument': {
      msg.contentType = MessageContentType.DOCUMENT;
      const doc: TdDocument | undefined = content.document;
      msg.fileName = doc?.file_name || 'Document';
      const caption3: TdFormattedText | undefined = content.caption;
      msg.text = caption3?.text || '';
      break;
    }
    case 'messageVoiceNote': {
      msg.contentType = MessageContentType.VOICE;
      const voice: TdVoiceNote | undefined = content.voice_note;
      msg.voiceDuration = voice?.duration || 0;
      const waveform: string | undefined = voice?.waveform;
      if (waveform) {
        msg.voiceWaveform = decodeWaveform(waveform);
      }
      break;
    }
    case 'messageSticker': {
      msg.contentType = MessageContentType.STICKER;
      const sticker: TdSticker | undefined = content.sticker;
      msg.text = sticker?.emoji || '';
      break;
    }
    case 'messageAnimation': {
      msg.contentType = MessageContentType.ANIMATION;
      msg.text = 'GIF';
      break;
    }
    case 'messageVideoNote': {
      msg.contentType = MessageContentType.VIDEO_NOTE;
      const videoNote: TdVideoNote | undefined = content.video_note;
      msg.videoNoteDuration = videoNote?.duration || 0;
      msg.videoNoteLength = videoNote?.length || 240;
      const vnFile: TdFile | undefined = videoNote?.video;
      if (vnFile) {
        msg.videoNoteFileId = vnFile.id || 0;
      }
      break;
    }
    case 'messagePoll': {
      msg.contentType = MessageContentType.POLL;
      const poll: TdPoll | undefined = content.poll;
      if (poll) {
        msg.pollId = poll.id || '';
        msg.pollQuestion = poll.question?.text || '';
        msg.pollTotalVoterCount = poll.total_voter_count || 0;
        msg.pollIsClosed = poll.is_closed || false;
        msg.pollIsAnonymous = poll.is_anonymous !== false;

        const pt: TdPollType | undefined = poll.type;
        msg.pollType = (pt ? tdType(pt as unknown as Record<string, Object>) : '') === 'pollTypeQuiz' ? 'quiz' : 'regular';

        const opts: TdPollOption[] | undefined = poll.options;
        if (opts) {
          msg.pollOptions = opts.map((opt: TdPollOption): PollOptionDisplay => {
            const displayOpt: PollOptionDisplay = {
              text: opt.text?.text || '',
              voterCount: opt.voter_count || 0,
              votePercentage: opt.vote_percentage || 0,
              isChosen: opt.is_chosen || false
            };
            return displayOpt;
          });
        }
      }
      break;
    }
    default: {
      msg.contentType = MessageContentType.UNSUPPORTED;
      msg.text = `[${type.replace('message', '')}]`;
      TdFallbackRegistry.getInstance().recordUnhandled(type, 'content');
      break;
    }
  }
}

// --- Text preview extraction ---

export function extractTextPreview(rawMsg: TdMessage): string {
  const content: TdMessageContent | undefined = rawMsg.content;
  if (!content) return '';

  const type: string = tdType(content as unknown as Record<string, Object>);
  switch (type) {
    case 'messageText': {
      return content.text?.text || '';
    }
    case 'messagePhoto': return 'Photo';
    case 'messageVideo': return 'Video';
    case 'messageDocument': {
      return content.document?.file_name || 'Document';
    }
    case 'messageVoiceNote': return 'Voice message';
    case 'messageSticker': {
      return `${content.sticker?.emoji || ''} Sticker`;
    }
    case 'messageAnimation': return 'GIF';
    case 'messageVideoNote': return 'Video message';
    case 'messagePoll': {
      const question: string = content.poll?.question?.text || '';
      return `📊 ${question}`;
    }
    default: {
      TdFallbackRegistry.getInstance().recordUnhandled(type, 'content');
      return type.replace('message', '');
    }
  }
}

// --- Chat parsing ---

export function parseChat(raw: TdChat): Chat {
  const lastMsg: TdMessage | undefined = raw.last_message;
  const positions: TdChatPosition[] | undefined = raw.positions;
  const notifSettings: TdNotificationSettings | undefined = raw.notification_settings;

  const chat = new Chat(
    raw.id || 0,
    raw.title || '',
    lastMsg ? extractTextPreview(lastMsg) : '',
    lastMsg ? (lastMsg.date || 0) : 0,
    raw.unread_count || 0,
    null,
    false,
    false,
    false
  );

  // Determine type
  const chatType: TdChatType | undefined = raw.type;
  if (chatType) {
    const t: string = tdType(chatType as unknown as Record<string, Object>);
    chat.isGroup = t === 'chatTypeSupergroup' || t === 'chatTypeBasicGroup';
    chat.isChannel = t === 'chatTypeSupergroup' && (chatType.is_channel === true);
  }

  // Mute status
  if (notifSettings) {
    const muteFor: number = notifSettings.mute_for || 0;
    chat.isMuted = muteFor > 0;
  }

  // Positions / pinned / order
  if (positions) {
    updateChatPositions(chat, positions);
  }

  return chat;
}

export function updateChatPositions(chat: Chat, positions: TdChatPosition[]): void {
  for (const pos of positions) {
    const list: Record<string, Object> | undefined = pos.list;
    if (list && tdType(list) === 'chatListMain') {
      chat.order = pos.order || '0';
      chat.isPinned = pos.is_pinned || false;
    }
  }
}

// --- Waveform decoding ---

export function decodeWaveform(base64: string): number[] {
  // TDLib sends waveform as base64-encoded packed 5-bit amplitude values
  // Each 5 bits encode a value 0-31, normalized to 0.0-1.0
  try {
    const raw: number[] = base64ToBytes(base64);
    if (raw.length === 0) return fallbackWaveform();

    const result: number[] = [];
    let bitIndex: number = 0;
    const totalBits: number = raw.length * 8;

    while (bitIndex + 5 <= totalBits) {
      const byteOffset: number = Math.floor(bitIndex / 8);
      const bitOffset: number = bitIndex % 8;

      let value: number;
      if (bitOffset <= 3) {
        value = (raw[byteOffset] >> bitOffset) & 0x1F;
      } else {
        const bitsFromFirst: number = 8 - bitOffset;
        const bitsFromSecond: number = 5 - bitsFromFirst;
        value = ((raw[byteOffset] >> bitOffset) & ((1 << bitsFromFirst) - 1))
          | (((raw[byteOffset + 1] || 0) & ((1 << bitsFromSecond) - 1)) << bitsFromFirst);
      }

      result.push(value / 31.0);
      bitIndex += 5;
    }

    return result.length > 0 ? result : fallbackWaveform();
  } catch (e) {
    hilog.debug(DOMAIN, TAG, 'Waveform decode failed: %{public}s', String(e));
    return fallbackWaveform();
  }
}

function base64ToBytes(base64: string): number[] {
  const chars: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  const bytes: number[] = [];
  let buffer: number = 0;
  let bitsCollected: number = 0;

  for (let i: number = 0; i < base64.length; i++) {
    const c: string = base64.charAt(i);
    if (c === '=') break;
    const idx: number = chars.indexOf(c);
    if (idx < 0) continue;

    buffer = (buffer << 6) | idx;
    bitsCollected += 6;

    while (bitsCollected >= 8) {
      bitsCollected -= 8;
      bytes.push((buffer >> bitsCollected) & 0xFF);
    }
  }

  return bytes;
}

function fallbackWaveform(): number[] {
  const result: number[] = [];
  for (let i: number = 0; i < 32; i++) {
    result.push(0.3);
  }
  return result;
}

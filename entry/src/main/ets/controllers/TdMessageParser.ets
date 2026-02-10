// TdMessageParser — pure parsing/mapping layer for TDLib responses
// Extracted from MessagesController to separate parsing from state management
// Reference: Telegram iOS MessageUtils, Android MessageObject

import { Chat } from '../models/Chat';
import { Message, MessageContentType } from '../models/Message';
import { TdFallbackRegistry } from '../services/TdFallbackRegistry';
import { hilog } from '@kit.PerformanceAnalysisKit';
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
  TdWebPage,
  TdContact,
  TdLocation,
  TdVenue,
  TdAudioNote,
  TdDice,
  TdDraftMessage,
  PollOptionDisplay,
  safeBool,
  safeNumber,
  safeString
} from '../models/TdTypes';

const TAG = 'TdMessageParser';
const DOMAIN = 0x0001;

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
  if (replyTo && tdType(replyTo as Record<string, Object>) === 'messageReplyToMessage') {
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
    const schedType: string = tdType(scheduling as Record<string, Object>);
    if (schedType === 'messageSchedulingStateSendAtDate') {
      msg.schedulingState = scheduling.send_date || 0;
    }
  }

  // Self-destruct
  const selfDestruct: TdSelfDestructType | undefined = raw.self_destruct_type;
  if (selfDestruct) {
    msg.selfDestructIn = selfDestruct.self_destruct_time || 0;
    const sdType: string = tdType(selfDestruct as Record<string, Object>);
    if (sdType === 'messageSelfDestructTypeImmediately') {
      msg.isViewOnce = true;
    }
  }

  // Edit date
  const editDate: number | undefined = raw.edit_date;
  if (editDate && editDate > 0) {
    msg.isEdited = true;
    msg.editDate = editDate;
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
  const type: string = tdType(content as Record<string, Object>);

  switch (type) {
    case 'messageText': {
      msg.contentType = MessageContentType.TEXT;
      const textObj: TdFormattedText | undefined = content.text;
      msg.text = textObj?.text || '';
      // Web page preview
      const webPage: TdWebPage | undefined = content.web_page;
      if (webPage) {
        msg.webPageUrl = webPage.url || '';
        msg.webPageTitle = webPage.title || '';
        msg.webPageDescription = webPage.description?.text || '';
        msg.webPageSiteName = webPage.site_name || '';
      }
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
        msg.pollType = (pt ? tdType(pt as Record<string, Object>) : '') === 'pollTypeQuiz' ? 'quiz' : 'regular';

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
    case 'messageContact': {
      msg.contentType = MessageContentType.CONTACT;
      const contact: TdContact | undefined = content.contact;
      if (contact) {
        msg.contactFirstName = contact.first_name || '';
        msg.contactLastName = contact.last_name || '';
        msg.contactPhone = contact.phone_number || '';
        msg.contactUserId = contact.user_id || 0;
      }
      break;
    }
    case 'messageLocation': {
      msg.contentType = MessageContentType.LOCATION;
      const location: TdLocation | undefined = content.location;
      if (location) {
        msg.locationLatitude = location.latitude || 0;
        msg.locationLongitude = location.longitude || 0;
      }
      break;
    }
    case 'messageLiveLocation': {
      msg.contentType = MessageContentType.LIVE_LOCATION;
      const liveLocation: TdLocation | undefined = content.location;
      if (liveLocation) {
        msg.locationLatitude = liveLocation.latitude || 0;
        msg.locationLongitude = liveLocation.longitude || 0;
      }
      msg.locationLivePeriod = content.live_period || 0;
      break;
    }
    case 'messageVenue': {
      msg.contentType = MessageContentType.VENUE;
      const venue: TdVenue | undefined = content.venue;
      if (venue) {
        msg.venueTitle = venue.title || '';
        msg.venueAddress = venue.address || '';
        const venueLocation: TdLocation | undefined = venue.location;
        if (venueLocation) {
          msg.locationLatitude = venueLocation.latitude || 0;
          msg.locationLongitude = venueLocation.longitude || 0;
        }
      }
      break;
    }
    case 'messageCall': {
      msg.contentType = MessageContentType.CALL;
      const payload: Record<string, Object> = content as Record<string, Object>;
      const call: Record<string, Object> | undefined = toRecord(payload['call']);
      msg.callDuration = safeNumber(call?.['duration']);
      msg.callIsVideo = safeBool(call?.['is_video']);
      const discardReason: Record<string, Object> | undefined = toRecord(call?.['discard_reason']);
      const reasonType: string = discardReason ? tdType(discardReason) : '';
      if (reasonType === 'callDiscardReasonMissed') {
        msg.callDiscardReason = 'missed';
      } else if (reasonType === 'callDiscardReasonDeclined') {
        msg.callDiscardReason = 'declined';
      } else if (reasonType === 'callDiscardReasonHungUp') {
        msg.callDiscardReason = 'hangup';
      } else {
        msg.callDiscardReason = '';
      }
      break;
    }
    case 'messageDice': {
      msg.contentType = MessageContentType.DICE;
      const dice: TdDice | undefined = content.dice;
      if (dice) {
        msg.diceEmoji = dice.emoji || '🎲';
        msg.diceValue = dice.value || 0;
      }
      break;
    }
    case 'messageAudio': {
      msg.contentType = MessageContentType.AUDIO;
      const audio: TdAudioNote | undefined = content.audio;
      if (audio) {
        msg.audioTitle = audio.title || '';
        msg.audioPerformer = audio.performer || '';
        msg.audioDuration = audio.duration || 0;
        const audioFile: TdFile | undefined = audio.audio;
        if (audioFile) {
          msg.audioFileId = audioFile.id || 0;
        }
      }
      const audioCaption: TdFormattedText | undefined = content.caption;
      msg.text = audioCaption?.text || '';
      break;
    }
    case 'messageGame': {
      msg.contentType = MessageContentType.GAME;
      const gamePayload: Record<string, Object> = content as Record<string, Object>;
      const game: Record<string, Object> | undefined = toRecord(gamePayload['game']);
      const gameTitle: string = safeString(game?.['title']);
      msg.text = gameTitle.length > 0 ? `🎮 ${gameTitle}` : '🎮 Game';
      break;
    }
    default: {
      const knownText: string | undefined = buildKnownContentText(type, content);
      if (knownText !== undefined) {
        msg.contentType = MessageContentType.TEXT;
        msg.text = knownText;
        break;
      }
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

  const type: string = tdType(content as Record<string, Object>);
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
    case 'messageContact': {
      const contact: Record<string, Object> | undefined = toRecord((content as Record<string, Object>)['contact']);
      const firstName: string = safeString(contact?.['first_name']);
      const lastName: string = safeString(contact?.['last_name']);
      const fullName: string = `${firstName} ${lastName}`.trim();
      return fullName.length > 0 ? `👤 ${fullName}` : '👤 Contact';
    }
    case 'messageLocation': return '📍 Location';
    case 'messageLiveLocation': return '📡 Live location';
    case 'messageVenue': {
      const venue: Record<string, Object> | undefined = toRecord((content as Record<string, Object>)['venue']);
      const venueTitle: string = safeString(venue?.['title']);
      return venueTitle.length > 0 ? `📍 ${venueTitle}` : '📍 Venue';
    }
    case 'messageCall': {
      const callPayload: Record<string, Object> = content as Record<string, Object>;
      return buildCallText(callPayload);
    }
    case 'messageDice': {
      const dicePayload: Record<string, Object> = content as Record<string, Object>;
      const diceObj: Record<string, Object> | undefined = toRecord(dicePayload['dice']);
      const diceEmoji: string = safeString(diceObj?.['emoji']) || '🎲';
      return diceEmoji;
    }
    case 'messageAudio': {
      const audioObj: Record<string, Object> | undefined = toRecord((content as Record<string, Object>)['audio']);
      const audioTitle: string = safeString(audioObj?.['title']);
      return audioTitle.length > 0 ? `🎵 ${audioTitle}` : '🎵 Audio';
    }
    case 'messageGame': {
      const gameObj: Record<string, Object> | undefined = toRecord((content as Record<string, Object>)['game']);
      const gameTitle: string = safeString(gameObj?.['title']);
      return gameTitle.length > 0 ? `🎮 ${gameTitle}` : '🎮 Game';
    }
    default: {
      const knownText: string | undefined = buildKnownContentText(type, content);
      if (knownText !== undefined) {
        return knownText;
      }
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

  // Last message outgoing/read status
  if (lastMsg) {
    chat.lastMessageIsOutgoing = lastMsg.is_outgoing || false;
  }

  // Draft message
  const draftMsg: TdDraftMessage | undefined = raw.draft_message;
  if (draftMsg) {
    const draftText: string | undefined = draftMsg.input_message_text?.text?.text;
    if (draftText) {
      chat.draftText = draftText;
    }
  }

  // Determine type
  const chatType: TdChatType | undefined = raw.type;
  if (chatType) {
    const t: string = tdType(chatType as Record<string, Object>);
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

// --- Known content fallback text ---

function buildKnownContentText(type: string, content: TdMessageContent): string | undefined {
  const payload: Record<string, Object> = content as Record<string, Object>;
  switch (type) {
    case 'messageInvoice': {
      const invoice: Record<string, Object> | undefined = toRecord(payload['invoice']);
      const title: string = safeString(invoice?.['title']);
      return title.length > 0 ? `💳 ${title}` : '💳 Invoice';
    }
    case 'messageProximityAlertTriggered': {
      const distance: number = safeNumber(payload['distance']);
      return distance > 0 ? `⚠️ Proximity alert (${distance} m)` : '⚠️ Proximity alert';
    }
    case 'messageScreenshotTaken': return '📷 Screenshot taken';
    case 'messageChatSetTtl': {
      const ttl: number = safeNumber(payload['ttl']);
      return ttl > 0 ? `🔒 Messages auto-delete in ${formatDuration(ttl)}` : '🔒 Auto-delete timer changed';
    }
    case 'messageChatChangeTitle': {
      const title: string = safeString(payload['title']);
      return title.length > 0 ? `✏️ Chat title changed to "${title}"` : '✏️ Chat title changed';
    }
    case 'messageChatChangePhoto': return '🖼️ Chat photo changed';
    case 'messageChatDeletePhoto': return '🗑️ Chat photo removed';
    case 'messageChatAddMembers': {
      const membersValue: Object | undefined = payload['member_user_ids'];
      if (Array.isArray(membersValue)) {
        const count: number = membersValue.length;
        if (count > 0) return `👥 Added ${count} member${count > 1 ? 's' : ''}`;
      }
      return '👥 Members added';
    }
    case 'messageChatJoinByLink': return '🔗 Joined via invite link';
    case 'messageChatDeleteMember': return '👤 Member removed';
    case 'messageChatUpgradeTo': return '⬆️ Group upgraded to supergroup';
    case 'messageChatUpgradeFrom': return '⬆️ Group upgraded';
    case 'messagePinMessage': return '📌 Message pinned';
    case 'messageGameScore': return '🏆 Game score updated';
    case 'messagePaymentSuccessful': return '✅ Payment successful';
    case 'messageContactRegistered': return '🎉 Contact joined Telegram';
    case 'messageCustomServiceAction': {
      const text: string = safeString(payload['text']);
      return text.length > 0 ? text : 'ℹ️ Service message';
    }
    case 'messageUnsupported': return 'Unsupported message';
    default: return undefined;
  }
}

function buildCallText(payload: Record<string, Object>): string {
  const call: Record<string, Object> | undefined = toRecord(payload['call']);
  const duration: number = safeNumber(call?.['duration']);
  const isVideo: boolean = safeBool(call?.['is_video']);
  const discardReason: Record<string, Object> | undefined = toRecord(call?.['discard_reason']);
  const reasonType: string = discardReason ? tdType(discardReason) : '';

  if (reasonType === 'callDiscardReasonMissed') {
    return isVideo ? '📹 Missed video call' : '📞 Missed call';
  }
  if (reasonType === 'callDiscardReasonDeclined') {
    return isVideo ? '📹 Declined video call' : '📞 Declined call';
  }
  if (duration > 0) {
    return `${isVideo ? '📹 Video call' : '📞 Call'} (${formatDuration(duration)})`;
  }
  return isVideo ? '📹 Video call' : '📞 Call';
}

function formatDuration(totalSeconds: number): string {
  if (totalSeconds <= 0) return '0s';
  const hours: number = Math.floor(totalSeconds / 3600);
  const minutes: number = Math.floor((totalSeconds % 3600) / 60);
  const seconds: number = totalSeconds % 60;
  if (hours > 0) {
    return `${hours}h ${minutes}m`;
  }
  if (minutes > 0) {
    return `${minutes}m ${seconds}s`;
  }
  return `${seconds}s`;
}

function toRecord(value: Object | undefined | null): Record<string, Object> | undefined {
  if (value === undefined || value === null) return undefined;
  return value as Record<string, Object>;
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

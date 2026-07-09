// Chat DTO - domain data transfer object for chats
// ArkTS compliant - uses TdObject wrapper class

import { ChatId } from '../EntityId';
import { TdObject, tdGetString, tdGetNumber, tdGetBoolean, tdGetInt64, tdGetObject, tdGetArray, tdHasKeys } from '../../utils/tdAccessors';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DTO_DOMAIN = 0x0003;
const DTO_TAG = 'ChatDto';

export enum ChatType {
  PRIVATE = 'private',
  SECRET = 'secret',
  GROUP = 'group',
  SUPERGROUP = 'supergroup',
  CHANNEL = 'channel'
}

export class ChatLastMessage {
  id: string = '0'; // MessageId as string (TDLib int64)
  text: string = '';
  timestamp: number = 0;
}

export class ChatPhoto {
  small: string = '';
  big: string = '';
  smallFileId: number = 0;
  bigFileId: number = 0;
}

export class ChatDto {
  id: ChatId = 0;
  type: ChatType = ChatType.PRIVATE;
  peerUserId: number = 0;
  accentColorId: number = -1;
  title: string = '';
  unreadCount: number = 0;
  unreadMentionCount: number = 0;
  muteFor: number = 0;
  lastReadOutboxMessageId: string = '0';
  lastReadInboxMessageId: string = '0';
  lastMessage?: ChatLastMessage;
  isPinned: boolean = false;
  photo?: ChatPhoto;
  order: string = '0';
  draftText: string = '';
  draftReplyToMessageId: string = '0';
  supergroupId: number = 0;
}

function extractOptionalAccentColorId(tdObject: TdObject): number {
  const rawValue = tdObject.get('accent_color_id');
  if (typeof rawValue === 'number') {
    return rawValue;
  }
  if (typeof rawValue === 'string' && rawValue.length > 0) {
    const parsed = parseInt(rawValue, 10);
    return Number.isNaN(parsed) ? -1 : parsed;
  }
  return -1;
}

// Helper to create DTO from raw TDLib chat object
export function createChatDtoFromTd(tdChat: TdObject): ChatDto {
  // Map TDLib chat type to our enum
  let type: ChatType = ChatType.PRIVATE;
  const tdTypeObj = tdGetObject(tdChat, 'type');
  const tdTypeStr = tdGetString(tdTypeObj, '@type');

  if (tdTypeStr === 'chatTypePrivate') {
    type = ChatType.PRIVATE;
  } else if (tdTypeStr === 'chatTypeSecret') {
    type = ChatType.SECRET;
  } else if (tdTypeStr === 'chatTypeBasicGroup') {
    type = ChatType.GROUP;
  } else if (tdTypeStr === 'chatTypeSupergroup') {
    const isChannel = tdGetBoolean(tdTypeObj, 'is_channel');
    type = isChannel ? ChatType.CHANNEL : ChatType.SUPERGROUP;
  }

  const chatDto = new ChatDto();
  // Extract supergroup_id for later getSupergroupFullInfo calls
  if (tdTypeStr === 'chatTypeSupergroup') {
    chatDto.supergroupId = tdGetNumber(tdTypeObj, 'supergroup_id');
  }
  chatDto.id = tdChat.getTopLevelNumber('id');
  chatDto.type = type;
  chatDto.title = tdGetString(tdChat, 'title');
  chatDto.accentColorId = extractOptionalAccentColorId(tdChat);
  chatDto.unreadCount = tdGetNumber(tdChat, 'unread_count');
  chatDto.lastReadOutboxMessageId = tdGetInt64(tdChat, 'last_read_outbox_message_id');
  chatDto.lastReadInboxMessageId = tdGetInt64(tdChat, 'last_read_inbox_message_id');

  const notificationSettings = tdGetObject(tdChat, 'notification_settings');
  if (tdHasKeys(notificationSettings)) {
    chatDto.muteFor = tdGetNumber(notificationSettings, 'mute_for');
  }

  if (type === ChatType.PRIVATE) {
    chatDto.peerUserId = tdGetNumber(tdTypeObj, 'user_id');
  }

  hilog.info(DTO_DOMAIN, DTO_TAG, 'chatFromTd id=%{public}d title="%{public}s" type=%{public}s',
    chatDto.id, chatDto.title || '(empty)', tdGetString(tdGetObject(tdChat, 'type'), '@type'));

  // Extract isPinned and order from positions
  const positions = tdGetArray(tdChat, 'positions');
  for (const position of positions) {
    const listObj = tdGetObject(position, 'list');
    const listType = tdGetString(listObj, '@type');
    if (listType === 'chatListMain') {
      chatDto.isPinned = tdGetBoolean(position, 'is_pinned');
      chatDto.order = tdGetInt64(position, 'order');
      break;
    }
  }

  // Last message
  const lastMsgObj = tdGetObject(tdChat, 'last_message');
  if (tdHasKeys(lastMsgObj)) {
    chatDto.lastMessage = extractLastMessage(lastMsgObj);
  }

  // Draft — the full chat object carries draft_message too, not only the
  // updateChatDraftMessage stream (cold start would lose drafts otherwise)
  const draftObj = tdGetObject(tdChat, 'draft_message');
  if (tdHasKeys(draftObj)) {
    const draftInput = tdGetObject(draftObj, 'input_message_text');
    if (tdHasKeys(draftInput)) {
      chatDto.draftText = tdGetString(tdGetObject(draftInput, 'text'), 'text');
    }
    // TDLib: draftMessage.reply_to is InputMessageReplyTo — only the
    // same-chat variant carries a message_id we can treat as local
    const draftReplyObj = tdGetObject(draftObj, 'reply_to');
    chatDto.draftReplyToMessageId = tdGetString(draftReplyObj, '@type') === 'inputMessageReplyToMessage'
      ? tdGetInt64(draftReplyObj, 'message_id') : '0';
  }

  // Photo if available
  const photoObj = tdGetObject(tdChat, 'photo');
  if (tdHasKeys(photoObj)) {
    chatDto.photo = extractChatPhoto(photoObj);
  }

  return chatDto;
}

// Extract ChatLastMessage from TDLib message object
export function extractLastMessage(tdMessage: TdObject): ChatLastMessage {
  const lastMsg = new ChatLastMessage();
  lastMsg.id = tdGetInt64(tdMessage, 'id');
  lastMsg.timestamp = tdGetNumber(tdMessage, 'date');

  // Extract text from content
  const content = tdGetObject(tdMessage, 'content');
  const contentType = tdGetString(content, '@type');

  if (contentType === 'messageText') {
    const textObj = tdGetObject(content, 'text');
    lastMsg.text = tdGetString(textObj, 'text');
  } else if (contentType === 'messagePhoto' || contentType === 'messageVideo' ||
    contentType === 'messageDocument' || contentType === 'messageAudio' ||
    contentType === 'messageVoiceNote') {
    const caption = tdGetObject(content, 'caption');
    const captionText = tdGetString(caption, 'text');
    lastMsg.text = captionText || `[${contentType.replace('message', '')}]`;
  } else if (contentType) {
    lastMsg.text = `[${contentType.replace('message', '')}]`;
  }

  return lastMsg;
}

// Extract ChatPhoto from TDLib photo object
export function extractChatPhoto(photoObj: TdObject): ChatPhoto {
  const smallObj = tdGetObject(photoObj, 'small');
  const bigObj = tdGetObject(photoObj, 'big');
  const smallLocal = tdGetObject(smallObj, 'local');
  const bigLocal = tdGetObject(bigObj, 'local');

  const photo = new ChatPhoto();
  photo.small = tdGetString(smallLocal, 'path');
  photo.big = tdGetString(bigLocal, 'path');
  // Use getTopLevelNumber to avoid nested remote.id (string) shadowing the numeric file id
  photo.smallFileId = smallObj.getTopLevelNumber('id');
  photo.bigFileId = bigObj.getTopLevelNumber('id');
  return photo;
}

// Full position data from chatListMain
export class ChatPositionInfo {
  isPinned: boolean = false;
  order: string = '0';
}

// Extract isPinned + order from a single TDLib position object
export function extractMainListPosition(tdPosition: TdObject): ChatPositionInfo | undefined {
  const listObj = tdGetObject(tdPosition, 'list');
  const listType = tdGetString(listObj, '@type');
  if (listType === 'chatListMain') {
    const info = new ChatPositionInfo();
    info.isPinned = tdGetBoolean(tdPosition, 'is_pinned');
    info.order = tdGetInt64(tdPosition, 'order');
    return info;
  }
  return undefined;
}

// Helper for partial updates (chatUpdated event)
export class ChatUpdateDto {
  peerUserId?: number;
  accentColorId?: number;
  title?: string;
  unreadCount?: number;
  unreadMentionCount?: number;
  muteFor?: number;
  lastReadOutboxMessageId?: string;
  lastReadInboxMessageId?: string;
  lastMessage?: ChatLastMessage;
  photo?: ChatPhoto;
  isPinned?: boolean;
  order?: string;
  draftText?: string;
  draftReplyToMessageId?: string;
}

export function applyChatUpdate(chat: ChatDto, update: ChatUpdateDto): ChatDto {
  const updatedChat = new ChatDto();

  // Copy all fields from original chat
  updatedChat.id = chat.id;
  updatedChat.type = chat.type;
  updatedChat.peerUserId = chat.peerUserId;
  updatedChat.accentColorId = chat.accentColorId;
  updatedChat.title = chat.title;
  updatedChat.unreadCount = chat.unreadCount;
  updatedChat.unreadMentionCount = chat.unreadMentionCount;
  updatedChat.muteFor = chat.muteFor;
  updatedChat.lastReadOutboxMessageId = chat.lastReadOutboxMessageId;
  updatedChat.lastReadInboxMessageId = chat.lastReadInboxMessageId;
  updatedChat.isPinned = chat.isPinned;
  updatedChat.lastMessage = chat.lastMessage;
  updatedChat.photo = chat.photo;
  updatedChat.order = chat.order;
  updatedChat.draftText = chat.draftText;
  updatedChat.draftReplyToMessageId = chat.draftReplyToMessageId;

  // Apply updates
  if (update.peerUserId !== undefined) {
    updatedChat.peerUserId = update.peerUserId;
  }
  if (update.accentColorId !== undefined) {
    updatedChat.accentColorId = update.accentColorId;
  }
  if (update.title !== undefined) {
    updatedChat.title = update.title;
  }
  if (update.unreadCount !== undefined) {
    updatedChat.unreadCount = update.unreadCount;
  }
  if (update.unreadMentionCount !== undefined) {
    updatedChat.unreadMentionCount = update.unreadMentionCount;
  }
  if (update.muteFor !== undefined) {
    updatedChat.muteFor = update.muteFor;
  }
  if (update.lastReadOutboxMessageId !== undefined) {
    updatedChat.lastReadOutboxMessageId = update.lastReadOutboxMessageId;
  }
  if (update.lastReadInboxMessageId !== undefined) {
    updatedChat.lastReadInboxMessageId = update.lastReadInboxMessageId;
  }
  if (update.isPinned !== undefined) {
    updatedChat.isPinned = update.isPinned;
  }
  if (update.lastMessage !== undefined) {
    updatedChat.lastMessage = update.lastMessage;
  }
  if (update.photo !== undefined) {
    updatedChat.photo = update.photo;
  }
  if (update.order !== undefined) {
    updatedChat.order = update.order;
  }
  if (update.draftText !== undefined) {
    updatedChat.draftText = update.draftText;
  }
  if (update.draftReplyToMessageId !== undefined) {
    updatedChat.draftReplyToMessageId = update.draftReplyToMessageId;
  }

  return updatedChat;
}

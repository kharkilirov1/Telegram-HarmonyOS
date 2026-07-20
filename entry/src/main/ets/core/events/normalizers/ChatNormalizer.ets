// ChatNormalizer — handles all chat-related TDLib updates
// Extracted from EventNormalizer to prevent god-file growth

import {
  AnyAppEvent,
  ChatActionEvent,
  ChatListUnreadMessageCountChangedEvent,
  ChatReadInboxEvent,
  ChatReadOutboxEvent,
  createNewChatEvent,
  createChatUpdatedEvent
} from '../../model/AppEvent';
import {
  createChatDtoFromTd,
  ChatUpdateDto,
  ChatLastMessage,
  ChatPhoto,
  extractLastMessage,
  extractChatListPosition,
  extractChatPhoto,
  extractCustomEmojiTextEntities
} from '../../model/dto/ChatDto';
import { TdObject } from '../../../models/TdTypes';
import {
  tdGetNumber, tdGetString, tdGetInt64,
  tdGetObject, tdGetArray, tdHasKeys
} from '../../utils/tdAccessors';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0003;
const TAG = 'ChatNormalizer';

function applyChatListPosition(updates: ChatUpdateDto, position: TdObject): boolean {
  const posInfo = extractChatListPosition(position);
  if (posInfo === undefined) {
    return false;
  }
  if (posInfo.listType === 'chatListMain') {
    updates.isPinned = posInfo.isPinned;
    updates.order = posInfo.order;
  } else if (posInfo.listType === 'chatListArchive') {
    updates.isArchivePinned = posInfo.isPinned;
    updates.archiveOrder = posInfo.order;
  }
  return true;
}

function applyChatListPositions(updates: ChatUpdateDto, positions: TdObject[]): void {
  for (const position of positions) {
    applyChatListPosition(updates, position);
  }
}

function handleNewChat(events: AnyAppEvent[], update: TdObject): void {
  const chat = tdGetObject(update, 'chat');
  const chatId = chat.getTopLevelNumber('id');
  if (!chatId) {
    return;
  }

  try {
    const chatDto = createChatDtoFromTd(chat);
    events.push(createNewChatEvent(chatId, chatDto));
  } catch (error) {
    hilog.error(DOMAIN, TAG, 'Failed to parse newChat id=%{public}d: %{public}s', chatId, String(error));
  }
}

function handleDirectChat(events: AnyAppEvent[], update: TdObject): void {
  const chatId = update.getTopLevelNumber('id');
  if (!chatId) return;

  try {
    const chatDto = createChatDtoFromTd(update);
    events.push(createNewChatEvent(chatId, chatDto));
  } catch (error) {
    hilog.error(DOMAIN, TAG, 'Failed to parse direct chat: %{public}s', String(error));
  }
}

function handleChatTitle(events: AnyAppEvent[], update: TdObject): void {
  const chatId = tdGetNumber(update, 'chat_id');
  if (!chatId) return;

  const nextTitle = tdGetString(update, 'title');
  if (nextTitle.trim().length === 0) {
    return;
  }

  const updates = new ChatUpdateDto();
  updates.title = nextTitle;
  events.push(createChatUpdatedEvent(chatId, updates));
}

function handleChatPhoto(events: AnyAppEvent[], update: TdObject): void {
  const chatId = tdGetNumber(update, 'chat_id');
  if (!chatId) return;

  const updates = new ChatUpdateDto();
  const photoObj = tdGetObject(update, 'photo');
  if (tdHasKeys(photoObj)) {
    updates.photo = extractChatPhoto(photoObj);
  } else {
    const emptyPhoto = new ChatPhoto();
    updates.photo = emptyPhoto;
  }
  events.push(createChatUpdatedEvent(chatId, updates));
}

function handleChatLastMessage(events: AnyAppEvent[], update: TdObject): void {
  const chatId = tdGetNumber(update, 'chat_id');
  if (!chatId) return;

  const updates = new ChatUpdateDto();

  const lastMsgObj = tdGetObject(update, 'last_message');
  if (tdHasKeys(lastMsgObj)) {
    updates.lastMessage = extractLastMessage(lastMsgObj);
  } else {
    const emptyLastMessage = new ChatLastMessage();
    updates.lastMessage = emptyLastMessage;
  }

  applyChatListPositions(updates, tdGetArray(update, 'positions'));

  const lastReadOutboxMessageId = tdGetInt64(update, 'last_read_outbox_message_id');
  if (lastReadOutboxMessageId !== '0') {
    updates.lastReadOutboxMessageId = lastReadOutboxMessageId;
  }

  const lastReadInboxMessageId = tdGetInt64(update, 'last_read_inbox_message_id');
  if (lastReadInboxMessageId !== '0') {
    updates.lastReadInboxMessageId = lastReadInboxMessageId;
  }

  events.push(createChatUpdatedEvent(chatId, updates));
}

function handleChatAddedToList(events: AnyAppEvent[], update: TdObject): void {
  const chatId = tdGetNumber(update, 'chat_id');
  if (!chatId) return;

  const listObj = tdGetObject(update, 'chat_list');
  const listType = tdGetString(listObj, '@type');
  const updates = new ChatUpdateDto();
  const fallbackOrder = (Math.floor(Date.now() / 1000)).toString();
  if (listType === 'chatListMain') {
    updates.order = fallbackOrder;
  } else if (listType === 'chatListArchive') {
    updates.archiveOrder = fallbackOrder;
  } else {
    return;
  }
  hilog.info(DOMAIN, TAG, 'chatAddedToList chatId=%{public}d list=%{public}s', chatId, listType);
  events.push(createChatUpdatedEvent(chatId, updates));
}

function handleChatPosition(events: AnyAppEvent[], update: TdObject): void {
  const chatId = tdGetNumber(update, 'chat_id');
  if (!chatId) return;

  const position = tdGetObject(update, 'position');
  if (!tdHasKeys(position)) return;

  const updates = new ChatUpdateDto();
  if (!applyChatListPosition(updates, position)) return;
  events.push(createChatUpdatedEvent(chatId, updates));
}

function handleChatReadInbox(events: AnyAppEvent[], update: TdObject): void {
  const chatId = tdGetNumber(update, 'chat_id');
  if (!chatId) return;

  const event = new ChatReadInboxEvent();
  event.chatId = chatId;
  event.unreadCount = tdGetNumber(update, 'unread_count');
  event.lastReadInboxMessageId = tdGetInt64(update, 'last_read_inbox_message_id');
  event.timestamp = Date.now();
  events.push(event);
}

function handleChatReadOutbox(events: AnyAppEvent[], update: TdObject): void {
  const chatId = tdGetNumber(update, 'chat_id');
  if (!chatId) return;

  const event = new ChatReadOutboxEvent();
  event.chatId = chatId;
  event.lastReadOutboxMessageId = tdGetInt64(update, 'last_read_outbox_message_id');
  event.timestamp = Date.now();
  events.push(event);
}

function handleUnreadMessageCount(events: AnyAppEvent[], update: TdObject): void {
  const listType = tdGetString(tdGetObject(update, 'chat_list'), '@type');
  if (listType !== 'chatListMain' && listType !== 'chatListArchive') {
    return;
  }

  const event = new ChatListUnreadMessageCountChangedEvent();
  event.chatListType = listType === 'chatListArchive' ? 'archive' : 'main';
  event.unreadCount = Math.max(0, tdGetNumber(update, 'unread_count'));
  event.unreadUnmutedCount = Math.max(0, tdGetNumber(update, 'unread_unmuted_count'));
  event.timestamp = Date.now();
  events.push(event);
}

function handleChatDraftMessage(events: AnyAppEvent[], update: TdObject): void {
  const chatId = tdGetNumber(update, 'chat_id');
  if (!chatId) return;
  hilog.info(DOMAIN, TAG, 'draft update for chat %{public}d', chatId);

  const updates = new ChatUpdateDto();

  const draftObj = tdGetObject(update, 'draft_message');
  if (tdHasKeys(draftObj)) {
    const inputMsg = tdGetObject(draftObj, 'input_message_text');
    if (tdHasKeys(inputMsg)) {
      const textObj = tdGetObject(inputMsg, 'text');
      updates.draftText = tdGetString(textObj, 'text');
      updates.draftCustomEmojiEntities = extractCustomEmojiTextEntities(textObj);
    }
    // TDLib: draftMessage.reply_to is InputMessageReplyTo — only the
    // same-chat variant carries a message_id we can treat as local
    const draftReplyObj = tdGetObject(draftObj, 'reply_to');
    updates.draftReplyToMessageId = tdGetString(draftReplyObj, '@type') === 'inputMessageReplyToMessage'
      ? tdGetInt64(draftReplyObj, 'message_id') : '0';
  } else {
    updates.draftText = '';
    updates.draftCustomEmojiEntities = [];
    updates.draftReplyToMessageId = '0';
  }

  applyChatListPositions(updates, tdGetArray(update, 'positions'));

  events.push(createChatUpdatedEvent(chatId, updates));
}

function handleChatUnreadMentionCount(events: AnyAppEvent[], update: TdObject): void {
  const chatId = tdGetNumber(update, 'chat_id');
  if (!chatId) return;

  const updates = new ChatUpdateDto();
  updates.unreadMentionCount = tdGetNumber(update, 'unread_mention_count');
  events.push(createChatUpdatedEvent(chatId, updates));
}

function handleChatNotificationSettings(events: AnyAppEvent[], update: TdObject): void {
  const chatId = tdGetNumber(update, 'chat_id');
  if (!chatId) return;

  const settings = tdGetObject(update, 'notification_settings');
  const updates = new ChatUpdateDto();
  if (tdHasKeys(settings)) {
    updates.muteFor = tdGetNumber(settings, 'mute_for');
  } else {
    updates.muteFor = 0;
  }
  events.push(createChatUpdatedEvent(chatId, updates));
}

function handleChatAccentColors(events: AnyAppEvent[], update: TdObject): void {
  const chatId = tdGetNumber(update, 'chat_id');
  if (!chatId) return;

  const rawAccentColor = update.get('accent_color_id');
  let accentColorId = -1;
  if (typeof rawAccentColor === 'number') {
    accentColorId = rawAccentColor;
  } else if (typeof rawAccentColor === 'string' && rawAccentColor.length > 0) {
    const parsed = parseInt(rawAccentColor, 10);
    accentColorId = Number.isNaN(parsed) ? -1 : parsed;
  }
  if (accentColorId < 0) {
    return;
  }

  const updates = new ChatUpdateDto();
  updates.accentColorId = accentColorId;
  events.push(createChatUpdatedEvent(chatId, updates));
}

// Map TDLib chatAction @type to short action name
function parseChatActionType(actionTypeStr: string): string {
  switch (actionTypeStr) {
    case 'chatActionTyping': return 'typing';
    case 'chatActionRecordingVideo': return 'recordingVideo';
    case 'chatActionUploadingVideo': return 'uploadingVideo';
    case 'chatActionRecordingVoiceNote': return 'recordingVoice';
    case 'chatActionUploadingVoiceNote': return 'uploadingVoice';
    case 'chatActionUploadingPhoto': return 'uploadingPhoto';
    case 'chatActionUploadingDocument': return 'uploadingDocument';
    case 'chatActionChoosingSticker': return 'choosingSticker';
    case 'chatActionChoosingLocation': return 'choosingLocation';
    case 'chatActionChoosingContact': return 'choosingContact';
    case 'chatActionStartPlayingGame': return 'playingGame';
    case 'chatActionRecordingVideoNote': return 'recordingVideoNote';
    case 'chatActionUploadingVideoNote': return 'uploadingVideoNote';
    case 'chatActionCancel': return 'cancel';
    default: return 'cancel';
  }
}

function handleChatAction(events: AnyAppEvent[], update: TdObject): void {
  const chatId = update.getTopLevelNumber('chat_id');
  if (!chatId) return;

  const actionObj = tdGetObject(update, 'action');
  const actionTypeStr = tdGetString(actionObj, '@type');
  const actionType = parseChatActionType(actionTypeStr);

  // Extract sender user id from messageSender
  const senderObj = tdGetObject(update, 'sender_id');
  const senderType = tdGetString(senderObj, '@type');
  let senderUserId = 0;
  if (senderType === 'messageSenderUser') {
    senderUserId = tdGetNumber(senderObj, 'user_id');
  }

  // info on purpose during the typing-delivery investigation: rare event,
  // and per-domain debug levels proved unreliable on the emulator
  hilog.info(DOMAIN, TAG, 'chatAction %{public}s chat=%{public}d sender=%{public}d',
    actionTypeStr, chatId, senderUserId);

  const event = new ChatActionEvent();
  event.chatId = chatId;
  event.senderUserId = senderUserId;
  event.actionType = actionType;
  event.timestamp = Date.now();
  events.push(event);
}

export function registerChatHandlers(
  handlers: Map<string, (events: AnyAppEvent[], update: TdObject) => void>
): void {
  handlers.set('updateNewChat', handleNewChat);
  handlers.set('chat', handleDirectChat);
  handlers.set('updateChatTitle', handleChatTitle);
  handlers.set('updateChatPhoto', handleChatPhoto);
  handlers.set('updateChatLastMessage', handleChatLastMessage);
  handlers.set('updateChatAddedToList', handleChatAddedToList);
  handlers.set('updateChatPosition', handleChatPosition);
  handlers.set('updateChatReadInbox', handleChatReadInbox);
  handlers.set('updateChatReadOutbox', handleChatReadOutbox);
  handlers.set('updateUnreadMessageCount', handleUnreadMessageCount);
  handlers.set('updateChatDraftMessage', handleChatDraftMessage);
  handlers.set('updateChatUnreadMentionCount', handleChatUnreadMentionCount);
  handlers.set('updateChatNotificationSettings', handleChatNotificationSettings);
  handlers.set('updateChatAccentColors', handleChatAccentColors);
  handlers.set('updateChatAction', handleChatAction);
}

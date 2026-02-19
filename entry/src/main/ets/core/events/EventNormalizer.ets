// Event Normalizer - converts raw TDLib updates to typed AppEvents
// Rule: all external events must be normalized with REAL DATA (no empty DTOs)

import {
  AnyAppEvent,
  createAuthStateChangedEvent,
  createNewMessageEvent,
  createNewChatEvent,
  createChatUpdatedEvent,
  AuthState,
  ConnectionState,
  NewChatEvent,
  ChatUpdatedEvent,
  ChatReadInboxEvent,
  ChatReadOutboxEvent,
  MessageContentUpdatedEvent,
  MessageSendSucceededEvent,
  MessageSendFailedEvent,
  MessagesDeletedEvent,
  UserUpdatedEvent,
  UserStatusChangedEvent,
  ConnectionStateChangedEvent
} from '../model/AppEvent';
import { ChatId, MessageId, UserId } from '../model/EntityId';
import { createChatDtoFromTd, ChatUpdateDto, ChatLastMessage, ChatPhoto, extractLastMessage, extractMainListPosition, extractChatPhoto } from '../model/dto/ChatDto';
import { createMessageDtoFromTd, parseMessageContent, MessageContentDto } from '../model/dto/MessageDto';
import { createUserDtoFromTd, parseUserStatus } from '../model/dto/UserDto';
import { TdObject } from '../../models/TdTypes';
import { tdGetString, tdGetNumber, tdGetBoolean, tdGetInt64, tdGetObject, tdGetArray, tdGetStringArray, tdHasKeys } from '../utils/tdAccessors';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0003;
const TAG = 'EventNormalizer';

export interface EventNormalizer {
  normalize(update: TdObject): AnyAppEvent[];
  getStats(): NormalizerStats;
}

export class NormalizerStats {
  totalUpdates: number = 0;
  normalizedEvents: number = 0;
  droppedUpdates: number = 0;
  byUpdateType: Map<string, number> = new Map<string, number>();
}

export class EventNormalizerImpl implements EventNormalizer {
  private stats: NormalizerStats = new NormalizerStats();

  normalize(update: TdObject): AnyAppEvent[] {
    this.stats.totalUpdates++;

    if (!update || typeof update !== 'object') {
      return [];
    }

    const type = tdGetString(update, '@type');
    if (!type) {
      return [];
    }

    // Update statistics
    const currentCount = this.stats.byUpdateType.get(type) || 0;
    this.stats.byUpdateType.set(type, currentCount + 1);

    const events: AnyAppEvent[] = [];

    try {
      switch (type) {
        // --- Auth ---
        case 'updateAuthorizationState':
          this.pushAuthEvents(events, update);
          break;

        // --- Connection ---
        case 'updateConnectionState':
          this.pushConnectionEvents(events, update);
          break;

        // --- Chat lifecycle ---
        case 'updateNewChat':
          this.handleNewChat(events, update);
          break;

        // --- Chat partial updates ---
        case 'updateChatTitle':
          this.handleChatTitle(events, update);
          break;

        case 'updateChatPhoto':
          this.handleChatPhoto(events, update);
          break;

        case 'updateChatLastMessage':
          this.handleChatLastMessage(events, update);
          break;

        case 'updateChatPosition':
          this.handleChatPosition(events, update);
          break;

        // --- Chat read state ---
        case 'updateChatReadInbox':
          this.handleChatReadInbox(events, update);
          break;

        case 'updateChatReadOutbox':
          this.handleChatReadOutbox(events, update);
          break;

        // --- Chat settings ---
        case 'updateChatNotificationSettings':
          // TODO: Add when notification settings reducer exists
          break;

        case 'updateChatDraftMessage':
          this.handleChatDraftMessage(events, update);
          break;

        case 'updateChatUnreadMentionCount':
          this.handleChatUnreadMentionCount(events, update);
          break;

        // --- Messages ---
        case 'updateNewMessage':
          this.handleNewMessage(events, update);
          break;

        case 'updateMessageContent':
          this.handleMessageContent(events, update);
          break;

        case 'updateMessageSendSucceeded':
          this.handleMessageSendSucceeded(events, update);
          break;

        case 'updateMessageSendFailed':
          this.handleMessageSendFailed(events, update);
          break;

        case 'updateDeleteMessages':
          this.handleDeleteMessages(events, update);
          break;

        // --- Users ---
        case 'updateUser':
          this.handleUser(events, update);
          break;

        case 'updateUserStatus':
          this.handleUserStatus(events, update);
          break;

        case 'updateUserFullInfo':
          // TODO: Add when user full info is needed in store
          break;

        default:
          this.stats.droppedUpdates++;
          break;
      }
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Failed to normalize %{public}s: %{public}s', type, err.message);
    }

    this.stats.normalizedEvents += events.length;
    return events;
  }

  getStats(): NormalizerStats {
    const statsCopy = new NormalizerStats();
    statsCopy.totalUpdates = this.stats.totalUpdates;
    statsCopy.normalizedEvents = this.stats.normalizedEvents;
    statsCopy.droppedUpdates = this.stats.droppedUpdates;
    this.stats.byUpdateType.forEach((value: number, key: string) => {
      statsCopy.byUpdateType.set(key, value);
    });
    return statsCopy;
  }

  // =====================================================
  // AUTH
  // =====================================================

  private pushAuthEvents(events: AnyAppEvent[], update: TdObject): void {
    const authState = tdGetObject(update, 'authorization_state');
    const stateType = tdGetString(authState, '@type');

    let appAuthState: AuthState = 'waitPhoneNumber';
    let isKnown = true;

    switch (stateType) {
      case 'authorizationStateWaitTdlibParameters':
        appAuthState = 'waitTdlibParameters';
        break;
      case 'authorizationStateWaitPhoneNumber':
        appAuthState = 'waitPhoneNumber';
        break;
      case 'authorizationStateWaitCode':
        appAuthState = 'waitCode';
        break;
      case 'authorizationStateWaitPassword':
        appAuthState = 'waitPassword';
        break;
      case 'authorizationStateWaitRegistration':
        appAuthState = 'waitRegistration';
        break;
      case 'authorizationStateReady':
        appAuthState = 'ready';
        break;
      case 'authorizationStateLoggingOut':
        appAuthState = 'loggingOut';
        break;
      case 'authorizationStateClosing':
        appAuthState = 'closing';
        break;
      case 'authorizationStateClosed':
        appAuthState = 'closed';
        break;
      default:
        isKnown = false;
    }

    if (isKnown) {
      // Note: authorizationStateReady does NOT contain user_id.
      // UserId must be obtained separately via getMe() after auth is ready.
      events.push(createAuthStateChangedEvent(appAuthState));
    }
  }

  // =====================================================
  // CONNECTION
  // =====================================================

  private pushConnectionEvents(events: AnyAppEvent[], update: TdObject): void {
    const state = tdGetObject(update, 'state');
    const stateType = tdGetString(state, '@type');

    let appConnectionState: ConnectionState = 'connecting';
    let isKnown = true;

    switch (stateType) {
      case 'connectionStateUpdating':
        appConnectionState = 'updating';
        break;
      case 'connectionStateReady':
        appConnectionState = 'ready';
        break;
      case 'connectionStateConnecting':
        appConnectionState = 'connecting';
        break;
      case 'connectionStateConnectingToProxy':
        appConnectionState = 'connecting';
        break;
      case 'connectionStateWaitingForNetwork':
        appConnectionState = 'waitingForNetwork';
        break;
      default:
        isKnown = false;
    }

    if (isKnown) {
      const event = new ConnectionStateChangedEvent();
      event.state = appConnectionState;
      event.timestamp = Date.now();
      events.push(event);
    }
  }

  // =====================================================
  // CHATS
  // =====================================================

  private handleNewChat(events: AnyAppEvent[], update: TdObject): void {
    const chat = tdGetObject(update, 'chat');
    const chatId = tdGetNumber(chat, 'id');
    if (!chatId) return;

    try {
      const chatDto = createChatDtoFromTd(chat);
      events.push(createNewChatEvent(chatId, chatDto));
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to parse newChat: %{public}s', String(error));
    }
  }

  private handleChatTitle(events: AnyAppEvent[], update: TdObject): void {
    const chatId = tdGetNumber(update, 'chat_id');
    if (!chatId) return;

    const updates = new ChatUpdateDto();
    updates.title = tdGetString(update, 'title');
    events.push(createChatUpdatedEvent(chatId, updates));
  }

  private handleChatPhoto(events: AnyAppEvent[], update: TdObject): void {
    const chatId = tdGetNumber(update, 'chat_id');
    if (!chatId) return;

    const updates = new ChatUpdateDto();
    const photoObj = tdGetObject(update, 'photo');
    if (tdHasKeys(photoObj)) {
      updates.photo = extractChatPhoto(photoObj);
    } else {
      // Photo removed — set empty photo
      const emptyPhoto = new ChatPhoto();
      updates.photo = emptyPhoto;
    }
    events.push(createChatUpdatedEvent(chatId, updates));
  }

  private handleChatLastMessage(events: AnyAppEvent[], update: TdObject): void {
    const chatId = tdGetNumber(update, 'chat_id');
    if (!chatId) return;

    const updates = new ChatUpdateDto();

    // Extract last message data (can be null if message was deleted)
    const lastMsgObj = tdGetObject(update, 'last_message');
    if (tdHasKeys(lastMsgObj)) {
      updates.lastMessage = extractLastMessage(lastMsgObj);
    } else {
      // Last message deleted — explicitly set empty last message to clear it in store
      const emptyLastMessage = new ChatLastMessage();
      updates.lastMessage = emptyLastMessage;
    }

    // Extract pinned state and order from positions if present
    const positions = tdGetArray(update, 'positions');
    for (const pos of positions) {
      const posInfo = extractMainListPosition(pos);
      if (posInfo !== undefined) {
        updates.isPinned = posInfo.isPinned;
        updates.order = posInfo.order;
        break;
      }
    }

    events.push(createChatUpdatedEvent(chatId, updates));
  }

  private handleChatPosition(events: AnyAppEvent[], update: TdObject): void {
    const chatId = tdGetNumber(update, 'chat_id');
    if (!chatId) return;

    const position = tdGetObject(update, 'position');
    if (!tdHasKeys(position)) return;

    const posInfo = extractMainListPosition(position);
    if (posInfo === undefined) return; // Not chatListMain — ignore (archive, folder, etc.)

    const updates = new ChatUpdateDto();
    updates.isPinned = posInfo.isPinned;
    updates.order = posInfo.order;
    events.push(createChatUpdatedEvent(chatId, updates));
  }

  private handleChatReadInbox(events: AnyAppEvent[], update: TdObject): void {
    const chatId = tdGetNumber(update, 'chat_id');
    if (!chatId) return;

    const event = new ChatReadInboxEvent();
    event.chatId = chatId;
    event.unreadCount = tdGetNumber(update, 'unread_count');
    event.lastReadInboxMessageId = tdGetInt64(update, 'last_read_inbox_message_id');
    event.timestamp = Date.now();
    events.push(event);
  }

  private handleChatReadOutbox(events: AnyAppEvent[], update: TdObject): void {
    const chatId = tdGetNumber(update, 'chat_id');
    if (!chatId) return;

    const event = new ChatReadOutboxEvent();
    event.chatId = chatId;
    event.lastReadOutboxMessageId = tdGetInt64(update, 'last_read_outbox_message_id');
    event.timestamp = Date.now();
    events.push(event);
  }

  /**
   * Обработка updateChatDraftMessage.
   * Huawei Best Practice: обрабатывать все важные TDLib события.
   */
  private handleChatDraftMessage(events: AnyAppEvent[], update: TdObject): void {
    const chatId = tdGetNumber(update, 'chat_id');
    if (!chatId) return;

    const updates = new ChatUpdateDto();

    // Extract draft message info
    const draftObj = tdGetObject(update, 'draft_message');
    if (tdHasKeys(draftObj)) {
      const inputMsg = tdGetObject(draftObj, 'input_message_text');
      if (tdHasKeys(inputMsg)) {
        const textObj = tdGetObject(inputMsg, 'text');
        updates.draftText = tdGetString(textObj, 'text');
      }
      updates.draftReplyToMessageId = tdGetInt64(draftObj, 'reply_to_message_id');
    } else {
      // Draft cleared
      updates.draftText = '';
      updates.draftReplyToMessageId = '0';
    }

    // Also extract positions if present
    const positions = tdGetArray(update, 'positions');
    for (const pos of positions) {
      const posInfo = extractMainListPosition(pos);
      if (posInfo !== undefined) {
        updates.order = posInfo.order;
        break;
      }
    }

    events.push(createChatUpdatedEvent(chatId, updates));
  }

  /**
   * Обработка updateChatUnreadMentionCount.
   */
  private handleChatUnreadMentionCount(events: AnyAppEvent[], update: TdObject): void {
    const chatId = tdGetNumber(update, 'chat_id');
    if (!chatId) return;

    const updates = new ChatUpdateDto();
    updates.unreadMentionCount = tdGetNumber(update, 'unread_mention_count');
    events.push(createChatUpdatedEvent(chatId, updates));
  }

  // =====================================================
  // MESSAGES
  // =====================================================

  private handleNewMessage(events: AnyAppEvent[], update: TdObject): void {
    const message = tdGetObject(update, 'message');
    const chatId = tdGetNumber(message, 'chat_id');
    const messageId = tdGetInt64(message, 'id');
    if (!chatId || messageId === '0') return;

    try {
      const messageDto = createMessageDtoFromTd(message);
      events.push(createNewMessageEvent(chatId, messageId, messageDto));
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to parse newMessage: %{public}s', String(error));
    }
  }

  private handleMessageContent(events: AnyAppEvent[], update: TdObject): void {
    const chatId = tdGetNumber(update, 'chat_id');
    const messageId = tdGetInt64(update, 'message_id');
    if (!chatId || messageId === '0') return;

    // Parse the actual new_content from TDLib
    const newContentObj = tdGetObject(update, 'new_content');
    const contentDto = parseMessageContent(newContentObj);

    const event = new MessageContentUpdatedEvent();
    event.chatId = chatId;
    event.messageId = messageId;
    event.newContent = contentDto;
    event.timestamp = Date.now();
    events.push(event);
  }

  private handleMessageSendSucceeded(events: AnyAppEvent[], update: TdObject): void {
    const message = tdGetObject(update, 'message');
    const oldMessageId = tdGetInt64(update, 'old_message_id');
    const chatId = tdGetNumber(message, 'chat_id');
    if (!chatId || oldMessageId === '0') return;

    try {
      const messageDto = createMessageDtoFromTd(message);

      const event = new MessageSendSucceededEvent();
      event.chatId = chatId;
      event.oldMessageId = oldMessageId;
      event.message = messageDto;
      event.timestamp = Date.now();
      events.push(event);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to parse messageSendSucceeded: %{public}s', String(error));
    }
  }

  private handleMessageSendFailed(events: AnyAppEvent[], update: TdObject): void {
    const message = tdGetObject(update, 'message');
    const oldMessageId = tdGetInt64(update, 'old_message_id');
    const chatId = tdGetNumber(message, 'chat_id');
    const messageId = tdGetInt64(message, 'id');
    if (!chatId || oldMessageId === '0') return;

    const errorObj = tdGetObject(update, 'error');
    const errorCode = tdGetNumber(errorObj, 'code');
    const errorMessage = tdGetString(errorObj, 'message');

    const event = new MessageSendFailedEvent();
    event.chatId = chatId;
    event.oldMessageId = oldMessageId;
    event.messageId = messageId;
    event.errorCode = errorCode;
    event.errorMessage = errorMessage;
    event.timestamp = Date.now();
    events.push(event);
  }

  private handleDeleteMessages(events: AnyAppEvent[], update: TdObject): void {
    const chatId = tdGetNumber(update, 'chat_id');
    if (!chatId) return;

    // TDLib sends isPermanent=false for cache-only deletions (e.g. chat history cleanup).
    // We only act on permanent deletes.
    const isPermanent = tdGetBoolean(update, 'is_permanent');
    const fromCache = tdGetBoolean(update, 'from_cache');

    // message_ids is array of int64 (primitives, not objects)
    const messageIds = tdGetStringArray(update, 'message_ids').filter((id: string) => id !== '0' && id !== '');

    if (messageIds.length === 0) return;

    const event = new MessagesDeletedEvent();
    event.chatId = chatId;
    event.messageIds = messageIds;
    event.isPermanent = isPermanent;
    event.fromCache = fromCache;
    event.timestamp = Date.now();
    events.push(event);
  }

  // =====================================================
  // USERS
  // =====================================================

  private handleUser(events: AnyAppEvent[], update: TdObject): void {
    const user = tdGetObject(update, 'user');
    const userId = tdGetNumber(user, 'id');
    if (!userId) return;

    try {
      const userDto = createUserDtoFromTd(user);

      const event = new UserUpdatedEvent();
      event.userId = userId;
      event.userData = userDto;
      event.timestamp = Date.now();
      events.push(event);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to parse user: %{public}s', String(error));
    }
  }

  private handleUserStatus(events: AnyAppEvent[], update: TdObject): void {
    const userId = tdGetNumber(update, 'user_id');
    if (!userId) return;

    const statusObj = tdGetObject(update, 'status');
    const status = parseUserStatus(statusObj);

    const event = new UserStatusChangedEvent();
    event.userId = userId;
    event.status = status;
    event.timestamp = Date.now();
    events.push(event);
  }
}

// Singleton instance
let instance: EventNormalizer | null = null;

export function getEventNormalizer(): EventNormalizer {
  if (!instance) {
    instance = new EventNormalizerImpl();
  }
  return instance;
}

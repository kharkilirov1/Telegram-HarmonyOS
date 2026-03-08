// LoadChatHistory use case - centralized history loading + normalize/dispatch pipeline
// Shared by OpenChat flow and ChatScreen fallback loader to avoid duplicated TDLib handling.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStore } from '../../core/store/AppStore';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { ChatId, MessageId } from '../../core/model/EntityId';
import { createGetChatHistoryCommand, createGetUserCommand } from '../../core/model/AppCommand';
import { getEventNormalizer } from '../../core/events/EventNormalizer';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { TdObject } from '../../models/TdTypes';
import { tdGetArray, tdGetObject, tdGetNumber, tdGetString, tdGetInt64, compareInt64 } from '../../core/utils/tdAccessors';

const TAG = 'LoadChatHistory';
const DOMAIN = 0x000D;
// Keep this comfortably above the default 50-message history page so one page
// can fully hydrate its sender set before the batch hits invariants/UI.
const MAX_MISSING_USER_HYDRATION_PER_LOAD = 64;
const MISSING_USER_HYDRATION_COOLDOWN_MS = 30000;
const NEWER_PAGE_OFFSET_DELTA = 1;
// TDLib can legally return much fewer messages than requested even when more
// history still exists, so treat tiny initial batches as ambiguous and top up
// once from the oldest anchor instead of freezing pagination immediately.
const INITIAL_HISTORY_TOP_UP_THRESHOLD = 12;
const INITIAL_HISTORY_MAX_TOP_UP_ATTEMPTS = 3;

export type LoadChatHistoryDirection = 'initial' | 'older' | 'newer';
export type LoadChatHistoryReason = 'default' | 'aroundUnread' | 'aroundMessage' | 'restore';

export class LoadChatHistoryParams {
  chatId: ChatId = 0;
  fromMessageId: MessageId = '0';
  offset: number = 0;
  limit: number = 50;
  onlyLocal: boolean = false;
  force: boolean = false;
  direction: LoadChatHistoryDirection = 'initial';
  reason: LoadChatHistoryReason = 'default';
}

class BucketReservation {
  bucketKey: string;
  requestSeq: number;

  constructor(bucketKey: string, requestSeq: number) {
    this.bucketKey = bucketKey;
    this.requestSeq = requestSeq;
  }
}

class MessageWindowResult {
  messageCount: number;
  oldestId: MessageId;
  newestId: MessageId;

  constructor(messageCount: number, oldestId: MessageId, newestId: MessageId) {
    this.messageCount = messageCount;
    this.oldestId = oldestId;
    this.newestId = newestId;
  }
}

export class LoadChatHistoryUseCase {
  private store: AppStore;
  private gateway: TdGatewayPort;
  private static inFlightChatIds: Set<ChatId> = new Set<ChatId>();
  private static inFlightRequestBuckets: Set<string> = new Set<string>();
  private static latestRequestSeqByBucket: Map<string, number> = new Map<string, number>();
  private static historyFetchedChatIds: Set<ChatId> = new Set<ChatId>();
  private static inFlightUserIds: Set<number> = new Set<number>();
  private static lastUserHydrationAt: Map<number, number> = new Map<number, number>();
  private static canLoadOlder: Map<ChatId, boolean> = new Map<ChatId, boolean>();
  private static canLoadNewer: Map<ChatId, boolean> = new Map<ChatId, boolean>();
  private static oldestMessageId: Map<ChatId, MessageId> = new Map<ChatId, MessageId>();
  private static newestMessageId: Map<ChatId, MessageId> = new Map<ChatId, MessageId>();

  constructor(store: AppStore, gateway: TdGatewayPort) {
    this.store = store;
    this.gateway = gateway;
  }

  /**
   * Clear all static caches. MUST be called during AppCoreRuntime shutdown/reset
   * to prevent stale state when a new runtime + store is created.
   */
  static resetState(): void {
    LoadChatHistoryUseCase.inFlightChatIds.clear();
    LoadChatHistoryUseCase.inFlightRequestBuckets.clear();
    LoadChatHistoryUseCase.latestRequestSeqByBucket.clear();
    LoadChatHistoryUseCase.historyFetchedChatIds.clear();
    LoadChatHistoryUseCase.inFlightUserIds.clear();
    LoadChatHistoryUseCase.lastUserHydrationAt.clear();
    LoadChatHistoryUseCase.canLoadOlder.clear();
    LoadChatHistoryUseCase.canLoadNewer.clear();
    LoadChatHistoryUseCase.oldestMessageId.clear();
    LoadChatHistoryUseCase.newestMessageId.clear();
    hilog.info(DOMAIN, TAG, 'Static state reset (all caches cleared)');
  }

  hasNonPendingMessages(chatId: ChatId): boolean {
    const existingMessages = this.store.getState().messages.messages.get(chatId);
    if (!existingMessages || existingMessages.size === 0) {
      return false;
    }
    for (const message of existingMessages.values()) {
      if (!message.isPending) {
        return true;
      }
    }
    return false;
  }

  hasHistoryBeenFetched(chatId: ChatId): boolean {
    return LoadChatHistoryUseCase.historyFetchedChatIds.has(chatId);
  }

  shouldRetry(chatId: ChatId): boolean {
    if (chatId === 0) {
      return false;
    }
    // If history was already fetched via getChatHistory — no retry needed
    if (this.hasHistoryBeenFetched(chatId)) {
      return false;
    }
    const chat = this.store.getState().chats.chats.get(chatId);
    if (!chat || !chat.lastMessage || chat.lastMessage.id === '0') {
      return false;
    }
    return true;
  }

  isLoading(chatId: ChatId, direction?: LoadChatHistoryDirection): boolean {
    if (direction !== undefined) {
      return LoadChatHistoryUseCase.inFlightRequestBuckets.has(this.getBucketKey(chatId, direction));
    }
    return LoadChatHistoryUseCase.inFlightChatIds.has(chatId);
  }

  canLoadOlderMessages(chatId: ChatId): boolean {
    const value = LoadChatHistoryUseCase.canLoadOlder.get(chatId);
    // Default to true if we haven't loaded yet (initial load hasn't set it)
    return value !== false;
  }

  getOldestMessageId(chatId: ChatId): MessageId {
    return LoadChatHistoryUseCase.oldestMessageId.get(chatId) || '0';
  }

  canLoadNewerMessages(chatId: ChatId): boolean {
    return LoadChatHistoryUseCase.canLoadNewer.get(chatId) === true;
  }

  getNewestMessageId(chatId: ChatId): MessageId {
    return LoadChatHistoryUseCase.newestMessageId.get(chatId) || '0';
  }

  private getBucketKey(chatId: ChatId, direction: LoadChatHistoryDirection): string {
    if (direction === 'older') {
      return chatId.toString() + ':older';
    }
    if (direction === 'newer') {
      return chatId.toString() + ':newer';
    }
    return chatId.toString() + ':primary';
  }

  private reserveBucket(chatId: ChatId, direction: LoadChatHistoryDirection): BucketReservation | null {
    const bucketKey = this.getBucketKey(chatId, direction);
    if (LoadChatHistoryUseCase.inFlightRequestBuckets.has(bucketKey)) {
      return null;
    }

    LoadChatHistoryUseCase.inFlightRequestBuckets.add(bucketKey);
    LoadChatHistoryUseCase.inFlightChatIds.add(chatId);
    const requestSeq = (LoadChatHistoryUseCase.latestRequestSeqByBucket.get(bucketKey) || 0) + 1;
    LoadChatHistoryUseCase.latestRequestSeqByBucket.set(bucketKey, requestSeq);
    return new BucketReservation(bucketKey, requestSeq);
  }

  private isLatestBucketRequest(bucketKey: string, requestSeq: number): boolean {
    return (LoadChatHistoryUseCase.latestRequestSeqByBucket.get(bucketKey) || 0) === requestSeq;
  }

  private releaseBucket(chatId: ChatId, bucketKey: string): void {
    LoadChatHistoryUseCase.inFlightRequestBuckets.delete(bucketKey);

    const chatPrefix = chatId.toString() + ':';
    for (const inFlightKey of LoadChatHistoryUseCase.inFlightRequestBuckets) {
      if (inFlightKey.startsWith(chatPrefix)) {
        return;
      }
    }

    LoadChatHistoryUseCase.inFlightChatIds.delete(chatId);
  }

  private updateMessageWindow(chatId: ChatId, messages: TdObject[]): MessageWindowResult {
    const messageCount = messages.length;
    let oldestId: MessageId = '0';
    let newestId: MessageId = '0';

    for (const msg of messages) {
      const msgId = tdGetInt64(msg, 'id');
      if (msgId === '' || msgId === '0') {
        continue;
      }
      if (oldestId === '0' || compareInt64(msgId, oldestId) < 0) {
        oldestId = msgId;
      }
      if (newestId === '0' || compareInt64(msgId, newestId) > 0) {
        newestId = msgId;
      }
    }

    if (oldestId !== '0') {
      const currentOldest = LoadChatHistoryUseCase.oldestMessageId.get(chatId) || '0';
      if (currentOldest === '0' || compareInt64(oldestId, currentOldest) < 0) {
        LoadChatHistoryUseCase.oldestMessageId.set(chatId, oldestId);
      }
    }

    if (newestId !== '0') {
      const currentNewest = LoadChatHistoryUseCase.newestMessageId.get(chatId) || '0';
      if (currentNewest === '0' || compareInt64(newestId, currentNewest) > 0) {
        LoadChatHistoryUseCase.newestMessageId.set(chatId, newestId);
      }
    }

    return new MessageWindowResult(messageCount, oldestId, newestId);
  }

  private refreshPaginationState(
    chatId: ChatId,
    params: LoadChatHistoryParams,
    messageWindow: MessageWindowResult,
    previousOldestId: MessageId,
    previousNewestId: MessageId
  ): void {
    const messageCount = messageWindow.messageCount;
    if (params.direction !== 'newer') {
      let canLoadOlder = true;
      if (messageCount === 0) {
        canLoadOlder = false;
      } else if (params.direction === 'older' &&
        previousOldestId !== '0' &&
        messageWindow.oldestId !== '0' &&
        compareInt64(messageWindow.oldestId, previousOldestId) >= 0) {
        canLoadOlder = false;
      }
      LoadChatHistoryUseCase.canLoadOlder.set(chatId, canLoadOlder);
    }

    if (params.direction !== 'older') {
      let canLoadNewer = false;
      const trackedNewestId = LoadChatHistoryUseCase.newestMessageId.get(chatId) || '0';
      const chat = this.store.getState().chats.chats.get(chatId);

      if (trackedNewestId !== '0' && chat && chat.lastMessage && chat.lastMessage.id !== '0') {
        canLoadNewer = compareInt64(trackedNewestId, chat.lastMessage.id) < 0;
      } else if (params.direction === 'newer') {
        canLoadNewer = messageCount > 0 &&
          previousNewestId !== '0' &&
          messageWindow.newestId !== '0' &&
          compareInt64(messageWindow.newestId, previousNewestId) > 0;
      } else if (params.fromMessageId !== '0' && params.offset <= -NEWER_PAGE_OFFSET_DELTA) {
        canLoadNewer = messageCount > 0;
      }

      LoadChatHistoryUseCase.canLoadNewer.set(chatId, canLoadNewer);
    }

    hilog.info(DOMAIN, TAG,
      'Window state for %{public}d: direction=%{public}s reason=%{public}s canOlder=%{public}s canNewer=%{public}s oldest=%{public}s newest=%{public}s',
      chatId,
      params.direction,
      params.reason,
      String(this.canLoadOlderMessages(chatId)),
      String(this.canLoadNewerMessages(chatId)),
      this.getOldestMessageId(chatId),
      this.getNewestMessageId(chatId));
  }

  private shouldTopUpInitialWindow(params: LoadChatHistoryParams, messageWindow: MessageWindowResult): boolean {
    if (params.direction !== 'initial' ||
      params.reason !== 'default' ||
      params.fromMessageId !== '0' ||
      params.offset !== 0) {
      return false;
    }
    if (messageWindow.oldestId === '0' || messageWindow.messageCount <= 0) {
      return false;
    }
    return messageWindow.messageCount < Math.min(params.limit, INITIAL_HISTORY_TOP_UP_THRESHOLD);
  }

  private async requestInitialOlderTopUp(chatId: ChatId, oldestId: MessageId, limit: number): Promise<void> {
    let currentOldestId = oldestId;
    for (let attempt = 0; attempt < INITIAL_HISTORY_MAX_TOP_UP_ATTEMPTS; attempt++) {
      const topUpParams = new LoadChatHistoryParams();
      topUpParams.chatId = chatId;
      topUpParams.fromMessageId = currentOldestId;
      topUpParams.limit = limit;
      topUpParams.direction = 'older';
      topUpParams.reason = 'default';

      if (attempt === 0) {
        hilog.info(DOMAIN, TAG,
          'Short initial history window for %{public}d; requesting one controlled older top-up from %{public}s',
          chatId, currentOldestId);
      } else {
        hilog.info(DOMAIN, TAG,
          'Initial history for %{public}d still shallow; requesting extra older top-up #%{public}d from %{public}s',
          chatId, attempt + 1, currentOldestId);
      }

      const oldestBeforeRequest = this.getOldestMessageId(chatId);
      try {
        await this.execute(topUpParams);
      } catch (error) {
        hilog.warn(DOMAIN, TAG,
          'Initial older top-up failed for %{public}d from %{public}s: %{public}s',
          chatId, currentOldestId, String(error));
        return;
      }

      const chatMessages = this.store.getState().messages.messages.get(chatId);
      const visibleMessageCount = chatMessages ? chatMessages.size : 0;
      const newestOldestId = this.getOldestMessageId(chatId);
      const progressed = newestOldestId !== '0' &&
        (oldestBeforeRequest === '0' || compareInt64(newestOldestId, oldestBeforeRequest) < 0);

      if (!this.canLoadOlderMessages(chatId) ||
        !progressed ||
        visibleMessageCount >= Math.min(limit, INITIAL_HISTORY_TOP_UP_THRESHOLD)) {
        return;
      }

      currentOldestId = newestOldestId;
    }
  }

  private collectMissingSenderIds(historyResponse: TdObject): number[] {
    const missingSenderIds: number[] = [];
    const seenUserIds: Set<number> = new Set<number>();
    const usersMap = this.store.getState().users.users;
    const now = Date.now();

    const messages = tdGetArray(historyResponse, 'messages');
    for (const message of messages) {
      const sender = tdGetObject(message, 'sender_id');
      const senderType = tdGetString(sender, '@type');
      if (senderType !== 'messageSenderUser') {
        continue;
      }

      const senderId = tdGetNumber(sender, 'user_id');
      if (senderId <= 0 || seenUserIds.has(senderId) || usersMap.has(senderId)) {
        continue;
      }
      if (LoadChatHistoryUseCase.inFlightUserIds.has(senderId)) {
        continue;
      }

      const lastRequestedAt = LoadChatHistoryUseCase.lastUserHydrationAt.get(senderId) || 0;
      if ((now - lastRequestedAt) < MISSING_USER_HYDRATION_COOLDOWN_MS) {
        continue;
      }

      seenUserIds.add(senderId);
      missingSenderIds.push(senderId);
      if (missingSenderIds.length >= MAX_MISSING_USER_HYDRATION_PER_LOAD) {
        break;
      }
    }

    return missingSenderIds;
  }

  private async hydrateMissingUsers(userIds: number[]): Promise<void> {
    for (const userId of userIds) {
      if (userId <= 0 || this.store.getState().users.users.has(userId)) {
        continue;
      }
      if (LoadChatHistoryUseCase.inFlightUserIds.has(userId)) {
        continue;
      }

      LoadChatHistoryUseCase.inFlightUserIds.add(userId);
      LoadChatHistoryUseCase.lastUserHydrationAt.set(userId, Date.now());
      try {
        const response = await this.gateway.send(createGetUserCommand(userId));
        const normalizedResponse = response as TdObject;
        if (!(normalizedResponse instanceof TdObject)) {
          continue;
        }

        const events = getEventNormalizer().normalize(normalizedResponse);
        if (events.length > 0) {
          await this.store.dispatchBatch(events);
        }
      } catch (error) {
        hilog.info(DOMAIN, TAG,
          'Unable to hydrate user %{public}d from history sender set: %{public}s',
          userId, String(error));
      } finally {
        LoadChatHistoryUseCase.inFlightUserIds.delete(userId);
      }
    }
  }

  async hydrateUsersIfMissing(userIds: number[]): Promise<number> {
    if (userIds.length === 0) {
      return 0;
    }

    const eligibleUserIds: number[] = [];
    const seenUserIds: Set<number> = new Set<number>();
    const usersMap = this.store.getState().users.users;
    const now = Date.now();

    for (const userId of userIds) {
      if (userId <= 0 || seenUserIds.has(userId) || usersMap.has(userId)) {
        continue;
      }
      if (LoadChatHistoryUseCase.inFlightUserIds.has(userId)) {
        continue;
      }

      const lastRequestedAt = LoadChatHistoryUseCase.lastUserHydrationAt.get(userId) || 0;
      if ((now - lastRequestedAt) < MISSING_USER_HYDRATION_COOLDOWN_MS) {
        continue;
      }

      seenUserIds.add(userId);
      eligibleUserIds.push(userId);
      if (eligibleUserIds.length >= MAX_MISSING_USER_HYDRATION_PER_LOAD) {
        break;
      }
    }

    if (eligibleUserIds.length === 0) {
      return 0;
    }

    await this.hydrateMissingUsers(eligibleUserIds);
    return eligibleUserIds.length;
  }

  async execute(params: LoadChatHistoryParams): Promise<boolean> {
    const chatId = params.chatId;
    if (chatId === 0) {
      return false;
    }

    const isPagination = params.fromMessageId !== '0';

    // Block only initial loads (not pagination) via historyFetchedChatIds
    if (!params.force && !isPagination && this.hasHistoryBeenFetched(chatId)) {
      hilog.info(DOMAIN, TAG,
        'Skipping history load for %{public}d (getChatHistory already completed)',
        chatId);
      return false;
    }

    const bucketReservation = this.reserveBucket(chatId, params.direction);
    if (bucketReservation === null) {
      hilog.info(DOMAIN, TAG, 'History load already in progress for %{public}d bucket=%{public}s',
        chatId, this.getBucketKey(chatId, params.direction));
      return false;
    }

    try {
      const command = createGetChatHistoryCommand(
        chatId,
        params.fromMessageId,
        params.offset,
        params.limit,
        params.onlyLocal
      );
      const response = await this.gateway.send(command);
      const normalizedResponse = response as TdObject;
      if (!(normalizedResponse instanceof TdObject)) {
        hilog.warn(DOMAIN, TAG, 'getChatHistory returned non-object response');
        return false;
      }

      if (!this.isLatestBucketRequest(bucketReservation.bucketKey, bucketReservation.requestSeq)) {
        hilog.info(DOMAIN, TAG, 'Ignoring stale history response for %{public}d bucket=%{public}s seq=%{public}d',
          chatId, bucketReservation.bucketKey, bucketReservation.requestSeq);
        return false;
      }

      const previousOldestId = this.getOldestMessageId(chatId);
      const previousNewestId = this.getNewestMessageId(chatId);
      const messages = tdGetArray(normalizedResponse, 'messages');
      const messageWindow = this.updateMessageWindow(chatId, messages);
      const deferInitialDispatchForTopUp = this.shouldTopUpInitialWindow(params, messageWindow);
      if (deferInitialDispatchForTopUp) {
        hilog.info(DOMAIN, TAG,
          'Deferring dispatch of short initial batch for %{public}d until older top-up completes',
          chatId);
        await this.requestInitialOlderTopUp(chatId, messageWindow.oldestId, params.limit);
      }

      const missingSenderIds = this.collectMissingSenderIds(normalizedResponse);
      if (missingSenderIds.length > 0) {
        hilog.info(DOMAIN, TAG, 'Hydrating %{public}d missing users for chat %{public}d',
          missingSenderIds.length, chatId);
        await this.hydrateMissingUsers(missingSenderIds);
      }

      const events = getEventNormalizer().normalize(normalizedResponse);
      if (events.length > 0) {
        await this.store.dispatchBatch(events);
        LoadChatHistoryUseCase.historyFetchedChatIds.add(chatId);
        hilog.info(DOMAIN, TAG, 'History fetched and dispatched for chat %{public}d (%{public}d events)',
          chatId, events.length);
      } else {
        hilog.warn(DOMAIN, TAG,
          'getChatHistory for %{public}d returned 0 events — NOT marking as fetched (will retry)',
          chatId);
      }

      // Track pagination state: oldest message and whether more history exists
      this.refreshPaginationState(chatId, params, messageWindow, previousOldestId, previousNewestId);

      return true;
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'History load failed for %{public}d: %{public}s',
        chatId, String(error));
      throw new AppError(
        AppErrorKind.NETWORK,
        `Failed to load history for chat ${chatId}`,
        String(error),
        0,
        true
      );
    } finally {
      this.releaseBucket(chatId, bucketReservation.bucketKey);
    }
  }
}

export function createLoadChatHistoryUseCase(
  store: AppStore,
  gateway: TdGatewayPort
): LoadChatHistoryUseCase {
  return new LoadChatHistoryUseCase(store, gateway);
}

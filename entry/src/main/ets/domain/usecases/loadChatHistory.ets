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
import { tdGetArray, tdGetObject, tdGetNumber, tdGetString } from '../../core/utils/tdAccessors';

const TAG = 'LoadChatHistory';
const DOMAIN = 0x000D;
const MAX_MISSING_USER_HYDRATION_PER_LOAD = 8;
const MISSING_USER_HYDRATION_COOLDOWN_MS = 30000;

export class LoadChatHistoryParams {
  chatId: ChatId = 0;
  fromMessageId: MessageId = '0';
  offset: number = 0;
  limit: number = 50;
  onlyLocal: boolean = false;
  force: boolean = false;
}

export class LoadChatHistoryUseCase {
  private store: AppStore;
  private gateway: TdGatewayPort;
  private static inFlightChatIds: Set<ChatId> = new Set<ChatId>();
  private static inFlightUserIds: Set<number> = new Set<number>();
  private static lastUserHydrationAt: Map<number, number> = new Map<number, number>();

  constructor(store: AppStore, gateway: TdGatewayPort) {
    this.store = store;
    this.gateway = gateway;
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

  shouldRetry(chatId: ChatId): boolean {
    if (chatId === 0) {
      return false;
    }
    if (this.hasNonPendingMessages(chatId)) {
      return false;
    }
    const chat = this.store.getState().chats.chats.get(chatId);
    if (!chat || !chat.lastMessage || chat.lastMessage.id === '0') {
      return false;
    }
    return true;
  }

  isLoading(chatId: ChatId): boolean {
    return LoadChatHistoryUseCase.inFlightChatIds.has(chatId);
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
        for (const event of events) {
          await this.store.dispatch(event);
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

  async execute(params: LoadChatHistoryParams): Promise<boolean> {
    const chatId = params.chatId;
    if (chatId === 0) {
      return false;
    }

    if (!params.force && this.hasNonPendingMessages(chatId)) {
      hilog.info(DOMAIN, TAG,
        'Skipping history load for %{public}d (cache has non-pending messages)',
        chatId);
      return false;
    }

    if (this.isLoading(chatId)) {
      hilog.info(DOMAIN, TAG, 'History load already in progress for %{public}d', chatId);
      return false;
    }

    LoadChatHistoryUseCase.inFlightChatIds.add(chatId);
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

      const events = getEventNormalizer().normalize(normalizedResponse);
      for (const event of events) {
        await this.store.dispatch(event);
      }

      const missingSenderIds = this.collectMissingSenderIds(normalizedResponse);
      if (missingSenderIds.length > 0) {
        hilog.info(DOMAIN, TAG, 'Hydrating %{public}d missing users for chat %{public}d',
          missingSenderIds.length, chatId);
        await this.hydrateMissingUsers(missingSenderIds);
      }

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
      LoadChatHistoryUseCase.inFlightChatIds.delete(chatId);
    }
  }
}

export function createLoadChatHistoryUseCase(
  store: AppStore,
  gateway: TdGatewayPort
): LoadChatHistoryUseCase {
  return new LoadChatHistoryUseCase(store, gateway);
}

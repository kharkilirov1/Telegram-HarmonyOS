// MarkChatRead use case - marks chat messages as read
// Business logic for read receipts and unread counts

import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStore } from '../../core/store/AppStore';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { ChatId, MessageId } from '../../core/model/EntityId';
import { createViewMessagesCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { compareInt64 } from '../../core/utils/tdAccessors';

const TAG = 'MarkChatRead';
const DOMAIN = 0x0009;

export interface MarkChatReadParams {
  chatId: ChatId;
  messageIds?: MessageId[]; // Specific messages to mark as read
  forceReadAll?: boolean; // Mark all messages as read
}

export class MarkChatReadUseCase {
  private store: AppStore;
  private gateway: TdGatewayPort;

  constructor(store: AppStore, gateway: TdGatewayPort) {
    this.store = store;
    this.gateway = gateway;
  }

  // Main entry point
  async execute(params: MarkChatReadParams): Promise<void> {
    const chatId = params.chatId;
    const messageIds = params.messageIds;
    const forceReadAll = params.forceReadAll !== undefined ? params.forceReadAll : false;

    try {
      hilog.info(DOMAIN, TAG, 'Marking chat %{public}d as read', chatId);

      if (forceReadAll) {
        await this.markAllMessagesRead(chatId);
      } else if (messageIds && messageIds.length > 0) {
        await this.markMessagesRead(chatId, messageIds);
      } else {
        await this.markLastMessageRead(chatId);
      }

      hilog.info(DOMAIN, TAG, 'Chat marked as read successfully');

    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Failed to mark chat as read: %{public}s', err.message);

      throw new AppError(
        AppErrorKind.UNKNOWN,
        `Failed to mark chat ${chatId} as read`,
        err.message,
        0,
        true
      );
    }
  }

  // Mark specific messages as read
  private async markMessagesRead(chatId: ChatId, messageIds: MessageId[]): Promise<void> {
    hilog.debug(DOMAIN, TAG, 'Marking %{public}d messages as read', messageIds.length);

    const command = createViewMessagesCommand(chatId, messageIds);
    await this.gateway.send(command);
  }

  // Mark all messages as read
  private async markAllMessagesRead(chatId: ChatId): Promise<void> {
    hilog.debug(DOMAIN, TAG, 'Marking all messages as read for chat %{public}d', chatId);

    const targetMessageId = this.resolveReadTargetMessageId(chatId, false);
    if (targetMessageId === '0') {
      return;
    }
    await this.markMessagesRead(chatId, [targetMessageId]);
  }

  // Mark last message as read
  private async markLastMessageRead(chatId: ChatId): Promise<void> {
    hilog.debug(DOMAIN, TAG, 'Marking last message as read for chat %{public}d', chatId);

    const targetMessageId = this.resolveReadTargetMessageId(chatId, true);
    if (targetMessageId === '0') {
      return;
    }
    await this.markMessagesRead(chatId, [targetMessageId]);
  }

  // Check if chat has unread messages
  hasUnreadMessages(chatId: ChatId): boolean {
    const state = this.store.getState();
    const chat = state.chats.chats.get(chatId);
    return chat !== undefined && chat.unreadCount > 0;
  }

  private resolveReadTargetMessageId(chatId: ChatId, preferUnreadIncoming: boolean): MessageId {
    const state = this.store.getState();
    const chat = state.chats.chats.get(chatId);
    if (!chat) {
      return '0';
    }

    const messagesByChat = state.messages.messages.get(chatId);
    let selectedId: MessageId = '0';
    let selectedTimestamp: number = 0;

    if (messagesByChat) {
      for (const message of messagesByChat.values()) {
        if (preferUnreadIncoming) {
          if (message.isOutgoing || message.isRead) {
            continue;
          }
          if (chat.lastReadInboxMessageId !== '0' && compareInt64(message.id, chat.lastReadInboxMessageId) <= 0) {
            continue;
          }
        }

        if (selectedId === '0') {
          selectedId = message.id;
          selectedTimestamp = message.timestamp;
          continue;
        }

        if (message.timestamp > selectedTimestamp) {
          selectedId = message.id;
          selectedTimestamp = message.timestamp;
          continue;
        }

        if (message.timestamp === selectedTimestamp && compareInt64(message.id, selectedId) > 0) {
          selectedId = message.id;
        }
      }
    }

    if (selectedId !== '0') {
      return selectedId;
    }

    if (chat.lastMessage) {
      return chat.lastMessage.id;
    }

    return '0';
  }
}

// Factory function
export function createMarkChatReadUseCase(
  store: AppStore,
  gateway: TdGatewayPort
): MarkChatReadUseCase {
  return new MarkChatReadUseCase(store, gateway);
}

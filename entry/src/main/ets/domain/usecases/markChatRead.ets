// MarkChatRead use case - marks chat messages as read
// Business logic for read receipts and unread counts

import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStore } from '../../core/store/AppStore';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { ChatId, MessageId } from '../../core/model/EntityId';
import { createViewMessagesCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';

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

    // TODO: In TDLib, use viewMessages with last message ID
    // or toggleChatIsMarkedAsUnread
  }

  // Mark last message as read
  private async markLastMessageRead(chatId: ChatId): Promise<void> {
    hilog.debug(DOMAIN, TAG, 'Marking last message as read for chat %{public}d', chatId);

    // TODO: Get last message ID from store state via selectors
  }

  // Check if chat has unread messages
  hasUnreadMessages(chatId: ChatId): boolean {
    // TODO: Use selectChatById selector
    return false;
  }
}

// Factory function
export function createMarkChatReadUseCase(
  store: AppStore,
  gateway: TdGatewayPort
): MarkChatReadUseCase {
  return new MarkChatReadUseCase(store, gateway);
}

// ToggleChatUnread use case — marks a chat as read or unread via TDLib
// TDLib responds with updateChatIsMarkedAsUnread → normalizer → reducer

import { hilog } from '@kit.PerformanceAnalysisKit';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { ChatId } from '../../core/model/EntityId';
import { createGetChatCommand, createToggleChatIsMarkedAsUnreadCommand, createViewMessagesCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { TdObject } from '../../models/TdTypes';

const TAG = 'ToggleChatUnread';
const DOMAIN = 0x0017;

export class ToggleChatUnreadUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async markAsUnread(chatId: ChatId): Promise<void> {
    if (!Number.isSafeInteger(chatId) || chatId === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400, false);
    }

    try {
      hilog.info(DOMAIN, TAG, 'Marking chat %{public}d as unread', chatId);
      const command = createToggleChatIsMarkedAsUnreadCommand(chatId, true);
      this.requireOk(await this.gateway.send(command));
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Mark unread failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to mark as unread', err.message, 0, true);
    }
  }

  async markAsRead(chatId: ChatId): Promise<void> {
    if (!Number.isSafeInteger(chatId) || chatId === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400, false);
    }

    try {
      hilog.info(DOMAIN, TAG, 'Marking chat %{public}d as read', chatId);
      // The manual unread flag is independent of the inbox read boundary.
      // Resolve the chat's last message, not an incomplete loaded history window.
      const response = await this.gateway.send(createGetChatCommand(chatId));
      if (!(response instanceof TdObject) || response.getTopLevelStringStrict('@type') !== 'chat' ||
        response.getTopLevelNumberStrict('id') !== chatId) {
        throw new Error('Invalid chat response');
      }
      if (response.isTopLevelNullOrMissing('last_message')) {
        // TDLib also uses null when the last message is unknown. Do not claim
        // that an unread inbox was read without a usable server-side boundary.
        if (response.getTopLevelNumberStrict('unread_count') !== 0) {
          throw new Error('Read boundary is not available');
        }
      } else {
        const lastMessage = response.getTopLevelObjectStrict('last_message');
        const messageId = lastMessage?.getTopLevelNumberStrict('id');
        if (lastMessage?.getTopLevelStringStrict('@type') !== 'message' ||
          lastMessage.getTopLevelNumberStrict('chat_id') !== chatId ||
          messageId === undefined || !Number.isSafeInteger(messageId) || messageId <= 0) {
          throw new Error('Invalid last message response');
        }
        // TDLib acknowledges viewMessages for yet-unsent IDs without advancing
        // the inbox. Fail explicitly instead of presenting that Ok as success.
        if (!lastMessage.isTopLevelNullOrMissing('sending_state') ||
          !lastMessage.isTopLevelNullOrMissing('scheduling_state')) {
          throw new Error('Last message is not a committed read boundary');
        }
        // Serializer sets force_read=true: this action also works for closed chats.
        this.requireOk(await this.gateway.send(createViewMessagesCommand(chatId, [String(messageId)])));
      }
      const command = createToggleChatIsMarkedAsUnreadCommand(chatId, false);
      this.requireOk(await this.gateway.send(command));
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Mark read failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to mark as read', err.message, 0, true);
    }
  }

  private requireOk(response: Object): void {
    if (!(response instanceof TdObject) || response.getTopLevelStringStrict('@type') !== 'ok') {
      throw new Error('Missing TDLib acknowledgement');
    }
  }
}

export function createToggleChatUnreadUseCase(gateway: TdGatewayPort): ToggleChatUnreadUseCase {
  return new ToggleChatUnreadUseCase(gateway);
}

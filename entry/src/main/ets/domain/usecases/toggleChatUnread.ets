// ToggleChatUnread use case — marks a chat as read or unread via TDLib
// TDLib responds with updateChatIsMarkedAsUnread → normalizer → reducer

import { hilog } from '@kit.PerformanceAnalysisKit';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { ChatId } from '../../core/model/EntityId';
import { createToggleChatIsMarkedAsUnreadCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';

const TAG = 'ToggleChatUnread';
const DOMAIN = 0x0017;

export class ToggleChatUnreadUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async markAsUnread(chatId: ChatId): Promise<void> {
    if (!chatId || chatId === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400, false);
    }

    try {
      hilog.info(DOMAIN, TAG, 'Marking chat %{public}d as unread', chatId);
      const command = createToggleChatIsMarkedAsUnreadCommand(chatId, true);
      await this.gateway.send(command);
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Mark unread failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to mark as unread', err.message, 0, true);
    }
  }

  async markAsRead(chatId: ChatId): Promise<void> {
    if (!chatId || chatId === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400, false);
    }

    try {
      hilog.info(DOMAIN, TAG, 'Marking chat %{public}d as read', chatId);
      const command = createToggleChatIsMarkedAsUnreadCommand(chatId, false);
      await this.gateway.send(command);
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Mark read failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to mark as read', err.message, 0, true);
    }
  }
}

export function createToggleChatUnreadUseCase(gateway: TdGatewayPort): ToggleChatUnreadUseCase {
  return new ToggleChatUnreadUseCase(gateway);
}

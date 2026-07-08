// ToggleChatPinned use case — pin/unpin a chat in the main chat list
// TDLib responds with updateChatPosition → ChatNormalizer → chatsReducer

import { hilog } from '@kit.PerformanceAnalysisKit';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { ChatId } from '../../core/model/EntityId';
import { createToggleChatPinnedCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';

const TAG = 'ToggleChatPinned';
const DOMAIN = 0x0014;

export class ToggleChatPinnedUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async setPinned(chatId: ChatId, isPinned: boolean): Promise<void> {
    if (!chatId || chatId === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400, false);
    }

    try {
      hilog.info(DOMAIN, TAG, 'Toggling pin for chat %{public}d -> %{public}s', chatId, String(isPinned));
      const command = createToggleChatPinnedCommand(chatId, isPinned);
      await this.gateway.send(command);
      hilog.info(DOMAIN, TAG, 'Chat pin toggled');
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Pin toggle failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to toggle chat pin', err.message, 0, true);
    }
  }
}

export function createToggleChatPinnedUseCase(gateway: TdGatewayPort): ToggleChatPinnedUseCase {
  return new ToggleChatPinnedUseCase(gateway);
}

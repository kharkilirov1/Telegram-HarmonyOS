// PinChatMessage use case — pin/unpin messages in a chat via TDLib
// TDLib responds with updateChatLastMessage / updateMessageIsPinned → normalizers → reducers

import { hilog } from '@kit.PerformanceAnalysisKit';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { ChatId, MessageId } from '../../core/model/EntityId';
import { createPinChatMessageCommand, createUnpinChatMessageCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';

const TAG = 'PinChatMessage';
const DOMAIN = 0x0015;

export class PinChatMessageUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async pin(chatId: ChatId, messageId: MessageId, disableNotification: boolean = false, onlyForSelf: boolean = false): Promise<void> {
    if (!chatId || chatId === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400, false);
    }
    if (!messageId || messageId === '0') {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid messageId', 'Input validation failed', 400, false);
    }

    try {
      hilog.info(DOMAIN, TAG, 'Pinning message %{public}s in chat %{public}d', messageId, chatId);
      const command = createPinChatMessageCommand(chatId, messageId, disableNotification, onlyForSelf);
      await this.gateway.send(command);
      hilog.info(DOMAIN, TAG, 'Message pinned');
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Pin failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to pin message', err.message, 0, true);
    }
  }

  async unpin(chatId: ChatId, messageId: MessageId): Promise<void> {
    if (!chatId || chatId === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400, false);
    }
    if (!messageId || messageId === '0') {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid messageId', 'Input validation failed', 400, false);
    }

    try {
      hilog.info(DOMAIN, TAG, 'Unpinning message %{public}s in chat %{public}d', messageId, chatId);
      const command = createUnpinChatMessageCommand(chatId, messageId);
      await this.gateway.send(command);
      hilog.info(DOMAIN, TAG, 'Message unpinned');
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Unpin failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to unpin message', err.message, 0, true);
    }
  }
}

export function createPinChatMessageUseCase(gateway: TdGatewayPort): PinChatMessageUseCase {
  return new PinChatMessageUseCase(gateway);
}

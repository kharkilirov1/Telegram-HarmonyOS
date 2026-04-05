// DeleteChatHistory use case — deletes chat history and optionally removes from list
// TDLib removes the chat from the list via updateChatLastMessage / updateChatPosition

import { hilog } from '@kit.PerformanceAnalysisKit';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { ChatId } from '../../core/model/EntityId';
import { createDeleteChatHistoryCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';

const TAG = 'DeleteChatHistory';
const DOMAIN = 0x0016;

export class DeleteChatHistoryUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async execute(chatId: ChatId, removeFromChatList: boolean = true, revoke: boolean = false): Promise<void> {
    if (!chatId || chatId === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400, false);
    }

    try {
      hilog.info(DOMAIN, TAG, 'Deleting chat history %{public}d (remove=%{public}s, revoke=%{public}s)',
        chatId, String(removeFromChatList), String(revoke));
      const command = createDeleteChatHistoryCommand(chatId, removeFromChatList, revoke);
      await this.gateway.send(command);
      hilog.info(DOMAIN, TAG, 'Chat history deleted');
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Delete failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to delete chat', err.message, 0, true);
    }
  }
}

export function createDeleteChatHistoryUseCase(gateway: TdGatewayPort): DeleteChatHistoryUseCase {
  return new DeleteChatHistoryUseCase(gateway);
}

// DeleteMessages use case — deletes messages via TDLib
// TDLib responds with updateDeleteMessages → MessageNormalizer → messagesReducer

import { hilog } from '@kit.PerformanceAnalysisKit';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { ChatId, MessageId } from '../../core/model/EntityId';
import { createDeleteMessagesCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';

const TAG = 'DeleteMessages';
const DOMAIN = 0x0011;

export class DeleteMessagesParams {
  chatId: ChatId = 0;
  messageIds: MessageId[] = [];
  revoke: boolean = true; // true = delete for everyone, false = delete for self
}

export class DeleteMessagesUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async execute(params: DeleteMessagesParams): Promise<void> {
    if (!params.chatId || params.chatId === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400, false);
    }
    if (!params.messageIds || params.messageIds.length === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'No messages to delete', 'Input validation failed', 400, false);
    }

    try {
      hilog.info(DOMAIN, TAG, 'Deleting %{public}d messages in chat %{public}d (revoke=%{public}s)',
        params.messageIds.length, params.chatId, String(params.revoke));

      const command = createDeleteMessagesCommand(params.chatId, params.messageIds, params.revoke);
      await this.gateway.send(command);

      hilog.info(DOMAIN, TAG, 'Messages deleted successfully');
      // TDLib will send updateDeleteMessages via event pipeline
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Failed to delete messages: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to delete messages', err.message, 0, true);
    }
  }
}

export function createDeleteMessagesUseCase(gateway: TdGatewayPort): DeleteMessagesUseCase {
  return new DeleteMessagesUseCase(gateway);
}

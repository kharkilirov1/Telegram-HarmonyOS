// ForwardMessages use case — forwards messages to another chat via TDLib
// TDLib responds with updateNewMessage for each forwarded message

import { hilog } from '@kit.PerformanceAnalysisKit';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { ChatId, MessageId } from '../../core/model/EntityId';
import { createForwardMessagesCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';

const TAG = 'ForwardMessages';
const DOMAIN = 0x0012;

export class ForwardMessagesParams {
  chatId: ChatId = 0;         // target chat
  fromChatId: ChatId = 0;     // source chat
  messageIds: MessageId[] = [];
  sendCopy: boolean = false;       // true = copy without "Forwarded from" header
  removeCaption: boolean = false;  // true = remove caption from media
}

export class ForwardMessagesUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async execute(params: ForwardMessagesParams): Promise<void> {
    if (!params.chatId || params.chatId === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid target chatId', 'Input validation failed', 400, false);
    }
    if (!params.fromChatId || params.fromChatId === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid source chatId', 'Input validation failed', 400, false);
    }
    if (!params.messageIds || params.messageIds.length === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'No messages to forward', 'Input validation failed', 400, false);
    }

    try {
      hilog.info(DOMAIN, TAG, 'Forwarding %{public}d messages from chat %{public}d to chat %{public}d',
        params.messageIds.length, params.fromChatId, params.chatId);

      const command = createForwardMessagesCommand(
        params.chatId, params.fromChatId, params.messageIds,
        params.sendCopy, params.removeCaption
      );
      await this.gateway.send(command);

      hilog.info(DOMAIN, TAG, 'Messages forwarded successfully');
      // TDLib will send updateNewMessage for each forwarded message via event pipeline
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Failed to forward messages: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to forward messages', err.message, 0, true);
    }
  }
}

export function createForwardMessagesUseCase(gateway: TdGatewayPort): ForwardMessagesUseCase {
  return new ForwardMessagesUseCase(gateway);
}

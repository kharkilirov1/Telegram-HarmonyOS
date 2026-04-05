// EditMessage use case — edits text of an existing message via TDLib
// TDLib responds with updateMessageContent → MessageNormalizer → messagesReducer

import { hilog } from '@kit.PerformanceAnalysisKit';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { ChatId, MessageId } from '../../core/model/EntityId';
import { createEditMessageTextCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';

const TAG = 'EditMessage';
const DOMAIN = 0x0010;

const MAX_MESSAGE_LENGTH = 4096;

export class EditMessageParams {
  chatId: ChatId = 0;
  messageId: MessageId = '0';
  text: string = '';
}

export class EditMessageUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async execute(params: EditMessageParams): Promise<void> {
    if (!params.chatId || params.chatId === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400, false);
    }
    if (!params.messageId || params.messageId === '0') {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid messageId', 'Input validation failed', 400, false);
    }
    if (!params.text || params.text.length === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Message text is empty', 'Input validation failed', 400, false);
    }
    if (params.text.length > MAX_MESSAGE_LENGTH) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, `Message too long: ${params.text.length} > ${MAX_MESSAGE_LENGTH}`, 'Input validation failed', 400, false);
    }

    try {
      hilog.info(DOMAIN, TAG, 'Editing message %{public}s in chat %{public}d', params.messageId, params.chatId);
      const command = createEditMessageTextCommand(params.chatId, params.messageId, params.text);
      await this.gateway.send(command);
      hilog.info(DOMAIN, TAG, 'Message edited successfully');
      // TDLib will send updateMessageContent via event pipeline
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Failed to edit message: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, `Failed to edit message ${params.messageId}`, err.message, 0, true);
    }
  }
}

export function createEditMessageUseCase(gateway: TdGatewayPort): EditMessageUseCase {
  return new EditMessageUseCase(gateway);
}

// SetMessageReactions use case — set or clear reactions on one message via TDLib.
// TDLib answers with updateMessageReactions, so the reducer applies the canonical snapshot; this use
// case only proves the command was accepted (or rejected) for the optimistic rollback in the
// controller.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { ChatId, MessageId } from '../../core/model/EntityId';
import { createSetMessageReactionsCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';

const TAG = 'SetMessageReactions';
const DOMAIN = 0x0014;

export class SetMessageReactionsUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  // Empty list removes every reaction the current account has on the message.
  async set(chatId: ChatId, messageId: MessageId, reactionKeys: string[]): Promise<void> {
    if (!chatId || messageId === '0') {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chat or message id',
        'Input validation failed', 400, false);
    }
    try {
      await this.gateway.send(createSetMessageReactionsCommand(chatId, messageId, reactionKeys));
      hilog.info(DOMAIN, TAG, 'Reactions sent for message %{public}s (%{public}d types)',
        messageId, reactionKeys.length);
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Reactions failed for message %{public}s: %{public}s',
        messageId, err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to set message reactions', err.message, 0, true);
    }
  }
}

export function createSetMessageReactionsUseCase(gateway: TdGatewayPort): SetMessageReactionsUseCase {
  return new SetMessageReactionsUseCase(gateway);
}

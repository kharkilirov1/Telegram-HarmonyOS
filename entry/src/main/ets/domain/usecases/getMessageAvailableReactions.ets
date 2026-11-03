// GetMessageAvailableReactions use case — the per-message picker list.
// TDLib answers with `availableReactions` (top/recent/popular reaction types plus custom-emoji
// permission); the picker merges those keys and falls back to the chat-level list on failure, so a
// rejected request degrades to "same as before" instead of an empty menu.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { ChatId, MessageId } from '../../core/model/EntityId';
import { createGetMessageAvailableReactionsCommand } from '../../core/model/AppCommand';
import {
  MessageAvailableReactionsSnapshot,
  parseAvailableReactions
} from '../../core/model/dto/MessageDto';
import { TdObject } from '../../models/TdTypes';

const TAG = 'GetMessageAvailableReactions';
const DOMAIN = 0x0014;
// One comfortable row on a phone; iOS asks for a similar row size.
const DEFAULT_ROW_SIZE = 12;

export class GetMessageAvailableReactionsUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  // Never throws: the picker degrades to the chat-level list, so a transport failure must not break
  // opening the message actions.
  async load(chatId: ChatId, messageId: MessageId,
    rowSize: number = DEFAULT_ROW_SIZE): Promise<MessageAvailableReactionsSnapshot> {
    const empty = new MessageAvailableReactionsSnapshot();
    if (!chatId || messageId === '0') {
      return empty;
    }
    try {
      const response = await this.gateway.send(
        createGetMessageAvailableReactionsCommand(chatId, messageId, rowSize)) as TdObject;
      return parseAvailableReactions(response);
    } catch (error) {
      const err = error as Error;
      hilog.warn(DOMAIN, TAG, 'Available reactions failed for message %{public}s: %{public}s',
        messageId, err.message);
      return empty;
    }
  }
}

export function createGetMessageAvailableReactionsUseCase(
  gateway: TdGatewayPort): GetMessageAvailableReactionsUseCase {
  return new GetMessageAvailableReactionsUseCase(gateway);
}

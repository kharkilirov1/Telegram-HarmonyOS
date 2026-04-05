// SearchChatMessages use case — searches messages in a chat via TDLib
// Returns found message IDs for navigation in the timeline.
// iOS ref: 0.2s debounce, auto-navigate to first result, limit=100.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { ChatId, MessageId } from '../../core/model/EntityId';
import { createSearchChatMessagesCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { TdObject } from '../../models/TdTypes';
import { tdGetNumber, tdGetString } from '../../core/utils/tdAccessors';

const TAG = 'SearchChatMessages';
const DOMAIN = 0x0013;

export class SearchChatMessagesResult {
  messageIds: MessageId[] = [];
  totalCount: number = 0;
}

export class SearchChatMessagesUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async execute(chatId: ChatId, query: string, fromMessageId: MessageId = '0'): Promise<SearchChatMessagesResult> {
    if (!chatId || chatId === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400, false);
    }
    if (!query || query.trim().length === 0) {
      const empty = new SearchChatMessagesResult();
      return empty;
    }

    try {
      hilog.info(DOMAIN, TAG, 'Searching in chat %{public}d for "%{public}s"', chatId, query);
      const command = createSearchChatMessagesCommand(chatId, query, fromMessageId);
      const response = await this.gateway.send(command) as TdObject;

      const result = new SearchChatMessagesResult();
      result.totalCount = tdGetNumber(response, 'total_count');

      // Parse messages array from TDLib foundMessages/messages response
      const messagesJson = tdGetString(response, '_messages_raw');
      if (messagesJson.length > 0) {
        // Parsed by gateway — extract message IDs
        result.messageIds = this.extractMessageIds(response);
      }

      hilog.info(DOMAIN, TAG, 'Found %{public}d messages (total=%{public}d)',
        result.messageIds.length, result.totalCount);
      return result;
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Search failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Search failed', err.message, 0, true);
    }
  }

  private extractMessageIds(response: TdObject): MessageId[] {
    const ids: MessageId[] = [];
    try {
      const messages = response.getArray('messages');
      for (let i = 0; i < messages.length; i++) {
        const msg = messages[i] as TdObject;
        const id = tdGetString(msg, 'id');
        if (id.length > 0 && id !== '0') {
          ids.push(id);
        }
      }
    } catch (_e) {
      // Response format may vary — return what we have
    }
    return ids;
  }
}

export function createSearchChatMessagesUseCase(gateway: TdGatewayPort): SearchChatMessagesUseCase {
  return new SearchChatMessagesUseCase(gateway);
}

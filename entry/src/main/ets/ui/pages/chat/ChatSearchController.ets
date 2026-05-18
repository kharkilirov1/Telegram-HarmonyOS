// ChatSearchController — debounced in-chat message search orchestration.

import {
  SearchChatMessagesResult,
  SearchChatMessagesUseCase
} from '../../../domain/usecases/searchChatMessages';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0021;
const TAG = 'ChatSearchController';
const SEARCH_DEBOUNCE_MS = 200;

export interface ChatSearchControllerHost {
  getActiveChatId(): number;
  getLifecycleToken(): number;
  getSearchUseCase(): SearchChatMessagesUseCase | undefined;
  isSearchModeActive(): boolean;
  getSearchQuery(): string;
  setSearchQuery(value: string): void;
  setSearchModeActive(value: boolean): void;
  scrollToMessageId(messageId: string): boolean;
}

export class ChatSearchController {
  private debounceTimerId: number = -1;

  handleSearchQueryChange(query: string, host: ChatSearchControllerHost): void {
    host.setSearchQuery(query);
    this.clearPendingTimer();
    if (query.trim().length === 0) {
      return;
    }

    const lifecycleToken: number = host.getLifecycleToken();
    let scheduledTimerId: number = -1;
    scheduledTimerId = setTimeout(() => {
      if (lifecycleToken !== host.getLifecycleToken() || this.debounceTimerId !== scheduledTimerId) {
        return;
      }
      this.debounceTimerId = -1;
      this.executeSearch(query, host);
    }, SEARCH_DEBOUNCE_MS) as number;
    this.debounceTimerId = scheduledTimerId;
  }

  closeSearch(host: ChatSearchControllerHost): void {
    host.setSearchModeActive(false);
    host.setSearchQuery('');
    this.clearPendingTimer();
  }

  clearPendingTimer(): void {
    if (this.debounceTimerId !== -1) {
      clearTimeout(this.debounceTimerId);
      this.debounceTimerId = -1;
    }
  }

  private executeSearch(query: string, host: ChatSearchControllerHost): void {
    const useCase = host.getSearchUseCase();
    const chatId = host.getActiveChatId();
    if (!useCase || chatId === 0) {
      return;
    }

    const lifecycleToken: number = host.getLifecycleToken();
    useCase.execute(chatId, query)
      .then((result: SearchChatMessagesResult) => {
        if (!this.isSearchContextActive(host, lifecycleToken, useCase, chatId, query)) {
          return;
        }
        if (result.messageIds.length > 0) {
          const firstId = result.messageIds[0];
          host.scrollToMessageId(firstId);
          hilog.info(DOMAIN, TAG, 'Search: navigated to first of %{public}d results', result.totalCount);
        } else {
          hilog.info(DOMAIN, TAG, 'Search: no results for "%{public}s"', query);
        }
      })
      .catch((err: Error) => {
        if (!this.isSearchContextActive(host, lifecycleToken, useCase, chatId, query)) {
          return;
        }
        hilog.error(DOMAIN, TAG, 'Search failed: %{public}s', err.message);
      });
  }

  private isSearchContextActive(
    host: ChatSearchControllerHost,
    lifecycleToken: number,
    useCase: SearchChatMessagesUseCase,
    chatId: number,
    query: string
  ): boolean {
    return lifecycleToken === host.getLifecycleToken() &&
      host.getSearchUseCase() === useCase &&
      host.getActiveChatId() === chatId &&
      host.isSearchModeActive() &&
      host.getSearchQuery() === query;
  }
}

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
  // position is 1-based among loaded results; total from TDLib (may exceed
  // loadedCount — only one page is fetched); 0/0/0 = none
  onSearchResultsUpdated(position: number, total: number, loadedCount: number): void;
}

export class ChatSearchController {
  private debounceTimerId: number = -1;
  // Loaded page of results, newest first (TDLib order for from_message_id=0)
  private resultIds: string[] = [];
  private currentIndex: number = 0;
  private totalCount: number = 0;

  handleSearchQueryChange(query: string, host: ChatSearchControllerHost): void {
    host.setSearchQuery(query);
    this.clearPendingTimer();
    if (query.trim().length === 0) {
      this.resetResults(host);
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

  // Older result = further down the newest-first list
  goToOlderResult(host: ChatSearchControllerHost): void {
    if (this.currentIndex + 1 >= this.resultIds.length) {
      return;
    }
    this.currentIndex++;
    this.navigateToCurrent(host);
  }

  goToNewerResult(host: ChatSearchControllerHost): void {
    if (this.currentIndex <= 0) {
      return;
    }
    this.currentIndex--;
    this.navigateToCurrent(host);
  }

  closeSearch(host: ChatSearchControllerHost): void {
    host.setSearchModeActive(false);
    host.setSearchQuery('');
    this.clearPendingTimer();
    this.resetResults(host);
  }

  clearPendingTimer(): void {
    if (this.debounceTimerId !== -1) {
      clearTimeout(this.debounceTimerId);
      this.debounceTimerId = -1;
    }
  }

  private navigateToCurrent(host: ChatSearchControllerHost): void {
    host.scrollToMessageId(this.resultIds[this.currentIndex]);
    host.onSearchResultsUpdated(this.currentIndex + 1, this.totalCount, this.resultIds.length);
  }

  private resetResults(host: ChatSearchControllerHost): void {
    this.resultIds = [];
    this.currentIndex = 0;
    this.totalCount = 0;
    host.onSearchResultsUpdated(0, 0, 0);
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
        this.resultIds = result.messageIds;
        this.currentIndex = 0;
        this.totalCount = result.totalCount;
        if (result.messageIds.length > 0) {
          this.navigateToCurrent(host);
          hilog.info(DOMAIN, TAG, 'Search: navigated to first of %{public}d results', result.totalCount);
        } else {
          host.onSearchResultsUpdated(0, 0, 0);
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

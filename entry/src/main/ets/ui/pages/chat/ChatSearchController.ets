// ChatSearchController — debounced in-chat message search orchestration.

import {
  SearchChatMessagesResult,
  SearchChatMessagesUseCase
} from '../../../domain/usecases/searchChatMessages';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0021;
const TAG = 'ChatSearchController';
const SEARCH_DEBOUNCE_MS = 200;
const SEARCH_PREFETCH_REMAINING = 25;

export interface ChatSearchControllerHost {
  getActiveChatId(): number;
  getLifecycleToken(): number;
  getSearchUseCase(): SearchChatMessagesUseCase | undefined;
  isSearchModeActive(): boolean;
  getSearchQuery(): string;
  setSearchQuery(value: string): void;
  setSearchModeActive(value: boolean): void;
  scrollToMessageId(messageId: string): boolean;
  // Scrolls when loaded, otherwise loads a history window around the target
  jumpToMessageId(messageId: string): void;
  // position is 1-based among loaded results; total from TDLib (may exceed
  // loadedCount while more pages are available); 0/0/0 = none
  onSearchResultsUpdated(position: number, total: number, loadedCount: number): void;
  onSearchLoadingChanged(value: boolean): void;
  onSearchErrorChanged(value: boolean): void;
}

export class ChatSearchController {
  private debounceTimerId: number = -1;
  // Loaded page of results, newest first (TDLib order for from_message_id=0)
  private resultIds: string[] = [];
  private currentIndex: number = 0;
  private totalCount: number = 0;
  private nextFromMessageId: string = '0';
  private loadingMore: boolean = false;
  private requestId: number = 0;

  handleSearchQueryChange(query: string, host: ChatSearchControllerHost): void {
    this.requestId++;
    host.setSearchQuery(query);
    this.clearPendingTimer();
    host.onSearchErrorChanged(false);
    if (query.trim().length === 0) {
      host.onSearchLoadingChanged(false);
      this.resetResults(host);
      return;
    }

    // Do not present the previous query's count as the new query's result.
    this.resetResults(host);
    host.onSearchLoadingChanged(true);
    const lifecycleToken: number = host.getLifecycleToken();
    const requestId: number = this.requestId;
    let scheduledTimerId: number = -1;
    scheduledTimerId = setTimeout(() => {
      if (lifecycleToken !== host.getLifecycleToken() || this.debounceTimerId !== scheduledTimerId) {
        return;
      }
      this.debounceTimerId = -1;
      this.executeSearch(query, requestId, host);
    }, SEARCH_DEBOUNCE_MS) as number;
    this.debounceTimerId = scheduledTimerId;
  }

  // Older result = further down the newest-first list
  goToOlderResult(host: ChatSearchControllerHost): void {
    if (this.currentIndex + 1 >= this.resultIds.length) {
      this.loadMore(host, true);
      return;
    }
    this.currentIndex++;
    this.navigateToCurrent(host);
    this.prefetchIfNeeded(host);
  }

  goToNewerResult(host: ChatSearchControllerHost): void {
    if (this.currentIndex <= 0) {
      return;
    }
    this.currentIndex--;
    this.navigateToCurrent(host);
  }

  closeSearch(host: ChatSearchControllerHost): void {
    this.requestId++;
    host.setSearchModeActive(false);
    host.setSearchQuery('');
    this.clearPendingTimer();
    host.onSearchLoadingChanged(false);
    host.onSearchErrorChanged(false);
    this.resetResults(host);
  }

  clearPendingTimer(): void {
    if (this.debounceTimerId !== -1) {
      clearTimeout(this.debounceTimerId);
      this.debounceTimerId = -1;
    }
  }

  private navigateToCurrent(host: ChatSearchControllerHost): void {
    host.jumpToMessageId(this.resultIds[this.currentIndex]);
    host.onSearchResultsUpdated(this.currentIndex + 1, this.totalCount, this.resultIds.length);
  }

  private resetResults(host: ChatSearchControllerHost): void {
    this.resultIds = [];
    this.currentIndex = 0;
    this.totalCount = 0;
    this.nextFromMessageId = '0';
    this.loadingMore = false;
    host.onSearchResultsUpdated(0, 0, 0);
  }

  private executeSearch(query: string, requestId: number, host: ChatSearchControllerHost): void {
    const useCase = host.getSearchUseCase();
    const chatId = host.getActiveChatId();
    if (!useCase || chatId === 0) {
      host.onSearchLoadingChanged(false);
      host.onSearchErrorChanged(true);
      return;
    }

    const lifecycleToken: number = host.getLifecycleToken();
    useCase.execute(chatId, query)
      .then((result: SearchChatMessagesResult) => {
        if (!this.isSearchContextActive(host, lifecycleToken, requestId, useCase, chatId, query)) {
          return;
        }
        this.resultIds = result.messageIds;
        this.currentIndex = 0;
        this.totalCount = result.totalCount;
        this.nextFromMessageId = result.nextFromMessageId;
        host.onSearchLoadingChanged(false);
        host.onSearchErrorChanged(false);
        if (result.messageIds.length > 0) {
          this.navigateToCurrent(host);
          hilog.info(DOMAIN, TAG, 'Search: navigated to first of %{public}d results', result.totalCount);
        } else {
          host.onSearchResultsUpdated(0, 0, 0);
          hilog.info(DOMAIN, TAG, 'Search: no results for "%{public}s"', query);
        }
      })
      .catch((err: Error) => {
        if (!this.isSearchContextActive(host, lifecycleToken, requestId, useCase, chatId, query)) {
          return;
        }
        host.onSearchLoadingChanged(false);
        host.onSearchErrorChanged(true);
        hilog.error(DOMAIN, TAG, 'Search failed: %{public}s', err.message);
      });
  }

  private prefetchIfNeeded(host: ChatSearchControllerHost): void {
    const remaining = this.resultIds.length - 1 - this.currentIndex;
    if (remaining <= SEARCH_PREFETCH_REMAINING) {
      this.loadMore(host, false);
    }
  }

  private loadMore(host: ChatSearchControllerHost, navigateAfterLoad: boolean): void {
    if (this.loadingMore || this.nextFromMessageId === '0' ||
      this.resultIds.length >= this.totalCount) {
      return;
    }
    const useCase = host.getSearchUseCase();
    const chatId = host.getActiveChatId();
    const query = host.getSearchQuery();
    if (!useCase || chatId === 0 || query.trim().length === 0) {
      return;
    }

    const lifecycleToken: number = host.getLifecycleToken();
    const requestId: number = this.requestId;
    const cursor: string = this.nextFromMessageId;
    const previousCount: number = this.resultIds.length;
    this.loadingMore = true;
    host.onSearchLoadingChanged(true);
    useCase.execute(chatId, query, cursor)
      .then((result: SearchChatMessagesResult) => {
        if (!this.isSearchContextActive(host, lifecycleToken, requestId, useCase, chatId, query)) {
          return;
        }
        const knownIds = new Set<string>(this.resultIds);
        for (let i = 0; i < result.messageIds.length; i++) {
          const messageId = result.messageIds[i];
          if (!knownIds.has(messageId)) {
            knownIds.add(messageId);
            this.resultIds.push(messageId);
          }
        }
        const addedCount = this.resultIds.length - previousCount;
        this.totalCount = Math.max(this.totalCount, result.totalCount);
        this.nextFromMessageId = addedCount > 0 ? result.nextFromMessageId : '0';
        this.loadingMore = false;
        host.onSearchLoadingChanged(false);
        host.onSearchErrorChanged(false);
        if (navigateAfterLoad && addedCount > 0 && this.currentIndex + 1 < this.resultIds.length) {
          this.currentIndex++;
          this.navigateToCurrent(host);
        } else {
          host.onSearchResultsUpdated(this.currentIndex + 1, this.totalCount, this.resultIds.length);
        }
        hilog.info(DOMAIN, TAG, 'Search: loaded %{public}d more results (%{public}d/%{public}d)',
          addedCount, this.resultIds.length, this.totalCount);
      })
      .catch((err: Error) => {
        if (!this.isSearchContextActive(host, lifecycleToken, requestId, useCase, chatId, query)) {
          return;
        }
        this.loadingMore = false;
        host.onSearchLoadingChanged(false);
        // Keep the already loaded page usable; pagination can be retried by the
        // next older-result press without replacing the valid counter by an error.
        hilog.error(DOMAIN, TAG, 'Search pagination failed: %{public}s', err.message);
      });
  }

  private isSearchContextActive(
    host: ChatSearchControllerHost,
    lifecycleToken: number,
    requestId: number,
    useCase: SearchChatMessagesUseCase,
    chatId: number,
    query: string
  ): boolean {
    return lifecycleToken === host.getLifecycleToken() &&
      requestId === this.requestId &&
      host.getSearchUseCase() === useCase &&
      host.getActiveChatId() === chatId &&
      host.isSearchModeActive() &&
      host.getSearchQuery() === query;
  }
}

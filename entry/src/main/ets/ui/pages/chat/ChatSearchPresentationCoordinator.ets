// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { TG_CHAT_SEARCH_INPUT_ID } from '../../tg_ui/atoms/TgChatTopBar';
import { ChatTimelineDataSource } from './ChatTimelineDataSource';
import { ChatTimelineEntryVO } from './ChatTimelineVO';
import { ChatSearchController, ChatSearchControllerHost } from './ChatSearchController';
import { SearchChatMessagesUseCase } from '../../../domain/usecases/searchChatMessages';

export interface ChatSearchPresentationCoordinatorPort extends ChatSearchControllerHost {
  dataSource: ChatTimelineDataSource;
  isSearchMode: boolean;
  pageLifecycleToken: number;
  searchCtrl: ChatSearchController;
  searchError: boolean;
  searchFlashMessageId: string;
  searchFlashTimerId: number;
  searchLoading: boolean;
  searchQuery: string;
  searchResultLoaded: number;
  searchResultPos: number;
  searchResultTotal: number;
  searchUseCase?: SearchChatMessagesUseCase;
  clearSearchFlash(): void;
  scheduleLifecycleTask(delayMs: number, task: () => void): void;
  getUIContext(): UIContext;
}

export function getSearchUseCase(host: ChatSearchPresentationCoordinatorPort): SearchChatMessagesUseCase | undefined {
    return host.searchUseCase;
  }

export function isSearchModeActive(host: ChatSearchPresentationCoordinatorPort): boolean {
    return host.isSearchMode;
  }

export function getSearchQuery(host: ChatSearchPresentationCoordinatorPort): string {
    return host.searchQuery;
  }

export function setSearchQuery(host: ChatSearchPresentationCoordinatorPort, value: string): void {
    host.searchQuery = value;
  }

export function setSearchModeActive(host: ChatSearchPresentationCoordinatorPort, value: boolean): void {
    host.isSearchMode = value;
  }

export function onSearchResultsUpdated(host: ChatSearchPresentationCoordinatorPort, position: number, total: number, loadedCount: number): void {
    host.searchResultPos = position;
    host.searchResultTotal = total;
    host.searchResultLoaded = loadedCount;
  }

export function onSearchLoadingChanged(host: ChatSearchPresentationCoordinatorPort, value: boolean): void {
    host.searchLoading = value;
  }

export function onSearchErrorChanged(host: ChatSearchPresentationCoordinatorPort, value: boolean): void {
    host.searchError = value;
  }

export function flashSearchHit(host: ChatSearchPresentationCoordinatorPort, messageId: string, index: number): void {
    host.clearSearchFlash();
    const entry: ChatTimelineEntryVO = host.dataSource.getData(index);
    entry.searchFlash = true;
    entry.key = entry.key + '_hl';
    host.dataSource.notifyItemChangedByMessageId(messageId);
    host.searchFlashMessageId = messageId;
    const lifecycleToken: number = host.pageLifecycleToken;
    const timerId: number = setTimeout(() => {
      if (lifecycleToken !== host.pageLifecycleToken || host.searchFlashTimerId !== timerId) {
        return;
      }
      host.searchFlashTimerId = -1;
      host.clearSearchFlash();
    }, 1600) as number;
    host.searchFlashTimerId = timerId;
  }

export function clearSearchFlash(host: ChatSearchPresentationCoordinatorPort): void {
    if (host.searchFlashTimerId !== -1) {
      clearTimeout(host.searchFlashTimerId);
      host.searchFlashTimerId = -1;
    }
    const messageId = host.searchFlashMessageId;
    if (messageId.length === 0) {
      return;
    }
    host.searchFlashMessageId = '';
    const count = host.dataSource.totalCount();
    for (let i = 0; i < count; i++) {
      const entry: ChatTimelineEntryVO = host.dataSource.getData(i);
      if (entry.kind === 'message' && entry.message.messageId === messageId) {
        // A timeline diff may have rebuilt the entry without the flag already
        if (entry.searchFlash) {
          entry.searchFlash = false;
          if (entry.key.endsWith('_hl')) {
            entry.key = entry.key.substring(0, entry.key.length - 3);
          }
          host.dataSource.notifyItemChangedByMessageId(messageId);
        }
        return;
      }
    }
  }

export function handleSearchQueryChange(host: ChatSearchPresentationCoordinatorPort, query: string): void {
    host.searchCtrl.handleSearchQueryChange(query, host);
  }

export function openSearch(host: ChatSearchPresentationCoordinatorPort): void {
    host.isSearchMode = true;
    // The conditional TextInput exists on the next frame. FocusController is
    // the documented path that also opens the system IME for TextInput.
    host.scheduleLifecycleTask(16, () => {
      host.getUIContext().getFocusController().requestFocus(TG_CHAT_SEARCH_INPUT_ID);
    });
  }

export function closeSearch(host: ChatSearchPresentationCoordinatorPort): void {
    host.clearSearchFlash();
    host.searchCtrl.closeSearch(host);
  }

export function useSearchFlashOutline(host: ChatSearchPresentationCoordinatorPort, entry: ChatTimelineEntryVO): boolean {
    return entry.kind === 'message' && entry.message.contentType === 'sticker';
  }

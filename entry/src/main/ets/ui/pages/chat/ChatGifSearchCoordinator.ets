// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { fileUri } from '@kit.CoreFileKit';
import { StickerCellVO } from '../../tg_ui/atoms/TgComposerStickerPanel';
import { StickerPanelUseCase, GifPanelEntry, GifSearchPage } from '../../../domain/usecases/stickerPanel';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0021;
const TAG = 'TgChatScreenPage';
const GIF_SEARCH_DEBOUNCE_MS: number = 250;

export interface ChatGifSearchCoordinatorPort {
  activeChatId: number;
  activeStickerTabId: string;
  gifSearchDebounceTimerId: number;
  gifSearchHasMore: boolean;
  gifSearchItems: StickerCellVO[];
  gifSearchLoading: boolean;
  gifSearchNextOffset: string;
  gifSearchPageLoading: boolean;
  gifSearchQuery: string;
  gifSearchRequestId: number;
  pageLifecycleToken: number;
  showComposerStickerPanel: boolean;
  stickerPanelUseCase?: StickerPanelUseCase;
  fetchGifSearchFiles(cells: StickerCellVO[], requestId: number): Promise<void>;
  toGifCellVO(entry: GifPanelEntry): StickerCellVO;
}

export function resetGifSearchState(host: ChatGifSearchCoordinatorPort): void {
    if (host.gifSearchDebounceTimerId >= 0) {
      clearTimeout(host.gifSearchDebounceTimerId);
      host.gifSearchDebounceTimerId = -1;
    }
    host.gifSearchRequestId++;
    host.gifSearchQuery = '';
    host.gifSearchNextOffset = '';
    host.gifSearchItems = [];
    host.gifSearchLoading = false;
    host.gifSearchHasMore = false;
    host.gifSearchPageLoading = false;
  }

export function handleGifSearchQueryChange(host: ChatGifSearchCoordinatorPort, query: string): void {
    if (host.gifSearchDebounceTimerId >= 0) {
      clearTimeout(host.gifSearchDebounceTimerId);
      host.gifSearchDebounceTimerId = -1;
    }
    const normalized = query.trim();
    const requestId = ++host.gifSearchRequestId;
    host.gifSearchQuery = normalized;
    host.gifSearchNextOffset = '';
    host.gifSearchItems = [];
    host.gifSearchHasMore = false;
    host.gifSearchPageLoading = false;
    if (normalized.length === 0 || host.activeChatId === 0 || host.activeStickerTabId !== 'gifs') {
      host.gifSearchLoading = false;
      return;
    }
    host.gifSearchLoading = true;
    const lifecycleToken = host.pageLifecycleToken;
    host.gifSearchDebounceTimerId = setTimeout(() => {
      host.gifSearchDebounceTimerId = -1;
      const useCase = host.stickerPanelUseCase;
      if (!useCase || lifecycleToken !== host.pageLifecycleToken ||
        requestId !== host.gifSearchRequestId || normalized !== host.gifSearchQuery ||
        !host.showComposerStickerPanel || host.activeStickerTabId !== 'gifs') {
        return;
      }
      useCase.searchGifs(normalized, host.activeChatId)
        .then((page: GifSearchPage) => {
          if (lifecycleToken !== host.pageLifecycleToken || requestId !== host.gifSearchRequestId ||
            normalized !== host.gifSearchQuery || !host.showComposerStickerPanel ||
            host.activeStickerTabId !== 'gifs') {
            return;
          }
          const cells: StickerCellVO[] = [];
          for (const entry of page.items) {
            cells.push(host.toGifCellVO(entry));
          }
          host.gifSearchItems = cells;
          host.gifSearchNextOffset = page.nextOffset;
          host.gifSearchHasMore = page.nextOffset.length > 0;
          host.gifSearchLoading = false;
          host.fetchGifSearchFiles(cells, requestId);
        })
        .catch((error: Error) => {
          if (requestId === host.gifSearchRequestId) {
            host.gifSearchLoading = false;
          }
          hilog.warn(DOMAIN, TAG, 'GIF search failed: %{public}s', error.message);
        });
    }, GIF_SEARCH_DEBOUNCE_MS) as number;
  }

export function loadMoreGifSearch(host: ChatGifSearchCoordinatorPort): void {
    const useCase = host.stickerPanelUseCase;
    const query = host.gifSearchQuery;
    const offset = host.gifSearchNextOffset;
    if (!useCase || query.length === 0 || offset.length === 0 || host.gifSearchLoading ||
      host.gifSearchPageLoading || !host.showComposerStickerPanel || host.activeStickerTabId !== 'gifs' ||
      host.activeChatId === 0) {
      return;
    }
    const lifecycleToken = host.pageLifecycleToken;
    const requestId = host.gifSearchRequestId;
    host.gifSearchPageLoading = true;
    useCase.searchGifs(query, host.activeChatId, offset)
      .then((page: GifSearchPage) => {
        if (lifecycleToken !== host.pageLifecycleToken || requestId !== host.gifSearchRequestId ||
          query !== host.gifSearchQuery || offset !== host.gifSearchNextOffset ||
          !host.showComposerStickerPanel || host.activeStickerTabId !== 'gifs') {
          return;
        }
        const knownIds: Set<string> = new Set<string>();
        for (const existing of host.gifSearchItems) {
          knownIds.add(existing.stickerId);
        }
        const appended: StickerCellVO[] = [];
        for (const entry of page.items) {
          const cell = host.toGifCellVO(entry);
          if (!knownIds.has(cell.stickerId)) {
            knownIds.add(cell.stickerId);
            appended.push(cell);
          }
        }
        host.gifSearchItems = host.gifSearchItems.concat(appended);
        host.gifSearchNextOffset = page.nextOffset;
        host.gifSearchHasMore = page.nextOffset.length > 0 && page.nextOffset !== offset;
        host.fetchGifSearchFiles(appended, requestId);
      })
      .catch((error: Error) => {
        hilog.warn(DOMAIN, TAG, 'GIF search pagination failed: %{public}s', error.message);
      })
      .finally(() => {
        if (requestId === host.gifSearchRequestId) {
          host.gifSearchPageLoading = false;
        }
      });
  }

export async function fetchGifSearchFiles(host: ChatGifSearchCoordinatorPort, cells: StickerCellVO[], requestId: number): Promise<void> {
    const useCase = host.stickerPanelUseCase;
    if (!useCase) {
      return;
    }
    const lifecycleToken = host.pageLifecycleToken;
    for (const cell of cells) {
      if (lifecycleToken !== host.pageLifecycleToken || requestId !== host.gifSearchRequestId ||
        !host.showComposerStickerPanel || host.activeStickerTabId !== 'gifs' ||
        host.gifSearchQuery.length === 0) {
        return;
      }
      if (cell.thumbPathUri.length === 0 && cell.thumbFileId > 0) {
        const path = await useCase.downloadStickerFile(cell.thumbFileId);
        if (path.length > 0) {
          cell.thumbPathUri = fileUri.getUriFromPath(path);
        }
      }
    }
  }

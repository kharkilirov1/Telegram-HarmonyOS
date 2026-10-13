// Regular sticker search behavior. The page owns reactive presentation state.

import { fileUri } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { StickerPanelEntry, StickerPanelUseCase } from '../../../domain/usecases/stickerPanel';
import { StickerCellVO } from '../../tg_ui/atoms/TgComposerStickerPanel';

const DOMAIN = 0x0021;
const TAG = 'ChatStickerSearch';
const STICKER_SEARCH_DEBOUNCE_MS: number = 250;

export interface ChatStickerSearchHost {
  getLifecycleToken(): number;
  getStickerSearchUseCase(): StickerPanelUseCase | undefined;
  isStickerSearchPanelActive(): boolean;
  getStickerSearchLanguageCodes(): string[];
  toStickerSearchCell(entry: StickerPanelEntry): StickerCellVO;
  setStickerSearchItems(items: StickerCellVO[]): void;
  setStickerSearchLoading(value: boolean): void;
}

export class ChatStickerSearchController {
  private query: string = '';
  private requestId: number = 0;
  private debounceTimerId: number = -1;

  reset(host: ChatStickerSearchHost): void {
    this.cancelPendingTimer();
    this.requestId++;
    this.query = '';
    host.setStickerSearchItems([]);
    host.setStickerSearchLoading(false);
  }

  handleSearchQueryChange(query: string, host: ChatStickerSearchHost): void {
    this.cancelPendingTimer();
    const normalized = query.trim();
    const requestId = ++this.requestId;
    this.query = normalized;
    host.setStickerSearchItems([]);
    const useCase = host.getStickerSearchUseCase();
    if (normalized.length < 2 || !useCase || !host.isStickerSearchPanelActive()) {
      host.setStickerSearchLoading(false);
      return;
    }

    host.setStickerSearchLoading(true);
    const lifecycleToken = host.getLifecycleToken();
    let scheduledTimerId: number = -1;
    scheduledTimerId = setTimeout(() => {
      if (this.debounceTimerId !== scheduledTimerId) {
        return;
      }
      this.debounceTimerId = -1;
      if (!this.isCurrent(host, useCase, lifecycleToken, requestId, normalized)) {
        return;
      }
      useCase.searchRegularStickers(normalized, host.getStickerSearchLanguageCodes())
        .then((entries: StickerPanelEntry[]) => {
          if (!this.isCurrent(host, useCase, lifecycleToken, requestId, normalized)) {
            return;
          }
          const cells: StickerCellVO[] = [];
          for (const entry of entries) {
            cells.push(host.toStickerSearchCell(entry));
          }
          host.setStickerSearchItems(cells);
          if (!this.isCurrent(host, useCase, lifecycleToken, requestId, normalized)) {
            return;
          }
          host.setStickerSearchLoading(false);
          void this.fetchPreviewFiles(cells, host, useCase, lifecycleToken, requestId, normalized);
        })
        .catch((error: Error) => {
          if (!this.isCurrent(host, useCase, lifecycleToken, requestId, normalized)) {
            return;
          }
          host.setStickerSearchLoading(false);
          hilog.warn(DOMAIN, TAG, 'Sticker search failed: %{public}s', error.message);
        });
    }, STICKER_SEARCH_DEBOUNCE_MS) as number;
    this.debounceTimerId = scheduledTimerId;
  }

  private cancelPendingTimer(): void {
    if (this.debounceTimerId >= 0) {
      clearTimeout(this.debounceTimerId);
      this.debounceTimerId = -1;
    }
  }

  private isCurrent(host: ChatStickerSearchHost, useCase: StickerPanelUseCase,
    lifecycleToken: number, requestId: number, query: string): boolean {
    return requestId === this.requestId && query === this.query &&
      lifecycleToken === host.getLifecycleToken() && host.getStickerSearchUseCase() === useCase &&
      host.isStickerSearchPanelActive();
  }

  private async fetchPreviewFiles(cells: StickerCellVO[], host: ChatStickerSearchHost,
    useCase: StickerPanelUseCase, lifecycleToken: number, requestId: number,
    query: string): Promise<void> {
    try {
      for (const cell of cells) {
        if (!this.isCurrent(host, useCase, lifecycleToken, requestId, query)) {
          return;
        }
        if (cell.thumbPathUri.length === 0 && cell.thumbFileId > 0) {
          const path = await useCase.downloadStickerFile(cell.thumbFileId);
          if (!this.isCurrent(host, useCase, lifecycleToken, requestId, query)) {
            return;
          }
          if (path.length > 0) {
            cell.thumbPathUri = fileUri.getUriFromPath(path);
          }
        }
        if (cell.pathUri.length === 0 && !cell.isAnimated && !cell.isVideo && cell.fileId > 0) {
          const path = await useCase.downloadStickerFile(cell.fileId);
          if (!this.isCurrent(host, useCase, lifecycleToken, requestId, query)) {
            return;
          }
          if (path.length > 0) {
            cell.pathUri = fileUri.getUriFromPath(path);
          }
        }
      }
    } catch (error) {
      if (this.isCurrent(host, useCase, lifecycleToken, requestId, query)) {
        hilog.warn(DOMAIN, TAG, 'Sticker preview failed: %{public}s', String(error));
      }
    }
  }
}

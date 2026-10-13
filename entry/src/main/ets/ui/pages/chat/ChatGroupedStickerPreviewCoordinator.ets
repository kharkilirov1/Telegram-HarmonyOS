// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { AppState } from '../../../core/model/AppState';
import { fileUri } from '@kit.CoreFileKit';
import { StickerCellVO } from '../../tg_ui/atoms/TgComposerStickerPanel';
import { StickerPanelUseCase } from '../../../domain/usecases/stickerPanel';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0021;
const TAG = 'TgChatScreenPage';

export interface ChatGroupedStickerPreviewCoordinatorPort {
  favoriteStickerItems: StickerCellVO[];
  groupedStickerPreviewRequests: Set<number>;
  pageLifecycleToken: number;
  premiumStickerItems: StickerCellVO[];
  stickerPanelUseCase?: StickerPanelUseCase;
  applyGroupedStickerPreviewPath(cell: StickerCellVO, fileId: number, path: string): void;
  refreshGroupedStickerHomePreviews(state: AppState): void;
}

export function applyGroupedStickerPreviewPath(host: ChatGroupedStickerPreviewCoordinatorPort, cell: StickerCellVO, fileId: number, path: string): void {
    if (path.length === 0) {
      return;
    }
    const uri = fileUri.getUriFromPath(path);
    if (fileId === cell.thumbFileId) {
      cell.thumbPathUri = uri;
    } else if (!cell.isAnimated && !cell.isVideo) {
      cell.pathUri = uri;
    }
  }

export function refreshGroupedStickerHomePreviews(host: ChatGroupedStickerPreviewCoordinatorPort, state: AppState): void {
    const cells: StickerCellVO[] = host.premiumStickerItems.concat(host.favoriteStickerItems);
    for (const cell of cells) {
      const fileId = cell.thumbFileId > 0 ? cell.thumbFileId : cell.fileId;
      if (fileId <= 0 || cell.previewUri().length > 0) {
        continue;
      }
      const transfer = state.files.transfers.get(fileId);
      if (transfer && transfer.isDownloadingCompleted && transfer.localPath.length > 0) {
        host.applyGroupedStickerPreviewPath(cell, fileId, transfer.localPath);
      }
    }
  }

export function requestGroupedStickerHomePreviews(host: ChatGroupedStickerPreviewCoordinatorPort, cells: StickerCellVO[], visibleLimit: number): void {
    const useCase = host.stickerPanelUseCase;
    if (!useCase) {
      return;
    }
    if (cells.length > 0) {
      hilog.info(DOMAIN, TAG,
        'Grouped sticker previews cells=%{public}d firstFile=%{public}d firstThumb=%{public}d',
        Math.min(cells.length, visibleLimit), cells[0].fileId, cells[0].thumbFileId);
    }
    host.refreshGroupedStickerHomePreviews(getAppCoreRuntime().getStore().getState());
    const token = host.pageLifecycleToken;
    for (const cell of cells.slice(0, visibleLimit)) {
      const fileId = cell.thumbFileId > 0 ? cell.thumbFileId : cell.fileId;
      if (fileId <= 0 || cell.previewUri().length > 0 || host.groupedStickerPreviewRequests.has(fileId)) {
        continue;
      }
      host.groupedStickerPreviewRequests.add(fileId);
      useCase.requestStickerFileDownload(fileId, 16).then((path: string) => {
        if (token === host.pageLifecycleToken) {
          host.applyGroupedStickerPreviewPath(cell, fileId, path);
        }
      });
    }
  }

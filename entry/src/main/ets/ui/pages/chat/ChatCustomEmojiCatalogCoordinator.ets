// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { fileUri } from '@kit.CoreFileKit';
import { CustomEmojiCellVO, CustomEmojiPackTabVO } from '../../tg_ui/atoms/TgComposerEmojiPanel';
import { StickerPanelUseCase, StickerPanelEntry, StickerSetInfoEntry } from '../../../domain/usecases/stickerPanel';
import { localized } from '../../../core/utils/AppResource';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0021;
const TAG = 'TgChatScreenPage';

export interface ChatCustomEmojiCatalogCoordinatorPort {
  activeCustomEmojiPackId: string;
  customEmojiPackTabs: CustomEmojiPackTabVO[];
  customEmojiPanelItems: CustomEmojiCellVO[];
  customEmojiPanelLoadedOnce: boolean;
  customEmojiPanelLoading: boolean;
  customEmojiSetCache: Map<string, CustomEmojiCellVO[]>;
  pageLifecycleToken: number;
  stickerPanelUseCase?: StickerPanelUseCase;
  fetchCustomEmojiFiles(cells: CustomEmojiCellVO[], tabId: string): Promise<void>;
  fetchCustomEmojiTabThumbs(tabs: CustomEmojiPackTabVO[]): Promise<void>;
  toCustomEmojiCellVO(entry: StickerPanelEntry): CustomEmojiCellVO | undefined;
}

export function toCustomEmojiCellVO(host: ChatCustomEmojiCatalogCoordinatorPort, entry: StickerPanelEntry): CustomEmojiCellVO | undefined {
    if (entry.customEmojiId === '0' || entry.emoji.length === 0) {
      return undefined;
    }
    const cell = new CustomEmojiCellVO(entry.customEmojiId, entry.emoji, entry.fileId,
      entry.thumbFileId, entry.isAnimated, entry.isVideo);
    if (entry.localPath.length > 0) {
      cell.pathUri = fileUri.getUriFromPath(entry.localPath);
    }
    if (entry.thumbPath.length > 0) {
      cell.thumbPathUri = fileUri.getUriFromPath(entry.thumbPath);
    }
    return cell;
  }

export async function fetchCustomEmojiFiles(host: ChatCustomEmojiCatalogCoordinatorPort, cells: CustomEmojiCellVO[], tabId: string): Promise<void> {
    const useCase = host.stickerPanelUseCase;
    if (!useCase) {
      return;
    }
    const token = host.pageLifecycleToken;
    for (const cell of cells) {
      if (token !== host.pageLifecycleToken || host.activeCustomEmojiPackId !== tabId) {
        return;
      }
      if (cell.thumbPathUri.length === 0 && cell.thumbFileId > 0) {
        const path = await useCase.downloadStickerFile(cell.thumbFileId);
        if (path.length > 0) {
          cell.thumbPathUri = fileUri.getUriFromPath(path);
        }
      }
      if (cell.pathUri.length === 0 && !cell.isAnimated && !cell.isVideo && cell.fileId > 0) {
        const path = await useCase.downloadStickerFile(cell.fileId);
        if (path.length > 0) {
          cell.pathUri = fileUri.getUriFromPath(path);
        }
      }
    }
  }

export async function fetchCustomEmojiTabThumbs(host: ChatCustomEmojiCatalogCoordinatorPort, tabs: CustomEmojiPackTabVO[]): Promise<void> {
    const useCase = host.stickerPanelUseCase;
    if (!useCase) {
      return;
    }
    const token = host.pageLifecycleToken;
    for (const tab of tabs) {
      if (token !== host.pageLifecycleToken) {
        return;
      }
      if (tab.tabId !== 'unicode' && tab.thumbUri.length === 0 && tab.thumbFileId > 0) {
        const path = await useCase.downloadStickerFile(tab.thumbFileId);
        if (path.length > 0) {
          tab.thumbUri = fileUri.getUriFromPath(path);
        }
      }
    }
  }

export function loadCustomEmojiPanelIfNeeded(host: ChatCustomEmojiCatalogCoordinatorPort): void {
    const useCase = host.stickerPanelUseCase;
    if (!useCase || host.customEmojiPanelLoadedOnce || host.customEmojiPanelLoading) {
      return;
    }
    host.customEmojiPackTabs = [new CustomEmojiPackTabVO('unicode',
      localized($r('app.string.emoji_tab').id, 'Emoji'), 0, '')];
    host.customEmojiPanelLoading = true;
    const token = host.pageLifecycleToken;
    const trendingPromise: Promise<StickerSetInfoEntry[]> = useCase.loadTrendingCustomEmojiSets(0, 12)
      .catch((error: Error): StickerSetInfoEntry[] => {
        hilog.warn(DOMAIN, TAG, 'Trending custom emoji packs load failed: %{public}s', error.message);
        return [];
      });
    const requests: Promise<StickerSetInfoEntry[]>[] = [
      useCase.loadInstalledCustomEmojiSets(),
      trendingPromise
    ];
    Promise.all(requests).then((sources: StickerSetInfoEntry[][]) => {
      if (token !== host.pageLifecycleToken) {
        return;
      }
      const tabs: CustomEmojiPackTabVO[] = [new CustomEmojiPackTabVO('unicode',
        localized($r('app.string.emoji_tab').id, 'Emoji'), 0, '')];
      const addedSetIds: Set<string> = new Set<string>();
      for (const sets of sources) {
        for (const set of sets) {
          if (addedSetIds.has(set.setId)) {
            continue;
          }
          addedSetIds.add(set.setId);
          const tab = new CustomEmojiPackTabVO(set.setId, set.title, set.thumbFileId, set.coverEmoji);
          if (set.thumbPath.length > 0) {
            tab.thumbUri = fileUri.getUriFromPath(set.thumbPath);
          }
          tabs.push(tab);
        }
      }
      host.customEmojiPackTabs = tabs;
      host.customEmojiPanelLoading = false;
      host.customEmojiPanelLoadedOnce = true;
      host.fetchCustomEmojiTabThumbs(tabs);
    }).catch((error: Error) => {
      if (token === host.pageLifecycleToken) {
        host.customEmojiPanelLoading = false;
      }
      hilog.warn(DOMAIN, TAG, 'Custom emoji packs load failed: %{public}s', error.message);
    });
  }

export function handleCustomEmojiTabSelected(host: ChatCustomEmojiCatalogCoordinatorPort, tabId: string): void {
    if (host.activeCustomEmojiPackId === tabId) {
      return;
    }
    host.activeCustomEmojiPackId = tabId;
    if (tabId === 'unicode') {
      host.customEmojiPanelItems = [];
      host.customEmojiPanelLoading = false;
      return;
    }
    const cached = host.customEmojiSetCache.get(tabId);
    if (cached !== undefined) {
      host.customEmojiPanelItems = cached;
      host.fetchCustomEmojiFiles(cached, tabId);
      return;
    }
    const useCase = host.stickerPanelUseCase;
    if (!useCase) {
      return;
    }
    host.customEmojiPanelItems = [];
    host.customEmojiPanelLoading = true;
    const token = host.pageLifecycleToken;
    useCase.loadStickerSet(tabId).then((entries: StickerPanelEntry[]) => {
      if (token !== host.pageLifecycleToken) {
        return;
      }
      const cells: CustomEmojiCellVO[] = [];
      for (const entry of entries) {
        const cell = host.toCustomEmojiCellVO(entry);
        if (cell !== undefined) {
          cells.push(cell);
        }
      }
      host.customEmojiSetCache.set(tabId, cells);
      host.customEmojiPanelLoading = false;
      if (host.activeCustomEmojiPackId === tabId) {
        host.customEmojiPanelItems = cells;
        host.fetchCustomEmojiFiles(cells, tabId);
      }
    }).catch((error: Error) => {
      if (token === host.pageLifecycleToken) {
        host.customEmojiPanelLoading = false;
      }
      hilog.warn(DOMAIN, TAG, 'Custom emoji pack load failed: %{public}s', error.message);
    });
  }

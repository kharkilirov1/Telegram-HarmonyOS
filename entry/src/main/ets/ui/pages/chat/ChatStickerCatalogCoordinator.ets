// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { fileUri } from '@kit.CoreFileKit';
import { StickerCellVO, StickerSetTabVO } from '../../tg_ui/atoms/TgComposerStickerPanel';
import { StickerPanelUseCase, StickerPanelEntry, StickerSetInfoEntry, GifPanelEntry, SendStickerParams, SendAnimationParams } from '../../../domain/usecases/stickerPanel';
import { localized } from '../../../core/utils/AppResource';

export interface ChatStickerCatalogCoordinatorPort {
  activeChatId: number;
  activeStickerTabId: string;
  favoriteStickerHomeLoaded: boolean;
  favoriteStickerHomeLoading: boolean;
  favoriteStickerItems: StickerCellVO[];
  pageLifecycleToken: number;
  premiumStickerHomeLoaded: boolean;
  premiumStickerHomeLoading: boolean;
  premiumStickerItems: StickerCellVO[];
  stickerPanelItems: StickerCellVO[];
  stickerPanelLoadedOnce: boolean;
  stickerPanelLoading: boolean;
  stickerPanelUseCase?: StickerPanelUseCase;
  stickerSetCache: Map<string, StickerCellVO[]>;
  stickerSetTabs: StickerSetTabVO[];
  canSendNewMessages(sendKind?: string): boolean;
  fetchStickerPanelFiles(cells: StickerCellVO[], tabId: string): Promise<void>;
  fetchStickerTabThumbs(tabs: StickerSetTabVO[]): Promise<void>;
  loadFavoriteStickerTab(): void;
  loadGifPanel(): void;
  loadPremiumStickerHomeIfNeeded(): void;
  loadStickerSetTabs(includeFavorites: boolean): void;
  requestGroupedStickerHomePreviews(cells: StickerCellVO[], visibleLimit: number): void;
  setStickerPanelVisible(value: boolean): void;
  toGifCellVO(entry: GifPanelEntry): StickerCellVO;
  toStickerCellVO(entry: StickerPanelEntry): StickerCellVO;
}

export function toStickerCellVO(host: ChatStickerCatalogCoordinatorPort, entry: StickerPanelEntry): StickerCellVO {
    const cell = new StickerCellVO(entry.stickerId, entry.remoteFileId, entry.fileId,
      entry.thumbFileId, entry.emoji, entry.isAnimated, entry.isVideo, entry.width, entry.height);
    if (entry.localPath.length > 0) {
      cell.pathUri = fileUri.getUriFromPath(entry.localPath);
    }
    if (entry.thumbPath.length > 0) {
      cell.thumbPathUri = fileUri.getUriFromPath(entry.thumbPath);
    }
    return cell;
  }

export function toGifCellVO(host: ChatStickerCatalogCoordinatorPort, entry: GifPanelEntry): StickerCellVO {
    const cellId = entry.inlineResultId.length > 0
      ? 'gif_inline_' + entry.inlineQueryId + '_' + entry.inlineResultId
      : 'gif_' + entry.remoteFileId;
    const cell = new StickerCellVO(cellId, entry.remoteFileId, entry.fileId,
      entry.thumbFileId, '', false, true, entry.width, entry.height);
    cell.isGif = true;
    cell.duration = entry.duration;
    cell.inlineQueryId = entry.inlineQueryId;
    cell.inlineResultId = entry.inlineResultId;
    if (entry.minithumbnailData.length > 0) {
      cell.minithumbnailUri = 'data:image/jpeg;base64,' + entry.minithumbnailData;
    }
    if (entry.thumbPath.length > 0) {
      cell.thumbPathUri = fileUri.getUriFromPath(entry.thumbPath);
    }
    return cell;
  }

export async function fetchStickerPanelFiles(host: ChatStickerCatalogCoordinatorPort, cells: StickerCellVO[], tabId: string): Promise<void> {
    const useCase = host.stickerPanelUseCase;
    if (!useCase) {
      return;
    }
    const token = host.pageLifecycleToken;
    for (const cell of cells) {
      if (token !== host.pageLifecycleToken || host.activeStickerTabId !== tabId) {
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

export async function fetchStickerTabThumbs(host: ChatStickerCatalogCoordinatorPort, tabs: StickerSetTabVO[]): Promise<void> {
    const useCase = host.stickerPanelUseCase;
    if (!useCase) {
      return;
    }
    const token = host.pageLifecycleToken;
    for (const tab of tabs) {
      if (token !== host.pageLifecycleToken) {
        return;
      }
      if (tab.thumbUri.length === 0 && tab.thumbFileId > 0) {
        const path = await useCase.downloadStickerFile(tab.thumbFileId);
        if (path.length > 0) {
          tab.thumbUri = fileUri.getUriFromPath(path);
        }
      }
    }
  }

export function loadStickerPanelIfNeeded(host: ChatStickerCatalogCoordinatorPort): void {
    const useCase = host.stickerPanelUseCase;
    host.loadPremiumStickerHomeIfNeeded();
    host.loadFavoriteStickerTab();
    if (!useCase || host.stickerPanelLoadedOnce || host.stickerPanelLoading) {
      return;
    }
    host.stickerPanelLoading = true;
    const token = host.pageLifecycleToken;
    useCase.loadRecentStickers().then((entries: StickerPanelEntry[]) => {
      if (token !== host.pageLifecycleToken) {
        return;
      }
      const cells: StickerCellVO[] = [];
      for (const entry of entries) {
        cells.push(host.toStickerCellVO(entry));
      }
      host.stickerSetCache.set('recent', cells);
      if (host.activeStickerTabId === 'recent') {
        host.stickerPanelItems = cells;
      }
      host.stickerPanelLoading = false;
      host.stickerPanelLoadedOnce = true;
      host.fetchStickerPanelFiles(cells, 'recent');
    }).catch(() => {
      if (token === host.pageLifecycleToken) {
        host.stickerPanelLoading = false;
      }
    });
  }

export function loadFavoriteStickerTab(host: ChatStickerCatalogCoordinatorPort): void {
    const useCase = host.stickerPanelUseCase;
    if (!useCase || host.favoriteStickerHomeLoading) {
      return;
    }
    if (host.favoriteStickerHomeLoaded) {
      host.requestGroupedStickerHomePreviews(host.favoriteStickerItems, 4);
      return;
    }
    host.favoriteStickerHomeLoading = true;
    const token = host.pageLifecycleToken;
    useCase.loadFavoriteStickers().then((entries: StickerPanelEntry[]) => {
      if (token !== host.pageLifecycleToken) {
        return;
      }
      const cells: StickerCellVO[] = [];
      for (const entry of entries) {
        cells.push(host.toStickerCellVO(entry));
      }
      host.favoriteStickerItems = cells;
      host.favoriteStickerHomeLoaded = true;
      host.favoriteStickerHomeLoading = false;
      if (cells.length > 0) {
        host.stickerSetCache.set('favorites', cells);
        host.requestGroupedStickerHomePreviews(cells, 4);
      }
      host.loadStickerSetTabs(cells.length > 0);
    }).catch(() => {
      if (token === host.pageLifecycleToken) {
        host.favoriteStickerHomeLoading = false;
        host.loadStickerSetTabs(false);
      }
    });
  }

export function loadPremiumStickerHomeIfNeeded(host: ChatStickerCatalogCoordinatorPort): void {
    const useCase = host.stickerPanelUseCase;
    if (!useCase || host.premiumStickerHomeLoading) {
      return;
    }
    if (host.premiumStickerHomeLoaded) {
      host.requestGroupedStickerHomePreviews(host.premiumStickerItems, 8);
      return;
    }
    host.premiumStickerHomeLoading = true;
    const token = host.pageLifecycleToken;
    useCase.loadPremiumStickers(16).then((entries: StickerPanelEntry[]) => {
      if (token !== host.pageLifecycleToken) {
        return;
      }
      const cells: StickerCellVO[] = [];
      for (const entry of entries) {
        cells.push(host.toStickerCellVO(entry));
      }
      host.premiumStickerItems = cells;
      host.premiumStickerHomeLoaded = true;
      host.premiumStickerHomeLoading = false;
      host.requestGroupedStickerHomePreviews(cells, 8);
    }).catch(() => {
      if (token === host.pageLifecycleToken) {
        host.premiumStickerHomeLoading = false;
      }
    });
  }

export function loadStickerSetTabs(host: ChatStickerCatalogCoordinatorPort, includeFavorites: boolean): void {
    const useCase = host.stickerPanelUseCase;
    if (!useCase || host.stickerSetTabs.length > 0) {
      return;
    }
    const token = host.pageLifecycleToken;
    useCase.loadInstalledStickerSets().then((sets: StickerSetInfoEntry[]) => {
      if (token !== host.pageLifecycleToken) {
        return;
      }
      const tabs: StickerSetTabVO[] = [];
      if (includeFavorites) {
        tabs.push(new StickerSetTabVO('favorites',
          localized($r('app.string.sticker_packs_favorites').id, 'Favorites'), 0, ''));
      }
      tabs.push(new StickerSetTabVO('recent',
        localized($r('app.string.sticker_packs_recent').id, 'Recent'), 0, ''));
      for (const set of sets) {
        const tab = new StickerSetTabVO(set.setId, set.title, set.thumbFileId, set.coverEmoji);
        if (set.thumbPath.length > 0) {
          tab.thumbUri = fileUri.getUriFromPath(set.thumbPath);
        }
        tabs.push(tab);
      }
      host.stickerSetTabs = tabs;
      host.fetchStickerTabThumbs(tabs);
    });
  }

export function handleStickerTabSelected(host: ChatStickerCatalogCoordinatorPort, tabId: string): void {
    if (host.activeStickerTabId === tabId) {
      return;
    }
    host.activeStickerTabId = tabId;
    const cached = host.stickerSetCache.get(tabId);
    if (cached !== undefined) {
      host.stickerPanelItems = cached;
      host.fetchStickerPanelFiles(cached, tabId);
      return;
    }
    const useCase = host.stickerPanelUseCase;
    if (!useCase || tabId === 'recent') {
      return;
    }
    if (tabId === 'gifs') {
      host.loadGifPanel();
      return;
    }
    host.stickerPanelItems = [];
    host.stickerPanelLoading = true;
    const token = host.pageLifecycleToken;
    useCase.loadStickerSet(tabId).then((entries: StickerPanelEntry[]) => {
      if (token !== host.pageLifecycleToken) {
        return;
      }
      const cells: StickerCellVO[] = [];
      for (const entry of entries) {
        cells.push(host.toStickerCellVO(entry));
      }
      host.stickerSetCache.set(tabId, cells);
      host.stickerPanelLoading = false;
      if (host.activeStickerTabId === tabId) {
        host.stickerPanelItems = cells;
        host.fetchStickerPanelFiles(cells, tabId);
      }
    }).catch(() => {
      if (token === host.pageLifecycleToken) {
        host.stickerPanelLoading = false;
      }
    });
  }

export function loadGifPanel(host: ChatStickerCatalogCoordinatorPort): void {
    const useCase = host.stickerPanelUseCase;
    if (!useCase) {
      return;
    }
    const cached = host.stickerSetCache.get('gifs');
    if (cached !== undefined) {
      host.stickerPanelItems = cached;
      host.fetchStickerPanelFiles(cached, 'gifs');
      return;
    }
    host.stickerPanelItems = [];
    host.stickerPanelLoading = true;
    const token = host.pageLifecycleToken;
    useCase.loadSavedAnimations().then((entries: GifPanelEntry[]) => {
      if (token !== host.pageLifecycleToken) {
        return;
      }
      const cells: StickerCellVO[] = [];
      for (const entry of entries) {
        cells.push(host.toGifCellVO(entry));
      }
      host.stickerSetCache.set('gifs', cells);
      host.stickerPanelLoading = false;
      if (host.activeStickerTabId === 'gifs') {
        host.stickerPanelItems = cells;
        host.fetchStickerPanelFiles(cells, 'gifs');
      }
    }).catch(() => {
      if (token === host.pageLifecycleToken) {
        host.stickerPanelLoading = false;
      }
    });
  }

export function handleStickerSelected(host: ChatStickerCatalogCoordinatorPort, cell: StickerCellVO): void {
    if (!host.canSendNewMessages('other')) return;
    const useCase = host.stickerPanelUseCase;
    if (!useCase || host.activeChatId === 0) {
      return;
    }
    if (cell.isGif) {
      const gifParams = new SendAnimationParams();
      gifParams.chatId = host.activeChatId;
      gifParams.remoteFileId = cell.remoteFileId;
      gifParams.duration = cell.duration;
      gifParams.width = cell.width;
      gifParams.height = cell.height;
      gifParams.inlineQueryId = cell.inlineQueryId;
      gifParams.inlineResultId = cell.inlineResultId;
      useCase.sendAnimation(gifParams);
      host.setStickerPanelVisible(false);
      return;
    }
    const params = new SendStickerParams();
    params.chatId = host.activeChatId;
    params.remoteFileId = cell.remoteFileId;
    params.width = cell.width;
    params.height = cell.height;
    params.emoji = cell.emoji;
    useCase.sendSticker(params);
    host.setStickerPanelVisible(false);
  }

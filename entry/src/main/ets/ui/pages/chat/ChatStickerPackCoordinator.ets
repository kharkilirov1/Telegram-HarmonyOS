// F6: sticker pack card inside the media viewer. Loads the pack of the visible sticker and toggles its
// installed state; iOS shows the same title + Add/Remove Stickers action under the sticker.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { StickerPackUseCase, StickerPackSticker, isValidStickerSetId } from '../../../domain/usecases/stickerPack';

const DOMAIN = 0x004A;
const TAG = 'ChatStickerPack';

export interface ChatStickerPackItem {
  stickerSetId: string;
}

export interface ChatStickerPackHost {
  galleryCurrentIndex: number;
  galleryItems: ChatStickerPackItem[];
  stickerPackSetId: string;
  stickerPackStickers: StickerPackSticker[];
  stickerPackPagingIndex: number;
  stickerPackTitle: string;
  stickerPackInstalled: boolean;
  stickerPackBusy: boolean;
  stickerPackUseCase?: StickerPackUseCase;
  pageLifecycleToken: number;
  stickerPackRequestToken: number;
}

// The set id of the sticker currently shown, or '0' when the visible item is not a sticker.
export function visibleStickerSetId(host: ChatStickerPackHost): string {
  const index = host.galleryCurrentIndex;
  if (index < 0 || index >= host.galleryItems.length) {
    return '0';
  }
  const setId = host.galleryItems[index].stickerSetId;
  return isValidStickerSetId(setId) ? setId : '0';
}

// Called whenever the visible item changes: loads the pack once per set, clears the card otherwise.
function syncStickerPackCardInternal(host: ChatStickerPackHost): void {
  const setId = visibleStickerSetId(host);
  if (setId === '0') {
    host.stickerPackSetId = '0';
    host.stickerPackTitle = '';
    host.stickerPackInstalled = false;
    host.stickerPackBusy = false;
    host.stickerPackStickers = [];
    host.stickerPackPagingIndex = -1;
    return;
  }
  if (setId === host.stickerPackSetId) {
    return;
  }
  loadStickerPackInternal(host, setId);
}

function loadStickerPackInternal(host: ChatStickerPackHost, setId: string): void {
  const useCase = host.stickerPackUseCase;
  if (useCase === undefined || !isValidStickerSetId(setId)) {
    return;
  }
  const lifecycleToken = host.pageLifecycleToken;
  host.stickerPackRequestToken += 1;
  const requestToken = host.stickerPackRequestToken;
  host.stickerPackSetId = setId;
  host.stickerPackTitle = '';
  host.stickerPackInstalled = false;
  host.stickerPackBusy = true;
  useCase.load(setId)
    .then((info) => {
      if (lifecycleToken !== host.pageLifecycleToken || requestToken !== host.stickerPackRequestToken ||
        host.stickerPackSetId !== setId) {
        return;
      }
      host.stickerPackTitle = info.title;
      host.stickerPackInstalled = info.isInstalled;
      host.stickerPackStickers = info.stickers;
      host.stickerPackBusy = false;
    })
    .catch((error: Error) => {
      if (lifecycleToken !== host.pageLifecycleToken || requestToken !== host.stickerPackRequestToken) {
        return;
      }
      host.stickerPackBusy = false;
      host.stickerPackTitle = '';
      hilog.warn(DOMAIN, TAG, 'Sticker pack load failed: %{public}s', error.message);
    });
}

function toggleStickerPackInstalledInternal(host: ChatStickerPackHost): void {
  const useCase = host.stickerPackUseCase;
  const setId = host.stickerPackSetId;
  if (useCase === undefined || host.stickerPackBusy || !isValidStickerSetId(setId)) {
    return;
  }
  const lifecycleToken = host.pageLifecycleToken;
  const nextInstalled = !host.stickerPackInstalled;
  host.stickerPackBusy = true;
  useCase.setInstalled(setId, nextInstalled)
    .then(() => {
      if (lifecycleToken !== host.pageLifecycleToken || host.stickerPackSetId !== setId) {
        return;
      }
      host.stickerPackInstalled = nextInstalled;
      host.stickerPackBusy = false;
    })
    .catch((error: Error) => {
      if (lifecycleToken !== host.pageLifecycleToken || host.stickerPackSetId !== setId) {
        return;
      }
      host.stickerPackBusy = false;
      hilog.warn(DOMAIN, TAG, 'Sticker pack update failed: %{public}s', error.message);
    });
}

// Session entry points: one delegate per Session method, names must match the Session method exactly.
export function syncStickerPackCard(host: ChatStickerPackHost): void {
  syncStickerPackCardInternal(host);
}

export function loadStickerPack(host: ChatStickerPackHost): void {
  const setId = visibleStickerSetId(host);
  if (setId === '0') {
    host.stickerPackSetId = '0';
    host.stickerPackTitle = '';
    host.stickerPackInstalled = false;
    host.stickerPackBusy = false;
    return;
  }
  if (setId === host.stickerPackSetId && host.stickerPackTitle.length > 0) {
    return;
  }
  loadStickerPackInternal(host, setId);
}

export function toggleStickerPackInstalled(host: ChatStickerPackHost): void {
  toggleStickerPackInstalledInternal(host);
}

export function handleStickerPackLoad(host: ChatStickerPackHost): void {
  loadStickerPack(host);
}

export function handleStickerPackToggle(host: ChatStickerPackHost): void {
  toggleStickerPackInstalled(host);
}

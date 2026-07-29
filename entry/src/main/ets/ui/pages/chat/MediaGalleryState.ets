import { MediaGalleryItem } from '../../../models/MediaGalleryItem';

export class MediaGalleryRefreshResult {
  items: MediaGalleryItem[] = [];
  currentIndex: number = 0;
  sourceMessageId: string = '0';
  shouldClose: boolean = false;
}

function clampGalleryIndex(index: number, length: number): number {
  if (length <= 0) {
    return 0;
  }
  return Math.max(0, Math.min(length - 1, index));
}

function isSameGalleryItem(previous: MediaGalleryItem, next: MediaGalleryItem): boolean {
  return previous.messageId === next.messageId &&
    previous.fileId === next.fileId &&
    previous.type === next.type;
}

// Builders keep sourceMessageId populated, but an empty value must not leak an
// empty geometryTransition id — the member message id is the safe identity.
function galleryTransitionSourceId(item: MediaGalleryItem): string {
  return item.sourceMessageId.length > 0 ? item.sourceMessageId : item.messageId;
}

// When the member composition is unchanged, copy the volatile file-state fields
// into the EXISTING item objects instead of replacing the array: ForEach keys
// stay stable, reused nodes keep object identity, and the @Trace fields carry
// the delta into the open gallery. Returns false when composition changed and
// the caller must fall back to the full resolveRefreshedMediaGalleryState path.
export function mergeGalleryItemsInPlace(previousItems: MediaGalleryItem[],
  nextItems: MediaGalleryItem[]): boolean {
  if (previousItems.length === 0 || previousItems.length !== nextItems.length) {
    return false;
  }
  for (let i = 0; i < previousItems.length; i++) {
    if (!isSameGalleryItem(previousItems[i], nextItems[i])) {
      return false;
    }
  }
  for (let i = 0; i < previousItems.length; i++) {
    const prev = previousItems[i];
    const next = nextItems[i];
    if (prev.path !== next.path) {
      prev.path = next.path;
    }
    if (prev.thumbnailPath !== next.thumbnailPath) {
      prev.thumbnailPath = next.thumbnailPath;
    }
    if (prev.minithumb !== next.minithumb) {
      prev.minithumb = next.minithumb;
    }
    if (prev.isDownloading !== next.isDownloading) {
      prev.isDownloading = next.isDownloading;
    }
    if (prev.isDownloadFailed !== next.isDownloadFailed) {
      prev.isDownloadFailed = next.isDownloadFailed;
    }
    if (prev.downloadProgress !== next.downloadProgress) {
      prev.downloadProgress = next.downloadProgress;
    }
  }
  return true;
}

export function resolveRefreshedMediaGalleryState(previousItems: MediaGalleryItem[], previousIndex: number,
  nextItems: MediaGalleryItem[]): MediaGalleryRefreshResult {
  const result = new MediaGalleryRefreshResult();
  result.items = nextItems;
  if (nextItems.length === 0) {
    result.shouldClose = true;
    result.currentIndex = 0;
    return result;
  }

  const safePreviousIndex = clampGalleryIndex(previousIndex, previousItems.length);
  if (previousItems.length > 0) {
    const previousItem = previousItems[safePreviousIndex];
    for (let i = 0; i < nextItems.length; i++) {
      if (isSameGalleryItem(previousItem, nextItems[i])) {
        result.currentIndex = i;
        result.sourceMessageId = galleryTransitionSourceId(nextItems[i]);
        return result;
      }
    }
  }

  result.currentIndex = clampGalleryIndex(previousIndex, nextItems.length);
  result.sourceMessageId = galleryTransitionSourceId(nextItems[result.currentIndex]);
  return result;
}

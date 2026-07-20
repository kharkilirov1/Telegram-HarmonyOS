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
        result.sourceMessageId = nextItems[i].sourceMessageId;
        return result;
      }
    }
  }

  result.currentIndex = clampGalleryIndex(previousIndex, nextItems.length);
  result.sourceMessageId = nextItems[result.currentIndex].sourceMessageId;
  return result;
}

// F6: pack paging inside the media viewer. Builds gallery items from a loaded pack so the viewer can swipe
// through the pack of the sticker it opened, starting on the sticker the user tapped.

import { MediaGalleryItem } from '../../../models/MediaGalleryItem';
import { nextStickerPackIndex, StickerPackInfo, StickerPackSticker } from '../../../domain/usecases/stickerPack';

// Grouped-sticker collapse can hide the tapped item, so the start index prefers an exact sticker id and
// falls back to the first item rather than guessing.
export function stickerPackStartIndex(stickers: StickerPackSticker[], stickerId: string): number {
  if (stickers.length === 0) {
    return 0;
  }
  for (let index = 0; index < stickers.length; index += 1) {
    if (stickers[index].stickerId === stickerId) {
      return index;
    }
  }
  return 0;
}

export function buildStickerPackGalleryItems(pack: StickerPackInfo): MediaGalleryItem[] {
  const items: MediaGalleryItem[] = [];
  for (const sticker of pack.stickers) {
    const item = new MediaGalleryItem();
    item.type = 'sticker';
    item.path = sticker.localPath;
    item.thumbnailPath = sticker.thumbPath;
    item.width = sticker.width;
    item.height = sticker.height;
    item.fileId = sticker.fileId;
    item.stickerSetId = pack.setId;
    item.messageId = '';
    item.sourceMessageId = '';
    items.push(item);
  }
  return items;
}

// F6: files worth downloading around the current sticker. iOS preloads neighbours so a swipe shows the
// sticker instead of a spinner; only files that are not on disk and have a download handle are returned.
export class StickerPackPreloadPlan {
  nextFileId: number = 0;
  previousFileId: number = 0;
}

export function stickerPackPreloadPlan(stickers: StickerPackSticker[], index: number): StickerPackPreloadPlan {
  const plan = new StickerPackPreloadPlan();
  if (index < 0 || index >= stickers.length) {
    return plan;
  }
  const nextIndex = nextStickerPackIndex(index, stickers.length, 1);
  if (nextIndex !== index && stickers[nextIndex].localPath.length === 0 && stickers[nextIndex].fileId > 0) {
    plan.nextFileId = stickers[nextIndex].fileId;
  }
  const previousIndex = nextStickerPackIndex(index, stickers.length, -1);
  if (previousIndex !== index && stickers[previousIndex].localPath.length === 0 &&
    stickers[previousIndex].fileId > 0) {
    plan.previousFileId = stickers[previousIndex].fileId;
  }
  return plan;
}

export function stickerPackPreloadFileIds(stickers: StickerPackSticker[], index: number): number[] {
  const plan = stickerPackPreloadPlan(stickers, index);
  const ids: number[] = [];
  if (plan.nextFileId > 0) {
    ids.push(plan.nextFileId);
  }
  if (plan.previousFileId > 0 && !ids.includes(plan.previousFileId)) {
    ids.push(plan.previousFileId);
  }
  return ids;
}

// Delta moves within the pack; the caller keeps the current index in the gallery view state.
export function stepStickerPackIndex(currentIndex: number, pack: StickerPackInfo, delta: number): number {
  return nextStickerPackIndex(currentIndex, pack.stickers.length, delta);
}

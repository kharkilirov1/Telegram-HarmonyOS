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

// Delta moves within the pack; the caller keeps the current index in the gallery view state.
export function stepStickerPackIndex(currentIndex: number, pack: StickerPackInfo, delta: number): number {
  return nextStickerPackIndex(currentIndex, pack.stickers.length, delta);
}

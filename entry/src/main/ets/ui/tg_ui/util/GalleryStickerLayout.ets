// F6: layout of an animated sticker inside the media viewer. The sticker keeps its aspect ratio and fits
// the viewport, exactly like the contained photo path does for static images.

export const GALLERY_STICKER_MAX_FRACTION = 0.86;

export class GalleryStickerSize {
  width: number = 0;
  height: number = 0;
}

export function isTgsPath(path: string): boolean {
  const lower = path.trim().toLowerCase();
  return lower.endsWith('.tgs');
}

export function galleryStickerSize(itemWidth: number, itemHeight: number,
  viewportWidth: number, viewportHeight: number): GalleryStickerSize {
  const size = new GalleryStickerSize();
  if (!Number.isFinite(viewportWidth) || !Number.isFinite(viewportHeight) ||
    viewportWidth <= 0 || viewportHeight <= 0) {
    return size;
  }
  const width = Number.isFinite(itemWidth) && itemWidth > 0 ? itemWidth : 1;
  const height = Number.isFinite(itemHeight) && itemHeight > 0 ? itemHeight : 1;
  const maxWidth = Math.floor(viewportWidth * GALLERY_STICKER_MAX_FRACTION);
  const maxHeight = Math.floor(viewportHeight * GALLERY_STICKER_MAX_FRACTION);
  const ratio = width / height;
  if (ratio >= 1) {
    size.width = maxWidth;
    size.height = Math.max(1, Math.floor(maxWidth / ratio));
  } else {
    size.height = maxHeight;
    size.width = Math.max(1, Math.floor(maxHeight * ratio));
  }
  return size;
}

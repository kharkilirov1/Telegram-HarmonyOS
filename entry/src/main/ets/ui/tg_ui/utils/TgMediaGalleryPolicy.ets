export type TgVisualMediaTapMode = 'open' | 'downloadAndOpen';
export type TgPhotoAlbumTapMode = 'open' | 'downloadAndOpen' | 'none';
export type TgGalleryPreviewKind = 'thumbnail' | 'minithumb' | 'none';

export class TgGalleryPhotoOffset {
  offsetX: number;
  offsetY: number;

  constructor(offsetX: number, offsetY: number) {
    this.offsetX = offsetX;
    this.offsetY = offsetY;
  }
}

export class TgGalleryPhotoTransform extends TgGalleryPhotoOffset {
  scale: number;

  constructor(scale: number, offsetX: number, offsetY: number) {
    super(offsetX, offsetY);
    this.scale = scale;
  }
}

export function resolveVisualMediaTapMode(hasLocalMedia: boolean, isDownloading: boolean): TgVisualMediaTapMode {
  if (!hasLocalMedia && !isDownloading) {
    return 'downloadAndOpen';
  }
  return 'open';
}

export function resolvePhotoAlbumTapMode(hasLocalMedia: boolean, isDownloading: boolean,
  fileId: number): TgPhotoAlbumTapMode {
  if (!hasLocalMedia && !isDownloading && fileId > 0) {
    return 'downloadAndOpen';
  }
  return 'open';
}

export function resolveGalleryTransferActive(isDownloading: boolean, downloadProgress: number,
  isOptimisticallyPending: boolean, isDownloadFailed: boolean): boolean {
  if (isDownloadFailed) {
    return false;
  }
  return isDownloading || (downloadProgress >= 0 && downloadProgress < 1) || isOptimisticallyPending;
}

export function resolveGalleryPreviewKind(thumbnailPath: string, minithumb: string): TgGalleryPreviewKind {
  if (thumbnailPath.trim().length > 0) {
    return 'thumbnail';
  }
  if (minithumb.trim().length > 0) {
    return 'minithumb';
  }
  return 'none';
}

export function clampGalleryPhotoScale(scale: number, minScale: number = 1, maxScale: number = 4): number {
  const lower = Math.max(0.01, Math.min(minScale, maxScale));
  const upper = Math.max(lower, maxScale);
  return Math.max(lower, Math.min(upper, scale));
}

function positiveDimension(value: number, fallback: number): number {
  return Number.isFinite(value) && value > 0 ? value : Math.max(1, fallback);
}

export function resolveGalleryPhotoOffset(
  requestedOffsetX: number,
  requestedOffsetY: number,
  scale: number,
  viewportWidth: number,
  viewportHeight: number,
  mediaWidth: number,
  mediaHeight: number
): TgGalleryPhotoOffset {
  const safeViewportWidth = positiveDimension(viewportWidth, 1);
  const safeViewportHeight = positiveDimension(viewportHeight, 1);
  const safeMediaWidth = positiveDimension(mediaWidth, safeViewportWidth);
  const safeMediaHeight = positiveDimension(mediaHeight, safeViewportHeight);
  const containedScale = Math.min(safeViewportWidth / safeMediaWidth, safeViewportHeight / safeMediaHeight);
  const containedWidth = safeMediaWidth * containedScale;
  const containedHeight = safeMediaHeight * containedScale;
  const safeScale = Math.max(1, scale);
  const maxOffsetX = Math.max(0, (containedWidth * safeScale - safeViewportWidth) / 2);
  const maxOffsetY = Math.max(0, (containedHeight * safeScale - safeViewportHeight) / 2);
  return new TgGalleryPhotoOffset(
    Math.max(-maxOffsetX, Math.min(maxOffsetX, requestedOffsetX)),
    Math.max(-maxOffsetY, Math.min(maxOffsetY, requestedOffsetY))
  );
}

export function resolveGalleryDoubleTapTransform(
  currentScale: number,
  tapX: number,
  tapY: number,
  viewportWidth: number,
  viewportHeight: number,
  mediaWidth: number,
  mediaHeight: number,
  targetScale: number,
  minScale: number = 1,
  maxScale: number = 4
): TgGalleryPhotoTransform {
  const safeMinScale = clampGalleryPhotoScale(minScale, minScale, maxScale);
  if (currentScale > safeMinScale + 0.01) {
    return new TgGalleryPhotoTransform(safeMinScale, 0, 0);
  }
  const nextScale = clampGalleryPhotoScale(targetScale, safeMinScale, maxScale);
  const requestedOffsetX = (viewportWidth / 2 - tapX) * (nextScale - safeMinScale);
  const requestedOffsetY = (viewportHeight / 2 - tapY) * (nextScale - safeMinScale);
  const offset = resolveGalleryPhotoOffset(
    requestedOffsetX,
    requestedOffsetY,
    nextScale,
    viewportWidth,
    viewportHeight,
    mediaWidth,
    mediaHeight
  );
  return new TgGalleryPhotoTransform(nextScale, offset.offsetX, offset.offsetY);
}

export function resolveGalleryPinchTransform(
  startScale: number,
  startOffsetX: number,
  startOffsetY: number,
  targetScale: number,
  startCenterX: number,
  startCenterY: number,
  currentCenterX: number,
  currentCenterY: number,
  viewportWidth: number,
  viewportHeight: number,
  mediaWidth: number,
  mediaHeight: number,
  minScale: number = 1,
  maxScale: number = 4
): TgGalleryPhotoTransform {
  const safeStartScale = clampGalleryPhotoScale(startScale, minScale, maxScale);
  const safeTargetScale = clampGalleryPhotoScale(targetScale, minScale, maxScale);
  const viewportCenterX = viewportWidth / 2;
  const viewportCenterY = viewportHeight / 2;
  const contentAnchorX = (startCenterX - viewportCenterX - startOffsetX) / safeStartScale;
  const contentAnchorY = (startCenterY - viewportCenterY - startOffsetY) / safeStartScale;
  const requestedOffsetX = currentCenterX - viewportCenterX - contentAnchorX * safeTargetScale;
  const requestedOffsetY = currentCenterY - viewportCenterY - contentAnchorY * safeTargetScale;
  const offset = resolveGalleryPhotoOffset(
    requestedOffsetX,
    requestedOffsetY,
    safeTargetScale,
    viewportWidth,
    viewportHeight,
    mediaWidth,
    mediaHeight
  );
  return new TgGalleryPhotoTransform(safeTargetScale, offset.offsetX, offset.offsetY);
}

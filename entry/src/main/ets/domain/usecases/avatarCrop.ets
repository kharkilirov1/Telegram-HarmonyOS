// A5: square avatar crop math. iOS crops the picked photo to a centered square before upload; the same
// square is computed here so the UI and the image pipeline agree without platform calls.

export const AVATAR_CROP_OUTPUT_SIZE = 512;

export class AvatarCropRect {
  x: number = 0;
  y: number = 0;
  size: number = 0;
}

// Largest centered square inside the source image, in source pixels.
export function computeAvatarCropRect(width: number, height: number): AvatarCropRect {
  const rect = new AvatarCropRect();
  if (!Number.isFinite(width) || !Number.isFinite(height) ||
    width <= 0 || height <= 0) {
    return rect;
  }
  const size = Math.floor(Math.min(width, height));
  if (size <= 0) {
    return rect;
  }
  rect.size = size;
  rect.x = Math.floor((width - size) / 2);
  rect.y = Math.floor((height - size) / 2);
  return rect;
}

// Uniform scale that turns the cropped square into the upload size, never upscaling a tiny source.
export function avatarCropScale(size: number): number {
  if (!Number.isFinite(size) || size <= 0) {
    return 1;
  }
  const scale = AVATAR_CROP_OUTPUT_SIZE / size;
  return scale > 0 ? scale : 1;
}

export function isValidAvatarCropRect(rect: AvatarCropRect, width: number, height: number): boolean {
  if (rect.size <= 0 || rect.x < 0 || rect.y < 0) {
    return false;
  }
  return rect.x + rect.size <= width && rect.y + rect.size <= height;
}

// A5: interactive editor. The preview is a square viewport that shows the photo "cover"-fitted; the user
// pinches to zoom and pans. This maps that gesture state back into source pixels so the upload crop
// matches exactly what the user framed.
export const AVATAR_EDITOR_MIN_ZOOM = 1;
export const AVATAR_EDITOR_MAX_ZOOM = 4;

export function clampAvatarZoom(zoom: number): number {
  if (!Number.isFinite(zoom)) {
    return AVATAR_EDITOR_MIN_ZOOM;
  }
  if (zoom < AVATAR_EDITOR_MIN_ZOOM) {
    return AVATAR_EDITOR_MIN_ZOOM;
  }
  if (zoom > AVATAR_EDITOR_MAX_ZOOM) {
    return AVATAR_EDITOR_MAX_ZOOM;
  }
  return zoom;
}

// offsetX/offsetY are preview pixels (positive = the image moved right/down).
export function computeAvatarCropRectFromTransform(width: number, height: number, viewportSide: number,
  zoom: number, offsetX: number, offsetY: number): AvatarCropRect {
  const rect = new AvatarCropRect();
  if (!Number.isFinite(width) || !Number.isFinite(height) || !Number.isFinite(viewportSide) ||
    width <= 0 || height <= 0 || viewportSide <= 0) {
    return rect;
  }
  const clampedZoom = clampAvatarZoom(zoom);
  const shortSide = Math.min(width, height);
  // Source pixels per preview pixel: the cover fit at zoom 1 shows exactly the short side.
  const sourcePerPreview = shortSide / (viewportSide * clampedZoom);
  const size = Math.max(1, Math.floor(shortSide / clampedZoom));
  const centerX = width / 2 - (Number.isFinite(offsetX) ? offsetX : 0) * sourcePerPreview;
  const centerY = height / 2 - (Number.isFinite(offsetY) ? offsetY : 0) * sourcePerPreview;
  rect.size = Math.min(size, Math.floor(shortSide));
  let x = Math.round(centerX - rect.size / 2);
  let y = Math.round(centerY - rect.size / 2);
  x = Math.max(0, Math.min(x, width - rect.size));
  y = Math.max(0, Math.min(y, height - rect.size));
  rect.x = x;
  rect.y = y;
  return rect;
}

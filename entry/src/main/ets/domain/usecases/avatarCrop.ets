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

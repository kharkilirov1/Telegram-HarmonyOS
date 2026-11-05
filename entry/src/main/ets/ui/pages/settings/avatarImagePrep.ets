// A5: turn a picked media URI into a square upload-ready JPEG in the sandbox cache.
// image kit: decode → centered crop → scale to the avatar size → pack as JPEG, then hand the path to
// setProfilePhoto (inputFileLocal).

import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  AVATAR_CROP_OUTPUT_SIZE,
  AvatarCropRect,
  avatarCropScale,
  computeAvatarCropRect,
  isValidAvatarCropRect
} from '../../../domain/usecases/avatarCrop';

export class AvatarSourceSize {
  width: number = 0;
  height: number = 0;
}

const DOMAIN = 0x00A6;
const TAG = 'AvatarImagePrep';

const JPEG_QUALITY = 92;

function toRegion(rect: AvatarCropRect): image.Region {
  const region: image.Region = { x: rect.x, y: rect.y, size: { width: rect.size, height: rect.size } };
  return region;
}

export class AvatarImagePreparation {
  // Returns the cached JPEG path, or '' when the source cannot be decoded.
  // A5: the editor needs the source aspect before any crop is chosen, so measure first and decode later.
  static async measure(sourceUri: string): Promise<AvatarSourceSize> {
    const size = new AvatarSourceSize();
    let source: image.ImageSource | undefined;
    try {
      source = image.createImageSource(sourceUri);
      const info = await source.getImageInfo();
      if (info !== undefined && Number.isFinite(info.size.width) && Number.isFinite(info.size.height)) {
        size.width = info.size.width;
        size.height = info.size.height;
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Measuring the picked photo failed: %{public}s', String(error));
    } finally {
      if (source !== undefined) {
        try {
          await source.release();
        } catch (_error) {
        }
      }
    }
    return size;
  }

  static async prepare(context: common.UIAbilityContext, sourceUri: string,
    requestedRect?: AvatarCropRect): Promise<string> {
    let source: image.ImageSource | undefined;
    let pixelMap: image.PixelMap | undefined;
    try {
      source = image.createImageSource(sourceUri);
      const info = await source.getImageInfo();
      // A5: the editor passes the user's frame; without one the center square is used.
    const cropRect = requestedRect !== undefined
      ? requestedRect
      : computeAvatarCropRect(info.size.width, info.size.height);
      if (!isValidAvatarCropRect(cropRect, info.size.width, info.size.height)) {
        return '';
      }
      // Decode at the crop size so a huge camera photo never inflates the heap.
      pixelMap = await source.createPixelMap({
        desiredSize: { width: cropRect.size, height: cropRect.size }
      });
      await pixelMap.crop(toRegion(cropRect));
      const scale = avatarCropScale(cropRect.size);
      if (scale !== 1) {
        await pixelMap.scale(scale, scale);
      }
      const packer = image.createImagePacker();
      const jpeg = await packer.packing(pixelMap, {
        format: 'image/jpeg',
        quality: JPEG_QUALITY
      });
      const target = context.cacheDir + '/avatar_' + Date.now().toString() + '.jpg';
      const file = fileIo.openSync(target, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      fileIo.writeSync(file.fd, jpeg);
      fileIo.closeSync(file);
      return target;
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Preparing the avatar failed: %{public}s', String(error));
      return '';
    } finally {
      if (pixelMap !== undefined) {
        pixelMap.release();
      }
      if (source !== undefined) {
        source.release();
      }
    }
  }

  static outputSize(): number {
    return AVATAR_CROP_OUTPUT_SIZE;
  }
}

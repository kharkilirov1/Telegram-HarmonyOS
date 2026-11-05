// F6 (pack card data layer): a sticker carries its pack id, and the pack can be read and installed.
// TDLib: sticker.set_id (int64), getStickerSet (td_api.tl:13354), changeStickerSet (:13371).

import { hilog } from '@kit.PerformanceAnalysisKit';
import { createChangeStickerSetCommand, createGetStickerSetCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { TdObject } from '../../models/TdTypes';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x0049;
const TAG = 'StickerPack';

// A sticker set id is a decimal int64; '0' means "no pack" and is rejected for network calls.
export function isValidStickerSetId(setId: string): boolean {
  return /^[1-9][0-9]{0,18}$/.test(setId);
}

// F6: one sticker of a pack, enough to page the viewer and pre-download the next file.
export class StickerPackSticker {
  stickerId: string = '0';
  remoteFileId: string = '';
  fileId: number = 0;
  localPath: string = '';
  thumbFileId: number = 0;
  thumbPath: string = '';
  emoji: string = '';
  isAnimated: boolean = false;
  isVideo: boolean = false;
  width: number = 0;
  height: number = 0;
}

export class StickerPackInfo {
  setId: string = '0';
  title: string = '';
  isInstalled: boolean = false;
  isArchived: boolean = false;
  stickerCount: number = 0;
  // Paging order is the pack order TDLib returned.
  stickers: StickerPackSticker[] = [];
}

export function parseStickerPackSticker(sticker: TdObject): StickerPackSticker {
  const entry = new StickerPackSticker();
  entry.stickerId = sticker.getTopLevelStringStrict('id') ?? '0';
  entry.emoji = sticker.getTopLevelStringStrict('emoji') ?? '';
  entry.width = sticker.getTopLevelNumberStrict('width') ?? 0;
  entry.height = sticker.getTopLevelNumberStrict('height') ?? 0;
  const format = sticker.getTopLevelStringStrict('format') ?? '';
  const formatType = format.length > 0
    ? format
    : sticker.getObject('format').getTopLevelStringStrict('@type') ?? '';
  entry.isAnimated = formatType === 'stickerFormatTgs';
  entry.isVideo = formatType === 'stickerFormatWebm';
  const file = sticker.getObject('sticker');
  entry.fileId = file.getTopLevelNumberStrict('id') ?? 0;
  entry.remoteFileId = file.getObject('remote').getTopLevelStringStrict('id') ?? '';
  const local = file.getObject('local');
  if (local.getTopLevelBooleanStrict('is_downloading_completed') === true) {
    entry.localPath = local.getTopLevelStringStrict('path') ?? '';
  }
  const thumbFile = sticker.getObject('thumbnail').getObject('file');
  entry.thumbFileId = thumbFile.getTopLevelNumberStrict('id') ?? 0;
  const thumbLocal = thumbFile.getObject('local');
  if (thumbLocal.getTopLevelBooleanStrict('is_downloading_completed') === true) {
    entry.thumbPath = thumbLocal.getTopLevelStringStrict('path') ?? '';
  }
  return entry;
}

// Clamped neighbour inside the pack; a single-sticker pack never wraps onto itself.
export function nextStickerPackIndex(current: number, count: number, delta: number): number {
  if (!Number.isInteger(current) || !Number.isInteger(count) || !Number.isInteger(delta) ||
    count <= 0 || delta === 0) {
    return current;
  }
  const next = current + delta;
  if (next < 0) {
    return 0;
  }
  if (next >= count) {
    return count - 1;
  }
  return next;
}

export function parseStickerPack(td: TdObject): StickerPackInfo | undefined {
  if (td.getTopLevelStringStrict('@type') !== 'stickerSet') {
    return undefined;
  }
  const info = new StickerPackInfo();
  info.setId = td.getTopLevelInt64StringStrict('id') ?? '0';
  info.title = td.getTopLevelStringStrict('title') ?? '';
  info.isInstalled = td.getTopLevelBooleanStrict('is_installed') === true;
  info.isArchived = td.getTopLevelBooleanStrict('is_archived') === true;
  const stickers = td.getTopLevelObjectArrayStrict('stickers');
  info.stickerCount = stickers === undefined ? 0 : stickers.length;
  info.stickers = [];
  if (stickers !== undefined) {
    for (const sticker of stickers) {
      if (sticker === null) {
        continue;
      }
      const parsed = parseStickerPackSticker(sticker);
      if (parsed.stickerId !== '0' && parsed.stickerId.length > 0) {
        info.stickers.push(parsed);
      }
    }
  }
  return info;
}

export class StickerPackUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async load(setId: string): Promise<StickerPackInfo> {
    this.validateSetId(setId);
    try {
      const command = createGetStickerSetCommand(setId);
      const response = await this.gateway.send(command) as TdObject;
      const info = parseStickerPack(response);
      if (info === undefined) {
        throw new AppError(AppErrorKind.UNKNOWN, 'Unsupported sticker set response', 'Unexpected @type',
          0, false);
      }
      return info;
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Sticker set load failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to load the sticker pack', err.message, 0, true);
    }
  }

  // Installing and removing share one TDLib call; an archived set is never installed.
  async setInstalled(setId: string, installed: boolean): Promise<void> {
    this.validateSetId(setId);
    try {
      await this.gateway.send(createChangeStickerSetCommand(setId, installed, false));
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Sticker set update failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to update the sticker pack', err.message, 0,
        true);
    }
  }

  private validateSetId(setId: string): void {
    if (!isValidStickerSetId(setId)) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid sticker set id', 'Input validation failed',
        400, false);
    }
  }
}

export function createStickerPackUseCase(gateway: TdGatewayPort): StickerPackUseCase {
  return new StickerPackUseCase(gateway);
}

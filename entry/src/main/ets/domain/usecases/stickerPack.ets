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

export class StickerPackInfo {
  setId: string = '0';
  title: string = '';
  isInstalled: boolean = false;
  isArchived: boolean = false;
  stickerCount: number = 0;
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
  const stickers = td.getTopLevelRawItemArrayStrict('stickers');
  info.stickerCount = stickers === undefined ? 0 : stickers.length;
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

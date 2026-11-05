// D16: resolve custom emoji ids to sticker documents so the text bubble can draw them.
// TDLib: getCustomEmojiStickers(custom_emoji_ids) → Stickers (request/response, no update).
// The resolver caches per id, batches only unknown ids, caps one request, and asks for a download when the
// file is not on disk yet; the caller re-resolves after the file update arrives.

import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  createDownloadFileCommand,
  createGetCustomEmojiStickersCommand
} from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { TdObject } from '../../core/utils/tdAccessors';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x00D1;
const TAG = 'CustomEmojiResolver';

export const CUSTOM_EMOJI_MAX_IDS_PER_REQUEST = 50;
export const CUSTOM_EMOJI_CACHE_LIMIT = 200;

export class CustomEmojiSticker {
  customEmojiId: string = '0';
  fileId: number = 0;
  localPath: string = '';
  thumbnailFileId: number = 0;
  thumbnailPath: string = '';
  isAnimated: boolean = false;
  isVideo: boolean = false;
  // True when a download was requested for this id; the caller retries after the file lands.
  downloadRequested: boolean = false;
}

export function isValidCustomEmojiId(id: string): boolean {
  if (id.length === 0 || id === '0') {
    return false;
  }
  // TDLib int64 ids are decimal strings; keep them exact and reject anything else.
  return /^[1-9][0-9]{0,18}$/.test(id);
}

export function parseCustomEmojiSticker(sticker: TdObject, customEmojiId: string): CustomEmojiSticker {
  const entry = new CustomEmojiSticker();
  entry.customEmojiId = customEmojiId;
  const format = sticker.getObject('format').getType();
  entry.isAnimated = format === 'stickerFormatTgs';
  entry.isVideo = format === 'stickerFormatWebm';

  const file = sticker.getObject('sticker');
  entry.fileId = file.getNumber('id');
  const local = file.getObject('local');
  if (local.getBool('is_downloading_completed')) {
    const path = local.getString('path');
    entry.localPath = path.length > 0 ? path : '';
  }

  const thumbnailFile = sticker.getObject('thumbnail').getObject('file');
  entry.thumbnailFileId = thumbnailFile.getNumber('id');
  const thumbnailLocal = thumbnailFile.getObject('local');
  if (thumbnailLocal.getBool('is_downloading_completed')) {
    const thumbPath = thumbnailLocal.getString('path');
    entry.thumbnailPath = thumbPath.length > 0 ? thumbPath : '';
  }
  return entry;
}

export class CustomEmojiResolverUseCase {
  private gateway: TdGatewayPort;
  private cache: Map<string, CustomEmojiSticker> = new Map<string, CustomEmojiSticker>();
  private pending: Set<string> = new Set<string>();

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  peek(customEmojiId: string): CustomEmojiSticker | undefined {
    return this.cache.get(customEmojiId);
  }

  isPending(customEmojiId: string): boolean {
    return this.pending.has(customEmojiId);
  }

  // Resolves every requested id that is neither cached with a path nor pending; returns cached entries.
  async resolve(customEmojiIds: string[]): Promise<Map<string, CustomEmojiSticker>> {
    const missing: string[] = [];
    for (const id of customEmojiIds) {
      if (!isValidCustomEmojiId(id) || this.cache.has(id) || this.pending.has(id)) {
        continue;
      }
      if (!missing.includes(id)) {
        missing.push(id);
      }
    }
    if (missing.length === 0) {
      return this.cachedResult(customEmojiIds);
    }
    const batch = missing.slice(0, CUSTOM_EMOJI_MAX_IDS_PER_REQUEST);
    for (const id of batch) {
      this.pending.add(id);
    }
    try {
      const response = await this.gateway.send(createGetCustomEmojiStickersCommand(batch)) as TdObject;
      this.applyResponse(response, batch);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Resolving custom emoji failed: %{public}s', String(error));
    } finally {
      for (const id of batch) {
        this.pending.delete(id);
      }
    }
    return this.cachedResult(customEmojiIds);
  }

  // A file update means the path may exist now; drop the cached entry so the next resolve re-reads it.
  invalidate(customEmojiId: string): void {
    this.cache.delete(customEmojiId);
  }

  clear(): void {
    this.cache.clear();
    this.pending.clear();
  }

  private applyResponse(response: TdObject, requestedIds: string[]): void {
    if (!(response instanceof TdObject) || response.getType() !== 'stickers') {
      return;
    }
    const stickers = response.getArray('stickers');
    for (const sticker of stickers) {
      const customEmojiId = this.customEmojiIdOf(sticker);
      if (!isValidCustomEmojiId(customEmojiId)) {
        continue;
      }
      const entry = parseCustomEmojiSticker(sticker, customEmojiId);
      this.cache.set(customEmojiId, entry);
      this.evictIfNeeded();
      if (entry.localPath.length === 0 && entry.fileId > 0) {
        this.requestDownload(entry);
      }
    }
    // A requested id the server omitted stays uncached so a later call can retry it.
    for (const id of requestedIds) {
      if (!this.cache.has(id)) {
        hilog.warn(DOMAIN, TAG, 'Server returned no sticker for custom emoji %{public}s', id);
      }
    }
  }

  private customEmojiIdOf(sticker: TdObject): string {
    const fullType = sticker.getObject('full_type');
    if (fullType.getType() !== 'stickerFullTypeCustomEmoji') {
      return '0';
    }
    return fullType.getInt64String('custom_emoji_id');
  }

  private requestDownload(entry: CustomEmojiSticker): void {
    entry.downloadRequested = true;
    this.gateway.send(createDownloadFileCommand(entry.fileId, 1))
      .catch((error: Error): void => {
        hilog.warn(DOMAIN, TAG, 'Custom emoji download request failed: %{public}s', error.message);
      });
  }

  private cachedResult(customEmojiIds: string[]): Map<string, CustomEmojiSticker> {
    const result: Map<string, CustomEmojiSticker> = new Map<string, CustomEmojiSticker>();
    for (const id of customEmojiIds) {
      const entry = this.cache.get(id);
      if (entry !== undefined) {
        result.set(id, entry);
      }
    }
    return result;
  }

  private evictIfNeeded(): void {
    while (this.cache.size > CUSTOM_EMOJI_CACHE_LIMIT) {
      const oldest = this.cache.keys().next();
      if (oldest.done === true) {
        return;
      }
      this.cache.delete(oldest.value);
    }
  }
}

export function createCustomEmojiResolverUseCase(gateway: TdGatewayPort): CustomEmojiResolverUseCase {
  return new CustomEmojiResolverUseCase(gateway);
}

// Documents the intended AppError import for callers that wrap resolver failures; kept exported for tests.
export function customEmojiResolverError(message: string): AppError {
  return new AppError(AppErrorKind.UNKNOWN, 'Custom emoji unavailable', message, 0, true);
}

// StickerService — TDLib sticker data loading, parsing, and file management
// Extracted from StickerPicker to separate data logic from UI
// Reference: Telegram iOS StickerPanelController, Android StickersAlert

import { TDLibClient } from './TDLibClient';
import { FileController } from '../controllers/FileController';
import { hilog } from '@kit.PerformanceAnalysisKit';

const STICKER_TAG = 'StickerService';
const STICKER_DOMAIN = 0x0001;

// --- Data models ---

export interface TelegramSticker {
  id: number;
  emoji: string;
  fileId: number;
  localPath: string;
  isAnimated: boolean;
}

export interface StickerSetInfo {
  id: string; // TDLib sticker set IDs are int64, use string for safety
  title: string;
  name: string;
  thumbnailEmoji: string;
  count: number;
  isLoaded: boolean;
  stickers: TelegramSticker[];
}

// --- Parsing helpers ---

export function parseStickerObject(raw: Record<string, Object>): TelegramSticker {
  const stickerId = (raw['id'] as number) || 0;
  const emoji = (raw['emoji'] as string) || '';
  const stickerFile = raw['sticker'] as Record<string, Object>;
  let fileId = 0;
  let localPath = '';
  let isAnimated = false;

  if (stickerFile) {
    const file = stickerFile['file'] as Record<string, Object>;
    if (file) {
      fileId = (file['id'] as number) || 0;
      const local = file['local'] as Record<string, Object>;
      if (local) {
        const isComplete = local['is_downloading_completed'] as boolean;
        if (isComplete) {
          localPath = (local['path'] as string) || '';
        }
      }
    }
  }

  const format = raw['format'] as Record<string, Object>;
  if (format) {
    const formatType = format['@type'] as string;
    if (formatType === 'stickerFormatTgs' || formatType === 'stickerFormatWebm') {
      isAnimated = true;
    }
  }

  const typeField = raw['type'] as Record<string, Object>;
  if (typeField) {
    const typeStr = typeField['@type'] as string;
    if (typeStr === 'stickerTypeAnimated' || typeStr === 'stickerTypeVideo') {
      isAnimated = true;
    }
  }

  return {
    id: stickerId,
    emoji: emoji,
    fileId: fileId,
    localPath: localPath,
    isAnimated: isAnimated
  } as TelegramSticker;
}

export function parseStickerSetInfoObject(raw: Record<string, Object>): StickerSetInfo {
  const id = String(raw['id'] || '0');
  const title = (raw['title'] as string) || '';
  const name = (raw['name'] as string) || '';
  const stickerCount = (raw['size'] as number) || 0;

  let thumbnailEmoji = '';
  const covers = raw['covers'] as Record<string, Object>[];
  if (covers && covers.length > 0) {
    thumbnailEmoji = (covers[0]['emoji'] as string) || '';
  }
  if (thumbnailEmoji.length === 0) {
    thumbnailEmoji = title.length > 0 ? title.charAt(0) : '';
  }

  return {
    id: id,
    title: title,
    name: name,
    thumbnailEmoji: thumbnailEmoji,
    count: stickerCount,
    isLoaded: false,
    stickers: []
  } as StickerSetInfo;
}

// --- TDLib operations ---

export async function loadRecentStickers(): Promise<TelegramSticker[]> {
  try {
    const recentParams: Record<string, Object> = {};
    recentParams['is_attached'] = false;
    const result = await TDLibClient.getInstance().send('getRecentStickers', recentParams);
    const data = result as Record<string, Object>;
    const stickersRaw = data['stickers'] as Record<string, Object>[];
    if (stickersRaw) {
      const parsed: TelegramSticker[] = [];
      for (const raw of stickersRaw) {
        parsed.push(parseStickerObject(raw));
      }
      return parsed;
    }
  } catch (e) {
    hilog.warn(STICKER_DOMAIN, STICKER_TAG, 'Failed to load recent stickers');
  }
  return [];
}

export async function loadInstalledSets(): Promise<StickerSetInfo[]> {
  try {
    const stickerType: Record<string, Object> = {};
    stickerType['@type'] = 'stickerTypeRegular';
    const installedParams: Record<string, Object> = {};
    installedParams['sticker_type'] = stickerType;
    const result = await TDLibClient.getInstance().send('getInstalledStickerSets', installedParams);
    const data = result as Record<string, Object>;
    const setsRaw = data['sets'] as Record<string, Object>[];
    if (setsRaw) {
      const sets: StickerSetInfo[] = [];
      for (const raw of setsRaw) {
        sets.push(parseStickerSetInfoObject(raw));
      }
      return sets;
    }
  } catch (e) {
    hilog.warn(STICKER_DOMAIN, STICKER_TAG, 'Failed to load sticker data');
  }
  return [];
}

export async function loadStickerSetStickers(setInfo: StickerSetInfo): Promise<TelegramSticker[]> {
  if (setInfo.isLoaded) return setInfo.stickers;
  try {
    const getSetParams: Record<string, Object> = {};
    getSetParams['set_id'] = setInfo.id;
    const result = await TDLibClient.getInstance().send('getStickerSet', getSetParams);
    const data = result as Record<string, Object>;
    const stickersRaw = data['stickers'] as Record<string, Object>[];
    if (stickersRaw) {
      const stickers: TelegramSticker[] = [];
      for (const raw of stickersRaw) {
        stickers.push(parseStickerObject(raw));
      }
      return stickers;
    }
  } catch (e) {
    hilog.warn(STICKER_DOMAIN, STICKER_TAG, 'Failed to load sticker data');
  }
  return [];
}

export async function loadTrendingSets(): Promise<StickerSetInfo[]> {
  try {
    const trendingType: Record<string, Object> = {};
    trendingType['@type'] = 'stickerTypeRegular';
    const trendingParams: Record<string, Object> = {};
    trendingParams['sticker_type'] = trendingType;
    trendingParams['offset'] = 0;
    trendingParams['limit'] = 20;
    const result = await TDLibClient.getInstance().send('getTrendingStickerSets', trendingParams);
    const data = result as Record<string, Object>;
    const setsRaw = data['sets'] as Record<string, Object>[];
    if (setsRaw) {
      const sets: StickerSetInfo[] = [];
      for (const raw of setsRaw) {
        sets.push(parseStickerSetInfoObject(raw));
      }
      return sets;
    }
  } catch (e) {
    hilog.warn(STICKER_DOMAIN, STICKER_TAG, 'Failed to load sticker data');
  }
  return [];
}

export async function installStickerSet(setId: string): Promise<void> {
  const installParams: Record<string, Object> = {};
  installParams['set_id'] = setId;
  installParams['is_installed'] = true;
  await TDLibClient.getInstance().send('changeStickerSet', installParams);
}

export async function removeStickerSet(setId: string): Promise<void> {
  const removeParams: Record<string, Object> = {};
  removeParams['set_id'] = setId;
  removeParams['is_installed'] = false;
  await TDLibClient.getInstance().send('changeStickerSet', removeParams);
}

export function downloadStickerFile(
  sticker: TelegramSticker,
  onPathReady: (fileId: number, path: string) => void
): void {
  FileController.getInstance().requestFile(sticker.fileId, 5, (path: string) => {
    onPathReady(sticker.fileId, path);
  });
}

export function updateStickerPathInList(
  stickers: TelegramSticker[],
  fileId: number,
  path: string
): { updated: boolean; list: TelegramSticker[] } {
  let updated = false;
  const newList = stickers.map((s: TelegramSticker): TelegramSticker => {
    if (s.fileId === fileId) {
      updated = true;
      return {
        id: s.id,
        emoji: s.emoji,
        fileId: s.fileId,
        localPath: path,
        isAnimated: s.isAnimated
      } as TelegramSticker;
    }
    return s;
  });
  return { updated, list: newList };
}

export function updateStickerPathInSets(
  sets: StickerSetInfo[],
  fileId: number,
  path: string
): { updated: boolean; list: StickerSetInfo[] } {
  let updated = false;
  const newSets = sets.map((set: StickerSetInfo): StickerSetInfo => {
    const result = updateStickerPathInList(set.stickers, fileId, path);
    if (result.updated) {
      updated = true;
      return {
        id: set.id,
        title: set.title,
        name: set.name,
        thumbnailEmoji: set.thumbnailEmoji,
        count: set.count,
        isLoaded: set.isLoaded,
        stickers: result.list
      } as StickerSetInfo;
    }
    return set;
  });
  return { updated, list: newSets };
}

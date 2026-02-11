// StickerService — TDLib sticker data loading, parsing, and file management
// Extracted from StickerPicker to separate data logic from UI
// Reference: Telegram iOS StickerPanelController, Android StickersAlert

import { TDLibClient } from './TDLibClient';
import { FileController } from '../controllers/FileController';
import { TdObject, safeNumber, safeString, safeBool, asRecord, asArray, tdType } from '../models/TdTypes';
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

interface UpdatedStickerList {
  updated: boolean;
  list: TelegramSticker[];
}

interface UpdatedStickerSetList {
  updated: boolean;
  list: StickerSetInfo[];
}

// --- Parsing helpers ---

export function parseStickerObject(raw: TdObject): TelegramSticker {
  const stickerId = safeNumber(raw['id']);
  const emoji = safeString(raw['emoji']);
  let fileId = 0;
  let localPath = '';
  let isAnimated = false;

  const stickerFileObj = raw['sticker'];
  if (stickerFileObj) {
    const stickerFile = asRecord(stickerFileObj);
    const file = asRecord(stickerFile['file']);
    if (file) {
      fileId = safeNumber(file['id']);
      const local = asRecord(file['local']);
      if (local) {
        const isComplete = safeBool(local['is_downloading_completed']);
        if (isComplete) {
          localPath = safeString(local['path']);
        }
      }
    }
  }

  if (raw['format']) {
    const format = asRecord(raw['format']);
    const formatType = safeString(format['@type']);
    if (formatType === 'stickerFormatTgs' || formatType === 'stickerFormatWebm') {
      isAnimated = true;
    }
  }

  if (raw['type']) {
    const typeField = asRecord(raw['type']);
    const typeStr = safeString(typeField['@type']);
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
  };
}

export function parseStickerSetInfoObject(raw: TdObject): StickerSetInfo {
  const id = String(raw['id'] || '0');
  const title = safeString(raw['title']);
  const name = safeString(raw['name']);
  const stickerCount = safeNumber(raw['size']);

  let thumbnailEmoji = '';
  const covers = asArray(raw['covers']);
  if (covers.length > 0) {
    thumbnailEmoji = safeString(covers[0]['emoji']);
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
  };
}

// --- TDLib operations ---

export async function loadRecentStickers(): Promise<TelegramSticker[]> {
  try {
    const recentParams: TdObject = {};
    recentParams['is_attached'] = false;
    const result = await TDLibClient.getInstance().send('getRecentStickers', recentParams);
    const stickersRaw = asArray(result['stickers']);
    if (stickersRaw.length > 0) {
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
    const stickerType: TdObject = {};
    stickerType['@type'] = 'stickerTypeRegular';
    const installedParams: TdObject = {};
    installedParams['sticker_type'] = stickerType;
    const result = await TDLibClient.getInstance().send('getInstalledStickerSets', installedParams);
    const setsRaw = asArray(result['sets']);
    if (setsRaw.length > 0) {
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
    const getSetParams: TdObject = {};
    getSetParams['set_id'] = setInfo.id;
    const result = await TDLibClient.getInstance().send('getStickerSet', getSetParams);
    const stickersRaw = asArray(result['stickers']);
    if (stickersRaw.length > 0) {
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
    const trendingType: TdObject = {};
    trendingType['@type'] = 'stickerTypeRegular';
    const trendingParams: TdObject = {};
    trendingParams['sticker_type'] = trendingType;
    trendingParams['offset'] = 0;
    trendingParams['limit'] = 20;
    const result = await TDLibClient.getInstance().send('getTrendingStickerSets', trendingParams);
    const setsRaw = asArray(result['sets']);
    if (setsRaw.length > 0) {
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
  const installParams: TdObject = {};
  installParams['set_id'] = setId;
  installParams['is_installed'] = true;
  await TDLibClient.getInstance().send('changeStickerSet', installParams);
}

export async function removeStickerSet(setId: string): Promise<void> {
  const removeParams: TdObject = {};
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
): UpdatedStickerList {
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
      };
    }
    return s;
  });
  const result: UpdatedStickerList = { updated: updated, list: newList };
  return result;
}

export function updateStickerPathInSets(
  sets: StickerSetInfo[],
  fileId: number,
  path: string
): UpdatedStickerSetList {
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
      };
    }
    return set;
  });
  const result: UpdatedStickerSetList = { updated: updated, list: newSets };
  return result;
}

// Storage statistics DTO — Settings → Data and Storage (H4).
// TDLib: storageStatistics (td_api.tl:8916), storageStatisticsByChat (:8910),
// storageStatisticsFast (getStorageStatisticsFast :14429).

import { TdObject as TdObjectType } from '../../../models/TdTypes';
import { TdObject } from '../../../models/TdTypes';

export const STORAGE_BYTE_UNITS: string[] = ['B', 'KB', 'MB', 'GB', 'TB'];

// Human size with one decimal for the larger units, matching the Telegram storage screen.
export function formatStorageBytes(bytes: number): string {
  if (!Number.isFinite(bytes) || bytes <= 0) {
    return '0 B';
  }
  let value: number = bytes;
  let unit: number = 0;
  while (value >= 1024 && unit < STORAGE_BYTE_UNITS.length - 1) {
    value = value / 1024;
    unit += 1;
  }
  if (unit === 0) {
    return `${Math.round(value)} B`;
  }
  const rounded: number = Math.round(value * 10) / 10;
  return `${rounded} ${STORAGE_BYTE_UNITS[unit]}`;
}

export class StorageChatUsageDto {
  chatId: number = 0;
  size: number = 0;
  count: number = 0;
}

export class StorageStatisticsDto {
  totalSize: number = 0;
  totalCount: number = 0;
  byChat: StorageChatUsageDto[] = [];
}

export class FastStorageStatisticsDto {
  filesSize: number = 0;
  fileCount: number = 0;
  databaseSize: number = 0;
  languagePackDatabaseSize: number = 0;
  logSize: number = 0;
}

function readInt64(td: TdObjectType, prop: string): number {
  const text = td.getTopLevelInt64StringStrict(prop);
  if (text === undefined || text.length === 0) {
    return 0;
  }
  const value = Number(text);
  return Number.isFinite(value) && value >= 0 ? value : 0;
}

export function createStorageStatisticsFromTd(td: TdObjectType): StorageStatisticsDto {
  const dto = new StorageStatisticsDto();
  if (td.getTopLevelStringStrict('@type') !== 'storageStatistics') {
    return dto;
  }
  dto.totalSize = readInt64(td, 'size');
  const total = td.getTopLevelNumberStrict('count');
  dto.totalCount = total !== undefined && Number.isSafeInteger(total) && total >= 0 ? total : 0;
  const rawChats = td.getTopLevelRawObjectArrayStrict('by_chat');
  if (rawChats === undefined) {
    return dto;
  }
  for (const rawText of rawChats) {
    const chatTd = TdObjectType.fromJSON(rawText);
    const chatId = chatTd.getTopLevelNumberStrict('chat_id');
    if (chatId === undefined || !Number.isSafeInteger(chatId) || chatId === 0) {
      continue;
    }
    const usage = new StorageChatUsageDto();
    usage.chatId = chatId;
    usage.size = readInt64(chatTd, 'size');
    const count = chatTd.getTopLevelNumberStrict('count');
    usage.count = count !== undefined && Number.isSafeInteger(count) && count >= 0 ? count : 0;
    dto.byChat.push(usage);
  }
  dto.byChat.sort((left: StorageChatUsageDto, right: StorageChatUsageDto): number => right.size - left.size);
  return dto;
}

export function createFastStorageStatisticsFromTd(td: TdObjectType): FastStorageStatisticsDto {
  const dto = new FastStorageStatisticsDto();
  if (td.getTopLevelStringStrict('@type') !== 'storageStatisticsFast') {
    return dto;
  }
  dto.filesSize = readInt64(td, 'files_size');
  const fileCount = td.getTopLevelNumberStrict('file_count');
  dto.fileCount = fileCount !== undefined && Number.isSafeInteger(fileCount) && fileCount >= 0 ? fileCount : 0;
  dto.databaseSize = readInt64(td, 'database_size');
  dto.languagePackDatabaseSize = readInt64(td, 'language_pack_database_size');
  dto.logSize = readInt64(td, 'log_size');
  return dto;
}

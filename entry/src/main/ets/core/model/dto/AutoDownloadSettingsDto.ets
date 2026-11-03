// Auto-download settings DTO — Settings → Data and Storage → Auto-Download (H4).
// TDLib: autoDownloadSettings (td_api.tl:8979), autoDownloadSettingsPresets (:8985),
// getAutoDownloadSettingsPresets (:14462), setAutoDownloadSettings (:14465).
// This TDLib version exposes presets only — there is no getter for the currently applied settings,
// so the screen applies a preset and reports it as applied for the session.

import { TdObject as TdObjectType } from '../../../models/TdTypes';

export type AutoDownloadNetworkType = 'mobile' | 'mobileRoaming' | 'wifi' | 'other' | 'none';
export type AutoDownloadPresetLevel = 'low' | 'medium' | 'high';

export class AutoDownloadSettingsDto {
  isAutoDownloadEnabled: boolean = true;
  maxPhotoFileSize: number = 0;
  maxVideoFileSize: number = 0;
  maxOtherFileSize: number = 0;
  videoUploadBitrate: number = 0;
  preloadLargeVideos: boolean = false;
  preloadNextAudio: boolean = false;
  preloadStories: boolean = false;
  useLessDataForCalls: boolean = false;
}

function readBool(td: TdObjectType, prop: string): boolean {
  return td.getTopLevelBooleanStrict(prop) ?? false;
}

function readInt(td: TdObjectType, prop: string): number {
  const value = td.getTopLevelNumberStrict(prop);
  return value !== undefined && Number.isFinite(value) && value >= 0 ? value : 0;
}

export function createAutoDownloadSettingsFromTd(td: TdObjectType): AutoDownloadSettingsDto {
  const dto = new AutoDownloadSettingsDto();
  dto.isAutoDownloadEnabled = readBool(td, 'is_auto_download_enabled');
  dto.maxPhotoFileSize = readInt(td, 'max_photo_file_size');
  dto.maxVideoFileSize = readInt(td, 'max_video_file_size');
  dto.maxOtherFileSize = readInt(td, 'max_other_file_size');
  dto.videoUploadBitrate = readInt(td, 'video_upload_bitrate');
  dto.preloadLargeVideos = readBool(td, 'preload_large_videos');
  dto.preloadNextAudio = readBool(td, 'preload_next_audio');
  dto.preloadStories = readBool(td, 'preload_stories');
  dto.useLessDataForCalls = readBool(td, 'use_less_data_for_calls');
  return dto;
}

export class AutoDownloadPresetsDto {
  hasPresets: boolean = false;
  low: AutoDownloadSettingsDto = new AutoDownloadSettingsDto();
  medium: AutoDownloadSettingsDto = new AutoDownloadSettingsDto();
  high: AutoDownloadSettingsDto = new AutoDownloadSettingsDto();
}

export function createAutoDownloadPresetsFromTd(td: TdObjectType): AutoDownloadPresetsDto {
  const dto = new AutoDownloadPresetsDto();
  if (td.getTopLevelStringStrict('@type') !== 'autoDownloadSettingsPresets') {
    return dto;
  }
  const low = td.getTopLevelObjectStrict('low');
  const medium = td.getTopLevelObjectStrict('medium');
  const high = td.getTopLevelObjectStrict('high');
  if (low === undefined || medium === undefined || high === undefined) {
    return dto;
  }
  dto.low = createAutoDownloadSettingsFromTd(low);
  dto.medium = createAutoDownloadSettingsFromTd(medium);
  dto.high = createAutoDownloadSettingsFromTd(high);
  dto.hasPresets = true;
  return dto;
}

export function selectAutoDownloadPreset(
  presets: AutoDownloadPresetsDto,
  level: AutoDownloadPresetLevel
): AutoDownloadSettingsDto {
  if (level === 'low') {
    return presets.low;
  }
  if (level === 'high') {
    return presets.high;
  }
  return presets.medium;
}

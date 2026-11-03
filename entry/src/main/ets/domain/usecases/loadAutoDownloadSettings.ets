// Auto-download settings — Settings → Data and Storage → Auto-Download (H4).
// TDLib exposes presets (getAutoDownloadSettingsPresets = AutoDownloadSettingsPresets, td_api.tl:14462)
// and an apply call (setAutoDownloadSettings, :14465). There is no getter for the settings currently in
// effect in this version, so the screen applies a preset and marks it as applied for the session.

import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  AutoDownloadNetworkType,
  createGetAutoDownloadSettingsPresetsCommand,
  createSetAutoDownloadSettingsCommand,
  SetAutoDownloadSettingsPayload
} from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import {
  AutoDownloadPresetLevel,
  AutoDownloadPresetsDto,
  AutoDownloadSettingsDto,
  createAutoDownloadPresetsFromTd,
  selectAutoDownloadPreset
} from '../../core/model/dto/AutoDownloadSettingsDto';
import { TdObject } from '../../models/TdTypes';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x0038;
const TAG = 'AutoDownloadSettings';

export class LoadAutoDownloadSettingsUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async fetchPresets(): Promise<AutoDownloadPresetsDto> {
    try {
      const response = await this.gateway.send(createGetAutoDownloadSettingsPresetsCommand()) as TdObject;
      return createAutoDownloadPresetsFromTd(response);
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'getAutoDownloadSettingsPresets failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to load auto-download presets', err.message, 0, true);
    }
  }

  async applyPreset(
    networkType: AutoDownloadNetworkType,
    presets: AutoDownloadPresetsDto,
    level: AutoDownloadPresetLevel
  ): Promise<void> {
    if (!presets.hasPresets) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Presets are unavailable', 'Load presets first', 400, false);
    }
    const settings: AutoDownloadSettingsDto = selectAutoDownloadPreset(presets, level);
    const payload = new SetAutoDownloadSettingsPayload();
    payload.networkType = networkType;
    payload.isAutoDownloadEnabled = settings.isAutoDownloadEnabled;
    payload.maxPhotoFileSize = settings.maxPhotoFileSize;
    payload.maxVideoFileSize = settings.maxVideoFileSize;
    payload.maxOtherFileSize = settings.maxOtherFileSize;
    payload.videoUploadBitrate = settings.videoUploadBitrate;
    payload.preloadLargeVideos = settings.preloadLargeVideos;
    payload.preloadNextAudio = settings.preloadNextAudio;
    payload.preloadStories = settings.preloadStories;
    payload.useLessDataForCalls = settings.useLessDataForCalls;
    try {
      hilog.info(DOMAIN, TAG, 'Applying %{public}s preset to %{public}s', level, networkType);
      await this.gateway.send(createSetAutoDownloadSettingsCommand(payload));
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'setAutoDownloadSettings failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to apply auto-download settings', err.message, 0, true);
    }
  }
}

export function createLoadAutoDownloadSettingsUseCase(
  gateway: TdGatewayPort
): LoadAutoDownloadSettingsUseCase {
  return new LoadAutoDownloadSettingsUseCase(gateway);
}

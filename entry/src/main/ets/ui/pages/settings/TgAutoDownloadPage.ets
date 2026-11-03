// TgAutoDownloadPage — Settings → Data and Storage → Auto-Download (H4).
// TDLib: getAutoDownloadSettingsPresets (td_api.tl:14462), setAutoDownloadSettings (:14465).
// Presets only: this TDLib version has no getter for the settings in effect, so a tapped row is shown
// as applied for this screen session (documented in the capability matrix).

import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { localized } from '../../../core/utils/AppResource';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import {
  createLoadAutoDownloadSettingsUseCase,
  LoadAutoDownloadSettingsUseCase
} from '../../../domain/usecases/loadAutoDownloadSettings';
import {
  AutoDownloadNetworkType,
  AutoDownloadPresetLevel,
  AutoDownloadPresetsDto,
  AutoDownloadSettingsDto,
  selectAutoDownloadPreset
} from '../../../core/model/dto/AutoDownloadSettingsDto';
import { AutoDownloadNetworkType as CommandNetworkType } from '../../../core/model/AppCommand';
import { formatStorageBytes } from '../../../core/model/dto/StorageStatisticsDto';
import { TgChatTopBar } from '../../tg_ui/atoms/TgChatTopBar';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { computeTopBarHeight } from '../../utils/SafeAreaUtils';

const DOMAIN = 0x0038;
const TAG = 'TgAutoDownloadPage';

@Builder
export function TgAutoDownloadPageBuilder() {
  TgAutoDownloadPage();
}

@ComponentV2
export struct TgAutoDownloadPage {
  @Local private pageStack: NavPathStack = new NavPathStack();
  @Local private presets: AutoDownloadPresetsDto = new AutoDownloadPresetsDto();
  @Local private isLoading: boolean = true;
  @Local private loadFailed: boolean = false;
  @Local private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @Local private topBarInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;
  @Local private appliedMobile: string = '';
  @Local private appliedRoaming: string = '';
  @Local private appliedWifi: string = '';

  private loadUseCase?: LoadAutoDownloadSettingsUseCase;
  private pageLifecycleToken: number = 0;

  aboutToAppear(): void {
    this.pageLifecycleToken += 1;
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.topBarTotalHeight = computeTopBarHeight(context);
      this.topBarInset = this.topBarTotalHeight - TgUiTokens.TOP_BAR_HEIGHT;
    } catch (_error) {
      this.topBarTotalHeight = TgUiTokens.TOP_BAR_HEIGHT;
      this.topBarInset = TgUiTokens.STATUS_BAR_FALLBACK_INSET;
    }
    try {
      this.loadUseCase = createLoadAutoDownloadSettingsUseCase(getTdGatewayAdapter());
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Auto-download use case init failed: %{public}s', String(error));
      this.isLoading = false;
      this.loadFailed = true;
      return;
    }
    this.reloadPresets();
  }

  aboutToDisappear(): void {
    this.pageLifecycleToken += 1;
    this.loadUseCase = undefined;
  }

  private reloadPresets(): void {
    const useCase = this.loadUseCase;
    if (useCase === undefined) {
      return;
    }
    const token: number = this.pageLifecycleToken;
    this.isLoading = true;
    this.loadFailed = false;
    useCase.fetchPresets()
      .then((presets: AutoDownloadPresetsDto) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.presets = presets;
        this.isLoading = false;
        this.loadFailed = !presets.hasPresets;
      })
      .catch((error: Error) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        hilog.error(DOMAIN, TAG, 'Load presets failed: %{public}s', error.message);
        this.isLoading = false;
        this.loadFailed = true;
      });
  }

  private presetLevelLabel(level: AutoDownloadPresetLevel): string {
    if (level === 'low') {
      return localized($r('app.string.auto_download_low').id, 'Low');
    }
    if (level === 'high') {
      return localized($r('app.string.auto_download_high').id, 'High');
    }
    return localized($r('app.string.auto_download_medium').id, 'Medium');
  }

  private presetSummary(level: AutoDownloadPresetLevel): string {
    const settings: AutoDownloadSettingsDto = selectAutoDownloadPreset(this.presets, level);
    if (!settings.isAutoDownloadEnabled) {
      return localized($r('app.string.auto_download_disabled').id, 'Auto-download is off');
    }
    return localized($r('app.string.auto_download_photo_limit').id, 'Photos up to') + ' ' +
      formatStorageBytes(settings.maxPhotoFileSize) + ' · ' +
      localized($r('app.string.auto_download_video_limit').id, 'videos up to') + ' ' +
      formatStorageBytes(settings.maxVideoFileSize);
  }

  private appliedLabel(network: AutoDownloadNetworkType): string {
    if (network === 'mobile') {
      return this.appliedMobile;
    }
    if (network === 'mobileRoaming') {
      return this.appliedRoaming;
    }
    return this.appliedWifi;
  }

  private markApplied(network: CommandNetworkType, level: AutoDownloadPresetLevel): void {
    const label: string = this.presetLevelLabel(level);
    if (network === 'mobile') {
      this.appliedMobile = label;
    } else if (network === 'mobileRoaming') {
      this.appliedRoaming = label;
    } else {
      this.appliedWifi = label;
    }
  }

  private apply(network: CommandNetworkType, level: AutoDownloadPresetLevel): void {
    const useCase = this.loadUseCase;
    if (useCase === undefined) {
      return;
    }
    const token: number = this.pageLifecycleToken;
    useCase.applyPreset(network, this.presets, level)
      .then(() => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.markApplied(network, level);
      })
      .catch((error: Error) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        hilog.error(DOMAIN, TAG, 'Apply preset failed: %{public}s', error.message);
      });
  }

  @Builder
  buildNetworkSection(title: string, network: CommandNetworkType) {
    Column() {
      Row() {
        Text(title)
          .fontSize(TgUiTokens.FONT_TITLE_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .layoutWeight(1)
        if (this.appliedLabel(network).length > 0) {
          Text(localized($r('app.string.auto_download_applied').id, 'Applied') + ': ' + this.appliedLabel(network))
            .fontSize(TgUiTokens.FONT_META_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_META)
        }
      }
      .width('100%')
      .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_12 })
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)

      ForEach(['low', 'medium', 'high'] as string[], (level: string) => {
        Row() {
          Column() {
            Text(this.presetLevelLabel(level as AutoDownloadPresetLevel))
              .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
              .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
            Text(this.presetSummary(level as AutoDownloadPresetLevel))
              .fontSize(TgUiTokens.FONT_META_SIZE)
              .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
              .margin({ top: TgUiTokens.SPACE_2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding({
          left: TgUiTokens.SPACE_16,
          right: TgUiTokens.SPACE_16,
          top: TgUiTokens.SPACE_10,
          bottom: TgUiTokens.SPACE_10
        })
        .onClick(() => {
          this.apply(network, level as AutoDownloadPresetLevel);
        })
      }, (level: string) => network + ':' + level)
    }
    .width('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    .borderRadius(12)
    .margin({ left: 16, right: 16, top: 16 })
    .clip(true)
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        Scroll() {
          Column() {
            if (this.isLoading) {
              Text(localized($r('app.string.auto_download_loading').id, 'Loading…'))
                .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ top: TgUiTokens.SPACE_24 })
            } else if (this.loadFailed || !this.presets.hasPresets) {
              Column() {
                Text(localized($r('app.string.auto_download_load_failed').id, 'Could not load presets'))
                  .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                  .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
                Text(localized($r('app.string.auto_download_retry').id, 'Retry'))
                  .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                  .fontColor(TgUiTokens.CHAT_TOP_BAR_SUBTITLE_ACCENT)
                  .margin({ top: TgUiTokens.SPACE_8 })
                  .onClick(() => {
                    this.reloadPresets();
                  })
              }
              .width('100%')
              .padding({ top: TgUiTokens.SPACE_24 })
            } else {
              this.buildNetworkSection(localized($r('app.string.auto_download_mobile').id, 'Mobile'),
                'mobile')
              this.buildNetworkSection(localized($r('app.string.auto_download_roaming').id, 'Roaming'),
                'mobileRoaming')
              this.buildNetworkSection(localized($r('app.string.auto_download_wifi').id, 'Wi-Fi'),
                'wifi')
              Text(localized($r('app.string.auto_download_note').id,
                'Presets only: the active preset is not exposed by TDLib in this version.'))
                .fontSize(TgUiTokens.FONT_META_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_META)
                .width('100%')
                .padding({
                  left: TgUiTokens.SPACE_16,
                  right: TgUiTokens.SPACE_16,
                  top: TgUiTokens.SPACE_12
                })
            }
            Column().height(40)
          }
          .width('100%')
        }
        .width('100%')
        .height('100%')
        .contentStartOffset(this.topBarTotalHeight)
        .scrollBar(BarState.Off)
        .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)

        TgChatTopBar({
          topInset: this.topBarInset,
          title: localized($r('app.string.data_storage_auto_download').id, 'Auto-Download'),
          onBackPress: (): void => {
            this.pageStack.pop();
          }
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
    }
    .hideTitleBar(true)
  }
}

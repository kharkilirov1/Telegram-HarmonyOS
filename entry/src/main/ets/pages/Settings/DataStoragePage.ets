// Data and Storage settings page
// Reference: Telegram iOS DataSettingsController, Android DataSettingsActivity

import { hilog } from '@kit.PerformanceAnalysisKit';
import { PreferencesService } from '../../services/PreferencesService';
import { ChatService } from '../../services/ChatService';

// Size limit options for videos and files auto-download
const SIZE_OPTIONS: number[] = [
  1048576,       // 1 MB
  5242880,       // 5 MB
  15728640,      // 15 MB
  52428800,      // 50 MB
  104857600,     // 100 MB
  536870912,     // 512 MB
  1610612736     // 1.5 GB
];

const SIZE_LABELS: string[] = [
  '1 MB', '5 MB', '15 MB', '50 MB', '100 MB', '512 MB', '1.5 GB'
];

@Builder
export function DataStorageBuilder(name: string, param: Object) {
  DataStoragePage()
}

@ComponentV2
export struct DataStoragePage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();

  // Auto-download per media type / per network type
  @Local photosMobile: boolean = false;
  @Local photosWifi: boolean = true;
  @Local photosRoaming: boolean = false;

  @Local videosMobile: boolean = false;
  @Local videosWifi: boolean = true;
  @Local videosRoaming: boolean = false;
  @Local videosMaxSize: number = 15728640;

  @Local filesMobile: boolean = false;
  @Local filesWifi: boolean = true;
  @Local filesRoaming: boolean = false;
  @Local filesMaxSize: number = 1048576;

  // Expandable section state
  @Local photosExpanded: boolean = false;
  @Local videosExpanded: boolean = false;
  @Local filesExpanded: boolean = false;

  // Auto-play
  @Local autoPlayGifs: boolean = true;
  @Local autoPlayVideos: boolean = true;

  // Save to gallery
  @Local saveIncoming: boolean = false;
  @Local saveEdited: boolean = false;

  // Cache info
  @Local cacheSize: string = '256 MB';

  // Size picker dialog state
  @Local showSizePicker: boolean = false;
  @Local sizePickerMediaType: string = 'videos';

  private prefs: PreferencesService = PreferencesService.getInstance();

  aboutToAppear(): void {
    this.loadSettings();
    this.loadAutoDownloadPresets();
  }

  private async loadSettings(): Promise<void> {
    const p = this.prefs;

    this.photosMobile = await p.getAutoDownloadEnabled('photos', 'mobile');
    this.photosWifi = await p.getAutoDownloadEnabled('photos', 'wifi');
    this.photosRoaming = await p.getAutoDownloadEnabled('photos', 'roaming');

    this.videosMobile = await p.getAutoDownloadEnabled('videos', 'mobile');
    this.videosWifi = await p.getAutoDownloadEnabled('videos', 'wifi');
    this.videosRoaming = await p.getAutoDownloadEnabled('videos', 'roaming');
    this.videosMaxSize = await p.getAutoDownloadMaxSize('videos');

    this.filesMobile = await p.getAutoDownloadEnabled('files', 'mobile');
    this.filesWifi = await p.getAutoDownloadEnabled('files', 'wifi');
    this.filesRoaming = await p.getAutoDownloadEnabled('files', 'roaming');
    this.filesMaxSize = await p.getAutoDownloadMaxSize('files');

    this.autoPlayGifs = await p.getAutoPlayGifs();
    this.autoPlayVideos = await p.getAutoPlayVideos();
    this.saveIncoming = await p.getSaveIncomingPhotos();
    this.saveEdited = await p.getSaveEditedPhotos();
  }

  private async loadAutoDownloadPresets(): Promise<void> {
    try {
      const result = await ChatService.getInstance().getAutoDownloadSettingsPresets();
      if (result !== null && result !== undefined) {
        // Presets loaded from TDLib; local preferences take priority for UI state
      }
    } catch (e) {
      hilog.warn(0x0001, 'DataStoragePage', 'Failed to load auto-download presets');
    }
  }

  private async syncToTDLib(networkTypeStr: string): Promise<void> {
    let tdlibNetworkType: string;
    if (networkTypeStr === 'mobile') {
      tdlibNetworkType = 'networkTypeMobile';
    } else if (networkTypeStr === 'roaming') {
      tdlibNetworkType = 'networkTypeRoaming';
    } else {
      tdlibNetworkType = 'networkTypeWiFi';
    }

    let photosEnabled: boolean;
    let videosEnabled: boolean;
    let filesEnabled: boolean;

    if (networkTypeStr === 'mobile') {
      photosEnabled = this.photosMobile;
      videosEnabled = this.videosMobile;
      filesEnabled = this.filesMobile;
    } else if (networkTypeStr === 'roaming') {
      photosEnabled = this.photosRoaming;
      videosEnabled = this.videosRoaming;
      filesEnabled = this.filesRoaming;
    } else {
      photosEnabled = this.photosWifi;
      videosEnabled = this.videosWifi;
      filesEnabled = this.filesWifi;
    }

    const isEnabled = photosEnabled || videosEnabled || filesEnabled;

    try {
      const autoDownloadSettings: Record<string, Object> = {};
      autoDownloadSettings['@type'] = 'autoDownloadSettings';
      autoDownloadSettings['is_auto_download_enabled'] = isEnabled;
      autoDownloadSettings['max_photo_file_size'] = photosEnabled ? 1048576 : 0;
      autoDownloadSettings['max_video_file_size'] = videosEnabled ? this.videosMaxSize : 0;
      autoDownloadSettings['max_other_file_size'] = filesEnabled ? this.filesMaxSize : 0;
      autoDownloadSettings['video_upload_bitrate'] = 0;
      autoDownloadSettings['preload_large_videos'] = false;
      autoDownloadSettings['preload_next_audio'] = true;
      autoDownloadSettings['preload_stories'] = true;
      autoDownloadSettings['use_less_data_for_calls'] = false;
      await ChatService.getInstance().setAutoDownloadSettings(autoDownloadSettings, tdlibNetworkType);
    } catch (e) {
      hilog.warn(0x0001, 'DataStoragePage', 'Failed to sync auto-download settings to TDLib');
    }
  }

  private formatSize(bytes: number): string {
    const idx = SIZE_OPTIONS.indexOf(bytes);
    if (idx >= 0) {
      return SIZE_LABELS[idx];
    }
    if (bytes >= 1073741824) {
      return `${(bytes / 1073741824).toFixed(1)} GB`;
    } else if (bytes >= 1048576) {
      return `${Math.round(bytes / 1048576)} MB`;
    }
    return `${Math.round(bytes / 1024)} KB`;
  }

  private getMediaSummary(mobile: boolean, wifi: boolean, roaming: boolean): string {
    const rm = getContext(this).resourceManager;
    const parts: string[] = [];
    if (mobile) {
      parts.push(rm.getStringByNameSync('data_summary_mobile'));
    }
    if (wifi) {
      parts.push(rm.getStringByNameSync('data_summary_wifi'));
    }
    if (roaming) {
      parts.push(rm.getStringByNameSync('data_summary_roaming'));
    }
    if (parts.length === 0) {
      return rm.getStringByNameSync('data_summary_off');
    }
    return parts.join(', ');
  }

  build() {
    NavDestination() {
      Column() {
        // Top bar
        Row() {
          Image($r('app.media.ic_back'))
            .width(24).height(24)
            .fillColor($r('app.color.telegram_blue'))
            .onClick(() => this.navPathStack.pop())
            .accessibilityText($r('app.string.accessibility_back'))

          Text($r('app.string.settings_data_storage'))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ left: 16 })
        }
        .width('100%')
        .height(56)
        .padding({ left: 8, right: 16 })
        .backgroundColor($r('app.color.glass_nav_bg'))
        .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
          colorMode: ThemeColorMode.SYSTEM,
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: 1.0
        })

        Scroll() {
          Column() {
            // --- Storage Usage Section ---
            this.sectionHeader($r('app.string.data_storage_usage_section'))

            Column() {
              Row() {
                this.settingsIcon($r('app.media.ic_document'), $r('app.color.settings_icon_blue'))
                Column() {
                  Text($r('app.string.data_storage_usage'))
                    .fontSize(16)
                    .fontColor($r('app.color.text_primary'))
                  Text(this.cacheSize)
                    .fontSize(13)
                    .fontColor($r('app.color.text_secondary'))
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Image($r('app.media.ic_forward'))
                  .width(14).height(14)
                  .fillColor($r('app.color.text_secondary'))
              }
              .width('100%').height(52)
              .padding({ left: 16, right: 16 })

              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 52 })

              Row() {
                this.settingsIcon($r('app.media.ic_channel'), $r('app.color.settings_icon_green'))
                Text($r('app.string.data_network_usage'))
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                Image($r('app.media.ic_forward'))
                  .width(14).height(14)
                  .fillColor($r('app.color.text_secondary'))
              }
              .width('100%').height(48)
              .padding({ left: 16, right: 16 })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            Blank().height(24)

            // --- Auto-Download Media Section ---
            this.sectionHeader($r('app.string.data_auto_download'))

            Column() {
              // Photos expandable row
              this.expandableMediaRow(
                $r('app.string.data_auto_download_photos'),
                this.getMediaSummary(this.photosMobile, this.photosWifi, this.photosRoaming),
                this.photosExpanded,
                () => { this.photosExpanded = !this.photosExpanded; }
              )

              if (this.photosExpanded) {
                Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

                this.networkToggleRow($r('app.string.data_mobile_data'), this.photosMobile, (v: boolean) => {
                  this.photosMobile = v;
                  this.prefs.setAutoDownloadEnabled('photos', 'mobile', v);
                  this.syncToTDLib('mobile');
                })
                Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 40 })

                this.networkToggleRow($r('app.string.data_wifi'), this.photosWifi, (v: boolean) => {
                  this.photosWifi = v;
                  this.prefs.setAutoDownloadEnabled('photos', 'wifi', v);
                  this.syncToTDLib('wifi');
                })
                Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 40 })

                this.networkToggleRow($r('app.string.data_roaming'), this.photosRoaming, (v: boolean) => {
                  this.photosRoaming = v;
                  this.prefs.setAutoDownloadEnabled('photos', 'roaming', v);
                  this.syncToTDLib('roaming');
                })
              }

              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

              // Videos expandable row
              this.expandableMediaRow(
                $r('app.string.data_auto_download_videos'),
                this.getMediaSummary(this.videosMobile, this.videosWifi, this.videosRoaming),
                this.videosExpanded,
                () => { this.videosExpanded = !this.videosExpanded; }
              )

              if (this.videosExpanded) {
                Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

                this.networkToggleRow($r('app.string.data_mobile_data'), this.videosMobile, (v: boolean) => {
                  this.videosMobile = v;
                  this.prefs.setAutoDownloadEnabled('videos', 'mobile', v);
                  this.syncToTDLib('mobile');
                })
                Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 40 })

                this.networkToggleRow($r('app.string.data_wifi'), this.videosWifi, (v: boolean) => {
                  this.videosWifi = v;
                  this.prefs.setAutoDownloadEnabled('videos', 'wifi', v);
                  this.syncToTDLib('wifi');
                })
                Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 40 })

                this.networkToggleRow($r('app.string.data_roaming'), this.videosRoaming, (v: boolean) => {
                  this.videosRoaming = v;
                  this.prefs.setAutoDownloadEnabled('videos', 'roaming', v);
                  this.syncToTDLib('roaming');
                })
                Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 40 })

                this.sizeLimitRow(this.videosMaxSize, () => {
                  this.sizePickerMediaType = 'videos';
                  this.showSizePicker = true;
                })
              }

              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

              // Files expandable row
              this.expandableMediaRow(
                $r('app.string.data_auto_download_files'),
                this.getMediaSummary(this.filesMobile, this.filesWifi, this.filesRoaming),
                this.filesExpanded,
                () => { this.filesExpanded = !this.filesExpanded; }
              )

              if (this.filesExpanded) {
                Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

                this.networkToggleRow($r('app.string.data_mobile_data'), this.filesMobile, (v: boolean) => {
                  this.filesMobile = v;
                  this.prefs.setAutoDownloadEnabled('files', 'mobile', v);
                  this.syncToTDLib('mobile');
                })
                Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 40 })

                this.networkToggleRow($r('app.string.data_wifi'), this.filesWifi, (v: boolean) => {
                  this.filesWifi = v;
                  this.prefs.setAutoDownloadEnabled('files', 'wifi', v);
                  this.syncToTDLib('wifi');
                })
                Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 40 })

                this.networkToggleRow($r('app.string.data_roaming'), this.filesRoaming, (v: boolean) => {
                  this.filesRoaming = v;
                  this.prefs.setAutoDownloadEnabled('files', 'roaming', v);
                  this.syncToTDLib('roaming');
                })
                Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 40 })

                this.sizeLimitRow(this.filesMaxSize, () => {
                  this.sizePickerMediaType = 'files';
                  this.showSizePicker = true;
                })
              }
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            Text($r('app.string.data_auto_download_hint'))
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .margin({ left: 32, top: 6 })

            Blank().height(12)

            // Reset auto-download settings
            Column() {
              Text($r('app.string.data_reset_settings'))
                .fontSize(16)
                .fontColor($r('app.color.telegram_blue'))
                .textAlign(TextAlign.Center)
                .width('100%')
                .height(44)
                .onClick(() => { this.resetAutoDownloadSettings(); })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            Blank().height(24)

            // --- Auto-Play Media Section ---
            this.sectionHeader($r('app.string.data_auto_play'))

            Column() {
              this.toggleRow($r('app.string.data_auto_play_gifs'), this.autoPlayGifs, (v: boolean) => {
                this.autoPlayGifs = v;
                this.prefs.setAutoPlayGifs(v);
              })
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.toggleRow($r('app.string.data_auto_play_videos'), this.autoPlayVideos, (v: boolean) => {
                this.autoPlayVideos = v;
                this.prefs.setAutoPlayVideos(v);
              })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            Blank().height(24)

            // --- Save to Gallery Section ---
            this.sectionHeader($r('app.string.data_save_gallery'))

            Column() {
              this.toggleRow($r('app.string.data_save_incoming'), this.saveIncoming,
                (v: boolean) => {
                  this.saveIncoming = v;
                  this.prefs.setSaveIncomingPhotos(v);
                })
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
              this.toggleRow($r('app.string.data_save_edited'), this.saveEdited,
                (v: boolean) => {
                  this.saveEdited = v;
                  this.prefs.setSaveEditedPhotos(v);
                })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            Blank().height(24)

            // --- Clear Cache ---
            Column() {
              Text($r('app.string.data_clear_cache'))
                .fontSize(16)
                .fontColor($r('app.color.logout_red'))
                .textAlign(TextAlign.Center)
                .width('100%')
                .height(48)
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })

            Blank().height(40)
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_secondary'))
    }
    .hideTitleBar(true)
    .bindSheet($$this.showSizePicker, this.sizePickerSheet(), {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      backgroundColor: $r('app.color.background_secondary')
    })
  }

  @Builder
  sectionHeader(title: ResourceStr) {
    Text(title)
      .fontSize(13)
      .fontColor($r('app.color.text_secondary'))
      .margin({ left: 32, bottom: 6, top: 2 })
  }

  @Builder
  settingsIcon(icon: Resource, bgColor: ResourceColor) {
    Column() {
      Image(icon)
        .width(18).height(18)
        .fillColor($r('app.color.icon_on_primary'))
    }
    .width(28).height(28)
    .borderRadius(6)
    .backgroundColor(bgColor)
    .justifyContent(FlexAlign.Center)
    .margin({ right: 12 })
  }

  @Builder
  toggleRow(label: ResourceStr, isOn: boolean, onChange: (v: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor($r('app.color.telegram_blue'))
        .onChange(onChange)
        .accessibilityText($r('app.string.accessibility_toggle_auto_download'))
    }
    .width('100%').height(44)
    .padding({ left: 16, right: 16 })
  }

  @Builder
  expandableMediaRow(title: ResourceStr, summary: string, expanded: boolean, onTap: () => void) {
    Row() {
      Column() {
        Text(title)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
        Text(summary)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Image($r('app.media.ic_forward'))
        .width(14).height(14)
        .fillColor($r('app.color.text_secondary'))
        .rotate({ angle: expanded ? 90 : 0 })
        .animation({ duration: 200, curve: Curve.EaseInOut })
    }
    .width('100%').height(52)
    .padding({ left: 16, right: 16 })
    .onClick(onTap)
  }

  @Builder
  networkToggleRow(label: ResourceStr, isOn: boolean, onChange: (v: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor($r('app.color.telegram_blue'))
        .onChange(onChange)
        .accessibilityText($r('app.string.accessibility_toggle_auto_download'))
    }
    .width('100%').height(44)
    .padding({ left: 40, right: 16 })
  }

  @Builder
  sizeLimitRow(currentSize: number, onTap: () => void) {
    Row() {
      Text($r('app.string.data_max_size', this.formatSize(currentSize)))
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      Image($r('app.media.ic_forward'))
        .width(14).height(14)
        .fillColor($r('app.color.text_secondary'))
    }
    .width('100%').height(44)
    .padding({ left: 40, right: 16 })
    .onClick(onTap)
  }

  @Builder
  sizePickerSheet() {
    Column() {
      Text($r('app.string.data_max_size', ''))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 16, bottom: 12 })

      ForEach(SIZE_OPTIONS, (size: number, index: number) => {
        Column() {
          Row() {
            Text(SIZE_LABELS[index])
              .fontSize(16)
              .fontColor($r('app.color.text_primary'))
              .layoutWeight(1)

            if (this.isCurrentSize(size)) {
              Image($r('app.media.ic_forward'))
                .width(16).height(16)
                .fillColor($r('app.color.telegram_blue'))
            }
          }
          .width('100%').height(48)
          .padding({ left: 16, right: 16 })
          .onClick(() => { this.onSizeSelected(size); })

          if (index < SIZE_OPTIONS.length - 1) {
            Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
          }
        }
      }, (size: number) => size.toString())

      Blank().height(34)
    }
    .width('100%')
    .backgroundColor($r('app.color.glass_card_bg'))
    .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
    .borderRadius(16)
    .margin({ left: 16, right: 16 })
  }

  private isCurrentSize(size: number): boolean {
    if (this.sizePickerMediaType === 'videos') {
      return this.videosMaxSize === size;
    }
    return this.filesMaxSize === size;
  }

  private onSizeSelected(size: number): void {
    if (this.sizePickerMediaType === 'videos') {
      this.videosMaxSize = size;
      this.prefs.setAutoDownloadMaxSize('videos', size);
    } else {
      this.filesMaxSize = size;
      this.prefs.setAutoDownloadMaxSize('files', size);
    }
    this.showSizePicker = false;
    // Sync all network types after size change
    this.syncToTDLib('mobile');
    this.syncToTDLib('wifi');
    this.syncToTDLib('roaming');
  }

  private async resetAutoDownloadSettings(): Promise<void> {
    // Reset to defaults: Wi-Fi only, default sizes
    this.photosMobile = false;
    this.photosWifi = true;
    this.photosRoaming = false;

    this.videosMobile = false;
    this.videosWifi = true;
    this.videosRoaming = false;
    this.videosMaxSize = 15728640;

    this.filesMobile = false;
    this.filesWifi = true;
    this.filesRoaming = false;
    this.filesMaxSize = 1048576;

    // Collapse all sections
    this.photosExpanded = false;
    this.videosExpanded = false;
    this.filesExpanded = false;

    const p = this.prefs;

    // Persist defaults
    await p.setAutoDownloadEnabled('photos', 'mobile', false);
    await p.setAutoDownloadEnabled('photos', 'wifi', true);
    await p.setAutoDownloadEnabled('photos', 'roaming', false);

    await p.setAutoDownloadEnabled('videos', 'mobile', false);
    await p.setAutoDownloadEnabled('videos', 'wifi', true);
    await p.setAutoDownloadEnabled('videos', 'roaming', false);
    await p.setAutoDownloadMaxSize('videos', 15728640);

    await p.setAutoDownloadEnabled('files', 'mobile', false);
    await p.setAutoDownloadEnabled('files', 'wifi', true);
    await p.setAutoDownloadEnabled('files', 'roaming', false);
    await p.setAutoDownloadMaxSize('files', 1048576);

    // Sync to TDLib
    this.syncToTDLib('mobile');
    this.syncToTDLib('wifi');
    this.syncToTDLib('roaming');
  }
}

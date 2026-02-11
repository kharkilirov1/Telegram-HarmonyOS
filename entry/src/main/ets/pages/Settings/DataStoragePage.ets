// Data and Storage settings page
// Reference: Telegram iOS DataSettingsController, Android DataSettingsActivity

import { hilog } from '@kit.PerformanceAnalysisKit';
import { PreferencesService } from '../../services/PreferencesService';
import { ChatService } from '../../services/ChatService';
import { DataStorageActionCard } from './components/DataStorageActionCard';
import { DataStorageAutoDownloadSection } from './components/DataStorageAutoDownloadSection';
import { DataStorageDualToggleSection } from './components/DataStorageDualToggleSection';
import { DataStorageSizePickerSheet } from './components/DataStorageSizePickerSheet';
import { DataStorageStorageUsageSection } from './components/DataStorageStorageUsageSection';
import { DataStorageTopBar } from './components/DataStorageTopBar';

const SIZE_OPTIONS: number[] = [
  1048576,
  5242880,
  15728640,
  52428800,
  104857600,
  536870912,
  1610612736
];

const SIZE_LABELS: string[] = [
  '1 MB',
  '5 MB',
  '15 MB',
  '50 MB',
  '100 MB',
  '512 MB',
  '1.5 GB'
];

@Builder
export function DataStorageBuilder(name: string, param: Object) {
  DataStoragePage()
}

@ComponentV2
export struct DataStoragePage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();

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

  @Local photosExpanded: boolean = false;
  @Local videosExpanded: boolean = false;
  @Local filesExpanded: boolean = false;

  @Local autoPlayGifs: boolean = true;
  @Local autoPlayVideos: boolean = true;

  @Local saveIncoming: boolean = false;
  @Local saveEdited: boolean = false;

  @Local cacheSize: string = '256 MB';

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
    }
    if (bytes >= 1048576) {
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
        DataStorageTopBar({
          onBack: () => {
            this.navPathStack.pop();
          }
        })

        Scroll() {
          Column() {
            DataStorageStorageUsageSection({
              cacheSize: this.cacheSize,
              onOpenStorageUsage: () => {
              },
              onOpenNetworkUsage: () => {
              }
            })

            Blank().height(24)

            DataStorageAutoDownloadSection({
              photosSummary: this.getMediaSummary(this.photosMobile, this.photosWifi, this.photosRoaming),
              videosSummary: this.getMediaSummary(this.videosMobile, this.videosWifi, this.videosRoaming),
              filesSummary: this.getMediaSummary(this.filesMobile, this.filesWifi, this.filesRoaming),
              photosExpanded: this.photosExpanded,
              videosExpanded: this.videosExpanded,
              filesExpanded: this.filesExpanded,
              photosMobile: this.photosMobile,
              photosWifi: this.photosWifi,
              photosRoaming: this.photosRoaming,
              videosMobile: this.videosMobile,
              videosWifi: this.videosWifi,
              videosRoaming: this.videosRoaming,
              videosMaxSizeLabel: this.formatSize(this.videosMaxSize),
              filesMobile: this.filesMobile,
              filesWifi: this.filesWifi,
              filesRoaming: this.filesRoaming,
              filesMaxSizeLabel: this.formatSize(this.filesMaxSize),
              onTogglePhotosExpanded: () => {
                this.photosExpanded = !this.photosExpanded;
              },
              onToggleVideosExpanded: () => {
                this.videosExpanded = !this.videosExpanded;
              },
              onToggleFilesExpanded: () => {
                this.filesExpanded = !this.filesExpanded;
              },
              onPhotosMobileChange: (value: boolean) => {
                this.photosMobile = value;
                this.prefs.setAutoDownloadEnabled('photos', 'mobile', value);
                this.syncToTDLib('mobile');
              },
              onPhotosWifiChange: (value: boolean) => {
                this.photosWifi = value;
                this.prefs.setAutoDownloadEnabled('photos', 'wifi', value);
                this.syncToTDLib('wifi');
              },
              onPhotosRoamingChange: (value: boolean) => {
                this.photosRoaming = value;
                this.prefs.setAutoDownloadEnabled('photos', 'roaming', value);
                this.syncToTDLib('roaming');
              },
              onVideosMobileChange: (value: boolean) => {
                this.videosMobile = value;
                this.prefs.setAutoDownloadEnabled('videos', 'mobile', value);
                this.syncToTDLib('mobile');
              },
              onVideosWifiChange: (value: boolean) => {
                this.videosWifi = value;
                this.prefs.setAutoDownloadEnabled('videos', 'wifi', value);
                this.syncToTDLib('wifi');
              },
              onVideosRoamingChange: (value: boolean) => {
                this.videosRoaming = value;
                this.prefs.setAutoDownloadEnabled('videos', 'roaming', value);
                this.syncToTDLib('roaming');
              },
              onFilesMobileChange: (value: boolean) => {
                this.filesMobile = value;
                this.prefs.setAutoDownloadEnabled('files', 'mobile', value);
                this.syncToTDLib('mobile');
              },
              onFilesWifiChange: (value: boolean) => {
                this.filesWifi = value;
                this.prefs.setAutoDownloadEnabled('files', 'wifi', value);
                this.syncToTDLib('wifi');
              },
              onFilesRoamingChange: (value: boolean) => {
                this.filesRoaming = value;
                this.prefs.setAutoDownloadEnabled('files', 'roaming', value);
                this.syncToTDLib('roaming');
              },
              onOpenVideosSizePicker: () => {
                this.sizePickerMediaType = 'videos';
                this.showSizePicker = true;
              },
              onOpenFilesSizePicker: () => {
                this.sizePickerMediaType = 'files';
                this.showSizePicker = true;
              }
            })

            Text($r('app.string.data_auto_download_hint'))
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .margin({ left: 32, top: 6 })

            Blank().height(12)

            DataStorageActionCard({
              label: $r('app.string.data_reset_settings'),
              textColor: $r('app.color.telegram_blue'),
              rowHeight: 44,
              onTap: () => {
                this.resetAutoDownloadSettings();
              }
            })

            Blank().height(24)

            DataStorageDualToggleSection({
              title: $r('app.string.data_auto_play'),
              firstLabel: $r('app.string.data_auto_play_gifs'),
              firstValue: this.autoPlayGifs,
              secondLabel: $r('app.string.data_auto_play_videos'),
              secondValue: this.autoPlayVideos,
              onFirstChange: (value: boolean) => {
                this.autoPlayGifs = value;
                this.prefs.setAutoPlayGifs(value);
              },
              onSecondChange: (value: boolean) => {
                this.autoPlayVideos = value;
                this.prefs.setAutoPlayVideos(value);
              }
            })

            Blank().height(24)

            DataStorageDualToggleSection({
              title: $r('app.string.data_save_gallery'),
              firstLabel: $r('app.string.data_save_incoming'),
              firstValue: this.saveIncoming,
              secondLabel: $r('app.string.data_save_edited'),
              secondValue: this.saveEdited,
              onFirstChange: (value: boolean) => {
                this.saveIncoming = value;
                this.prefs.setSaveIncomingPhotos(value);
              },
              onSecondChange: (value: boolean) => {
                this.saveEdited = value;
                this.prefs.setSaveEditedPhotos(value);
              }
            })

            Blank().height(24)

            DataStorageActionCard({
              label: $r('app.string.data_clear_cache'),
              textColor: $r('app.color.logout_red'),
              rowHeight: 48,
              onTap: () => {
              }
            })

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
  private sizePickerSheet() {
    DataStorageSizePickerSheet({
      title: $r('app.string.data_max_size', ''),
      sizeOptions: SIZE_OPTIONS,
      sizeLabels: SIZE_LABELS,
      currentSize: this.getCurrentPickerSize(),
      onSelectSize: (size: number) => {
        this.onSizeSelected(size);
      }
    })
  }

  private getCurrentPickerSize(): number {
    if (this.sizePickerMediaType === 'videos') {
      return this.videosMaxSize;
    }
    return this.filesMaxSize;
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
    this.syncToTDLib('mobile');
    this.syncToTDLib('wifi');
    this.syncToTDLib('roaming');
  }

  private async resetAutoDownloadSettings(): Promise<void> {
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

    this.photosExpanded = false;
    this.videosExpanded = false;
    this.filesExpanded = false;

    const p = this.prefs;

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

    this.syncToTDLib('mobile');
    this.syncToTDLib('wifi');
    this.syncToTDLib('roaming');
  }
}

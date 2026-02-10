@ComponentV2
export struct DataStorageAutoDownloadSection {
  @Param photosSummary: string = '';
  @Param videosSummary: string = '';
  @Param filesSummary: string = '';

  @Param photosExpanded: boolean = false;
  @Param videosExpanded: boolean = false;
  @Param filesExpanded: boolean = false;

  @Param photosMobile: boolean = false;
  @Param photosWifi: boolean = false;
  @Param photosRoaming: boolean = false;

  @Param videosMobile: boolean = false;
  @Param videosWifi: boolean = false;
  @Param videosRoaming: boolean = false;
  @Param videosMaxSizeLabel: string = '';

  @Param filesMobile: boolean = false;
  @Param filesWifi: boolean = false;
  @Param filesRoaming: boolean = false;
  @Param filesMaxSizeLabel: string = '';

  @Event onTogglePhotosExpanded: () => void = () => {};
  @Event onToggleVideosExpanded: () => void = () => {};
  @Event onToggleFilesExpanded: () => void = () => {};

  @Event onPhotosMobileChange: (value: boolean) => void = (_value: boolean) => {};
  @Event onPhotosWifiChange: (value: boolean) => void = (_value: boolean) => {};
  @Event onPhotosRoamingChange: (value: boolean) => void = (_value: boolean) => {};

  @Event onVideosMobileChange: (value: boolean) => void = (_value: boolean) => {};
  @Event onVideosWifiChange: (value: boolean) => void = (_value: boolean) => {};
  @Event onVideosRoamingChange: (value: boolean) => void = (_value: boolean) => {};

  @Event onFilesMobileChange: (value: boolean) => void = (_value: boolean) => {};
  @Event onFilesWifiChange: (value: boolean) => void = (_value: boolean) => {};
  @Event onFilesRoamingChange: (value: boolean) => void = (_value: boolean) => {};

  @Event onOpenVideosSizePicker: () => void = () => {};
  @Event onOpenFilesSizePicker: () => void = () => {};

  build() {
    Column() {
      Text($r('app.string.data_auto_download'))
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .margin({ left: 32, bottom: 6, top: 2 })

      Column() {
        this.expandableMediaRow(
          $r('app.string.data_auto_download_photos'),
          this.photosSummary,
          this.photosExpanded,
          () => {
            this.onTogglePhotosExpanded();
          }
        )

        if (this.photosExpanded) {
          Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

          this.networkToggleRow($r('app.string.data_mobile_data'), this.photosMobile, (value: boolean) => {
            this.onPhotosMobileChange(value);
          })
          Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 40 })

          this.networkToggleRow($r('app.string.data_wifi'), this.photosWifi, (value: boolean) => {
            this.onPhotosWifiChange(value);
          })
          Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 40 })

          this.networkToggleRow($r('app.string.data_roaming'), this.photosRoaming, (value: boolean) => {
            this.onPhotosRoamingChange(value);
          })
        }

        Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

        this.expandableMediaRow(
          $r('app.string.data_auto_download_videos'),
          this.videosSummary,
          this.videosExpanded,
          () => {
            this.onToggleVideosExpanded();
          }
        )

        if (this.videosExpanded) {
          Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

          this.networkToggleRow($r('app.string.data_mobile_data'), this.videosMobile, (value: boolean) => {
            this.onVideosMobileChange(value);
          })
          Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 40 })

          this.networkToggleRow($r('app.string.data_wifi'), this.videosWifi, (value: boolean) => {
            this.onVideosWifiChange(value);
          })
          Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 40 })

          this.networkToggleRow($r('app.string.data_roaming'), this.videosRoaming, (value: boolean) => {
            this.onVideosRoamingChange(value);
          })
          Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 40 })

          this.sizeLimitRow(this.videosMaxSizeLabel, () => {
            this.onOpenVideosSizePicker();
          })
        }

        Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

        this.expandableMediaRow(
          $r('app.string.data_auto_download_files'),
          this.filesSummary,
          this.filesExpanded,
          () => {
            this.onToggleFilesExpanded();
          }
        )

        if (this.filesExpanded) {
          Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

          this.networkToggleRow($r('app.string.data_mobile_data'), this.filesMobile, (value: boolean) => {
            this.onFilesMobileChange(value);
          })
          Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 40 })

          this.networkToggleRow($r('app.string.data_wifi'), this.filesWifi, (value: boolean) => {
            this.onFilesWifiChange(value);
          })
          Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 40 })

          this.networkToggleRow($r('app.string.data_roaming'), this.filesRoaming, (value: boolean) => {
            this.onFilesRoamingChange(value);
          })
          Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 40 })

          this.sizeLimitRow(this.filesMaxSizeLabel, () => {
            this.onOpenFilesSizePicker();
          })
        }
      }
      .width('100%')
      .backgroundColor($r('app.color.glass_card_bg'))
      .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
      .borderRadius(16)
      .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
      .margin({ left: 16, right: 16 })
    }
    .width('100%')
  }

  @Builder
  private expandableMediaRow(title: ResourceStr, summary: string, expanded: boolean, onTap: () => void) {
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
        .width(14)
        .height(14)
        .fillColor($r('app.color.text_secondary'))
        .rotate({ angle: expanded ? 90 : 0 })
        .animation({ duration: 200, curve: Curve.EaseInOut })
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      onTap();
    })
  }

  @Builder
  private networkToggleRow(label: ResourceStr, isOn: boolean, onChange: (value: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor($r('app.color.telegram_blue'))
        .onChange((value: boolean) => {
          onChange(value);
        })
        .accessibilityText($r('app.string.accessibility_toggle_auto_download'))
    }
    .width('100%')
    .height(44)
    .padding({ left: 40, right: 16 })
  }

  @Builder
  private sizeLimitRow(label: string, onTap: () => void) {
    Row() {
      Text($r('app.string.data_max_size', label))
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      Image($r('app.media.ic_forward'))
        .width(14)
        .height(14)
        .fillColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .height(44)
    .padding({ left: 40, right: 16 })
    .onClick(() => {
      onTap();
    })
  }
}

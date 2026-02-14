import { SettingsIconBadge } from './SettingsIconBadge';

@ComponentV2
export struct DataStorageStorageUsageSection {
  @Param cacheSize: string = '0 MB';

  @Event onOpenStorageUsage: () => void = () => {};
  @Event onOpenNetworkUsage: () => void = () => {};

  build() {
    Column() {
      Text($r('app.string.data_storage_usage_section'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ left: 32, bottom: 6, top: 2 })

      Column() {
        Row() {
          SettingsIconBadge({
            icon: $r('app.media.ic_document'),
            bgColor: $r('app.color.settings_icon_blue')
          })

          Column() {
            Text($r('app.string.data_storage_usage'))
              .fontSize(16)
              .fontColor($r('app.color.text_primary'))

            Text(this.cacheSize)
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Image($r('app.media.ic_forward'))
            .width(14)
            .height(14)
            .fillColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .height(52)
        .padding({ left: 16, right: 16 })
        .onClick(() => {
          this.onOpenStorageUsage();
        })
        .hoverEffect(HoverEffect.Highlight)
        .opacity(1.0)
        .stateStyles({
          pressed: {
            .opacity(0.6)
          },
          normal: {
            .opacity(1.0)
          }
        })

        Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 52 })

        Row() {
          SettingsIconBadge({
            icon: $r('app.media.ic_channel'),
            bgColor: $r('app.color.settings_icon_green')
          })

          Text($r('app.string.data_network_usage'))
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)

          Image($r('app.media.ic_forward'))
            .width(14)
            .height(14)
            .fillColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .onClick(() => {
          this.onOpenNetworkUsage();
        })
        .hoverEffect(HoverEffect.Highlight)
        .opacity(1.0)
        .stateStyles({
          pressed: {
            .opacity(0.6)
          },
          normal: {
            .opacity(1.0)
          }
        })
      }
      .width('100%')
      .backgroundColor($r('app.color.glass_card_bg'))
      .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
      .borderRadius(24)
      .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
      .margin({ left: 12, right: 12 })
    }
    .width('100%')
  }
}

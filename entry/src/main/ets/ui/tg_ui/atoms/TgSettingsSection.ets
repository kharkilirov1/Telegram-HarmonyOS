// TgSettingsSection — iOS insetGrouped settings section container (Phase E-2).
// V1 @Component to support @BuilderParam for slot content.

import { TgUiTokens } from '../tokens/TgUiTokens';

@Component
export struct TgSettingsSection {
  @Prop header: string = '';
  @Prop footer: string = '';

  @BuilderParam content: () => void = this.defaultContent;

  @Builder
  defaultContent() {
    // empty
  }

  build() {
    Column() {
      if (this.header.length > 0) {
        Text(this.header.toUpperCase())
          .fontSize(TgUiTokens.SETTINGS_SECTION_HEADER_SIZE)
          .fontColor(TgUiTokens.SETTINGS_SECTION_HEADER_COLOR)
          .width('100%')
          .padding({
            left: TgUiTokens.SETTINGS_SECTION_SIDE_INSET + TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SETTINGS_SECTION_HEADER_BOTTOM_GAP
          })
      }

      Column() {
        this.content()
      }
      .width('100%')
      .backgroundColor(TgUiTokens.SETTINGS_SECTION_BG)
      .borderRadius(TgUiTokens.SETTINGS_SECTION_RADIUS)
      .clip(true)
      .margin({
        left: TgUiTokens.SETTINGS_SECTION_SIDE_INSET,
        right: TgUiTokens.SETTINGS_SECTION_SIDE_INSET
      })

      if (this.footer.length > 0) {
        Text(this.footer)
          .fontSize(TgUiTokens.SETTINGS_SECTION_FOOTER_SIZE)
          .fontColor(TgUiTokens.SETTINGS_SECTION_FOOTER_COLOR)
          .width('100%')
          .padding({
            left: TgUiTokens.SETTINGS_SECTION_SIDE_INSET + TgUiTokens.SPACE_16,
            top: TgUiTokens.SETTINGS_SECTION_HEADER_BOTTOM_GAP
          })
      }
    }
    .width('100%')
    .margin({ top: TgUiTokens.SETTINGS_SECTION_TOP_GAP })
  }
}

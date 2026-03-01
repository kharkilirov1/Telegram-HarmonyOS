import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgCountrySectionHeader {
  @Param title: string = '';

  build() {
    Row() {
      Text(this.title)
        .fontSize(TgUiTokens.COUNTRY_SECTION_HEADER_TEXT_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(TgUiTokens.COUNTRY_SECTION_HEADER_TEXT_COLOR)
    }
    .width('100%')
    .height(TgUiTokens.COUNTRY_SECTION_HEADER_HEIGHT)
    .alignItems(VerticalAlign.Center)
    .padding({ left: TgUiTokens.COUNTRY_SECTION_HEADER_SIDE_INSET })
    .backgroundColor(TgUiTokens.COUNTRY_SECTION_HEADER_BG)
  }
}


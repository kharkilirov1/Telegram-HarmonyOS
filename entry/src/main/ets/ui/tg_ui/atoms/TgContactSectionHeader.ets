import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgContactSectionHeader {
  @Param title: string = '';
  @Param sectionHeight: number = TgUiTokens.CONTACT_SECTION_HEADER_HEIGHT;

  build() {
    Row() {
      Text(this.title)
        .fontSize(TgUiTokens.CONTACT_SECTION_HEADER_TEXT_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
    }
    .width('100%')
    .height(this.sectionHeight)
    .padding({
      left: TgUiTokens.CONTACT_SECTION_HEADER_SIDE_INSET,
      right: TgUiTokens.CONTACT_ROW_INDEXER_END_PADDING
    })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
  }
}

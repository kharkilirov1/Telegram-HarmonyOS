import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgCountryRow {
  @Param flagEmoji: string = '';
  @Param countryName: string = '';
  @Param dialCode: string = '';
  @Param showSeparator: boolean = true;
  @Event onPress: () => void = (): void => {};

  build() {
    Column() {
      Row() {
        Text(this.flagEmoji)
          .fontSize(TgUiTokens.COUNTRY_ROW_FLAG_SIZE)
          .margin({ right: TgUiTokens.COUNTRY_ROW_FLAG_NAME_GAP })

        Text(this.countryName)
          .fontSize(TgUiTokens.COUNTRY_ROW_NAME_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.dialCode)
          .fontSize(TgUiTokens.COUNTRY_ROW_DIAL_CODE_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
      }
      .width('100%')
      .height(TgUiTokens.COUNTRY_ROW_HEIGHT)
      .alignItems(VerticalAlign.Center)
      .padding({
        left: TgUiTokens.COUNTRY_ROW_SIDE_INSET,
        right: TgUiTokens.COUNTRY_ROW_DIAL_CODE_END_INSET
      })
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
      .onClick(() => {
        this.onPress();
      })

      if (this.showSeparator) {
        Divider()
          .strokeWidth(TgUiTokens.COUNTRY_ROW_SEPARATOR_STROKE)
          .color(TgUiTokens.COLOR_SEPARATOR)
          .margin({ left: TgUiTokens.COUNTRY_ROW_SEPARATOR_INSET })
      }
    }
    .width('100%')
  }
}


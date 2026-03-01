// TgSearchBar — iOS-style inline search bar for chat list header (Phase D-2).
// Scrolls with list content: visible at top, hides behind translucent top bar on scroll.

import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgSearchBar {
  @Param placeholder: string = 'Search';

  @Event onTextChange: (text: string) => void = (_: string) => {};
  @Event onSubmit: (text: string) => void = (_: string) => {};

  build() {
    Row() {
      Search({ placeholder: this.placeholder })
        .searchIcon({
          src: TgUiTokens.ICON_RES_SEARCH,
          size: TgUiTokens.SEARCH_BAR_ICON_SIZE,
          color: TgUiTokens.SEARCH_BAR_ICON_COLOR
        })
        .cancelButton({
          style: CancelButtonStyle.INPUT
        })
        .searchButton('')
        .height(TgUiTokens.SEARCH_BAR_HEIGHT)
        .backgroundColor(TgUiTokens.SEARCH_BAR_BG)
        .borderRadius(TgUiTokens.SEARCH_BAR_RADIUS)
        .placeholderColor(TgUiTokens.SEARCH_BAR_PLACEHOLDER_COLOR)
        .placeholderFont({ size: TgUiTokens.SEARCH_BAR_FONT_SIZE })
        .textFont({ size: TgUiTokens.SEARCH_BAR_FONT_SIZE })
        .fontColor(TgUiTokens.SEARCH_BAR_TEXT_COLOR)
        .onChange((value: string) => {
          this.onTextChange(value);
        })
        .onSubmit((value: string) => {
          this.onSubmit(value);
        })
    }
    .width('100%')
    .padding({
      left: TgUiTokens.SEARCH_BAR_SIDE_INSET,
      right: TgUiTokens.SEARCH_BAR_SIDE_INSET,
      top: TgUiTokens.SEARCH_BAR_VERTICAL_INSET,
      bottom: TgUiTokens.SEARCH_BAR_VERTICAL_INSET
    })
  }
}

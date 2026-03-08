import { TgSearchBar } from '../atoms/TgSearchBar';
import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgSearchBarDemo {
  @Local private query: string = '';

  build() {
    Column({ space: TgUiTokens.SPACE_12 }) {
      TgSearchBar({
        placeholder: 'Search',
        onTextChange: (value: string): void => {
          this.query = value;
        },
        onSubmit: (value: string): void => {
          this.query = value;
        }
      })

      TgSearchBar({
        placeholder: 'Search chats, people, media and files'
      })

      Text(this.query.length > 0 ? 'Query: ' + this.query : 'Query: —')
        .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16 })

      Blank()
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
  }
}

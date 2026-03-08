import { TgTabBar } from '../atoms/TgTabBar';
import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgTabBarDemo {
  @Local private selectedIndex: number = 2;

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column({ space: TgUiTokens.SPACE_12 }) {
        Text('Tap tabs to preview active/inactive states and unread badge placement.')
          .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            top: TgUiTokens.SPACE_16
          })

        Blank()
          .layoutWeight(1)
      }
      .width('100%')
      .height('100%')

      TgTabBar({
        selectedIndex: this.selectedIndex,
        chatBadgeCount: 128,
        onTabSelect: (index: number): void => {
          this.selectedIndex = index;
        }
      })
      .margin({ bottom: TgUiTokens.SPACE_16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
  }
}

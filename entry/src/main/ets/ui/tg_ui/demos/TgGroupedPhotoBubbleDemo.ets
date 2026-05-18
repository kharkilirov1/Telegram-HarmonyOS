import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgGroupedPhotoBubble } from '../atoms/TgGroupedPhotoBubble';

@Preview({ title: 'TgGroupedPhotoBubble' })
@ComponentV2
export struct TgGroupedPhotoBubbleDemo {
  @Builder
  private caseBlock(label: string, isOutgoing: boolean, count: number,
    containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH) {
    Column({ space: TgUiTokens.SPACE_6 }) {
      Text(label)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .width('100%')

      TgGroupedPhotoBubble({
        photoPaths: new Array<string>(count).fill($r('app.media.app_icon') as string),
        photoWidths: new Array<number>(count).fill(1200),
        photoHeights: new Array<number>(count).fill(900),
        isOutgoing: isOutgoing,
        containerWidth: containerWidth
      })
    }
    .width('100%')
    .padding({
      left: TgUiTokens.SPACE_16,
      right: TgUiTokens.SPACE_16,
      top: TgUiTokens.SPACE_6,
      bottom: TgUiTokens.SPACE_6
    })
  }

  build() {
    Scroll() {
      Column() {
        Text('TgGroupedPhotoBubble Demo')
          .fontSize(TgUiTokens.FONT_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            top: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        this.caseBlock('01 incoming pair', false, 2)
        this.caseBlock('02 outgoing trio', true, 3)
        this.caseBlock('03 incoming four-up', false, 4)
        this.caseBlock('04 outgoing 5+ overlay', true, 5)
      }
      .width('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
  }
}

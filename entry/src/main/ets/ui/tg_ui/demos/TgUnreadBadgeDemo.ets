import { TgUnreadBadge } from '../atoms/TgUnreadBadge';
import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgUnreadBadgeDemo {
  @Builder
  private caseRow(label: string, count: number, isMuted: boolean = false, isDisabled: boolean = false) {
    Row() {
      Text(label)
        .layoutWeight(1)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
      TgUnreadBadge({
        count,
        isMuted,
        isDisabled
      })
    }
    .width('100%')
    .padding({
      left: TgUiTokens.SPACE_16,
      right: TgUiTokens.SPACE_16,
      top: TgUiTokens.SPACE_8,
      bottom: TgUiTokens.SPACE_8
    })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      Text('TgUnreadBadge Demo')
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

      Text('Rules: <=0 hidden, 1..99 exact, >=100 as 99+')
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        .width('100%')
        .padding({
          left: TgUiTokens.SPACE_16,
          right: TgUiTokens.SPACE_16,
          bottom: TgUiTokens.SPACE_8
        })

      this.caseRow('01 count=0 (hidden)', 0)
      this.caseRow('02 count=1', 1)
      this.caseRow('03 count=9', 9)
      this.caseRow('04 count=10', 10)
      this.caseRow('05 count=99', 99)
      this.caseRow('06 count=100 -> 99+', 100)
      this.caseRow('07 count=207 muted', 207, true)
      this.caseRow('08 count=2700 -> 99+', 2700)
      this.caseRow('09 disabled state', 9, false, true)

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
  }
}


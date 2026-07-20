import { TgRootTabUnreadBadge } from '../atoms/TgRootTabUnreadBadge';
import { TgUiTokens } from '../tokens/TgUiTokens';

@Preview({ title: 'TgRootTabUnreadBadge' })
@ComponentV2
export struct TgRootTabUnreadBadgeDemo {
  @Builder
  private badgeState(label: string, count: number) {
    Row() {
      Text(label)
        .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_PRIMARY)
        .layoutWeight(1)

      Stack() {
        SymbolGlyph($r('sys.symbol.ellipsis_message'))
          .fontSize(24)
          .fontColor([TgUiTokens.TAB_ITEM_UNSELECTED])
        TgRootTabUnreadBadge({ count })
          .position({
            x: TgUiTokens.TAB_BADGE_OFFSET_X,
            y: TgUiTokens.TAB_BADGE_OFFSET_Y
          })
      }
      .width(52)
      .height(36)
    }
    .width('100%')
    .height(52)
    .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16 })
  }

  build() {
    Column() {
      this.badgeState('Single digit', 1)
      this.badgeState('Two digits', 66)
      this.badgeState('Three digits', 999)
      this.badgeState('Compact thousand', 1000)
      this.badgeState('Decimal thousand', 2500)
      this.badgeState('Compact million', 1250000)
    }
    .width('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
  }
}

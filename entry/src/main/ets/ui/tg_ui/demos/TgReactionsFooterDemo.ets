// TgReactionsFooterDemo — state matrix for the reaction footer (S3b).
// No business logic: the demo feeds the same primitives the timeline row produces.

import { TgReactionsFooter } from '../atoms/TgReactionsFooter';
import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgReactionsFooterDemo {
  @Local bg: Resource = TgUiTokens.COLOR_BG_PRIMARY;

  @Builder
  private buildCase(title: string, emojis: string[], counts: number[], chosen: boolean[],
    hidden: number) {
    Column() {
      Text(title)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .margin({ bottom: TgUiTokens.SPACE_4 })
      TgReactionsFooter({
        emojis: emojis,
        counts: counts,
        chosenFlags: chosen,
        hiddenCount: hidden
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(TgUiTokens.SPACE_8)
    .backgroundColor(TgUiTokens.COLOR_MSG_BUBBLE_INCOMING_BG)
    .borderRadius(TgUiTokens.MSG_BUBBLE_RADIUS)
    .margin({ bottom: TgUiTokens.SPACE_8 })
  }

  build() {
    Scroll() {
      Column() {
        Text('TgReactionsFooter')
          .fontSize(TgUiTokens.FONT_TITLE_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .margin({ bottom: TgUiTokens.SPACE_8 })

        this.buildCase('no reactions (atom not rendered by the bubble)',
          [], [], [], 0)
        this.buildCase('one own reaction', ['👍'], [1], [true], 0)
        this.buildCase('several incoming reactions', ['🔥', '❤️', '👏'], [12, 7, 3],
          [false, false, false], 0)
        this.buildCase('own + incoming', ['👍', '🔥'], [4, 12], [true, false], 0)
        this.buildCase('overflow (6 visible + 4 hidden)',
          ['😁', '🔥', '👍', '❤️', '🎉', '👏'], [9, 8, 7, 6, 5, 4],
          [false, false, false, false, false, false], 4)
        this.buildCase('custom emoji fallback', [
          TgUiTokens.REACTION_CUSTOM_EMOJI_FALLBACK
        ], [2], [true], 0)
      }
      .width('100%')
      .padding(TgUiTokens.SPACE_8)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bg)
  }
}

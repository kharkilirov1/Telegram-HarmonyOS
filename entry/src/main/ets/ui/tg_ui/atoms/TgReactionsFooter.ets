// TgReactionsFooter — read-only row of reaction pills under a bubble (S3b).
//
// Data path: Message.reactions → ChatTimelineVO packs chips (chosen first, cap six) → this footer
// renders the visible pills plus "+N". Tapping, sending and the picker belong to S3c/S3d; the atom
// deliberately exposes no @Event yet so no interaction can look wired before the command exists.
//
// Reference: TelegramUI ChatMessageReactionsFooterContentNode — pills in a wrapping row, item
// spacing 6 pt, counts inside the pill; a chosen pill is tinted with the accent color.

import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgReactionsFooter {
  // Display glyphs for the visible chips, in the order the VO packed them.
  @Param emojis: string[] = [];
  // Chip keys in the same order; a tap reports the key so the controller never guesses the type.
  @Param keys: string[] = [];
  @Param counts: number[] = [];
  @Param chosenFlags: boolean[] = [];
  // Chips beyond the visible cap; rendered as "+N" so the row stays one line.
  @Param hiddenCount: number = 0;

  // S3c: tap toggles one chip; the controller performs the optimistic update and rollback.
  @Event onReactionPress: (key: string) => void = (_: string) => {};

  private hasChips(): boolean {
    return this.emojis.length > 0;
  }

  private chipBackground(index: number): Resource {
    return this.chosenFlags[index] ? TgUiTokens.REACTION_CHIP_BG_CHOSEN : TgUiTokens.REACTION_CHIP_BG;
  }

  private countColor(index: number): Resource {
    return this.chosenFlags[index] ? TgUiTokens.REACTION_CHIP_TEXT_CHOSEN : TgUiTokens.REACTION_CHIP_TEXT;
  }

  @Builder
  private buildChip(index: number) {
    Row() {
      Text(this.emojis[index])
        .fontSize(TgUiTokens.REACTION_CHIP_EMOJI_SIZE)
      Text(this.counts[index].toString())
        .fontSize(TgUiTokens.REACTION_CHIP_COUNT_SIZE)
        .fontWeight(TgUiTokens.REACTION_CHIP_COUNT_WEIGHT)
        .fontColor(this.countColor(index))
        .margin({ left: TgUiTokens.REACTION_CHIP_PADDING_H / 2 })
    }
    .height(TgUiTokens.REACTION_CHIP_HEIGHT)
    .padding({ left: TgUiTokens.REACTION_CHIP_PADDING_H, right: TgUiTokens.REACTION_CHIP_PADDING_H })
    .backgroundColor(this.chipBackground(index))
    .borderRadius(TgUiTokens.REACTION_CHIP_RADIUS)
    .margin({ right: TgUiTokens.REACTION_CHIP_GAP, bottom: TgUiTokens.REACTION_CHIP_GAP })
    .onClick(() => {
      const key = index < this.keys.length ? this.keys[index] : '';
      if (key.length > 0) {
        this.onReactionPress(key);
      }
    })
  }

  @Builder
  private buildOverflowChip() {
    Row() {
      Text('+' + this.hiddenCount.toString())
        .fontSize(TgUiTokens.REACTION_CHIP_COUNT_SIZE)
        .fontWeight(TgUiTokens.REACTION_CHIP_COUNT_WEIGHT)
        .fontColor(TgUiTokens.REACTION_CHIP_TEXT)
    }
    .height(TgUiTokens.REACTION_CHIP_HEIGHT)
    .padding({ left: TgUiTokens.REACTION_CHIP_PADDING_H, right: TgUiTokens.REACTION_CHIP_PADDING_H })
    .backgroundColor(TgUiTokens.REACTION_CHIP_BG)
    .borderRadius(TgUiTokens.REACTION_CHIP_RADIUS)
    .margin({ right: TgUiTokens.REACTION_CHIP_GAP, bottom: TgUiTokens.REACTION_CHIP_GAP })
  }

  build() {
    if (this.hasChips()) {
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.emojis, (emoji: string, index: number) => {
          this.buildChip(index)
        }, (emoji: string, index: number): string => emoji + index.toString())
        if (this.hiddenCount > 0) {
          this.buildOverflowChip()
        }
      }
      .width('100%')
      .margin({ top: TgUiTokens.REACTION_FOOTER_TOP_GAP })
    }
  }
}

// Custom emoji chips cannot render yet (D16); the footer shows the neutral placeholder from tokens
// rather than an empty pill, so the count and the chosen state stay readable.
export function reactionFooterGlyph(emoji: string, customEmojiId: string): string {
  if (emoji.length > 0) {
    return emoji;
  }
  return customEmojiId !== '0' ? TgUiTokens.REACTION_CUSTOM_EMOJI_FALLBACK : '';
}

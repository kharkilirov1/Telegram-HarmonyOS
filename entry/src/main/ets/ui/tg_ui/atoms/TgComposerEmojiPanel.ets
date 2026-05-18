// TgComposerEmojiPanel — compact composer-owned emoji quick panel.
//
// This is the first safe slice of Telegram's emoji/sticker input mode:
// parent owns input-mode state, this atom only renders recent emoji and emits selections.

import { TgIcon } from './TgIcon';
import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';

const DEFAULT_COMPOSER_EMOJI: string[] = [
  '😀', '😂', '😍', '👍', '🙏', '🔥',
  '❤️', '🎉', '😎', '🥲', '👏', '🤔',
  '😅', '👌', '😭', '💯', '🤝', '✨'
];

@ComponentV2
export struct TgComposerEmojiPanel {
  @Param title: string = 'Recent';
  @Param stickersTitle: string = 'Stickers';
  @Param emojis: string[] = [];
  @Param glassMode: string = TgGlassPolicy.MODE_AUTO;

  @Event onEmojiSelected: (emoji: string) => void = (_: string) => {};
  @Event onStickerPress: () => void = () => {};

  private useBlur(): boolean {
    return TgGlassPolicy.shouldUseRealtimeBlurForMode(this.glassMode);
  }

  private panelBg(): ResourceColor {
    return this.useBlur() ? TgUiTokens.COMPOSER_CAPSULE_BG : TgUiTokens.COMPOSER_CAPSULE_FALLBACK_BG;
  }

  private panelBlurStyle(): BlurStyle {
    return TgGlassPolicy.composerBlurStyle();
  }

  private resolvedEmojis(): string[] {
    return this.emojis.length > 0 ? this.emojis : DEFAULT_COMPOSER_EMOJI;
  }

  private rowIndexes(): number[] {
    const columns = TgUiTokens.COMPOSER_EMOJI_COLUMNS;
    const count = Math.ceil(this.resolvedEmojis().length / columns);
    const rows: number[] = [];
    for (let i = 0; i < count; i++) {
      rows.push(i);
    }
    return rows;
  }

  private emojiRow(rowIndex: number): string[] {
    const columns = TgUiTokens.COMPOSER_EMOJI_COLUMNS;
    const start = rowIndex * columns;
    return this.resolvedEmojis().slice(start, start + columns);
  }

  @Builder
  private buildEmojiCell(emoji: string, _index: number) {
    Row() {
      Text(emoji)
        .fontSize(TgUiTokens.COMPOSER_EMOJI_TEXT_SIZE)
        .textAlign(TextAlign.Center)
    }
    .width(TgUiTokens.COMPOSER_EMOJI_CELL_SIZE)
    .height(TgUiTokens.COMPOSER_EMOJI_CELL_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(TgUiTokens.COMPOSER_EMOJI_CELL_RADIUS)
    .onClick(() => {
      this.onEmojiSelected(emoji);
    })
  }

  @Builder
  private buildStickerPill() {
    Row({ space: TgUiTokens.SPACE_4 }) {
      TgIcon({
        src: TgUiTokens.ICON_RES_STICKER,
        iconSize: TgUiTokens.FONT_META_SIZE,
        tintColor: TgUiTokens.COMPOSER_ACTION_ACTIVE
      })

      Text(this.stickersTitle)
        .fontSize(TgUiTokens.COMPOSER_EMOJI_HEADER_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(TgUiTokens.COMPOSER_ACTION_ACTIVE)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(TgUiTokens.COMPOSER_EMOJI_PILL_HEIGHT)
    .padding({
      left: TgUiTokens.COMPOSER_EMOJI_PILL_PADDING_H,
      right: TgUiTokens.COMPOSER_EMOJI_PILL_PADDING_H
    })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(TgUiTokens.COMPOSER_EMOJI_PILL_RADIUS)
    .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
    .onClick(() => {
      this.onStickerPress();
    })
  }

  build() {
    Column() {
      Column({ space: TgUiTokens.COMPOSER_EMOJI_PANEL_ROW_GAP }) {
        Row() {
          Text(this.title)
            .fontSize(TgUiTokens.COMPOSER_EMOJI_HEADER_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(TgUiTokens.COLOR_TEXT_META)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          this.buildStickerPill()
        }
        .width('100%')
        .height(TgUiTokens.COMPOSER_EMOJI_PANEL_HEADER_HEIGHT)
        .alignItems(VerticalAlign.Center)

        Column({ space: TgUiTokens.COMPOSER_EMOJI_CELL_GAP }) {
          ForEach(this.rowIndexes(), (rowIndex: number) => {
            Row({ space: TgUiTokens.COMPOSER_EMOJI_CELL_GAP }) {
              ForEach(this.emojiRow(rowIndex), (emoji: string, index: number) => {
                this.buildEmojiCell(emoji, rowIndex * TgUiTokens.COMPOSER_EMOJI_COLUMNS + index)
              }, (emoji: string, index: number) => `composer_emoji_${rowIndex}_${index}_${emoji}`)
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
          }, (rowIndex: number) => `composer_emoji_row_${rowIndex}`)
        }
        .width('100%')
      }
      .width('100%')
      .padding({
        left: TgUiTokens.COMPOSER_EMOJI_PANEL_PADDING,
        right: TgUiTokens.COMPOSER_EMOJI_PANEL_PADDING,
        top: TgUiTokens.COMPOSER_EMOJI_PANEL_PADDING,
        bottom: TgUiTokens.COMPOSER_EMOJI_PANEL_PADDING
      })
      .backgroundColor(this.panelBg())
      .backgroundBlurStyle(this.panelBlurStyle(), TgGlassPolicy.glassOptions())
      .borderRadius(TgUiTokens.COMPOSER_EMOJI_PANEL_RADIUS)
      .border({ width: TgUiTokens.COMPOSER_BORDER_WIDTH, color: TgUiTokens.COMPOSER_CAPSULE_BORDER })
      .clip(true)
    }
    .width('100%')
    .padding({
      left: TgUiTokens.COMPOSER_SIDE_INSET,
      right: TgUiTokens.COMPOSER_SIDE_INSET,
      bottom: TgUiTokens.COMPOSER_EMOJI_PANEL_TOP_GAP
    })
  }
}

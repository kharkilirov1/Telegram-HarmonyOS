import { TgComposerEmojiPanel } from '../atoms/TgComposerEmojiPanel';
import { TgComposerInput } from '../atoms/TgComposerInput';
import { TgUiTokens } from '../tokens/TgUiTokens';

@Preview({ title: 'TgComposerEmojiPanel' })
@ComponentV2
export struct TgComposerEmojiPanelDemo {
  @Local private draft: string = '';
  @Local private lastAction: string = 'none';

  private appendEmoji(emoji: string): void {
    this.draft = `${this.draft}${emoji}`;
    this.lastAction = `emoji ${emoji}`;
  }

  build() {
    Scroll() {
      Column({ space: TgUiTokens.SPACE_12 }) {
        Text('TgComposerEmojiPanel Demo')
          .fontSize(TgUiTokens.FONT_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .width('100%')

        Text(`Draft: ${this.draft.length > 0 ? this.draft : '(empty)'}`)
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .width('100%')

        Text(`Last action: ${this.lastAction}`)
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_META)
          .width('100%')

        Column() {
          TgComposerEmojiPanel({
            title: 'Recent',
            stickersTitle: 'Stickers',
            onEmojiSelected: (emoji: string): void => {
              this.appendEmoji(emoji);
            },
            onStickerPress: (): void => {
              this.lastAction = 'stickers';
            }
          })

          TgComposerInput({
            text: this.draft,
            placeholder: 'Message',
            onTextChange: (value: string): void => {
              this.draft = value;
            },
            onSendPress: (_text: string): void => {
              this.lastAction = 'send';
              this.draft = '';
            },
            onAttachPress: (): void => {
              this.lastAction = 'attach';
            },
            onEmojiPress: (): void => {
              this.lastAction = 'toggle emoji';
            },
            onVoicePress: (): void => {
              this.lastAction = 'voice';
            }
          })
        }
        .width('100%')
        .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
        .borderRadius(TgUiTokens.RADIUS_12)
        .padding({ top: TgUiTokens.SPACE_12, bottom: TgUiTokens.SPACE_12 })

        TgComposerEmojiPanel({
          title: 'Narrow recent',
          stickersTitle: 'Stickers',
          emojis: ['🙂', '😄', '😉', '😇', '😋', '🤗', '🤩', '😤', '🥳', '😴', '😬', '🙌'],
          onEmojiSelected: (emoji: string): void => {
            this.appendEmoji(emoji);
          },
          onStickerPress: (): void => {
            this.lastAction = 'stickers';
          }
        })
        .width(TgUiTokens.MSG_DEMO_NARROW_CONTAINER_WIDTH)
      }
      .width('100%')
      .padding({
        left: TgUiTokens.SPACE_16,
        right: TgUiTokens.SPACE_16,
        top: TgUiTokens.SPACE_16,
        bottom: TgUiTokens.SPACE_16
      })
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
  }
}

// TgReactionPickerDemo — state matrix for the reaction picker row (S3d).
// Feeds the same keys AppState.availableReactionKeys produces; no business logic here.

import { TgReactionPicker } from '../atoms/TgReactionPicker';
import { DEFAULT_QUICK_REACTION_KEYS } from '../../../core/model/AppState';
import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgReactionPickerDemo {
  @Local picked: string = '';

  @Builder
  private buildCase(title: string, keys: string[]) {
    Column() {
      Text(title)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .margin({ bottom: TgUiTokens.SPACE_4 })
      TgReactionPicker({
        keys: keys,
        onReactionPress: (key: string): void => {
          this.picked = key;
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: TgUiTokens.SPACE_8, bottom: TgUiTokens.SPACE_8 })
  }

  build() {
    Scroll() {
      Column() {
        Text('TgReactionPicker')
          .fontSize(TgUiTokens.FONT_TITLE_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .margin({ bottom: TgUiTokens.SPACE_8 })

        this.buildCase('chat allows all reactions (12 iOS defaults)', DEFAULT_QUICK_REACTION_KEYS)
        this.buildCase('chatAvailableReactionsSome', ['emoji:🔥', 'emoji:👍', 'emoji:🎉'])
        this.buildCase('custom emoji fallback', [
          TgUiTokens.REACTION_CUSTOM_EMOJI_FALLBACK, 'emoji:👍'
        ])
        this.buildCase('no reactions available (atom not rendered by the popup)', [])

        Text(this.picked.length > 0 ? 'picked: ' + this.picked : 'picked: —')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_META)
          .margin({ top: TgUiTokens.SPACE_8 })
      }
      .width('100%')
      .padding(TgUiTokens.SPACE_8)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
  }
}

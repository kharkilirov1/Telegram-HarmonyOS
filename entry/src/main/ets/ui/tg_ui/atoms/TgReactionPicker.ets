// TgReactionPicker — horizontal row of available reactions shown above message actions (S3d).
//
// Data comes from the chat-level available_reactions list (`availableReactionKeys`), so the picker
// never offers an emoji the server would reject. The atom reports the chip key; the chat page routes
// it to ChatReactionController, which owns the optimistic toggle and rollback.

import { TgUiTokens } from '../tokens/TgUiTokens';
import {
  prefetchReactionPickerEmoji,
  reactionPickerEmojiState,
  syncPickerPaths
} from '../state/ReactionPickerEmojiState';

@ComponentV2
export struct TgReactionPicker {
  // Chip keys in display order (already capped by AppState.availableReactionKeys).
  @Param keys: string[] = [];
  @Event onReactionPress: (key: string) => void = (_: string) => {};
  // Bumped by the resolver when a custom emoji file lands; reading it keeps the pills in sync.
  @Local private emojiRevision: number = 0;

  aboutToAppear(): void {
    this.syncCustomEmoji();
  }

  @Monitor('keys')
  onKeysChanged(): void {
    this.syncCustomEmoji();
  }

  private syncCustomEmoji(): void {
    if (this.keys.length === 0) {
      return;
    }
    syncPickerPaths(this.keys);
    this.emojiRevision = reactionPickerEmojiState.revision;
    prefetchReactionPickerEmoji(this.keys).then((filled: number): void => {
      if (filled > 0) {
        this.emojiRevision = reactionPickerEmojiState.revision;
      }
    }).catch((): void => {});
  }

  private customEmojiPath(key: string): string {
    // Touch the revision so a resolved file re-renders the pill.
    const revision = this.emojiRevision + reactionPickerEmojiState.revision;
    return revision >= 0 ? reactionPickerEmojiState.pathFor(key) : '';
  }

  @Builder
  private buildPill(key: string) {
    Row() {
      if (this.customEmojiPath(key).length > 0) {
        Image(this.customEmojiPath(key))
          .width(TgUiTokens.REACTION_PICKER_GLYPH_SIZE)
          .height(TgUiTokens.REACTION_PICKER_GLYPH_SIZE)
          .objectFit(ImageFit.Contain)
      } else {
        Text(reactionPickerGlyph(key))
          .fontSize(TgUiTokens.REACTION_PICKER_GLYPH_SIZE)
      }
    }
    .width(TgUiTokens.REACTION_PICKER_PILL_SIZE)
    .height(TgUiTokens.REACTION_PICKER_PILL_SIZE)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(TgUiTokens.REACTION_CHIP_BG)
    .borderRadius(TgUiTokens.REACTION_CHIP_RADIUS)
    .margin({ right: TgUiTokens.REACTION_CHIP_GAP })
    .onClick(() => {
      this.onReactionPress(key);
    })
  }

  build() {
    if (this.keys.length > 0) {
      Scroll() {
        Row() {
          ForEach(this.keys, (key: string) => {
            this.buildPill(key)
          }, (key: string): string => key)
        }
        .padding({ left: TgUiTokens.REACTION_PICKER_PADDING_H, right: TgUiTokens.REACTION_PICKER_PADDING_H })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .height(TgUiTokens.REACTION_PICKER_HEIGHT)
      .align(Alignment.Start)
    }
  }
}

// Chip key → glyph. Custom emoji have no renderable glyph yet (D16), so the picker shows the same
// neutral placeholder the footer uses instead of an empty pill.
export function reactionPickerGlyph(key: string): string {
  if (key.startsWith('emoji:')) {
    return key.substring('emoji:'.length);
  }
  if (key.startsWith('custom:')) {
    return TgUiTokens.REACTION_CUSTOM_EMOJI_FALLBACK;
  }
  return '';
}

// TgEntityKeyboardModeBar — Telegram entity-keyboard bottom mode switch.
//
// GIF, Stickers and Emoji are peer content modes in Telegram iOS. Sticker-pack
// groups belong to the independent top strip and must never be mixed into this
// control.

import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgIcon } from './TgIcon';

export type TgEntityKeyboardMode = 'gifs' | 'stickers' | 'emoji';

@ComponentV2
export struct TgEntityKeyboardModeBar {
  @Param activeMode: TgEntityKeyboardMode = 'stickers';
  @Param gifTitle: string = 'GIF';
  @Param stickersTitle: string = 'Stickers';
  @Param emojiTitle: string = 'Emoji';
  @Param settingsAccessibilityText: string = 'Sticker settings';
  @Param showSettings: boolean = true;

  @Event onModePress: (mode: TgEntityKeyboardMode) => void = (_: TgEntityKeyboardMode) => {};
  @Event onSettingsPress: () => void = () => {};

  private titleFor(mode: TgEntityKeyboardMode): string {
    if (mode === 'gifs') {
      return this.gifTitle;
    }
    if (mode === 'emoji') {
      return this.emojiTitle;
    }
    return this.stickersTitle;
  }

  @Builder
  private buildMode(mode: TgEntityKeyboardMode) {
    Row() {
      Text(this.titleFor(mode))
        .fontSize(TgUiTokens.ENTITY_KEYBOARD_MODE_TEXT_SIZE)
        .fontWeight(this.activeMode === mode ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.activeMode === mode ? TgUiTokens.COLOR_TEXT_TITLE : TgUiTokens.COLOR_TEXT_META)
        .maxLines(1)
    }
    .height(TgUiTokens.ENTITY_KEYBOARD_MODE_PILL_HEIGHT)
    .padding({
      left: TgUiTokens.ENTITY_KEYBOARD_MODE_ITEM_PADDING_H,
      right: TgUiTokens.ENTITY_KEYBOARD_MODE_ITEM_PADDING_H
    })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(TgUiTokens.ENTITY_KEYBOARD_MODE_PILL_RADIUS)
    .backgroundColor(this.activeMode === mode ? TgUiTokens.COLOR_BG_SECONDARY : Color.Transparent)
    .onClick(() => {
      if (this.activeMode !== mode) {
        this.onModePress(mode);
      }
    })
  }

  build() {
    Row() {
      Blank()
        .width(TgUiTokens.ENTITY_KEYBOARD_SETTINGS_SLOT_WIDTH)

      Row() {
        Row({ space: TgUiTokens.ENTITY_KEYBOARD_MODE_GAP }) {
          this.buildMode('gifs')
          this.buildMode('stickers')
          this.buildMode('emoji')
        }
        .height(TgUiTokens.ENTITY_KEYBOARD_MODE_PILL_HEIGHT)
        .borderRadius(TgUiTokens.ENTITY_KEYBOARD_MODE_PILL_RADIUS)
        .border({ width: TgUiTokens.COMPOSER_BORDER_WIDTH, color: TgUiTokens.COMPOSER_CAPSULE_BORDER })
      }
      .layoutWeight(1)
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)

      Row() {
        if (this.showSettings) {
          Row() {
            TgIcon({
              src: TgUiTokens.ICON_RES_SETTINGS,
              iconSize: TgUiTokens.ENTITY_KEYBOARD_SETTINGS_ICON_SIZE,
              tintColor: TgUiTokens.COLOR_ICON_SECONDARY
            })
          }
          .width(TgUiTokens.ENTITY_KEYBOARD_SETTINGS_BUTTON_SIZE)
          .height(TgUiTokens.ENTITY_KEYBOARD_SETTINGS_BUTTON_SIZE)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .borderRadius(TgUiTokens.ENTITY_KEYBOARD_SETTINGS_BUTTON_SIZE / 2)
          .border({ width: TgUiTokens.COMPOSER_BORDER_WIDTH, color: TgUiTokens.COMPOSER_CAPSULE_BORDER })
          .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
          .clip(true)
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.88 })
          .responseRegion({
            x: TgUiTokens.ENTITY_KEYBOARD_SETTINGS_RESPONSE_OFFSET,
            y: TgUiTokens.ENTITY_KEYBOARD_SETTINGS_RESPONSE_OFFSET,
            width: TgUiTokens.ENTITY_KEYBOARD_SETTINGS_RESPONSE_SIZE,
            height: TgUiTokens.ENTITY_KEYBOARD_SETTINGS_RESPONSE_SIZE
          })
          .accessibilityText(this.settingsAccessibilityText)
          .onClick(() => this.onSettingsPress())
        }
      }
      .width(TgUiTokens.ENTITY_KEYBOARD_SETTINGS_SLOT_WIDTH)
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(TgUiTokens.ENTITY_KEYBOARD_MODE_BAR_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }
}

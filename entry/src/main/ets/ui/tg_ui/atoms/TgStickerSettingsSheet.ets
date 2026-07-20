// TgStickerSettingsSheet — installed sticker packs shown from the entity keyboard.

import { TgUiTokens } from '../tokens/TgUiTokens';
import { StickerSetTabVO } from './TgComposerStickerPanel';

@ComponentV2
export struct TgStickerSettingsSheet {
  @Param packs: StickerSetTabVO[] = [];
  @Param installedTitle: string = 'Installed Sticker Packs';
  @Param emptyTitle: string = 'No installed sticker packs';

  private installedPacks(): StickerSetTabVO[] {
    return this.packs.filter((pack: StickerSetTabVO): boolean => {
      return pack.tabId !== 'recent' && pack.tabId !== 'favorites' && pack.tabId !== 'gifs';
    });
  }

  @Builder
  private buildThumb(pack: StickerSetTabVO) {
    Row() {
      if (pack.thumbUri.length > 0) {
        Image(pack.thumbUri)
          .width(TgUiTokens.STICKER_SETTINGS_THUMB_SIZE)
          .height(TgUiTokens.STICKER_SETTINGS_THUMB_SIZE)
          .objectFit(ImageFit.Contain)
      } else {
        Text(pack.fallbackEmoji.length > 0 ? pack.fallbackEmoji : '◌')
          .fontSize(TgUiTokens.STICKER_SETTINGS_FALLBACK_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_META)
      }
    }
    .width(TgUiTokens.STICKER_SETTINGS_THUMB_SIZE)
    .height(TgUiTokens.STICKER_SETTINGS_THUMB_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(TgUiTokens.STICKER_SETTINGS_THUMB_RADIUS)
    .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
    .clip(true)
  }

  @Builder
  private buildPack(pack: StickerSetTabVO, showSeparator: boolean) {
    Stack({ alignContent: Alignment.Bottom }) {
      Row({ space: TgUiTokens.SETTINGS_ROW_GAP }) {
        this.buildThumb(pack)

        Text(pack.title)
          .layoutWeight(1)
          .fontSize(TgUiTokens.SETTINGS_ROW_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height(TgUiTokens.STICKER_SETTINGS_ROW_HEIGHT)
      .padding({ left: TgUiTokens.SETTINGS_ROW_PADDING_H, right: TgUiTokens.SETTINGS_ROW_PADDING_H })

      if (showSeparator) {
        Divider()
          .strokeWidth(TgUiTokens.SETTINGS_ROW_SEPARATOR_STROKE)
          .color(TgUiTokens.COLOR_SEPARATOR)
          .margin({ left: TgUiTokens.SETTINGS_ROW_PADDING_H + TgUiTokens.STICKER_SETTINGS_THUMB_SIZE +
            TgUiTokens.SETTINGS_ROW_GAP })
      }
    }
    .width('100%')
    .height(TgUiTokens.STICKER_SETTINGS_ROW_HEIGHT)
  }

  build() {
    Column() {
      Text(this.installedTitle)
        .width('100%')
        .fontSize(TgUiTokens.STICKER_SETTINGS_SECTION_TITLE_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .padding({ left: TgUiTokens.SETTINGS_ROW_PADDING_H, right: TgUiTokens.SETTINGS_ROW_PADDING_H })
        .margin({ top: TgUiTokens.STICKER_SETTINGS_SECTION_TOP_GAP, bottom: TgUiTokens.SPACE_4 })

      if (this.installedPacks().length === 0) {
        Text(this.emptyTitle)
          .width('100%')
          .fontSize(TgUiTokens.STICKER_SETTINGS_EMPTY_TEXT_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_META)
          .textAlign(TextAlign.Center)
          .padding({ top: TgUiTokens.SPACE_16 + TgUiTokens.SPACE_8 })
      } else {
        List() {
          ForEach(this.installedPacks(), (pack: StickerSetTabVO, index: number) => {
            ListItem() {
              this.buildPack(pack, index < this.installedPacks().length - 1)
            }
          }, (pack: StickerSetTabVO): string => pack.tabId)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}

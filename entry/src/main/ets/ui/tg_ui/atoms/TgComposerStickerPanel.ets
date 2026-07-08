// TgComposerStickerPanel — recent-stickers grid for the composer input mode.
//
// Cells render static previews only (webp file, else thumbnail, else emoji):
// animating a whole grid of tgs/webm players would burn the main thread.
// Paths land asynchronously as downloads finish, hence the @Trace VO fields.

import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';

@ObservedV2
export class StickerCellVO {
  readonly stickerId: string;
  readonly remoteFileId: string;
  readonly fileId: number;
  readonly thumbFileId: number;
  readonly emoji: string;
  readonly isAnimated: boolean;
  readonly isVideo: boolean;
  readonly width: number;
  readonly height: number;
  @Trace pathUri: string = '';      // file:// URI of the sticker file (webp usable directly)
  @Trace thumbPathUri: string = ''; // file:// URI of the thumbnail

  constructor(stickerId: string, remoteFileId: string, fileId: number, thumbFileId: number,
    emoji: string, isAnimated: boolean, isVideo: boolean, width: number, height: number) {
    this.stickerId = stickerId;
    this.remoteFileId = remoteFileId;
    this.fileId = fileId;
    this.thumbFileId = thumbFileId;
    this.emoji = emoji;
    this.isAnimated = isAnimated;
    this.isVideo = isVideo;
    this.width = width;
    this.height = height;
  }

  previewUri(): string {
    // tgs/webm files are not renderable by Image — always prefer the thumbnail
    if (this.isAnimated || this.isVideo) {
      return this.thumbPathUri;
    }
    return this.pathUri.length > 0 ? this.pathUri : this.thumbPathUri;
  }
}

// One pack tab in the strip; 'recent' is a synthetic tab, real packs carry a set id.
@ObservedV2
export class StickerSetTabVO {
  readonly tabId: string;
  readonly title: string;
  readonly thumbFileId: number;
  readonly fallbackEmoji: string;
  @Trace thumbUri: string = '';

  constructor(tabId: string, title: string, thumbFileId: number, fallbackEmoji: string) {
    this.tabId = tabId;
    this.title = title;
    this.thumbFileId = thumbFileId;
    this.fallbackEmoji = fallbackEmoji;
  }
}

@ComponentV2
export struct TgComposerStickerPanel {
  @Param title: string = 'Stickers';
  @Param emojiTitle: string = 'Emoji';
  @Param items: StickerCellVO[] = [];
  @Param tabs: StickerSetTabVO[] = [];
  @Param activeTabId: string = 'recent';
  @Param isLoading: boolean = false;
  @Param glassMode: string = TgGlassPolicy.MODE_AUTO;

  @Event onStickerSelected: (item: StickerCellVO) => void = (_: StickerCellVO) => {};
  @Event onTabSelected: (tabId: string) => void = (_: string) => {};
  @Event onEmojiPress: () => void = () => {};

  private useBlur(): boolean {
    return TgGlassPolicy.shouldUseRealtimeBlurForMode(this.glassMode);
  }

  private panelBg(): ResourceColor {
    return this.useBlur() ? TgUiTokens.COMPOSER_CAPSULE_BG : TgUiTokens.COMPOSER_CAPSULE_FALLBACK_BG;
  }

  @Builder
  private buildCell(item: StickerCellVO) {
    Row() {
      if (item.previewUri().length > 0) {
        Image(item.previewUri())
          .width(TgUiTokens.COMPOSER_STICKER_CELL_SIZE)
          .height(TgUiTokens.COMPOSER_STICKER_CELL_SIZE)
          .objectFit(ImageFit.Contain)
          .interpolation(ImageInterpolation.High)
      } else {
        Text(item.emoji.length > 0 ? item.emoji : '❔')
          .fontSize(TgUiTokens.COMPOSER_STICKER_EMOJI_FALLBACK_SIZE)
          .textAlign(TextAlign.Center)
      }
    }
    .width(TgUiTokens.COMPOSER_STICKER_CELL_SIZE)
    .height(TgUiTokens.COMPOSER_STICKER_CELL_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(TgUiTokens.COMPOSER_EMOJI_CELL_RADIUS)
    .onClick(() => {
      this.onStickerSelected(item);
    })
  }

  @Builder
  private buildTab(tab: StickerSetTabVO) {
    Row() {
      if (tab.tabId === 'recent') {
        Text('🕘')
          .fontSize(TgUiTokens.COMPOSER_STICKER_TAB_EMOJI_SIZE)
      } else if (tab.thumbUri.length > 0) {
        Image(tab.thumbUri)
          .width(TgUiTokens.COMPOSER_STICKER_TAB_SIZE - 8)
          .height(TgUiTokens.COMPOSER_STICKER_TAB_SIZE - 8)
          .objectFit(ImageFit.Contain)
      } else if (tab.fallbackEmoji.length > 0) {
        Text(tab.fallbackEmoji)
          .fontSize(TgUiTokens.COMPOSER_STICKER_TAB_EMOJI_SIZE)
      } else {
        Text(tab.title.length > 0 ? tab.title.substring(0, 1) : '?')
          .fontSize(TgUiTokens.COMPOSER_EMOJI_HEADER_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_META)
      }
    }
    .width(TgUiTokens.COMPOSER_STICKER_TAB_SIZE)
    .height(TgUiTokens.COMPOSER_STICKER_TAB_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .borderRadius(TgUiTokens.COMPOSER_STICKER_TAB_RADIUS)
    .backgroundColor(this.activeTabId === tab.tabId
      ? TgUiTokens.COLOR_BG_SECONDARY
      : Color.Transparent)
    .onClick(() => {
      this.onTabSelected(tab.tabId);
    })
  }

  @Builder
  private buildTabStrip() {
    Scroll() {
      Row({ space: TgUiTokens.COMPOSER_STICKER_TAB_GAP }) {
        ForEach(this.tabs, (tab: StickerSetTabVO) => {
          this.buildTab(tab)
        }, (tab: StickerSetTabVO) => `sticker_tab_${tab.tabId}`)
      }
      .alignItems(VerticalAlign.Center)
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .align(Alignment.Start)
    .width('100%')
    .height(TgUiTokens.COMPOSER_STICKER_TAB_STRIP_HEIGHT)
  }

  @Builder
  private buildEmojiPill() {
    Row() {
      Text(this.emojiTitle)
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
      this.onEmojiPress();
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

          this.buildEmojiPill()
        }
        .width('100%')
        .height(TgUiTokens.COMPOSER_EMOJI_PANEL_HEADER_HEIGHT)
        .alignItems(VerticalAlign.Center)

        if (this.tabs.length > 0) {
          this.buildTabStrip()
        }

        if (this.items.length === 0) {
          Row() {
            Text(this.isLoading ? '…' : '—')
              .fontSize(TgUiTokens.COMPOSER_STICKER_EMOJI_FALLBACK_SIZE)
              .fontColor(TgUiTokens.COLOR_TEXT_META)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
        } else {
          Grid() {
            ForEach(this.items, (item: StickerCellVO) => {
              GridItem() {
                this.buildCell(item)
              }
            }, (item: StickerCellVO) => `sticker_cell_${item.stickerId}`)
          }
          .columnsTemplate('1fr 1fr 1fr 1fr')
          .columnsGap(TgUiTokens.COMPOSER_STICKER_CELL_GAP)
          .rowsGap(TgUiTokens.COMPOSER_STICKER_CELL_GAP)
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height(TgUiTokens.COMPOSER_STICKER_PANEL_HEIGHT)
      .padding({
        left: TgUiTokens.COMPOSER_EMOJI_PANEL_PADDING,
        right: TgUiTokens.COMPOSER_EMOJI_PANEL_PADDING,
        top: TgUiTokens.COMPOSER_EMOJI_PANEL_PADDING,
        bottom: TgUiTokens.COMPOSER_EMOJI_PANEL_PADDING
      })
      .backgroundColor(this.panelBg())
      .backgroundBlurStyle(TgGlassPolicy.composerBlurStyle(), TgGlassPolicy.glassOptions())
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

// TgAttachmentSheet — Telegram-style recent-media attachment surface.
//
// The component is UI-only: the page supplies real PhotoAsset URIs and the
// controller owns picker/permission behavior.

import { TgIcon } from './TgIcon';
import { TgUiTokens } from '../tokens/TgUiTokens';

@ObservedV2
export class TgAttachmentRecentItem {
  readonly uri: string;
  readonly displayName: string;
  readonly isVideo: boolean;

  constructor(uri: string, displayName: string, isVideo: boolean) {
    this.uri = uri;
    this.displayName = displayName;
    this.isVideo = isVideo;
  }
}

@ComponentV2
export struct TgAttachmentSheet {
  @Param items: TgAttachmentRecentItem[] = [];
  @Param isLoading: boolean = false;
  @Param categoryEnabled: boolean[] = [true, true, true, false, false, false];

  @Event onClose: () => void = () => {};
  @Event onRecentPress: (item: TgAttachmentRecentItem) => void = (_: TgAttachmentRecentItem) => {};
  @Event onCategoryPress: (index: number) => void = (_: number) => {};

  private categoryTitle(index: number): Resource {
    switch (index) {
      case 0:
        return $r('app.string.attach_gallery');
      case 1:
        return $r('app.string.attach_camera');
      case 2:
        return $r('app.string.attach_file');
      case 3:
        return $r('app.string.attach_location');
      case 4:
        return $r('app.string.attach_poll');
      default:
        return $r('app.string.attach_contact');
    }
  }

  private categoryIcon(index: number): Resource {
    switch (index) {
      case 0:
        return TgUiTokens.ICON_RES_PHOTO;
      case 1:
        return TgUiTokens.ICON_RES_CAMERA;
      case 2:
        return TgUiTokens.ICON_RES_DOCUMENT;
      case 3:
        return TgUiTokens.ICON_RES_LOCATION;
      case 4:
        return TgUiTokens.ICON_RES_POLL;
      default:
        return TgUiTokens.ICON_RES_CONTACT;
    }
  }

  private categoryIsEnabled(index: number): boolean {
    return index < this.categoryEnabled.length && this.categoryEnabled[index];
  }

  @Builder
  private buildGrabber() {
    Row()
      .width(TgUiTokens.ATTACHMENT_SHEET_GRABBER_WIDTH)
      .height(TgUiTokens.ATTACHMENT_SHEET_GRABBER_HEIGHT)
      .backgroundColor(TgUiTokens.COLOR_TEXT_META)
      .opacity(TgUiTokens.ATTACHMENT_SHEET_GRABBER_OPACITY)
      .borderRadius(TgUiTokens.ATTACHMENT_SHEET_GRABBER_HEIGHT / 2)
      .margin({
        top: TgUiTokens.ATTACHMENT_SHEET_GRABBER_TOP,
        bottom: TgUiTokens.ATTACHMENT_SHEET_GRABBER_BOTTOM
      })
  }

  @Builder
  private buildHeader() {
    Stack({ alignContent: Alignment.Center }) {
      Row() {
        Row() {
          TgIcon({
            src: TgUiTokens.ICON_RES_CLOSE,
            iconSize: TgUiTokens.ATTACHMENT_SHEET_CLOSE_ICON_SIZE,
            tintColor: TgUiTokens.COLOR_TEXT_TITLE
          })
        }
        .width(TgUiTokens.ATTACHMENT_SHEET_CLOSE_SIZE)
        .height(TgUiTokens.ATTACHMENT_SHEET_CLOSE_SIZE)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .borderRadius(TgUiTokens.ATTACHMENT_SHEET_CLOSE_SIZE / 2)
        .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
        .onClick(() => {
          this.onClose();
        })

        Blank()
      }
      .width('100%')

      Row({ space: TgUiTokens.ATTACHMENT_SHEET_TITLE_GAP }) {
        Text($r('app.string.sticker_packs_recent'))
          .fontSize(TgUiTokens.ATTACHMENT_SHEET_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .maxLines(1)

        SymbolGlyph($r('sys.symbol.chevron_down'))
          .fontSize(TgUiTokens.ATTACHMENT_SHEET_CHEVRON_SIZE)
          .fontColor([TgUiTokens.COLOR_TEXT_META])
      }
    }
    .width('100%')
    .height(TgUiTokens.ATTACHMENT_SHEET_HEADER_HEIGHT)
    .padding({
      left: TgUiTokens.ATTACHMENT_SHEET_SIDE_INSET,
      right: TgUiTokens.ATTACHMENT_SHEET_SIDE_INSET
    })
  }

  @Builder
  private buildRecentCell(item: TgAttachmentRecentItem) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Image(item.uri)
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .interpolation(ImageInterpolation.High)

      Row() {
        if (item.isVideo) {
          TgIcon({
            src: TgUiTokens.ICON_RES_VIDEO,
            iconSize: TgUiTokens.ATTACHMENT_SHEET_MEDIA_BADGE_ICON_SIZE,
            tintColor: Color.White
          })
        }
      }
      .width(TgUiTokens.ATTACHMENT_SHEET_MEDIA_BADGE_SIZE)
      .height(TgUiTokens.ATTACHMENT_SHEET_MEDIA_BADGE_SIZE)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .borderRadius(TgUiTokens.ATTACHMENT_SHEET_MEDIA_BADGE_SIZE / 2)
      .border({
        width: TgUiTokens.ATTACHMENT_SHEET_MEDIA_BADGE_BORDER,
        color: Color.White
      })
      .backgroundColor(item.isVideo ? 'rgba(0, 0, 0, 0.36)' : 'rgba(0, 0, 0, 0.08)')
      .margin({
        top: TgUiTokens.ATTACHMENT_SHEET_MEDIA_BADGE_MARGIN,
        right: TgUiTokens.ATTACHMENT_SHEET_MEDIA_BADGE_MARGIN
      })
    }
    .width('100%')
    .aspectRatio(1)
    .clip(true)
    .onClick(() => {
      this.onRecentPress(item);
    })
  }

  @Builder
  private buildRecentGrid() {
    if (this.items.length > 0) {
      Grid() {
        ForEach(this.items, (item: TgAttachmentRecentItem) => {
          GridItem() {
            this.buildRecentCell(item)
          }
        }, (item: TgAttachmentRecentItem) => item.uri)
      }
      .columnsTemplate('1fr 1fr 1fr')
      .columnsGap(TgUiTokens.ATTACHMENT_SHEET_GRID_GAP)
      .rowsGap(TgUiTokens.ATTACHMENT_SHEET_GRID_GAP)
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    } else {
      Column({ space: TgUiTokens.ATTACHMENT_SHEET_EMPTY_GAP }) {
        if (this.isLoading) {
          LoadingProgress()
            .width(TgUiTokens.ATTACHMENT_SHEET_LOADING_SIZE)
            .height(TgUiTokens.ATTACHMENT_SHEET_LOADING_SIZE)
            .color(TgUiTokens.COMPOSER_ACTION_ACTIVE)
        }
        Text(this.isLoading ? $r('app.string.loading') : $r('app.string.shared_media_no_items'))
          .fontSize(TgUiTokens.COMPOSER_TEXT_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_META)
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
  }

  @Builder
  private buildCategory(index: number) {
    Column({ space: TgUiTokens.ATTACHMENT_SHEET_CATEGORY_GAP }) {
      TgIcon({
        src: this.categoryIcon(index),
        iconSize: TgUiTokens.ATTACHMENT_SHEET_CATEGORY_ICON_SIZE,
        tintColor: index === 0 ? TgUiTokens.COMPOSER_ACTION_ACTIVE : TgUiTokens.COLOR_TEXT_META
      })

      Text(this.categoryTitle(index))
        .fontSize(TgUiTokens.ATTACHMENT_SHEET_CATEGORY_TEXT_SIZE)
        .fontColor(index === 0 ? TgUiTokens.COMPOSER_ACTION_ACTIVE : TgUiTokens.COLOR_TEXT_META)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(TgUiTokens.ATTACHMENT_SHEET_CATEGORY_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(index === 0 ? TgUiTokens.ATTACHMENT_SHEET_ACTIVE_BG : Color.Transparent)
    .borderRadius(TgUiTokens.ATTACHMENT_SHEET_CATEGORY_RAIL_RADIUS)
    .opacity(this.categoryIsEnabled(index) ? 1 : TgUiTokens.ATTACHMENT_SHEET_DISABLED_OPACITY)
    .onClick(() => {
      if (this.categoryIsEnabled(index)) {
        this.onCategoryPress(index);
      }
    })
  }

  @Builder
  private buildCategoryRail() {
    Grid() {
        ForEach([0, 1, 2, 3, 4, 5], (index: number) => {
          GridItem() {
            this.buildCategory(index)
          }
        }, (index: number) => `attachment_category_${index}`)
    }
    .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr')
    .width('100%')
    .height(TgUiTokens.ATTACHMENT_SHEET_CATEGORY_RAIL_HEIGHT)
    .backgroundColor(TgUiTokens.COMPOSER_CAPSULE_FALLBACK_BG)
    .border({
      width: TgUiTokens.COMPOSER_BORDER_WIDTH,
      color: TgUiTokens.COMPOSER_CAPSULE_BORDER
    })
    .borderRadius(TgUiTokens.ATTACHMENT_SHEET_CATEGORY_RAIL_RADIUS)
    .margin({
      left: TgUiTokens.ATTACHMENT_SHEET_SIDE_INSET,
      right: TgUiTokens.ATTACHMENT_SHEET_SIDE_INSET,
      bottom: TgUiTokens.ATTACHMENT_SHEET_BOTTOM_INSET
    })
  }

  build() {
    Column() {
      this.buildGrabber()
      this.buildHeader()
      this.buildRecentGrid()
      this.buildCategoryRail()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.ATTACHMENT_SHEET_BG)
  }
}

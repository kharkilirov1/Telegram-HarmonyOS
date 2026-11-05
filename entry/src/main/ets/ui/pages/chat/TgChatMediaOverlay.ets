// Extracted from TgChatScreenPage; layout and callback semantics are preserved.

import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { TgMediaGalleryPage } from '../../tg_ui/atoms/TgMediaGalleryPage';
import { ChatChromeState } from './ChatChromeState';
import { ChatMediaViewState } from './ChatMediaViewState';
import { ChatMediaOverlayPort } from './ChatScreenViewPorts';
import { localized } from '../../../core/utils/AppResource';
import { MediaGalleryItem } from '../../../models/MediaGalleryItem';
import { StickerPackInfo } from '../../../domain/usecases/stickerPack';
import { buildStickerPackGalleryItems, stickerPackStartIndex } from './StickerPackGalleryItems';

@ComponentV2
export struct TgChatMediaOverlay {
  @Require @Param chrome: ChatChromeState;
  @Require @Param media: ChatMediaViewState;
  @Require @Param bindings: ChatMediaOverlayPort;

  // F6: when the opened sticker belongs to a loaded pack, the viewer pages that pack.
  @Local private packGalleryItems: MediaGalleryItem[] = [];
  @Local private packGalleryIndex: number = -1;

  @Monitor('media.galleryCurrentIndex', 'media.stickerPackStickers', 'media.galleryItems')
  onGalleryIndexChange(): void {
    this.bindings.loadStickerPack();
    this.syncPackPaging();
  }

  private syncPackPaging(): void {
    const stickers = this.media.stickerPackStickers;
    if (stickers.length < 2) {
      this.packGalleryItems = [];
      this.packGalleryIndex = -1;
      return;
    }
    const current = this.media.galleryCurrentIndex;
    if (current < 0 || current >= this.media.galleryItems.length) {
      return;
    }
    if (this.media.galleryItems[current].type !== 'sticker') {
      this.packGalleryItems = [];
      this.packGalleryIndex = -1;
      return;
    }
    if (this.packGalleryItems.length > 0) {
      return;
    }
    const pack = new StickerPackInfo();
    pack.setId = this.media.stickerPackSetId;
    pack.stickers = stickers;
    this.packGalleryItems = buildStickerPackGalleryItems(pack);
    // The tapped sticker may not carry an id on the gallery item, so file identity picks the start.
    const tappedFileId = this.media.galleryItems[current].fileId;
    let start = 0;
    for (let index = 0; index < stickers.length; index += 1) {
      if (stickers[index].fileId > 0 && stickers[index].fileId === tappedFileId) {
        start = index;
        break;
      }
    }
    this.packGalleryIndex = start;
    this.media.stickerPackPagingIndex = start;
  }

  private galleryItems(): MediaGalleryItem[] {
    return this.packGalleryItems.length > 0 ? this.packGalleryItems : this.media.galleryItems;
  }

  private galleryStartIndex(): number {
    return this.packGalleryIndex >= 0 ? this.packGalleryIndex : this.media.galleryCurrentIndex;
  }

  @Builder
  private buildStickerPackCard() {
    if (this.media.stickerPackSetId !== '0') {
      Row() {
        Text(this.media.stickerPackTitle.length > 0 ? this.media.stickerPackTitle : '...')
          .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
          .fontColor(TgUiTokens.MEDIA_GALLERY_TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(this.media.stickerPackInstalled
          ? localized($r('app.string.sticker_pack_remove').id, 'Remove')
          : localized($r('app.string.sticker_pack_add').id, 'Add Stickers'))
          .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(TgUiTokens.CHAT_TOP_BAR_ACTION_FOREGROUND)
          .opacity(this.media.stickerPackBusy ? 0.5 : 1)
          .onClick(() => {
            if (!this.media.stickerPackBusy) {
              this.bindings.toggleStickerPackInstalled();
            }
          })
      }
      .width('100%')
      .height(TgUiTokens.TOP_BAR_HEIGHT)
      .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16 })
      .backgroundColor(TgUiTokens.MEDIA_GALLERY_PILL_BG)
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      TgMediaGalleryPage({
      mediaItems: this.galleryItems(),
      initialIndex: this.galleryStartIndex(),
      downloadStateVersion: this.media.pendingMediaDownloadVersion,
      statusBarHeight: Math.max(0, this.chrome.topBarTotalHeight - TgUiTokens.TOP_BAR_HEIGHT - TgUiTokens.TOP_BAR_BOTTOM_PADDING),
      onDismiss: (): void => {
        this.bindings.animateMediaGalleryState(false);
      },
      onIndexChange: (index: number): void => {
        if (this.packGalleryItems.length > 0) {
          this.packGalleryIndex = index;
          this.media.stickerPackPagingIndex = index;
          return;
        }
        this.bindings.handleGalleryIndexChange(index);
      },
      onDownloadRequest: (fileId: number): void => {
        this.bindings.requestMediaDownload(fileId);
      },
      onDownloadCancel: (fileId: number): void => {
        this.bindings.cancelMediaDownload(fileId);
      }
      })
      this.buildStickerPackCard()
    }
    .width('100%')
    .height('100%')
  }
}

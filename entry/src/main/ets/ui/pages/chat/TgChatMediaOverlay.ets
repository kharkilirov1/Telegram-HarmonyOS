// Extracted from TgChatScreenPage; layout and callback semantics are preserved.

import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { TgMediaGalleryPage } from '../../tg_ui/atoms/TgMediaGalleryPage';
import { ChatChromeState } from './ChatChromeState';
import { ChatMediaViewState } from './ChatMediaViewState';
import { ChatMediaOverlayPort } from './ChatScreenViewPorts';
import { localized } from '../../../core/utils/AppResource';

@ComponentV2
export struct TgChatMediaOverlay {
  @Require @Param chrome: ChatChromeState;
  @Require @Param media: ChatMediaViewState;
  @Require @Param bindings: ChatMediaOverlayPort;

  @Monitor('media.galleryCurrentIndex')
  onGalleryIndexChange(): void {
    this.bindings.loadStickerPack();
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
      mediaItems: this.media.galleryItems,
      initialIndex: this.media.galleryCurrentIndex,
      downloadStateVersion: this.media.pendingMediaDownloadVersion,
      statusBarHeight: Math.max(0, this.chrome.topBarTotalHeight - TgUiTokens.TOP_BAR_HEIGHT - TgUiTokens.TOP_BAR_BOTTOM_PADDING),
      onDismiss: (): void => {
        this.bindings.animateMediaGalleryState(false);
      },
      onIndexChange: (index: number): void => {
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

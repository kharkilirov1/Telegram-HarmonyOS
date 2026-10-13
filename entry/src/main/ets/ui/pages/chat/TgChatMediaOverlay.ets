// Extracted from TgChatScreenPage; layout and callback semantics are preserved.

import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { TgMediaGalleryPage } from '../../tg_ui/atoms/TgMediaGalleryPage';
import { ChatChromeState } from './ChatChromeState';
import { ChatMediaViewState } from './ChatMediaViewState';
import { ChatMediaOverlayPort } from './ChatScreenViewPorts';

@ComponentV2
export struct TgChatMediaOverlay {
  @Require @Param chrome: ChatChromeState;
  @Require @Param media: ChatMediaViewState;
  @Require @Param bindings: ChatMediaOverlayPort;

  build() {
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
  }
}

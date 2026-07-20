import { TgLinkPreviewBubble } from '../atoms/TgLinkPreviewBubble';
import { TgUiTokens } from '../tokens/TgUiTokens';

@Preview({ title: 'TgLinkPreviewBubble' })
@ComponentV2
export struct TgLinkPreviewBubbleDemo {
  @Builder
  private caseBlock(label: string, siteName: string, title: string, description: string,
    showLargeMedia: boolean = false, showMediaAboveDescription: boolean = false,
    isOutgoing: boolean = false, includeMedia: boolean = true) {
    Column({ space: TgUiTokens.SPACE_6 }) {
      Text(label)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
      TgLinkPreviewBubble({
        url: 'https://telegram.org/blog/example',
        displayUrl: 'telegram.org',
        siteName: siteName,
        title: title,
        description: description,
        photoPath: includeMedia ? $r('app.media.app_icon') : '',
        showLargeMedia: showLargeMedia,
        showMediaAboveDescription: showMediaAboveDescription,
        isOutgoing: isOutgoing,
        availableWidth: 280,
      })
    }
    .padding(TgUiTokens.SPACE_8)
    .backgroundColor(isOutgoing ? TgUiTokens.COLOR_MSG_BUBBLE_OUTGOING_BG
      : TgUiTokens.COLOR_MSG_BUBBLE_INCOMING_BG)
    .borderRadius(TgUiTokens.BUBBLE_RADIUS_INCOMING)
  }

  build() {
    Scroll() {
      Column({ space: TgUiTokens.SPACE_12 }) {
        this.caseBlock('small trailing media', 'Telegram', 'A compact article preview',
          'The title and description keep their hierarchy while the square poster stays on the trailing edge.')
        this.caseBlock('large media', 'Telegram Blog', 'Large visual preview',
          'Media follows the description for a regular large preview.', true)
        this.caseBlock('large media above description', 'Video', 'Media-first preview',
          'TDLib can explicitly place the large poster above the description.', true, true)
        this.caseBlock('text-only', '', 'No image is required',
          'The accent rail, URL fallback and typography remain stable without media.', false, false, false, false)
        this.caseBlock('outgoing', 'telegram.org', 'Outgoing preview',
          'The same hierarchy uses the outgoing bubble palette.', false, false, true)
      }
      .padding(TgUiTokens.SPACE_16)
      .width('100%')
    }
    .backgroundColor(TgUiTokens.COLOR_CHAT_WALLPAPER_BASE)
    .width('100%')
    .height('100%')
  }
}

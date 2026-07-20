import { TgMessageRouter } from '../molecules/TgMessageRouter';
import { TgUiTokens } from '../tokens/TgUiTokens';

@Preview({ title: 'TgMessageRouter' })
@ComponentV2
export struct TgMessageRouterDemo {
  @Builder
  private buildSection(title: string) {
    Text(title)
      .fontSize(TgUiTokens.FONT_META_SIZE)
      .fontColor(TgUiTokens.COLOR_TEXT_META)
      .width('100%')
      .padding({ left: TgUiTokens.SPACE_4 })
  }

  build() {
    Scroll() {
      Column({ space: TgUiTokens.SPACE_12 }) {
        this.buildSection('text')
        TgMessageRouter({
          contentType: 'text',
          text: 'Router fallback text bubble',
          containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
        })

        this.buildSection('broadcast channel: full-width text lane')
        TgMessageRouter({
          contentType: 'text',
          text: 'A long broadcast post uses the iOS full-width lane while preserving space for the trailing share action.',
          isBroadcastChannel: true,
          containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
        })

        this.buildSection('photo')
        TgMessageRouter({
          contentType: 'photo',
          photoPath: '',
          caption: 'Photo caption',
          photoWidth: 300,
          photoHeight: 220,
          containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
        })

        this.buildSection('video')
        TgMessageRouter({
          contentType: 'video',
          videoThumbPath: '',
          videoPath: '',
          videoDuration: 37,
          videoWidth: 280,
          videoHeight: 180,
          caption: 'Preview video',
          isOutgoing: true,
          containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
        })

        this.buildSection('document')
        TgMessageRouter({
          contentType: 'document',
          fileName: 'Telegram Design Brief.pdf',
          fileSize: 3_145_728,
          mimeType: 'application/pdf',
          containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
        })

        this.buildSection('voice')
        TgMessageRouter({
          contentType: 'voice',
          voiceDuration: 82,
          voiceWaveform: '1,3,4,6,8,7,5,4,3,5,7,8,6,4,2',
          isVoiceListened: true,
          isOutgoing: true,
          containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
        })

        this.buildSection('sticker')
        TgMessageRouter({
          contentType: 'sticker',
          stickerPath: '',
          stickerWidth: 160,
          stickerHeight: 160,
          containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
        })
      }
      .width('100%')
      .padding({
        left: TgUiTokens.SPACE_16,
        right: TgUiTokens.SPACE_16,
        top: TgUiTokens.SPACE_16,
        bottom: TgUiTokens.SPACE_16
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
  }
}

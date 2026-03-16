import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgInstantVideoBubble } from '../atoms/TgInstantVideoBubble';

@ComponentV2
export struct TgInstantVideoBubbleDemo {
  @Builder
  private caseBlock(label: string, thumb: string | Resource, videoPath: string | Resource = '',
    containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, durationSec: number = 17,
    isDownloadPending: boolean = false, downloadProgress: number = -1) {
    Column({ space: TgUiTokens.SPACE_6 }) {
      Text(label)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .width('100%')

      TgInstantVideoBubble({
        thumbnailPath: thumb,
        videoPath: videoPath,
        durationSec: durationSec,
        containerWidth: containerWidth,
        isDownloadPending: isDownloadPending,
        downloadProgress: downloadProgress
      })
    }
    .width('100%')
    .padding({
      left: TgUiTokens.SPACE_16,
      right: TgUiTokens.SPACE_16,
      top: TgUiTokens.SPACE_6,
      bottom: TgUiTokens.SPACE_6
    })
  }

  build() {
    Scroll() {
      Column() {
        Text('TgInstantVideoBubble Demo')
          .fontSize(TgUiTokens.FONT_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            top: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        this.caseBlock('01 downloaded — play overlay', $r('app.media.app_icon'), 'file://demo/video.mp4')
        this.caseBlock('02 not downloaded — download icon', $r('app.media.app_icon'))
        this.caseBlock('03 downloading 55% — radial ring', $r('app.media.app_icon'), '', TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, 24, true, 0.55)
        this.caseBlock('04 downloading indeterminate', $r('app.media.app_icon'), '', TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, 12, true, -1)
        this.caseBlock('05 placeholder / no preview', '')
        this.caseBlock('06 regular-width lane', $r('app.media.app_icon'), 'file://demo/video.mp4',
          TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH + 240, 64)
      }
      .width('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
  }
}

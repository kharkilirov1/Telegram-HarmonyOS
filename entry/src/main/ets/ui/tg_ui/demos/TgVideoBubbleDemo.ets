import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgVideoBubble } from '../atoms/TgVideoBubble';

@Preview({ title: 'TgVideoBubble' })
@ComponentV2
export struct TgVideoBubbleDemo {
  private shortCaption: string = 'Sunset timelapse';
  private longCaption: string = 'Длинная подпись для видео-bubble: проверка отступов, наложения play-кнопки и бейджа длительности, а также переноса текста в стиле Telegram iOS.';

  @Builder
  private caseBlock(label: string, isOutgoing: boolean, thumbnailPath: string | Resource, caption: string,
    durationSec: number, videoWidth: number, videoHeight: number,
    containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, useConstrainedContainer: boolean = false,
    videoPath: string | Resource = '', isDownloadPending: boolean = false, downloadProgress: number = -1,
    isShortVideo: boolean = false) {
    Column({ space: TgUiTokens.SPACE_6 }) {
      Text(label)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .width('100%')

      if (useConstrainedContainer) {
        Row() {
          TgVideoBubble({
            thumbnailPath: thumbnailPath,
            videoPath: videoPath,
            durationSec: durationSec,
            caption: caption,
            isOutgoing: isOutgoing,
            containerWidth: containerWidth,
            videoWidth: videoWidth,
            videoHeight: videoHeight,
            isDownloadPending: isDownloadPending,
            downloadProgress: downloadProgress,
            isShortVideo: isShortVideo
          })
          .width(containerWidth)
        }
        .width('100%')
      } else {
        TgVideoBubble({
          thumbnailPath: thumbnailPath,
          videoPath: videoPath,
          durationSec: durationSec,
          caption: caption,
          isOutgoing: isOutgoing,
          containerWidth: containerWidth,
          videoWidth: videoWidth,
          videoHeight: videoHeight,
          isDownloadPending: isDownloadPending,
          downloadProgress: downloadProgress,
          isShortVideo: isShortVideo
        })
      }
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
        Text('TgVideoBubble Demo')
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

        Text('Phase C.1 / Step 2: video preview bubble + download/fetch/play status + duration badge + optional caption')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        this.caseBlock('01 incoming 16:9 no caption', false, $r('app.media.app_icon'), '', 42, 1280, 720)
        this.caseBlock('02 outgoing short caption', true, $r('app.media.app_icon'), this.shortCaption, 135, 1280, 720)
        this.caseBlock('03 incoming vertical 9:16', false, $r('app.media.app_icon'), '', 65, 720, 1280)
        this.caseBlock('04 outgoing long caption', true, $r('app.media.app_icon'), this.longCaption, 250, 1280, 720)
        this.caseBlock('05 placeholder without thumbnail', false, '', '', 18, 0, 0)
        this.caseBlock('06 narrow container stress', false, $r('app.media.app_icon'), this.shortCaption, 301, 1280, 720,
          TgUiTokens.MSG_DEMO_NARROW_CONTAINER_WIDTH, true)
        this.caseBlock('07 remote video shows download status', false, $r('app.media.app_icon'), '', 42, 1280, 720)
        this.caseBlock('08 fetching video shows determinate ring + close icon', false, $r('app.media.app_icon'), '', 42, 1280, 720,
          TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, false, '', true, 0.42)
        this.caseBlock('09 local video switches to play status', false, $r('app.media.app_icon'), '', 42, 1280, 720,
          TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, false, 'file://demo-video.mp4')
        this.caseBlock('10 local short-video preview suppresses center play overlay', false, $r('app.media.app_icon'), '', 12, 720, 720,
          TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, false, 'file://demo-round.mp4', false, -1, true)
      }
      .width('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
  }
}

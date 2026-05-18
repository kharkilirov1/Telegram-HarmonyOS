import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgPhotoBubble } from '../atoms/TgPhotoBubble';

@Preview({ title: 'TgPhotoBubble' })
@ComponentV2
export struct TgPhotoBubbleDemo {
  private captionShort: string = 'Evening skyline';
  private captionLong: string = 'Это длинная подпись для проверки того, как caption ведет себя внутри медиа-bubble: перенос строк, отступы, и визуальная плотность в стиле Telegram iOS.';

  @Builder
  private caseBlock(label: string, isOutgoing: boolean, photoPath: string | Resource, caption: string,
    photoWidth: number, photoHeight: number, containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH,
    useConstrainedContainer: boolean = false, hasLocalPhoto: boolean = true, isDownloading: boolean = false,
    downloadProgress: number = -1) {
    Column({ space: TgUiTokens.SPACE_6 }) {
      Text(label)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .width('100%')

      if (useConstrainedContainer) {
        Row() {
          TgPhotoBubble({
            photoPath: photoPath,
            hasLocalPhoto: hasLocalPhoto,
            isDownloading: isDownloading,
            downloadProgress: downloadProgress,
            caption: caption,
            isOutgoing: isOutgoing,
            containerWidth: containerWidth,
            photoWidth: photoWidth,
            photoHeight: photoHeight
          })
          .width(containerWidth)
        }
        .width('100%')
      } else {
        TgPhotoBubble({
          photoPath: photoPath,
          hasLocalPhoto: hasLocalPhoto,
          isDownloading: isDownloading,
          downloadProgress: downloadProgress,
          caption: caption,
          isOutgoing: isOutgoing,
          containerWidth: containerWidth,
          photoWidth: photoWidth,
          photoHeight: photoHeight
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
        Text('TgPhotoBubble Demo')
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

        Text('Phase C.1 / Step 1: photo bubble geometry + optional caption')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        this.caseBlock('01 incoming 16:9 no caption', false, $r('app.media.app_icon'), '', 1280, 720)
        this.caseBlock('02 outgoing 16:9 short caption', true, $r('app.media.app_icon'), this.captionShort, 1280, 720)
        this.caseBlock('03 incoming vertical 3:4', false, $r('app.media.app_icon'), '', 900, 1200)
        this.caseBlock('04 outgoing long caption', true, $r('app.media.app_icon'), this.captionLong, 1280, 720)
        this.caseBlock('05 placeholder without file path', false, '', '', 0, 0,
          TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, false, false)
        this.caseBlock('06 narrow container stress', false, $r('app.media.app_icon'), this.captionShort,
          1280, 720, TgUiTokens.MSG_DEMO_NARROW_CONTAINER_WIDTH, true)
        this.caseBlock('07 remote thumbnail / download icon', false, $r('app.media.app_icon'), '',
          1280, 720, TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, false, false)
        this.caseBlock('08 fetching determinate / cancel icon', true, $r('app.media.app_icon'), this.captionShort,
          1280, 720, TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, false, false, true, 0.43)
        this.caseBlock('09 fetching indeterminate / cancel icon', false, '', '',
          0, 0, TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, false, false, true, -1)
      }
      .width('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
  }
}

import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgStickerView } from '../atoms/TgStickerView';

@ComponentV2
export struct TgStickerViewDemo {
  @Builder
  private caseBlock(label: string, isOutgoing: boolean, stickerPath: string | Resource, stickerWidth: number, stickerHeight: number,
    isAnimated: boolean = false, isVideo: boolean = false,
    containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, useConstrainedContainer: boolean = false) {
    Column({ space: TgUiTokens.SPACE_6 }) {
      Text(label)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .width('100%')

      if (useConstrainedContainer) {
        Row() {
          TgStickerView({
            stickerPath: stickerPath,
            isOutgoing: isOutgoing,
            isAnimatedSticker: isAnimated,
            isVideoSticker: isVideo,
            stickerWidth: stickerWidth,
            stickerHeight: stickerHeight,
            containerWidth: containerWidth
          })
          .width(containerWidth)
        }
        .width('100%')
      } else {
        TgStickerView({
          stickerPath: stickerPath,
          isOutgoing: isOutgoing,
          isAnimatedSticker: isAnimated,
          isVideoSticker: isVideo,
          stickerWidth: stickerWidth,
          stickerHeight: stickerHeight,
          containerWidth: containerWidth
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
        Text('TgStickerView Demo')
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

        Text('Phase C.1 / Step 5: sticker without bubble, transparent background, fixed-size constraints')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        this.caseBlock('01 incoming static square', false, $r('app.media.app_icon'), 512, 512)
        this.caseBlock('02 outgoing static wide', true, $r('app.media.app_icon'), 512, 420)
        this.caseBlock('03 incoming static tall', false, $r('app.media.app_icon'), 320, 520)
        this.caseBlock('04 outgoing animated sticker size', true, $r('app.media.app_icon'), 512, 512, true, false)
        this.caseBlock('05 incoming video-sticker size', false, $r('app.media.app_icon'), 512, 512, false, true)
        this.caseBlock('06 placeholder without path', false, '', 0, 0)
        this.caseBlock('07 narrow container stress', true, $r('app.media.app_icon'), 512, 512,
          false, false, TgUiTokens.MSG_DEMO_NARROW_CONTAINER_WIDTH, true)
      }
      .width('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
  }
}


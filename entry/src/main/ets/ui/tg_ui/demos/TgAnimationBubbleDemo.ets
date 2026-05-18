import { TgAnimationBubble } from '../atoms/TgAnimationBubble';
import { TgUiTokens } from '../tokens/TgUiTokens';

@Entry
@Preview({ title: 'TgAnimationBubble' })
@ComponentV2
struct TgAnimationBubbleDemo {
  build() {
    Scroll() {
      Column({ space: 16 }) {
        Text('TgAnimationBubble Demo')
          .fontSize(20).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Center)
          .margin({ top: 16, bottom: 8 })

        // 1. Placeholder — no preview, no file
        Text('1. Placeholder (no preview)')
          .fontSize(14).fontColor('#888').width('100%').padding({ left: 16 })
        TgAnimationBubble({
          isOutgoing: false,
          containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH,
          onAnimationTap: () => {},
          onDownloadToggle: () => {}
        })

        // 2. Preview only — not downloaded
        Text('2. Preview, not downloaded (incoming)')
          .fontSize(14).fontColor('#888').width('100%').padding({ left: 16 })
        TgAnimationBubble({
          thumbnailPath: $r('app.media.startIcon'),
          isOutgoing: false,
          animationWidth: 320,
          animationHeight: 240,
          containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH,
          onAnimationTap: () => {},
          onDownloadToggle: () => {}
        })

        // 3. Downloading — indeterminate
        Text('3. Downloading (indeterminate)')
          .fontSize(14).fontColor('#888').width('100%').padding({ left: 16 })
        TgAnimationBubble({
          thumbnailPath: $r('app.media.startIcon'),
          isOutgoing: false,
          animationWidth: 320,
          animationHeight: 240,
          isDownloadPending: true,
          downloadProgress: -1,
          containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH,
          onAnimationTap: () => {},
          onDownloadToggle: () => {}
        })

        // 4. Downloading — 45%
        Text('4. Downloading (45%)')
          .fontSize(14).fontColor('#888').width('100%').padding({ left: 16 })
        TgAnimationBubble({
          thumbnailPath: $r('app.media.startIcon'),
          isOutgoing: true,
          animationWidth: 320,
          animationHeight: 240,
          isDownloadPending: true,
          downloadProgress: 0.45,
          containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH,
          onAnimationTap: () => {},
          onDownloadToggle: () => {}
        })

        // 5. Local animation ready (outgoing)
        Text('5. Local animation (outgoing)')
          .fontSize(14).fontColor('#888').width('100%').padding({ left: 16 })
        TgAnimationBubble({
          animationPath: $r('app.media.startIcon'),
          isOutgoing: true,
          animationWidth: 320,
          animationHeight: 180,
          containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH,
          onAnimationTap: () => {},
          onDownloadToggle: () => {}
        })
      }
      .width('100%')
      .padding({ bottom: 32 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}

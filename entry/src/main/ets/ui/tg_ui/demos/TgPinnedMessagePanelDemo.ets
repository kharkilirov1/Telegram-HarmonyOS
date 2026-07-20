import { TgChatBackground } from '../atoms/TgChatBackground';
import { TgPinnedMessagePanel } from '../atoms/TgPinnedMessagePanel';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';
import { TgUiTokens } from '../tokens/TgUiTokens';

@Preview({ title: 'TgPinnedMessagePanel' })
@ComponentV2
export struct TgPinnedMessagePanelDemo {
  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      TgChatBackground({ showPattern: true })

      Scroll() {
        Column({ space: TgUiTokens.SPACE_12 }) {
          TgPinnedMessagePanel({
            title: 'Pinned Message',
            preview: 'One pinned text message'
          })

          TgPinnedMessagePanel({
            title: 'Pinned Message #1',
            preview: 'First of several pinned messages',
            index: 0,
            totalCount: 4
          })

          TgPinnedMessagePanel({
            title: 'Pinned Message #2',
            preview: 'Middle navigation-stripe state',
            index: 1,
            totalCount: 4
          })

          TgPinnedMessagePanel({
            title: 'Pinned Message #4',
            preview: 'Last navigation-stripe state',
            index: 3,
            totalCount: 4
          })

          TgPinnedMessagePanel({
            title: 'Pinned Photo',
            preview: 'Photo attachment with thumbnail',
            hasThumbnail: true,
            thumbnailSrc: $r('app.media.app_icon_transparent')
          })

          TgPinnedMessagePanel({
            title: 'Pinned Message with a long title that must ellipsize',
            preview: 'Long preview text must remain on one line without moving the trailing action'
          })

          TgPinnedMessagePanel({
            title: 'Fallback material',
            preview: 'Opaque fallback keeps the same geometry',
            glassMode: TgGlassPolicy.MODE_FALLBACK
          })
        }
        .width('100%')
        .padding({ top: TgUiTokens.SPACE_12, bottom: TgUiTokens.SPACE_12 })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}

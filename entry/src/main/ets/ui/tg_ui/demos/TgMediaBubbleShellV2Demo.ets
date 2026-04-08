import { TgMediaBubbleShellV2 } from '../atoms/TgMediaBubbleShellV2';
import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgMessageSendStatus } from '../atoms/TgMessageMeta';

@ComponentV2
export struct TgMediaBubbleShellV2Demo {
  private captionText: string = 'Caption should reserve space for inline meta instead of forcing a second meta row below the media.';

  @Builder
  private caseBlock(label: string, builder: () => void) {
    Column({ space: TgUiTokens.SPACE_6 }) {
      Text(label)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .width('100%')

      builder()
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
        Text('TgMediaBubbleShellV2 Demo')
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

        Text('Parallel visual-media shell rebuild: sender + reply + media + caption/meta rules')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        this.caseBlock('01 incoming photo no caption', () => {
          TgMediaBubbleShellV2({
            mediaKind: 'photo',
            timeText: '11:02',
            containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
          })
        })

        this.caseBlock('02 incoming photo with sender + reply + caption', () => {
          TgMediaBubbleShellV2({
            mediaKind: 'photo',
            showSenderName: true,
            senderName: 'Rose',
            senderColorHex: '#8544d6',
            showReplySnippet: true,
            replyAuthor: 'Alex',
            replyPreview: 'Photo',
            replyHasThumbnail: true,
            caption: this.captionText,
            timeText: '11:05',
            containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
          })
        })

        this.caseBlock('03 outgoing video with caption', () => {
          TgMediaBubbleShellV2({
            mediaKind: 'video',
            isOutgoing: true,
            caption: this.captionText,
            timeText: '11:09',
            sendStatus: TgMessageSendStatus.Read,
            containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
          })
        })

        this.caseBlock('04 incoming animation no caption', () => {
          TgMediaBubbleShellV2({
            mediaKind: 'animation',
            timeText: '11:14',
            containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
          })
        })

        this.caseBlock('05 outgoing album with caption', () => {
          TgMediaBubbleShellV2({
            mediaKind: 'photoAlbum',
            isOutgoing: true,
            caption: 'Album caption with inline meta reserve',
            albumPhotoPaths: ['', '', '', ''],
            timeText: '11:20',
            sendStatus: TgMessageSendStatus.Sent,
            containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
          })
        })
      }
      .width('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
  }
}

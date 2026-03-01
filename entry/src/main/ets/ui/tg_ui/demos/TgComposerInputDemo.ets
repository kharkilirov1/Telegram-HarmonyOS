import { TgComposerInput } from '../atoms/TgComposerInput';
import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgComposerInputDemo {
  @Builder
  private caseBlock(label: string, isDisabled: boolean = false,
    showAttach: boolean = true, showEmoji: boolean = true,
    showReply: boolean = false, containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH) {
    Column({ space: TgUiTokens.SPACE_6 }) {
      Text(label)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .width('100%')

      Row() {
        TgComposerInput({
          placeholder: 'Message',
          isDisabled: isDisabled,
          showAttachButton: showAttach,
          showEmojiButton: showEmoji,
          showReplySnippet: showReply,
          replyAuthor: 'Alex',
          replyPreview: 'Reply snippet in composer header',
          replyIsOutgoing: false,
          replyIsQuote: false,
          replyHasThumbnail: false,
          containerWidth: containerWidth,
          onSendPress: (text: string): void => {
            // Demo: no-op
          }
        })
        .width(containerWidth)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
      .borderRadius(TgUiTokens.RADIUS_8)
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
        Text('TgComposerInput Demo')
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

        Text('Phase F-1: real input + send to TDLib')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        this.caseBlock('01 default (type and send)')
        this.caseBlock('02 reply snippet shown', false, true, true, true)
        this.caseBlock('03 no attach button', false, false, true)
        this.caseBlock('04 no emoji button', false, true, false)
        this.caseBlock('05 disabled state', true)
        this.caseBlock('06 narrow container', false, true, true, false, TgUiTokens.MSG_DEMO_NARROW_CONTAINER_WIDTH)
        this.caseBlock('07 wide container', false, true, true, false, TgUiTokens.MSG_DEMO_WIDE_CONTAINER_WIDTH)
      }
      .width('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
  }
}

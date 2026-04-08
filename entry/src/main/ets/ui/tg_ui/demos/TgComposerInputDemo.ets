import { TgComposerInput } from '../atoms/TgComposerInput';
import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgComposerInputDemo {
  @Local private interactiveDraft: string = '';

  @Builder
  private caseBlock(label: string, isDisabled: boolean = false,
    showAttach: boolean = true,
    showReply: boolean = false,
    containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH,
    text: string = '',
    showEmoji: boolean = true,
    interactive: boolean = false) {
    Column({ space: TgUiTokens.SPACE_6 }) {
      Text(label)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .width('100%')

      Row() {
        TgComposerInput({
          text: interactive ? this.interactiveDraft : text,
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
          onTextChange: (value: string): void => {
            if (interactive) {
              this.interactiveDraft = value;
            }
          },
          onSendPress: (_text: string): void => {
            if (interactive) {
              this.interactiveDraft = '';
            }
          },
          onReplyCancelPress: (): void => {
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

  @Builder
  private editCaseBlock() {
    Column({ space: TgUiTokens.SPACE_6 }) {
      Text('05 edit mode snippet')
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .width('100%')

      Row() {
        TgComposerInput({
          text: 'Edited text here',
          placeholder: 'Message',
          showEditSnippet: true,
          editPreview: 'Original message that is being edited',
          containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH,
          onTextChange: (_value: string): void => {},
          onSendPress: (_text: string): void => {},
          onEditCancelPress: (): void => {}
        })
        .width(TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH)
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

        Text('iOS-style: attach circle + text capsule + action circle')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        this.caseBlock('01 empty idle (interactive)', false, true, false,
          TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, '', true, true)
        this.caseBlock('02 short text → send', false, true, false,
          TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, 'hello')
        this.caseBlock('03 multiline text', false, true, false,
          TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, 'First line\nSecond line\nThird line')
        this.caseBlock('04 reply snippet shown', false, true, true)
        this.editCaseBlock()
        this.caseBlock('06 no attach button', false, false)
        this.caseBlock('07 no emoji button', false, true, false,
          TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, 'No emoji lane', false)
        this.caseBlock('08 disabled state', true, true, false,
          TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, 'Disabled draft')
        this.caseBlock('09 narrow container', false, true, false,
          TgUiTokens.MSG_DEMO_NARROW_CONTAINER_WIDTH, 'Narrow width sample')
        this.caseBlock('10 wide container', false, true, false,
          TgUiTokens.MSG_DEMO_WIDE_CONTAINER_WIDTH, 'Wide width sample')
        this.caseBlock('11 long text send', false, true, false,
          TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH,
          'This longer composer sample checks that the unified capsule remains stable under a more telegram-like draft width.')
      }
      .width('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
  }
}

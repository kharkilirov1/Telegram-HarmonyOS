import { TgComposerInput } from '../atoms/TgComposerInput';
import { TgUiTokens } from '../tokens/TgUiTokens';

@Preview({ title: 'TgComposerInput' })
@ComponentV2
export struct TgComposerInputDemo {
  @Local private interactiveDraft: string = '';
  @Local private lastAuxAction: string = 'none';

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
            this.lastAuxAction = 'send';
          },
          onAttachPress: (): void => {
            this.lastAuxAction = 'attach';
          },
          onEmojiPress: (): void => {
            this.lastAuxAction = 'emoji';
          },
          onVoicePress: (): void => {
            this.lastAuxAction = 'voice';
          },
          onReplyCancelPress: (): void => {
            this.lastAuxAction = 'reply cancel';
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
          onSendPress: (_text: string): void => {
            this.lastAuxAction = 'edit send';
          },
          onAttachPress: (): void => {
            this.lastAuxAction = 'attach';
          },
          onEmojiPress: (): void => {
            this.lastAuxAction = 'emoji';
          },
          onVoicePress: (): void => {
            this.lastAuxAction = 'voice';
          },
          onEditCancelPress: (): void => {
            this.lastAuxAction = 'edit cancel';
          }
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

  @Builder
  private forwardCaseBlock() {
    Column({ space: TgUiTokens.SPACE_6 }) {
      Text('06 forward mode snippet')
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .width('100%')

      Row() {
        TgComposerInput({
          text: '',
          placeholder: 'Add a comment',
          showForwardSnippet: true,
          forwardTitle: 'Forwarded message',
          forwardPreview: 'Alex: Photo',
          containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH,
          onTextChange: (_value: string): void => {},
          onSendPress: (_text: string): void => {
            this.lastAuxAction = 'forward send';
          },
          onAttachPress: (): void => {
            this.lastAuxAction = 'attach';
          },
          onEmojiPress: (): void => {
            this.lastAuxAction = 'emoji';
          },
          onVoicePress: (): void => {
            this.lastAuxAction = 'voice';
          },
          onForwardCancelPress: (): void => {
            this.lastAuxAction = 'forward cancel';
          }
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

  @Builder
  private attachmentCaseBlock() {
    Column({ space: TgUiTokens.SPACE_6 }) {
      Text('07 selected attachment snippet')
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .width('100%')

      Row() {
        TgComposerInput({
          text: '',
          placeholder: 'Add a caption',
          showAttachmentSnippet: true,
          attachmentKind: 'photo',
          attachmentTitle: 'Photo',
          attachmentPreview: 'IMG_0042.JPG',
          containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH,
          onTextChange: (_value: string): void => {},
          onSendPress: (_text: string): void => {
            this.lastAuxAction = 'attachment send';
          },
          onAttachPress: (): void => {
            this.lastAuxAction = 'attach';
          },
          onEmojiPress: (): void => {
            this.lastAuxAction = 'emoji';
          },
          onVoicePress: (): void => {
            this.lastAuxAction = 'voice';
          },
          onAttachmentCancelPress: (): void => {
            this.lastAuxAction = 'attachment cancel';
          }
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

        Text('iOS-style: accessory panels + send dock inside text capsule; mic stays outside')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        Text(`Last composer action: ${this.lastAuxAction}`)
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_META)
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
        this.forwardCaseBlock()
        this.attachmentCaseBlock()
        this.caseBlock('08 no attach button', false, false)
        this.caseBlock('09 no emoji button', false, true, false,
          TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, 'No emoji lane', false)
        this.caseBlock('10 disabled state', true, true, false,
          TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, 'Disabled draft')
        this.caseBlock('11 narrow container', false, true, false,
          TgUiTokens.MSG_DEMO_NARROW_CONTAINER_WIDTH, 'Narrow width sample')
        this.caseBlock('12 wide container', false, true, false,
          TgUiTokens.MSG_DEMO_WIDE_CONTAINER_WIDTH, 'Wide width sample')
        this.caseBlock('13 long text send', false, true, false,
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

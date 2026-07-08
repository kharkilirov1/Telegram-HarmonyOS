// TgComposerInput — iOS Telegram-style glass composer bar
//
// iOS layout: [attach glass button] [text field glass capsule] [mic glass button].
// Accessory panels belong inside the text capsule above the input row.
// When text/forward content is sendable, the send action docks inside the text capsule.
// Text input is controlled by the screen, while the atom stays UI-only.

import { TgIcon } from './TgIcon';
import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';

@ComponentV2
export struct TgComposerInput {
  @Param text: string = '';
  @Param placeholder: string = 'Message';
  // TextArea keeps an internal buffer: a bare `text:` prop renders but typing
  // starts from the stale buffer (edit-prefill got wiped by the first key).
  // Two-way `!!` binding on a @Local mirror keeps prop and buffer in sync.
  @Local textBuffer: string = '';

  @Monitor('text')
  onTextParamChanged(_m: IMonitor): void {
    if (this.text !== this.textBuffer) {
      this.textBuffer = this.text;
    }
  }

  aboutToAppear(): void {
    this.textBuffer = this.text;
  }
  @Param isDisabled: boolean = false;
  @Param showAttachButton: boolean = true;
  @Param showEmojiButton: boolean = true;

  @Param showReplySnippet: boolean = false;
  @Param replyAuthor: string = '';
  @Param replyPreview: string = '';
  @Param replyIsOutgoing: boolean = false;
  @Param replyIsQuote: boolean = false;
  @Param replyHasThumbnail: boolean = false;

  @Param showEditSnippet: boolean = false;
  @Param editPreview: string = '';
  @Param showForwardSnippet: boolean = false;
  @Param forwardTitle: string = 'Forwarded message';
  @Param forwardPreview: string = '';
  @Param showAttachmentSnippet: boolean = false;
  @Param attachmentKind: string = 'document';
  @Param attachmentTitle: string = 'Attachment';
  @Param attachmentPreview: string = '';

  @Param containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
  @Param glassMode: string = TgGlassPolicy.MODE_AUTO;
  @Param bottomInset: number = 0;

  @Event onSendPress: (text: string) => void = (_: string) => {};
  @Event onTextChange: (text: string) => void = (_: string) => {};
  @Event onAttachPress: () => void = () => {};
  @Event onEmojiPress: () => void = () => {};
  @Event onVoicePress: () => void = () => {};
  @Event onReplyCancelPress: () => void = () => {};
  @Event onEditCancelPress: () => void = () => {};
  @Event onForwardCancelPress: () => void = () => {};
  @Event onAttachmentCancelPress: () => void = () => {};

  // Controls the TextArea so we can drop the soft keyboard when the emoji panel
  // opens (otherwise system keyboard and panel fight for the same space).
  private textController: TextAreaController = new TextAreaController();

  private hasText(): boolean {
    return this.text.trim().length > 0;
  }

  private hasPendingForward(): boolean {
    return this.showForwardSnippet;
  }

  private hasPendingAttachment(): boolean {
    return this.showAttachmentSnippet;
  }

  private canSend(): boolean {
    return (this.hasText() || this.hasPendingForward() || this.hasPendingAttachment()) && !this.isDisabled;
  }

  private hasAccessoryPanel(): boolean {
    return this.showForwardSnippet || this.showEditSnippet || this.showReplySnippet || this.showAttachmentSnippet;
  }

  private handleSend(): void {
    const trimmed = this.text.trim();
    if (trimmed.length === 0 && !this.showForwardSnippet && !this.showAttachmentSnippet) {
      return;
    }
    this.onSendPress(trimmed);
  }

  private useBlur(): boolean {
    return TgGlassPolicy.shouldUseRealtimeBlurForMode(this.glassMode);
  }

  private capsuleBg(): ResourceColor {
    return this.useBlur() ? TgUiTokens.COMPOSER_CAPSULE_BG : TgUiTokens.COMPOSER_CAPSULE_FALLBACK_BG;
  }

  private capsuleBlurStyle(): BlurStyle {
    return TgGlassPolicy.composerBlurStyle();
  }

  private resolvedReplyAuthor(): string {
    return this.replyAuthor.length > 0 ? this.replyAuthor : 'Reply';
  }

  private resolvedReplyPreview(): string {
    return this.replyPreview.length > 0 ? this.replyPreview : 'Message';
  }

  private replyTitleColor(): ResourceColor {
    return this.replyIsOutgoing ? TgUiTokens.REPLY_SNIPPET_TITLE_OUTGOING : TgUiTokens.REPLY_SNIPPET_TITLE_INCOMING;
  }

  private replyPreviewColor(): ResourceColor {
    return this.replyIsOutgoing ? TgUiTokens.REPLY_SNIPPET_PREVIEW_OUTGOING : TgUiTokens.REPLY_SNIPPET_PREVIEW_INCOMING;
  }

  private replyBarColor(): ResourceColor {
    return this.replyIsOutgoing ? TgUiTokens.REPLY_SNIPPET_BAR_OUTGOING : TgUiTokens.REPLY_SNIPPET_BAR_INCOMING;
  }

  private attachmentIcon(): Resource {
    switch (this.attachmentKind) {
      case 'photo':
        return TgUiTokens.ICON_RES_PHOTO;
      case 'video':
        return TgUiTokens.ICON_RES_VIDEO;
      default:
        return TgUiTokens.ICON_RES_DOCUMENT;
    }
  }

  @Builder
  private buildActionButton() {
    Row() {
      TgIcon({
        src: this.canSend() ? TgUiTokens.ICON_RES_SEND : TgUiTokens.ICON_RES_MIC,
        iconSize: TgUiTokens.COMPOSER_ICON_SIZE,
        tintColor: this.canSend()
          ? TgUiTokens.COLOR_AVATAR_PLACEHOLDER_TEXT
          : TgUiTokens.COMPOSER_ACTION_INACTIVE
      })
    }
    .width(TgUiTokens.COMPOSER_BUTTON_SIZE)
    .height(TgUiTokens.COMPOSER_BUTTON_SIZE)
    .flexShrink(0)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    // R1.5: плоская иконка микрофона; заливка остаётся только у активного send
    .backgroundColor(this.canSend() ? TgUiTokens.COMPOSER_ACTION_ACTIVE : Color.Transparent)
    .borderRadius(TgUiTokens.COMPOSER_BUTTON_SIZE / 2)
    .clip(true)
    .onClick(() => {
      if (this.isDisabled) {
        return;
      }
      if (this.canSend()) {
        this.handleSend();
      } else {
        this.onVoicePress();
      }
    })
  }

  @Builder
  private buildAccessorySeparator() {
    if (this.hasAccessoryPanel()) {
      Row() {}
        .width('100%')
        .height(TgUiTokens.COMPOSER_BORDER_WIDTH)
        .backgroundColor(TgUiTokens.COMPOSER_CAPSULE_BORDER)
    }
  }

  @Builder
  private buildAttachmentAccessoryPanel() {
    if (this.showAttachmentSnippet) {
      Row() {
        Row() {
          TgIcon({
            src: this.attachmentIcon(),
            iconSize: TgUiTokens.COMPOSER_REPLY_CLOSE_SIZE,
            tintColor: TgUiTokens.COMPOSER_ACTION_ACTIVE
          })
        }
        .width(TgUiTokens.COMPOSER_BUTTON_SIZE)
        .height(TgUiTokens.COMPOSER_BUTTON_SIZE)
        .flexShrink(0)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)

        Column({ space: TgUiTokens.COMPOSER_ACCESSORY_TEXT_GAP }) {
          Text(this.attachmentTitle)
            .fontSize(TgUiTokens.COMPOSER_TEXT_SIZE - 2)
            .fontWeight(FontWeight.Medium)
            .fontColor(TgUiTokens.COMPOSER_ACTION_ACTIVE)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (this.attachmentPreview.length > 0) {
            Text(this.attachmentPreview)
              .fontSize(TgUiTokens.COMPOSER_TEXT_SIZE - 2)
              .fontColor(TgUiTokens.COMPOSER_PLACEHOLDER)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Row() {
          TgIcon({
            src: TgUiTokens.ICON_RES_CLOSE,
            iconSize: TgUiTokens.COMPOSER_REPLY_CLOSE_SIZE,
            tintColor: TgUiTokens.COMPOSER_ACTION_INACTIVE
          })
        }
        .width(TgUiTokens.COMPOSER_BUTTON_SIZE)
        .height(TgUiTokens.COMPOSER_BUTTON_SIZE)
        .flexShrink(0)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .margin({ left: TgUiTokens.COMPOSER_REPLY_CLOSE_GAP })
        .onClick(() => {
          this.onAttachmentCancelPress();
        })
      }
      .width('100%')
      .constraintSize({ minHeight: TgUiTokens.COMPOSER_ACCESSORY_MIN_HEIGHT })
      .alignItems(VerticalAlign.Center)
      .padding({
        left: TgUiTokens.COMPOSER_ATTACH_LEFT_INSET,
        right: TgUiTokens.COMPOSER_ATTACH_LEFT_INSET
      })
    }
  }

  @Builder
  private buildEditAccessoryPanel() {
    if (this.showEditSnippet) {
      Row() {
        Row() {
          TgIcon({
            src: TgUiTokens.ICON_RES_EDIT,
            iconSize: TgUiTokens.COMPOSER_REPLY_CLOSE_SIZE,
            tintColor: TgUiTokens.COMPOSER_ACTION_ACTIVE
          })
        }
        .width(TgUiTokens.COMPOSER_BUTTON_SIZE)
        .height(TgUiTokens.COMPOSER_BUTTON_SIZE)
        .flexShrink(0)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)

        Column({ space: TgUiTokens.COMPOSER_ACCESSORY_TEXT_GAP }) {
          Text('Edit Message')
            .fontSize(TgUiTokens.COMPOSER_TEXT_SIZE - 2)
            .fontWeight(FontWeight.Medium)
            .fontColor(TgUiTokens.COMPOSER_ACTION_ACTIVE)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (this.editPreview.length > 0) {
            Text(this.editPreview)
              .fontSize(TgUiTokens.COMPOSER_TEXT_SIZE - 2)
              .fontColor(TgUiTokens.COMPOSER_PLACEHOLDER)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Row() {
          TgIcon({
            src: TgUiTokens.ICON_RES_CLOSE,
            iconSize: TgUiTokens.COMPOSER_REPLY_CLOSE_SIZE,
            tintColor: TgUiTokens.COMPOSER_ACTION_INACTIVE
          })
        }
        .width(TgUiTokens.COMPOSER_BUTTON_SIZE)
        .height(TgUiTokens.COMPOSER_BUTTON_SIZE)
        .flexShrink(0)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .margin({ left: TgUiTokens.COMPOSER_REPLY_CLOSE_GAP })
        .onClick(() => {
          this.onEditCancelPress();
        })
      }
      .width('100%')
      .constraintSize({ minHeight: TgUiTokens.COMPOSER_ACCESSORY_MIN_HEIGHT })
      .alignItems(VerticalAlign.Center)
      .padding({
        left: TgUiTokens.COMPOSER_ATTACH_LEFT_INSET,
        right: TgUiTokens.COMPOSER_ATTACH_LEFT_INSET
      })
    }
  }

  @Builder
  private buildForwardAccessoryPanel() {
    if (this.showForwardSnippet) {
      Row() {
        Row() {
          TgIcon({
            src: TgUiTokens.ICON_RES_FORWARD,
            iconSize: TgUiTokens.COMPOSER_REPLY_CLOSE_SIZE,
            tintColor: TgUiTokens.COMPOSER_ACTION_ACTIVE
          })
        }
        .width(TgUiTokens.COMPOSER_BUTTON_SIZE)
        .height(TgUiTokens.COMPOSER_BUTTON_SIZE)
        .flexShrink(0)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)

        Column({ space: TgUiTokens.COMPOSER_ACCESSORY_TEXT_GAP }) {
          Text(this.forwardTitle)
            .fontSize(TgUiTokens.COMPOSER_TEXT_SIZE - 2)
            .fontWeight(FontWeight.Medium)
            .fontColor(TgUiTokens.COMPOSER_ACTION_ACTIVE)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (this.forwardPreview.length > 0) {
            Text(this.forwardPreview)
              .fontSize(TgUiTokens.COMPOSER_TEXT_SIZE - 2)
              .fontColor(TgUiTokens.COMPOSER_PLACEHOLDER)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Row() {
          TgIcon({
            src: TgUiTokens.ICON_RES_CLOSE,
            iconSize: TgUiTokens.COMPOSER_REPLY_CLOSE_SIZE,
            tintColor: TgUiTokens.COMPOSER_ACTION_INACTIVE
          })
        }
        .width(TgUiTokens.COMPOSER_BUTTON_SIZE)
        .height(TgUiTokens.COMPOSER_BUTTON_SIZE)
        .flexShrink(0)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .margin({ left: TgUiTokens.COMPOSER_REPLY_CLOSE_GAP })
        .onClick(() => {
          this.onForwardCancelPress();
        })
      }
      .width('100%')
      .constraintSize({ minHeight: TgUiTokens.COMPOSER_ACCESSORY_MIN_HEIGHT })
      .alignItems(VerticalAlign.Center)
      .padding({
        left: TgUiTokens.COMPOSER_ATTACH_LEFT_INSET,
        right: TgUiTokens.COMPOSER_ATTACH_LEFT_INSET
      })
    }
  }

  @Builder
  private buildReplyAccessoryPanel() {
    if (this.showReplySnippet) {
      Row() {
        Row() {}
          .width(TgUiTokens.REPLY_SNIPPET_BAR_WIDTH)
          .height(TgUiTokens.REPLY_SNIPPET_TITLE_LINE_HEIGHT +
            TgUiTokens.COMPOSER_ACCESSORY_TEXT_GAP +
            TgUiTokens.REPLY_SNIPPET_PREVIEW_LINE_HEIGHT)
          .backgroundColor(this.replyBarColor())
          .borderRadius(TgUiTokens.REPLY_SNIPPET_BAR_RADIUS)
          .margin({ left: TgUiTokens.COMPOSER_TEXT_PADDING_LEFT })
          .flexShrink(0)

        Column({ space: TgUiTokens.COMPOSER_ACCESSORY_TEXT_GAP }) {
          Text(this.resolvedReplyAuthor())
            .fontSize(TgUiTokens.REPLY_SNIPPET_TITLE_SIZE)
            .fontWeight(TgUiTokens.REPLY_SNIPPET_TITLE_WEIGHT)
            .lineHeight(TgUiTokens.REPLY_SNIPPET_TITLE_LINE_HEIGHT)
            .fontColor(this.replyTitleColor())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Text(this.resolvedReplyPreview())
            .fontSize(TgUiTokens.REPLY_SNIPPET_PREVIEW_SIZE)
            .fontWeight(TgUiTokens.REPLY_SNIPPET_PREVIEW_WEIGHT)
            .lineHeight(TgUiTokens.REPLY_SNIPPET_PREVIEW_LINE_HEIGHT)
            .fontColor(this.replyPreviewColor())
            .maxLines(this.replyIsQuote ? TgUiTokens.REPLY_SNIPPET_QUOTE_MAX_PREVIEW_LINES : 1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .layoutWeight(1)
        .margin({ left: TgUiTokens.REPLY_SNIPPET_BAR_GAP })
        .alignItems(HorizontalAlign.Start)

        if (this.replyHasThumbnail) {
          Image($r('app.media.app_icon_transparent'))
            .width(TgUiTokens.REPLY_SNIPPET_THUMB_SIZE)
            .height(TgUiTokens.REPLY_SNIPPET_THUMB_SIZE)
            .objectFit(ImageFit.Cover)
            .borderRadius(TgUiTokens.REPLY_SNIPPET_THUMB_RADIUS)
            .clip(true)
            .margin({ left: TgUiTokens.REPLY_SNIPPET_THUMB_GAP })
        }

        Row() {
          TgIcon({
            src: TgUiTokens.ICON_RES_CLOSE,
            iconSize: TgUiTokens.COMPOSER_REPLY_CLOSE_SIZE,
            tintColor: TgUiTokens.COMPOSER_ACTION_INACTIVE
          })
        }
        .width(TgUiTokens.COMPOSER_BUTTON_SIZE)
        .height(TgUiTokens.COMPOSER_BUTTON_SIZE)
        .flexShrink(0)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .margin({ left: TgUiTokens.COMPOSER_REPLY_CLOSE_GAP })
        .onClick(() => {
          this.onReplyCancelPress();
        })
      }
      .width('100%')
      .constraintSize({ minHeight: TgUiTokens.COMPOSER_ACCESSORY_MIN_HEIGHT })
      .alignItems(VerticalAlign.Center)
      .padding({ right: TgUiTokens.COMPOSER_ATTACH_LEFT_INSET })
    }
  }

  build() {
    Column() {
      Row({ space: TgUiTokens.COMPOSER_ELEMENT_GAP }) {

        // ── Attach button (separate glass circle) ──
        if (this.showAttachButton) {
          Row() {
            TgIcon({
              src: TgUiTokens.ICON_RES_ATTACH,
              iconSize: TgUiTokens.COMPOSER_ICON_SIZE,
              tintColor: TgUiTokens.COMPOSER_ACTION_INACTIVE
            })
          }
          .width(TgUiTokens.COMPOSER_BUTTON_SIZE)
          .height(TgUiTokens.COMPOSER_BUTTON_SIZE)
          .flexShrink(0)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          // R1.5: плоская скрепка без капсулы
          .backgroundColor(Color.Transparent)
          .borderRadius(TgUiTokens.COMPOSER_BUTTON_SIZE / 2)
          .onClick(() => {
            if (!this.isDisabled) {
              this.onAttachPress();
            }
          })
        }

        // ── Text field capsule owns accessory panels + input row ──
        Column() {
          this.buildForwardAccessoryPanel()
          this.buildEditAccessoryPanel()
          this.buildReplyAccessoryPanel()
          this.buildAttachmentAccessoryPanel()
          this.buildAccessorySeparator()

          Row() {
            TextArea({ text: this.textBuffer!!, placeholder: this.placeholder, controller: this.textController })
              .style(TextContentStyle.INLINE)
              .fontSize(TgUiTokens.COMPOSER_TEXT_SIZE)
              .fontWeight(TgUiTokens.COMPOSER_TEXT_WEIGHT)
              .fontColor(TgUiTokens.COMPOSER_TEXT)
              .caretColor(TgUiTokens.COMPOSER_ACTION_ACTIVE)
              .placeholderColor(TgUiTokens.COMPOSER_PLACEHOLDER)
              .placeholderFont({
                size: TgUiTokens.COMPOSER_TEXT_SIZE,
                weight: TgUiTokens.COMPOSER_TEXT_WEIGHT
              })
              .backgroundColor(Color.Transparent)
              .borderRadius(0)
              .padding({
                top: TgUiTokens.COMPOSER_TEXT_PADDING_TOP,
                bottom: TgUiTokens.COMPOSER_TEXT_PADDING_BOTTOM,
                left: TgUiTokens.COMPOSER_TEXT_PADDING_LEFT,
                right: this.showEmojiButton ? 0 : TgUiTokens.COMPOSER_TEXT_PADDING_LEFT
              })
              .margin(0)
              .layoutWeight(1)
              .maxLines(TgUiTokens.COMPOSER_MAX_LINES)
              .onChange((value: string) => {
                this.onTextChange(value);
              })
              .onSubmit((enterKey: EnterKeyType, event?: SubmitEvent) => {
                if (enterKey === EnterKeyType.Send) {
                  event?.keepEditableState();
                  this.handleSend();
                }
              })
              .enterKeyType(EnterKeyType.Send)
              .enableKeyboardOnFocus(true)

            // Emoji button inside text capsule (right side, like iOS accessory)
            if (this.showEmojiButton) {
              Row() {
                TgIcon({
                  src: TgUiTokens.ICON_RES_EMOJI,
                  iconSize: TgUiTokens.COMPOSER_ICON_SIZE,
                  tintColor: TgUiTokens.COMPOSER_ACTION_INACTIVE
                })
              }
              .width(TgUiTokens.COMPOSER_BUTTON_SIZE)
              .height(TgUiTokens.COMPOSER_BUTTON_SIZE)
              .flexShrink(0)
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)
              .onClick(() => {
                if (!this.isDisabled) {
                  this.textController.stopEditing();
                  this.onEmojiPress();
                }
              })
            }

            if (this.canSend()) {
              this.buildActionButton()
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .constraintSize({ minHeight: TgUiTokens.COMPOSER_MIN_CAPSULE_HEIGHT })
          .padding({ left: TgUiTokens.COMPOSER_ATTACH_LEFT_INSET, right: TgUiTokens.COMPOSER_ATTACH_LEFT_INSET })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor(this.capsuleBg())
        .backgroundBlurStyle(this.capsuleBlurStyle(), TgGlassPolicy.glassOptions())
        .borderRadius(TgUiTokens.COMPOSER_CAPSULE_RADIUS)
        .border({ width: TgUiTokens.COMPOSER_BORDER_WIDTH, color: TgUiTokens.COMPOSER_CAPSULE_BORDER })
        .clip(true)

        // ── Mic button remains a separate glass circle on idle input ──
        if (!this.canSend()) {
          this.buildActionButton()
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
      .padding({
        left: TgUiTokens.COMPOSER_SIDE_INSET,
        right: TgUiTokens.COMPOSER_SIDE_INSET,
        top: TgUiTokens.COMPOSER_VERTICAL_INSET,
        bottom: TgUiTokens.COMPOSER_VERTICAL_INSET
      })
    }
    .width('100%')
    .padding({ bottom: this.bottomInset })
    .backgroundColor(Color.Transparent)
    .opacity(this.isDisabled ? TgUiTokens.COMPOSER_DISABLED_OPACITY : 1)
  }
}

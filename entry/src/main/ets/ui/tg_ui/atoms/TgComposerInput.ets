// TgComposerInput — iOS Telegram-style glass composer bar
//
// iOS layout: [attach glass button] [text field glass capsule] [send/mic glass button]
// Three separate glass elements, not one unified capsule.
// Text input is controlled by the screen, while the atom stays UI-only.

import { TgIcon } from './TgIcon';
import { TgReplySnippet } from './TgReplySnippet';
import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';

@ComponentV2
export struct TgComposerInput {
  @Param text: string = '';
  @Param placeholder: string = 'Message';
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

  @Param containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
  @Param glassMode: string = TgGlassPolicy.MODE_AUTO;
  @Param bottomInset: number = 0;

  @Event onSendPress: (text: string) => void = (_: string) => {};
  @Event onTextChange: (text: string) => void = (_: string) => {};
  @Event onReplyCancelPress: () => void = () => {};
  @Event onEditCancelPress: () => void = () => {};

  private hasText(): boolean {
    return this.text.trim().length > 0;
  }

  private canSend(): boolean {
    return this.hasText() && !this.isDisabled;
  }

  private handleSend(): void {
    const trimmed = this.text.trim();
    if (trimmed.length === 0) {
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

  @Builder
  private buildEditSnippet() {
    if (this.showEditSnippet) {
      Row() {
        // Edit icon + accent bar
        Row() {
          TgIcon({
            src: TgUiTokens.ICON_RES_EDIT,
            iconSize: TgUiTokens.COMPOSER_REPLY_CLOSE_SIZE,
            tintColor: TgUiTokens.COMPOSER_ACTION_ACTIVE,
            accessibilityText: 'Edit'
          })
        }
        .width(TgUiTokens.COMPOSER_BUTTON_SIZE)
        .height(TgUiTokens.COMPOSER_BUTTON_SIZE)
        .flexShrink(0)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)

        // Label + preview
        Column({ space: 2 }) {
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

        // Close button
        Row() {
          TgIcon({
            src: TgUiTokens.ICON_RES_CLOSE,
            iconSize: TgUiTokens.COMPOSER_REPLY_CLOSE_SIZE,
            tintColor: TgUiTokens.COMPOSER_ACTION_INACTIVE,
            accessibilityText: 'Cancel edit'
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
      .alignItems(VerticalAlign.Center)
      .padding({ left: TgUiTokens.COMPOSER_SIDE_INSET, right: TgUiTokens.COMPOSER_SIDE_INSET })
      .backgroundColor(this.capsuleBg())
      .backgroundBlurStyle(this.capsuleBlurStyle(), TgGlassPolicy.glassOptions())
      .borderRadius(TgUiTokens.COMPOSER_CAPSULE_RADIUS)
      .border({ width: TgUiTokens.COMPOSER_BORDER_WIDTH, color: TgUiTokens.COMPOSER_CAPSULE_BORDER })
      .clip(true)
    }
  }

  @Builder
  private buildReplySnippet() {
    if (this.showReplySnippet) {
      Row() {
        TgReplySnippet({
          author: this.replyAuthor,
          preview: this.replyPreview,
          isOutgoing: this.replyIsOutgoing,
          isQuote: this.replyIsQuote,
          hasThumbnail: this.replyHasThumbnail,
          containerWidth: this.containerWidth
        })
          .layoutWeight(1)

        Row() {
          TgIcon({
            src: TgUiTokens.ICON_RES_CLOSE,
            iconSize: TgUiTokens.COMPOSER_REPLY_CLOSE_SIZE,
            tintColor: TgUiTokens.COMPOSER_ACTION_INACTIVE,
            accessibilityText: 'Cancel reply'
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
      .alignItems(VerticalAlign.Center)
      .padding({ left: TgUiTokens.COMPOSER_SIDE_INSET, right: TgUiTokens.COMPOSER_SIDE_INSET })
      .backgroundColor(this.capsuleBg())
      .backgroundBlurStyle(this.capsuleBlurStyle(), TgGlassPolicy.glassOptions())
      .borderRadius(TgUiTokens.COMPOSER_CAPSULE_RADIUS)
      .border({ width: TgUiTokens.COMPOSER_BORDER_WIDTH, color: TgUiTokens.COMPOSER_CAPSULE_BORDER })
      .clip(true)
    }
  }

  build() {
    Column({ space: TgUiTokens.COMPOSER_REPLY_GAP }) {
      this.buildEditSnippet()
      this.buildReplySnippet()

      // Main row: [attach] [text capsule] [send/mic]
      Row({ space: TgUiTokens.COMPOSER_ELEMENT_GAP }) {

        // ── Attach button (separate glass circle) ──
        if (this.showAttachButton) {
          Row() {
            TgIcon({
              src: TgUiTokens.ICON_RES_ATTACH,
              iconSize: TgUiTokens.COMPOSER_ICON_SIZE,
              tintColor: TgUiTokens.COMPOSER_ACTION_INACTIVE,
              accessibilityText: 'Attach media'
            })
          }
          .width(TgUiTokens.COMPOSER_BUTTON_SIZE)
          .height(TgUiTokens.COMPOSER_BUTTON_SIZE)
          .flexShrink(0)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .backgroundColor(this.capsuleBg())
          .backgroundBlurStyle(this.capsuleBlurStyle(), TgGlassPolicy.glassOptions())
          .borderRadius(TgUiTokens.COMPOSER_BUTTON_SIZE / 2)
          .border({ width: TgUiTokens.COMPOSER_BORDER_WIDTH, color: TgUiTokens.COMPOSER_CAPSULE_BORDER })
          .clip(true)
        }

        // ── Text field (separate glass capsule) ──
        Row() {
          TextArea({ text: this.text, placeholder: this.placeholder })
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
                tintColor: TgUiTokens.COMPOSER_ACTION_INACTIVE,
                accessibilityText: 'Choose emoji'
              })
            }
            .width(TgUiTokens.COMPOSER_BUTTON_SIZE)
            .height(TgUiTokens.COMPOSER_BUTTON_SIZE)
            .flexShrink(0)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
          }
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center)
        .constraintSize({ minHeight: TgUiTokens.COMPOSER_MIN_CAPSULE_HEIGHT })
        .padding({ left: TgUiTokens.COMPOSER_ATTACH_LEFT_INSET, right: TgUiTokens.COMPOSER_ATTACH_LEFT_INSET })
        .backgroundColor(this.capsuleBg())
        .backgroundBlurStyle(this.capsuleBlurStyle(), TgGlassPolicy.glassOptions())
        .borderRadius(TgUiTokens.COMPOSER_CAPSULE_RADIUS)
        .border({ width: TgUiTokens.COMPOSER_BORDER_WIDTH, color: TgUiTokens.COMPOSER_CAPSULE_BORDER })
        .clip(true)

        // ── Send / Mic button (separate glass circle) ──
        Row() {
          TgIcon({
            src: this.canSend() ? TgUiTokens.ICON_RES_SEND : TgUiTokens.ICON_RES_MIC,
            iconSize: TgUiTokens.COMPOSER_ICON_SIZE,
            tintColor: this.canSend()
              ? TgUiTokens.COLOR_AVATAR_PLACEHOLDER_TEXT
              : TgUiTokens.COMPOSER_ACTION_INACTIVE,
            accessibilityText: this.canSend() ? 'Send message' : 'Record voice message'
          })
        }
        .width(TgUiTokens.COMPOSER_BUTTON_SIZE)
        .height(TgUiTokens.COMPOSER_BUTTON_SIZE)
        .flexShrink(0)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor(this.canSend() ? TgUiTokens.COMPOSER_ACTION_ACTIVE : this.capsuleBg())
        .backgroundBlurStyle(this.canSend() ? BlurStyle.NONE : this.capsuleBlurStyle(), TgGlassPolicy.glassOptions())
        .borderRadius(TgUiTokens.COMPOSER_BUTTON_SIZE / 2)
        .border({
          width: this.canSend() ? 0 : TgUiTokens.COMPOSER_BORDER_WIDTH,
          color: TgUiTokens.COMPOSER_CAPSULE_BORDER
        })
        .clip(true)
        .onClick(() => {
          this.handleSend();
        })
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

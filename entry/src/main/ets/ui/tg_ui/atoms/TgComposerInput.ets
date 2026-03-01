// TgComposerInput — message composer bar (Phase F-1)
// TextArea for real input + attach/emoji/send buttons + reply snippet

import { TgIcon } from './TgIcon';
import { TgReplySnippet } from './TgReplySnippet';
import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgComposerInput {
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

  @Param containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;

  @Event onSendPress: (text: string) => void = (_: string) => {};
  @Event onTextChange: (text: string) => void = (_: string) => {};
  @Event onReplyCancelPress: () => void = () => {};

  @Local private inputText: string = '';

  private hasText(): boolean {
    return this.inputText.trim().length > 0;
  }

  private canSend(): boolean {
    return this.hasText() && !this.isDisabled;
  }

  private actionIconRes(): Resource {
    return this.canSend() ? TgUiTokens.ICON_RES_SEND : TgUiTokens.ICON_RES_MIC;
  }

  private actionIconTint(): ResourceColor {
    return this.canSend() ? TgUiTokens.COLOR_AVATAR_PLACEHOLDER_TEXT : TgUiTokens.COMPOSER_ACTION_INACTIVE;
  }

  private actionBackgroundColor(): ResourceColor {
    return this.canSend() ? TgUiTokens.COMPOSER_ACTION_ACTIVE : Color.Transparent;
  }

  private composerOpacity(): number {
    return this.isDisabled ? TgUiTokens.COMPOSER_DISABLED_OPACITY : 1;
  }

  private handleSend(): void {
    const trimmed = this.inputText.trim();
    if (trimmed.length === 0) {
      return;
    }
    this.onSendPress(trimmed);
    this.inputText = '';
  }

  @Builder
  private buildAttachButton() {
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
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
  }

  @Builder
  private buildEmojiButton() {
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
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
  }

  @Builder
  private buildActionButton() {
    Row() {
      TgIcon({
        src: this.actionIconRes(),
        iconSize: TgUiTokens.COMPOSER_ICON_SIZE,
        tintColor: this.actionIconTint()
      })
    }
    .width(TgUiTokens.COMPOSER_BUTTON_SIZE)
    .height(TgUiTokens.COMPOSER_BUTTON_SIZE)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.actionBackgroundColor())
    .borderRadius(TgUiTokens.COMPOSER_BUTTON_SIZE / 2)
    .onClick(() => {
      this.handleSend();
    })
  }

  @Builder
  private buildTextInput() {
    TextArea({ text: this.inputText, placeholder: this.placeholder })
      .fontSize(TgUiTokens.COMPOSER_TEXT_SIZE)
      .fontWeight(TgUiTokens.COMPOSER_TEXT_WEIGHT)
      .fontColor(TgUiTokens.COMPOSER_TEXT)
      .placeholderColor(TgUiTokens.COMPOSER_PLACEHOLDER)
      .placeholderFont({ size: TgUiTokens.COMPOSER_TEXT_SIZE, weight: TgUiTokens.COMPOSER_TEXT_WEIGHT })
      .backgroundColor(Color.Transparent)
      .padding(0)
      .layoutWeight(1)
      .maxLines(TgUiTokens.COMPOSER_MAX_LINES)
      .onChange((value: string) => {
        this.inputText = value;
        this.onTextChange(value);
      })
      .onSubmit((enterKey: EnterKeyType) => {
        if (enterKey === EnterKeyType.Send) {
          this.handleSend();
        }
      })
      .enterKeyType(EnterKeyType.Send)
      .enableKeyboardOnFocus(true)
  }

  @Builder
  private buildReplySnippet() {
    if (this.showReplySnippet) {
      TgReplySnippet({
        author: this.replyAuthor,
        preview: this.replyPreview,
        isOutgoing: this.replyIsOutgoing,
        isQuote: this.replyIsQuote,
        hasThumbnail: this.replyHasThumbnail,
        containerWidth: this.containerWidth
      })
        .width('100%')
        .padding({
          left: TgUiTokens.COMPOSER_SIDE_INSET,
          right: TgUiTokens.COMPOSER_SIDE_INSET
        })
    }
  }

  build() {
    Column({ space: TgUiTokens.COMPOSER_REPLY_GAP }) {
      Divider()
        .strokeWidth(1)
        .color(TgUiTokens.COMPOSER_TOP_SEPARATOR)

      this.buildReplySnippet()

      Row({ space: TgUiTokens.COMPOSER_ROW_GAP }) {
        this.buildAttachButton()

        Row({ space: TgUiTokens.COMPOSER_ROW_GAP }) {
          this.buildTextInput()
          this.buildEmojiButton()
        }
        .layoutWeight(1)
        .padding({
          left: TgUiTokens.COMPOSER_INPUT_PADDING_H,
          right: TgUiTokens.COMPOSER_INPUT_PADDING_H,
          top: TgUiTokens.COMPOSER_INPUT_PADDING_V,
          bottom: TgUiTokens.COMPOSER_INPUT_PADDING_V
        })
        .backgroundColor(TgUiTokens.COMPOSER_INPUT_BG)
        .borderRadius(TgUiTokens.COMPOSER_INPUT_RADIUS)
        .constraintSize({
          minHeight: TgUiTokens.COMPOSER_MIN_HEIGHT,
          maxHeight: TgUiTokens.COMPOSER_MAX_HEIGHT
        })
        .alignItems(VerticalAlign.Center)

        this.buildActionButton()
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
    .backgroundColor(TgUiTokens.COMPOSER_BG)
    .opacity(this.composerOpacity())
  }
}

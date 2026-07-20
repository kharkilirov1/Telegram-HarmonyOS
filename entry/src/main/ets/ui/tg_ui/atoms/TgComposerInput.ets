// TgComposerInput — iOS Telegram-style glass composer bar
//
// iOS layout: [attach glass button] [text field glass capsule] [mic glass button].
// Reply/edit snippets stay in the capsule; keyboard-mode panels render below the composer.
// The trailing action keeps one external slot and transforms from mic to send when content is sendable.
// Text input is controlled by the screen, while the atom stays UI-only.

import { uiMaterial } from '@kit.ArkUI';
import { inputMethod } from '@kit.IMEKit';
import { Available, deviceInfo } from '@kit.BasicServicesKit';
import { TgIcon } from './TgIcon';
import { TgAttachmentRecentItem, TgAttachmentSheet } from './TgAttachmentSheet';
import { TgUiFeatureFlags } from '../TgUiFeatureFlags';
import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';
import {
  resolveComposerMaterialMode,
  TgComposerMaterialMode
} from '../utils/TgComposerMaterialPolicy';
import {
  formatVoiceRecordingDuration,
  resolveVoiceRecordingGesture,
  TgVoiceRecordingState
} from '../utils/TgVoiceRecordingPolicy';
import {
  composerMenuLabelTransition,
  composerPopupTransition
} from '../utils/TgComposerMotionPolicy';

@ComponentV2
export struct TgComposerInput {
  @Param text: string = '';
  @Param placeholder: string = 'Message';
  @Param requestedCaretPosition: number = 0;
  @Param caretRequestRevision: number = 0;
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

  @Monitor('caretRequestRevision')
  onCaretRequestChanged(_m: IMonitor): void {
    const caretOffset = Math.max(0, Math.min(this.text.length, this.requestedCaretPosition));
    setTimeout(() => {
      this.textController.caretPosition(caretOffset);
    }, 0);
  }

  aboutToAppear(): void {
    this.textBuffer = this.text;
  }
  @Param isDisabled: boolean = false;
  @Param showAttachButton: boolean = true;
  @Param attachmentMenuLabels: string[] = ['Camera', 'Photo', 'Video', 'Document'];
  @Param attachmentRecentItems: TgAttachmentRecentItem[] = [];
  @Param attachmentRecentLoading: boolean = false;
  @Param emojiPanelOpen: boolean = false;
  @Param showEmojiButton: boolean = true;
  @Param showBotMenu: boolean = false;
  @Param botMenuTitle: string = 'Menu';
  @Param botMenuOpen: boolean = false;
  @Param botMenuCommands: string[] = [];
  @Param botMenuDescriptions: string[] = [];
  @Param voiceRecordingState: TgVoiceRecordingState = 'idle';
  @Param voiceRecordingDurationMs: number = 0;
  @Param voiceSlideLabel: string = 'Slide to cancel';
  @Param voiceLockedLabel: string = 'Recording';
  @Param voicePreparingLabel: string = 'Starting...';
  @Param voiceSendingLabel: string = 'Sending...';

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
  @Event onTextSelectionChange: (start: number, end: number) => void = (_: number, __: number) => {};
  @Event onInputWillFocus: () => void = () => {};
  @Event onInputFocusChange: (focused: boolean) => void = (_: boolean) => {};
  @Event onAttachPress: () => void = () => {};
  @Event onAttachmentMenuItemPress: (index: number) => void = (_: number) => {};
  @Event onAttachmentMenuOpenChange: (isOpen: boolean) => void = (_: boolean) => {};
  @Event onAttachmentRecentPress: (item: TgAttachmentRecentItem) => void = (_: TgAttachmentRecentItem) => {};
  @Event onEmojiPress: () => void = () => {};
  @Event onKeyboardModePress: () => void = () => {};
  @Event onVoicePress: () => void = () => {};
  @Event onVoiceRecordStart: () => void = () => {};
  @Event onVoiceRecordSend: () => void = () => {};
  @Event onVoiceRecordCancel: () => void = () => {};
  @Event onVoiceRecordLock: () => void = () => {};
  @Event onBotMenuPress: () => void = () => {};
  @Event onBotMenuOpenChange: (isOpen: boolean) => void = (_: boolean) => {};
  @Event onBotMenuCommandPress: (index: number) => void = (_: number) => {};
  @Event onReplyCancelPress: () => void = () => {};
  @Event onEditCancelPress: () => void = () => {};
  @Event onForwardCancelPress: () => void = () => {};
  @Event onAttachmentCancelPress: () => void = () => {};

  // Controls the TextArea so we can drop the soft keyboard when the emoji panel
  // opens (otherwise system keyboard and panel fight for the same space).
  private textController: TextAreaController = new TextAreaController();
  private readonly textFocusKey: string = 'tg_chat_composer_text_input';
  @Local private voiceGestureActive: boolean = false;
  @Local private voiceGestureResolved: boolean = false;
  @Local private attachmentMenuOpen: boolean = false;
  @Local private inputFocused: boolean = false;
  private voiceClickSuppressionUntil: number = 0;

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

  private isVoiceRecordingActive(): boolean {
    return this.voiceRecordingState !== 'idle' && this.voiceRecordingState !== 'error';
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

  private responseRegionOffset(): number {
    return (TgUiTokens.COMPOSER_BUTTON_SIZE - TgUiTokens.COMPOSER_RESPONSE_SIZE) / 2;
  }

  private materialMode(): TgComposerMaterialMode {
    return resolveComposerMaterialMode(
      deviceInfo.apiAvailable('26.0.0'),
      TgUiFeatureFlags.USE_NATIVE_IMMERSIVE_COMPOSER_MATERIAL,
      this.useBlur()
    );
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
  private buildActionIcon() {
    TgIcon({
      src: this.canSend() ? TgUiTokens.ICON_RES_SEND : TgUiTokens.ICON_RES_MIC,
      iconSize: TgUiTokens.COMPOSER_ICON_SIZE,
      tintColor: this.canSend()
        ? TgUiTokens.COLOR_AVATAR_PLACEHOLDER_TEXT
        : TgUiTokens.COMPOSER_CONTROL_ICON
    })
  }

  private handleActionPress(): void {
    if (this.isDisabled) {
      return;
    }
    if (Date.now() <= this.voiceClickSuppressionUntil) {
      return;
    }
    if (this.canSend()) {
      this.handleSend();
    } else {
      this.onVoicePress();
    }
  }

  private beginVoiceRecordingGesture(): void {
    if (this.isDisabled || this.canSend() || this.isVoiceRecordingActive()) {
      return;
    }
    this.voiceGestureActive = true;
    this.voiceGestureResolved = false;
    this.voiceClickSuppressionUntil = Date.now() + 600;
    this.textController.stopEditing();
    this.onVoiceRecordStart();
  }

  private updateVoiceRecordingGesture(event?: GestureEvent): void {
    if (!this.voiceGestureActive || this.voiceGestureResolved || event === undefined) {
      return;
    }
    const resolution = resolveVoiceRecordingGesture(event.offsetX, event.offsetY);
    if (resolution === 'cancel') {
      this.voiceGestureResolved = true;
      this.voiceGestureActive = false;
      this.onVoiceRecordCancel();
    } else if (resolution === 'lock') {
      this.voiceGestureResolved = true;
      this.voiceGestureActive = false;
      this.onVoiceRecordLock();
    }
  }

  private finishVoiceRecordingGesture(): void {
    if (!this.voiceGestureActive || this.voiceGestureResolved) {
      return;
    }
    this.voiceGestureActive = false;
    this.voiceGestureResolved = true;
    this.onVoiceRecordSend();
  }

  private cancelVoiceRecordingGesture(): void {
    if (!this.voiceGestureActive || this.voiceGestureResolved) {
      return;
    }
    this.voiceGestureActive = false;
    this.voiceGestureResolved = true;
    this.onVoiceRecordCancel();
  }

  @Available({ minApiVersion: '26.0.0' })
  @Builder
  private buildNativeActionButton() {
    Row() {
      this.buildActionIcon()
    }
    .width(TgUiTokens.COMPOSER_BUTTON_SIZE)
    .height(TgUiTokens.COMPOSER_BUTTON_SIZE)
    .flexShrink(0)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .systemMaterial(new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      colorInvert: true,
      applyShadow: true,
      interactive: true
    }))
    .borderRadius(TgUiTokens.COMPOSER_BUTTON_SIZE / 2)
    .clip(true)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.85 })
    .responseRegion({
      x: this.responseRegionOffset(),
      y: this.responseRegionOffset(),
      width: TgUiTokens.COMPOSER_RESPONSE_SIZE,
      height: TgUiTokens.COMPOSER_RESPONSE_SIZE
    })
    .onClick(() => {
      this.handleActionPress();
    })
    .gesture(
      GestureGroup(GestureMode.Parallel,
        LongPressGesture({ repeat: false, duration: TgUiTokens.COMPOSER_RECORDING_HOLD_MS })
          .onAction(() => {
            this.beginVoiceRecordingGesture();
          })
          .onActionEnd(() => {
            this.finishVoiceRecordingGesture();
          })
          .onActionCancel(() => {
            this.cancelVoiceRecordingGesture();
          }),
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: 2 })
          .onActionUpdate((event?: GestureEvent) => {
            this.updateVoiceRecordingGesture(event);
          })
          .onActionEnd(() => {
            this.finishVoiceRecordingGesture();
          })
          .onActionCancel(() => {
            this.cancelVoiceRecordingGesture();
          })
      )
    )
  }

  @Builder
  private buildFallbackActionButton() {
    Row() {
      this.buildActionIcon()
    }
    .width(TgUiTokens.COMPOSER_BUTTON_SIZE)
    .height(TgUiTokens.COMPOSER_BUTTON_SIZE)
    .flexShrink(0)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    // Glass circle on API23-25; solid accent only for the active send state.
    .backgroundColor(this.canSend() ? TgUiTokens.COMPOSER_ACTION_ACTIVE : this.capsuleBg())
    .backgroundBlurStyle(this.canSend() ? BlurStyle.NONE : this.capsuleBlurStyle(),
      TgGlassPolicy.glassOptions())
    .border({
      width: this.canSend() ? 0 : TgUiTokens.COMPOSER_CONTROL_BORDER_WIDTH,
      color: TgUiTokens.COMPOSER_CAPSULE_BORDER
    })
    .borderRadius(TgUiTokens.COMPOSER_BUTTON_SIZE / 2)
    .clip(true)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.85 })
    .responseRegion({
      x: this.responseRegionOffset(),
      y: this.responseRegionOffset(),
      width: TgUiTokens.COMPOSER_RESPONSE_SIZE,
      height: TgUiTokens.COMPOSER_RESPONSE_SIZE
    })
    .onClick(() => {
      this.handleActionPress();
    })
    .gesture(
      GestureGroup(GestureMode.Parallel,
        LongPressGesture({ repeat: false, duration: TgUiTokens.COMPOSER_RECORDING_HOLD_MS })
          .onAction(() => {
            this.beginVoiceRecordingGesture();
          })
          .onActionEnd(() => {
            this.finishVoiceRecordingGesture();
          })
          .onActionCancel(() => {
            this.cancelVoiceRecordingGesture();
          }),
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: 2 })
          .onActionUpdate((event?: GestureEvent) => {
            this.updateVoiceRecordingGesture(event);
          })
          .onActionEnd(() => {
            this.finishVoiceRecordingGesture();
          })
          .onActionCancel(() => {
            this.cancelVoiceRecordingGesture();
          })
      )
    )
  }

  @Builder
  private buildActionButton() {
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (!this.canSend() && this.materialMode() === 'nativeImmersive') {
        this.buildNativeActionButton()
      } else {
        this.buildFallbackActionButton()
      }
    } else {
      this.buildFallbackActionButton()
    }
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

  @Builder
  private buildTextCapsuleContent() {
    this.buildForwardAccessoryPanel()
    this.buildEditAccessoryPanel()
    this.buildReplyAccessoryPanel()
    this.buildAttachmentAccessoryPanel()
    this.buildAccessorySeparator()

    Row() {
      TextArea({ text: this.textBuffer!!, placeholder: this.placeholder, controller: this.textController })
        .id(this.textFocusKey)
        // DEFAULT, not INLINE: the INLINE focus state paints an opaque
        // system block + blue frame over the glass capsule while typing.
        .style(TextContentStyle.DEFAULT)
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
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down && !this.inputFocused) {
            this.onInputWillFocus();
          }
        })
        .onFocus(() => {
          this.inputFocused = true;
          this.onInputFocusChange(true);
        })
        .onBlur(() => {
          this.inputFocused = false;
          this.onInputFocusChange(false);
        })
        .onTextSelectionChange((start: number, end: number) => {
          this.onTextSelectionChange(start, end);
        })
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

      // Emoji button inside text capsule (right side, like iOS accessory).
      if (this.showEmojiButton) {
        Row() {
          TgIcon({
            src: this.emojiPanelOpen ? TgUiTokens.ICON_RES_KEYBOARD : TgUiTokens.ICON_RES_EMOJI,
            iconSize: TgUiTokens.COMPOSER_ICON_SIZE,
            tintColor: TgUiTokens.COMPOSER_ACTION_INACTIVE
          })
        }
        .width(TgUiTokens.COMPOSER_BUTTON_SIZE)
        .height(TgUiTokens.COMPOSER_BUTTON_SIZE)
        .flexShrink(0)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.8 })
        .responseRegion({
          x: this.responseRegionOffset(),
          y: this.responseRegionOffset(),
          width: TgUiTokens.COMPOSER_RESPONSE_SIZE,
          height: TgUiTokens.COMPOSER_RESPONSE_SIZE
        })
        .onClick(() => {
          if (!this.isDisabled) {
            this.attachmentMenuOpen = false;
            this.onAttachmentMenuOpenChange(false);
            this.onBotMenuOpenChange(false);
            if (this.emojiPanelOpen) {
              this.onKeyboardModePress();
              setTimeout(() => {
                this.getUIContext().getFocusController().requestFocus(this.textFocusKey);
                this.textController.caretPosition(Math.max(0,
                  Math.min(this.textBuffer.length, this.requestedCaretPosition)));
                try {
                  inputMethod.getController().showTextInput().catch(() => {});
                } catch (_error) {
                  // Focus still lands in the TextArea; a direct field tap remains available.
                }
              }, 32);
            } else {
              this.textController.stopEditing();
              this.onEmojiPress();
            }
          }
        })
      }

    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .constraintSize({ minHeight: TgUiTokens.COMPOSER_MIN_CAPSULE_HEIGHT })
    .padding({ left: TgUiTokens.COMPOSER_ATTACH_LEFT_INSET, right: TgUiTokens.COMPOSER_ATTACH_LEFT_INSET })
  }

  @Builder
  private buildAttachIcon() {
    TgIcon({
      src: TgUiTokens.ICON_RES_ATTACH,
      iconSize: TgUiTokens.COMPOSER_ICON_SIZE,
      tintColor: TgUiTokens.COMPOSER_CONTROL_ICON
    })
  }

  @Builder
  private buildAttachmentSheet() {
    TgAttachmentSheet({
      items: this.attachmentRecentItems,
      isLoading: this.attachmentRecentLoading,
      onClose: (): void => {
        this.attachmentMenuOpen = false;
        this.onAttachmentMenuOpenChange(false);
      },
      onRecentPress: (item: TgAttachmentRecentItem): void => {
        this.attachmentMenuOpen = false;
        this.onAttachmentMenuOpenChange(false);
        this.onAttachmentRecentPress(item);
      },
      onCategoryPress: (index: number): void => {
        this.attachmentMenuOpen = false;
        this.onAttachmentMenuOpenChange(false);
        this.onAttachmentMenuItemPress(index);
      }
    })
  }

  private handleAttachPress(): void {
    if (!this.isDisabled) {
      this.textController.stopEditing();
      this.onBotMenuOpenChange(false);
      this.attachmentMenuOpen = !this.attachmentMenuOpen;
      this.onAttachmentMenuOpenChange(this.attachmentMenuOpen);
      this.onAttachPress();
    }
  }

  @Available({ minApiVersion: '26.0.0' })
  @Builder
  private buildNativeAttachButton() {
    Row() {
      this.buildAttachIcon()
    }
    .width(TgUiTokens.COMPOSER_BUTTON_SIZE)
    .height(TgUiTokens.COMPOSER_BUTTON_SIZE)
    .flexShrink(0)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .systemMaterial(new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      colorInvert: true,
      applyShadow: true,
      interactive: true
    }))
    .borderRadius(TgUiTokens.COMPOSER_BUTTON_SIZE / 2)
    .clip(true)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.85 })
    .responseRegion({
      x: this.responseRegionOffset(),
      y: this.responseRegionOffset(),
      width: TgUiTokens.COMPOSER_RESPONSE_SIZE,
      height: TgUiTokens.COMPOSER_RESPONSE_SIZE
    })
    .onClick(() => {
      this.handleAttachPress();
    })
  }

  @Builder
  private buildFallbackAttachButton() {
    Row() {
      this.buildAttachIcon()
    }
    .width(TgUiTokens.COMPOSER_BUTTON_SIZE)
    .height(TgUiTokens.COMPOSER_BUTTON_SIZE)
    .flexShrink(0)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.capsuleBg())
    .backgroundBlurStyle(this.capsuleBlurStyle(), TgGlassPolicy.glassOptions())
    .border({ width: TgUiTokens.COMPOSER_CONTROL_BORDER_WIDTH, color: TgUiTokens.COMPOSER_CAPSULE_BORDER })
    .borderRadius(TgUiTokens.COMPOSER_BUTTON_SIZE / 2)
    .clip(true)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.85 })
    .responseRegion({
      x: this.responseRegionOffset(),
      y: this.responseRegionOffset(),
      width: TgUiTokens.COMPOSER_RESPONSE_SIZE,
      height: TgUiTokens.COMPOSER_RESPONSE_SIZE
    })
    .onClick(() => {
      this.handleAttachPress();
    })
  }

  @Builder
  private buildAttachButton() {
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (this.materialMode() === 'nativeImmersive') {
        this.buildNativeAttachButton()
      } else {
        this.buildFallbackAttachButton()
      }
    } else {
      this.buildFallbackAttachButton()
    }
  }

  @Available({ minApiVersion: '26.0.0' })
  @Builder
  private buildNativeTextCapsule() {
    Column() {
      this.buildTextCapsuleContent()
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .systemMaterial(new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      applyShadow: true,
      interactive: false
    }))
    .borderRadius(TgUiTokens.COMPOSER_CAPSULE_RADIUS)
    .clip(true)
  }

  @Builder
  private buildFallbackTextCapsule() {
    Column() {
      this.buildTextCapsuleContent()
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(this.capsuleBg())
    .backgroundBlurStyle(this.capsuleBlurStyle(), TgGlassPolicy.glassOptions())
    .borderRadius(TgUiTokens.COMPOSER_CAPSULE_RADIUS)
    .border({ width: TgUiTokens.COMPOSER_BORDER_WIDTH, color: TgUiTokens.COMPOSER_CAPSULE_BORDER })
    .clip(true)
  }

  @Builder
  private buildTextCapsule() {
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (this.materialMode() === 'nativeImmersive') {
        this.buildNativeTextCapsule()
      } else {
        this.buildFallbackTextCapsule()
      }
    } else {
      this.buildFallbackTextCapsule()
    }
  }

  private visibleBotMenuCommands(): string[] {
    return this.botMenuCommands;
  }

  private botMenuPopupHeight(): number {
    const rows = Math.min(
      this.visibleBotMenuCommands().length,
      TgUiTokens.COMPOSER_BOT_POPUP_MAX_VISIBLE_ROWS
    );
    return rows * TgUiTokens.COMPOSER_BOT_POPUP_ROW_HEIGHT;
  }

  private botMenuDescription(index: number, command: string): string {
    if (index >= 0 && index < this.botMenuDescriptions.length) {
      const description = this.botMenuDescriptions[index].trim();
      if (description.length > 0) {
        return description;
      }
    }
    return command;
  }

  private botMenuExpanded(): boolean {
    return !this.inputFocused && this.textBuffer.length === 0;
  }

  @Builder
  private buildMenuGlyph() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: TgUiTokens.COMPOSER_MENU_LINE_GAP }) {
        ForEach([0, 1, 2], (_line: number) => {
          Row() {}
            .width(TgUiTokens.COMPOSER_MENU_LINE_WIDTH)
            .height(TgUiTokens.COMPOSER_MENU_LINE_HEIGHT)
            .borderRadius(TgUiTokens.COMPOSER_MENU_LINE_HEIGHT / 2)
            .backgroundColor(TgUiTokens.COLOR_AVATAR_PLACEHOLDER_TEXT)
        })
      }
      .opacity(this.botMenuOpen ? 0 : 1)
      .scale({ x: this.botMenuOpen ? 0.72 : 1, y: this.botMenuOpen ? 0.72 : 1 })
      .animation({ duration: TgUiTokens.COMPOSER_MENU_ICON_TRANSITION_MS, curve: Curve.EaseOut })

      Stack({ alignContent: Alignment.Center }) {
        Row() {}
          .width(TgUiTokens.COMPOSER_MENU_CLOSE_LINE_WIDTH)
          .height(TgUiTokens.COMPOSER_MENU_CLOSE_LINE_HEIGHT)
          .borderRadius(TgUiTokens.COMPOSER_MENU_CLOSE_LINE_HEIGHT / 2)
          .backgroundColor(TgUiTokens.COLOR_AVATAR_PLACEHOLDER_TEXT)
          .rotate({ angle: 45 })
        Row() {}
          .width(TgUiTokens.COMPOSER_MENU_CLOSE_LINE_WIDTH)
          .height(TgUiTokens.COMPOSER_MENU_CLOSE_LINE_HEIGHT)
          .borderRadius(TgUiTokens.COMPOSER_MENU_CLOSE_LINE_HEIGHT / 2)
          .backgroundColor(TgUiTokens.COLOR_AVATAR_PLACEHOLDER_TEXT)
          .rotate({ angle: -45 })
      }
      .opacity(this.botMenuOpen ? 1 : 0)
      .scale({ x: this.botMenuOpen ? 1 : 0.72, y: this.botMenuOpen ? 1 : 0.72 })
      .rotate({ angle: this.botMenuOpen ? 0 : -45 })
      .animation({ duration: TgUiTokens.COMPOSER_MENU_ICON_TRANSITION_MS, curve: Curve.EaseOut })
    }
    .width(TgUiTokens.COMPOSER_MENU_GLYPH_SIZE)
    .height(TgUiTokens.COMPOSER_MENU_GLYPH_SIZE)
  }

  @Builder
  private buildBotMenuPanel() {
    List() {
      ForEach(this.visibleBotMenuCommands(), (command: string, index: number) => {
        ListItem() {
          Column() {
            Row({ space: TgUiTokens.COMPOSER_MENU_GAP }) {
              Text(this.botMenuDescription(index, command))
                .fontSize(TgUiTokens.COMPOSER_BOT_POPUP_PRIMARY_TEXT_SIZE)
                .fontWeight(FontWeight.Regular)
                .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)

              Text(`/${command}`)
                .fontSize(TgUiTokens.COMPOSER_BOT_POPUP_COMMAND_TEXT_SIZE)
                .fontWeight(FontWeight.Regular)
                .fontColor(TgUiTokens.COLOR_TEXT_META)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .height(TgUiTokens.COMPOSER_BOT_POPUP_ROW_HEIGHT -
              TgUiTokens.COMPOSER_BOT_POPUP_SEPARATOR_WIDTH)
            .padding({
              left: TgUiTokens.COMPOSER_BOT_POPUP_PADDING_H,
              right: TgUiTokens.COMPOSER_BOT_POPUP_PADDING_H
            })
            .alignItems(VerticalAlign.Center)

            Divider()
              .height(TgUiTokens.COMPOSER_BOT_POPUP_SEPARATOR_WIDTH)
              .color(index < this.visibleBotMenuCommands().length - 1
                ? TgUiTokens.COLOR_SEPARATOR
                : Color.Transparent)
              .margin({ left: TgUiTokens.COMPOSER_BOT_POPUP_PADDING_H })
          }
          .width('100%')
          .height(TgUiTokens.COMPOSER_BOT_POPUP_ROW_HEIGHT)
          .onClick(() => {
            this.onBotMenuCommandPress(index);
            this.onBotMenuOpenChange(false);
          })
        }
      }, (command: string, index: number) => `${index}:${command}`)
    }
    .width('100%')
    .height(this.botMenuPopupHeight())
    .scrollBar(BarState.Off)
    .backgroundColor(this.capsuleBg())
    .backgroundBlurStyle(this.capsuleBlurStyle(), TgGlassPolicy.glassOptions())
    .border({ width: TgUiTokens.COMPOSER_BORDER_WIDTH, color: TgUiTokens.COMPOSER_CAPSULE_BORDER })
    .borderRadius(TgUiTokens.COMPOSER_KEYBOARD_PANEL_RADIUS)
    .clip(true)
    .transition(composerPopupTransition())
  }

  @Builder
  private buildBotMenuContent() {
    Row({ space: TgUiTokens.COMPOSER_MENU_GAP }) {
      this.buildMenuGlyph()
      if (this.botMenuExpanded()) {
        Text(this.botMenuTitle)
          .fontSize(TgUiTokens.COMPOSER_MENU_TEXT_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(TgUiTokens.COLOR_AVATAR_PLACEHOLDER_TEXT)
          .maxLines(1)
          .transition(composerMenuLabelTransition())
      }
    }
    .height(TgUiTokens.COMPOSER_BUTTON_SIZE)
    .constraintSize({ minWidth: TgUiTokens.COMPOSER_BUTTON_SIZE })
    .padding({ left: TgUiTokens.COMPOSER_MENU_PADDING_H, right: TgUiTokens.COMPOSER_MENU_PADDING_H })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .animation({ duration: TgUiTokens.COMPOSER_MENU_ICON_TRANSITION_MS, curve: Curve.EaseInOut })
  }

  @Available({ minApiVersion: '26.0.0' })
  @Builder
  private buildNativeBotMenu() {
    Row() {
      this.buildBotMenuContent()
    }
    .height(TgUiTokens.COMPOSER_BUTTON_SIZE)
    .flexShrink(0)
    .backgroundColor(TgUiTokens.COMPOSER_ACTION_ACTIVE)
    .borderRadius(TgUiTokens.COMPOSER_CAPSULE_RADIUS)
    .clip(true)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.94 })
    .responseRegion({
      x: this.responseRegionOffset(),
      y: this.responseRegionOffset(),
      width: this.botMenuExpanded() ? '100%' : TgUiTokens.COMPOSER_RESPONSE_SIZE,
      height: TgUiTokens.COMPOSER_RESPONSE_SIZE
    })
    .onClick(() => {
      if (!this.isDisabled) {
        this.attachmentMenuOpen = false;
        this.textController.stopEditing();
        this.onBotMenuPress();
      }
    })
  }

  @Builder
  private buildFallbackBotMenu() {
    Row() {
      this.buildBotMenuContent()
    }
    .height(TgUiTokens.COMPOSER_BUTTON_SIZE)
    .flexShrink(0)
    .backgroundColor(TgUiTokens.COMPOSER_ACTION_ACTIVE)
    .borderRadius(TgUiTokens.COMPOSER_CAPSULE_RADIUS)
    .clip(true)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.94 })
    .responseRegion({
      x: this.responseRegionOffset(),
      y: this.responseRegionOffset(),
      width: this.botMenuExpanded() ? '100%' : TgUiTokens.COMPOSER_RESPONSE_SIZE,
      height: TgUiTokens.COMPOSER_RESPONSE_SIZE
    })
    .onClick(() => {
      if (!this.isDisabled) {
        this.attachmentMenuOpen = false;
        this.textController.stopEditing();
        this.onBotMenuPress();
      }
    })
  }

  @Builder
  private buildBotMenu() {
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (this.materialMode() === 'nativeImmersive') {
        this.buildNativeBotMenu()
      } else {
        this.buildFallbackBotMenu()
      }
    } else {
      this.buildFallbackBotMenu()
    }
  }

  @Builder
  private buildRecordingWaveform() {
    Row({ space: 2 }) {
      ForEach([8, 15, 11, 20, 13, 18, 9, 16, 12, 19, 10, 14], (height: number) => {
        Row() {}
          .width(2)
          .height(height)
          .borderRadius(1)
          .backgroundColor(TgUiTokens.COMPOSER_ACTION_ACTIVE)
      })
    }
    .height(24)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildRecordingSurfaceContent() {
    Row({ space: TgUiTokens.COMPOSER_RECORDING_GAP }) {
      if (this.voiceRecordingState === 'locked') {
        Row() {
          TgIcon({
            src: TgUiTokens.ICON_RES_DELETE,
            iconSize: TgUiTokens.COMPOSER_RECORDING_ICON_SIZE,
            tintColor: TgUiTokens.COMPOSER_RECORDING_RED
          })
        }
        .width(TgUiTokens.COMPOSER_BUTTON_SIZE)
        .height(TgUiTokens.COMPOSER_BUTTON_SIZE)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.82 })
        .onClick(() => {
          this.onVoiceRecordCancel();
        })
      } else {
        Row() {}
          .width(TgUiTokens.COMPOSER_RECORDING_DOT_SIZE)
          .height(TgUiTokens.COMPOSER_RECORDING_DOT_SIZE)
          .borderRadius(TgUiTokens.COMPOSER_RECORDING_DOT_SIZE / 2)
          .backgroundColor(TgUiTokens.COMPOSER_RECORDING_RED)
          .opacity(this.voiceRecordingState === 'sending' ? 0.35 : 1)
      }

      Text(formatVoiceRecordingDuration(this.voiceRecordingDurationMs))
        .fontSize(TgUiTokens.COMPOSER_RECORDING_TIMER_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(TgUiTokens.COMPOSER_TEXT)
        .minFontScale(1)
        .maxFontScale(1)

      if (this.voiceRecordingState === 'locked') {
        this.buildRecordingWaveform()
        Text(this.voiceLockedLabel)
          .fontSize(TgUiTokens.COMPOSER_RECORDING_LABEL_SIZE)
          .fontColor(TgUiTokens.COMPOSER_PLACEHOLDER)
          .maxLines(1)
          .layoutWeight(1)
      } else if (this.voiceRecordingState === 'sending') {
        Progress({ value: 40, total: 100, type: ProgressType.Ring })
          .width(TgUiTokens.COMPOSER_RECORDING_PROGRESS_SIZE)
          .height(TgUiTokens.COMPOSER_RECORDING_PROGRESS_SIZE)
          .color(TgUiTokens.COMPOSER_ACTION_ACTIVE)
        Text(this.voiceSendingLabel)
          .fontSize(TgUiTokens.COMPOSER_RECORDING_LABEL_SIZE)
          .fontColor(TgUiTokens.COMPOSER_PLACEHOLDER)
          .maxLines(1)
          .layoutWeight(1)
      } else {
        Text(this.voiceRecordingState === 'preparing' ? this.voicePreparingLabel : this.voiceSlideLabel)
          .fontSize(TgUiTokens.COMPOSER_RECORDING_LABEL_SIZE)
          .fontColor(TgUiTokens.COMPOSER_PLACEHOLDER)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .onClick(() => {
            this.onVoiceRecordCancel();
          })
      }
    }
    .width('100%')
    .height(TgUiTokens.COMPOSER_BUTTON_SIZE)
    .padding({ left: TgUiTokens.COMPOSER_RECORDING_PADDING_H, right: TgUiTokens.COMPOSER_RECORDING_PADDING_H })
    .alignItems(VerticalAlign.Center)
  }

  @Available({ minApiVersion: '26.0.0' })
  @Builder
  private buildNativeRecordingSurface() {
    Row() {
      this.buildRecordingSurfaceContent()
    }
    .layoutWeight(1)
    .systemMaterial(new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      applyShadow: true,
      interactive: false
    }))
    .borderRadius(TgUiTokens.COMPOSER_CAPSULE_RADIUS)
    .clip(true)
  }

  @Builder
  private buildFallbackRecordingSurface() {
    Row() {
      this.buildRecordingSurfaceContent()
    }
    .layoutWeight(1)
    .backgroundColor(this.capsuleBg())
    .backgroundBlurStyle(this.capsuleBlurStyle(), TgGlassPolicy.glassOptions())
    .border({ width: TgUiTokens.COMPOSER_BORDER_WIDTH, color: TgUiTokens.COMPOSER_CAPSULE_BORDER })
    .borderRadius(TgUiTokens.COMPOSER_CAPSULE_RADIUS)
    .clip(true)
  }

  @Builder
  private buildRecordingSurface() {
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (this.materialMode() === 'nativeImmersive') {
        this.buildNativeRecordingSurface()
      } else {
        this.buildFallbackRecordingSurface()
      }
    } else {
      this.buildFallbackRecordingSurface()
    }
  }

  @Builder
  private buildFallbackRecordingAction() {
    Row() {
      TgIcon({
        src: this.voiceRecordingState === 'locked' ? TgUiTokens.ICON_RES_SEND : TgUiTokens.ICON_RES_LOCK,
        iconSize: TgUiTokens.COMPOSER_RECORDING_ICON_SIZE,
        tintColor: this.voiceRecordingState === 'locked'
          ? TgUiTokens.COLOR_AVATAR_PLACEHOLDER_TEXT
          : TgUiTokens.COMPOSER_ACTION_ACTIVE
      })
    }
    .width(TgUiTokens.COMPOSER_BUTTON_SIZE)
    .height(TgUiTokens.COMPOSER_BUTTON_SIZE)
    .flexShrink(0)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.voiceRecordingState === 'locked'
      ? TgUiTokens.COMPOSER_ACTION_ACTIVE
      : this.capsuleBg())
    .backgroundBlurStyle(this.voiceRecordingState === 'locked'
      ? BlurStyle.NONE
      : this.capsuleBlurStyle(), TgGlassPolicy.glassOptions())
    .border({
      width: this.voiceRecordingState === 'locked' ? 0 : TgUiTokens.COMPOSER_CONTROL_BORDER_WIDTH,
      color: TgUiTokens.COMPOSER_CAPSULE_BORDER
    })
    .borderRadius(TgUiTokens.COMPOSER_BUTTON_SIZE / 2)
    .clip(true)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.85 })
    .onClick(() => {
      if (this.voiceRecordingState === 'locked') {
        this.onVoiceRecordSend();
      }
    })
  }

  @Available({ minApiVersion: '26.0.0' })
  @Builder
  private buildNativeRecordingAction() {
    Row() {
      TgIcon({
        src: TgUiTokens.ICON_RES_LOCK,
        iconSize: TgUiTokens.COMPOSER_RECORDING_ICON_SIZE,
        tintColor: TgUiTokens.COMPOSER_ACTION_ACTIVE
      })
    }
    .width(TgUiTokens.COMPOSER_BUTTON_SIZE)
    .height(TgUiTokens.COMPOSER_BUTTON_SIZE)
    .flexShrink(0)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .systemMaterial(new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      colorInvert: true,
      applyShadow: true,
      interactive: false
    }))
    .borderRadius(TgUiTokens.COMPOSER_BUTTON_SIZE / 2)
    .clip(true)
  }

  @Builder
  private buildRecordingAction() {
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (this.voiceRecordingState !== 'locked' && this.materialMode() === 'nativeImmersive') {
        this.buildNativeRecordingAction()
      } else {
        this.buildFallbackRecordingAction()
      }
    } else {
      this.buildFallbackRecordingAction()
    }
  }

  @Builder
  private buildRecordingComposer() {
    Row({ space: TgUiTokens.COMPOSER_ELEMENT_GAP }) {
      this.buildRecordingSurface()
      this.buildRecordingAction()
    }
    .width('100%')
    .alignItems(VerticalAlign.Bottom)
    .animation({ duration: TgUiTokens.COMPOSER_LAYOUT_TRANSITION_MS, curve: Curve.Smooth })
    .padding({
      left: TgUiTokens.COMPOSER_SIDE_INSET,
      right: TgUiTokens.COMPOSER_SIDE_INSET,
      top: TgUiTokens.COMPOSER_VERTICAL_INSET,
      bottom: TgUiTokens.COMPOSER_VERTICAL_INSET
    })
  }

  @Builder
  private buildIdleComposer() {
    Row({ space: TgUiTokens.COMPOSER_ELEMENT_GAP }) {
      if (this.showBotMenu) {
        this.buildBotMenu()
      }

      // Attach button remains a distinct liquid circle next to the optional bot menu.
      if (this.showAttachButton) {
        this.buildAttachButton()
      }

      this.buildTextCapsule()

      this.buildActionButton()
    }
    .width('100%')
    .alignItems(VerticalAlign.Bottom)
    .animation({ duration: TgUiTokens.COMPOSER_LAYOUT_TRANSITION_MS, curve: Curve.Smooth })
    .padding({
      left: TgUiTokens.COMPOSER_SIDE_INSET,
      right: TgUiTokens.COMPOSER_SIDE_INSET,
      top: TgUiTokens.COMPOSER_VERTICAL_INSET,
      bottom: TgUiTokens.COMPOSER_VERTICAL_INSET
    })
  }

  build() {
    Column() {
      if (this.botMenuOpen) {
        this.buildBotMenuPanel()
      }

      if (this.isVoiceRecordingActive()) {
        this.buildRecordingComposer()
      } else {
        this.buildIdleComposer()
      }
    }
    .width('100%')
    .padding({ bottom: this.bottomInset })
    .backgroundColor(Color.Transparent)
    .opacity(this.isDisabled ? TgUiTokens.COMPOSER_DISABLED_OPACITY : 1)
    .bindSheet(this.attachmentMenuOpen, this.buildAttachmentSheet(), {
      height: TgUiTokens.ATTACHMENT_SHEET_HEIGHT,
      dragBar: false,
      showClose: false,
      preferType: SheetType.BOTTOM,
      mode: SheetMode.OVERLAY,
      backgroundColor: TgUiTokens.ATTACHMENT_SHEET_BG,
      blurStyle: this.capsuleBlurStyle(),
      maskColor: TgUiTokens.COMPOSER_ATTACHMENT_SHEET_MASK,
      enableOutsideInteractive: false,
      onDisappear: () => {
        if (this.attachmentMenuOpen) {
          this.attachmentMenuOpen = false;
        }
        this.onAttachmentMenuOpenChange(false);
      }
    })
  }
}

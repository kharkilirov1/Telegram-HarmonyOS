// Chat input bar with emoji, stickers, GIF, attachments, voice recording
// Reference: Telegram iOS ChatInputBar, Android ChatActivityEnterView
// Voice recording UI extracted to VoiceRecordingBar.ets

import { Message } from '../../models/Message';
import { EmojiPicker } from './EmojiPicker';
import { AttachmentPanel } from './AttachmentPanel';
import { StickerPicker } from './StickerPicker';
import { GifPicker } from './GifPicker';
import { VoiceRecordingBar } from './VoiceRecordingBar';

@ComponentV2
export struct ChatInputBar {
  @Local inputText: string = '';
  @Local isRecording: boolean = false;
  @Local recordingDuration: number = 0;
  @Local recordingLocked: boolean = false;
  @Local showEmojiPicker: boolean = false;
  @Local showAttachPanel: boolean = false;
  @Local showStickerPicker: boolean = false;
  @Local showGifPicker: boolean = false;
  @Local showSchedulePicker: boolean = false;
  @Param replyMessage: Message | null = null;
  @Param editMessage: Message | null = null;
  @Param chatId: number = 0;

  @Event onSendMessage: (text: string) => void = () => {};
  @Event onSendScheduled: (text: string, sendDate: number) => void = () => {};
  @Event onEditMessage: (messageId: number, text: string) => void = () => {};
  @Event onAttachTap: () => void = () => {};
  @Event onCancelReply: () => void = () => {};
  @Event onCancelEdit: () => void = () => {};
  @Event onSendSticker: (emoji: string) => void = () => {};
  @Event onSendGif: (gifId: number) => void = () => {};
  @Event onSendVoice: (duration: number) => void = () => {};
  @Event onDraftChange: (text: string) => void = () => {};
  @Event onCreatePoll: () => void = () => {};

  private recordingTimerId: number = -1;

  aboutToAppear(): void {
    if (this.editMessage !== null) {
      this.inputText = this.editMessage.text;
    }
  }

  aboutToDisappear(): void {
    // Ensure recording timer is cleaned up when component is removed
    this.resetRecordingState();
  }

  build() {
    Column() {
      // Reply bar
      if (this.replyMessage !== null) {
        Row() {
          Image($r('app.media.ic_reply'))
            .width(18).height(18)
            .fillColor($r('app.color.telegram_blue'))
            .margin({ right: 6 })

          Divider()
            .vertical(true)
            .strokeWidth(2)
            .color($r('app.color.telegram_blue'))
            .height('100%')

          Column() {
            Text(this.replyMessage.senderName)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.telegram_blue'))
              .maxLines(1)
            Text(this.replyMessage.text)
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .margin({ left: 8 })
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Image($r('app.media.ic_close'))
            .width(18).height(18)
            .fillColor($r('app.color.text_secondary'))
            .onClick(() => this.onCancelReply())
        }
        .width('100%').height(40)
        .padding({ left: 12, right: 12 })
        .backgroundColor($r('app.color.background_primary'))

        Divider().strokeWidth(0.5).color($r('app.color.separator'))
      }

      // Edit bar
      if (this.editMessage !== null) {
        Row() {
          Image($r('app.media.ic_edit'))
            .width(18).height(18)
            .fillColor($r('app.color.telegram_blue'))
            .margin({ right: 6 })

          Divider()
            .vertical(true)
            .strokeWidth(2)
            .color($r('app.color.telegram_blue'))
            .height('100%')

          Column() {
            Text($r('app.string.editing_message'))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.telegram_blue'))
              .maxLines(1)
            Text(this.editMessage.text)
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .margin({ left: 8 })
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Image($r('app.media.ic_close'))
            .width(18).height(18)
            .fillColor($r('app.color.text_secondary'))
            .onClick(() => {
              this.onCancelEdit();
              this.inputText = '';
            })
        }
        .width('100%').height(40)
        .padding({ left: 12, right: 12 })
        .backgroundColor($r('app.color.background_primary'))

        Divider().strokeWidth(0.5).color($r('app.color.separator'))
      }

      Divider().strokeWidth(0.5).color($r('app.color.separator'))

      // Main input row
      Row() {
        if (this.isRecording) {
          VoiceRecordingBar({
            recordingDuration: this.recordingDuration,
            recordingLocked: this.recordingLocked,
            onStop: () => { this.stopRecording(); },
            onCancel: () => { this.cancelRecording(); },
            onLock: () => { this.recordingLocked = true; }
          })
        } else {
          // Emoji/Sticker toggle button
          Image(this.showEmojiPicker || this.showStickerPicker || this.showGifPicker
            ? $r('app.media.ic_close')
            : $r('app.media.ic_emoji'))
            .width(24).height(24)
            .fillColor($r('app.color.text_secondary'))
            .margin({ right: 6 })
            .accessibilityText($r('app.string.accessibility_emoji'))
            .onClick(() => {
              this.closeAllPanels();
              this.showEmojiPicker = !this.showEmojiPicker;
            })

          // Attach button
          Image($r('app.media.ic_attach'))
            .width(24).height(24)
            .fillColor($r('app.color.text_secondary'))
            .accessibilityText($r('app.string.accessibility_attach'))
            .onClick(() => {
              const wasOpen = this.showAttachPanel;
              this.closeAllPanels();
              this.showAttachPanel = !wasOpen;
            })
            .margin({ right: 6 })

          // Text area
          TextArea({ placeholder: $r('app.string.message_placeholder'), text: this.inputText })
            .fontSize(16)
            .layoutWeight(1)
            .constraintSize({ minHeight: 36, maxHeight: 120 })
            .backgroundColor($r('app.color.background_secondary'))
            .borderRadius(20)
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .onChange((value: string) => {
              this.inputText = value;
              this.onDraftChange(value);
            })
            .onFocus(() => { this.closeAllPanels(); })

          // Send / Mic toggle
          if (this.inputText.trim().length > 0) {
            Image(this.editMessage !== null ? $r('app.media.ic_check_single') : $r('app.media.ic_send'))
              .width(28).height(28)
              .fillColor($r('app.color.telegram_blue'))
              .margin({ left: 6 })
              .accessibilityText($r('app.string.accessibility_send'))
              .gesture(
                GestureGroup(GestureMode.Exclusive,
                  LongPressGesture({ repeat: false, duration: 500 })
                    .onAction(() => {
                      this.showSchedulePicker = true;
                    }),
                  TapGesture()
                    .onAction(() => {
                      const text = this.inputText.trim();
                      if (text.length > 0) {
                        if (this.editMessage !== null) {
                          this.onEditMessage(this.editMessage.id, text);
                        } else {
                          this.onSendMessage(text);
                        }
                        this.inputText = '';
                      }
                    })
                )
              )
          } else {
            Image($r('app.media.ic_mic'))
              .width(24).height(24)
              .fillColor($r('app.color.text_secondary'))
              .margin({ left: 6 })
              .accessibilityText($r('app.string.accessibility_record'))
              .gesture(
                GestureGroup(GestureMode.Exclusive,
                  LongPressGesture({ repeat: false, duration: 200 })
                    .onAction(() => { this.startRecording(); }),
                  TapGesture()
                    .onAction(() => { this.startRecording(); })
                )
              )
          }
        }
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 6, bottom: 6 })
      .backgroundColor($r('app.color.glass_input_bg'))
      .backgroundBlurStyle(BlurStyle.COMPONENT_THIN, {
        colorMode: ThemeColorMode.SYSTEM,
        adaptiveColor: AdaptiveColor.DEFAULT,
        scale: 1.0
      })

      // Panel selector tabs (emoji / stickers / gifs)
      if (this.showEmojiPicker || this.showStickerPicker || this.showGifPicker) {
        Row({ space: 0 }) {
          this.panelTab($r('app.string.emoji_tab'), this.showEmojiPicker, () => {
            this.showEmojiPicker = true;
            this.showStickerPicker = false;
            this.showGifPicker = false;
          })
          this.panelTab($r('app.string.stickers_tab'), this.showStickerPicker, () => {
            this.showEmojiPicker = false;
            this.showStickerPicker = true;
            this.showGifPicker = false;
          })
          this.panelTab($r('app.string.gifs_tab'), this.showGifPicker, () => {
            this.showEmojiPicker = false;
            this.showStickerPicker = false;
            this.showGifPicker = true;
          })
        }
        .width('100%')
        .height(36)
        .backgroundColor($r('app.color.background_primary'))
      }

      // Emoji picker panel
      if (this.showEmojiPicker) {
        EmojiPicker({
          onEmojiSelected: (emoji: string) => { this.inputText += emoji; }
        })
      }

      // Sticker picker panel
      if (this.showStickerPicker) {
        StickerPicker({
          onStickerSelected: (emoji: string) => {
            this.onSendSticker(emoji);
            this.closeAllPanels();
          }
        })
      }

      // GIF picker panel
      if (this.showGifPicker) {
        GifPicker({
          onGifSelected: (gifId: number) => {
            this.onSendGif(gifId);
            this.closeAllPanels();
          }
        })
      }

      // Attachment panel
      if (this.showAttachPanel) {
        AttachmentPanel({
          onCamera: () => { this.showAttachPanel = false; },
          onGallery: () => { this.showAttachPanel = false; },
          onFile: () => { this.showAttachPanel = false; },
          onLocation: () => { this.showAttachPanel = false; },
          onContact: () => { this.showAttachPanel = false; },
          onPoll: () => { this.showAttachPanel = false; this.onCreatePoll(); },
          onClose: () => { this.showAttachPanel = false; }
        })
      }

      // Schedule picker panel
      if (this.showSchedulePicker) {
        this.schedulePickerPanel()
      }
    }
    .width('100%')
  }

  @Builder
  panelTab(label: ResourceStr, isActive: boolean, onTap: () => void) {
    Column() {
      Text(label)
        .fontSize(14)
        .fontColor(isActive
          ? $r('app.color.telegram_blue')
          : $r('app.color.text_secondary'))
        .fontWeight(isActive ? FontWeight.Medium : FontWeight.Normal)
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })

      Divider()
        .strokeWidth(2)
        .color(isActive ? $r('app.color.telegram_blue') : Color.Transparent)
        .width('80%')
    }
    .layoutWeight(1)
    .onClick(onTap)
  }

  // --- Recording control ---

  private startRecording(): void {
    this.isRecording = true;
    this.recordingDuration = 0;
    this.recordingLocked = false;
    this.closeAllPanels();

    this.recordingTimerId = setInterval(() => {
      this.recordingDuration++;
    }, 1000);
  }

  private stopRecording(): void {
    const duration = this.recordingDuration;
    this.resetRecordingState();
    if (duration > 0) {
      this.onSendVoice(duration);
    }
  }

  private cancelRecording(): void {
    this.resetRecordingState();
  }

  private resetRecordingState(): void {
    this.isRecording = false;
    this.recordingLocked = false;
    if (this.recordingTimerId >= 0) {
      clearInterval(this.recordingTimerId);
      this.recordingTimerId = -1;
    }
  }

  private closeAllPanels(): void {
    this.showEmojiPicker = false;
    this.showStickerPicker = false;
    this.showGifPicker = false;
    this.showAttachPanel = false;
    this.showSchedulePicker = false;
  }

  private sendScheduled(hoursFromNow: number): void {
    const text = this.inputText.trim();
    if (text.length > 0) {
      const sendDate = Math.floor(Date.now() / 1000) + hoursFromNow * 3600;
      this.onSendScheduled(text, sendDate);
      this.inputText = '';
      this.showSchedulePicker = false;
    }
  }

  @Builder
  schedulePickerPanel() {
    Column() {
      Text($r('app.string.schedule_message'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 16, bottom: 12 })

      this.scheduleOption($r('app.string.schedule_in_1h'), 1)
      Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
      this.scheduleOption($r('app.string.schedule_in_2h'), 2)
      Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
      this.scheduleOption($r('app.string.schedule_in_4h'), 4)
      Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
      this.scheduleOption($r('app.string.schedule_tomorrow_morning'), 18)
      Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
      this.scheduleOption($r('app.string.schedule_tomorrow_evening'), 30)

      Button($r('app.string.cancel'))
        .width('90%')
        .height(44)
        .fontSize(20)
        .fontColor($r('app.color.telegram_blue'))
        .backgroundColor($r('app.color.background_secondary'))
        .borderRadius(12)
        .margin({ top: 12, bottom: 16 })
        .onClick(() => { this.showSchedulePicker = false; })
    }
    .width('100%')
    .backgroundColor($r('app.color.background_primary'))
    .borderRadius({ topLeft: 16, topRight: 16 })
  }

  @Builder
  scheduleOption(label: ResourceStr, hoursFromNow: number) {
    Row() {
      Image($r('app.media.ic_settings'))
        .width(20).height(20)
        .fillColor($r('app.color.telegram_blue'))
        .margin({ right: 12 })
      Text(label)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .onClick(() => { this.sendScheduled(hoursFromNow); })
  }
}

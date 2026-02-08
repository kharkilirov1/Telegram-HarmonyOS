// Chat input bar with emoji, stickers, GIF, attachments, voice recording
// Reference: Telegram iOS ChatInputBar, Android ChatActivityEnterView

import { Message } from '../../models/Message';
import { EmojiPicker } from './EmojiPicker';
import { AttachmentPanel } from './AttachmentPanel';
import { StickerPicker } from './StickerPicker';
import { GifPicker } from './GifPicker';

@ComponentV2
export struct ChatInputBar {
  @Local inputText: string = '';
  @Local isRecording: boolean = false;
  @Local recordingDuration: number = 0;
  @Local recordingLocked: boolean = false;
  @Local recordingCancelled: boolean = false;
  @Local slideOffsetX: number = 0;
  @Local slideOffsetY: number = 0;
  @Local showEmojiPicker: boolean = false;
  @Local showAttachPanel: boolean = false;
  @Local showStickerPicker: boolean = false;
  @Local showGifPicker: boolean = false;
  @Param replyMessage: Message | null = null;
  @Param editMessage: Message | null = null;

  @Param onSendMessage: (text: string) => void = () => {};
  @Param onEditMessage: (messageId: number, text: string) => void = () => {};
  @Param onAttachTap: () => void = () => {};
  @Param onCancelReply: () => void = () => {};
  @Param onCancelEdit: () => void = () => {};
  @Param onSendSticker: (emoji: string) => void = () => {};
  @Param onSendGif: (gifId: number) => void = () => {};
  @Param onSendVoice: (duration: number) => void = () => {};

  private recordingTimerId: number = -1;

  aboutToAppear(): void {
    if (this.editMessage !== null) {
      this.inputText = this.editMessage.text;
    }
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
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.telegram_blue'))
              .maxLines(1)
            Text(this.replyMessage.text)
              .fontSize(13)
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
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.telegram_blue'))
              .maxLines(1)
            Text(this.editMessage.text)
              .fontSize(13)
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
          this.buildRecordingUI()
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
            .borderRadius(18)
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .onChange((value: string) => { this.inputText = value; })
            .onFocus(() => { this.closeAllPanels(); })

          // Send / Mic toggle
          if (this.inputText.trim().length > 0) {
            Image(this.editMessage !== null ? $r('app.media.ic_check_single') : $r('app.media.ic_send'))
              .width(28).height(28)
              .fillColor($r('app.color.telegram_blue'))
              .margin({ left: 6 })
              .accessibilityText($r('app.string.accessibility_send'))
              .onClick(() => {
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

      // Panel selector tabs (emoji / stickers / gifs) — like Telegram Android
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
          onPoll: () => { this.showAttachPanel = false; },
          onClose: () => { this.showAttachPanel = false; }
        })
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

  @Builder
  buildRecordingUI() {
    if (this.recordingLocked) {
      // Locked recording mode — shows waveform preview + delete/send
      Row() {
        // Delete (trash) button
        Image($r('app.media.ic_delete'))
          .width(24).height(24)
          .fillColor($r('app.color.error_red'))
          .onClick(() => { this.cancelRecording(); })

        // Recording indicator + timer
        Row() {
          Circle()
            .width(8).height(8)
            .fill($r('app.color.recording_red'))

          Text(this.formatRecordingDuration())
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .margin({ left: 6 })
        }
        .margin({ left: 12 })

        // Waveform preview bars
        Row({ space: 1 }) {
          ForEach(this.generateLiveWaveform(), (amp: number, index: number) => {
            Column()
              .width(3)
              .height(amp * 20)
              .borderRadius(1.5)
              .backgroundColor($r('app.color.telegram_blue'))
          }, (_amp: number, index: number) => index.toString())
        }
        .height(22)
        .alignItems(VerticalAlign.Center)
        .margin({ left: 12 })
        .layoutWeight(1)

        // Send button
        Image($r('app.media.ic_send'))
          .width(28).height(28)
          .fillColor($r('app.color.telegram_blue'))
          .margin({ left: 8 })
          .onClick(() => { this.stopRecording(); })
      }
      .width('100%')
    } else {
      // Slide-to-cancel mode — finger is held down
      Row() {
        Circle()
          .width(10).height(10)
          .fill($r('app.color.recording_red'))

        Text(this.formatRecordingDuration())
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 8 })

        Blank().layoutWeight(1)

        Row() {
          Image($r('app.media.ic_back'))
            .width(14).height(14)
            .fillColor($r('app.color.text_secondary'))
            .opacity(Math.min(1, Math.abs(this.slideOffsetX) / 60 + 0.4))
          Text($r('app.string.slide_to_cancel'))
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ left: 4 })
        }
        .translate({ x: this.slideOffsetX * 0.5 })

        Blank().layoutWeight(1)

        // Lock indicator (slide up to lock)
        Column() {
          Image($r('app.media.ic_pin'))
            .width(16).height(16)
            .fillColor($r('app.color.text_secondary'))
        }
        .width(28).height(28)
        .borderRadius(14)
        .backgroundColor($r('app.color.background_secondary'))
        .justifyContent(FlexAlign.Center)
        .opacity(this.slideOffsetY < -20 ? 1 : 0.5)
        .margin({ right: 4 })

        // Stop/send recording button
        Image($r('app.media.ic_send'))
          .width(28).height(28)
          .fillColor($r('app.color.telegram_blue'))
          .onClick(() => { this.stopRecording(); })
      }
      .width('100%')
      .gesture(
        PanGesture({ direction: PanDirection.Horizontal | PanDirection.Vertical })
          .onActionUpdate((event: GestureEvent) => {
            this.slideOffsetX = Math.min(0, event.offsetX);
            this.slideOffsetY = Math.min(0, event.offsetY);
          })
          .onActionEnd(() => {
            if (this.slideOffsetX < -100) {
              // Slid far enough left → cancel
              this.cancelRecording();
            } else if (this.slideOffsetY < -60) {
              // Slid far enough up → lock recording
              this.recordingLocked = true;
            }
            this.slideOffsetX = 0;
            this.slideOffsetY = 0;
          })
      )
    }
  }

  private formatRecordingDuration(): string {
    const m = Math.floor(this.recordingDuration / 60);
    const s = this.recordingDuration % 60;
    return `${m}:${s.toString().padStart(2, '0')}`;
  }

  private startRecording(): void {
    this.isRecording = true;
    this.recordingDuration = 0;
    this.recordingLocked = false;
    this.recordingCancelled = false;
    this.slideOffsetX = 0;
    this.slideOffsetY = 0;
    this.closeAllPanels();

    // Timer for recording duration display
    this.recordingTimerId = setInterval(() => {
      this.recordingDuration++;
    }, 1000);
  }

  private stopRecording(): void {
    const duration = this.recordingDuration;
    this.resetRecordingState();

    // Send voice message via callback (AudioCapturer would provide actual audio data)
    if (duration > 0) {
      this.onSendVoice(duration);
    }
  }

  private cancelRecording(): void {
    this.recordingCancelled = true;
    this.resetRecordingState();
  }

  private resetRecordingState(): void {
    this.isRecording = false;
    this.recordingLocked = false;
    this.slideOffsetX = 0;
    this.slideOffsetY = 0;
    if (this.recordingTimerId >= 0) {
      clearInterval(this.recordingTimerId);
      this.recordingTimerId = -1;
    }
  }

  private generateLiveWaveform(): number[] {
    // Generate dynamic waveform bars based on recording duration for visual feedback
    const bars: number[] = [];
    const count = 20;
    for (let i = 0; i < count; i++) {
      const base = 0.3 + 0.4 * Math.sin((this.recordingDuration * 2 + i) * 0.8);
      bars.push(Math.min(1, Math.max(0.15, base)));
    }
    return bars;
  }

  private closeAllPanels(): void {
    this.showEmojiPicker = false;
    this.showStickerPicker = false;
    this.showGifPicker = false;
    this.showAttachPanel = false;
  }
}

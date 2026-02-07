import { Message } from '../../models/Message';
import { EmojiPicker } from './EmojiPicker';
import { AttachmentPanel } from './AttachmentPanel';

@ComponentV2
export struct ChatInputBar {
  @Local inputText: string = '';
  @Local isRecording: boolean = false;
  @Local recordingDuration: number = 0;
  @Local showEmojiPicker: boolean = false;
  @Local showAttachPanel: boolean = false;
  @Param replyMessage: Message | null = null;
  @Param editMessage: Message | null = null;

  @Param onSendMessage: (text: string) => void = () => {};
  @Param onEditMessage: (messageId: number, text: string) => void = () => {};
  @Param onAttachTap: () => void = () => {};
  @Param onCancelReply: () => void = () => {};
  @Param onCancelEdit: () => void = () => {};

  aboutToAppear(): void {
    // Pre-fill text when editing a message
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
            .width(18)
            .height(18)
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
            .width(18)
            .height(18)
            .fillColor($r('app.color.text_secondary'))
            .onClick(() => this.onCancelReply())
        }
        .width('100%')
        .height(40)
        .padding({ left: 12, right: 12 })
        .backgroundColor($r('app.color.background_primary'))

        Divider().strokeWidth(0.5).color($r('app.color.separator'))
      }

      // Edit bar (like Telegram — blue edit icon + "Editing" label)
      if (this.editMessage !== null) {
        Row() {
          Image($r('app.media.ic_edit'))
            .width(18)
            .height(18)
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
            .width(18)
            .height(18)
            .fillColor($r('app.color.text_secondary'))
            .onClick(() => {
              this.onCancelEdit();
              this.inputText = '';
            })
        }
        .width('100%')
        .height(40)
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
          // Emoji button — toggles emoji picker (like Android Telegram)
          Image(this.showEmojiPicker ? $r('app.media.ic_close') : $r('app.media.ic_emoji'))
            .width(24)
            .height(24)
            .fillColor($r('app.color.text_secondary'))
            .margin({ right: 6 })
            .onClick(() => {
              this.showEmojiPicker = !this.showEmojiPicker;
              this.showAttachPanel = false;
            })

          // Attach button — toggles attachment panel
          Image($r('app.media.ic_attach'))
            .width(24)
            .height(24)
            .fillColor($r('app.color.text_secondary'))
            .onClick(() => {
              this.showAttachPanel = !this.showAttachPanel;
              this.showEmojiPicker = false;
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
            .onChange((value: string) => {
              this.inputText = value;
            })
            .onFocus(() => {
              this.showEmojiPicker = false;
              this.showAttachPanel = false;
            })

          // Send / Mic toggle
          if (this.inputText.trim().length > 0) {
            Image(this.editMessage !== null ? $r('app.media.ic_check_single') : $r('app.media.ic_send'))
              .width(28)
              .height(28)
              .fillColor($r('app.color.telegram_blue'))
              .margin({ left: 6 })
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
              .width(24)
              .height(24)
              .fillColor($r('app.color.text_secondary'))
              .margin({ left: 6 })
              .gesture(
                LongPressGesture({ repeat: false, duration: 200 })
                  .onAction(() => {
                    this.startRecording();
                  })
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

      // Emoji picker panel (slides up like Telegram Android)
      if (this.showEmojiPicker) {
        EmojiPicker({
          onEmojiSelected: (emoji: string) => {
            this.inputText += emoji;
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
  buildRecordingUI() {
    Row() {
      Circle()
        .width(10)
        .height(10)
        .fill($r('app.color.recording_red'))

      Text(this.formatRecordingDuration())
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .margin({ left: 8 })

      Blank().layoutWeight(1)

      Row() {
        Image($r('app.media.ic_back'))
          .width(14)
          .height(14)
          .fillColor($r('app.color.text_secondary'))
        Text($r('app.string.slide_to_cancel'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 4 })
      }

      Blank().layoutWeight(1)
    }
    .width('100%')
  }

  private formatRecordingDuration(): string {
    const m = Math.floor(this.recordingDuration / 60);
    const s = this.recordingDuration % 60;
    return `${m}:${s.toString().padStart(2, '0')}`;
  }

  private startRecording(): void {
    this.isRecording = true;
    this.recordingDuration = 0;
    this.showEmojiPicker = false;
    this.showAttachPanel = false;
  }
}

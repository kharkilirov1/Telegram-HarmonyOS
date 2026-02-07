import { Message, MessageContentType } from '../../models/Message';

@Component
export struct MessageBubble {
  @ObjectLink message: Message;
  @Prop isFirstInGroup: boolean = true;
  @Prop isLastInGroup: boolean = true;
  @Prop showSenderName: boolean = false;

  build() {
    Column() {
      Row() {
        // Avatar space for incoming messages
        if (!this.message.isOutgoing) {
          if (this.isLastInGroup && this.showSenderName) {
            // Show avatar on last message in group
            Text(this.getInitial())
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .width(34)
              .height(34)
              .borderRadius(17)
              .backgroundColor(this.getSenderColor())
              .textAlign(TextAlign.Center)
              .margin({ right: 6 })
              .alignSelf(ItemAlign.End)
          } else {
            Blank().width(40)
          }
        }

        // Bubble content
        Column() {
          // Reply quote
          if (this.message.replyToMessageId > 0 && this.message.replyPreviewText.length > 0) {
            Row() {
              Divider()
                .vertical(true)
                .strokeWidth(2)
                .color($r('app.color.telegram_blue'))
                .height('100%')

              Column() {
                Text(this.message.replyPreviewSenderName)
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.telegram_blue'))
                  .maxLines(1)

                Text(this.message.replyPreviewText)
                  .fontSize(13)
                  .fontColor($r('app.color.text_secondary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .margin({ left: 8 })
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .height(36)
            .margin({ bottom: 4 })
          }

          // Forwarded header
          if (this.message.forwardedFrom.length > 0) {
            Row() {
              Image($r('app.media.ic_forward'))
                .width(14)
                .height(14)
                .fillColor($r('app.color.telegram_blue'))
                .margin({ right: 4 })
              Text(this.message.forwardedFrom)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.telegram_blue'))
                .fontStyle(FontStyle.Italic)
            }
            .margin({ bottom: 4 })
          }

          // Sender name (groups, first in group only)
          if (!this.message.isOutgoing && this.showSenderName && this.isFirstInGroup) {
            Text(this.message.senderName)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getSenderColor())
              .margin({ bottom: 2 })
          }

          // --- Content by type ---
          if (this.message.contentType === MessageContentType.STICKER) {
            this.buildSticker()
          } else if (this.message.contentType === MessageContentType.PHOTO) {
            this.buildPhoto()
          } else if (this.message.contentType === MessageContentType.VOICE) {
            this.buildVoice()
          } else if (this.message.contentType === MessageContentType.VIDEO) {
            this.buildVideo()
          } else if (this.message.contentType === MessageContentType.DOCUMENT) {
            this.buildDocument()
          } else {
            this.buildText()
          }
        }
        .padding(this.message.contentType === MessageContentType.STICKER ? 0 :
          this.message.contentType === MessageContentType.PHOTO ? 2 :
            { left: 10, right: 10, top: 6, bottom: 6 })
        .borderRadius(this.getBubbleRadii())
        .backgroundColor(this.getBubbleColor())
        .constraintSize({ maxWidth: '75%' })
      }
      .width('100%')
      .justifyContent(this.message.isOutgoing ? FlexAlign.End : FlexAlign.Start)
      .padding({ left: 8, right: 8 })
    }
    .width('100%')
    .margin({
      top: this.isFirstInGroup ? 6 : 1,
      bottom: this.isLastInGroup ? 6 : 1
    })
  }

  // --- Bubble shape: tail on last message of group ---
  private getBubbleRadii(): BorderRadiuses {
    const r = 17;
    const tailR = 4;
    if (this.message.contentType === MessageContentType.STICKER) {
      return { topLeft: 0, topRight: 0, bottomLeft: 0, bottomRight: 0 };
    }
    if (!this.isLastInGroup) {
      return { topLeft: r, topRight: r, bottomLeft: r, bottomRight: r };
    }
    if (this.message.isOutgoing) {
      return { topLeft: r, topRight: r, bottomLeft: r, bottomRight: tailR };
    }
    return { topLeft: r, topRight: r, bottomLeft: tailR, bottomRight: r };
  }

  private getBubbleColor(): ResourceColor {
    if (this.message.contentType === MessageContentType.STICKER) {
      return Color.Transparent;
    }
    return this.message.isOutgoing
      ? $r('app.color.chat_bubble_outgoing')
      : $r('app.color.chat_bubble_incoming');
  }

  // --- Content builders ---

  @Builder
  buildText() {
    Column() {
      Text(this.message.text)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .lineHeight(21)

      this.buildTimeRow()
    }
  }

  @Builder
  buildPhoto() {
    Column() {
      Stack({ alignContent: Alignment.BottomEnd }) {
        if (this.message.photoUrl) {
          Image(this.message.photoUrl)
            .width('100%')
            .borderRadius(15)
            .objectFit(ImageFit.Cover)
        }

        // Time overlay on photo
        Row() {
          Text(this.formatTime(this.message.date))
            .fontSize(11)
            .fontColor(Color.White)
          if (this.message.isOutgoing) {
            this.buildCheckmarks(Color.White)
          }
        }
        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        .borderRadius(10)
        .backgroundColor($r('app.color.time_overlay'))
        .margin({ right: 6, bottom: 6 })
      }

      // Caption
      if (this.message.text.length > 0) {
        Text(this.message.text)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 8, right: 8, top: 4 })
        this.buildTimeRow()
      }
    }
  }

  @Builder
  buildSticker() {
    Column() {
      if (this.message.stickerUrl) {
        Image(this.message.stickerUrl)
          .width(160)
          .height(160)
          .objectFit(ImageFit.Contain)
      } else {
        Text(this.message.text)
          .fontSize(64)
      }
      this.buildTimeRow()
    }
  }

  @Builder
  buildVoice() {
    Row() {
      Image($r('app.media.ic_play'))
        .width(32)
        .height(32)
        .fillColor($r('app.color.telegram_blue'))

      Column() {
        // Waveform bars
        Row({ space: 1 }) {
          ForEach(this.message.voiceWaveform.length > 0
            ? this.message.voiceWaveform
            : [0.3, 0.5, 0.8, 1.0, 0.7, 0.4, 0.6, 0.9, 0.5, 0.3,
              0.7, 0.8, 0.4, 0.6, 0.9, 0.5, 0.3, 0.7, 0.4, 0.6],
            (amp: number, idx: number) => {
              Column()
                .width(2)
                .height(amp * 20)
                .borderRadius(1)
                .backgroundColor($r('app.color.telegram_blue'))
            })
        }
        .height(24)
        .alignItems(VerticalAlign.Center)

        Text(this.formatDuration(this.message.voiceDuration))
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
      }
      .margin({ left: 8 })
      .layoutWeight(1)
    }
    .width('100%')
  }

  @Builder
  buildVideo() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.message.photoUrl) {
        Image(this.message.photoUrl)
          .width('100%')
          .borderRadius(15)
          .objectFit(ImageFit.Cover)
      }

      // Play button overlay
      Circle()
        .width(48)
        .height(48)
        .fill($r('app.color.play_overlay'))

      Image($r('app.media.ic_play'))
        .width(24)
        .height(24)
        .fillColor(Color.White)

      // Duration badge
      if (this.message.videoDuration > 0) {
        Text(this.formatDuration(this.message.videoDuration))
          .fontSize(11)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.time_overlay'))
          .borderRadius(4)
          .padding({ left: 4, right: 4, top: 1, bottom: 1 })
          .position({ x: 8, y: 8 })
      }
    }
  }

  @Builder
  buildDocument() {
    Row() {
      Image($r('app.media.ic_document'))
        .width(40)
        .height(40)
        .fillColor($r('app.color.telegram_blue'))

      Column() {
        Text(this.message.fileName || $r('app.string.document_label'))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.telegram_blue'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text($r('app.string.file_label'))
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
      }
      .margin({ left: 10 })
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      this.buildTimeRow()
    }
    .width('100%')
  }

  // --- Time + checkmarks row ---

  @Builder
  buildTimeRow() {
    Row() {
      Blank().layoutWeight(1)
      Text(this.formatTime(this.message.date))
        .fontSize(11)
        .fontColor($r('app.color.text_secondary'))
      if (this.message.isOutgoing) {
        this.buildCheckmarks($r('app.color.text_secondary'))
      }
    }
    .width('100%')
    .margin({ top: 2 })
  }

  @Builder
  buildCheckmarks(tint: ResourceColor) {
    Image(this.message.isRead ? $r('app.media.ic_check_double') : $r('app.media.ic_check_single'))
      .width(16)
      .height(16)
      .fillColor(this.message.isRead ? $r('app.color.telegram_blue') : tint)
      .margin({ left: 3 })
  }

  // --- Helpers ---

  private getSenderColor(): ResourceColor {
    const colors: Resource[] = [
      $r('app.color.sender_color_1'), $r('app.color.sender_color_2'),
      $r('app.color.sender_color_3'), $r('app.color.sender_color_4'),
      $r('app.color.sender_color_5'), $r('app.color.sender_color_6'),
      $r('app.color.sender_color_7')
    ];
    return colors[Math.abs(this.message.senderId) % colors.length];
  }

  private getInitial(): string {
    return this.message.senderName.length > 0
      ? this.message.senderName.charAt(0)
      : '?';
  }

  private formatTime(timestamp: number): string {
    if (timestamp === 0) return '';
    const date = new Date(timestamp * 1000);
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' } as Intl.DateTimeFormatOptions);
  }

  private formatDuration(seconds: number): string {
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return `${m}:${s.toString().padStart(2, '0')}`;
  }
}

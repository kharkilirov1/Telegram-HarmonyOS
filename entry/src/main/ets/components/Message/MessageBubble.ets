import { Message, MessageContentType, MessageReaction, PollOption } from '../../models/Message';
import { ReactionBar } from './ReactionBar';
import { PollBubble } from './PollBubble';

// URL detection regex
const URL_REGEX = /https?:\/\/[^\s<>"{}|\\^`\[\]]+/gi;

@ComponentV2
export struct MessageBubble {
  @Param message: Message = new Message();
  @Param isFirstInGroup: boolean = true;
  @Param isLastInGroup: boolean = true;
  @Param showSenderName: boolean = false;
  @Event onReply: (message: Message) => void = () => {};
  @Event onForward: (message: Message) => void = () => {};
  @Event onCopy: (message: Message) => void = () => {};
  @Event onDelete: (message: Message) => void = () => {};
  @Event onEdit: (message: Message) => void = () => {};
  @Event onMediaTap: (url: string) => void = () => {};
  @Event onVideoPlay: (url: string, duration: number) => void = () => {};
  @Event onReactionTap: (message: Message, emoji: string) => void = () => {};
  @Event onPollVote: (message: Message, optionIndex: number) => void = () => {};
  @Param isSelectionMode: boolean = false;
  @Param isSelected: boolean = false;
  @Event onSelect: (message: Message) => void = () => {};

  @Local swipeOffsetX: number = 0;
  @Local downloadProgress: number = -1; // -1 = not downloading, 0..100 = progress
  @Local spoilerRevealed: boolean = false;
  @Local viewOnceOpened: boolean = false;

  build() {
    Column() {
      Row() {
        // Selection checkbox (multi-select mode like iOS/Android)
        if (this.isSelectionMode) {
          Checkbox()
            .select(this.isSelected)
            .selectedColor($r('app.color.telegram_blue'))
            .width(22).height(22)
            .margin({ right: 8 })
            .onChange((value: boolean) => { this.onSelect(this.message); })
        }

        // Avatar space for incoming messages
        if (!this.message.isOutgoing) {
          if (this.isLastInGroup && this.showSenderName) {
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

          // View-once indicator
          if (this.message.isViewOnce && !this.viewOnceOpened) {
            this.buildViewOnce()
          } else if (this.message.contentType === MessageContentType.STICKER) {
            this.buildSticker()
          } else if (this.message.contentType === MessageContentType.PHOTO) {
            this.buildPhoto()
          } else if (this.message.contentType === MessageContentType.VOICE) {
            this.buildVoice()
          } else if (this.message.contentType === MessageContentType.VIDEO) {
            this.buildVideo()
          } else if (this.message.contentType === MessageContentType.DOCUMENT) {
            this.buildDocument()
          } else if (this.message.contentType === MessageContentType.VIDEO_NOTE) {
            this.buildVideoNote()
          } else if (this.message.contentType === MessageContentType.POLL) {
            PollBubble({
              message: this.message,
              onVote: (msg: Message, optionIndex: number) => { this.onPollVote(msg, optionIndex); }
            })
          } else {
            this.buildText()
          }
        }
        .padding(this.message.contentType === MessageContentType.STICKER ? 0 :
          this.message.contentType === MessageContentType.PHOTO ? 2 :
            this.message.contentType === MessageContentType.VIDEO_NOTE ? 0 :
              { left: 10, right: 10, top: 6, bottom: 6 })
        .borderRadius(this.getBubbleRadii())
        .backgroundColor(this.getBubbleColor())
        .constraintSize({ maxWidth: '75%' })
        .gesture(
          GestureGroup(GestureMode.Exclusive,
            LongPressGesture()
              .onAction(() => {
                if (this.isSelectionMode) {
                  this.onSelect(this.message);
                } else {
                  this.showMessageActions();
                }
              }),
            // Swipe-to-reply: horizontal pan gesture (like Telegram iOS/Android)
            PanGesture({ direction: PanDirection.Left, distance: 20 })
              .onActionUpdate((event: GestureEvent) => {
                const offsetX = event.offsetX;
                if (offsetX < 0) {
                  this.swipeOffsetX = Math.max(offsetX, -80);
                }
              })
              .onActionEnd(() => {
                if (this.swipeOffsetX < -50) {
                  this.onReply(this.message);
                }
                this.swipeOffsetX = 0;
              })
          )
        )
        .translate({ x: this.swipeOffsetX })
      }
      .width('100%')
      .justifyContent(this.message.isOutgoing ? FlexAlign.End : FlexAlign.Start)
      .padding({ left: 8, right: 8 })

      // Swipe reply indicator arrow
      if (this.swipeOffsetX < -20) {
        Row() {
          Blank()
          Image($r('app.media.ic_reply'))
            .width(20).height(20)
            .fillColor($r('app.color.telegram_blue'))
            .opacity(Math.min(1, Math.abs(this.swipeOffsetX) / 50))
        }
        .width('100%')
        .padding({ right: 16 })
        .position({ y: 0 })
      }

      // Reaction bar below bubble (like Telegram iOS/Android)
      if (this.message.reactions.length > 0) {
        ReactionBar({
          reactions: this.message.reactions,
          isOutgoing: this.message.isOutgoing,
          onReactionTap: (emoji: string) => {
            this.onReactionTap(this.message, emoji);
          },
          onAddReaction: () => {
            this.onReactionTap(this.message, '');
          }
        })
      }
    }
    .width('100%')
    .margin({
      top: this.isFirstInGroup ? 6 : 1,
      bottom: this.isLastInGroup ? 6 : 1
    })
  }

  private showMessageActions(): void {
    // Build action list — Edit only for own messages (like Telegram)
    const buttons: Array<AlertDialogButtonOptions> = [
      {
        value: $r('app.string.reply'),
        action: () => { this.onReply(this.message); }
      },
      {
        value: $r('app.string.forward'),
        action: () => { this.onForward(this.message); }
      },
      {
        value: $r('app.string.copy'),
        action: () => { this.onCopy(this.message); }
      }
    ];

    // Edit is only available for outgoing text messages (like Telegram)
    if (this.message.isOutgoing && this.message.contentType === MessageContentType.TEXT) {
      buttons.push({
        value: $r('app.string.edit'),
        action: () => { this.onEdit(this.message); }
      });
    }

    buttons.push({
      value: $r('app.string.delete'),
      fontColor: $r('app.color.error_red'),
      action: () => { this.onDelete(this.message); }
    });

    AlertDialog.show({
      title: undefined,
      message: undefined,
      buttons: buttons
    });
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
      // Detect URLs and render as rich text (reference: Telegram link rendering)
      if (this.containsUrl(this.message.text)) {
        this.buildRichText()
      } else if (this.message.hasSpoiler && !this.spoilerRevealed) {
        // Spoiler text — blurred until tapped
        Text(this.message.text)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .lineHeight(21)
          .blur(15)
          .onClick(() => { this.spoilerRevealed = true; })
      } else {
        Text(this.message.text)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .lineHeight(21)
      }

      // Link preview card (if URL detected)
      if (this.containsUrl(this.message.text)) {
        this.buildLinkPreview()
      }

      this.buildTimeRow()
    }
  }

  @Builder
  buildRichText() {
    Text() {
      ForEach(this.splitByUrls(this.message.text), (part: TextPart, index: number) => {
        if (part.isUrl) {
          Span(part.text)
            .fontColor($r('app.color.telegram_blue'))
            .decoration({ type: TextDecorationType.Underline, color: $r('app.color.telegram_blue') })
        } else {
          Span(part.text)
            .fontColor($r('app.color.text_primary'))
        }
      }, (_part: TextPart, index: number) => index.toString())
    }
    .fontSize(16)
    .lineHeight(21)
  }

  @Builder
  buildLinkPreview() {
    // Minimal link preview card (like Telegram — site name, title, description)
    Column() {
      Divider()
        .strokeWidth(2)
        .color($r('app.color.telegram_blue'))
        .width('100%')

      Text(this.extractDomain(this.message.text))
        .fontSize(12)
        .fontColor($r('app.color.telegram_blue'))
        .fontWeight(FontWeight.Medium)
        .margin({ top: 4 })
        .maxLines(1)

      Text(this.extractDomain(this.message.text))
        .fontSize(14)
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Medium)
        .margin({ top: 2 })
        .maxLines(1)
    }
    .width('100%')
    .padding({ left: 8, top: 4, bottom: 4 })
    .margin({ top: 4 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildPhoto() {
    Column() {
      Stack({ alignContent: Alignment.BottomEnd }) {
        if (this.message.photoUrl) {
          Image(this.message.photoUrl)
            .alt($r('app.media.ic_photo'))
            .autoResize(true)
            .onError(() => {})
            .width('100%')
            .borderRadius(15)
            .objectFit(ImageFit.Cover)
            .blur(this.message.hasSpoiler && !this.spoilerRevealed ? 40 : 0)
            .onClick(() => {
              if (this.message.hasSpoiler && !this.spoilerRevealed) {
                this.spoilerRevealed = true;
              } else if (this.message.photoUrl) {
                this.onMediaTap(this.message.photoUrl);
              }
            })
        } else {
          // Photo placeholder (stub mode)
          Column() {
            Image($r('app.media.ic_photo'))
              .width(48)
              .height(48)
              .fillColor(Color.White)
              .opacity(0.7)
          }
          .width('100%')
          .height(180)
          .borderRadius(15)
          .backgroundColor('#E0E0E0')
          .justifyContent(FlexAlign.Center)
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
          .alt($r('app.media.ic_sticker'))
          .autoResize(true)
          .onError(() => {})
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
    Column() {
      Row() {
        Image($r('app.media.ic_play'))
          .width(36)
          .height(36)
          .fillColor(Color.White)
          .backgroundColor($r('app.color.telegram_blue'))
          .borderRadius(18)
          .padding(8)

        Column() {
          // Waveform bars with gradient-like effect
          Row({ space: 1 }) {
            ForEach(this.message.voiceWaveform.length > 0
              ? this.message.voiceWaveform
              : [0.3, 0.5, 0.8, 1.0, 0.7, 0.4, 0.6, 0.9, 0.5, 0.3,
                0.7, 0.8, 0.4, 0.6, 0.9, 0.5, 0.3, 0.7, 0.4, 0.6],
              (amp: number, idx: number) => {
                Column()
                  .width(3)
                  .height(amp * 24)
                  .borderRadius(1.5)
                  .backgroundColor($r('app.color.telegram_blue'))
              }, (_amp: number, index: number) => index.toString())
          }
          .height(28)
          .alignItems(VerticalAlign.Center)

          Row() {
            Text(this.formatDuration(this.message.voiceDuration))
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
            Blank().layoutWeight(1)
          }
          .width('100%')
          .margin({ top: 2 })
        }
        .margin({ left: 10 })
        .layoutWeight(1)
      }
      .width('100%')

      this.buildTimeRow()
    }
  }

  @Builder
  buildVideo() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        if (this.message.photoUrl) {
          Image(this.message.photoUrl)
            .alt($r('app.media.ic_photo'))
            .autoResize(true)
            .onError(() => {})
            .width('100%')
            .height(200)
            .borderRadius(15)
            .objectFit(ImageFit.Cover)
            .blur(this.message.hasSpoiler && !this.spoilerRevealed ? 40 : 0)
        } else {
          // Video placeholder (stub mode)
          Column()
            .width('100%')
            .height(200)
            .borderRadius(15)
            .backgroundColor('#333333')
        }

        if (this.message.hasSpoiler && !this.spoilerRevealed) {
          // Spoiler: tap to reveal
          Text($r('app.string.tap_to_reveal'))
            .fontSize(14)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Medium)
        } else {
          // Play button overlay
          Column() {
            Image($r('app.media.ic_play'))
              .width(28)
              .height(28)
              .fillColor(Color.White)
          }
          .width(52)
          .height(52)
          .borderRadius(26)
          .backgroundColor($r('app.color.play_overlay'))
          .justifyContent(FlexAlign.Center)
        }

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
      .onClick(() => {
        if (this.message.hasSpoiler && !this.spoilerRevealed) {
          this.spoilerRevealed = true;
        } else {
          this.onVideoPlay(this.message.photoUrl || '', this.message.videoDuration);
        }
      })

      // Caption
      if (this.message.text.length > 0) {
        Text(this.message.text)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 8, right: 8, top: 4 })
      }
    }
  }

  @Builder
  buildDocument() {
    Column() {
      Row() {
        // Document icon with download progress overlay
        Stack({ alignContent: Alignment.Center }) {
          if (this.downloadProgress >= 0 && this.downloadProgress < 100) {
            // Download in progress — circular progress ring
            Progress({ value: this.downloadProgress, total: 100, type: ProgressType.Ring })
              .width(44).height(44)
              .color($r('app.color.telegram_blue'))
              .backgroundColor($r('app.color.background_secondary'))
              .style({ strokeWidth: 3 })

            Image($r('app.media.ic_close'))
              .width(16).height(16)
              .fillColor($r('app.color.telegram_blue'))
          } else {
            Column() {
              Image(this.downloadProgress === 100
                ? $r('app.media.ic_document')
                : $r('app.media.ic_download'))
                .width(24).height(24)
                .fillColor(Color.White)
            }
            .width(44).height(44)
            .borderRadius(8)
            .backgroundColor($r('app.color.telegram_blue'))
            .justifyContent(FlexAlign.Center)
          }
        }
        .width(44).height(44)
        .onClick(() => {
          if (this.downloadProgress < 0) {
            this.simulateDownload();
          }
        })

        Column() {
          Text(this.message.fileName || $r('app.string.document_label'))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.telegram_blue'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Row() {
            if (this.downloadProgress >= 0 && this.downloadProgress < 100) {
              Text(`${this.downloadProgress}%`)
                .fontSize(13)
                .fontColor($r('app.color.telegram_blue'))
              Text(' \u2022 ')
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
            }
            Text(this.getFileSizeLabel())
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
          }
        }
        .margin({ left: 10 })
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.downloadProgress < 0) {
          Image($r('app.media.ic_download'))
            .width(22).height(22)
            .fillColor($r('app.color.telegram_blue'))
            .onClick(() => { this.simulateDownload(); })
        }
      }
      .width('100%')

      this.buildTimeRow()
    }
  }

  private getFileSizeLabel(): string {
    // File size from message metadata (stub: estimate from fileName)
    const ext = (this.message.fileName || '').split('.').pop()?.toLowerCase() || '';
    switch (ext) {
      case 'pdf': return 'PDF';
      case 'doc': case 'docx': return 'Word';
      case 'xls': case 'xlsx': return 'Excel';
      case 'zip': case 'rar': return 'Archive';
      case 'apk': return 'APK';
      case 'mp3': case 'ogg': return 'Audio';
      default: return 'File';
    }
  }

  private simulateDownload(): void {
    // Simulate file download progress for UI preview (real impl uses FileController)
    this.downloadProgress = 0;
    const timerId = setInterval(() => {
      this.downloadProgress += Math.floor(Math.random() * 15 + 5);
      if (this.downloadProgress >= 100) {
        this.downloadProgress = 100;
        clearInterval(timerId);
      }
    }, 300);
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

  @Builder
  buildVideoNote() {
    // Round video message (Telegram "video circles")
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        // Round video thumbnail or placeholder
        Column()
          .width(this.message.videoNoteLength > 0
            ? Math.min(this.message.videoNoteLength, 240)
            : 240)
          .height(this.message.videoNoteLength > 0
            ? Math.min(this.message.videoNoteLength, 240)
            : 240)
          .borderRadius(120)
          .backgroundColor('#333333')
          .clip(true)

        // Play button overlay
        Column() {
          Image($r('app.media.ic_play'))
            .width(24).height(24)
            .fillColor(Color.White)
        }
        .width(44).height(44)
        .borderRadius(22)
        .backgroundColor($r('app.color.play_overlay'))
        .justifyContent(FlexAlign.Center)
      }

      // Duration badge
      if (this.message.videoNoteDuration > 0) {
        Text(this.formatDuration(this.message.videoNoteDuration))
          .fontSize(11)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.time_overlay'))
          .borderRadius(8)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .margin({ top: -24 })
      }
    }
  }

  // --- View-once message (like Telegram "view once" photo/video) ---

  @Builder
  buildViewOnce() {
    Column() {
      Column() {
        Image($r('app.media.ic_photo'))
          .width(40).height(40)
          .fillColor($r('app.color.telegram_blue'))
          .opacity(0.6)
      }
      .width(200)
      .height(200)
      .borderRadius(15)
      .backgroundColor($r('app.color.background_secondary'))
      .justifyContent(FlexAlign.Center)
      .blur(30)

      Row() {
        Image($r('app.media.ic_view_once'))
          .width(16).height(16)
          .fillColor($r('app.color.telegram_blue'))
          .margin({ right: 4 })
        Text(this.message.contentType === MessageContentType.PHOTO
          ? $r('app.string.view_once_photo')
          : $r('app.string.view_once_video'))
          .fontSize(14)
          .fontColor($r('app.color.telegram_blue'))
          .fontWeight(FontWeight.Medium)
      }
      .margin({ top: 8 })
      .justifyContent(FlexAlign.Center)

      this.buildTimeRow()
    }
    .onClick(() => {
      this.viewOnceOpened = true;
    })
  }

  // --- Spoiler overlay for photos/videos ---

  @Builder
  buildSpoilerOverlay() {
    Column()
      .width('100%')
      .height('100%')
      .backgroundColor('#88000000')
      .blur(40)
      .justifyContent(FlexAlign.Center)
      .onClick(() => { this.spoilerRevealed = true; })
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
    const hours = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    const s = seconds % 60;
    if (hours > 0) {
      return `${hours}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
    }
    return `${m}:${s.toString().padStart(2, '0')}`;
  }

  // --- URL detection ---

  private containsUrl(text: string): boolean {
    return URL_REGEX.test(text);
  }

  private extractDomain(text: string): string {
    const match = text.match(URL_REGEX);
    if (match && match.length > 0) {
      try {
        const url = match[0];
        const domainMatch = url.match(/https?:\/\/([^/]+)/);
        return domainMatch ? domainMatch[1] : url;
      } catch (e) {
        return '';
      }
    }
    return '';
  }

  private splitByUrls(text: string): TextPart[] {
    const parts: TextPart[] = [];
    let lastIndex = 0;
    const regex = /https?:\/\/[^\s<>"{}|\\^`\[\]]+/gi;
    let match: RegExpExecArray | null;

    while ((match = regex.exec(text)) !== null) {
      if (match.index > lastIndex) {
        parts.push({ text: text.substring(lastIndex, match.index), isUrl: false });
      }
      parts.push({ text: match[0], isUrl: true });
      lastIndex = match.index + match[0].length;
    }

    if (lastIndex < text.length) {
      parts.push({ text: text.substring(lastIndex), isUrl: false });
    }

    return parts.length > 0 ? parts : [{ text: text, isUrl: false }];
  }
}

interface TextPart {
  text: string;
  isUrl: boolean;
}

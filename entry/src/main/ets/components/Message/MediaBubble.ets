import { Message, MessageContentType } from '../../models/Message';
import { MessageMetaRow } from './MessageMetaRow';
import { formatMediaDuration, formatMessageTime } from './MessageUtils';

@ComponentV2
export struct MediaBubble {
  @Param message: Message = new Message();
  @Event onMediaTap: (url: string, messageId: number, chatId: number) => void = () => {};
  @Event onVideoPlay: (url: string, duration: number) => void = () => {};

  @Local spoilerRevealed: boolean = false;
  @Local viewOnceOpened: boolean = false;

  build() {
    if (this.message.isViewOnce && !this.viewOnceOpened) {
      this.buildViewOnce()
    } else if (this.message.contentType === MessageContentType.STICKER) {
      this.buildSticker()
    } else if (this.message.contentType === MessageContentType.PHOTO) {
      this.buildPhoto()
    } else if (this.message.contentType === MessageContentType.VOICE) {
      this.buildVoice()
    } else if (this.message.contentType === MessageContentType.ANIMATION) {
      this.buildVideo()
    } else if (this.message.contentType === MessageContentType.VIDEO) {
      this.buildVideo()
    } else if (this.message.contentType === MessageContentType.VIDEO_NOTE) {
      this.buildVideoNote()
    } else {
      this.buildSticker()
    }
  }

  @Builder
  private buildPhoto() {
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
                this.onMediaTap(this.message.photoUrl, this.message.id, this.message.chatId);
              }
            })
        } else {
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
          .backgroundColor($r('app.color.placeholder_bg'))
          .justifyContent(FlexAlign.Center)
        }

        Row() {
          Text(formatMessageTime(this.message.date))
            .fontSize(11)
            .fontColor(Color.White)
          if (this.message.isOutgoing) {
            this.buildOverlayCheckmarks()
          }
        }
        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        .borderRadius(10)
        .backgroundColor($r('app.color.time_overlay'))
        .margin({ right: 6, bottom: 6 })
      }

      if (this.message.text.length > 0) {
        Text(this.message.text)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 8, right: 8, top: 4 })
        MessageMetaRow({
          date: this.message.date,
          isOutgoing: this.message.isOutgoing,
          isRead: this.message.isRead,
          tint: $r('app.color.text_secondary'),
          checkTint: $r('app.color.telegram_blue')
        })
      }
    }
  }

  @Builder
  private buildSticker() {
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
      MessageMetaRow({
        date: this.message.date,
        isOutgoing: this.message.isOutgoing,
        isRead: this.message.isRead,
        isEdited: this.message.isEdited,
        tint: $r('app.color.text_secondary'),
        checkTint: $r('app.color.telegram_blue')
      })
    }
  }

  @Builder
  private buildVoice() {
    Column() {
      Row() {
        Image($r('app.media.ic_play'))
          .width(36)
          .height(36)
          .fillColor(Color.White)
          .backgroundColor($r('app.color.telegram_blue'))
          .borderRadius(20)
          .padding(8)

        Column() {
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
            Text(formatMediaDuration(this.message.voiceDuration))
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

      MessageMetaRow({
        date: this.message.date,
        isOutgoing: this.message.isOutgoing,
        isRead: this.message.isRead,
        isEdited: this.message.isEdited,
        tint: $r('app.color.text_secondary'),
        checkTint: $r('app.color.telegram_blue')
      })
    }
  }

  @Builder
  private buildVideo() {
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
          Column()
            .width('100%')
            .height(200)
            .borderRadius(15)
            .backgroundColor($r('app.color.video_placeholder_bg'))
        }

        if (this.message.hasSpoiler && !this.spoilerRevealed) {
          Text($r('app.string.tap_to_reveal'))
            .fontSize(14)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Medium)
        } else {
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

        if (this.message.contentType === MessageContentType.ANIMATION) {
          Text($r('app.string.gif'))
            .fontSize(11)
            .fontColor(Color.White)
            .backgroundColor($r('app.color.time_overlay'))
            .borderRadius(4)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .position({ x: 8, y: 8 })
        } else if (this.message.videoDuration > 0) {
          Text(formatMediaDuration(this.message.videoDuration))
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
          const playableUrl: string = this.message.videoUrl || '';
          if (playableUrl.length > 0) {
            this.onVideoPlay(playableUrl, this.message.videoDuration);
          } else if (this.message.photoUrl) {
            this.onMediaTap(this.message.photoUrl, this.message.id, this.message.chatId);
          }
        }
      })

      if (this.message.text.length > 0) {
        Text(this.message.text)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 8, right: 8, top: 4 })
      }
    }
  }

  @Builder
  private buildVideoNote() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(this.message.videoNoteLength > 0
            ? Math.min(this.message.videoNoteLength, 240)
            : 240)
          .height(this.message.videoNoteLength > 0
            ? Math.min(this.message.videoNoteLength, 240)
            : 240)
          .borderRadius(120)
          .backgroundColor($r('app.color.video_placeholder_bg'))
          .clip(true)

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

      if (this.message.videoNoteDuration > 0) {
        Text(formatMediaDuration(this.message.videoNoteDuration))
          .fontSize(11)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.time_overlay'))
          .borderRadius(8)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .margin({ top: -24 })
      }
    }
  }

  @Builder
  private buildViewOnce() {
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

      MessageMetaRow({
        date: this.message.date,
        isOutgoing: this.message.isOutgoing,
        isRead: this.message.isRead,
        isEdited: this.message.isEdited,
        tint: $r('app.color.text_secondary'),
        checkTint: $r('app.color.telegram_blue')
      })
    }
    .onClick(() => { this.viewOnceOpened = true; })
  }

  @Builder
  private buildOverlayCheckmarks() {
    Image(this.message.isRead ? $r('app.media.ic_check_double') : $r('app.media.ic_check_single'))
      .width(16)
      .height(16)
      .fillColor(this.message.isRead ? $r('app.color.telegram_blue') : Color.White)
      .margin({ left: 3 })
  }
}

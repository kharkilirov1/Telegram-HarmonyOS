import { Message } from '../../models/Message';
import { MessageMetaRow } from './MessageMetaRow';
import { formatMediaDuration } from './MessageUtils';

@ComponentV2
export struct AudioBubble {
  @Param message: Message = new Message();
  @Local isPlaying: boolean = false;

  build() {
    Column() {
      Row() {
        // Play/Pause button — iOS: circular blue button
        Stack() {
          Circle()
            .width(44)
            .height(44)
            .fill($r('app.color.telegram_blue'))

          Image(this.isPlaying ? $r('app.media.ic_pause') : $r('app.media.ic_play'))
            .width(20)
            .height(20)
            .fillColor(Color.White)
        }
        .width(44)
        .height(44)
        .margin({ right: 10 })
        .onClick(() => { this.isPlaying = !this.isPlaying; })

        Column() {
          // Track title — iOS: semibold
          Text(this.getTitle())
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          // Performer
          Text(this.getPerformer())
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 1 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          // Progress bar + duration
          Row() {
            // Progress track
            Stack({ alignContent: Alignment.Start }) {
              // Background track
              Column()
                .width('100%')
                .height(2)
                .borderRadius(1)
                .backgroundColor($r('app.color.separator'))

              // Progress fill (placeholder at 0%)
              Column()
                .width(0)
                .height(2)
                .borderRadius(1)
                .backgroundColor($r('app.color.telegram_blue'))
            }
            .layoutWeight(1)
            .height(2)

            Text(formatMediaDuration(this.message.audioDuration))
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
              .margin({ left: 8 })
          }
          .width('100%')
          .margin({ top: 6 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      // Caption text
      if (this.message.text.length > 0) {
        Text(this.message.text)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .lineHeight(21)
          .margin({ top: 6 })
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
    .width('100%')
  }

  private getTitle(): string {
    return this.message.audioTitle.length > 0 ? this.message.audioTitle : 'Unknown Track';
  }

  private getPerformer(): string {
    return this.message.audioPerformer.length > 0 ? this.message.audioPerformer : 'Unknown Artist';
  }
}

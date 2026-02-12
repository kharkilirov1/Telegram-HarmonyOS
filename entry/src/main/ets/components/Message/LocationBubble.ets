import { Message, MessageContentType } from '../../models/Message';
import { MessageMetaRow } from './MessageMetaRow';
import { formatMessageTime } from './MessageUtils';

@ComponentV2
export struct LocationBubble {
  @Param message: Message = new Message();

  build() {
    Column() {
      // Map preview — iOS: 2:1 aspect ratio with pin at center
      Stack({ alignContent: Alignment.Center }) {
        // Map background with gradient — mimics iOS map tile
        Column()
          .width('100%')
          .height('100%')
          .borderRadius({ topLeft: 13, topRight: 13 })
          .linearGradient({
            angle: 135,
            colors: [['#D4E4F7', 0.0], ['#C8D8E8', 0.3], ['#E0EBF5', 0.7], ['#D0DFF0', 1.0]]
          })

        // Grid lines — subtle map pattern
        Column() {
          ForEach([0, 1, 2], (_: number, idx: number) => {
            Divider()
              .strokeWidth(0.5)
              .color('#C0D0E0')
              .width('100%')
              .margin({ top: idx === 0 ? 0 : 35 })
          }, (_: number, index: number) => index.toString())
        }
        .width('100%')
        .height('100%')
        .padding({ top: 20, bottom: 20 })
        .opacity(0.5)

        // Pin marker — iOS: centered in map area
        Column() {
          if (this.message.contentType === MessageContentType.LIVE_LOCATION) {
            // Live: pulsing blue dot (iOS: ChatMessageLiveLocationPositionNode)
            Stack() {
              Circle()
                .width(28)
                .height(28)
                .fill($r('app.color.telegram_blue'))
                .opacity(0.2)
              Circle()
                .width(14)
                .height(14)
                .fill($r('app.color.telegram_blue'))
              Circle()
                .width(6)
                .height(6)
                .fill(Color.White)
            }
          } else {
            // Static: red pin marker
            Column() {
              Image($r('app.media.ic_location'))
                .width(28)
                .height(28)
                .fillColor('#FF3B30')
            }
            .width(36)
            .height(36)
            .borderRadius(20)
            .backgroundColor(Color.White)
            .justifyContent(FlexAlign.Center)
            .shadow({ radius: 4, color: '#40000000', offsetY: 2 })
          }
        }
        .offset({ y: -4 })

        // iOS: timestamp overlay on map (bottom-right like photos)
        Row() {
          Text(formatMessageTime(this.message.date))
            .fontSize(11)
            .fontColor(Color.White)
          if (this.message.isOutgoing) {
            if (this.message.sendState === 'sending') {
              Image($r('app.media.ic_clock'))
                .width(16).height(16)
                .fillColor(Color.White)
                .margin({ left: 3 })
            } else if (this.message.sendState === 'failed') {
              Image($r('app.media.ic_warning'))
                .width(16).height(16)
                .fillColor($r('app.color.swipe_delete'))
                .margin({ left: 3 })
            } else {
              Image(this.message.isRead ? $r('app.media.ic_check_double') : $r('app.media.ic_check_single'))
                .width(16).height(16)
                .fillColor(this.message.isRead ? $r('app.color.telegram_blue') : Color.White)
                .margin({ left: 3 })
            }
          }
        }
        .padding({ left: 5, right: 5, top: 2, bottom: 2 })
        .borderRadius(8)
        .backgroundColor('#80000000')
        .position({ right: 6, bottom: 6 })
      }
      .width('100%')
      .aspectRatio(2)
      .clip(true)

      // Live location info — iOS: timer (28x28) + elapsed text
      if (this.message.contentType === MessageContentType.LIVE_LOCATION) {
        Row() {
          // Timer circle — iOS: 28x28 ChatMessageLiveLocationTimerNode
          Stack() {
            Circle()
              .width(28)
              .height(28)
              .fill(Color.Transparent)
              .stroke($r('app.color.telegram_blue'))
              .strokeWidth(2)
            Image($r('app.media.ic_location'))
              .width(16).height(16)
              .fillColor($r('app.color.telegram_blue'))
          }
          .margin({ right: 8 })

          Column() {
            Text($r('app.string.live_location_label'))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
            Text(this.getLiveText())
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 1 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 10, right: 10, top: 8, bottom: 4 })
      }

      // Venue info — iOS: title (medium 14pt) + address (regular 14pt, max 2 lines)
      if (this.message.contentType === MessageContentType.VENUE) {
        Column() {
          if (this.message.venueTitle.length > 0) {
            Text(this.message.venueTitle)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          if (this.message.venueAddress.length > 0) {
            Text(this.message.venueAddress)
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 2 })
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 10, right: 10, top: 6, bottom: 4 })
      }

      // Static location: coordinates below map
      if (this.message.contentType === MessageContentType.LOCATION) {
        if (this.message.locationLatitude !== 0 || this.message.locationLongitude !== 0) {
          Text(`${this.message.locationLatitude.toFixed(5)}, ${this.message.locationLongitude.toFixed(5)}`)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .padding({ left: 10, right: 10, top: 6, bottom: 2 })
        }
      }
    }
    .width('100%')
  }

  private getLiveText(): string {
    if (this.message.locationLivePeriod > 0) {
      const minutes: number = Math.floor(this.message.locationLivePeriod / 60);
      if (minutes >= 60) {
        const hours: number = Math.floor(minutes / 60);
        const rem: number = minutes % 60;
        if (rem > 0) {
          return this.getString('location_updated_hours_minutes', 'Updated %sh %sm ago')
            .replace('%s', hours.toString())
            .replace('%s', rem.toString());
        }
        return this.getString('location_updated_hours', 'Updated %sh ago')
          .replace('%s', hours.toString());
      }
      return this.getString('location_updated_minutes', 'Updated %sm ago')
        .replace('%s', minutes.toString());
    }
    return this.getString('location_sharing', 'Sharing location');
  }

  private getString(name: string, fallback: string): string {
    try {
      return getContext(this).resourceManager.getStringByNameSync(name);
    } catch (_e) {
      return fallback;
    }
  }
}

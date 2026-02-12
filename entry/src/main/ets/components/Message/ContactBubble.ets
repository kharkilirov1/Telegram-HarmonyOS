import { Message } from '../../models/Message';
import { MessageMetaRow } from './MessageMetaRow';
import { getSenderColor } from './MessageUtils';

@ComponentV2
export struct ContactBubble {
  @Param message: Message = new Message();

  build() {
    Column() {
      Row() {
        // Avatar — iOS: 40x40 with initials
        Text(this.getInitials())
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .width(40)
          .height(40)
          .borderRadius(20)
          .backgroundColor(getSenderColor(this.message.contactUserId || this.message.senderId))
          .textAlign(TextAlign.Center)
          .margin({ right: 9 })

        Column() {
          // Name — iOS: semibold 14pt
          Text(this.getContactName())
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          // Phone number — iOS: up to 5 lines of info
          if (this.message.contactPhone.length > 0) {
            Text(this.formatPhone(this.message.contactPhone))
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 1 })
              .maxLines(2)
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ top: 4, bottom: 4 })

      // iOS: separator 3pt with mainColor 0.2 alpha, then 2 buttons (33pt height each)
      Divider()
        .strokeWidth(0.5)
        .color($r('app.color.separator'))
        .margin({ top: 6 })

      // Message button — iOS: 33pt button with uppercase text
      Row() {
        Image($r('app.media.ic_send'))
          .width(16).height(16)
          .fillColor($r('app.color.telegram_blue'))
          .margin({ right: 6 })
        Text($r('app.string.contact_send_message'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.telegram_blue'))
      }
      .width('100%')
      .height(33)
      .justifyContent(FlexAlign.Center)

      // Add Contact separator + button
      Divider()
        .strokeWidth(0.5)
        .color($r('app.color.separator'))

      Row() {
        Image($r('app.media.ic_contact_add'))
          .width(16).height(16)
          .fillColor($r('app.color.telegram_blue'))
          .margin({ right: 6 })
        Text($r('app.string.contact_add_contact'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.telegram_blue'))
      }
      .width('100%')
      .height(33)
      .justifyContent(FlexAlign.Center)

      MessageMetaRow({
        date: this.message.date,
        isOutgoing: this.message.isOutgoing,
        isRead: this.message.isRead,
        isEdited: this.message.isEdited,
        sendState: this.message.sendState,
        tint: $r('app.color.text_secondary'),
        checkTint: $r('app.color.telegram_blue')
      })
    }
    .width('100%')
  }

  private getContactName(): string {
    const first: string = this.message.contactFirstName;
    const last: string = this.message.contactLastName;
    const full: string = `${first} ${last}`.trim();
    if (full.length > 0) {
      return full;
    }
    return getContext(this).resourceManager.getStringByNameSync('contact_label');
  }

  private formatPhone(phone: string): string {
    if (phone.startsWith('+')) return phone;
    return `+${phone}`;
  }

  private getInitials(): string {
    const first: string = this.message.contactFirstName;
    const last: string = this.message.contactLastName;
    if (first.length > 0 && last.length > 0) {
      return first.charAt(0) + last.charAt(0);
    }
    if (first.length > 0) return first.charAt(0);
    if (last.length > 0) return last.charAt(0);
    return '?';
  }
}

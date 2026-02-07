import { Chat } from '../../models/Chat';

@Component
export struct ChatListItem {
  @ObjectLink chat: Chat;
  onChatClick: (chatId: number) => void = () => {};

  build() {
    Row() {
      // Avatar
      Stack() {
        if (this.chat.photo !== null) {
          Image(this.chat.photo)
            .width(54)
            .height(54)
            .borderRadius(27)
        } else {
          // Placeholder avatar with initials
          Text(this.getInitials())
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .width(54)
            .height(54)
            .borderRadius(27)
            .backgroundColor(this.getAvatarColor())
            .textAlign(TextAlign.Center)
        }
      }
      .margin({ right: 12 })

      // Chat info
      Column() {
        // Top row: name + time
        Row() {
          Text(this.chat.title)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          Text(this.formatDate(this.chat.lastMessageDate))
            .fontSize(13)
            .fontColor(this.chat.unreadCount > 0 ? $r('app.color.telegram_blue') : $r('app.color.text_secondary'))
        }
        .width('100%')

        // Bottom row: last message + unread badge
        Row() {
          Text(this.chat.lastMessage)
            .fontSize(15)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          if (this.chat.unreadCount > 0) {
            Text(this.chat.unreadCount > 99 ? '99+' : this.chat.unreadCount.toString())
              .fontSize(13)
              .fontColor(Color.White)
              .backgroundColor($r('app.color.telegram_blue'))
              .borderRadius(12)
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
              .minWidth(24)
              .textAlign(TextAlign.Center)
          }
        }
        .width('100%')
        .margin({ top: 4 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .onClick(() => {
      this.onChatClick(this.chat.id);
    })
  }

  private getInitials(): string {
    const parts = this.chat.title.split(' ');
    if (parts.length >= 2) {
      return parts[0].charAt(0) + parts[1].charAt(0);
    }
    return this.chat.title.charAt(0);
  }

  private getAvatarColor(): string {
    // Telegram-style avatar colors based on id
    const colors: string[] = [
      '#FF5733', '#E91E63', '#9C27B0', '#673AB7',
      '#3F51B5', '#2196F3', '#00BCD4', '#009688'
    ];
    return colors[Math.abs(this.chat.id) % colors.length];
  }

  private formatDate(timestamp: number): string {
    if (timestamp === 0) return '';
    const date = new Date(timestamp * 1000);
    const now = new Date();

    if (date.toDateString() === now.toDateString()) {
      // Today: show time
      return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' } as Intl.DateTimeFormatOptions);
    }

    // Older: show date
    const diff = now.getTime() - date.getTime();
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    if (days < 7) {
      const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      return weekdays[date.getDay()];
    }

    return `${date.getDate()}.${(date.getMonth() + 1).toString().padStart(2, '0')}`;
  }
}

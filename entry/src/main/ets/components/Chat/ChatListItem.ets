import { Chat } from '../../models/Chat';
import { AvatarWithStatus } from '../Common/AvatarWithStatus';
import { TypingIndicator } from '../Common/TypingIndicator';

@ComponentV2
export struct ChatListItem {
  @Param chat: Chat = new Chat();
  @Event onChatClick: (chatId: number) => void;

  build() {
    Row() {
      // Avatar with online indicator
      AvatarWithStatus({
        photoUrl: this.chat.photo || '',
        initials: this.getInitials(),
        avatarColor: this.getAvatarColor(),
        avatarSize: 54,
        isOnline: this.chat.isUserOnline,
        showOnlineDot: !this.chat.isGroup && !this.chat.isChannel
      })
      .margin({ right: 12 })

      // Content column
      Column() {
        // Top row: channel icon + title + mute icon + time
        Row() {
          if (this.chat.isChannel) {
            Image($r('app.media.ic_channel'))
              .width(16)
              .height(16)
              .fillColor($r('app.color.text_primary'))
              .margin({ right: 4 })
          }

          Text(this.chat.title)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          if (this.chat.isMuted) {
            Image($r('app.media.ic_mute'))
              .width(15)
              .height(15)
              .fillColor($r('app.color.text_secondary'))
              .margin({ left: 4, right: 4 })
          }

          Text(this.formatDate(this.chat.lastMessageDate))
            .fontSize(13)
            .fontColor(this.chat.unreadCount > 0 && !this.chat.isMuted
              ? $r('app.color.telegram_blue')
              : $r('app.color.text_secondary'))
        }
        .width('100%')

        // Bottom row: typing / last message + badge / pin
        Row() {
          if (this.chat.isTyping) {
            TypingIndicator({ typingText: this.chat.typingDescription })
              .layoutWeight(1)
          } else {
            Text() {
              // Sender prefix for groups
              if (this.chat.isGroup && this.chat.lastMessageSenderName.length > 0) {
                Span(this.chat.lastMessageSenderName + ': ')
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
              }
              Span(this.chat.lastMessage)
                .fontColor($r('app.color.text_secondary'))
            }
            .fontSize(15)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          }

          // Right: unread badge OR pin icon
          if (this.chat.unreadCount > 0) {
            Text(this.chat.unreadCount > 99 ? '99+' : this.chat.unreadCount.toString())
              .fontSize(12)
              .fontColor(Color.White)
              .backgroundColor(this.chat.isMuted
                ? $r('app.color.text_secondary')
                : $r('app.color.telegram_blue'))
              .borderRadius(10)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .constraintSize({ minWidth: 20 })
              .height(20)
              .textAlign(TextAlign.Center)
          } else if (this.chat.isPinned) {
            Image($r('app.media.ic_pin'))
              .width(16)
              .height(16)
              .fillColor($r('app.color.text_secondary'))
          }
        }
        .width('100%')
        .margin({ top: 4 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height(76)
    .padding({ left: 16, right: 16 })
    .onClick(() => this.onChatClick(this.chat.id))
  }

  private getInitials(): string {
    const parts = this.chat.title.split(' ');
    if (parts.length >= 2) {
      return parts[0].charAt(0) + parts[1].charAt(0);
    }
    return this.chat.title.charAt(0);
  }

  private getAvatarColor(): ResourceColor {
    const colors: ResourceColor[] = [
      $r('app.color.sender_color_1'), $r('app.color.sender_color_2'),
      $r('app.color.sender_color_3'), $r('app.color.sender_color_8'),
      $r('app.color.sender_color_4'), $r('app.color.sender_color_5'),
      $r('app.color.sender_color_6'), $r('app.color.sender_color_7')
    ];
    return colors[Math.abs(this.chat.id) % colors.length];
  }

  private formatDate(timestamp: number): string {
    if (timestamp === 0) return '';
    const date = new Date(timestamp * 1000);
    const now = new Date();

    if (date.toDateString() === now.toDateString()) {
      return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' } as Intl.DateTimeFormatOptions);
    }

    const diff = now.getTime() - date.getTime();
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    if (days < 7) {
      const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      return weekdays[date.getDay()];
    }

    return `${date.getDate()}.${(date.getMonth() + 1).toString().padStart(2, '0')}`;
  }
}

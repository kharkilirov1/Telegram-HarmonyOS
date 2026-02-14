import { Chat } from '../../models/Chat';
import { AvatarWithStatus } from '../Common/AvatarWithStatus';
import { TypingIndicator } from '../Common/TypingIndicator';

// Reusable list item for LazyForEach — aligns with HarmonyOS ArkUI best practice
@Reusable
@ComponentV2
export struct ChatListItem {
  @Param chat: Chat = new Chat();
  @Event onChatClick: (chatId: number) => void;

  aboutToReuse(params: Record<string, Object>): void {
    const c = params['chat'];
    if (c !== undefined) {
      this.chat = c as Chat;
    }
  }

  build() {
    Row() {
      // Avatar with online indicator
      AvatarWithStatus({
        photoUrl: this.chat.photo || '',
        initials: this.getInitials(),
        avatarColor: this.getAvatarColor(),
        avatarSize: 48,
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
              .width(16)
              .height(16)
              .fillColor($r('app.color.text_secondary'))
              .margin({ left: 4, right: 4 })
          }

          Text(this.formatDate(this.chat.lastMessageDate))
            .fontSize(12)
            .fontColor((this.chat.unreadCount > 0 || this.chat.isMarkedAsUnread) && !this.chat.isMuted
              ? $r('app.color.telegram_blue')
              : $r('app.color.text_secondary'))
        }
        .width('100%')

        // Bottom row: typing / last message + badge / pin
        Row() {
          if (this.chat.isTyping) {
            TypingIndicator({ typingText: this.chat.typingDescription })
              .layoutWeight(1)
          } else if (this.chat.draftText.length > 0) {
            Text() {
              Span(this.getDraftPrefix())
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.error_red'))
              Span(this.chat.draftText)
                .fontColor($r('app.color.text_secondary'))
            }
            .fontSize(16)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          } else {
            Row() {
              // Outgoing check icons — iOS: proper SVG checkmarks
              if (this.chat.lastMessageIsOutgoing && !this.chat.isChannel) {
                Image(this.chat.lastMessageIsRead
                  ? $r('app.media.ic_check_double')
                  : $r('app.media.ic_check_single'))
                  .width(16).height(16)
                  .fillColor(this.chat.lastMessageIsRead
                    ? $r('app.color.telegram_blue')
                    : $r('app.color.text_secondary'))
                  .margin({ right: 4 })
              }

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
              .fontSize(16)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            }
            .layoutWeight(1)
            .alignItems(VerticalAlign.Top)
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
              .transition(TransitionEffect.OPACITY.combine(
                TransitionEffect.scale({ x: 0.5, y: 0.5 })
              ).animation({ duration: 200, curve: Curve.EaseOut }))
          } else if (this.chat.isMarkedAsUnread) {
            Circle()
              .width(10)
              .height(10)
              .fill(this.chat.isMuted
                ? $r('app.color.text_secondary')
                : $r('app.color.telegram_blue'))
              .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
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
    .height(72)
    .padding({ left: 16, right: 16 })
    .onClick(() => this.onChatClick(this.chat.id))
    .hoverEffect(HoverEffect.Highlight)
    .opacity(1.0)
    .stateStyles({
      pressed: {
        .opacity(0.6)
      },
      normal: {
        .opacity(1.0)
      }
    })
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
      return date.toLocaleDateString([], { weekday: 'short' } as Intl.DateTimeFormatOptions);
    }

    return `${date.getDate()}.${(date.getMonth() + 1).toString().padStart(2, '0')}`;
  }

  private getDraftPrefix(): string {
    return getContext(this).resourceManager.getStringByNameSync('chat_draft_prefix');
  }
}

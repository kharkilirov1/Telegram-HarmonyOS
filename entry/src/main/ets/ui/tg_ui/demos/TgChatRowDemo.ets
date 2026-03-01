import { TgChatRow, TgChatRowData } from '../atoms/TgChatRow';
import { TgChatSendStatus } from '../atoms/TgChatMeta';
import { TgUiTokens } from '../tokens/TgUiTokens';

@Component
export struct TgChatRowDemo {
  private makeBaseRowData(): TgChatRowData {
    const data = new TgChatRowData();
    data.chatId = 1;
    data.title = 'Telegram Design Team';
    data.preview = 'Ship TgChatRow without layout jumps';
    data.timeText = '12:37';
    data.avatarInitials = 'TD';
    return data;
  }

  private makeLongTextRowData(): TgChatRowData {
    const data = new TgChatRowData();
    data.chatId = 2;
    data.title = 'Very long chat title to validate ellipsis stability on narrow widths in real chat list';
    data.preview = 'Long preview text should be truncated correctly and must never push right meta cluster';
    data.timeText = '18:04';
    data.avatarInitials = 'VL';
    return data;
  }

  private makeVariant(timeText: string, unreadCount: number = 0, isMuted: boolean = false, isPinned: boolean = false,
    sendStatus: TgChatSendStatus = TgChatSendStatus.None, avatarOnline: boolean = false): TgChatRowData {
    const data = this.makeBaseRowData();
    data.timeText = timeText;
    data.unreadCount = unreadCount;
    data.isMuted = isMuted;
    data.isPinned = isPinned;
    data.sendStatus = sendStatus;
    data.avatarIsOnline = avatarOnline;
    return data;
  }

  private makeLongVariant(unreadCount: number = 0, isPinned: boolean = false, sendStatus: TgChatSendStatus = TgChatSendStatus.None): TgChatRowData {
    const data = this.makeLongTextRowData();
    data.unreadCount = unreadCount;
    data.isPinned = isPinned;
    data.sendStatus = sendStatus;
    return data;
  }

  @Builder
  private label(text: string) {
    Text(text)
      .fontSize(TgUiTokens.FONT_META_SIZE)
      .fontColor(TgUiTokens.COLOR_TEXT_META)
      .width('100%')
      .padding({
        left: TgUiTokens.SPACE_16,
        right: TgUiTokens.SPACE_16,
        top: TgUiTokens.SPACE_8,
        bottom: TgUiTokens.SPACE_4
      })
  }

  build() {
    Scroll() {
      Column() {
        Text('TgChatRow Demo')
          .fontSize(TgUiTokens.FONT_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            top: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        this.label('01 normal (no unread)')
        TgChatRow({ data: this.makeVariant('12:37'), showSeparator: true })

        this.label('02 unread = 1')
        TgChatRow({ data: this.makeVariant('12:38', 1), showSeparator: true })

        this.label('03 unread = 99')
        TgChatRow({ data: this.makeVariant('12:39', 99), showSeparator: true })

        this.label('04 unread = 207 (99+)')
        TgChatRow({ data: this.makeVariant('12:40', 207), showSeparator: true })

        this.label('05 pinned (no unread)')
        TgChatRow({ data: this.makeVariant('12:41', 0, false, true), showSeparator: true })

        this.label('06 muted (no unread)')
        TgChatRow({ data: this.makeVariant('12:42', 0, true), showSeparator: true })

        this.label('07 muted + unread')
        TgChatRow({ data: this.makeVariant('12:43', 11, true), showSeparator: true })

        this.label('08 sending')
        TgChatRow({ data: this.makeVariant('12:44', 0, false, false, TgChatSendStatus.Sending), showSeparator: true })

        this.label('09 sent')
        TgChatRow({ data: this.makeVariant('12:45', 0, false, false, TgChatSendStatus.Sent), showSeparator: true })

        this.label('10 read')
        TgChatRow({ data: this.makeVariant('12:46', 0, false, false, TgChatSendStatus.Read), showSeparator: true })

        this.label('11 online avatar')
        TgChatRow({ data: this.makeVariant('12:47', 0, false, false, TgChatSendStatus.None, true), showSeparator: true })

        this.label('12 ellipsis torture')
        TgChatRow({ data: this.makeLongTextRowData(), showSeparator: true })

        this.label('13 failed only')
        TgChatRow({ data: this.makeVariant('12:48', 0, false, false, TgChatSendStatus.Failed), showSeparator: true })

        this.label('14 failed + unread')
        TgChatRow({ data: this.makeVariant('12:49', 3, false, false, TgChatSendStatus.Failed), showSeparator: true })

        Divider()
          .color(TgUiTokens.COLOR_SEPARATOR)
          .strokeWidth(TgUiTokens.CHAT_ROW_SEPARATOR_STROKE)
          .margin({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            top: TgUiTokens.SPACE_8,
            bottom: TgUiTokens.SPACE_8
          })

        Text('Jump probe (same left content, right state changes)')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        TgChatRow({ data: this.makeLongVariant(), showSeparator: true })
        TgChatRow({ data: this.makeLongVariant(0, false, TgChatSendStatus.Read), showSeparator: true })
        TgChatRow({ data: this.makeLongVariant(12), showSeparator: true })
        TgChatRow({ data: this.makeLongVariant(0, true), showSeparator: true })
      }
      .width('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
  }
}


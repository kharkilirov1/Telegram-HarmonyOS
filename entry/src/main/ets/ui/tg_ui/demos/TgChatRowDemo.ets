import { TgChatRow, TgChatRowData } from '../atoms/TgChatRow';
import { TgChatSendStatus } from '../atoms/TgChatMeta';
import { TgUiTokens } from '../tokens/TgUiTokens';

@Preview({ title: 'TgChatRow' })
@ComponentV2
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

  private makeDraftVariant(): TgChatRowData {
    const data = this.makeBaseRowData();
    data.chatId = 3;
    data.timeText = '12:50';
    data.previewPrefix = 'Draft:';
    data.previewPrefixStyle = 'draft';
    data.preview = 'Need one more pass on the glass capsule proportions';
    data.isDraft = true;
    return data;
  }

  private makeTypingVariant(): TgChatRowData {
    const data = this.makeBaseRowData();
    data.chatId = 4;
    data.timeText = '12:51';
    data.preview = 'Alice typing...';
    data.isTyping = true;
    return data;
  }

  private makeAuthorPrefixVariant(): TgChatRowData {
    const data = this.makeBaseRowData();
    data.chatId = 5;
    data.timeText = '12:52';
    data.previewPrefix = 'You:';
    data.previewPrefixStyle = 'author';
    data.preview = 'Ship the chat-list row parity pass today';
    return data;
  }

  private makeVerifiedVariant(): TgChatRowData {
    const data = this.makeBaseRowData();
    data.chatId = 6;
    data.timeText = '12:53';
    data.title = 'Telegram News';
    data.preview = 'Verified title badge should stay stable before the mute icon';
    data.isVerified = true;
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
        TgChatRow({ ...this.makeVariant('12:37'), showSeparator: true })

        this.label('02 unread = 1')
        TgChatRow({ ...this.makeVariant('12:38', 1), showSeparator: true })

        this.label('03 unread = 99')
        TgChatRow({ ...this.makeVariant('12:39', 99), showSeparator: true })

        this.label('04 unread = 207 exact')
        TgChatRow({ ...this.makeVariant('12:40', 207), showSeparator: true })

        this.label('05 unread = 2.5K compact')
        TgChatRow({ ...this.makeVariant('12:40', 2500), showSeparator: true })

        this.label('06 pinned (no unread)')
        TgChatRow({ ...this.makeVariant('12:41', 0, false, true), showSeparator: true })

        this.label('07 muted (no unread)')
        TgChatRow({ ...this.makeVariant('12:42', 0, true), showSeparator: true })

        this.label('08 muted + unread')
        TgChatRow({ ...this.makeVariant('12:43', 11, true), showSeparator: true })

        this.label('09 sending')
        TgChatRow({ ...this.makeVariant('12:44', 0, false, false, TgChatSendStatus.Sending), showSeparator: true })

        this.label('10 sent')
        TgChatRow({ ...this.makeVariant('12:45', 0, false, false, TgChatSendStatus.Sent), showSeparator: true })

        this.label('11 read')
        TgChatRow({ ...this.makeVariant('12:46', 0, false, false, TgChatSendStatus.Read), showSeparator: true })

        this.label('12 online avatar')
        TgChatRow({ ...this.makeVariant('12:47', 0, false, false, TgChatSendStatus.None, true), showSeparator: true })

        this.label('13 ellipsis torture')
        TgChatRow({ ...this.makeLongTextRowData(), showSeparator: true })

        this.label('14 failed only')
        TgChatRow({ ...this.makeVariant('12:48', 0, false, false, TgChatSendStatus.Failed), showSeparator: true })

        this.label('15 failed + unread')
        TgChatRow({ ...this.makeVariant('12:49', 3, false, false, TgChatSendStatus.Failed), showSeparator: true })

        this.label('16 draft prefix styling')
        TgChatRow({ ...this.makeDraftVariant(), showSeparator: true })

        this.label('17 typing preview (no author accent)')
        TgChatRow({ ...this.makeTypingVariant(), showSeparator: true })

        this.label('18 group sender prefix accent')
        TgChatRow({ ...this.makeAuthorPrefixVariant(), showSeparator: true })

        this.label('19 verified title badge')
        TgChatRow({ ...this.makeVerifiedVariant(), showSeparator: true })

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

        TgChatRow({ ...this.makeLongVariant(), showSeparator: true })
        TgChatRow({ ...this.makeLongVariant(0, false, TgChatSendStatus.Read), showSeparator: true })
        TgChatRow({ ...this.makeLongVariant(12), showSeparator: true })
        TgChatRow({ ...this.makeLongVariant(0, true), showSeparator: true })
      }
      .width('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
  }
}


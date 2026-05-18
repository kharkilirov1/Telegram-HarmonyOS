import { TgChatMeta, TgChatSendStatus } from '../atoms/TgChatMeta';
import { TgUiTokens } from '../tokens/TgUiTokens';

@Preview({ title: 'TgChatMeta' })
@ComponentV2
export struct TgChatMetaDemo {
  @Builder
  private stateRow(label: string, timeText: string, sendStatus: TgChatSendStatus, unreadCount: number, isMuted: boolean = false, isPinned: boolean = false) {
    Row() {
      Text(label)
        .layoutWeight(1)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      TgChatMeta({
        timeText,
        sendStatus,
        unreadCount,
        isMuted,
        isPinned
      })
    }
    .width('100%')
    .padding({
      left: TgUiTokens.SPACE_16,
      right: TgUiTokens.SPACE_16,
      top: TgUiTokens.SPACE_8,
      bottom: TgUiTokens.SPACE_8
    })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private jumpProbeRow(timeText: string, sendStatus: TgChatSendStatus, unreadCount: number, isMuted: boolean = false, isPinned: boolean = false) {
    Row() {
      Column({ space: TgUiTokens.SPACE_4 }) {
        Text('Very long Telegram-like title that must keep stable ellipsis behavior')
          .fontSize(TgUiTokens.FONT_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text('Message preview should not jump when right cluster changes state')
          .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .padding({ right: TgUiTokens.SPACE_8 })

      TgChatMeta({
        timeText,
        sendStatus,
        unreadCount,
        isMuted,
        isPinned
      })
    }
    .width('100%')
    .height(TgUiTokens.CHAT_ROW_HEIGHT)
    .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16 })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      Text('TgChatMeta Demo')
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

      Text('Anti-jump: minWidth reserve + fixed bottom row geometry')
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        .width('100%')
        .padding({
          left: TgUiTokens.SPACE_16,
          right: TgUiTokens.SPACE_16,
          bottom: TgUiTokens.SPACE_8
        })

      this.stateRow('01 none', '12:37', TgChatSendStatus.None, 0)
      this.stateRow('02 sending', '12:38', TgChatSendStatus.Sending, 0)
      this.stateRow('03 sent', '12:39', TgChatSendStatus.Sent, 0)
      this.stateRow('04 read', '12:40', TgChatSendStatus.Read, 0)
      this.stateRow('05 pinned', '12:41', TgChatSendStatus.None, 0, false, true)
      this.stateRow('06 unread=5', '12:42', TgChatSendStatus.None, 5)
      this.stateRow('07 unread=207 exact muted', '12:43', TgChatSendStatus.None, 207, true)
      this.stateRow('08 unread=2.5K compact', '12:44', TgChatSendStatus.None, 2500)
      this.stateRow('09 unread=1.2M compact muted', '12:45', TgChatSendStatus.None, 1250000, true)
      this.stateRow('10 failed', '12:46', TgChatSendStatus.Failed, 0)
      this.stateRow('11 failed + unread', '12:47', TgChatSendStatus.Failed, 5)

      Divider()
        .color(TgUiTokens.COLOR_SEPARATOR)
        .strokeWidth(1)
        .margin({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_8, bottom: TgUiTokens.SPACE_8 })

      Text('Jump probe (same left content, changing right state)')
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        .width('100%')
        .padding({
          left: TgUiTokens.SPACE_16,
          right: TgUiTokens.SPACE_16,
          bottom: TgUiTokens.SPACE_8
        })

      this.jumpProbeRow('13:01', TgChatSendStatus.None, 0)
      this.jumpProbeRow('13:01', TgChatSendStatus.Read, 0)
      this.jumpProbeRow('13:01', TgChatSendStatus.None, 12)
      this.jumpProbeRow('13:01', TgChatSendStatus.None, 2500)
      this.jumpProbeRow('13:01', TgChatSendStatus.None, 0, false, true)
      this.jumpProbeRow('13:01', TgChatSendStatus.Failed, 7)

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
  }
}

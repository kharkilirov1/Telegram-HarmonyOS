// ChatListItem — individual chat cell for the chat list
// Layout adapted from Telegram iOS ChatListItemNode:
//   [Avatar 54vp] [12vp gap] [Title + Time / Message + Badge]
// Cell height: 76vp (iOS standard)

import { ChatItemVO } from './ChatItemVO';
import { AppShellTokens } from '../../theme/AppShellTokens';

@Reusable
@Component
export struct ChatListItem {
  @State item: ChatItemVO = new ChatItemVO();

  aboutToReuse(params: Record<string, ESObject>): void {
    this.item = params.item as ChatItemVO;
  }

  build() {
    Row() {
      // ── Avatar ──
      Stack() {
        Circle()
          .width(AppShellTokens.LIST_ROW_AVATAR_SIZE)
          .height(AppShellTokens.LIST_ROW_AVATAR_SIZE)
          .fill(this.item.avatarColor)
        Text(this.item.initials)
          .fontSize(AppShellTokens.LIST_ROW_INITIALS_SIZE)
          .fontColor(AppShellTokens.ICON_ON_PRIMARY)
          .fontWeight(FontWeight.Medium)
      }
      .width(AppShellTokens.LIST_ROW_AVATAR_SIZE)
      .height(AppShellTokens.LIST_ROW_AVATAR_SIZE)

      // ── Content ──
      Column() {
        // Row 1: Title + Time
        Row() {
          Text(this.item.title)
            .fontSize(AppShellTokens.LIST_ROW_TITLE_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppShellTokens.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          if (this.item.formattedTime.length > 0) {
            Text(this.item.formattedTime)
              .fontSize(AppShellTokens.LIST_ROW_TIME_SIZE)
              .fontColor(this.item.unreadCount > 0 ? AppShellTokens.ACCENT : AppShellTokens.TEXT_SECONDARY)
              .margin({ left: AppShellTokens.LIST_ROW_SIDE_GAP_SMALL })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // Row 2: Last message + Badge
        Row() {
          Text(this.item.lastMessage.length > 0 ? this.item.lastMessage : ' ')
            .fontSize(AppShellTokens.LIST_ROW_MESSAGE_SIZE)
            .fontColor(AppShellTokens.TEXT_SECONDARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          if (this.item.unreadCount > 0) {
            Text(this.item.unreadCount > 99 ? '99+' : this.item.unreadCount.toString())
              .fontSize(AppShellTokens.LIST_ROW_BADGE_TEXT_SIZE)
              .fontColor(AppShellTokens.BADGE_TEXT)
              .fontWeight(FontWeight.Medium)
              .textAlign(TextAlign.Center)
              .height(AppShellTokens.LIST_ROW_BADGE_HEIGHT)
              .constraintSize({ minWidth: AppShellTokens.LIST_ROW_BADGE_MIN_WIDTH })
              .padding({
                left: AppShellTokens.LIST_ROW_BADGE_SIDE_PADDING,
                right: AppShellTokens.LIST_ROW_BADGE_SIDE_PADDING
              })
              .borderRadius(AppShellTokens.LIST_ROW_BADGE_RADIUS)
              .backgroundColor(AppShellTokens.BADGE_BG)
              .margin({ left: AppShellTokens.LIST_ROW_SIDE_GAP_SMALL })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: AppShellTokens.LIST_ROW_SUBTITLE_TOP_MARGIN })
      }
      .layoutWeight(1)
      .margin({ left: AppShellTokens.LIST_ROW_GAP })
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height(AppShellTokens.LIST_ROW_HEIGHT)
    .padding({
      left: AppShellTokens.LIST_ROW_HORIZONTAL_PADDING,
      right: AppShellTokens.LIST_ROW_HORIZONTAL_PADDING
    })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.item.isPinned ? AppShellTokens.CHATLIST_PINNED_ITEM_BG : AppShellTokens.BACKGROUND)
  }
}

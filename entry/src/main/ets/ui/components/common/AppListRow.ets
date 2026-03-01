import { AppShellTokens } from '../../theme/AppShellTokens';

@Component
export struct AppListRow {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop trailingText: string = '';
  @Prop leadingText: string = '';
  @Prop leadingBgColor: Resource = AppShellTokens.PLACEHOLDER_BG;
  @Prop showDivider: boolean = true;

  build() {
    Column() {
      Row() {
        Stack() {
          Circle()
            .width(AppShellTokens.LIST_ROW_AVATAR_SIZE)
            .height(AppShellTokens.LIST_ROW_AVATAR_SIZE)
            .fill(this.leadingBgColor)

          Text(this.leadingText)
            .fontSize(AppShellTokens.LIST_ROW_LEADING_TEXT_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppShellTokens.ICON_ON_PRIMARY)
        }
        .width(AppShellTokens.LIST_ROW_AVATAR_SIZE)
        .height(AppShellTokens.LIST_ROW_AVATAR_SIZE)

        Column() {
          Row() {
            Text(this.title)
              .fontSize(AppShellTokens.LIST_ROW_TITLE_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppShellTokens.TEXT_PRIMARY)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)

            if (this.trailingText.length > 0) {
              Text(this.trailingText)
                .fontSize(AppShellTokens.LIST_ROW_TIME_SIZE)
                .fontColor(AppShellTokens.TEXT_SECONDARY)
                .margin({ left: AppShellTokens.LIST_ROW_SIDE_GAP_MEDIUM })
            }
          }
          .width('100%')

          if (this.subtitle.length > 0) {
            Text(this.subtitle)
              .fontSize(AppShellTokens.LIST_ROW_SUBTITLE_SIZE)
              .fontColor(AppShellTokens.TEXT_SECONDARY)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .margin({ top: AppShellTokens.LIST_ROW_SUBTITLE_TOP_MARGIN })
          }
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

      if (this.showDivider) {
        Divider()
          .strokeWidth(AppShellTokens.LIST_ROW_SEPARATOR_STROKE)
          .color(AppShellTokens.SEPARATOR)
          .margin({ left: AppShellTokens.LIST_ROW_CONTENT_START })
      }
    }
    .width('100%')
    .backgroundColor(AppShellTokens.BACKGROUND)
  }
}

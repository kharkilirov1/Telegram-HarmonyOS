import { AppShellTokens } from '../../theme/AppShellTokens';

@Component
export struct AppTabBarItem {
  @Prop title: string = '';
  @Prop icon: Resource = $r('app.media.ic_settings');
  @Prop isSelected: boolean = false;
  @Prop badgeCount: number = 0;

  build() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Image(this.icon)
          .width(AppShellTokens.TAB_ICON_SIZE)
          .height(AppShellTokens.TAB_ICON_SIZE)
          .fillColor(this.isSelected ? AppShellTokens.ACCENT : AppShellTokens.TEXT_SECONDARY)

        if (this.badgeCount > 0) {
          Text(this.badgeCount > 99 ? '99+' : this.badgeCount.toString())
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppShellTokens.BADGE_TEXT)
            .textAlign(TextAlign.Center)
            .height(AppShellTokens.TAB_BADGE_HEIGHT)
            .constraintSize({ minWidth: AppShellTokens.TAB_BADGE_MIN_WIDTH })
            .padding({ left: 5, right: 5 })
            .borderRadius(AppShellTokens.TAB_BADGE_RADIUS)
            .backgroundColor(AppShellTokens.BADGE_BG)
            .translate({ x: 10, y: -7 })
        }
      }
      .width(AppShellTokens.TAB_ICON_SIZE)
      .height(AppShellTokens.TAB_ICON_SIZE)

      Text(this.title)
        .fontSize(AppShellTokens.TAB_TEXT_SIZE)
        .fontColor(this.isSelected ? AppShellTokens.ACCENT : AppShellTokens.TEXT_SECONDARY)
        .margin({ top: 2 })
        .maxLines(1)
    }
    .width('100%')
    .height(AppShellTokens.TAB_ITEM_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

import { uiMaterial } from '@kit.ArkUI';
import { Available, deviceInfo } from '@kit.BasicServicesKit';
import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';

export enum TgChatListFilter {
  All = 0,
  Unread = 1,
  Personal = 2
}

@ComponentV2
export struct TgChatListFilterBar {
  @Param selectedIndex: number = TgChatListFilter.All;
  @Param allText: string = 'All';
  @Param unreadText: string = 'Unread';
  @Param personalText: string = 'Personal';
  @Param unreadCount: number = 0;
  @Param glassMode: string = TgGlassPolicy.MODE_AUTO;

  @Event onSelectedIndexChange: (index: number) => void = (_: number): void => {};

  private useBlur(): boolean {
    return TgGlassPolicy.shouldUseRealtimeBlurForMode(this.glassMode);
  }

  private useNativeMaterial(): boolean {
    return deviceInfo.apiAvailable('26.0.0') && this.useBlur();
  }

  private badgeText(): string {
    if (this.unreadCount > 999) {
      return '999+';
    }
    return this.unreadCount.toString();
  }

  private isSelected(index: number): boolean {
    return this.selectedIndex === index;
  }

  @Builder
  private buildBadge() {
    if (this.unreadCount > 0) {
      Text(this.badgeText())
        .fontSize(TgUiTokens.CHAT_LIST_NAV_FILTER_BADGE_FONT_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(TgUiTokens.FILTER_BAR_BADGE_TEXT_COLOR)
        .height(TgUiTokens.CHAT_LIST_NAV_FILTER_BADGE_HEIGHT)
        .constraintSize({ minWidth: TgUiTokens.CHAT_LIST_NAV_FILTER_BADGE_HEIGHT })
        .padding({
          left: TgUiTokens.CHAT_LIST_NAV_FILTER_BADGE_PADDING_H,
          right: TgUiTokens.CHAT_LIST_NAV_FILTER_BADGE_PADDING_H
        })
        .textAlign(TextAlign.Center)
        .backgroundColor(TgUiTokens.FILTER_BAR_BADGE_INACTIVE_BG)
        .borderRadius(TgUiTokens.CHAT_LIST_NAV_FILTER_BADGE_HEIGHT / 2)
        .margin({ left: TgUiTokens.CHAT_LIST_NAV_FILTER_BADGE_GAP })
    }
  }

  @Builder
  private buildItem(index: number, text: string, showBadge: boolean) {
    Row() {
      Text(text)
        .fontSize(TgUiTokens.CHAT_LIST_NAV_FILTER_FONT_SIZE)
        .fontWeight(this.isSelected(index) ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(TgUiTokens.FILTER_BAR_TAB_TEXT_COLOR)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (showBadge) {
        this.buildBadge()
      }
    }
    .layoutWeight(1)
    .height(TgUiTokens.CHAT_LIST_NAV_FILTER_HEIGHT -
      TgUiTokens.CHAT_LIST_NAV_FILTER_SELECTED_INSET * 2)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.isSelected(index) ? TgUiTokens.FILTER_BAR_HIGHLIGHT_BG : Color.Transparent)
    .borderRadius(TgUiTokens.CHAT_LIST_NAV_FILTER_SELECTED_RADIUS)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
    .animation({ duration: TgUiTokens.CHAT_LIST_NAV_FILTER_MOTION_MS, curve: Curve.Smooth })
    .accessibilityText(showBadge && this.unreadCount > 0 ? `${text} ${this.badgeText()}` : text)
    .onClick(() => {
      if (this.selectedIndex !== index) {
        this.onSelectedIndexChange(index);
      }
    })
  }

  @Builder
  private buildItems() {
    Row({ space: TgUiTokens.CHAT_LIST_NAV_FILTER_INNER_GAP }) {
      this.buildItem(TgChatListFilter.All, this.allText, false)
      this.buildItem(TgChatListFilter.Unread, this.unreadText, true)
      this.buildItem(TgChatListFilter.Personal, this.personalText, false)
    }
    .width('100%')
    .height('100%')
    .padding(TgUiTokens.CHAT_LIST_NAV_FILTER_SELECTED_INSET)
  }

  @Available({ minApiVersion: '26.0.0' })
  @Builder
  private buildNativeRail() {
    Row() {
      this.buildItems()
    }
    .width('100%')
    .height(TgUiTokens.CHAT_LIST_NAV_FILTER_HEIGHT)
    .systemMaterial(new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      colorInvert: true,
      applyShadow: true,
      interactive: true
    }))
    .borderRadius(TgUiTokens.CHAT_LIST_NAV_FILTER_RADIUS)
    .clip(true)
  }

  @Builder
  private buildFallbackRail() {
    Row() {
      this.buildItems()
    }
    .width('100%')
    .height(TgUiTokens.CHAT_LIST_NAV_FILTER_HEIGHT)
    .backgroundColor(this.useBlur() ? TgUiTokens.FILTER_BAR_BG : TgUiTokens.FILTER_BAR_FALLBACK_BG)
    .backgroundBlurStyle(this.useBlur() ? BlurStyle.COMPONENT_ULTRA_THIN : BlurStyle.NONE,
      TgGlassPolicy.glassOptions())
    .border({
      width: TgUiTokens.FILTER_BAR_BORDER_WIDTH,
      color: TgUiTokens.FILTER_BAR_BORDER_COLOR
    })
    .borderRadius(TgUiTokens.CHAT_LIST_NAV_FILTER_RADIUS)
    .clip(true)
    .renderGroup(true)
  }

  build() {
    if (deviceInfo.apiAvailable('26.0.0')) {
      if (this.useNativeMaterial()) {
        this.buildNativeRail()
      } else {
        this.buildFallbackRail()
      }
    } else {
      this.buildFallbackRail()
    }
  }
}

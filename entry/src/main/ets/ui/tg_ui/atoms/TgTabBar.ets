// TgTabBar — Floating glass island tab bar (Phase D-1).
// iOS Telegram–style capsule shape with blur-over-content.

import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';
import { getString } from '../../../core/utils/AppResource';
import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

declare function px2vp(value: number): number;
const DOMAIN = 0x0020;
const TAG = 'TgTabBar';

@ComponentV2
export struct TgTabBar {
  @Param selectedIndex: number = 0;
  @Param chatBadgeCount: number = 0;
  @Param glassMode: string = TgGlassPolicy.MODE_AUTO;
  @Event onTabSelect: (index: number) => void = (_: number): void => {};

  @Local private bottomInset: number = 0;
  private mainWindow?: window.Window;

  aboutToAppear(): void {
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const windowStage = context.windowStage;
      if (windowStage) {
        this.mainWindow = windowStage.getMainWindowSync();
        this.updateBottomInset(this.mainWindow);
        this.mainWindow.on('windowSizeChange', (_size: window.Size) => {
          if (this.mainWindow !== undefined) {
            this.updateBottomInset(this.mainWindow);
          }
        });
      }
    } catch (_error) {
      this.bottomInset = 0;
    }
  }

  aboutToDisappear(): void {
    if (this.mainWindow !== undefined) {
      try {
        this.mainWindow.off('windowSizeChange');
      } catch (_error) {
      }
      this.mainWindow = undefined;
    }
  }

  private updateBottomInset(mainWindow: window.Window): void {
    let computedInset: number = 0;
    try {
      const systemAvoid = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      computedInset = Math.max(computedInset, px2vp(systemAvoid.bottomRect.height));
    } catch (_error) {
    }
    try {
      const navAvoid = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      computedInset = Math.max(computedInset, px2vp(navAvoid.bottomRect.height));
    } catch (_error) {
    }
    this.bottomInset = computedInset;
  }

  private tabLabel(resourceId: number, fallback: string): string {
    const localized = getString(resourceId);
    return localized.length > 0 ? localized : fallback;
  }

  private useRealtimeBlur(): boolean {
    return TgGlassPolicy.shouldUseRealtimeBlurForMode(this.glassMode);
  }

  private iconColor(index: number): Resource {
    return this.selectedIndex === index ? TgUiTokens.COLOR_ICON_PRIMARY : TgUiTokens.COLOR_ICON_SECONDARY;
  }

  @Builder
  private buildBadge() {
    if (this.chatBadgeCount > 0) {
      Text(this.chatBadgeCount > 99 ? '99+' : this.chatBadgeCount.toString())
        .fontSize(TgUiTokens.TAB_BAR_BADGE_FONT_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(TgUiTokens.COLOR_UNREAD_TEXT)
        .textAlign(TextAlign.Center)
        .height(TgUiTokens.TAB_BAR_BADGE_HEIGHT)
        .constraintSize({ minWidth: TgUiTokens.TAB_BAR_BADGE_MIN_WIDTH })
        .padding({ left: TgUiTokens.TAB_BAR_BADGE_PADDING_H, right: TgUiTokens.TAB_BAR_BADGE_PADDING_H })
        .borderRadius(TgUiTokens.TAB_BAR_BADGE_RADIUS)
        .backgroundColor(TgUiTokens.COLOR_UNREAD_BG)
        .translate({ x: TgUiTokens.TAB_BAR_BADGE_OFFSET_X, y: TgUiTokens.TAB_BAR_BADGE_OFFSET_Y })
    }
  }

  @Builder
  private buildTab(index: number, title: string, icon: Resource, showBadge: boolean) {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Image(icon)
          .width(TgUiTokens.TAB_BAR_ICON_SIZE)
          .height(TgUiTokens.TAB_BAR_ICON_SIZE)
          .fillColor(this.iconColor(index))

        if (showBadge) {
          this.buildBadge()
        }
      }
      .width(TgUiTokens.TAB_BAR_ICON_SIZE)
      .height(TgUiTokens.TAB_BAR_ICON_SIZE)

      Text(title)
        .fontSize(TgUiTokens.TAB_BAR_TEXT_SIZE)
        .fontColor(this.iconColor(index))
        .margin({ top: TgUiTokens.SPACE_2 })
        .maxLines(1)
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      hilog.info(DOMAIN, TAG, 'Tab click index=%{public}d', index);
      // Fallback path: write shared tab index even if callback channel is delayed.
      AppStorage.set<number>(StorageKeys.MAIN_TAB_INDEX, index);
      this.onTabSelect(index);
    })
  }

  @Builder
  private buildIslandSpecular() {
    if (this.useRealtimeBlur()) {
      Column()
        .width('100%')
        .height('100%')
        .borderRadius(TgUiTokens.TAB_BAR_ISLAND_RADIUS)
        .linearGradient({
          angle: 115,
          colors: [
            [TgUiTokens.GLASS_SPECULAR_TOP, 0.0],
            [TgUiTokens.GLASS_SPECULAR_MID, 0.36],
            [TgUiTokens.GLASS_SPECULAR_BOTTOM, 1.0]
          ]
        })
    }
  }

  build() {
    Column() {
      Row() {
        this.buildTab(0, this.tabLabel($r('app.string.contacts_title').id, 'Contacts'), $r('app.media.ic_contact'), false)
        this.buildTab(1, this.tabLabel($r('app.string.calls_title').id, 'Calls'), $r('app.media.ic_phone_call'), false)
        this.buildTab(2, this.tabLabel($r('app.string.chats_title').id, 'Chats'), $r('app.media.ic_chat'), true)
        this.buildTab(3, this.tabLabel($r('app.string.settings').id, 'Settings'), $r('app.media.ic_settings'), false)
      }
      .width('100%')
      .height(TgUiTokens.TAB_BAR_ISLAND_HEIGHT)
      .constraintSize({ maxWidth: TgUiTokens.TAB_BAR_ISLAND_MAX_WIDTH })
      .borderRadius(TgUiTokens.TAB_BAR_ISLAND_RADIUS)
      .backgroundColor(this.useRealtimeBlur() ? TgUiTokens.TAB_BAR_ISLAND_BG : TgUiTokens.TAB_BAR_ISLAND_FALLBACK_BG)
      .backgroundBlurStyle(TgGlassPolicy.tabBarBlurStyle())
      // NOTE: keep click behavior stable first; specular overlay can be restored later if needed.
      .border({
        width: TgUiTokens.TAB_BAR_ISLAND_BORDER_WIDTH,
        color: TgUiTokens.TAB_BAR_ISLAND_BORDER_COLOR
      })
      .shadow({
        radius: TgUiTokens.TAB_BAR_ISLAND_SHADOW_RADIUS,
        offsetX: 0,
        offsetY: TgUiTokens.TAB_BAR_ISLAND_SHADOW_OFFSET_Y,
        color: TgUiTokens.TAB_BAR_ISLAND_SHADOW_COLOR
      })
      .margin({
        left: TgUiTokens.TAB_BAR_ISLAND_SIDE_INSET,
        right: TgUiTokens.TAB_BAR_ISLAND_SIDE_INSET
      })
      .clip(true)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}

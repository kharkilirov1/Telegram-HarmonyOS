// TgTabBar — centered glass capsule tab bar.
// Visual grounding: current Telegram iOS TabBarComponent / GlassBackgroundContainerView.

import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';
import { getString } from '../../../core/utils/AppResource';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

declare function px2vp(value: number): number;
const DOMAIN = 0x0020;
const TAG = 'TgTabBar';
const ISLAND_SCREEN_RATIO: number = 0.8;

@ComponentV2
export struct TgTabBar {
  @Param selectedIndex: number = 0;
  @Param chatBadgeCount: number = 0;
  @Param glassMode: string = TgGlassPolicy.MODE_AUTO;
  @Event onTabSelect: (index: number) => void = (_: number): void => {};

  @Local private islandWidth: number = TgUiTokens.TAB_BAR_ISLAND_MAX_WIDTH;
  private mainWindow?: window.Window;

  aboutToAppear(): void {
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const windowStage = context.windowStage;
      if (windowStage) {
        this.mainWindow = windowStage.getMainWindowSync();
        this.updateWindowMetrics(this.mainWindow);
        this.mainWindow.on('windowSizeChange', (_size: window.Size) => {
          if (this.mainWindow !== undefined) {
            this.updateWindowMetrics(this.mainWindow);
          }
        });
      }
    } catch (_error) {
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

  private updateWindowMetrics(mainWindow: window.Window): void {
    try {
      const props = mainWindow.getWindowProperties();
      const screenWidthVp: number = px2vp(props.windowRect.width);
      this.islandWidth = Math.min(
        screenWidthVp * ISLAND_SCREEN_RATIO,
        TgUiTokens.TAB_BAR_ISLAND_MAX_WIDTH
      );
    } catch (_error) {
    }
  }

  private tabLabel(resourceId: number, fallback: string): string {
    const localized = getString(resourceId);
    return localized.length > 0 ? localized : fallback;
  }

  private useRealtimeBlur(): boolean {
    return TgGlassPolicy.shouldUseRealtimeBlurForMode(this.glassMode);
  }

  private isSelected(index: number): boolean {
    return this.selectedIndex === index;
  }

  private tabIconColor(index: number): Resource {
    return this.isSelected(index) ? TgUiTokens.COLOR_ICON_PRIMARY : TgUiTokens.COLOR_ICON_SECONDARY;
  }

  private tabFontWeight(index: number): FontWeight {
    return this.isSelected(index) ? FontWeight.Medium : FontWeight.Regular;
  }

  private tabContentScale(index: number): number {
    return this.isSelected(index)
      ? TgUiTokens.TAB_BAR_ITEM_SELECTED_CONTENT_SCALE
      : TgUiTokens.TAB_BAR_ITEM_UNSELECTED_CONTENT_SCALE;
  }

  private tabContentOpacity(index: number): number {
    return this.isSelected(index)
      ? TgUiTokens.TAB_BAR_ITEM_SELECTED_CONTENT_OPACITY
      : TgUiTokens.TAB_BAR_ITEM_UNSELECTED_CONTENT_OPACITY;
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
        .position({ right: 0, top: 0 })
        .translate({ x: TgUiTokens.TAB_BAR_BADGE_OFFSET_X, y: TgUiTokens.TAB_BAR_BADGE_OFFSET_Y })
    }
  }

  @Builder
  private buildTab(index: number, title: string, icon: Resource, showBadge: boolean) {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .borderRadius(TgUiTokens.TAB_BAR_ISLAND_HEIGHT / 2)
        .backgroundColor(TgUiTokens.TAB_BAR_PILL_BG)
        .backgroundBlurStyle(
          this.useRealtimeBlur() && this.isSelected(index) ? BlurStyle.COMPONENT_THIN : BlurStyle.NONE,
          TgGlassPolicy.glassOptions()
        )
        .border({
          width: this.isSelected(index) ? TgUiTokens.TAB_BAR_PILL_BORDER_WIDTH : 0,
          color: TgUiTokens.TAB_BAR_ISLAND_BORDER_COLOR
        })
        .clip(true)
        .opacity(this.isSelected(index) ? 1 : 0)
        .scale({
          x: this.isSelected(index) ? 1 : TgUiTokens.TAB_BAR_PILL_UNSELECTED_SCALE,
          y: this.isSelected(index) ? 1 : TgUiTokens.TAB_BAR_PILL_UNSELECTED_SCALE
        })
        .animation({
          duration: TgUiTokens.TAB_BAR_PILL_ANIM_DURATION,
          curve: Curve.EaseOut
        })

      Column() {
        Stack({ alignContent: Alignment.TopEnd }) {
          Image(icon)
            .width(TgUiTokens.TAB_BAR_ICON_SIZE)
            .height(TgUiTokens.TAB_BAR_ICON_SIZE)
            .fillColor(this.tabIconColor(index))
            .animation({
              duration: TgUiTokens.TAB_BAR_PILL_ANIM_DURATION,
              curve: Curve.EaseOut
            })

          if (showBadge) {
            this.buildBadge()
          }
        }
        .width(TgUiTokens.TAB_BAR_ICON_SIZE)
        .height(TgUiTokens.TAB_BAR_ICON_SIZE)
        .clip(false)

        Text(title)
          .fontSize(TgUiTokens.TAB_BAR_TEXT_SIZE)
          .fontWeight(this.tabFontWeight(index))
          .fontColor(this.tabIconColor(index))
          .margin({ top: TgUiTokens.SPACE_2 })
          .maxLines(1)
          .animation({
            duration: TgUiTokens.TAB_BAR_PILL_ANIM_DURATION,
            curve: Curve.EaseOut
          })
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .opacity(this.tabContentOpacity(index))
      .scale({
        x: this.tabContentScale(index),
        y: this.tabContentScale(index)
      })
      .animation({
        duration: TgUiTokens.TAB_BAR_PILL_ANIM_DURATION,
        curve: Curve.EaseOut
      })
    }
    .layoutWeight(1)
    .height('100%')
    .clip(false)
    .onClick(() => {
      hilog.info(DOMAIN, TAG, 'Tab click index=%{public}d', index);
      this.onTabSelect(index);
    })
  }

  build() {
    Column() {
      Row() {
        this.buildTab(0, this.tabLabel($r('app.string.contacts_title').id, 'Contacts'), $r('app.media.ic_contact'), false)
        this.buildTab(1, this.tabLabel($r('app.string.calls_title').id, 'Calls'), $r('app.media.ic_phone_call'), false)
        this.buildTab(2, this.tabLabel($r('app.string.chats_title').id, 'Chats'), $r('app.media.ic_chat'), true)
        this.buildTab(3, this.tabLabel($r('app.string.settings').id, 'Settings'), $r('app.media.ic_settings'), false)
      }
      .height(TgUiTokens.TAB_BAR_ISLAND_HEIGHT)
      .width(this.islandWidth)
      .borderRadius(TgUiTokens.TAB_BAR_ISLAND_RADIUS)
      .backgroundColor(this.useRealtimeBlur() ? TgUiTokens.TAB_BAR_ISLAND_BG : TgUiTokens.TAB_BAR_ISLAND_FALLBACK_BG)
      .backgroundBlurStyle(TgGlassPolicy.tabBarBlurStyle(), TgGlassPolicy.glassOptions())
      .padding(TgUiTokens.TAB_BAR_ISLAND_INNER_PADDING)
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
      .clip(false)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}

// TgFilterBar — Horizontal glass-capsule filter bar with animated highlight (Phase G).
// iOS Telegram–style ChatListFilterTabContainerNode: single glass island, sliding selection.

import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';

export interface TgFilterBarItem {
  id: string;
  title: string;
  badgeCount: number;
}

interface TabLayout {
  x: number;
  width: number;
}

@ComponentV2
export struct TgFilterBar {
  @Param items: TgFilterBarItem[] = [];
  @Param selectedId: string = '';
  @Param glassMode: string = TgGlassPolicy.MODE_AUTO;
  @Param onFilterSelect: (id: string) => void = (_: string): void => {};

  @Local private highlightX: number = 0;
  @Local private highlightWidth: number = 0;
  @Local private tabLayouts: TabLayout[] = [];
  @Local private containerWidth: number = 0;
  @Local private isFirstLayout: boolean = true;

  private scroller: Scroller = new Scroller();

  private useRealtimeBlur(): boolean {
    return TgGlassPolicy.shouldUseRealtimeBlurForMode(this.glassMode);
  }

  private selectedIndex(): number {
    for (let i = 0; i < this.items.length; i++) {
      if (this.items[i].id === this.selectedId) {
        return i;
      }
    }
    return 0;
  }

  private isSelectedItem(id: string): boolean {
    return id === this.selectedId;
  }

  private badgeBg(id: string): Resource {
    return this.isSelectedItem(id)
      ? TgUiTokens.FILTER_BAR_BADGE_ACTIVE_BG
      : TgUiTokens.FILTER_BAR_BADGE_INACTIVE_BG;
  }

  private handleTabClick(item: TgFilterBarItem, index: number): void {
    this.onFilterSelect(item.id);
    this.animateHighlightTo(index);
    this.scrollToCenter(index);
  }

  private animateHighlightTo(index: number): void {
    if (index < 0 || index >= this.tabLayouts.length) {
      return;
    }
    const layout = this.tabLayouts[index];
    if (layout.width <= 0) {
      return;
    }
    const targetX = layout.x - TgUiTokens.FILTER_BAR_HIGHLIGHT_PADDING_H;
    const targetW = layout.width + TgUiTokens.FILTER_BAR_HIGHLIGHT_PADDING_H * 2;
    try {
      this.getUIContext()?.animateTo({
        duration: TgUiTokens.FILTER_BAR_HIGHLIGHT_ANIM_DURATION,
        curve: Curve.EaseInOut
      }, () => {
        this.highlightX = targetX;
        this.highlightWidth = targetW;
      });
    } catch (_e) {
      this.highlightX = targetX;
      this.highlightWidth = targetW;
    }
  }

  private setHighlightImmediate(index: number): void {
    if (index < 0 || index >= this.tabLayouts.length) {
      return;
    }
    const layout = this.tabLayouts[index];
    if (layout.width <= 0) {
      return;
    }
    this.highlightX = layout.x - TgUiTokens.FILTER_BAR_HIGHLIGHT_PADDING_H;
    this.highlightWidth = layout.width + TgUiTokens.FILTER_BAR_HIGHLIGHT_PADDING_H * 2;
  }

  private scrollToCenter(index: number): void {
    if (index < 0 || index >= this.tabLayouts.length || this.containerWidth <= 0) {
      return;
    }
    const layout = this.tabLayouts[index];
    const tabCenter = layout.x + layout.width / 2;
    const targetOffset = tabCenter - this.containerWidth / 2;
    this.scroller.scrollTo({
      xOffset: Math.max(0, targetOffset),
      yOffset: 0,
      animation: { duration: TgUiTokens.FILTER_BAR_HIGHLIGHT_ANIM_DURATION, curve: Curve.EaseInOut }
    });
  }

  private onTabAreaChange(index: number, _oldArea: Area, newArea: Area): void {
    while (this.tabLayouts.length <= index) {
      const emptyLayout: TabLayout = { x: 0, width: 0 };
      this.tabLayouts.push(emptyLayout);
    }
    const updatedLayout: TabLayout = {
      x: Number(newArea.position.x) || 0,
      width: Number(newArea.width) || 0
    };
    this.tabLayouts[index] = updatedLayout;

    if (this.isFirstLayout && index === this.selectedIndex()) {
      this.isFirstLayout = false;
      this.setHighlightImmediate(index);
    }
  }

  @Builder
  private buildHighlight() {
    if (this.highlightWidth > 0) {
      Row()
        .width(this.highlightWidth)
        .height(TgUiTokens.FILTER_BAR_HIGHLIGHT_HEIGHT)
        .borderRadius(TgUiTokens.FILTER_BAR_HIGHLIGHT_RADIUS)
        .backgroundColor(TgUiTokens.FILTER_BAR_HIGHLIGHT_BG)
        .position({
          x: this.highlightX,
          y: (TgUiTokens.FILTER_BAR_HEIGHT - TgUiTokens.FILTER_BAR_HIGHLIGHT_HEIGHT) / 2
        })
        .hitTestBehavior(HitTestMode.Transparent)
    }
  }

  @Builder
  private buildBadge(item: TgFilterBarItem) {
    if (item.badgeCount > 0) {
      Text(item.badgeCount > 99 ? '99+' : item.badgeCount.toString())
        .fontSize(TgUiTokens.FILTER_BAR_BADGE_FONT_SIZE)
        .fontWeight(FontWeight.Regular)
        .fontColor(TgUiTokens.FILTER_BAR_BADGE_TEXT_COLOR)
        .textAlign(TextAlign.Center)
        .height(TgUiTokens.FILTER_BAR_BADGE_SIZE)
        .constraintSize({ minWidth: TgUiTokens.FILTER_BAR_BADGE_SIZE })
        .padding({ left: TgUiTokens.FILTER_BAR_BADGE_PADDING_H, right: TgUiTokens.FILTER_BAR_BADGE_PADDING_H })
        .borderRadius(TgUiTokens.FILTER_BAR_BADGE_SIZE / 2)
        .backgroundColor(this.badgeBg(item.id))
    }
  }

  @Builder
  private buildTab(item: TgFilterBarItem, index: number) {
    Row({ space: TgUiTokens.FILTER_BAR_BADGE_TEXT_OFFSET }) {
      Text(item.title)
        .fontSize(TgUiTokens.FILTER_BAR_TAB_FONT_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(TgUiTokens.FILTER_BAR_TAB_TEXT_COLOR)
        .maxLines(1)

      this.buildBadge(item)
    }
    .height(TgUiTokens.FILTER_BAR_HEIGHT)
    .padding({
      top: TgUiTokens.FILTER_BAR_TAB_VERTICAL_INSET,
      bottom: TgUiTokens.FILTER_BAR_TAB_VERTICAL_INSET
    })
    .alignItems(VerticalAlign.Center)
    .onAreaChange((oldArea: Area, newArea: Area) => {
      this.onTabAreaChange(index, oldArea, newArea);
    })
    .onClick(() => {
      this.handleTabClick(item, index);
    })
  }

  @Builder
  private buildIslandSpecular() {
    if (this.useRealtimeBlur()) {
      Column()
        .width('100%')
        .height('100%')
        .borderRadius(TgUiTokens.FILTER_BAR_RADIUS)
        .linearGradient({
          angle: 115,
          colors: [
            [TgUiTokens.GLASS_SPECULAR_TOP, 0.0],
            [TgUiTokens.GLASS_SPECULAR_MID, 0.36],
            [TgUiTokens.GLASS_SPECULAR_BOTTOM, 1.0]
          ]
        })
        .hitTestBehavior(HitTestMode.Transparent)
    }
  }

  build() {
    Column() {
      Scroll(this.scroller) {
        Stack() {
          this.buildHighlight()

          Row({ space: TgUiTokens.FILTER_BAR_TAB_MIN_SPACING }) {
            ForEach(this.items, (item: TgFilterBarItem, index: number) => {
              this.buildTab(item, index)
            }, (item: TgFilterBarItem) => item.id)
          }
          .padding({
            left: TgUiTokens.FILTER_BAR_INNER_PADDING,
            right: TgUiTokens.FILTER_BAR_INNER_PADDING
          })
          .justifyContent(FlexAlign.Start)
          .alignItems(VerticalAlign.Center)
          .height(TgUiTokens.FILTER_BAR_HEIGHT)
        }
        .alignContent(Alignment.Start)
        .height(TgUiTokens.FILTER_BAR_HEIGHT)
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .width('100%')
      .height(TgUiTokens.FILTER_BAR_HEIGHT)
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        this.containerWidth = Number(newArea.width) || 0;
      })
      .constraintSize({ maxWidth: TgUiTokens.FILTER_BAR_MAX_WIDTH })
      .borderRadius(TgUiTokens.FILTER_BAR_RADIUS)
      .backgroundColor(this.useRealtimeBlur() ? TgUiTokens.FILTER_BAR_BG : TgUiTokens.FILTER_BAR_FALLBACK_BG)
      .backgroundBlurStyle(TgGlassPolicy.filterBarBlurStyle())
      .overlay(this.buildIslandSpecular())
      .border({
        width: TgUiTokens.FILTER_BAR_BORDER_WIDTH,
        color: TgUiTokens.FILTER_BAR_BORDER_COLOR
      })
      .shadow({
        radius: TgUiTokens.FILTER_BAR_SHADOW_RADIUS,
        offsetX: 0,
        offsetY: TgUiTokens.FILTER_BAR_SHADOW_OFFSET_Y,
        color: TgUiTokens.FILTER_BAR_SHADOW_COLOR
      })
      .clip(true)
      .margin({
        left: TgUiTokens.FILTER_BAR_SIDE_INSET,
        right: TgUiTokens.FILTER_BAR_SIDE_INSET
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}

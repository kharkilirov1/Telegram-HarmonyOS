export interface RootTabBarRenderState {
  overlap: boolean;
  height: number;
  bottomMargin: number;
  opacity: number;
  maskHeight: number;
}

export interface RootSearchDockGeometry {
  groupWidth: number;
  tabBarWidth: number;
  activeTabBarWidth: number;
  miniBarExpandedWidth: number;
  miniBarIdleWidth: number;
  gap: number;
  sideMargin: number;
}

export const ROOT_TAB_BAR_VISIBLE_HEIGHT: number = 48;
export const ROOT_TAB_BAR_FLOATING_BOTTOM_MARGIN: number = 30;
export const ROOT_TAB_BAR_BACKPLATE_MASK_HEIGHT: number = 110;
export const ROOT_TAB_BAR_CONTENT_AVOID_FLOOR: number = 10;
export const ROOT_TAB_BAR_CONTENT_BREATHING_ROOM: number = 6;
export const ROOT_SEARCH_DOCK_MAX_GROUP_WIDTH: number = 500;
export const ROOT_SEARCH_DOCK_SIDE_MARGIN: number = 20;
export const ROOT_SEARCH_DOCK_INNER_INSET: number = 0;
export const ROOT_SEARCH_DOCK_CONTROL_SIZE: number = ROOT_TAB_BAR_VISIBLE_HEIGHT;
export const ROOT_SEARCH_DOCK_IDLE_WIDTH: number = ROOT_TAB_BAR_VISIBLE_HEIGHT;
export const ROOT_SEARCH_DOCK_GAP: number = 16;
export const ROOT_SEARCH_DOCK_FALLBACK_CONTAINER_WIDTH: number = 436;

export function resolveRootTabBarRenderState(selectedIndex: number,
  chatScreenVisible: boolean, keyboardVisible: boolean = false,
  keepVisibleForKeyboard: boolean = false): RootTabBarRenderState {
  const hidden = (selectedIndex === 2 && chatScreenVisible) ||
    (keyboardVisible && !keepVisibleForKeyboard);
  if (hidden) {
    return {
      overlap: false,
      height: 0,
      bottomMargin: 0,
      opacity: 0,
      maskHeight: 0
    };
  }
  return {
    overlap: true,
    height: ROOT_TAB_BAR_VISIBLE_HEIGHT,
    bottomMargin: ROOT_TAB_BAR_FLOATING_BOTTOM_MARGIN,
    opacity: 1,
    maskHeight: ROOT_TAB_BAR_BACKPLATE_MASK_HEIGHT
  };
}

export function resolveRootSearchDockGeometry(containerWidth: number): RootSearchDockGeometry {
  const safeContainerWidth = Number.isFinite(containerWidth) && containerWidth > 0
    ? containerWidth
    : ROOT_SEARCH_DOCK_FALLBACK_CONTAINER_WIDTH;
  const groupWidth = Math.min(ROOT_SEARCH_DOCK_MAX_GROUP_WIDTH, safeContainerWidth);
  const miniBarExpandedWidth = Math.max(
    ROOT_SEARCH_DOCK_IDLE_WIDTH,
    groupWidth - ROOT_SEARCH_DOCK_SIDE_MARGIN * 2
  );
  const tabBarWidth = Math.max(
    0,
    miniBarExpandedWidth - ROOT_SEARCH_DOCK_IDLE_WIDTH - ROOT_SEARCH_DOCK_GAP
  );
  return {
    groupWidth,
    tabBarWidth,
    activeTabBarWidth: ROOT_TAB_BAR_VISIBLE_HEIGHT,
    miniBarExpandedWidth,
    miniBarIdleWidth: ROOT_SEARCH_DOCK_IDLE_WIDTH,
    gap: ROOT_SEARCH_DOCK_GAP,
    sideMargin: ROOT_SEARCH_DOCK_SIDE_MARGIN
  };
}

export function computeRootTabContentBottomInset(systemBottomInset: number,
  navigationBottomInset: number): number {
  const resolvedBottomInset = Math.max(0, systemBottomInset, navigationBottomInset);
  return ROOT_TAB_BAR_VISIBLE_HEIGHT
    + Math.max(resolvedBottomInset, ROOT_TAB_BAR_CONTENT_AVOID_FLOOR)
    + ROOT_TAB_BAR_CONTENT_BREATHING_ROOM;
}

// Accepted legacy fallback. Its relationship to a runtime avoid-area value is
// unproven and intentionally deferred beyond the zero-delta M2a refactor.
export const ROOT_TAB_BAR_FALLBACK_CONTENT_INSET: number = 82;

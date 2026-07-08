// SafeAreaUtils — centralised safe-area metrics computation
// Eliminates copy-paste of computeSafeInsets / bindWindowSizeListener across shell pages.

import { TgUiTokens } from '../tg_ui/tokens/TgUiTokens';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

declare function px2vp(value: number): number;

/**
 * Compute the total top-bar height including the system status-bar inset.
 * Falls back to TgUiTokens.TOP_BAR_HEIGHT when the window stage is unavailable.
 */
export function computeTopBarHeight(context: common.UIAbilityContext): number {
  try {
    const windowStage = context.windowStage;
    if (windowStage) {
      const mainWindow = windowStage.getMainWindowSync();
      const systemAvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const topInset = px2vp(systemAvoidArea.topRect.height);
      return topInset + TgUiTokens.TOP_BAR_HEIGHT + TgUiTokens.TOP_BAR_BOTTOM_PADDING;
    }
  } catch (_error) {
  }
  return TgUiTokens.STATUS_BAR_FALLBACK_INSET + TgUiTokens.TOP_BAR_HEIGHT + TgUiTokens.TOP_BAR_BOTTOM_PADDING;
}

/**
 * Compute the chat-list header height including the integrated search lane.
 * Falls back to the tokenized chat-list navigation height when the window stage is unavailable.
 */
export function computeChatListTopBarHeight(context: common.UIAbilityContext): number {
  try {
    const windowStage = context.windowStage;
    if (windowStage) {
      const mainWindow = windowStage.getMainWindowSync();
      const systemAvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const topInset = px2vp(systemAvoidArea.topRect.height);
      return topInset + TgUiTokens.CHAT_LIST_NAV_TOTAL_HEIGHT;
    }
  } catch (_error) {
  }
  return TgUiTokens.STATUS_BAR_FALLBACK_INSET + TgUiTokens.CHAT_LIST_NAV_TOTAL_HEIGHT;
}

/**
 * Compute the bottom content inset for tab pages (accounts for the overlaid tab-bar capsule + system nav).
 * Falls back to TgUiTokens.TAB_BAR_CONTENT_SAFE_BOTTOM.
 */
export function computeTabBottomInset(context: common.UIAbilityContext): number {
  try {
    const windowStage = context.windowStage;
    if (windowStage) {
      const mainWindow = windowStage.getMainWindowSync();
      const systemAvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      let bottomInset = px2vp(systemAvoidArea.bottomRect.height);
      try {
        const navAvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
        bottomInset = Math.max(bottomInset, px2vp(navAvoidArea.bottomRect.height));
      } catch (_error) {
      }
      return TgUiTokens.TAB_BAR_ISLAND_HEIGHT
        + Math.max(bottomInset, TgUiTokens.TAB_BAR_ISLAND_BOTTOM_MARGIN)
        + TgUiTokens.SPACE_6;
    }
  } catch (_error) {
  }
  return TgUiTokens.TAB_BAR_CONTENT_SAFE_BOTTOM;
}

/**
 * Compute the bottom overlay inset for the chat screen (simple max with SPACE_8).
 * Falls back to TgUiTokens.SPACE_8.
 */
export function computeChatBottomInset(context: common.UIAbilityContext): number {
  try {
    const windowStage = context.windowStage;
    if (windowStage) {
      const mainWindow = windowStage.getMainWindowSync();
      const systemAvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      let bottomInset = px2vp(systemAvoidArea.bottomRect.height);
      try {
        const navAvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
        bottomInset = Math.max(bottomInset, px2vp(navAvoidArea.bottomRect.height));
      } catch (_error) {
      }
      return Math.max(bottomInset, TgUiTokens.SPACE_8);
    }
  } catch (_error) {
  }
  return TgUiTokens.SPACE_8;
}

/**
 * Get the main window from UIAbilityContext. Returns undefined on failure.
 */
export function getMainWindow(context: common.UIAbilityContext): window.Window | undefined {
  try {
    const windowStage = context.windowStage;
    if (windowStage) {
      return windowStage.getMainWindowSync();
    }
  } catch (_error) {
  }
  return undefined;
}

/**
 * Safely remove a previously registered windowSizeChange listener.
 */
export function removeWindowSizeListener(mainWindow: window.Window | undefined): void {
  if (mainWindow !== undefined) {
    try {
      mainWindow.off('windowSizeChange');
    } catch (_error) {
    }
    try {
      mainWindow.off('avoidAreaChange');
    } catch (_error) {
    }
  }
}

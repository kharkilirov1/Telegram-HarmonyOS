// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { ChatTimelineDataSource } from './ChatTimelineDataSource';
import { computeTopBarHeight, computeChatBottomInset, getMainWindow, addWindowSizeListener, removeWindowSizeListener } from '../../utils/SafeAreaUtils';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

const COMPOSER_KEYBOARD_SETTLE_MS = 320;
declare function px2vp(value: number): number;

export interface ChatWindowGeometryCoordinatorPort {
  bottomOverlayInset: number;
  chatViewportHeight: number;
  composerResizeKeepsBottomAligned: boolean;
  dataSource: ChatTimelineDataSource;
  isSearchMode: boolean;
  lastVisibleEndIndex: number;
  listScroller: Scroller;
  mainWindow?: window.Window;
  pageLifecycleToken: number;
  pinnedMessageVisible: boolean;
  pinnedMessagesListVisible: boolean;
  showMediaGallery: boolean;
  timelineContainerWidth: number;
  topBarTotalHeight: number;
  windowSizeListener?: () => void;
  computeSafeInsets(): void;
  scheduleComposerBottomAlignment(): void;
  scheduleLifecycleTask(delayMs: number, task: () => void): void;
  scrollTimelineToBottomAligned(): void;
  setEmojiPanelVisible(value: boolean): void;
  setStickerPanelVisible(value: boolean): void;
  shouldKeepTimelineBottomAligned(): boolean;
  shouldShowPinnedMessagePanel(): boolean;
  updateTimelineContainerWidth(windowWidthPx: number): void;
  getUIContext(): UIContext;
}

export function scrollToBottomSoon(host: ChatWindowGeometryCoordinatorPort): void {
    host.scheduleLifecycleTask(100, () => {
      host.scrollTimelineToBottomAligned();
    });
  }

export function scrollTimelineToBottomAligned(host: ChatWindowGeometryCoordinatorPort): void {
    const lastIndex = host.dataSource.totalCount() - 1;
    if (lastIndex < 0) {
      return;
    }
    // The List viewport already ends above the composer. END keeps the last
    // bubble attached to that moving edge while the keyboard/input grows.
    host.listScroller.scrollToIndex(lastIndex, false, ScrollAlign.END);
  }

export function shouldKeepTimelineBottomAligned(host: ChatWindowGeometryCoordinatorPort): boolean {
    const total = host.dataSource.totalCount();
    if (total === 0 || host.lastVisibleEndIndex < 0) {
      return true;
    }
    return total - 1 - host.lastVisibleEndIndex <= 3;
  }

export function scheduleComposerBottomAlignment(host: ChatWindowGeometryCoordinatorPort): void {
    host.scheduleLifecycleTask(16, () => {
      host.scrollTimelineToBottomAligned();
    });
    // RESIZE changes the page throughout the IME transition. Re-attach once
    // after it settles so the final bubble cannot remain below the new edge.
    host.scheduleLifecycleTask(COMPOSER_KEYBOARD_SETTLE_MS, () => {
      host.scrollTimelineToBottomAligned();
    });
  }

export function handleComposerFocusChange(host: ChatWindowGeometryCoordinatorPort, focused: boolean): void {
    if (!focused) {
      host.composerResizeKeepsBottomAligned = false;
      return;
    }
    if (!host.composerResizeKeepsBottomAligned) {
      host.composerResizeKeepsBottomAligned = host.shouldKeepTimelineBottomAligned();
    }
    if (host.composerResizeKeepsBottomAligned) {
      host.scheduleComposerBottomAlignment();
    }
  }

export function handleComposerWillFocus(host: ChatWindowGeometryCoordinatorPort): void {
    // Touch down arrives before ArkUI starts the IME RESIZE pass. Capture the
    // old viewport here; onFocus can already observe the shortened List.
    host.composerResizeKeepsBottomAligned = host.shouldKeepTimelineBottomAligned();
    // Telegram's custom emoji/sticker panel and the system IME share one slot.
    // Clear custom mode on touch-down so it is removed before focus opens IME.
    host.setEmojiPanelVisible(false);
    host.setStickerPanelVisible(false);
  }

export function handleChatViewportAreaChange(host: ChatWindowGeometryCoordinatorPort, newArea: Area): void {
    const h = newArea.height as number;
    if (h <= 0 || h === host.chatViewportHeight) {
      return;
    }
    host.chatViewportHeight = h;
    if (host.composerResizeKeepsBottomAligned) {
      host.scheduleLifecycleTask(16, () => {
        host.scrollTimelineToBottomAligned();
      });
    }
  }

export function chatTopInset(host: ChatWindowGeometryCoordinatorPort): number {
    return Math.max(0, host.topBarTotalHeight - TgUiTokens.TOP_BAR_HEIGHT - TgUiTokens.TOP_BAR_BOTTOM_PADDING);
  }

export function shouldShowPinnedMessagePanel(host: ChatWindowGeometryCoordinatorPort): boolean {
    return host.pinnedMessageVisible && !host.isSearchMode && !host.showMediaGallery &&
      !host.pinnedMessagesListVisible;
  }

export function chatContentStartOffset(host: ChatWindowGeometryCoordinatorPort): number {
    if (!host.shouldShowPinnedMessagePanel()) {
      return host.topBarTotalHeight;
    }
    return host.topBarTotalHeight + TgUiTokens.PINNED_PANEL_HEIGHT + TgUiTokens.SPACE_4;
  }

export function computeSafeInsets(host: ChatWindowGeometryCoordinatorPort): void {
    try {
      const context: common.UIAbilityContext = host.getUIContext().getHostContext() as common.UIAbilityContext;
      host.topBarTotalHeight = computeTopBarHeight(context);
      host.bottomOverlayInset = computeChatBottomInset(context);
    } catch (_error) {
      host.topBarTotalHeight = TgUiTokens.TOP_BAR_HEIGHT;
      host.bottomOverlayInset = TgUiTokens.SPACE_8;
    }
  }

export function bindWindowSizeListener(host: ChatWindowGeometryCoordinatorPort): void {
    try {
      removeWindowSizeListener(host.windowSizeListener);
      host.windowSizeListener = undefined;
      host.mainWindow = undefined;
      const context: common.UIAbilityContext = host.getUIContext().getHostContext() as common.UIAbilityContext;
      const boundWindow = getMainWindow(context);
      host.mainWindow = boundWindow;
      if (boundWindow !== undefined) {
        const lifecycleToken: number = host.pageLifecycleToken;
        host.updateTimelineContainerWidth(boundWindow.getWindowProperties().windowRect.width);
        host.windowSizeListener = addWindowSizeListener(boundWindow, (size: window.Size) => {
          if (lifecycleToken !== host.pageLifecycleToken || host.mainWindow !== boundWindow) {
            return;
          }
          host.updateTimelineContainerWidth(size.width);
          host.computeSafeInsets();
        }, (data: window.AvoidAreaOptions) => {
          // Status-bar / safe-area height changes are not guaranteed by windowSizeChange.
          if (lifecycleToken !== host.pageLifecycleToken || host.mainWindow !== boundWindow) {
            return;
          }
          if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
            host.computeSafeInsets();
          }
        });
      }
    } catch (_error) {
      host.timelineContainerWidth = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
    }
  }

export function updateTimelineContainerWidth(host: ChatWindowGeometryCoordinatorPort, windowWidthPx: number): void {
    const widthVp: number = px2vp(windowWidthPx);
    const horizontalInsets: number = TgUiTokens.SPACE_12 * 2;
    const computed: number = Math.floor(widthVp - horizontalInsets);
    host.timelineContainerWidth = Math.max(1, computed);
  }

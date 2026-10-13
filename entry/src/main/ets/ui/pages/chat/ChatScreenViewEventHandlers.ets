// Extracted from TgChatScreenPage; layout and callback semantics are preserved.

import { ChatTimelineDataSource } from './ChatTimelineDataSource';
import { ChatScreenRouteParams } from './ChatScreenRouteParams';
import { reconcileCustomEmojiEntities } from '../../tg_ui/utils/TgCustomEmojiDraftPolicy';
import { PendingJumpSignal } from './PendingJumpSignal';
import { PendingSharedMediaAction, PendingSharedMediaActionSignal } from './PendingSharedMediaActionSignal';
import { PendingChatSearchSignal } from './PendingChatSearchSignal';
import { CustomEmojiTextEntity } from '../../../core/model/AppCommand';
import { MediaGalleryItem } from '../../../models/MediaGalleryItem';
import { AppStore } from '../../../core/store/AppStore';

export interface HandleTimelineScrollIndexPort {
  blockAutoPaginationUntilUserScroll: boolean;
  dataSource: ChatTimelineDataSource;
  isApplyingTimelineDiff: boolean;
  isLoadingNewer: boolean;
  isLoadingOlder: boolean;
  isNearBottomPaginationEdge(end: number, totalCount: number): boolean;
  isNearTopPaginationEdge(start: number): boolean;
  lastVisibleEndIndex: number;
  lastVisibleStartIndex: number;
  loadNewerMessages(): void;
  loadOlderMessages(): void;
  refreshScrollToBottomVisibility(endIndex: number): void;
  shouldSuppressLoadOlder(): boolean;
}

export interface HandleComposerTextChangePort {
  composerDraftText: string;
  composerResizeKeepsBottomAligned: boolean;
  customEmojiDraftEntities: CustomEmojiTextEntity[];
  expectedProgrammaticCustomEmojiText: string;
  scheduleDraftDebounce(): void;
  shouldKeepTimelineBottomAligned(): boolean;
}

export interface HandleComposerAreaChangePort {
  composerResizeKeepsBottomAligned: boolean;
  composerTotalHeight: number;
  scheduleComposerBottomAlignment(): void;
  shouldKeepTimelineBottomAligned(): boolean;
}

export interface HandleGalleryIndexChangePort {
  galleryCurrentIndex: number;
  galleryItems: MediaGalleryItem[];
  gallerySourceMessageId: string;
}

export interface HandleNavReadyPort {
  bindChatRoute(params: ChatScreenRouteParams | undefined): void;
  pageStack: NavPathStack;
}

export interface HandleNavShownPort {
  activeChatId: number;
  accountStore?: AppStore;
  routeContext?: ChatScreenRouteParams;
  beginSharedMediaAction(action: PendingSharedMediaAction): void;
  jumpToMessageId(messageId: string): void;
  openSearch(): void;
  showOwnedChatRoute(): boolean;
}

export interface HandleNavBackPressedPort {
  handleBackPress(): void;
  routeActivated: boolean;
}

export interface ChatScreenViewEventHandlersPort extends HandleTimelineScrollIndexPort, HandleComposerTextChangePort, HandleComposerAreaChangePort, HandleGalleryIndexChangePort, HandleNavReadyPort, HandleNavShownPort, HandleNavBackPressedPort {}

export function handleTimelineScrollIndex(host: HandleTimelineScrollIndexPort, start: number, end: number): void {
  host.lastVisibleStartIndex = start;
  host.lastVisibleEndIndex = end;
  host.refreshScrollToBottomVisibility(end);
  if (host.isApplyingTimelineDiff) {
    return;
  }
  // Android pattern: simple !isLoading guard, no latch required.
  if (host.blockAutoPaginationUntilUserScroll) {
    return;
  }
  if (host.shouldSuppressLoadOlder()) {
    return;
  }
  const totalCount = host.dataSource.totalCount();
  if (host.isNearTopPaginationEdge(start) && !host.isLoadingOlder) {
    host.loadOlderMessages();
  }
  if (host.isNearBottomPaginationEdge(end, totalCount) && !host.isLoadingNewer) {
    host.loadNewerMessages();
  }
}

export function handleComposerTextChange(host: HandleComposerTextChangePort, value: string): void {
  host.composerResizeKeepsBottomAligned = host.shouldKeepTimelineBottomAligned();
  if (value === host.expectedProgrammaticCustomEmojiText) {
    host.expectedProgrammaticCustomEmojiText = '';
  } else if (value !== host.composerDraftText && host.customEmojiDraftEntities.length > 0) {
    host.customEmojiDraftEntities = reconcileCustomEmojiEntities(
      host.composerDraftText,
      value,
      host.customEmojiDraftEntities
    );
    host.expectedProgrammaticCustomEmojiText = '';
  }
  host.composerDraftText = value;
  host.scheduleDraftDebounce();
}

export function handleComposerAreaChange(host: HandleComposerAreaChangePort, height: number): void {
  const h = height;
  if (h > 0 && h !== host.composerTotalHeight) {
    const keepBottomAligned = host.composerResizeKeepsBottomAligned ||
      host.shouldKeepTimelineBottomAligned();
    host.composerTotalHeight = h;
    host.composerResizeKeepsBottomAligned = false;
    if (keepBottomAligned) {
      host.scheduleComposerBottomAlignment();
    }
  }
}

export function handleGalleryIndexChange(host: HandleGalleryIndexChangePort, index: number): void {
  host.galleryCurrentIndex = index;
  if (index >= 0 && index < host.galleryItems.length) {
    host.gallerySourceMessageId = host.galleryItems[index].sourceMessageId;
  }
}

export function handleNavReady(host: HandleNavReadyPort, context: NavDestinationContext): void {
  host.pageStack = context.pathStack;
  host.bindChatRoute(context.pathInfo.param as ChatScreenRouteParams | undefined);
}

export function handleNavShown(host: HandleNavShownPort): void {
  if (!host.showOwnedChatRoute()) return;
  // Shared Media actions reuse the exact chat gallery/download/playback
  // paths after the profile stack unwinds. Plain jump intent remains for
  // older callers and reply/search navigation.
  const pendingAction = PendingSharedMediaActionSignal.consume(host.activeChatId);
  if (pendingAction !== undefined) {
    host.beginSharedMediaAction(pendingAction);
  } else {
    const pendingId = PendingJumpSignal.consume(host.activeChatId);
    if (pendingId !== '0') {
      host.jumpToMessageId(pendingId);
    }
  }
  const store = host.accountStore;
  const route = host.routeContext;
  const searchOwner = store !== undefined && route !== undefined &&
    route.accountStore === store && route.chatId === host.activeChatId && route.isCurrentAccount(store)
    ? store : undefined;
  if (PendingChatSearchSignal.consume(host.activeChatId, searchOwner)) {
    host.openSearch();
  }
}

export function handleNavBackPressed(host: HandleNavBackPressedPort): boolean {
  // Invalid/unbound routes expose no account actions; let the native
  // destination handle an explicit Back instead of trapping the user.
  if (!host.routeActivated) return false;
  host.handleBackPress();
  return true;
}

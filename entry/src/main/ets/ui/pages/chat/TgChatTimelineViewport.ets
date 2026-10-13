// Extracted from TgChatScreenPage; layout and callback semantics are preserved.

import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { TgDateSeparator, TgUnreadMarker } from '../../tg_ui/atoms/TgDateSeparator';
import { ChatTimelineDataSource } from './ChatTimelineDataSource';
import { ChatTimelineEntryVO } from './ChatTimelineVO';
import { localized } from '../../../core/utils/AppResource';
import { ChatChromeState } from './ChatChromeState';
import { ChatMediaViewState } from './ChatMediaViewState';
import { ChatTimelineViewState } from './ChatTimelineViewState';
import { ChatTimelineViewportPort } from './ChatScreenViewPorts';
import { TgChatTimelineRow } from './TgChatTimelineRow';

@ComponentV2
export struct TgChatTimelineViewport {
  @Require @Param chrome: ChatChromeState;
  @Require @Param media: ChatMediaViewState;
  @Require @Param timeline: ChatTimelineViewState;
  @Require @Param bindings: ChatTimelineViewportPort;
  @Require @Param dataSource: ChatTimelineDataSource;
  @Require @Param listScroller: Scroller;

  build() {
    // ── Content layer (under top bar, physically ends above composer) ──
    Column() {
      if (this.chrome.activeChatId !== 0) {
        if (this.bindings.shouldShowHistoryLoadingPlaceholder()) {
          Column({ space: TgUiTokens.SPACE_8 }) {
            LoadingProgress()
              .width(TgUiTokens.CHATLIST_STATUS_ICON_SIZE)
              .height(TgUiTokens.CHATLIST_STATUS_ICON_SIZE)
              .color(TgUiTokens.COLOR_ICON_PRIMARY)
            Text(localized($r('app.string.loading').id, 'Loading...'))
              .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
              .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else if (this.dataSource.totalCount() > 0) {
          List({ scroller: this.listScroller, initialIndex: this.timeline.listInitialIndex }) {
            LazyForEach(this.dataSource, (entry: ChatTimelineEntryVO) => {
              ListItem() {
                Row() {
                  this.buildTimelineEntry(entry)
                }
                .width('100%')
                .backgroundColor(entry.searchFlash ? TgUiTokens.SEARCH_HIT_FLASH : Color.Transparent)
                .border({
                  width: entry.searchFlash && this.bindings.useSearchFlashOutline(entry)
                    ? TgUiTokens.SEARCH_HIT_OUTLINE_WIDTH : 0,
                  color: TgUiTokens.SEARCH_HIT_OUTLINE
                })
                .borderRadius(entry.searchFlash && this.bindings.useSearchFlashOutline(entry)
                  ? TgUiTokens.SEARCH_HIT_OUTLINE_RADIUS : 0)
                // NO .reuseId here: V1 reuse on a @ComponentV2 row silently skips
                // @Param re-init — notifyDataChange re-rendered a STALE bubble
                // (download button survived a completed download; Monitor probe
                // confirmed fresh videoPath never reached the reused component).
                // Proper V2 reuse would be @ReusableV2 + .reuse() (API 18+) — a
                // separate migration if scroll perf ever demands it.
              }
            }, (entry: ChatTimelineEntryVO) => entry.key)
          }
          .cachedCount(30)
          .listDirection(Axis.Vertical)
          .layoutWeight(1)
          .edgeEffect(EdgeEffect.Spring)
          .scrollBar(BarState.Off)
          .contentStartOffset(this.bindings.chatContentStartOffset())
          // iOS-style under-glass timeline: the List viewport spans the full
          // screen so bubbles scroll beneath the composer capsule (the glass
          // samples real content), while contentEndOffset keeps the resting
          // bottom position of the last message above the composer. This
          // replaces the old viewport-clip padding (spec
          // TgIosNativeLiquidComposer.md contract reversed 2026-08-29).
          .contentEndOffset(this.chrome.composerTotalHeight)
          .maintainVisibleContentPosition(true)
          .onDidScroll((scrollOffset: number, scrollState: ScrollState) => {
            this.bindings.maybeUnlockAutoPagination(scrollOffset, scrollState);
          })
          .onScrollIndex((start: number, end: number) => {
            this.bindings.handleTimelineScrollIndex(start, end);
          })
          .onTouch((event: TouchEvent) => {
            this.bindings.handleTimelineTouch(event);
          })
        } else {
          Column({ space: TgUiTokens.SPACE_8 }) {
            Text(localized($r('app.string.no_messages').id, 'No messages yet'))
              .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
              .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }
      } else {
        Column({ space: TgUiTokens.SPACE_8 }) {
          Text(localized($r('app.string.chat_not_selected').id, 'Chat is not selected'))
            .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildTimelineEntry(entry: ChatTimelineEntryVO) {
      if (entry.kind === 'date') {
        TgDateSeparator({
          text: entry.dateText,
          containerWidth: this.chrome.timelineContainerWidth
        })
          .padding({ top: TgUiTokens.SPACE_8, bottom: TgUiTokens.SPACE_4 })
      } else if (entry.kind === 'unread') {
        TgUnreadMarker({
          text: entry.unreadText,
          containerWidth: this.chrome.timelineContainerWidth
        })
          .padding({
            top: TgUiTokens.UNREAD_MARKER_MARGIN_TOP,
            bottom: TgUiTokens.UNREAD_MARKER_MARGIN_BOTTOM
          })
      } else if (entry.kind === 'service') {
        TgDateSeparator({
          text: entry.serviceText,
          containerWidth: this.chrome.timelineContainerWidth,
          maxLines: 3,
          isService: true
        })
          .padding({ top: TgUiTokens.SPACE_4, bottom: TgUiTokens.SPACE_4 })
      } else {
        TgChatTimelineRow({ chrome: this.chrome, media: this.media, timeline: this.timeline, bindings: this.bindings, entry: entry })
      }
    }
}

# TgPinnedMessageList Component Passport

## Scope

- Atom: `TgPinnedMessageList`.
- Milestone: M4 Timeline Completeness.
- Presentation-only list for the exact TDLib `searchMessagesFilterPinned`
  collection; fetching, pagination and timeline jumps remain page-owned.

## References

- Shipped Telegram iOS pinned-panel list action.
- Telegram iOS:
  `ChatPinnedMessageTitlePanelNode.listPressed()` ->
  `ChatController.openPinnedMessages(at:)` -> `.pinnedMessages(id:)`.
- TDLib: `searchChatMessages(..., filter: searchMessagesFilterPinned)` returns
  reverse-chronological `foundChatMessages` with `total_count` and the exact
  `next_from_message_id` cursor.

## Inputs and states

- `items`: stable message id, localized title, preview, stripe index/count and
  optional thumbnail.
- `contentStartOffset`, `bottomInset`.
- populated, loading-more and empty states.
- `onItemPress(index)` and `onLoadMore()`.

## Layout contract

- Reuses the accepted isolated `TgPinnedMessagePanel` geometry instead of
  adding a full-width plate.
- Each row keeps its true `index / totalCount` stripe position and disables the
  panel trailing action; the whole row jumps to that message.
- The list scrolls beneath the existing chat top capsules, respects the
  measured top offset and leaves the system bottom inset clear.

## Acceptance

- [x] No fabricated count or `lastMessage` fallback.
- [x] Int64 ids/cursors remain strings.
- [x] Opening the list, selecting an older pin and returning to the timeline
  jump to that exact message.
- [x] Pagination stops on cursor `0`, a repeated cursor or lifecycle/chat
  change.

## Runtime witness

- API23 real `HUAWEI Chat`: exact total `2548`; older row `#2547` updated the
  live panel and jumped to `HUAWEI готовит ноутбук...`.
- Repeated real swipes crossed the first 100-result page and exposed
  `#2434...#2421`, proving that the opaque-cursor path engaged.
- The right-edge spring was captured mid-transaction and at rest under
  `.codex/ui-audit/2026-07-19/pinned-messages-navigation/`.

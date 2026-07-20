# TgReplySnippet (Phase C / Step 3)

## Goal
Implement Telegram-like reply snippet block used above message text:
- left accent line
- author/title
- reply preview text
- optional media thumbnail

The visual atom stays UI-only. Live integration additionally hydrates missing
reply originals so the atom receives real author/preview/thumbnail data.

## iOS References
- `submodules/TelegramUI/Components/Chat/ChatMessageReplyInfoNode/Sources/ChatMessageReplyInfoNode.swift`
  - primary visual tree for reply header
  - line + title + preview + optional image geometry
  - quote mode line/title/text max lines behavior
- `submodules/TelegramUI/Components/Chat/ChatMessageBubbleItemNode/Sources/ChatMessageBubbleItemNode.swift`
  - integration placement inside bubble content stack
- `submodules/TelegramUI/Components/Chat/ChatMessageTextBubbleContentNode/Sources/ChatMessageTextBubbleContentNode.swift`
  - trailing/meta coexistence constraints with message body
- `submodules/TelegramCore/Sources/Account/AccountIntermediateState.swift:800-814`
  - records `ReplyMessageAttribute.messageId` as an associated-message dependency

## Behavior References
- TDLib: `tdlib/td/generate/scheme/td_api.tl:10295-10304`
  - `getRepliedMessage(chat_id, message_id)` receives the **replying message id**
  - returns the original non-bundled message or an error when unavailable
- Telegram Android:
  `TMessagesProj/src/main/java/org/telegram/messenger/MediaDataController.java:6252-6285`
  - resolves replies already present in the loaded batch first
  - gathers missing originals afterward and updates the same message row

## Live Hydration Contract
1) `ChatTimelineVO` remains a pure projection and may temporarily emit the
   localized generic fallback while the original is absent.
2) `ReplyHydrationCoordinator` scans the loaded chat window newest-first,
   collapses duplicate targets, and caps work to 8 requests per pass / 32 per
   page session.
3) `getRepliedMessage` is sent with the replying row's id, never the missing
   target id.
4) A valid returned `message` is stored in a context-scoped associated-message
   map under `<reply_to.chat_id>:<message_id>`, not inserted into normal chat
   history. TDLib may return an original whose actual `chat_id` differs from
   the relationship chat id, so those two identities must remain separate.
5) The existing timeline rebuild and `ChatTimelineDataSource.sameMessage`
   reply-field diff replace the placeholder in-place. The `LazyForEach` item
   key carries a compact reply render stamp because `@ComponentV2` `@Param`
   values remain frozen when only `onDataChange` fires on the current runtime.
   Only loaded chat rows are scanned for new work; associated originals are
   lookup data, not a recursive hydration queue.
6) Failed or deleted originals are attempted once per page session, avoiding a
   rebuild/request loop. Re-entering the chat permits a fresh attempt.

## Props / Inputs
- `author: string`
- `preview: string`
- `isOutgoing: boolean`
- `isQuote: boolean`
- `hasThumbnail: boolean`
- `thumbnailSrc: Resource | string`
- `containerWidth: number`
- `maxWidthRatio: number`

## State Matrix (demo)
- incoming/outgoing basic
- with/without thumbnail
- long author
- long preview
- quote mode incoming/outgoing
- quote + thumbnail
- narrow / wide width containers

## Layout Rules
1) Root width constrained by `containerWidth * maxWidthRatio`.
2) Left accent line has fixed tokenized width and fills snippet height.
3) Author and preview are ellipsized using `maxLines` contracts:
   - regular: 1 line each
   - quote: 2 lines author + up to 5 preview lines.
4) Optional thumbnail is anchored right with fixed tokenized size/radius.
5) All spacing, typography, colors, and geometry are tokenized.

## Token Mapping
- Geometry:
  - `REPLY_SNIPPET_MIN_HEIGHT`
  - `REPLY_SNIPPET_PADDING_H/V`
  - `REPLY_SNIPPET_BAR_WIDTH/RADIUS/GAP`
  - `REPLY_SNIPPET_TEXT_GAP`
  - `REPLY_SNIPPET_THUMB_SIZE/RADIUS/GAP`
- Typography:
  - `REPLY_SNIPPET_TITLE_SIZE/WEIGHT/LINE_HEIGHT`
  - `REPLY_SNIPPET_PREVIEW_SIZE/WEIGHT/LINE_HEIGHT`
  - `REPLY_SNIPPET_MAX_*_LINES`
  - `REPLY_SNIPPET_QUOTE_MAX_*_LINES`
- Colors:
  - `REPLY_SNIPPET_TITLE_INCOMING/OUTGOING`
  - `REPLY_SNIPPET_PREVIEW_INCOMING/OUTGOING`
  - `REPLY_SNIPPET_BAR_INCOMING/OUTGOING`

## Acceptance Checklist
- [ ] Left accent line is visually stable and does not detach on tall quote mode
- [ ] Author/preview ellipsis works for long strings
- [ ] Thumbnail does not shift text block unexpectedly
- [ ] Narrow and wide container behavior remains stable
- [ ] Tokens-only implementation (no magic visual constants)
- [ ] Missing original is hydrated in-place without duplicate request storms

## Demo Requirements (`TgReplySnippetDemo.ets`)
At least 10 cases:
1) incoming basic
2) outgoing basic
3) incoming with thumbnail
4) outgoing with thumbnail
5) long author
6) long preview
7) outgoing long preview
8) quote incoming
9) quote outgoing
10) quote + thumbnail
11) narrow container
12) wide container

## Known Risks
- Final color calibration for outgoing reply title/line may need tuning after bubble integration.
- Live chat integration now wires media-aware reply labels and thumbnails from `ChatTimelineVO` / `TgMessageRouter`, but edge cases still need device verification for partial downloads and media types without local previews.

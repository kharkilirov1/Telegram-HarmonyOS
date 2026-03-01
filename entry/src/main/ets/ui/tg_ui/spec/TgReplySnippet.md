# TgReplySnippet (Phase C / Step 3)

## Goal
Implement Telegram-like reply snippet block used above message text:
- left accent line
- author/title
- reply preview text
- optional media thumbnail

UI-only scope for this step. No tap actions, no media loading logic, no entity interactions.

## iOS References
- `submodules/TelegramUI/Components/Chat/ChatMessageReplyInfoNode/Sources/ChatMessageReplyInfoNode.swift`
  - primary visual tree for reply header
  - line + title + preview + optional image geometry
  - quote mode line/title/text max lines behavior
- `submodules/TelegramUI/Components/Chat/ChatMessageBubbleItemNode/Sources/ChatMessageBubbleItemNode.swift`
  - integration placement inside bubble content stack
- `submodules/TelegramUI/Components/Chat/ChatMessageTextBubbleContentNode/Sources/ChatMessageTextBubbleContentNode.swift`
  - trailing/meta coexistence constraints with message body

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
- Real media thumbnail loading/caching will be addressed at integration step.

# TgDocumentRow (Phase C.1 / Step 3)

## Goal
Implement Telegram-style document attachment row atom:
- stronger leading file/extension tile with separate secondary action chip
- file name + metadata (type/size)
- optional transfer progress states (ring in tile + linear bar below)

UI-only scope for this step. No real transfer state machine or tap actions.

## iOS References
- `submodules/TelegramUI/Components/Chat/ChatMessageFileBubbleContentNode/Sources/ChatMessageFileBubbleContentNode.swift`
  - file bubble integration and layout context
- `submodules/TelegramUI/Components/Chat/ChatMessageInteractiveFileNode/Sources/ChatMessageInteractiveFileNode.swift`
  - file title/description layout and download-state visuals
- `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Sources/ChatMessageItemCommon.swift`
  - file bubble inset baseline (`top:15, left:9, bottom:15, right:12`)

## Android Reference
- `TMessagesProj/src/main/java/org/telegram/ui/Cells/SharedDocumentCell.java`
  - confirms the stronger `40dp`-class leading tile / thumbnail identity block
  - separates file identity from the transfer/open affordance

## Props / Inputs
- `fileName: string`
- `fileSize: number` (bytes)
- `mimeType: string`
- `isOutgoing: boolean`
- `documentPath: string`
- `isDownloading: boolean`
- `downloadProgress: number` (`-1` hidden, `0..1` visible)
- `containerWidth: number`
- `maxWidthRatio: number`

## State Matrix (demo)
- incoming/outgoing
- different file types and sizes
- long filename truncation
- downloaded/open-ready vs missing/local-download state
- indeterminate downloading spinner
- progress hidden / active (mid + near complete)
- narrow container stress

## Layout Rules
1) Root alignment left/right by message direction.
2) Bubble width constrained by `containerWidth * maxWidthRatio` and tokenized min/max.
3) Leading tile has fixed box size and rounded background; idle states keep extension readability, determinate transfer uses an in-tile ring with percent, and indeterminate transfer uses a spinner face.
4) Secondary action chip stays visually separate from the identity tile so open/download remains easy to scan.
5) Text block contains title (up to 2 lines ellipsis) + meta line (1 line ellipsis).
6) Linear progress bar appears only when `downloadProgress` in `[0, 1)`.
7) All visual constants are tokenized.

## Token Mapping
- Colors:
  - `DOCUMENT_ROW_ICON_BG`, `DOCUMENT_ROW_ICON_TINT`
  - `DOCUMENT_ROW_ACTION_BG`, `DOCUMENT_ROW_ACTION_ICON`
- `DOCUMENT_ROW_TITLE_INCOMING/OUTGOING`
- `DOCUMENT_ROW_META_INCOMING/OUTGOING`
- `DOCUMENT_ROW_PROGRESS_BG/FILL`
- Geometry/Typography:
  - `DOCUMENT_ROW_RADIUS`
  - `DOCUMENT_ROW_MIN_WIDTH/MAX_WIDTH`
  - `DOCUMENT_ROW_PADDING_H/PADDING_V`
  - `DOCUMENT_ROW_ICON_BOX_SIZE/ICON_SIZE/ICON_RADIUS`
  - `DOCUMENT_ROW_PROGRESS_RING_STROKE`
  - `DOCUMENT_ROW_ACTION_SIZE/ACTION_ICON_SIZE/ACTION_OFFSET`
  - `DOCUMENT_ROW_CONTENT_GAP`, `DOCUMENT_ROW_TEXT_GAP`
  - `DOCUMENT_ROW_TITLE_SIZE/LINE_HEIGHT`
  - `DOCUMENT_ROW_META_SIZE/LINE_HEIGHT`
  - `DOCUMENT_ROW_EXTENSION_SIZE/LINE_HEIGHT`
  - `DOCUMENT_ROW_PROGRESS_HEIGHT/RADIUS/TOP_GAP`

## Acceptance Checklist
- [ ] File name truncation stays stable with long names
- [ ] Progress bar appears/disappears cleanly by state
- [ ] Idle state no longer reads as a flat generic icon row
- [ ] Leading tile/action hierarchy is visually stronger than the old flat extension row
- [ ] In-tile ring/spinner states read clearly during transfer
- [ ] Incoming/outgoing alignment matches bubble rhythm
- [ ] MIME/size text remains readable and consistent
- [ ] No hardcoded visual constants in atom

## Demo Requirements (`TgDocumentRowDemo.ets`)
At least 7 cases:
1) incoming regular file
2) outgoing regular file
3) long filename truncation
4) outgoing active progress
5) incoming near-complete progress
6) missing extension/mime fallback
7) narrow container stress

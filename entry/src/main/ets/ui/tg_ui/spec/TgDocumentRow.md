# TgDocumentRow (Phase C.1 / Step 3)

## Goal
Implement Telegram-style document attachment row atom:
- leading file/download icon slot
- file name + metadata (type/size)
- optional download progress bar

UI-only scope for this step. No real transfer state machine or tap actions.

## iOS References
- `submodules/TelegramUI/Components/Chat/ChatMessageFileBubbleContentNode/Sources/ChatMessageFileBubbleContentNode.swift`
  - file bubble integration and layout context
- `submodules/TelegramUI/Components/Chat/ChatMessageInteractiveFileNode/Sources/ChatMessageInteractiveFileNode.swift`
  - file title/description layout and download-state visuals
- `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Sources/ChatMessageItemCommon.swift`
  - file bubble inset baseline (`top:15, left:9, bottom:15, right:12`)

## Props / Inputs
- `fileName: string`
- `fileSize: number` (bytes)
- `mimeType: string`
- `isOutgoing: boolean`
- `downloadProgress: number` (`-1` hidden, `0..1` visible)
- `containerWidth: number`
- `maxWidthRatio: number`

## State Matrix (demo)
- incoming/outgoing
- different file types and sizes
- long filename truncation
- progress hidden / active (mid + near complete)
- narrow container stress

## Layout Rules
1) Root alignment left/right by message direction.
2) Bubble width constrained by `containerWidth * maxWidthRatio` and tokenized min/max.
3) Leading icon slot has fixed box size and rounded background.
4) Text block contains title (1 line ellipsis) + meta line (1 line ellipsis).
5) Progress bar appears only when `downloadProgress` in `[0, 1)`.
6) All visual constants are tokenized.

## Token Mapping
- Colors:
  - `DOCUMENT_ROW_ICON_BG`, `DOCUMENT_ROW_ICON_TINT`
  - `DOCUMENT_ROW_TITLE_INCOMING/OUTGOING`
  - `DOCUMENT_ROW_META_INCOMING/OUTGOING`
  - `DOCUMENT_ROW_PROGRESS_BG/FILL`
- Geometry/Typography:
  - `DOCUMENT_ROW_RADIUS`
  - `DOCUMENT_ROW_MIN_WIDTH/MAX_WIDTH`
  - `DOCUMENT_ROW_PADDING_H/PADDING_V`
  - `DOCUMENT_ROW_ICON_BOX_SIZE/ICON_SIZE/ICON_RADIUS`
  - `DOCUMENT_ROW_CONTENT_GAP`, `DOCUMENT_ROW_TEXT_GAP`
  - `DOCUMENT_ROW_TITLE_SIZE/LINE_HEIGHT`
  - `DOCUMENT_ROW_META_SIZE/LINE_HEIGHT`
  - `DOCUMENT_ROW_PROGRESS_HEIGHT/RADIUS/TOP_GAP`

## Acceptance Checklist
- [ ] File name truncation stays stable with long names
- [ ] Progress bar appears/disappears cleanly by state
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

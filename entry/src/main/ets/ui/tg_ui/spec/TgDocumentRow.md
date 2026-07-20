# TgDocumentRow (Phase C.1 / Step 3)

## Goal
Implement Telegram-style document attachment row atom:
- stronger leading file/extension tile with separate secondary action chip
- file name + metadata (type/size)
- explicit transfer status states (download/open chip, ring/spinner + close icon, linear bar below)

UI atom scope for this step. Runtime download/cancel/open ownership stays in `TgMessageRouter` / chat parent callbacks.

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
- remote idle download chip
- indeterminate downloading spinner + close icon
- determinate downloading ring + close icon (mid + near complete)
- narrow container stress

## Transfer State Machine
- `documentPath.length === 0`, `isDownloading=false`, `downloadProgress < 0` -> extension/file tile plus secondary download chip.
- `isDownloading=true`, `downloadProgress < 0` -> dimmed tile with `LoadingProgress` and project-owned `ICON_RES_CLOSE`.
- `isDownloading=true` or `downloadProgress in [0, 1)` -> dimmed tile with `Progress({ type: ProgressType.Ring })`, project-owned `ICON_RES_CLOSE`, percent meta, and linear progress bar.
- `documentPath.length > 0`, transfer inactive -> open-ready/document identity state; parent decides whether tap opens local content.
- Atom delegates taps through `onDownloadToggle`; router maps active transfers to cancel and remote idle to download.

## Layout Rules
1) Root alignment left/right by message direction.
2) Bubble width constrained by `containerWidth * maxWidthRatio` and tokenized min/max.
3) Leading tile has fixed box size and rounded background; idle states keep extension readability, determinate transfer uses an in-tile ring with percent/linear progress, and indeterminate transfer uses a spinner face.
4) Secondary action chip stays visually separate from the identity tile so open/download remains easy to scan.
5) Text block contains title (up to 2 lines ellipsis) + meta line (1 line ellipsis).
6) Linear progress bar appears only when `downloadProgress` in `[0, 1)`.
7) All visual constants are tokenized.

## Token Mapping
- Colors:
  - `DOCUMENT_ROW_ICON_BG`, `DOCUMENT_ROW_ICON_TINT`
  - `DOCUMENT_ROW_ACTION_BG`, `DOCUMENT_ROW_ACTION_ICON`
- `DOCUMENT_ROW_TITLE_INCOMING/OUTGOING`
- `DOCUMENT_ROW_META_INCOMING/OUTGOING`; outgoing metadata is bubble-aware
  secondary text and intentionally does not reuse global `text_secondary`
- `DOCUMENT_ROW_META_INCOMING/OUTGOING`
- `DOCUMENT_ROW_PROGRESS_BG/FILL`
- `MEDIA_OVERLAY_DARK`, `MEDIA_PROGRESS_COLOR`
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
  - `MEDIA_CANCEL_ICON_SIZE`
  - `MEDIA_STATUS_TRANSITION_SCALE`, `MEDIA_STATUS_ANIM_DURATION`
- Icons:
  - `ICON_RES_DOCUMENT`, `ICON_RES_DOWNLOAD`, `ICON_RES_CLOSE`

## Acceptance Checklist
- [ ] File name truncation stays stable with long names
- [ ] Progress bar appears/disappears cleanly by state
- [ ] Fetching tile uses project-owned `ICON_RES_CLOSE`, not `sys.media.ohos_ic_public_cancel`
- [ ] Idle state no longer reads as a flat generic icon row
- [ ] Leading tile/action hierarchy is visually stronger than the old flat extension row
- [ ] In-tile ring/spinner states read clearly during transfer
- [ ] Incoming/outgoing alignment matches bubble rhythm
- [ ] MIME/size text remains readable and consistent
- [ ] No hardcoded visual constants in atom

## Demo Requirements (`TgDocumentRowDemo.ets`)
At least 8 cases:
1) incoming regular file
2) outgoing downloaded/open-ready file
3) long filename truncation
4) outgoing active progress
5) incoming indeterminate transfer
6) incoming near-complete progress
7) missing extension/mime fallback
8) narrow container stress while downloading

## Current Behavior Boundary
- The atom renders remote/fetching/local document status only.
- `TgMessageRouter` currently owns actual download/cancel/open decisions through `onDownloadToggle` and `onTap`.
- Static demo coverage is review coverage, not manual device/emulator visual acceptance.

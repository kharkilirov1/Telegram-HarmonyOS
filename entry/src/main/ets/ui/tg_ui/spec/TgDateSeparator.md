# TgDateSeparator + TgUnreadMarker (Phase C / Step 4)

## Goal
Implement chat timeline separators:
- **Date separator** (centered capsule with date text)
- **Unread marker** (centered unread bar)

UI-only scope for this step. No scroll-sticky behavior or read-state logic wiring.

## iOS References
- `submodules/TelegramUI/Components/Chat/ChatMessageItemImpl/Sources/ChatMessageDateHeader.swift`
  - date header capsule appearance and placement contracts
- `submodules/TelegramUI/Components/Chat/ChatMessageItemImpl/Sources/ChatUnreadItem.swift`
  - unread bar row height, centered label, and list spacing behavior
- `submodules/TelegramUI/Components/Chat/ChatMessageItemImpl/Sources/ChatMessageItemImpl.swift`
  - integration points where unread/date entries are inserted in timeline

## Atoms
1) `TgDateSeparator`
2) `TgUnreadMarker`

## Props / Inputs
### `TgDateSeparator`
- `text: string`
- `containerWidth: number`
- `maxWidthRatio: number`

### `TgUnreadMarker`
- `text: string`
- `containerWidth: number`
- `maxWidthRatio: number`

## State Matrix (demo)
- date: short labels (`Today`, `Yesterday`)
- date: long localized label
- date: narrow/wide container
- unread: default and long text
- unread: narrow/wide container
- sequence probe (`date → unread → date`)

## Layout Rules
1) Date separator:
   - centered capsule,
   - max width constrained by ratio of container width,
   - one-line ellipsis for long labels.
2) Unread marker:
   - centered bar with fixed height and centered label,
   - max width constrained by ratio of container width,
   - one-line ellipsis for long labels.
3) All colors/sizes/weights are tokenized.

## Token Mapping
- Date separator:
  - `DATE_SEPARATOR_BG`, `DATE_SEPARATOR_TEXT`
  - `DATE_SEPARATOR_FONT_SIZE/WEIGHT/LINE_HEIGHT`
  - `DATE_SEPARATOR_PADDING_H/V`
  - `DATE_SEPARATOR_RADIUS`
  - `DATE_SEPARATOR_MIN_HEIGHT`
  - `DATE_SEPARATOR_SIDE_INSET`
  - `DATE_SEPARATOR_MAX_WIDTH_RATIO`
- Unread marker:
  - `UNREAD_MARKER_BG`, `UNREAD_MARKER_TEXT`
  - `UNREAD_MARKER_FONT_SIZE/WEIGHT/LINE_HEIGHT`
  - `UNREAD_MARKER_HEIGHT`
  - `UNREAD_MARKER_RADIUS`
  - `UNREAD_MARKER_SIDE_INSET`
  - `UNREAD_MARKER_MAX_WIDTH_RATIO`

## Acceptance Checklist
- [ ] Date capsule remains centered and visually stable across label lengths
- [ ] Unread bar height remains stable and text is centered
- [ ] Long text is ellipsized without overflow
- [ ] Narrow/wide container behavior is stable
- [ ] Tokens-only implementation

## Demo Requirements (`TgDateSeparatorDemo.ets`)
At least 10 cases including:
1) date today
2) date yesterday
3) date short explicit
4) date long explicit
5) date narrow
6) date wide
7) unread default
8) unread long
9) unread narrow
10) unread wide
11) sequence probe

## Known Risks
- Final unread bar color/alpha may need calibration after chat screen integration.
- Sticky date-header behavior belongs to integration stage, not atom stage.

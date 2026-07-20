# TgDateSeparator + TgUnreadMarker (Phase C / Step 4)

## Goal
Implement chat timeline separators:
- **Date separator** (centered capsule with date text)
- **Unread marker** (centered unread bar)

The atoms stay UI-only; chat integration owns insertion and keeps the entry-time unread boundary stable while TDLib updates live read fields.

## iOS References
- `submodules/TelegramUI/Components/Chat/ChatMessageItemImpl/Sources/ChatMessageDateHeader.swift`
  - `ChatMessageDateContentNode`: `13pt` medium label, `22pt` capsule, `6pt` horizontal inset, capsule radius = half-height
  - current-year labels use localized month + day; only today gets the dedicated `Today` label; another year adds the year
- `submodules/TelegramUI/Components/Chat/ChatMessageItemImpl/Sources/ChatUnreadItem.swift`
  - `13pt` regular label, full-width `25pt` bar, centered label, `6pt` top and `5pt` bottom list insets
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
- `maxLines: number`
- `isService: boolean` (keeps multi-line service-event geometry independent from the compact date pill)

### `TgUnreadMarker`
- `text: string`
- `containerWidth: number`
- `maxWidthRatio: number`

## State Matrix (demo)
- date: short label (`Today`) and explicit localized month/day labels
- date: recent non-today labels use localized month/day, not weekday abbreviations
- date: cross-year labels include the year
- date: long localized label
- date: narrow/wide container
- unread: default and long text
- unread: narrow/wide container
- sequence probe (`date → unread → date`)

## Layout Rules
1) Date separator:
   - centered capsule,
   - `22vp` capsule height inside the page-owned `34vp` date-header lane (`8vp` top + `4vp` bottom), matching iOS `ChatMessageDateContentNode`,
   - `6vp` horizontal inset and `11vp` pill radius,
   - label semantics mirror iOS: `Today`; otherwise locale-aware month/day, with year only across calendar years,
   - max width constrained by ratio of container width,
   - one-line ellipsis for long labels.
2) Service-event variant:
   - explicitly selected with `isService`,
   - preserves the roomier `34vp` minimum and `4vp` vertical padding for multi-line event text.
3) Unread marker:
   - flat edge-to-edge bar with fixed `25vp` height and no corner radius,
   - `13fp` regular one-line label centered in both axes,
   - page-owned `6vp` top and `5vp` bottom spacing,
   - an entry-time sticky boundary remains authoritative after `markChatRead`; TDLib boundary `"0"` means the first incoming message, not an absent snapshot,
   - one-line ellipsis for long labels.
4) All colors/sizes/weights are tokenized.

## Token Mapping
- Date separator:
  - `DATE_SEPARATOR_BG`, `DATE_SEPARATOR_TEXT`
  - `DATE_SEPARATOR_FONT_SIZE/WEIGHT/LINE_HEIGHT`
  - `DATE_SEPARATOR_PADDING_H/V`
  - `DATE_SEPARATOR_RADIUS`
  - `DATE_SEPARATOR_MIN_HEIGHT`
  - `DATE_SEPARATOR_SIDE_INSET`
  - `DATE_SEPARATOR_MAX_WIDTH_RATIO`
  - `SERVICE_SEPARATOR_PADDING_V/RADIUS/MIN_HEIGHT`
- Unread marker:
  - `UNREAD_MARKER_BG`, `UNREAD_MARKER_TEXT`
  - `UNREAD_MARKER_FONT_SIZE/WEIGHT/LINE_HEIGHT`
  - `UNREAD_MARKER_HEIGHT`
  - `UNREAD_MARKER_RADIUS`
  - `UNREAD_MARKER_SIDE_INSET`
  - `UNREAD_MARKER_MAX_WIDTH_RATIO`
  - `UNREAD_MARKER_MARGIN_TOP/BOTTOM`

## Acceptance Checklist
- [x] Date capsule remains centered and visually stable across label lengths
- [x] Unread bar height remains stable and text is centered in a live unread chat
- [x] Long text is ellipsized without overflow
- [x] Narrow/wide container behavior is stable
- [x] Tokens-only implementation

## Demo Requirements (`TgDateSeparatorDemo.ets`)
At least 12 cases including:
1) date today
2) date localized month/day
3) date short explicit
4) date long explicit
5) date narrow
6) date wide
7) multi-line service-event variant
8) unread default
9) unread long
10) unread narrow
11) unread wide
12) sequence probe

## Known Risks
- Final unread bar color/alpha may need calibration after chat screen integration.
- Sticky date-header behavior belongs to integration stage, not atom stage.

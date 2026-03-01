# TgCountryRow Component Passport

## 1) Scope
- Atom: `TgCountryRow`
- Target layer: `atoms`
- Status: `in-progress`

## 2) iOS source mapping
- `submodules/CountrySelectionUI/Sources/AuthorizationSequenceCountrySelectionControllerNode.swift`
  - `tableView(_:cellForRowAt:)` country text/value composition
  - row selection behavior in `didSelectRowAt`

## 3) Props / inputs
- `flagEmoji: string`
- `countryName: string`
- `dialCode: string`
- `showSeparator: boolean`
- callback: `onPress`

## 4) State matrix
- default row
- last row (separator hidden)
- long country name (ellipsis)

## 5) Layout rules
- three-part row: flag, name (flex), dial code.
- fixed row height.
- separator inset starts after flag column.

## 6) Token mapping
- `COUNTRY_ROW_HEIGHT`
- `COUNTRY_ROW_SIDE_INSET`
- `COUNTRY_ROW_FLAG_SIZE`
- `COUNTRY_ROW_FLAG_NAME_GAP`
- `COUNTRY_ROW_DIAL_CODE_END_INSET`
- `COUNTRY_ROW_NAME_SIZE`
- `COUNTRY_ROW_DIAL_CODE_SIZE`
- `COUNTRY_ROW_SEPARATOR_STROKE`
- `COUNTRY_ROW_SEPARATOR_INSET`
- `COLOR_BG_PRIMARY`
- `COLOR_TEXT_TITLE`
- `COLOR_TEXT_PREVIEW`
- `COLOR_SEPARATOR`

## 7) Acceptance checklist
- [x] row press callback is isolated in atom
- [x] separator toggles correctly for last row
- [x] text overflow remains stable


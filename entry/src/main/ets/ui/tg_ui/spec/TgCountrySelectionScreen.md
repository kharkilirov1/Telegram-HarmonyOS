# TgCountrySelectionScreen Component Passport

## 1) Scope
- Molecule: `TgCountrySelectionScreen`
- Target layer: `molecules`
- Status: `in-progress`

## 2) iOS source mapping
- `submodules/CountrySelectionUI/Sources/AuthorizationSequenceCountrySelectionController.swift`
- `submodules/CountrySelectionUI/Sources/AuthorizationSequenceCountrySelectionControllerNode.swift`

## 3) Props / inputs
- `isLoaded: boolean`
- `topInset: number`
- `bottomInset: number`
- `searchText: string`
- `searchPlaceholder: string`
- `groupedCountries: TgCountryGroup[]`
- `alphabet: string[]`
- callbacks:
  - `onBackPress`
  - `onSearchChange`
  - `onCountryPress`

## 4) State matrix
- loading state
- grouped list state
- alphabet index visible/hidden
- active search query

## 5) Layout rules
- full-screen stack: list layer + top glass overlay + bottom search overlay.
- list has spacer items for overlay regions to avoid clipping.
- index rail anchored above bottom search overlay.

## 6) Token mapping
- `COUNTRY_TOP_OVERLAY_BAR_HEIGHT`
- `COUNTRY_SEARCH_OVERLAY_HEIGHT`
- `SPACE_16`
- `COLOR_BG_PRIMARY`
- `COLOR_ICON_PRIMARY`
- `COLOR_TEXT_TITLE`
- `COLOR_OVERLAY_DIM`

## 7) Acceptance checklist
- [x] page-level country UI composed through tg_ui atoms only
- [x] no inline back/search/header/row render code in page
- [x] molecule remains stateless w.r.t. business logic (inputs/callbacks only)


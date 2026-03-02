# TgCountrySelectionScreen Component Passport

## 1) Scope
- Molecule: `TgCountrySelectionScreen`
- Target layer: `molecules`
- Status: `done`

## 2) iOS source mapping
- `submodules/CountrySelectionUI/Sources/AuthorizationSequenceCountrySelectionController.swift`
- `submodules/CountrySelectionUI/Sources/AuthorizationSequenceCountrySelectionControllerNode.swift`

## 3) Presentation
- Displayed inside `bindSheet(SheetSize.LARGE)` from `PhoneInputPage`
- Sheet provides built-in title (`select_country` resource) and close button (`showClose: true`)
- No separate page or NavDestination required

## 4) Props / inputs
- `isLoaded: boolean`
- `searchText: string`
- `searchPlaceholder: string`
- `groupedCountries: TgCountryGroup[]`
- `alphabet: string[]`
- callbacks:
  - `onSearchChange: (value: string) => void`
  - `onCountryPress: (country: CountryInfo) => void`

## 5) State matrix
- loading state (spinner)
- grouped list state
- alphabet index visible/hidden
- active search query

## 6) Layout rules
```
Column (100% x 100%)
  Search (search bar, always visible at top)
  if isLoaded:
    Stack (layoutWeight 1)
      List (sticky headers, full size)
        ForEach(groups) -> ListItemGroup
          Header: TgCountrySectionHeader
          ForEach(countries) -> TgCountryRow
      AlphabetIndexer (right-aligned)
  else:
    LoadingProgress (centered, layoutWeight 1)
```

## 7) Token mapping
- `COUNTRY_SHEET_SEARCH_HEIGHT`
- `COUNTRY_SHEET_SEARCH_SIDE_INSET`
- `SEARCH_BAR_BG`
- `SPACE_8`
- `COLOR_BG_PRIMARY`
- `COLOR_ICON_PRIMARY`
- `COLOR_TEXT_TITLE`
- `COLOR_OVERLAY_DIM`

## 8) Acceptance checklist
- [x] country UI composed through tg_ui atoms only
- [x] no inline back/search/header/row render code in page
- [x] molecule remains stateless w.r.t. business logic (inputs/callbacks only)
- [x] search bar at top (inside sheet, below built-in title)
- [x] no overlays (sheet provides title + close)
- [x] alphabet indexer works without bottom margin offset

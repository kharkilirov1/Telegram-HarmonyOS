# TgCountryBottomSearchOverlay Component Passport

## 1) Scope
- Atom: `TgCountryBottomSearchOverlay`
- Target layer: `atoms`
- Status: `in-progress`

## 2) iOS source mapping
- `submodules/CountrySelectionUI/Sources/AuthorizationSequenceCountrySelectionControllerNode.swift`
  - `SearchInputPanelComponent` in glass mode anchored to bottom

## 3) Props / inputs
- `query: string`
- `bottomInset: number`
- `placeholder: string`
- callback: `onQueryChange`

## 4) State matrix
- empty query
- active query
- bottom inset present (gesture area)
- bottom inset absent fallback

## 5) Layout rules
- search capsule at top of overlay block.
- edge blur strip below capsule sized by bottom inset.
- full-width overlay block; page decides stacking/hit test.

## 6) Token mapping
- `COUNTRY_SEARCH_CAPSULE_HEIGHT`
- `COUNTRY_SEARCH_SIDE_INSET`
- `COUNTRY_SEARCH_VERTICAL_INSET`
- `COUNTRY_SEARCH_EDGE_BLUR_RADIUS`
- `SPACE_8`

## 7) Acceptance checklist
- [x] controlled input via props + callback
- [x] no hardcoded geometry inside atom
- [x] keeps bottom edge blur for home-indicator zone


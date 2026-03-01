# TgCountryTopOverlay Component Passport

## 1) Scope
- Atom: `TgCountryTopOverlay`
- Target layer: `atoms`
- Status: `in-progress`

## 2) iOS source mapping
- `submodules/CountrySelectionUI/Sources/AuthorizationSequenceCountrySelectionController.swift`
  - glass navigation mode + close/back action (`GlassBarButtonComponent`)
- `submodules/CountrySelectionUI/Sources/AuthorizationSequenceCountrySelectionControllerNode.swift`
  - top edge effect behavior for glass mode

## 3) Props / inputs
- `topInset: number`
- callback: `onBackPress`

## 4) State matrix
- normal notch inset
- zero inset fallback

## 5) Layout rules
- safe-area spacer row first.
- fixed content bar height below inset.
- circular back control anchored to start.
- translucent blur background.

## 6) Token mapping
- `COUNTRY_TOP_OVERLAY_BAR_HEIGHT`
- `COUNTRY_TOP_OVERLAY_BACK_SIZE`
- `COUNTRY_TOP_OVERLAY_BACK_ICON_SIZE`
- `COUNTRY_TOP_OVERLAY_SIDE_INSET`
- `COUNTRY_TOP_OVERLAY_BACK_BG`
- `ICON_RES_BACK`
- `COLOR_ICON_PRIMARY`

## 7) Acceptance checklist
- [x] single back control in overlay
- [x] top inset passed from page, not hardcoded
- [x] blur style remains page-independent


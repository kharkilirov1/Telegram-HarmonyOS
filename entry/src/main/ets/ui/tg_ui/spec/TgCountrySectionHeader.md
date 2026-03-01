# TgCountrySectionHeader Component Passport

## 1) Scope
- Atom: `TgCountrySectionHeader`
- Target layer: `atoms`
- Status: `in-progress`

## 2) iOS source mapping
- `submodules/CountrySelectionUI/Sources/AuthorizationSequenceCountrySelectionControllerNode.swift`
  - section headers (`titleForHeaderInSection`, header colors in `willDisplayHeaderView`)

## 3) Props / inputs
- `title: string`

## 4) State matrix
- single-letter header (`A`, `B`, `C`)
- multi-char fallback header

## 5) Layout rules
- fixed compact header height.
- left aligned text with stable inset.
- secondary text tone over secondary background.

## 6) Token mapping
- `COUNTRY_SECTION_HEADER_HEIGHT`
- `COUNTRY_SECTION_HEADER_TEXT_SIZE`
- `COUNTRY_SECTION_HEADER_SIDE_INSET`
- `COUNTRY_SECTION_HEADER_BG`
- `COUNTRY_SECTION_HEADER_TEXT_COLOR`

## 7) Acceptance checklist
- [x] no magic numbers inside atom
- [x] stable header height and inset
- [x] reusable in grouped `ListItemGroup`


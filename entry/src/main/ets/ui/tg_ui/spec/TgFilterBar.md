# TgFilterBar Component Passport

- Status: `archived` — standalone atom/demo removed from the active API23 shell branch; chat-list filtering should be reintroduced only as a deliberate product slice.
## 1) Scope
- Atom: `TgFilterBar`
- Target layer: `atoms`
- Status: `done`

## 2) iOS source mapping
- `ChatListFilterTabContainerNode.swift`
- Single glass island container with internal sliding highlight

## 3) Presentation
- Horizontal glass-capsule bar for chat list filtering
- Placed above chat list (overlay pattern, like TgTopBar/TgTabBar)
- Scrollable when items exceed visible width

## 4) Props / inputs
- `items: TgFilterBarItem[]` — filter entries (id, title, badgeCount)
- `selectedId: string` — currently selected filter id
- `glassMode: string` — glass rendering mode (auto/high/fallback)
- `onFilterSelect: (id: string) => void` — selection callback

## 5) State matrix
| State | Visual |
|-------|--------|
| Default | Glass island, all tabs visible, highlight on selected |
| Tab click | Highlight animates to new tab (250ms EaseInOut) |
| Badge active | Blue circle on selected tab |
| Badge inactive | Gray circle on unselected tab |
| Scroll | Horizontal scroll with spring edge effect |
| Glass mode | Blur + specular overlay |
| Fallback mode | Solid background_secondary, no blur |

## 6) Layout rules
```
Column (centering)
  Stack (glass island, constrained maxWidth 560)
    Layer 0: highlight Row
      .position({ x: highlightX, y: centered })
      .borderRadius(18)
      .backgroundColor(filter_highlight_bg)
    Layer 1: Scroll (horizontal)
      Row (padding: inner 14)
        ForEach(items) -> Row(space: 4)
          Text(title) — 14fp medium
          Badge — circle 18, badge count (if > 0)
```

## 7) Token mapping
- `FILTER_BAR_HEIGHT` (44)
- `FILTER_BAR_RADIUS` (22)
- `FILTER_BAR_SIDE_INSET` (16)
- `FILTER_BAR_INNER_PADDING` (14)
- `FILTER_BAR_MAX_WIDTH` (560)
- `FILTER_BAR_BG`, `FILTER_BAR_FALLBACK_BG`
- `FILTER_BAR_BORDER_WIDTH` (0.5), `FILTER_BAR_BORDER_COLOR`
- `FILTER_BAR_SHADOW_COLOR`, `FILTER_BAR_SHADOW_RADIUS` (20), `FILTER_BAR_SHADOW_OFFSET_Y` (8)
- `FILTER_BAR_TAB_FONT_SIZE` (14), `FILTER_BAR_TAB_TEXT_COLOR`
- `FILTER_BAR_TAB_MIN_SPACING` (26), `FILTER_BAR_TAB_VERTICAL_INSET` (4)
- `FILTER_BAR_HIGHLIGHT_HEIGHT` (36), `FILTER_BAR_HIGHLIGHT_PADDING_H` (10)
- `FILTER_BAR_HIGHLIGHT_RADIUS` (18), `FILTER_BAR_HIGHLIGHT_BG`
- `FILTER_BAR_HIGHLIGHT_ANIM_DURATION` (250)
- `FILTER_BAR_BADGE_SIZE` (18), `FILTER_BAR_BADGE_FONT_SIZE` (14)
- `FILTER_BAR_BADGE_PADDING_H` (4), `FILTER_BAR_BADGE_TEXT_OFFSET` (4)
- `FILTER_BAR_BADGE_ACTIVE_BG`, `FILTER_BAR_BADGE_INACTIVE_BG`, `FILTER_BAR_BADGE_TEXT_COLOR`
- `GLASS_SPECULAR_TOP`, `GLASS_SPECULAR_MID`, `GLASS_SPECULAR_BOTTOM`

## 8) Demo matrix
| Case | Description |
|------|-------------|
| Typical | 6 filters (All=23, Unread=5, Personal, Groups=1, Channels=12, Bots) |
| Minimal | 2 filters without badges |
| Scroll | 12 filters for horizontal scroll testing |
| Glass | Background image to demonstrate blur effect |

## 9) Acceptance checklist
- [x] Glass island styling matches TgTabBar pattern
- [x] Highlight slides smoothly between tabs (animateTo 250ms)
- [x] Auto-center selected tab on scroll
- [x] Badge color: blue (active) / gray (inactive)
- [x] Specular overlay for glass mode
- [x] Fallback mode without blur
- [x] Horizontal scroll with spring bounce
- [x] All 27 FILTER_BAR_* tokens consumed
- [x] No magic numbers in component
- [x] @ComponentV2 + @Param + @Local pattern

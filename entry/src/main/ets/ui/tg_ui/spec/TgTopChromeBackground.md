# TgTopChromeBackground Component Passport

## 1) Scope
- Atom: `TgTopChromeBackground`
- Target layer: `atoms`
- Status: `done`

## 2) Reference grounding
- `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\ChatListHeaderComponent\Sources\ChatListNavigationBar.swift`
  - shared upper blur/effect ownership
  - top edge emphasis via `EdgeEffectView`
- `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\ChatListHeaderComponent\Sources\ChatListHeaderComponent.swift`
  - content rendered above a separate upper background/effect surface
- `docs/ai/UPPER_CHROME_V2_ARCHITECTURE.md`
  - repo-local target assembly contract

## 3) Purpose
Repo-local V2 primitive for the **shared upper chrome background**.

This component is intentionally presentation-only:
- safe-area fill
- blur/tint surface
- top-edge emphasis
- optional bottom separator

It does **not** own title/actions/search/content.

## 4) Props / inputs
- `topInset: number`
- `contentHeight: number`
- `glassMode: string`
- `showBottomSeparator: boolean`
- `showTopEdgeEmphasis: boolean`

## 5) State matrix
- realtime blur on
- fallback/no-blur mode
- with/without bottom separator
- with/without top-edge emphasis
- short/normal/tall upper chrome heights

## 6) Layout rules
- total rendered height is `topInset + contentHeight`
- safe-area fill is part of this background, not a separate ad-hoc spacer painted elsewhere
- blur/tint is applied across the whole top chrome surface
- top-edge emphasis is a shallow overlay near the upper edge, not a full second bar
- content components are expected to be stacked **above** this primitive

## 7) Token mapping
- `TOP_BAR_GLASS_BG`
- `TOP_BAR_GLASS_FALLBACK_BG`
- `TOP_BAR_SEPARATOR`
- `TOP_BAR_SEPARATOR_STROKE`
- `TOP_CHROME_EDGE_HEIGHT`
- `TOP_CHROME_EDGE_TOP`
- `TOP_CHROME_EDGE_BOTTOM`
- `GLASS_SPECULAR_*`

## 8) Acceptance checklist
- [x] reusable across upper chrome surfaces
- [x] presentation-only ownership (no title/search/action logic inside)
- [x] supports safe-area fill + shared blur surface
- [x] supports stronger top-edge emphasis
- [x] works with ComponentV2 param-driven composition

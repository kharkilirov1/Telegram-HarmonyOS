# TgIcon Component Passport

## 1) Scope
- Atom: `TgIcon`
- Target layer: `atoms`
- Status: `in-progress`

## 2) iOS source mapping
- `submodules/TelegramPresentationData/Sources/Resources/PresentationResourcesChatList.swift`
  - resource colorization patterns (`generateTintedImage`, status/check/mute icons)
- `submodules/ChatListUI/Sources/Node/ChatListItem.swift`
  - icon placement in visual tree (muted, pin, status checks, date/status cluster)

## 3) Props / inputs
- `src: Resource` — icon resource (prefer SVG)
- `iconSize: number` — icon square size (tokenized)
- `tintColor: ResourceColor` — desired tint
- `isEnabled: boolean` — disabled state opacity behavior
- `iconOpacity: number` — explicit visibility tuning
- `supportSvg2: boolean` — toggles SVG tint path strategy

## 4) States
- default (secondary tint)
- active/accent
- muted
- disabled
- supportSvg2 enabled/disabled

## 5) Layout rules
- Fixed square icon box (`iconSize x iconSize`)
- `objectFit: Contain`
- no implicit margins/padding inside atom
- tint via `fillColor` when `supportSvg2 = true`
- note: tint requires SVG drawable elements with `fill != none`

## 6) Token mapping
- sizes/colors/opacities from:
  - `entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets`

## 7) Acceptance checklist
- [x] All visual constants sourced from tokens
- [x] Supports SVG tint path via fillColor
- [x] Demo covers multiple icon states/sizes
- [ ] Integrated into next atoms (`TgChatMeta`, `TgChatRow`)

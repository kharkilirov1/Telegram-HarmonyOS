# TgAvatar Component Passport

## 1) Scope
- Atom: `TgAvatar`
- Target layer: `atoms`
- Status: `in-progress`

## 2) iOS source mapping
- `submodules/ChatListUI/Sources/Node/ChatListItem.swift`
  - avatar sizing + insets:
    - `avatarDiameter = min(60.0, floor(baseDisplaySize * 60.0 / 17.0))` (lines ~1921, ~2432)
    - compact mode uses `avatarDiameter = 40.0` (lines ~1924, ~2436)
  - avatar frame:
    - `avatarFrame` computed from row height center (line ~3951)
  - online marker overlay:
    - `onlineFrame` anchored to avatar bottom-right (lines ~4112–4118)
    - regular offset: `-2.0` / voice-chat variant with `+1.0 - UIScreenPixel`
- `submodules/TelegramPresentationData/Sources/Resources/PresentationResourcesChatList.swift`
  - online badge visual style:
    - `recentStatusOnlineIcon` uses circular base + inner online dot (size 14 regular, 22 voice-chat)

## 3) Props / inputs
- `avatarSize: number` — avatar diameter (`40/54/60` token sizes)
- `initials: string` — placeholder initials (trim to 1–2 chars)
- `useImage: boolean` — photo vs placeholder mode
- `imageSrc: Resource | string` — avatar image source (resource or local path)
- `isOnline: boolean` — show/hide online dot overlay
- `avatarBackgroundColor: ResourceColor` — placeholder background
- `textColor: ResourceColor` — initials color
- `onlineDotColor: ResourceColor` — online dot fill
- `onlineDotBorderColor: ResourceColor` — ring color around online dot

## 4) States
- Placeholder avatar, offline
- Placeholder avatar, online
- Image avatar, offline
- Image avatar, online
- Size variants (`40`, `54`, `60`)
- Long initials normalization case (`"Alexander"` -> `"AL"`)
- Initials centering checks (`"A"`, `"MW"`, `"Ж"`, `"И"`, `"12"`)

## 5) Layout rules
- Avatar is always clipped round (`radius = max`).
- Online dot is fixed to bottom-right and does not shift avatar geometry.
- Dot uses border ring to keep separation from variable row backgrounds.
- Dot placement formula:
  - `x = size - dotSize - dotOffset`
  - `y = size - dotSize - dotOffset`
  - current default offset matches iOS regular marker behavior via tokenized `AVATAR_ONLINE_DOT_OFFSET_X/Y`.
- Ring color defaults to row background token (`COLOR_BG_PRIMARY`) to avoid visible hard-edge halos.
- No internal margins in atom; container controls external spacing.

## 6) Token mapping
- Source: `entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets`
  - avatar sizes (`AVATAR_SIZE_SM/MD/DEFAULT`)
  - online dot metrics (`AVATAR_ONLINE_DOT_*`)
  - placeholder colors (`COLOR_AVATAR_PLACEHOLDER_*`)
  - initials typography (`FONT_AVATAR_INITIALS_SIZE_SM/MD/LG`)

## 7) Acceptance checklist
- [x] Stable geometry (online on/off does not resize avatar)
- [x] All visual constants tokenized
- [x] Demo covers 6+ states including size variants
- [x] Dot ring uses tokenized row background color (not hardcoded black)
- [x] Initials centering matrix added (`A/MW/Ж/И/12`)
- [x] No clipping regressions observed for dot overlay in demo cases
- [ ] Final offset polish after side-by-side iOS screenshot comparison

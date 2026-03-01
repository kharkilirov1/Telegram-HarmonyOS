# TgUnreadBadge Component Passport

## 1) Scope
- Atom: `TgUnreadBadge`
- Target layer: `atoms`
- Status: `in-progress`

## 2) iOS source mapping
- `submodules/ChatListUI/Sources/Node/ChatListBadgeNode.swift`
  - `class ChatListBadgeNode` (line ~36): dedicated unread/mention badge node.
  - `asyncLayout` (line ~66): width logic is not fixed circle; width expands by text while keeping minimum `imageWidth`.
  - text centering: text frame is horizontally centered inside background frame (`backgroundFrame.midX`) and vertically centered with screen-pixel alignment.
- `submodules/ChatListUI/Sources/Node/ChatListItem.swift`
  - `badgeFont` uses monospaced numbers (line ~2177).
  - `badgeDiameter` derived from base display size (line ~2448).
  - unread text created via `compactNumericCountString(...)` (line ~3246).
  - right-cluster placement uses trailing X budget so badge/pin layout stays stable (lines ~4308–4331).
- `submodules/TelegramPresentationData/Sources/Resources/PresentationResourcesChatList.swift`
  - `generateBadgeBackgroundImage(...)` (line ~23): circular source image turned stretchable for capsule behavior.

## 3) Props / inputs
- `count: number` — unread count source.
- `isMuted: boolean` — muted visual variant.
- `isDisabled: boolean` — demo/interaction-disabled visual variant (opacity).
- `height: number` — fixed badge height (token).
- `minWidth: number` — minimum width floor (token).
- `horizontalPadding: number` — left/right text padding (token).
- `activeBackgroundColor: ResourceColor` — active badge color.
- `mutedBackgroundColor: ResourceColor` — muted badge color.
- `textColor: ResourceColor` — badge text color.

## 4) State matrix
- Hidden: `count <= 0`
- Active unread: `count = 1..99`
- Overflow unread: `count >= 100` -> text `"99+"` (P0 contract)
- Muted unread style (`isMuted = true`)
- Disabled opacity style (`isDisabled = true`)

## 5) Layout rules
- Height is fixed (`UNREAD_BADGE_HEIGHT` token).
- Width is adaptive with floor:
  - `minWidth = UNREAD_BADGE_MIN_WIDTH`
  - plus horizontal text padding (`UNREAD_BADGE_H_PADDING`).
- Capsule shape is computed as `radius = height / 2` (no hardcoded radius in atom).
- Text is single-line and centered; no multiline growth.
- Component is self-contained: no external margin is applied inside atom.

## 6) Token mapping
- Source: `entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets`
  - `COLOR_UNREAD_BG`, `COLOR_UNREAD_BG_MUTED`, `COLOR_UNREAD_TEXT`
  - `FONT_BADGE_SIZE`
  - `UNREAD_BADGE_HEIGHT`, `UNREAD_BADGE_MIN_WIDTH`, `UNREAD_BADGE_H_PADDING`
  - `UNREAD_BADGE_MAX_VISIBLE_COUNT`
  - `UNREAD_BADGE_DISABLED_OPACITY`

## 7) Acceptance checklist
- [x] `count <= 0` hides badge
- [x] `1..99` renders exact number
- [x] `>=100` renders `99+`
- [x] Fixed height + min width + horizontal padding (capsule geometry)
- [x] Text visually centered in badge container
- [x] All visual values sourced from tokens (no hardcoded color/size/font in atom)
- [ ] Final side-by-side polish against iOS screenshot set


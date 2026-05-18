# TgInstantVideoBubble Component Passport

## Goal
Telegram-style circular video note atom with iOS-aligned radial progress and transparent overlays.

UI-only scope:
- circular media surface (212 compact / 240 regular)
- **iOS-style radial progress ring** around circle perimeter during download (not centered spinner)
- **Semi-transparent play/download overlay** (no opaque bg circle — iOS `InstantVideoRadialStatusNode` pattern)
- project-owned close icon while fetching/cancellable
- duration badge inside the circle
- dim overlay during download

Full playback/gallery behavior remains owned by chat screen/viewer flows.

## References

### Telegram iOS
- `submodules/TelegramUI/Components/Chat/ChatMessageInstantVideoBubbleContentNode/Sources/ChatMessageInstantVideoBubbleContentNode.swift`
  - circular masking with `radius = width / 2.0`
  - dedicated instant-video path
- `submodules/TelegramUI/Components/Chat/InstantVideoRadialStatusNode/Sources/InstantVideoRadialStatusNode.swift`
  - radial progress ring around entire circle (white, 60% alpha)
  - play triangle: centered, white, 60% opacity, no opaque background
  - scales on tap (1.0 + 1.4×progress)
- `submodules/TelegramUI/Sources/ChatInstantVideoMessageDurationNode.swift`
  - duration badge: 18pt height, white text, semi-opaque black bg, lower-right corner

### Telegram Android
- `TMessagesProj/src/main/java/org/telegram/ui/Cells/ChatMessageCell.java`
  - videoNote circle: 220dp
  - play button: 44dp centered

## Props / Inputs
- `thumbnailPath: string | Resource`
- `videoPath: string | Resource`
- `durationSec: number`
- `containerWidth: number`
- `noBubbleWrap: boolean`
- `isDownloadPending: boolean`
- `downloadProgress: number`
- `onTap()`

## State Matrix
- downloaded — semi-transparent play triangle (no bg circle)
- not downloaded — semi-transparent download icon (no bg circle)
- downloading determinate — radial ring progress around circle + dim overlay + close icon
- downloading indeterminate — spinner + dim overlay + close icon
- placeholder / no preview
- compact vs regular lane

## Layout Rules
1. Bubble surface is circular (radius = diameter / 2).
2. Diameter: 212vp compact, 240vp regular, min 160vp.
3. Preview image: `ImageFit.Cover`, clipped to circle.
4. **Download progress**: radial `Progress(Ring)` around the full circle perimeter, white 60% alpha, 3vp stroke.
5. **Play/download overlay**: semi-transparent icons (#99FFFFFF), NO opaque background circle.
6. **Fetching/cancel overlay**: full-circle dim layer with radial/spinner progress and `ICON_RES_CLOSE`; tap delegates to parent `onDownloadToggle`.
7. Duration badge: lower-right corner inside circle, semi-opaque dark bg pill.
8. Caption/meta outside the circle remain router-owned.

## Token Mapping
- `INSTANT_VIDEO_BUBBLE_SIZE`, `INSTANT_VIDEO_BUBBLE_SIZE_REGULAR`, `INSTANT_VIDEO_BUBBLE_MIN_SIZE`
- `INSTANT_VIDEO_BUBBLE_PLAY_ICON_SIZE`
- `INSTANT_VIDEO_BUBBLE_DURATION_*`
- `VIDEO_BUBBLE_PLAY_ICON`, `VIDEO_BUBBLE_DURATION_BG`, `VIDEO_BUBBLE_DURATION_TEXT`
- `VIDEO_BUBBLE_PLACEHOLDER_BG`, `VIDEO_BUBBLE_PLACEHOLDER_ICON`
- `MEDIA_RING_PROGRESS_COLOR`, `MEDIA_PROGRESS_COLOR`, `MEDIA_PROGRESS_STROKE`, `MEDIA_OVERLAY_DARK`
- `MEDIA_STATUS_TRANSITION_SCALE`, `MEDIA_STATUS_ANIM_DURATION`
- `ICON_RES_PLAY`, `ICON_RES_DOWNLOAD`, `ICON_RES_CLOSE`

## Acceptance Checklist
- [ ] `videoNote` renders as a perfect circle
- [ ] Radial ring progress appears around circle perimeter during download
- [ ] No opaque background circle behind play/download icons
- [ ] Semi-transparent overlays match iOS 60% white pattern
- [ ] Dim overlay and close icon visible during download
- [ ] Duration badge readable in lower-right corner
- [ ] Placeholder works when no preview available
- [ ] Circle clipping stays clean
- [ ] Tap target is the whole circle

## Current Behavior Boundary
- `TgMessageRouter` maps `onDownloadToggle` to download or cancel through the shared media command path.
- `TgInstantVideoBubble` renders the circular status state only; TDLib commands and gallery/playback behavior remain parent-owned.
- Static demo coverage is not manual device/emulator visual acceptance.

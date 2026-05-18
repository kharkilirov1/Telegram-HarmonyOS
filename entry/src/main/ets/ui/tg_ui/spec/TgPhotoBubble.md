# TgPhotoBubble (Phase C.1 / Step 1)

## Goal
Implement Telegram-style photo bubble atom for chat timeline:
- media thumbnail/content with rounded corners
- incoming/outgoing alignment
- optional caption block under media
- explicit remote/fetching/local status affordance

UI scope for this step. The atom renders status controls and delegates all download/cancel/gallery behavior to the parent router.

## iOS References
- `submodules/TelegramUI/Components/Chat/ChatMessageMediaBubbleContentNode/Sources/ChatMessageMediaBubbleContentNode.swift`
  - media bubble container and integration in chat message content
- `submodules/TelegramUI/Components/Chat/ChatMessageInteractiveMediaNode/Sources/ChatMessageInteractiveMediaNode.swift`
  - interactive media rendering and corner handling
- `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Sources/ChatMessageItemCommon.swift`
  - canonical media layout constants:
    - `defaultCornerRadius = 16`
    - `maxDimensions = 300x380` (compact)
    - `minDimensions = 170x74`

## Props / Inputs
- `photoPath: string | Resource`
- `hasLocalPhoto: boolean`
- `isDownloading: boolean`
- `downloadProgress: number`
- `caption: string`
- `isOutgoing: boolean`
- `containerWidth: number`
- `maxWidthRatio: number`
- `photoWidth: number`
- `photoHeight: number`

## State Matrix (demo)
- incoming/outgoing
- with/without caption
- horizontal and vertical aspect ratios
- placeholder state when file path is missing
- narrow container stress
- remote/download affordance when a thumbnail exists but full photo is not local
- fetching/progress affordance with cancellable close icon
- local photo state with no download overlay

## Layout Rules
1) Bubble aligns left for incoming, right for outgoing.
2) Bubble width respects `containerWidth * maxWidthRatio`, clamped by tokenized media min/max bounds.
3) Media keeps aspect ratio when `photoWidth/photoHeight` are available; otherwise fallback square-ish size.
4) Caption is optional and rendered below media inside the same bubble container.
5) Center status overlay is a finite state machine:
   - `hasLocalPhoto=false`, `isDownloading=false` -> download icon
   - `isDownloading=true`, `downloadProgress >= 0 && < 1` -> ring progress + close icon
   - `isDownloading=true`, indeterminate progress -> loading spinner + close icon
   - `hasLocalPhoto=true`, `isDownloading=false` -> no overlay; surface tap opens photo
6) All geometry/colors/typography are tokenized.
7) The atom never sends TDLib commands directly; `onDownloadToggle` is parent-owned.

## Token Mapping
- Geometry:
  - `PHOTO_BUBBLE_RADIUS`
  - `PHOTO_BUBBLE_IMAGE_INSET`
  - `PHOTO_BUBBLE_MIN_WIDTH/MIN_HEIGHT`
  - `PHOTO_BUBBLE_MAX_WIDTH/MAX_HEIGHT`
  - `PHOTO_BUBBLE_CAPTION_TOP_GAP`
  - `PHOTO_BUBBLE_CAPTION_PADDING_H/PADDING_BOTTOM`
- Typography:
  - `PHOTO_BUBBLE_CAPTION_SIZE`
  - `PHOTO_BUBBLE_CAPTION_LINE_HEIGHT`
  - `PHOTO_BUBBLE_CAPTION_MAX_LINES`
- Colors:
  - `COLOR_MSG_BUBBLE_INCOMING_BG/OUTGOING_BG`
  - `PHOTO_BUBBLE_CAPTION_TEXT_INCOMING/OUTGOING`
  - `PHOTO_BUBBLE_PLACEHOLDER_BG/ICON`
- Shared media status:
  - `MEDIA_PROGRESS_COLOR`
  - `MEDIA_PROGRESS_STROKE`
  - `MEDIA_OVERLAY_DARK`
  - `MEDIA_CANCEL_ICON_SIZE`
  - `MEDIA_STATUS_TRANSITION_SCALE`
  - `MEDIA_STATUS_ANIM_DURATION`
  - `ICON_RES_DOWNLOAD`
  - `ICON_RES_CLOSE`

## Acceptance Checklist
- [ ] Bubble corners visually match iOS-like 16dp baseline for media cards
- [ ] Caption is stable and ellipsized for long text
- [ ] Aspect-ratio handling does not overflow max height
- [ ] Missing-path placeholder remains layout-compatible
- [ ] Remote/fetching/local status overlay switches without system icon dependencies
- [ ] Fetching overlay delegates to parent-owned download toggle for cancellation
- [ ] No magic visual constants in atom

## Demo Requirements (`TgPhotoBubbleDemo.ets`)
At least 9 cases:
1) incoming no caption
2) outgoing short caption
3) incoming vertical media
4) outgoing long caption
5) placeholder without file path
6) narrow container stress
7) remote thumbnail with download icon
8) determinate fetching with ring + close icon
9) indeterminate fetching with spinner + close icon

## Current Behavior Boundary
- `TgMessageRouter` decides whether `onDownloadToggle` means request or cancel.
- `TgChatScreenPage` owns actual TDLib `downloadFile` / `cancelDownloadFile` commands.
- This atom does not verify device/gallery behavior by itself; demo coverage is static state coverage only.

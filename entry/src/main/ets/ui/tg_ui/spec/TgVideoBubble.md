# TgVideoBubble (Phase C.1 / Step 2)

## Goal
Implement Telegram-style video bubble atom:
- preview image area (thumbnail)
- center radial status overlay: download -> fetching/progress -> play
- duration badge on bottom-right
- optional caption below media

UI scope for this atom: it renders the current media state and forwards taps to the parent.
Actual TDLib download, cancel, gallery open, and playback behavior stay parent-owned.

## iOS References
- `submodules/TelegramUI/Components/Chat/ChatMessageMediaBubbleContentNode/Sources/ChatMessageMediaBubbleContentNode.swift`
  - media bubble composition and integration in message bubble stack
- `submodules/TelegramUI/Components/Chat/ChatMessageInteractiveMediaNode/Sources/ChatMessageInteractiveMediaNode.swift`
  - video overlay behavior and inline timestamp/progress visuals
- `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Sources/ChatMessageItemCommon.swift`
  - canonical geometry constants:
    - image corner radius `16`
    - image min dimensions `170x74`
    - image max dimensions `300x380`
    - video vertical/horizontal max heights (`250/360`) for layout contracts

## Props / Inputs
- `thumbnailPath: string | Resource`
- `videoPath: string | Resource`
- `durationSec: number`
- `caption: string`
- `isOutgoing: boolean`
- `containerWidth: number`
- `maxWidthRatio: number`
- `videoWidth: number`
- `videoHeight: number`
- `isDownloadPending: boolean`
- `downloadProgress: number`
- `hidePlayButton: boolean`
- `isShortVideo: boolean`

## State Matrix (demo)
- incoming/outgoing
- with/without caption
- horizontal and vertical video aspect ratio
- missing thumbnail placeholder
- narrow container stress
- remote video with download affordance
- fetching video with indeterminate/determinate progress
- local video with play affordance
- local short-video preview where autoplay ownership suppresses the center play overlay

## Layout Rules
1) Bubble aligns left (incoming) or right (outgoing).
2) Main media area keeps aspect ratio from `videoWidth/videoHeight` when provided.
3) Center media status is overlayed via `Stack` and switches between download, fetching/progress, and play states.
4) Duration badge is anchored bottom-right in preview.
5) Caption renders below media inside same bubble and is ellipsized.
6) All geometry/colors/typography come from tokens.
7) Short-video inline playback uses `TgInlineVideoView`; while that helper owns the live preview, the video bubble suppresses the generic center play overlay to avoid a wrong mixed state.

## Internal helper ownership: `TgInlineVideoView`
`TgInlineVideoView` is treated as a non-public inline renderer owned by the video bubble when the local short-video file is available.

Parent-owned contract:
1. `TgVideoBubble` owns media sizing, bubble chrome, caption, duration badge, download/progress overlays, and tap routing.
2. `TgInlineVideoView` receives final `videoWidth` / `videoHeight` plus `videoPath` / `thumbnailPath`; it must not recompute bubble layout or own caption/status overlays.
3. In this parent, inline playback is limited to `hasLocalVideo() && isShortVideo`: `autoPlay=true`, `loop=false`, `muted=true`, `showControls=false`, `isCircular=false`.
4. The helper may keep the thumbnail visible until playback starts and return to thumbnail/error affordance on `Video.onError`, but the parent keeps duration/download/caption rhythm stable.
5. `onTap` is forwarded to the parent playback action; full-screen/gallery playback controls are not owned by this bubble spec.

## Token Mapping
- Geometry:
  - `VIDEO_BUBBLE_RADIUS`
  - `VIDEO_BUBBLE_IMAGE_INSET`
  - `VIDEO_BUBBLE_MIN_WIDTH/MIN_HEIGHT`
  - `VIDEO_BUBBLE_MAX_WIDTH/MAX_HEIGHT`
  - `VIDEO_BUBBLE_PLAY_BG_SIZE`
  - `VIDEO_BUBBLE_PLAY_ICON_SIZE`
  - `MEDIA_STATUS_TRANSITION_SCALE`
  - `MEDIA_STATUS_ANIM_DURATION`
  - `VIDEO_BUBBLE_DURATION_RADIUS/PADDING_*/MARGIN`
  - `VIDEO_BUBBLE_CAPTION_*`
- Colors:
  - `COLOR_MSG_BUBBLE_INCOMING_BG/OUTGOING_BG`
  - `VIDEO_BUBBLE_PLAY_BG/PLAY_ICON`
  - `MEDIA_OVERLAY_DARK`
  - `MEDIA_PROGRESS_COLOR`
  - `VIDEO_BUBBLE_DURATION_BG/DURATION_TEXT`
  - `VIDEO_BUBBLE_CAPTION_TEXT_INCOMING/OUTGOING`
  - `VIDEO_BUBBLE_PLACEHOLDER_BG/ICON`

## Acceptance Checklist
- [ ] Play overlay is centered and stable across aspect ratios
- [ ] Download/fetch/play icon switching is visible and uses project-owned tg_ui icons
- [ ] Determinate and indeterminate fetching states render a visible progress affordance
- [ ] Duration badge is readable on light/dark previews
- [ ] Caption and preview geometry do not break bubble corners
- [ ] Missing-thumbnail state keeps same bubble rhythm
- [ ] No hardcoded visual constants in atom

## Demo Requirements (`TgVideoBubbleDemo.ets`)
At least 6 cases:
1) incoming no caption
2) outgoing short caption
3) vertical video
4) outgoing long caption
5) placeholder without thumbnail
6) narrow container stress
7) remote download state
8) fetching/progress state
9) local playable state
10) short-video state without generic center play overlay

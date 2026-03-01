# TgVideoBubble (Phase C.1 / Step 2)

## Goal
Implement Telegram-style video bubble atom:
- preview image area (thumbnail)
- center play overlay
- duration badge on bottom-right
- optional caption below media

UI-only scope for this step. No playback logic, progress fetch, or gestures.

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

## State Matrix (demo)
- incoming/outgoing
- with/without caption
- horizontal and vertical video aspect ratio
- missing thumbnail placeholder
- narrow container stress

## Layout Rules
1) Bubble aligns left (incoming) or right (outgoing).
2) Main media area keeps aspect ratio from `videoWidth/videoHeight` when provided.
3) Center play button is overlayed via `Stack` (overlay-only usage).
4) Duration badge is anchored bottom-right in preview.
5) Caption renders below media inside same bubble and is ellipsized.
6) All geometry/colors/typography come from tokens.

## Token Mapping
- Geometry:
  - `VIDEO_BUBBLE_RADIUS`
  - `VIDEO_BUBBLE_IMAGE_INSET`
  - `VIDEO_BUBBLE_MIN_WIDTH/MIN_HEIGHT`
  - `VIDEO_BUBBLE_MAX_WIDTH/MAX_HEIGHT`
  - `VIDEO_BUBBLE_PLAY_BG_SIZE`
  - `VIDEO_BUBBLE_PLAY_ICON_SIZE`
  - `VIDEO_BUBBLE_DURATION_RADIUS/PADDING_*/MARGIN`
  - `VIDEO_BUBBLE_CAPTION_*`
- Colors:
  - `COLOR_MSG_BUBBLE_INCOMING_BG/OUTGOING_BG`
  - `VIDEO_BUBBLE_PLAY_BG/PLAY_ICON`
  - `VIDEO_BUBBLE_DURATION_BG/DURATION_TEXT`
  - `VIDEO_BUBBLE_CAPTION_TEXT_INCOMING/OUTGOING`
  - `VIDEO_BUBBLE_PLACEHOLDER_BG/ICON`

## Acceptance Checklist
- [ ] Play overlay is centered and stable across aspect ratios
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

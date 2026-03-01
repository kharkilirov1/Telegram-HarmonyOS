# TgPhotoBubble (Phase C.1 / Step 1)

## Goal
Implement Telegram-style photo bubble atom for chat timeline:
- media thumbnail/content with rounded corners
- incoming/outgoing alignment
- optional caption block under media

UI-only scope for this step. No media download, progress, gestures, or gallery transitions yet.

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

## Layout Rules
1) Bubble aligns left for incoming, right for outgoing.
2) Bubble width respects `containerWidth * maxWidthRatio`, clamped by tokenized media min/max bounds.
3) Media keeps aspect ratio when `photoWidth/photoHeight` are available; otherwise fallback square-ish size.
4) Caption is optional and rendered below media inside the same bubble container.
5) All geometry/colors/typography are tokenized.

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

## Acceptance Checklist
- [ ] Bubble corners visually match iOS-like 16dp baseline for media cards
- [ ] Caption is stable and ellipsized for long text
- [ ] Aspect-ratio handling does not overflow max height
- [ ] Missing-path placeholder remains layout-compatible
- [ ] No magic visual constants in atom

## Demo Requirements (`TgPhotoBubbleDemo.ets`)
At least 6 cases:
1) incoming no caption
2) outgoing short caption
3) incoming vertical media
4) outgoing long caption
5) placeholder without file path
6) narrow container stress

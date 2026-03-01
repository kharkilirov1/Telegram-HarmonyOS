# TgStickerView (Phase C.1 / Step 5)

## Goal
Implement Telegram-style sticker message atom:
- **no bubble background**
- transparent sticker rendering area
- fixed-size constraints with aspect-fit by source dimensions

UI-only scope for this step. No playback engine for animated/video stickers.

## iOS References
- `submodules/TelegramUI/Components/Chat/ChatMessageStickerItemNode/Sources/ChatMessageStickerItemNode.swift`
  - static sticker message rendering path
  - baseline display target `184x184` (`displaySize = CGSize(width: 184.0, height: 184.0)`)
- `submodules/TelegramUI/Components/Chat/ChatMessageAnimatedStickerItemNode/Sources/ChatMessageAnimatedStickerItemNode.swift`
  - animated sticker rendering path
  - larger display target for specific sticker classes (`180..240`)
- `submodules/TelegramUI/Components/Chat/ChatMessageBubbleItemNode/Sources/ChatMessageBubbleItemNode.swift`
  - content routing distinction for sticker/animated-sticker item nodes

## Props / Inputs
- `stickerPath: string | Resource`
- `isOutgoing: boolean`
- `isAnimatedSticker: boolean`
- `isVideoSticker: boolean`
- `stickerWidth: number`
- `stickerHeight: number`
- `containerWidth: number`
- `maxWidthRatio: number`

## State Matrix (demo)
- incoming/outgoing
- square/wide/tall source dimensions
- animated sticker size path
- video sticker size path
- missing file placeholder
- narrow container stress

## Layout Rules
1) Alignment by direction only (incoming left, outgoing right).
2) No bubble background/radius around the sticker itself.
3) Sticker bounds are aspect-fitted within tokenized max size.
4) Animated/video stickers can use larger max envelope than static stickers.
5) Placeholder is used only when file path is missing.
6) All visual constants are tokenized.

## Token Mapping
- Sizes:
  - `STICKER_VIEW_MAX_SIZE`
  - `STICKER_VIEW_ANIMATED_MAX_SIZE`
  - `STICKER_VIEW_MIN_SIZE`
  - `STICKER_VIEW_PLACEHOLDER_SIZE`
- Colors:
  - `STICKER_VIEW_PLACEHOLDER_BG`
  - `STICKER_VIEW_PLACEHOLDER_ICON`
- Icon:
  - `ICON_RES_STICKER`

## Acceptance Checklist
- [ ] Sticker renders without message bubble background
- [ ] Aspect ratio preserved for non-square stickers
- [ ] Animated/video states can occupy larger size envelope
- [ ] Placeholder appears only when path is unavailable
- [ ] No hardcoded visual constants in atom

## Demo Requirements (`TgStickerViewDemo.ets`)
At least 7 cases:
1) incoming static square
2) outgoing static wide
3) incoming static tall
4) outgoing animated size
5) incoming video-sticker size
6) placeholder without path
7) narrow container stress

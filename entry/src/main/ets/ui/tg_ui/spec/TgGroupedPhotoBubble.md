# TgGroupedPhotoBubble (Phase C.1 / grouped media follow-up)

## Goal
Implement Telegram-style grouped photo/album bubble for chat timeline:
- one bubble per `media_album_id` cluster
- 2-up / 3-up / 4-up mosaic layouts
- `5+` overflow overlay on the last visible cell
- incoming/outgoing alignment inside the normal bubble lane

UI-only scope for this step. No multi-select, drag, gallery transitions, or shared-element animation.

## References

### Telegram iOS
- `submodules/TelegramUI/Components/Chat/ChatMessageMediaBubbleContentNode/Sources/ChatMessageMediaBubbleContentNode.swift`
  - grouped media bubble integration and caption/meta contract
- `submodules/TelegramUI/Components/Chat/ChatMessageBubbleItemNode/Sources/ChatMessageBubbleItemNode.swift`
  - bubble composition around media groups

### Telegram Android
- `TMessagesProj/src/main/java/org/telegram/ui/Cells/GroupMedia.java`
  - grouped-media mosaic sizing/layout attempts
- `TMessagesProj/src/main/java/org/telegram/ui/Cells/ChatMessageCell.java`
  - grouped message cell integration

## Props / Inputs
- `photoPaths: string[]`
- `photoWidths: number[]`
- `photoHeights: number[]`
- `isOutgoing: boolean`
- `containerWidth: number`
- `maxWidthRatio: number`
- `noBubbleWrap: boolean`
- `onPhotoTap(photoPath: string)`

## State Matrix (demo)
- incoming 2-up
- outgoing 3-up
- incoming 4-up
- outgoing `5+`
- placeholder/missing-path cell
- narrow container stress

## Layout Rules
1) Bubble aligns left for incoming, right for outgoing.
2) Layout is driven by grouped-media count, not by a stack of single-photo bubbles.
3) Bubble width respects message-lane width helpers and grouped-media max width tokens.
4) Cells use clipped rounded corners and Telegram-style tight inter-cell gap.
5) For `5+`, the last visible cell shows a dark overlay with `+N`.
6) Caption/time/meta stay outside this atom; router owns outer composition.

## Token Mapping
- Geometry:
  - `PHOTO_ALBUM_RADIUS`
  - `PHOTO_ALBUM_GAP`
  - `PHOTO_ALBUM_MAX_WIDTH/MAX_WIDTH_REGULAR`
  - `PHOTO_ALBUM_MAX_HEIGHT/MAX_HEIGHT_REGULAR`
  - `PHOTO_ALBUM_TWO_HEIGHT_RATIO`
  - `PHOTO_ALBUM_THREE_HEIGHT_RATIO`
  - `PHOTO_ALBUM_THREE_PRIMARY_WIDTH_RATIO`
- Overlay:
  - `PHOTO_ALBUM_OVERLAY_TEXT_SIZE`
  - `PHOTO_ALBUM_OVERLAY_BG`

## Acceptance Checklist
- [ ] album messages collapse into a single bubble in timeline
- [ ] pair/trio/four-up layouts render as one grouped unit
- [ ] last visible cell in `5+` shows `+N`
- [ ] rounded clipping stays clean on all cells
- [ ] tapping a cell surfaces the tapped photo path to the router/page
- [ ] no hardcoded geometry outside tokens

## Demo Requirements (`TgGroupedPhotoBubbleDemo.ets`)
At least 4 cases:
1) incoming pair
2) outgoing trio
3) incoming four-up
4) outgoing `5+` overlay

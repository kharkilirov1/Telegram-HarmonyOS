# TgMediaGalleryPage — Page-Level Contract

## Purpose
Full-screen media gallery surface opened from the chat screen for message media:
- photo, video, animation, and video-note items
- swipe between media from the current chat timeline
- top sender/time overlay and bottom caption overlay
- photo zoom/pan/dismiss gestures
- full-screen video/animation playback through the internal `TgInlineVideoView` helper

This is a page/integration surface, not a reusable message bubble atom.

## References
- iOS:
  - `submodules/AccountContext/Sources/GalleryController.swift`
  - `submodules/AccountContext/Sources/OpenChatMessage.swift`
  - `submodules/TelegramUI/Components/Chat/ChatMessageMediaBubbleContentNode/Sources/ChatMessageMediaBubbleContentNode.swift`
  - `submodules/TelegramUI/Components/Chat/ChatMessageInteractiveMediaNode/Sources/ChatMessageInteractiveMediaNode.swift`
- HarmonyOS / ArkUI:
  - `Swiper` for paged media navigation
  - `Image` with `ImageFit.Contain` for full-screen photo viewing
  - `PinchGesture`, `PanGesture`, and `TapGesture` for zoom/dismiss/toggle behavior
  - `Video` via internal `TgInlineVideoView`

## Inputs
| Param/Event | Type | Default | Contract |
| --- | --- | --- | --- |
| `mediaItems` | `MediaGalleryItem[]` | `[]` | Ordered gallery items built by the chat screen from visible/loaded media messages. |
| `initialIndex` | `number` | `0` | Initial item index; parent must clamp to a valid range before opening. |
| `statusBarHeight` | `number` | `0` | Top inset used by the overlay bar/counter. |
| `onDismiss` | `() => void` | noop | Parent-owned close action. |
| `onDownloadRequest` | `(fileId: number) => void` | noop | Parent-owned media download request for not-downloaded items. |
| `onDownloadCancel` | `(fileId: number) => void` | noop | Parent-owned media download cancellation for active transfer items. |

## Item model
`MediaGalleryItem` fields consumed by this page:
- `type`: `photo`, `video`, `animation`, or `videoNote`
- `path`: local full media path when downloaded
- `thumbnailPath`: local thumbnail/preview path
- `caption`
- `senderName`
- `timestamp`
- `width` / `height`
- `durationSec`
- `fileId`
- `messageId`
- `isDownloading`
- `downloadProgress`

## State matrix
| State | Expected behavior |
| --- | --- |
| Single downloaded photo | Black full-screen background, contained image, top overlay, optional caption. |
| Multi-item gallery | `Swiper` uses `initialIndex`, disables loop, shows counter when overlay is visible. |
| Downloaded video | Renders through `TgInlineVideoView`, shows controls, duration badge, and overlay toggle on tap. |
| Downloaded animation/GIF | Renders through `TgInlineVideoView`, loops, stays muted, no video controls. |
| Not downloaded item | Shows thumbnail if present plus centered download affordance; download event is delegated to parent. Photo thumbnails must not be treated as full local media. |
| Determinate transfer | `downloadProgress in 0..1` renders a ring + project close icon even when `isDownloading` is false. |
| Indeterminate transfer | `isDownloading=true` with no progress renders spinner + project close icon. |
| Empty gallery | Shows a safe empty state instead of a blank `Swiper`. |
| Captioned media | Caption appears in bottom overlay, max 4 lines, ellipsized. |
| Zoomed photo | Pinch clamps scale to `1.0...4.0`; one-finger pan moves the zoomed photo. |
| Non-zoomed vertical pan | Updates dismiss offset/opacity and calls `onDismiss` after the threshold. |

## Layout and interaction rules
1. Page background is black and fills safe areas.
2. Media content lives in a non-looping `Swiper` with `cachedCount(1)`.
3. `currentIndex` is the source of truth for overlay text, counter, and active video command.
4. Tap toggles top/bottom overlays; double tap toggles photo zoom between reset and 2x.
5. Photo rendering uses `ImageFit.Contain`; media must not be cropped in the full-screen viewer.
6. Swipe change resets photo zoom and stops the previous video before activating the new current video.
7. Download behavior is delegated through `onDownloadRequest(fileId)` and `onDownloadCancel(fileId)`; this page only keeps a local optimistic pending hint after a tap.
8. Dismiss is parent-owned through `onDismiss`; this page must not mutate chat route/navigation state directly.
9. Gallery items distinguish `path` (full local media) from `thumbnailPath` (preview only). Missing full paths must stay in download/transfer UI even when a thumbnail exists.

## Internal helper ownership: `TgInlineVideoView`
`TgInlineVideoView` remains a non-public playback renderer. In this page, `TgMediaGalleryPage` owns the full-screen playback contract:
1. The page supplies final displayed dimensions from `MediaGalleryItem.width/height` with current fallbacks.
2. `autoPlay` is true only for the current swiper index.
3. `loop` and `muted` are true for `animation`; normal video shows controls and is not forced muted by the page contract.
4. `playbackCommand` is derived from current/previous index changes so leaving an item stops previous playback.
5. The helper owns low-level `Video` lifecycle/thumbnail/error fallback; the page owns overlay, caption, counter, duration badge, and download state.

## Token / polish debt
The gallery overlay, pill, text colors, close/download sizes, and dismiss threshold are tokenized through `MEDIA_GALLERY_*`. Some page-local paddings and badge micro-radii remain literal because they are one-off layout insets.

## Acceptance checklist
- [ ] Opens at the correct `initialIndex` from `TgChatScreenPage`.
- [ ] Multi-item counter matches current swiper index.
- [ ] Photo pinch/double-tap/pan interactions do not conflict with overlay tap.
- [ ] Dismiss gesture only dismisses when photo scale is reset.
- [ ] Video starts only for the current item and stops previous playback on swipe.
- [ ] Animation/GIF loops muted without showing normal video controls.
- [ ] Not-downloaded items delegate download request with the correct `fileId`.
- [ ] Active transfer items delegate cancel with the correct `fileId`.
- [ ] Photo thumbnails do not open as if full photos are downloaded.
- [ ] Empty gallery does not render a blank full-screen Swiper.
- [ ] Caption/top overlay contrast is readable in light/dark media.
- [ ] No manual device/emulator acceptance is claimed without an actual artifact.

## Demo
`entry/src/main/ets/ui/tg_ui/demos/TgMediaGalleryPageDemo.ets` covers:
1. single downloaded photo
2. multi-photo gallery with initial index
3. video with duration/caption
4. animation/GIF item
5. not-downloaded photo/video with thumbnail
6. downloading photo/video states
7. empty gallery fallback
8. long caption and long sender name

The demo is static preview coverage only; it is not manual device/emulator acceptance.

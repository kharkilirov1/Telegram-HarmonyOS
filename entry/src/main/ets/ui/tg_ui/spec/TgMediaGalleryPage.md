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
  - `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Sources\ChatController.swift` — resolves the visible message `transitionNode` and updates `hiddenMedia` while the gallery owns that media
  - `C:\Refs\Telegram\Telegram-iOS-current\submodules\GalleryUI\Sources\GalleryController.swift` — presentation/dismiss coordination and current central item
  - `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Sources\OpenChatMessage.swift` — `transitionNode` and `setupTemporaryHiddenMedia` contracts
  - `C:\Refs\Telegram\Telegram-iOS-current\submodules\GalleryUI\Sources\GalleryControllerNode.swift` — continuous vertical-dismiss alpha/threshold behavior
  - `C:\Refs\Telegram\Telegram-iOS-current\submodules\GalleryUI\Sources\Items\ChatImageGalleryItem.swift` — image fetch/status UI, transition snapshots and return target
  - `C:\Refs\Telegram\Telegram-iOS-current\submodules\GalleryData\Sources\GalleryData.swift` — stable gallery item identity and group construction
  - `C:\Refs\Telegram\Telegram-iOS-current\submodules\GalleryUI\Sources\ZoomableContentGalleryItemNode.swift` — single/double-tap arbitration and zooming around the tapped content point
  - `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\Chat\ChatMessageMediaBubbleContentNode\Sources\ChatMessageMediaBubbleContentNode.swift`
  - `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\Chat\ChatMessageInteractiveMediaNode\Sources\ChatMessageInteractiveMediaNode.swift`
  - `C:\Refs\Telegram\Telegram-iOS-current\submodules\Postbox\Sources\MediaResourceStatus.swift` — `Remote`, `Local`, `Fetching`, and `Paused` transfer states
- HarmonyOS / ArkUI:
  - `Swiper` for paged media navigation
  - `Image` with `ImageFit.Contain` for full-screen photo viewing
  - `PinchGesture`, `PanGesture`, and `TapGesture` for zoom/dismiss/toggle behavior
  - `geometryTransition` with the same stable message/media identity on the chat source and fullscreen destination
  - `animateTo` with native `curves.responsiveSpringMotion` for the shared state change
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
- `minithumb`: TDLib `data:image/...` fallback used only when no local thumbnail path exists
- `caption`
- `senderName`
- `timestamp`
- `width` / `height`
- `durationSec`
- `fileId`
- `messageId`
- `sourceMessageId`: stable identity of the exact source media node; album children use their own
  real member message IDs
- `sourceMediaIdentity`: semantic identity of the media inside the source message; paired with
  `sourceMessageId` so identity does not depend on current gallery or album index
- `isDownloading`
- `downloadProgress`

## State matrix
| State | Expected behavior |
| --- | --- |
| Single downloaded photo | Black full-screen background, contained image, top overlay, optional caption. |
| Multi-item gallery | `Swiper` uses `initialIndex`, disables loop, shows counter when overlay is visible. |
| Downloaded video | Renders through `TgInlineVideoView`, shows controls, duration badge, and overlay toggle on tap. |
| Downloaded animation/GIF | Renders through `TgInlineVideoView`, loops, stays muted, no video controls. |
| Not downloaded item | Shows a local thumbnail or blurred TDLib minithumbnail fallback plus centered download affordance; download event is delegated to parent. Preview data must not be treated as full local media. |
| Remote/paused ordinary photo tapped in chat | Requests that exact photo resource and remains in chat. The gallery opens only after the full photo becomes local; thumbnail/minithumb availability does not bypass this gate. |
| Remote video surface tap | Opens the gallery immediately and starts one download request in parallel; an already-active transfer opens without issuing a duplicate request. |
| Determinate transfer | `downloadProgress in 0..1` renders a `50 x 50 pt` iOS-equivalent radial ring + cancel icon even when `isDownloading` is false. |
| Indeterminate transfer | `isDownloading=true` with no progress renders the same `50 x 50 pt` spinner + cancel icon. |
| Empty gallery | Shows a safe empty state instead of a blank `Swiper`. |
| Captioned media | Caption appears in bottom overlay, max 4 lines, ellipsized. |
| Zoomed photo | Pinch clamps scale to `1.0...4.0`, preserves the grabbed content point under the moving pinch center, and bounds offsets to the contained-media overflow; one-finger pan moves the zoomed photo on both axes. |
| Non-zoomed photo | The photo owns only vertical pan for dismiss; horizontal pan is released to the gallery `Swiper`. |
| Open from a visible media bubble | Only the visual media surface is temporarily hidden and the active gallery item receives the same composite `geometryTransition` id; caption, reply, sender, status, transfer badge, and metadata are not part of the shared element. |
| Swipe or timeline refresh while open | Hidden source identity follows the current central item. It is re-resolved by stable message/media identity after reorder/rebuild, never by the originally tapped index. |
| Close to a visible source | Gallery removal and source restoration target the current central item's exact source in one native spring transaction, producing the reverse shared-element path. |
| Current source unavailable | If the current source is offscreen, removed, or no longer resolvable, dismiss without a shared target; never jump back to the originally tapped or stale cell. |

## Layout and interaction rules
1. Page background is black and fills safe areas.
2. Media content lives in a non-looping `Swiper` with `cachedCount(1)`.
3. `currentIndex` is the source of truth for overlay text, counter, active video command, hidden chat
   media and the close transition target.
4. Download/cancel controls stay outside the photo's parent tap recognizer so nested controls remain reachable.
5. Photo taps use one `GestureMode.Exclusive` group with the double tap before the single tap. Single tap toggles overlays; double tap zooms around the local tap point or resets without also toggling overlays.
6. Pinch tracks `pinchCenterX/Y` from the gesture start through updates so the grabbed content point stays under the fingers. Pinch and zoomed pan always pass through the same contained-media bounds resolver.
7. Dismiss and zoom pan are separate tagged recognizers. `onGestureRecognizerJudgeBegin` reads the current scale at recognition time: at `1x` it continues only `gallery_photo_dismiss_pan` (`PanDirection.Vertical`) and rejects `gallery_photo_zoom_pan` so horizontal motion reaches the surrounding `Swiper`; above `1x` it rejects dismiss and continues `gallery_photo_zoom_pan` (`PanDirection.All`).
8. Photo rendering uses `ImageFit.Contain`; media must not be cropped in the full-screen viewer.
9. Swipe change resets photo zoom and stops the previous video before activating the new current video.
10. Download behavior is delegated through `onDownloadRequest(fileId)` and `onDownloadCancel(fileId)`; this page only keeps a local optimistic pending hint after a tap.
11. Dismiss is parent-owned through `onDismiss`; this page must not mutate chat route/navigation state directly.
12. Gallery items distinguish `path` (full local media) from `thumbnailPath` (preview only). Missing full paths must stay in download/transfer UI even when a thumbnail exists.
13. When `thumbnailPath` is absent, `minithumb` keeps the fullscreen transfer surface visually continuous with the chat bubble and uses the shared Telegram blur token.
14. Shared-element identity is the composite `(sourceMessageId, sourceMediaIdentity)`, not gallery
    child index. Album children publish distinct member IDs so the fullscreen item returns to the
    exact source cell rather than morphing the complete mosaic.
15. Only the current `Swiper` item owns the fullscreen transition id; cached neighbor pages must never publish the same destination id simultaneously.
16. The parent chat page owns the `animateTo` transaction and source hiding. On every central-item
    change it restores the previous source and hides the newly current source. After a timeline
    refresh/reorder it resolves that state again by composite stable identity, not retained index.
    The gallery remains a custom Telegram surface and does not take over the native page/navigation
    shell.
17. Single media uses the media node inside `TgMediaBubbleShellV2`; albums move the source host down
    to the exact cell inside `TgGroupedPhotoBubble`. The outer captioned bubble and complete mosaic
    never become a fullscreen endpoint.
18. Both shared-element endpoints carry `TransitionEffect.OPACITY`; HarmonyOS requires the
    transition to retain disappearing content while the parent `animateTo` transaction pairs the
    source and destination. A transition id is published only when the exact current source is
    visible; an offscreen/removed source uses the explicit non-shared fallback instead.
19. The source snapshot contains only the visual media. Date/status, transfer badge/radial control,
    caption and other bubble overlays are hidden before capture so they do not scale into fullscreen.
20. The centered gallery transfer control has the iOS logical size `50 x 50 pt`; on HarmonyOS
    `MEDIA_GALLERY_DOWNLOAD_BUTTON_SIZE` must resolve to `50 vp`, not `80 vp`.
21. At reset zoom, vertical dismiss follows the finger one-to-one. During the drag, controls alpha
    is `clamp(1 - abs(dy) / 50, 0, 1)` and background alpha is
    `clamp(1 - abs(dy) / 80, 0, 1)`.
22. Dismiss commits when normalized iOS-equivalent `abs(velocityY) > 1.0` or
    `abs(dy) > viewportHeight / 12`. Otherwise it reverses continuously from the current visual
    state and restores offset, controls and background without a jump.
23. A committed dismiss returns through shared geometry only when the current central source is
    visible. Otherwise the item continues offscreen in the gesture direction over `0.2 s`, while
    chrome/background fade and all temporary hidden-source state is released.

## Apple interaction and motion rubric

- Direct manipulation: drag displacement is continuous and proportional to the finger; no threshold
  causes a pre-commit snap.
- Spatial continuity: open, swipe, timeline refresh and close preserve the current media's composite
  identity. The originally tapped item has no special role after the central item changes.
- Interruption safety: a canceled or reversed gesture continues from the currently rendered offset
  and alpha values; no animation restarts from a stale endpoint.
- Offscreen safety: if a source cannot be resolved, use the non-shared slide/fade fallback instead of
  fabricating a destination or animating to another cell.
- Reduced motion: preserve the same identity/hiding lifecycle but replace scale/spring travel with a
  short cross-fade; source and fullscreen copies must still never be visible simultaneously.
- iOS timing baseline for image transitions: open position spring `0.21 s`, scale/bounds `0.25 s`,
  content alpha `0.10 s`; close position spring `0.25 s`, content alpha `0.08 s`; gallery
  chrome/background use `0.15 s` on open and `0.10 s` on close.

## Internal helper ownership: `TgInlineVideoView`
`TgInlineVideoView` remains a non-public playback renderer. In this page, `TgMediaGalleryPage` owns the full-screen playback contract:
1. The page supplies final displayed dimensions from `MediaGalleryItem.width/height` with current fallbacks.
2. `autoPlay` is true only for the current swiper index.
3. `loop` and `muted` are true for `animation`; normal video shows controls and is not forced muted by the page contract.
4. `playbackCommand` is derived from current/previous index changes so leaving an item stops previous playback.
5. The helper owns low-level `Video` lifecycle/thumbnail/error fallback; the page owns overlay, caption, counter, duration badge, and download state.

## Token / polish debt
The gallery overlay, pill, text colors, dismiss threshold, and native spring parameters are tokenized
through `MEDIA_GALLERY_*`. `MEDIA_GALLERY_DOWNLOAD_BUTTON_SIZE` has a normative `50 vp` target from
the iOS `50 pt` control. Some page-local paddings and badge micro-radii remain literal because they
are one-off layout insets.

## Acceptance checklist
- [x] Opens at the correct `initialIndex` from `TgChatScreenPage` (API23 remote video opened directly at `8 / 10`).
- [x] Visible source media expands into fullscreen through one shared `geometryTransition` identity (API23 source/intermediate/destination sequence in `24-geometry-open.gif`).
- [ ] Caption, reply, sender, and message metadata stay outside the shared-element geometry and do not scale with the photo/video.
- [x] Close restores the active source media without leaving a duplicate source under the fullscreen item (API23 `26-geometry-close-final.png`).
- [x] Multi-item counter matches current swiper index (API23 `17 / 76 -> 18 / 76`).
- [x] Photo double-tap/pan interactions do not conflict with overlay tap; focal-pinch math is covered by the focused policy test and the same bounded transform path.
- [x] At `1x`, a horizontal swipe changes the gallery page; above `1x`, the same movement pans the photo instead (API23 `17 / 76 -> 18 / 76`, then zoomed pan remains `17 / 76`).
- [x] Dismiss gesture only owns the reset-scale path; a reset-scale vertical swipe closed the gallery after the zoom/pan/reset sequence.
- [ ] Video starts only for the current item and stops previous playback on swipe.
- [ ] Animation/GIF loops muted without showing normal video controls.
- [x] Not-downloaded items delegate download request with the correct `fileId` (API23 `ChatMediaDownload` logged `fileId=12085`).
- [x] A remote video tap opens the gallery before download completion and shows the active transfer over preview media.
- [x] Missing local thumbnails have a focused policy-tested blurred TDLib minithumb fallback.
- [ ] Active transfer items delegate cancel with the correct `fileId`.
- [x] A remote/paused ordinary photo requests download and remains in chat; only the local full
  photo opens the gallery.
- [x] Photo thumbnails/minithumbs do not open as if full photos are downloaded.
- [ ] Gallery download/cancel control measures `50 x 50 vp`.
- [ ] After swipe and timeline refresh, exactly the current central source is hidden and close returns
  to that exact message/media identity rather than the originally tapped cell.
- [ ] Missing/offscreen/removed current source uses the directional `0.2 s` non-shared fallback and
  releases hidden-source state without jumping to a stale cell.
- [ ] Vertical dismiss tracks offset and both alpha curves continuously, supports reversal, and uses
  the velocity or `viewportHeight / 12` commit rule.
- [ ] Empty gallery does not render a blank full-screen Swiper.
- [ ] Caption/top overlay contrast is readable in light/dark media.
- [ ] No manual device/emulator acceptance is claimed without an actual artifact.

## Current gesture evidence
- Final API23 evidence is under `.codex/ui-audit/2026-07-19/gallery-gesture-arbitration/`: `74-gallery-full-baseline.jpeg`, `75-paged-at-1x.jpeg`, `76-doubletap-zoom.jpeg`, `77-zoom-pan-owned.jpeg`, `78-doubletap-reset.jpeg`, and `79-vertical-dismiss.jpeg`.
- The exact counter path is `17 / 76 -> 18 / 76` at `1x`; after double-tap zoom the same horizontal movement keeps `17 / 76` and changes the media crop (mean absolute pixel delta `69.0407`). Double-tap reset restores the baseline media crop exactly (MAD `0.0`, empty diff bounding box).
- The installed HAP SHA-256 is `409347C11AB014E81003E2E69E44F1C569AE5984C0BC5E678E3316F322E39005`. Both shell smoke contracts, clean main `assembleHap`, and ohosTest `assembleHap` passed before installation.

## Demo
`entry/src/main/ets/ui/tg_ui/demos/TgMediaGalleryPageDemo.ets` covers:
1. single downloaded photo
2. multi-photo gallery with initial index
3. video with duration/caption
4. animation/GIF item
5. not-downloaded photo/video with local-thumbnail and TDLib-minithumb branches
6. downloading photo/video states
7. empty gallery fallback
8. long caption and long sender name

The demo is static preview coverage only; it is not manual device/emulator acceptance.

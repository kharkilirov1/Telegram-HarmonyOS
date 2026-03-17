# Phase 1 Design: Media Gallery + Video + GIF Playback

**Date:** 2026-03-17
**Status:** Approved
**Scope:** Fullscreen media viewer, inline video playback, GIF animation

---

## 1. Overview

Bring visual media (photo, video, GIF, video note) to iOS Telegram parity on HarmonyOS. Three main deliverables:

1. **TgMediaGalleryPage** — unified fullscreen viewer replacing TgPhotoViewerPage + TgVideoPlayerPage
2. **TgInlineVideoView** — reusable inline Video component for bubbles
3. **Bubble refactors** — wire inline video into animation/video/videoNote bubbles

## 2. Architecture

### New Components

```
TgMediaGalleryPage (new)    — fullscreen: photo zoom/swipe, video playback
TgInlineVideoView (new)     — inline ArkUI Video wrapper for bubbles
```

### Refactored Components

```
TgAnimationBubble           — static Image → TgInlineVideoView (autoPlay, loop, muted)
TgVideoBubble               — short (≤30s) inline muted autoplay; long tap→gallery
TgInstantVideoBubble        — inline circular video with playback progress ring
TgMessageRouter             — unified onMediaGalleryOpen, isShortVideo prop
TgChatScreenPage            — gallery overlay, viewport lifecycle, remove old viewers
```

### Deleted Components

```
TgPhotoViewerPage           — replaced by TgMediaGalleryPage
TgVideoPlayerPage           — replaced by TgMediaGalleryPage
```

## 3. TgMediaGalleryPage — Fullscreen Viewer

### Input Contract

```typescript
mediaItems: MediaGalleryItem[]   // all visual media from current chat
initialIndex: number             // tapped item index
```

```typescript
interface MediaGalleryItem {
  type: 'photo' | 'video' | 'animation' | 'videoNote'
  path: string              // local file URI
  thumbnailPath: string
  caption: string
  senderName: string
  timestamp: string
  width: number
  height: number
  durationSec: number       // for video/videoNote
}
```

### Behavior by Media Type

| Type | Viewer Behavior |
|------|----------------|
| photo | PinchGesture zoom (1x→4x), double-tap toggle 1x↔2x, pan when zoomed |
| video | Video component fullscreen, custom controls overlay (play/pause, seek, duration) |
| animation | Video loop=true muted=true, no controls |
| videoNote | Video fullscreen (non-circular), controls |

### UI Structure

- **Background:** solid black, status bar hidden
- **Top bar overlay:** sender name + timestamp + close (X) button, fade on tap
- **Bottom bar overlay:** caption text + action buttons (share/forward/save), fade on tap
- **Swipe:** horizontal Swiper between items
- **Dismiss:** swipe-down gesture → fade + scale → close

### Lifecycle

- Open: pause inline video in bubble if playing
- Close: resume inline if needed
- Swipe between items: pause previous video, auto-play next if video/GIF
- Video instances: `LazyForEach` inside Swiper, only current±1 created
- Swiper `onChange`: send `playbackCommand='stop'` to previous, `playbackCommand='play'` to current
- `aboutToDisappear()` in each Swiper item: `controller.stop()` + release

### Navigation

- Overlay layer in TgChatScreenPage root Stack (not NavPathStack)
- Same pattern as current photo/video viewers

## 4. TgInlineVideoView — Inline Video Component

### Input Contract

```typescript
@Param videoPath: string            // file URI
@Param thumbnailPath: string        // preview before play
@Param width: number                // container width
@Param height: number               // container height
@Param autoPlay: boolean            // GIF=true, video short=true, others=false
@Param loop: boolean                // GIF=true, others=false
@Param muted: boolean               // inline=true, gallery=false
@Param showControls: boolean        // false for inline, true for gallery
@Param isCircular: boolean          // true for videoNote
@Param playbackCommand: string      // 'play' | 'pause' | 'stop' | 'none' — parent controls playback via @Monitor
@Event onTap: () => void
@Event onPlaybackEnd: () => void
@Event onProgressUpdate: (currentSec: number, totalSec: number) => void
```

### States

```
idle       → thumbnail visible, Video hidden
playing    → Video active, thumbnail hidden
paused     → Video paused, play icon overlay
completed  → last frame or thumbnail, replay icon overlay
```

### Key Decisions

- ArkUI `Video` component with `controls(false)` — custom overlay controls
- `VideoController` stored inside component
- **Parent→child control:** `@Param playbackCommand` + `@Monitor('playbackCommand')` handler calls controller.start()/pause()/stop(). This solves viewport lifecycle (max 3) and gallery swipe (pause previous).
- **Child→parent progress:** `onProgressUpdate(currentSec, totalSec)` fires from `Video.onUpdate()` callback. Used by TgInstantVideoBubble for playback progress ring.
- Thumbnail overlays Video until first frame renders (avoids black flash)
- Circular videoNote: `Video` + `.clip(true)` + `.borderRadius(size/2)`
- GIF: `autoPlay(true)` + `loop(true)` + `muted(true)` — starts on viewport entry

### Lifecycle

- `aboutToDisappear()`: calls `controller.stop()` — ensures cleanup when LazyForEach destroys item

### Performance

- Max 3 concurrent Video instances in viewport (HarmonyOS limitation)
- `onVisibleAreaChange`: create at 0.5 visibility, release at 0.0
- Priority: playing > autoPlay > idle
- GIFs outside viewport paused, resumed on re-entry

## 5. Bubble Refactors

### TgAnimationBubble (GIF)

- Current: `Image(thumbnailPath)` — static
- New: `TgInlineVideoView(autoPlay=true, loop=true, muted=true)`
- GIF badge stays in corner
- Download overlay when file not local (current behavior preserved)
- After download → auto-transition to autoPlay

### TgVideoBubble

- Short video (≤30s): `TgInlineVideoView(autoPlay=true, muted=true)` inline
  - Small mute/unmute icon in corner
  - Tap → open gallery with sound
- Long video (>30s): thumbnail + play button (current behavior)
  - Tap → open gallery fullscreen
- Threshold 30s matches iOS `automaticPlayback`

### TgInstantVideoBubble (Video Note)

- Current: circular thumbnail + play/download overlay
- New: `TgInlineVideoView(isCircular=true, autoPlay=false, muted=false)` — plays with sound (iOS parity)
- Playback progress ring: driven by `onProgressUpdate(currentSec, totalSec)` → white ring around perimeter
- **Tap state machine:**
  ```
  idle → [tap] → playing (inline in circle)
  playing → [tap] → gallery fullscreen
  completed → [tap] → replay from start
  ```
- Unified `@Event onBubbleTap: (state: 'idle' | 'playing' | 'completed') => void` replaces separate onTap/onPlayToggle

### TgPhotoBubble

- No component changes
- Tap → TgMediaGalleryPage instead of TgPhotoViewerPage

### TgGroupedPhotoBubble

- Tap on cell → TgMediaGalleryPage with correct initialIndex

### TgMessageRouter

- New `@Param isShortVideo: boolean` — drives inline vs thumbnail decision
  - Computed in `ChatTimelineVO.buildEntry()`: `isShortVideo = videoDuration > 0 && videoDuration <= 30`
- New `@Event onMediaGalleryOpen: (messageId: string, mediaIndex: number) => void`
  - Replaces separate onPhotoTap / onVideoTap
- Animation branch passes autoPlay/loop to TgInlineVideoView via TgAnimationBubble

### TgChatScreenPage

- Remove TgPhotoViewerPage and TgVideoPlayerPage
- Single TgMediaGalleryPage overlay
- `buildMediaGalleryItems()` filters timeline for visual media → MediaGalleryItem[]
- Viewport-based video lifecycle management (max 3 active)
- `onMediaGalleryOpen` handler opens gallery at correct index

## 6. Data Flow

### Media Gallery Items Pipeline

```
ChatTimelineVO entries
  → filter by visual media (photo, video, animation, videoNote)
  → map to MediaGalleryItem[]
  → pass to TgMediaGalleryPage with initialIndex
```

### Inline Video Lifecycle

```
onVisibleAreaChange(0.0→0.5) → create Video instance, show thumbnail
onVisibleAreaChange(0.5→1.0) → autoPlay if GIF/shortVideo
onVisibleAreaChange(→0.0)    → pause + release Video instance
```

### File Readiness

- Inline video starts only when videoPath is non-empty
- Not-downloaded: thumbnail + download overlay (current behavior)
- After download complete: auto-transition to autoPlay (GIF) or idle with play button (video)

### Gallery Not-Downloaded Media

- Gallery includes items even when path is empty (user may tap not-yet-downloaded media)
- Not-downloaded items: show thumbnail + download button overlay in gallery
- On download tap: trigger `onMediaDownloadRequest(fileId)` from gallery
- After download completes: gallery item auto-transitions to playable state

## 7. Error Handling

- `Video.onError()` → fallback to thumbnail + retry icon
- Gallery video error → thumbnail + "Playback failed" overlay
- PinchGesture clamp 1x-4x, pan bounded to image edges
- Gallery dismiss releases all Video instances
- Chat exit (`aboutToDisappear`) releases all inline Videos

## 8. Parallel Implementation Streams

### Agent A: TgMediaGalleryPage (worktree)

New files only — no existing file modifications:
- `entry/src/main/ets/ui/tg_ui/atoms/TgMediaGalleryPage.ets`
- `entry/src/main/ets/ui/tg_ui/spec/TgMediaGalleryPage.md`
- `entry/src/main/ets/ui/tg_ui/demos/TgMediaGalleryPageDemo.ets`
- `MediaGalleryItem` model (in same file or separate)

### Agent B: TgInlineVideoView + GIF (worktree)

New files only — no existing file modifications:
- `entry/src/main/ets/ui/tg_ui/atoms/TgInlineVideoView.ets`
- `entry/src/main/ets/ui/tg_ui/spec/TgInlineVideoView.md`
- `entry/src/main/ets/ui/tg_ui/demos/TgInlineVideoViewDemo.ets`

### Integration (sequential, after A+B merge)

Modifications to existing files:
- `TgAnimationBubble.ets` — Image → TgInlineVideoView
- `TgVideoBubble.ets` — add inline video path
- `TgInstantVideoBubble.ets` — add inline circular video + progress ring
- `TgMessageRouter.ets` — unified onMediaGalleryOpen, isShortVideo
- `TgChatScreenPage.ets` — gallery overlay, viewport lifecycle, remove old viewers
- Delete: `TgPhotoViewerPage.ets`, `TgVideoPlayerPage.ets`

## 9. Verification

### Static
- `scripts/smoke-build.ps1` after each stream + integration

### Device
1. Photo tap → gallery opens, pinch zoom works, swipe between photos
2. Short video auto-plays muted inline, tap → gallery with sound
3. Long video shows thumbnail + play, tap → gallery fullscreen
4. GIF auto-plays looping muted in bubble
5. Video note plays inline in circle with progress ring
6. Gallery swipe between mixed media types
7. Swipe-down dismiss works cleanly
8. Max 3 inline videos — no crash on media-heavy chats
9. Album cell tap → gallery at correct index
10. No regression in download/progress states

## 10. HarmonyOS Platform Notes

- ArkUI `Video` component: `autoPlay`, `loop`, `muted`, `controls(false)`, `VideoController`
- `Image` component does NOT animate GIF on API 22 — use `Video` for GIF playback
- TDLib delivers GIF/animation as MP4 files — `Video` component compatible
- `PinchGesture` + `PanGesture` for photo zoom/pan
- `Swiper` for horizontal gallery navigation
- `onVisibleAreaChange` for viewport-based lifecycle

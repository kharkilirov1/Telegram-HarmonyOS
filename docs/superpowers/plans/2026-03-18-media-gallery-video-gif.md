# Media Gallery + Video + GIF Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring photo/video/GIF/videoNote media to iOS Telegram parity — fullscreen gallery viewer, inline video playback, GIF animation.

**Architecture:** Two new components (TgMediaGalleryPage, TgInlineVideoView) built in parallel worktrees, then integrated into existing bubble atoms and router. ArkUI `Video` component for all video/GIF playback. `Swiper` + `PinchGesture` for gallery.

**Tech Stack:** ArkTS, ArkUI Video component, VideoController, PinchGesture, PanGesture, Swiper, LazyForEach

**Spec:** `docs/superpowers/specs/2026-03-17-media-gallery-video-gif-design.md`

---

## Chunk 1: TgInlineVideoView (Agent B — worktree)

New reusable inline video component. No existing files modified.

### Task 1: TgInlineVideoView spec file

**Files:**
- Create: `entry/src/main/ets/ui/tg_ui/spec/TgInlineVideoView.md`

- [ ] **Step 1: Write component passport**

```markdown
# TgInlineVideoView — Component Passport

## Purpose
Reusable inline video playback component wrapping ArkUI Video with custom overlay controls.
Used by TgAnimationBubble (GIF), TgVideoBubble (short video), TgInstantVideoBubble (round video).

## Inputs
| Param | Type | Default | Description |
|---|---|---|---|
| videoPath | string | '' | File URI of local video |
| thumbnailPath | string/Resource | '' | Preview image before play |
| width | number | 0 | Container width |
| height | number | 0 | Container height |
| autoPlay | boolean | false | Auto-start on mount (GIF=true) |
| loop | boolean | false | Loop playback (GIF=true) |
| muted | boolean | true | Mute audio (inline=true, gallery=false) |
| showControls | boolean | false | Show play/pause overlay |
| isCircular | boolean | false | Circular clip for videoNote |
| playbackCommand | string | 'none' | Parent command: play/pause/stop/none |

## Events
| Event | Signature | Description |
|---|---|---|
| onTap | () => void | Surface tap |
| onPlaybackEnd | () => void | Video finished |
| onProgressUpdate | (currentSec, totalSec) => void | Playback position update |

## States
idle → thumbnail visible, Video hidden
playing → Video active, thumbnail hidden
paused → Video paused, play overlay
completed → last frame, replay overlay

## Platform Notes
- ArkUI Video: controls(false), VideoController for imperative control
- @Monitor('playbackCommand') for parent→child control
- aboutToDisappear() calls controller.stop()
- Max 3 concurrent instances recommended
```

- [ ] **Step 2: Commit**
```
git add entry/src/main/ets/ui/tg_ui/spec/TgInlineVideoView.md
git commit -m "docs: add TgInlineVideoView component passport"
```

---

### Task 2: TgInlineVideoView atom

**Files:**
- Create: `entry/src/main/ets/ui/tg_ui/atoms/TgInlineVideoView.ets`

- [ ] **Step 1: Create the component**

```typescript
import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgIcon } from './TgIcon';

@ComponentV2
export struct TgInlineVideoView {
  @Param videoPath: string = '';
  @Param thumbnailPath: string | Resource = '';
  @Param width: number = 0;
  @Param height: number = 0;
  @Param autoPlay: boolean = false;
  @Param loop: boolean = false;
  @Param muted: boolean = true;
  @Param showControls: boolean = false;
  @Param isCircular: boolean = false;
  @Param playbackCommand: string = 'none';
  @Event onTap: () => void = () => {};
  @Event onPlaybackEnd: () => void = () => {};
  @Event onProgressUpdate: (currentSec: number, totalSec: number) => void =
    (_c: number, _t: number) => {};

  @Local private state: string = 'idle'; // idle, playing, paused, completed
  @Local private showThumbnail: boolean = true;
  private controller: VideoController = new VideoController();

  @Monitor('playbackCommand')
  onPlaybackCommandChange(): void {
    if (this.playbackCommand === 'play') {
      this.controller.start();
      this.state = 'playing';
      this.showThumbnail = false;
    } else if (this.playbackCommand === 'pause') {
      this.controller.pause();
      this.state = 'paused';
    } else if (this.playbackCommand === 'stop') {
      this.controller.stop();
      this.state = 'idle';
      this.showThumbnail = true;
    }
  }

  aboutToDisappear(): void {
    this.controller.stop();
  }

  private hasVideo(): boolean {
    if (typeof this.videoPath === 'string') {
      return this.videoPath.trim().length > 0;
    }
    return false;
  }

  private hasThumbnail(): boolean {
    if (typeof this.thumbnailPath === 'string') {
      return (this.thumbnailPath as string).trim().length > 0;
    }
    return true;
  }

  private borderRadiusValue(): number {
    return this.isCircular ? this.height / 2 : 0;
  }

  @Builder
  private buildPlayOverlay() {
    if (this.showControls && this.state !== 'playing') {
      Row() {
        TgIcon({
          src: this.state === 'completed' ? TgUiTokens.ICON_RES_PLAY : TgUiTokens.ICON_RES_PLAY,
          iconSize: TgUiTokens.VIDEO_BUBBLE_PLAY_ICON_SIZE,
          tintColor: '#FFFFFF'
        })
      }
      .width(TgUiTokens.VIDEO_BUBBLE_PLAY_BG_SIZE)
      .height(TgUiTokens.VIDEO_BUBBLE_PLAY_BG_SIZE)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor('#40000000')
      .borderRadius(TgUiTokens.RADIUS_ROUND_MAX)
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // Video layer (always present when path available, hidden behind thumbnail)
      if (this.hasVideo()) {
        Video({
          src: this.videoPath,
          controller: this.controller
        })
          .width(this.width)
          .height(this.height)
          .autoPlay(this.autoPlay)
          .loop(this.loop)
          .muted(this.muted)
          .controls(false)
          .objectFit(ImageFit.Cover)
          .borderRadius(this.borderRadiusValue())
          .clip(true)
          .onStart(() => {
            this.state = 'playing';
            this.showThumbnail = false;
          })
          .onPause(() => {
            this.state = 'paused';
          })
          .onFinish(() => {
            if (!this.loop) {
              this.state = 'completed';
              this.onPlaybackEnd();
            }
          })
          .onUpdate((event: { time: number }) => {
            // Video.onUpdate provides current time in seconds
            // Duration not directly available from event — use onPrepared
          })
          .onPrepared((event: { duration: number }) => {
            // Store duration for progress calc
          })
      }

      // Thumbnail overlay (hides black flash before first frame)
      if (this.showThumbnail && this.hasThumbnail()) {
        Image(this.thumbnailPath)
          .width(this.width)
          .height(this.height)
          .objectFit(ImageFit.Cover)
          .borderRadius(this.borderRadiusValue())
          .clip(true)
      }

      // Play/pause overlay
      this.buildPlayOverlay()
    }
    .width(this.width)
    .height(this.height)
    .borderRadius(this.borderRadiusValue())
    .clip(true)
    .onClick(() => this.onTap())
  }
}
```

**NOTE:** This is the skeleton. The implementing agent must:
1. Wire `onUpdate` + `onPrepared` for progress — add `@Local private totalDuration: number = 0;`, then:
   ```typescript
   .onPrepared((event: { duration: number }) => {
     this.totalDuration = event.duration;
   })
   .onUpdate((event: { time: number }) => {
     this.onProgressUpdate(event.time, this.totalDuration);
   })
   ```
2. Verify `Video.onUpdate` / `Video.onPrepared` event shape in HarmonyOS docs (`search_harmonyos_docs("Video onUpdate onPrepared event")`)
3. Add `onError` fallback — `@Local private hasError: boolean = false;`, show thumbnail + retry icon when true
4. Test all state transitions in demo

- [ ] **Step 2: Verify compilation**
```
powershell -ExecutionPolicy Bypass -File scripts/smoke-build.ps1
```
Expected: BUILD SUCCESSFUL

- [ ] **Step 3: Commit**
```
git add entry/src/main/ets/ui/tg_ui/atoms/TgInlineVideoView.ets
git commit -m "feat: add TgInlineVideoView inline video component"
```

---

### Task 3: TgInlineVideoView demo

**Files:**
- Create: `entry/src/main/ets/ui/tg_ui/demos/TgInlineVideoViewDemo.ets`

- [ ] **Step 1: Create demo with all states**

Demo should cover:
1. Thumbnail only (no videoPath)
2. Auto-play GIF mode (autoPlay=true, loop=true, muted=true) — use any local mp4 if available
3. Manual play mode (showControls=true, autoPlay=false)
4. Circular mode (isCircular=true)
5. Parent control test — buttons that set playbackCommand to play/pause/stop

- [ ] **Step 2: Verify compilation**
```
powershell -ExecutionPolicy Bypass -File scripts/smoke-build.ps1
```

- [ ] **Step 3: Commit**
```
git add entry/src/main/ets/ui/tg_ui/demos/TgInlineVideoViewDemo.ets
git commit -m "feat: add TgInlineVideoView demo page"
```

---

## Chunk 2: TgMediaGalleryPage (Agent A — worktree)

New fullscreen media viewer. No existing files modified.

### Task 4: MediaGalleryItem model

**Files:**
- Create: `entry/src/main/ets/models/MediaGalleryItem.ets`

- [ ] **Step 1: Create model**

```typescript
export class MediaGalleryItem {
  type: string = 'photo'; // 'photo' | 'video' | 'animation' | 'videoNote'
  path: string = '';
  thumbnailPath: string = '';
  caption: string = '';
  senderName: string = '';
  timestamp: string = '';
  width: number = 0;
  height: number = 0;
  durationSec: number = 0;
  fileId: number = 0; // for download-on-demand in gallery
}
```

- [ ] **Step 2: Commit**
```
git add entry/src/main/ets/models/MediaGalleryItem.ets
git commit -m "feat: add MediaGalleryItem model"
```

---

### Task 5: TgMediaGalleryPage spec

**Files:**
- Create: `entry/src/main/ets/ui/tg_ui/spec/TgMediaGalleryPage.md`

- [ ] **Step 1: Write passport** (based on approved design spec Section 3)

- [ ] **Step 2: Commit**

---

### Task 6: TgMediaGalleryPage atom

**Files:**
- Create: `entry/src/main/ets/ui/tg_ui/atoms/TgMediaGalleryPage.ets`

- [ ] **Step 1: Create component skeleton**

Key elements:
- `@Param mediaItems: MediaGalleryItem[]`
- `@Param initialIndex: number`
- `@Event onDismiss: () => void`
- `@Event onDownloadRequest: (fileId: number) => void`
- `Swiper` with `LazyForEach` for items
- Per-item rendering: photo → `Image` with pinch/pan gestures, video → `TgInlineVideoView`
- Top bar overlay: sender + time + close button
- Bottom bar overlay: caption
- Black background, tap toggles overlay visibility
- Swipe-down dismiss gesture

**Implementation notes for agent:**
1. Use `search_harmonyos_docs("Swiper LazyForEach")` to verify Swiper + LazyForEach pattern
2. Use `search_harmonyos_docs("PinchGesture PanGesture combined")` for zoom gesture implementation
3. Photo zoom: `@Local scale: number = 1.0`, `@Local offsetX/offsetY`, `PinchGesture` updates scale (clamp 1-4), `PanGesture` updates offset when scale>1, double-tap toggles 1↔2
4. Swiper `onChange`: send playbackCommand 'stop' to prev, 'play' to current (if video)
5. `aboutToDisappear()`: stop all video instances
6. Not-downloaded items: show thumbnail + download button, fire `onDownloadRequest`

- [ ] **Step 2: Verify compilation**
```
powershell -ExecutionPolicy Bypass -File scripts/smoke-build.ps1
```

- [ ] **Step 3: Commit**
```
git add entry/src/main/ets/ui/tg_ui/atoms/TgMediaGalleryPage.ets
git commit -m "feat: add TgMediaGalleryPage fullscreen viewer"
```

---

### Task 7: TgMediaGalleryPage demo

**Files:**
- Create: `entry/src/main/ets/ui/tg_ui/demos/TgMediaGalleryPageDemo.ets`

- [ ] **Step 1: Create demo**

Demo with mock MediaGalleryItems:
1. 3 photos (use app icons as placeholders)
2. 1 video placeholder (thumbnail only, no local video)
3. Test: swipe between, pinch zoom on photo, dismiss gesture
4. Open button that shows gallery overlay

- [ ] **Step 2: Verify and commit**

---

## Chunk 3: Integration (sequential — after Agent A + B merge)

### Task 8: Merge worktrees

- [ ] **Step 1: Merge Agent A branch into dev**
- [ ] **Step 2: Merge Agent B branch into dev**
- [ ] **Step 3: Resolve any conflicts (unlikely — separate files)**
- [ ] **Step 4: Smoke build**
```
powershell -ExecutionPolicy Bypass -File scripts/smoke-build.ps1
```

---

### Task 9: Add isShortVideo to ChatTimelineVO

**Files:**
- Modify: `entry/src/main/ets/ui/pages/chat/ChatTimelineVO.ets`

- [ ] **Step 1: Add isShortVideo field to ChatMessageRowVO**

Find the class `ChatMessageRowVO` and add:
```typescript
isShortVideo: boolean = false;
```

- [ ] **Step 2: Compute isShortVideo in build function**

In the video content mapping section (where `row.videoDuration` is set), add:
```typescript
row.isShortVideo = row.videoDuration > 0 && row.videoDuration <= 30;
```

Also for animation type:
```typescript
row.isShortVideo = true; // GIFs always inline
```

- [ ] **Step 3: Smoke build and commit**

---

### Task 10: Wire TgAnimationBubble to TgInlineVideoView

**Files:**
- Modify: `entry/src/main/ets/ui/tg_ui/atoms/TgAnimationBubble.ets`

- [ ] **Step 1: Replace static Image with TgInlineVideoView**

When `hasLocalAnimation()`:
```typescript
TgInlineVideoView({
  videoPath: this.animationPath as string,
  thumbnailPath: this.thumbnailPath,
  width: this.computedMediaWidth(),
  height: this.computedMediaHeight(),
  autoPlay: true,
  loop: true,
  muted: true,
  showControls: false,
  isCircular: false,
  onTap: () => this.onAnimationTap()
})
```

When not local: keep current download overlay behavior.

- [ ] **Step 2: Add import**
```typescript
import { TgInlineVideoView } from './TgInlineVideoView';
```

- [ ] **Step 3: Smoke build and commit**

---

### Task 11: Wire TgVideoBubble inline playback

**Files:**
- Modify: `entry/src/main/ets/ui/tg_ui/atoms/TgVideoBubble.ets`

- [ ] **Step 1: Add isShortVideo param**
```typescript
@Param isShortVideo: boolean = false;
```

- [ ] **Step 2: For short local videos, render TgInlineVideoView instead of static thumbnail**

In `buildMedia()`, when `hasLocalVideo() && this.isShortVideo`:
```typescript
TgInlineVideoView({
  videoPath: this.videoPath as string,
  thumbnailPath: this.thumbnailPath,
  width: this.computedMediaWidth(),
  height: this.computedMediaHeight(),
  autoPlay: true,
  loop: false,
  muted: true,
  showControls: false,
  onTap: () => this.onVideoPlayTap()
})
```

When `hasLocalVideo() && !this.isShortVideo`: keep current thumbnail + play button behavior.

- [ ] **Step 3: Add mute/unmute icon overlay for inline short video**

Small icon (16vp) in bottom-left corner over inline video, toggles muted state on tap:
```typescript
if (this.isShortVideo && this.hasLocalVideo()) {
  Image($r('sys.media.ohos_ic_public_sound_off'))
    .width(16).height(16).fillColor('#FFFFFF')
    .position({ left: 8, bottom: 8 })
    .onClick(() => { /* toggle muted on TgInlineVideoView */ })
}
```

- [ ] **Step 4: Smoke build and commit**

---

### Task 12: Wire TgInstantVideoBubble inline playback

**Files:**
- Modify: `entry/src/main/ets/ui/tg_ui/atoms/TgInstantVideoBubble.ets`

- [ ] **Step 1: Add playback state and TgInlineVideoView**

Replace static play button with inline video when local:
```typescript
@Local private playbackState: string = 'idle'; // idle, playing, completed
@Local private playbackProgress: number = 0;
@Local private totalDuration: number = 0;
```

When `hasLocalVideo()` and `playbackState !== 'idle'`:
```typescript
TgInlineVideoView({
  videoPath: this.videoPath as string,
  thumbnailPath: this.thumbnailPath,
  width: this.bubbleSize(),
  height: this.bubbleSize(),
  autoPlay: false,
  loop: false,
  muted: false, // video notes play with sound
  isCircular: true,
  playbackCommand: this.playbackState === 'playing' ? 'play' : 'none',
  onTap: () => { /* playing → gallery */ },
  onPlaybackEnd: () => { this.playbackState = 'completed'; },
  onProgressUpdate: (cur: number, total: number) => {
    this.totalDuration = total;
    this.playbackProgress = total > 0 ? cur / total : 0;
  }
})
```

- [ ] **Step 2: Draw playback progress ring using this.playbackProgress**

White ring around perimeter (reuse existing `buildRadialProgress` pattern but with playback data).

- [ ] **Step 3: Implement tap state machine**

```
idle → tap → set playbackState = 'playing'
playing → tap → fire onTap() (opens gallery)
completed → tap → set playbackState = 'playing' (replay)
```

- [ ] **Step 4: Smoke build and commit**

---

### Task 13: Wire TgMessageRouter

**Files:**
- Modify: `entry/src/main/ets/ui/tg_ui/molecules/TgMessageRouter.ets`

- [ ] **Step 1: Add new params/events**
```typescript
@Param isShortVideo: boolean = false;
@Event onMediaGalleryOpen: (messageId: string) => void = (_: string) => {};
```

- [ ] **Step 2: Pass isShortVideo to TgVideoBubble**

In video branch, add `isShortVideo: this.isShortVideo`.

- [ ] **Step 3: Route all visual media taps through onMediaGalleryOpen**

Replace:
- photo `onPhotoTap` → `onMediaGalleryOpen(this.messageId)`
- video `onVideoPlayTap` → `onMediaGalleryOpen(this.messageId)`
- animation `onAnimationTap` → `onMediaGalleryOpen(this.messageId)`

Keep existing events as fallback for non-gallery paths.

- [ ] **Step 4: Smoke build and commit**

---

### Task 13.5: Verify photo/grouped bubble tap routing

**Files:**
- Review: `entry/src/main/ets/ui/tg_ui/atoms/TgPhotoBubble.ets`
- Review: `entry/src/main/ets/ui/tg_ui/atoms/TgGroupedPhotoBubble.ets`

- [ ] **Step 1: Verify TgPhotoBubble tap goes through router**

TgPhotoBubble's `handleSurfaceTap()` calls `this.onPhotoTap()` which is wired in router to `this.onPhotoTap()`. In Task 13 we remap this to `onMediaGalleryOpen`. Confirm no direct viewer opening in the atom itself.

- [ ] **Step 2: Verify TgGroupedPhotoBubble tap goes through router**

TgGroupedPhotoBubble's `onPhotoTap(photoPath)` is wired in router to `this.onAlbumPhotoTap(photoPath, caption)`. This needs to be remapped to `onMediaGalleryOpen` with the correct index. Add to Task 13: remap album photo tap to find the correct gallery index by matching photoPath against gallery items.

- [ ] **Step 3: Commit if any changes needed**

---

### Task 14: Wire TgChatScreenPage — Gallery + Viewport Lifecycle

**Files:**
- Modify: `entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets`

- [ ] **Step 1: Add gallery state**
```typescript
@State private showMediaGallery: boolean = false;
@State private galleryItems: MediaGalleryItem[] = [];
@State private galleryInitialIndex: number = 0;
```

- [ ] **Step 2: Build buildMediaGalleryItems() method**

Filter timeline entries for visual media types, map to MediaGalleryItem[]:
```typescript
private buildMediaGalleryItems(): MediaGalleryItem[] {
  const items: MediaGalleryItem[] = [];
  const entries = this.dataSource.getAllEntries();
  for (const entry of entries) {
    if (entry.kind !== 'message') continue;
    const ct = entry.message.contentType;
    if (ct === 'photo' || ct === 'video' || ct === 'animation' || ct === 'videoNote') {
      const item = new MediaGalleryItem();
      item.type = ct;
      item.path = ct === 'photo' ? entry.message.photoPath : entry.message.videoPath;
      item.thumbnailPath = ct === 'photo' ? entry.message.photoPath : entry.message.videoThumbPath;
      item.caption = entry.message.caption;
      item.senderName = entry.message.senderName;
      item.timestamp = entry.message.timeText;
      item.width = ct === 'photo' ? entry.message.photoWidth : entry.message.videoWidth;
      item.height = ct === 'photo' ? entry.message.photoHeight : entry.message.videoHeight;
      item.durationSec = entry.message.videoDuration;
      item.fileId = ct === 'photo' ? entry.message.photoFileId : entry.message.videoFileId;
      items.push(item);
    }
  }
  return items;
}
```

- [ ] **Step 3: Handle onMediaGalleryOpen**

Find the media message's index in gallery items and open gallery:
```typescript
private handleMediaGalleryOpen(messageId: string): void {
  const items = this.buildMediaGalleryItems();
  let index = 0;
  // Find matching item
  const entries = this.dataSource.getAllEntries();
  let mediaIndex = 0;
  for (const entry of entries) {
    if (entry.kind !== 'message') continue;
    const ct = entry.message.contentType;
    if (ct === 'photo' || ct === 'video' || ct === 'animation' || ct === 'videoNote') {
      if (entry.message.messageId === messageId) {
        index = mediaIndex;
        break;
      }
      mediaIndex++;
    }
  }
  this.galleryItems = items;
  this.galleryInitialIndex = index;
  this.showMediaGallery = true;
}
```

- [ ] **Step 4: Add TgMediaGalleryPage overlay in build()**

In the root Stack, after existing overlays:
```typescript
if (this.showMediaGallery) {
  TgMediaGalleryPage({
    mediaItems: this.galleryItems,
    initialIndex: this.galleryInitialIndex,
    onDismiss: () => { this.showMediaGallery = false; },
    onDownloadRequest: (fileId: number) => {
      this.requestMediaDownload(fileId);
    }
  })
}
```

- [ ] **Step 5: Pass isShortVideo and onMediaGalleryOpen to router**

In `buildMessageItem`, add:
```typescript
isShortVideo: entry.message.isShortVideo,
onMediaGalleryOpen: (messageId: string): void => {
  this.handleMediaGalleryOpen(messageId);
},
```

- [ ] **Step 6: Implement viewport video lifecycle (max 3 concurrent)**

Add `onVisibleAreaChange` to message ListItems that contain inline video (video/animation/videoNote):
```typescript
.onVisibleAreaChange([0.0, 0.5], (isVisible: boolean, currentRatio: number) => {
  // Track active video count, send playbackCommand='stop' when >3
})
```

Track active inline video message IDs in a Set. When a new video enters viewport and count > 3, stop the oldest non-playing one. When a video exits viewport (ratio → 0.0), remove from active set.

- [ ] **Step 7: Remove old TgPhotoViewerPage and TgVideoPlayerPage overlays**

Delete the `buildPhotoViewer()` and `buildVideoPlayer()` builders and their state variables (`viewerPhotoPath`, `viewerPhotoPaths`, `viewerPhotoInitialIndex`, `viewerPhotoCaption`, `showVideoPlayer`, `viewerVideoPath`, `viewerVideoCaption`, `viewerVideoThumbPath`, etc.).

Delete files:
- `entry/src/main/ets/ui/pages/chat/TgPhotoViewerPage.ets`
- `entry/src/main/ets/ui/pages/chat/TgVideoPlayerPage.ets`

- [ ] **Step 8: Smoke build**
```
powershell -ExecutionPolicy Bypass -File scripts/smoke-build.ps1
```

- [ ] **Step 9: Commit**
```
git commit -m "feat: wire media gallery + inline video into chat screen"
```

---

### Task 15: Update project docs

**Files:**
- Modify: `STATUS.md`
- Modify: `TASKS/TODO.md`
- Modify: `TASKS/LESSONS.md`

- [ ] **Step 1: Update STATUS.md** with Phase 1 completion
- [ ] **Step 2: Add verification items to TODO.md**
- [ ] **Step 3: Add lessons learned**
- [ ] **Step 4: Commit**

---

## Verification Checklist

After all tasks complete, verify on device (Clean Build!):

1. [ ] Photo tap → gallery opens, pinch zoom works (1x-4x), double-tap toggle
2. [ ] Swipe between photos in gallery
3. [ ] Gallery swipe-down dismiss
4. [ ] Short video (≤30s) auto-plays muted inline in bubble
5. [ ] Short video tap → gallery with sound
6. [ ] Long video shows thumbnail + play button, tap → gallery
7. [ ] GIF auto-plays looping muted in bubble
8. [ ] Video note tap → plays inline in circle with progress ring
9. [ ] Video note second tap → gallery fullscreen
10. [ ] Album cell tap → gallery at correct index
11. [ ] Gallery shows download button for not-yet-downloaded media
12. [ ] Max 3 inline videos — no crash on media-heavy chats
13. [ ] No regression in download/progress indicator states
14. [ ] Swipe between mixed media types in gallery (photo→video→GIF)
15. [ ] All existing chat functionality unchanged (text, voice, audio, document)

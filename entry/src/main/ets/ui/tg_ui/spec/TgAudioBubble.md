# TgAudioBubble Component Passport

## Goal
Telegram-style audio/music bubble with iOS-aligned art tile + seek bar layout.

UI-only scope:
- **Art tile** (44vp, radius 12) as leading visual anchor — gradient bg + music note / play / pause / progress states
- **Seek bar** for playback progress (thin horizontal bar, iOS `ChatMessageInteractiveFileNode` pattern)
- title + performer + duration/size meta stack
- determinate/indeterminate transfer states on the art tile
- download/open tap contract remains page-owned

## References

### Telegram iOS
- `submodules/TelegramUI/Components/Chat/ChatMessageInteractiveFileNode/Sources/ChatMessageInteractiveFileNode.swift`
  - `progressDiameter = 44.0` — art tile is the dominant visual anchor
  - Album art thumbnail shown when available; gradient + music note otherwise
  - Seek bar appears below performer, shows playback progress
  - title and description stacked to the right of the art tile
- `submodules/TelegramUI/Components/Chat/ChatMessageItemView/Sources/ChatMessageItemView.swift`
  - music messages are treated as a separate category from voice and documents

### Telegram Android
- `TMessagesProj/src/main/java/org/telegram/ui/Cells/AudioPlayerCell.java`
  - `RadialProgress2` on the art tile
  - Seek bar height ~30dp
  - title / author text stack sits to the right

### HarmonyOS
- ArkUI `Progress({ type: ProgressType.Ring })` for ring progress on art tile
- `linearGradient` for gradient art tile background

## Props / Inputs
- `title`
- `performer`
- `durationSec`
- `fileSize`
- `mimeType`
- `audioPath`
- `isDownloading`
- `downloadProgress`
- `isOutgoing`
- `isPlaying`
- `playbackProgress`
- `containerWidth`
- `maxWidthRatio`
- `noBubbleWrap`
- `onTap()`

## State Matrix
- idle (not downloaded) — music note icon on gradient art tile
- downloaded, not playing — play icon on art tile
- downloaded, playing — pause icon on art tile + seek bar filled
- determinate download — `downloadProgress` in `0..1` is treated as active even if `isDownloading` is false; ring progress + close/cancel icon on art tile + download progress bar
- indeterminate download — spinner on art tile
- incoming / outgoing color variants
- long title / missing performer fallback

## Layout Rules
1. Leading element is a **44vp square art tile** (radius 12) with gradient bg.
2. Art tile shows: music note or download affordance (remote idle) / play (downloaded) / pause (playing) / ring + project close icon (determinate transfer) / spinner + project close icon (indeterminate transfer).
3. Text stack: title (2 lines max) → performer (1 line) → seek bar → duration/size meta.
4. **Seek bar**: thin 3vp horizontal bar below performer, filled by `playbackProgress`.
5. During download, seek bar is replaced by download progress bar.
6. Bubble width follows chat lane constraints via `resolveAudioBubbleWidth()`.
7. Download/open behavior stays outside the atom; the atom only emits `onTap`.

## Token Mapping
- `AUDIO_BUBBLE_ART_SIZE`, `AUDIO_BUBBLE_ART_RADIUS`, `AUDIO_BUBBLE_ART_ICON_SIZE`
- `AUDIO_BUBBLE_ART_GRADIENT_START`, `AUDIO_BUBBLE_ART_GRADIENT_END`
- `AUDIO_BUBBLE_ART_ICON` (white icon on gradient)
- `AUDIO_BUBBLE_SEEK_HEIGHT`, `AUDIO_BUBBLE_SEEK_RADIUS`, `AUDIO_BUBBLE_SEEK_TOP_GAP`
- `AUDIO_BUBBLE_SEEK_BG`, `AUDIO_BUBBLE_SEEK_FILL`
- `AUDIO_BUBBLE_TITLE_SIZE`, `AUDIO_BUBBLE_META_SIZE`, `AUDIO_BUBBLE_BOTTOM_META_SIZE`
- `ICON_RES_MUSIC`, `ICON_RES_PLAY`, `ICON_RES_PAUSE`, `ICON_RES_DOWNLOAD`, `ICON_RES_CLOSE`
- `MEDIA_PROGRESS_COLOR`, `MEDIA_CANCEL_ICON_SIZE`, `MEDIA_PROGRESS_STROKE`

## Acceptance Checklist
- [ ] Art tile is visually distinct from document tile — gradient + music note
- [ ] Play/pause states shown on art tile overlay
- [ ] Ring progress renders on art tile during determinate download
- [ ] Determinate `downloadProgress` alone renders as active transfer and cancels through the router
- [ ] Transfer cancel icon uses project `TgIcon(ICON_RES_CLOSE)`, not a system media asset
- [ ] Seek bar shows playback progress when playing
- [ ] Seek bar replaced by download bar during active download
- [ ] Duration + file size meta reads correctly
- [ ] Long titles ellipsize cleanly on 2 lines
- [ ] Missing performer falls back to mimeType or "Audio"
- [ ] Incoming/outgoing bubble colors stay aligned
- [ ] Page-owned tap contract works for download and open

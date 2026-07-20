# TgVoiceBubble (Phase C.1 / Step 4)

## Goal
Implement Telegram-style voice-note bubble atom:
- leading play/pause control
- remote/download transfer control
- waveform visualization
- trailing duration text

UI-only scope for this step. No real playback/seek engine integration; download/cancel behavior remains parent/router-owned.

## iOS References
- `submodules/TelegramUI/Components/Chat/ChatMessageFileBubbleContentNode/Sources/ChatMessageFileBubbleContentNode.swift`
  - voice/file bubble placement inside chat bubble content pipeline
- `submodules/TelegramUI/Components/Chat/ChatMessageInteractiveFileNode/Sources/ChatMessageInteractiveFileNode.swift`
  - voice waveform/scrubbing region and duration/status composition
- `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Sources/ChatMessageItemCommon.swift`
  - message bubble/file inset contracts for sizing rhythm

## Props / Inputs
- `durationSec: number`
- `waveform: string`
- `isOutgoing: boolean`
- `isPlaying: boolean`
- `playbackProgress: number` (`0..1`)
- `isListened: boolean`
- `hasLocalFile: boolean`
- `isDownloading: boolean`
- `downloadProgress: number` (`-1` for indeterminate / inactive, `0..1` for determinate transfer)
- `containerWidth: number`
- `maxWidthRatio: number`

## State Matrix (demo)
- incoming fresh vs listened
- paused vs playing
- different progress values
- outgoing/incoming
- fallback waveform when waveform string is empty
- narrow container stress
- remote voice (download icon)
- determinate transfer from `downloadProgress` even when `isDownloading` is false
- indeterminate transfer with cancel affordance

## Layout Rules
1) Bubble aligns by direction (incoming left, outgoing right).
2) Fixed play/pause circular control on leading side.
3) Waveform renders in the top `18vp` lane after the `44vp` control.
4) Duration sits below the waveform on the same leading edge, not in a trailing
   third column; this mirrors iOS `scrubbingFrame(x:57,y:1,h:18)` and
   `descriptionFrame(x:56,y:22)` and lets short voice notes keep the `120vp`
   duration-scaled width floor.
5) The voice content lane has no extra vertical padding around its `44vp`
   control. Message status overlaps the lane by `5vp`: iOS starts its `44pt`
   progress frame at `y=-3`, shifts the status reference by `+8`, then applies
   `statusOffset=-10`, which puts status at `y=39`. This avoids stacking a full
   independent metadata row while keeping duration and status baselines apart.
6) Played progress is reflected via active/inactive waveform bar colors.
7) Transfer state is active when `isDownloading` is true or `downloadProgress` is in `0..1`; the leading control renders progress/spinner plus project-owned close icon.
8) Waveform scrubbing/progress color is disabled while the file is remote or transferring.
9) All visuals are tokenized.

## Token Mapping
- Colors:
  - `VOICE_BUBBLE_BUTTON_BG/ICON_INCOMING/OUTGOING`
  - incoming control keeps Telegram accent + white glyph;
    outgoing control uses outgoing primary as its fill and the qualified bubble
    fill for its glyph/ring, matching iOS `mediaActiveControlColor` plus the
    transparent cut-out foreground of `SemanticStatusNode`
  - `VOICE_BUBBLE_WAVE_ACTIVE/INACTIVE`
  - `VOICE_BUBBLE_DURATION_INCOMING/OUTGOING`
  - outgoing inactive waveform resolves the qualified
    `app.color.message_meta_outgoing` resource into the numeric Canvas color;
    Telegram iOS maps `mediaInactiveControlColor` to outgoing secondary text,
    while active playback remains outgoing primary/white
  - outgoing duration consumes the same qualified
    `app.color.message_meta_outgoing` semantic as outgoing message time;
    Telegram iOS maps `fileDurationColor` to outgoing secondary text
  - `MEDIA_PROGRESS_COLOR`
- Geometry/Typography:
  - `VOICE_BUBBLE_RADIUS`
  - `VOICE_BUBBLE_MIN_WIDTH/MAX_WIDTH`
  - `VOICE_BUBBLE_PADDING_H/PADDING_V`
  - `VOICE_BUBBLE_CONTENT_GAP`
  - `VOICE_BUBBLE_BUTTON_SIZE/BUTTON_ICON_SIZE`
  - `VOICE_BUBBLE_WAVE_BARS_COUNT`
  - `VOICE_BUBBLE_WAVE_BAR_WIDTH/BAR_GAP`
  - `VOICE_BUBBLE_WAVE_MIN_HEIGHT/MAX_HEIGHT/WAVE_AREA_HEIGHT`
  - `VOICE_BUBBLE_WAVE_DURATION_GAP`
  - `VOICE_BUBBLE_DURATION_SIZE/LINE_HEIGHT`
  - `VOICE_BUBBLE_STATUS_OVERLAP/STATUS_BOTTOM_INSET`
  - `MEDIA_CANCEL_ICON_SIZE`, `MEDIA_PROGRESS_STROKE`
- Icons:
  - `ICON_RES_PLAY`, `ICON_RES_PAUSE`, `ICON_RES_DOWNLOAD`, `ICON_RES_CLOSE`

## Acceptance Checklist
- [ ] Play/pause control remains stable across states
- [ ] Remote state shows download affordance, not play/pause
- [ ] Determinate `downloadProgress` alone renders an active cancel/progress control
- [ ] Indeterminate transfer shows spinner + project close icon
- [ ] Waveform bars render consistently and respect progress coloring
- [ ] Duration text is readable and aligned
- [ ] Narrow container keeps geometry without overflow
- [ ] No hardcoded visual constants in atom

## Demo Requirements (`TgVoiceBubbleDemo.ets`)
At least 7 cases:
1) incoming fresh
2) incoming playing
3) incoming listened/complete
4) outgoing paused
5) outgoing playing
6) fallback waveform
7) narrow container stress
8) remote download
9) determinate transfer from progress-only state
10) indeterminate transfer/cancel

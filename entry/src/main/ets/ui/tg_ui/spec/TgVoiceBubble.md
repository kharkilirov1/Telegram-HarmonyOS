# TgVoiceBubble (Phase C.1 / Step 4)

## Goal
Implement Telegram-style voice-note bubble atom:
- leading play/pause control
- waveform visualization
- trailing duration text

UI-only scope for this step. No real playback/seek engine integration.

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
- `containerWidth: number`
- `maxWidthRatio: number`

## State Matrix (demo)
- incoming fresh vs listened
- paused vs playing
- different progress values
- outgoing/incoming
- fallback waveform when waveform string is empty
- narrow container stress

## Layout Rules
1) Bubble aligns by direction (incoming left, outgoing right).
2) Fixed play/pause circular control on leading side.
3) Waveform rendered as tokenized bars in a center flexible area.
4) Duration text anchored at trailing side.
5) Played progress is reflected via active/inactive waveform bar colors.
6) All visuals are tokenized.

## Token Mapping
- Colors:
  - `VOICE_BUBBLE_BUTTON_BG/ICON`
  - `VOICE_BUBBLE_WAVE_ACTIVE/INACTIVE`
  - `VOICE_BUBBLE_DURATION_INCOMING/OUTGOING`
- Geometry/Typography:
  - `VOICE_BUBBLE_RADIUS`
  - `VOICE_BUBBLE_MIN_WIDTH/MAX_WIDTH`
  - `VOICE_BUBBLE_PADDING_H/PADDING_V`
  - `VOICE_BUBBLE_CONTENT_GAP`
  - `VOICE_BUBBLE_BUTTON_SIZE/BUTTON_ICON_SIZE`
  - `VOICE_BUBBLE_WAVE_BARS_COUNT`
  - `VOICE_BUBBLE_WAVE_BAR_WIDTH/BAR_GAP`
  - `VOICE_BUBBLE_WAVE_MIN_HEIGHT/MAX_HEIGHT/WAVE_AREA_HEIGHT`
  - `VOICE_BUBBLE_DURATION_SIZE/LINE_HEIGHT`

## Acceptance Checklist
- [ ] Play/pause control remains stable across states
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

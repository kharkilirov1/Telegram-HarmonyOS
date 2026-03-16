# Media Bubbles Improvement Plan (Voice, Audio, Document)

**Status:** Draft / Pending Approval  
**Goal:** Bring `TgVoiceBubble`, `TgAudioBubble`, and `TgDocumentRow` to high-fidelity iOS parity in ArkUI.

## Phase 1: Interaction & Event Isolation
**Objective:** Fix "blind" global taps and separate interactive elements from the bubble body.
- **Voice & Audio:** Add `@Event onPlayToggle: () => void`. 
- **Document:** Add `@Event onDownloadToggle: () => void`.
- **Implementation:** Stop event propagation (`event.stopPropagation()`) on the Play/Pause and Download buttons so they don't trigger the bubble's global `onTap` (which is meant for selection/context menu).

## Phase 2: Playback & Scrubbing
**Objective:** Allow users to seek through audio and voice messages.
- **Audio:** Replace the static dual-`Row` progress bar in `TgAudioBubble` with an interactive ArkUI `Slider` (styled to match iOS, with a visible thumb).
- **Voice:** Add `PanGesture` to the waveform area in `TgVoiceBubble` to calculate and emit `@Event onSeek: (progress: number) => void`.

## Phase 3: Visual Polish & Waveform Rendering
**Objective:** Fix the choppy voice waveform and align bubble geometry with iOS.
- **Waveform (`TgVoiceBubble`):** Replace the array of `Row` elements with a custom `Canvas` or `Path` component. Draw the waveform as a single mask, allowing pixel-perfect color splitting for the `playbackProgress` (unplayed vs played colors).
- **Metadata:** Integrate the transcription button ("→A") layout space and properly align the duration/seen indicator (blue dot/ticks).
- **Adaptive Bubbles:** Refactor `TgMessageBubbleBase` to support `top/bottom/both/none` grouping flags to render adaptive corner radii (e.g., 6pt inner corners) and the message tail (CGPath equivalent).

## Phase 4: Document States & Thumbnails
**Objective:** Match iOS file states and visual richness.
- **States:** Implement distinct UI states for `TgDocumentRow`: Idle (Download icon), Downloading (Ring progress + Cancel cross), Downloaded (File icon or Thumbnail).
- **Thumbnails:** Add support for rendering image/PDF thumbnails instead of the generic file icon when `documentPath` points to a supported local media file.

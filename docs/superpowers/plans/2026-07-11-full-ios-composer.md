# Full iOS Composer Implementation Plan

**Goal:** Finish the planned iOS composer parity slice without replacing the
custom Telegram atom or rewriting unrelated chat behavior.

## Task 1 — Pure contracts and RED tests

- Add `TgVoiceRecordingPolicy` with states, gesture resolution, duration
  formatting and the 500ms minimum-duration rule.
- Add Hypium tests before implementation.
- Extend media command tests with `mediaKind='voice'`, duration and empty
  waveform serialization to exact `inputMessageVoiceNote` JSON.

## Task 2 — TDLib voice send path

- Extend `SendMediaMessagePayload`, params and serializer with duration and
  waveform fields.
- Keep photo/video/document output byte-for-byte compatible.
- Validate voice duration and accept only the existing supported media kinds
  plus `voice`.

## Task 3 — Recorder lifecycle

- Add `ChatVoiceRecordingController`.
- Request `ohos.permission.MICROPHONE` on first hold.
- Record mono AAC/M4A through `AVRecorder` into the application files dir.
- Implement prepare/start/stop/release/fd-close/delete and lifecycle guards.
- Send through the existing injected `SendMediaMessageUseCase`.

## Task 4 — iOS recording UI and gestures

- Add reactive recording props/events to `TgComposerInput`.
- Bind long-press plus pan to start/cancel/lock/send.
- Render recording, locked and sending states using existing/native material
  policy and new tokens only.
- Preserve all existing normal/reply/edit/forward/attachment/multiline states.

## Task 5 — Camera and bot Menu

- Add CameraPicker to the existing attachment action menu.
- Persist `User.isBot` from TDLib user type.
- Add `loadBotMenuInfo` for real bot menu title/commands.
- Render leading Menu pill only for an actual private bot chat and send selected
  commands through the current text use case.

## Task 6 — Verification and evidence

- Run source contract, focused Hypium compile, PowerShell/Bash smoke, root-tab
  geometry and clean target-26 build.
- Install entry HAP only, prove fresh process and capture API23 runtime states.
- Update `STATUS.md`, `TASKS/TODO.md`, `TASKS/LESSONS.md` with only witnessed
  outcomes and remaining hardware/API26 boundary.


# STATUS — Telegram-HarmonyOS

Snapshot date: 2026-05-18

## Current State

- **Branch:** `dev`
- **Phase:** Phase 2 — Consolidate current working batch (per `TASKS/AGENT_EXECUTION_PLAN.md`)
- **Build:** `scripts/smoke-build.ps1` — green
- **Smoke:** `scripts/smoke-ui-phase0.ps1` — green; `bash ./scripts/smoke-ui-phase0.sh` — green
- **Warnings:** unverified `libtdlib_napi.so`, missing signing config
- **Device/emulator verification:** not performed

## Architecture

```
TDLib (C++ NAPI) → TdGateway → MainThreadDispatcher → EventNormalizer → AppStore → AppStoreBridge → UI
```

- Clean Architecture + Redux-like store (serial dispatch, reducer-driven)
- UI: `@ComponentV2` decorators, token-first via `TgUiTokens.ets`
- Root shell: API23 `HdsTabs` + `HdsNavigation` (D14)
- 35 tg_ui atoms, 2 molecules, specs + demos for each

## Recent Changes (2026-05-03 consolidated batch)

### Chat-list polish
- Unread counters: Telegram-style compact `K`/`M` instead of `99+`
- Unread badge: custom Row/Text capsule replacing stock ArkUI `Badge`

### Composer
- Emoji quick panel (`TgComposerEmojiPanel`)
- Attachment picker: real `PhotoViewPicker` / `DocumentViewPicker`
- Send-media: TDLib `sendMessage` with `inputFileLocal` for photo/video/document
- Reply/edit/forward accessory panels embedded inside text capsule
- iOS-correct docking: send action inside capsule, idle mic outside

### Media bubbles
- Download/cancel path: real `cancelDownloadFile` command
- Status controls: photo, video, animation, instant-video, audio, voice — all have correct remote/fetching/local state machines
- Transfer progress: determinate ring, indeterminate spinner, project-owned close icons
- Gallery: transfer/loading states, download/cancel, empty fallback
- Document row: status control correction

### Bubble layout
- Live grouping corners: `top` / `middle` / `bottom` / `none` from consecutive-message spacing
- Rich text entities: bold, italic, code, links, mentions in text bubbles

### Tests
- New: `AppStateModels` (124), `TextEngine` (64), `ChatTimelineVO` (42), `MessagesReducer` (15), `StateClone` (17), `ChatCommands`, `FilePipeline`, `LoadCalls`, `MessageDtoParser`, `UserDto`, `AppError`
- 16 deleted legacy tests (old services/controllers — replaced by new domain-focused tests)

### tg_ui coverage
- New specs: `TgPollBubble`, `TgContactBubble`, `TgLocationBubble`, `TgMediaGalleryPage`, `TgComposerEmojiPanel`
- New demos: corresponding demos for all above + `TgTextBubbleV3` parent-demo with rich entities
- Removed: `TgFilterBar`, `TgSearchBar`, `TgTextBubbleV2`, `TgTabBar` (specs + atoms)

### Review-driven cleanup (2026-05-18)
- `TdGateway.ets`: replaced `getMethodTimeout()` if/else chain with `Record<string, number>` map lookup
- Removed noise files: heartbeat scripts, runtime-sweep scripts, `index.html`, `codegenie-cpl-mcp.json`, `HARMONY_DEV_TOOL_SPEC.md`, `TASKS/runtime-sweeps/`
- Trimmed `STATUS.md` from 1220+ lines to ~80 lines

## Known Issues

- `TgChatScreenPage.ets` — 3094 lines, needs decomposition (Phase 3+)
- `CommandSerializer.ets` — ~600 lines, manual serialization per message type
- 0 tests on `TdGateway`, `EventNormalizer`, `AuthSideEffect`, use cases
- Selectors without memoization (no reselect pattern)

## Working Tree

- ~80 modified tracked files
- ~16 deleted tracked files
- ~25 untracked files (new features, tests, specs, demos)
- Untracked features: `sendMediaMessage.ets`, `PendingForwardTransfer.ets`, `TgForwardTargetPickerPage.ets`

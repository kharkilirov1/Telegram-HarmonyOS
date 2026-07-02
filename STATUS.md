# STATUS — Telegram-HarmonyOS

Snapshot date: 2026-07-02

## Current State

- **Branch:** `dev`
- **Phase:** R1 — MVP-стабилизация (Release Track v2 per `TASKS/AGENT_EXECUTION_PLAN.md`); R0 завершён 2026-07-02
- **Direction:** минимальный релизный клиент v0.1.0 (MVP-чеклист в плане) → фичи маленькими обновлениями v0.x; ширина роадмапа больше не цель
- **Last committed baseline:** `eb81eca fix: keep main thread responsive during tdlib batch storms` (P0 cold-start freeze, P1 pagination edge-lock, P2 default tab — эмуляторные witness в TODO)
- **Current follow-up:** Media download behavior now covers user intent continuation, failed-download retry state, open gallery refresh, and a startup AppFreeze mitigation for background media auto-downloads
- **Build:** `scripts/smoke-build.ps1` — green (re-run 2026-07-02 with the `DownloadMessageMediaUseCase` throttling patch in tree)
- **Smoke:** `scripts/smoke-ui-phase0.ps1` — green (re-run 2026-07-02); `bash ./scripts/smoke-ui-phase0.sh` — green on last run 2026-05-19
- **Warnings:** unverified `libtdlib_napi.so`, missing signing config
- **Device/emulator verification:** blocked locally (`hdc list targets` = `[Empty]`, `signingConfigs` empty)

## Architecture

```text
TDLib (C++ NAPI) → TdGateway → MainThreadDispatcher → EventNormalizer → AppStore → AppStoreBridge → UI
```

- Clean Architecture + Redux-like store (serial dispatch, reducer-driven)
- UI: `@ComponentV2` decorators, token-first via `TgUiTokens.ets`
- Root shell: API23 `HdsTabs` + `HdsNavigation` (D14)
- Chat-list unread badge is now a project-owned inline `TgChatMeta` capsule, not a standalone `TgUnreadBadge` atom

## Recent Changes (2026-05-19 current follow-up)

### Media behavior runtime
- Added `PendingMediaOpenIntent.ets` to track tap intent for unloaded document/audio/voice media across `downloadFile` progress updates
- `TgChatScreenPage` now resolves the pending intent after timeline rebuild and opens documents or starts inline audio/voice playback when file paths arrive
- Cancel/clear paths now reset the pending media open intent so stale downloads cannot auto-open after navigation/cancel
- Added `ChatTimelineVO.test.ets` coverage for pending media open resolution, stale chat/lifecycle guards, and document/audio/voice paths
- `ChatMediaDownloadController` now tracks failed on-demand downloads, exposes retry-capable status, and clears failure on retry/cancel/resolved file paths
- Media bubble params now receive failed-download booleans; document/audio/voice rows expose non-polished retry status text while visual media keeps the retry download affordance
- Open `TgMediaGalleryPage` state now receives refreshed media items after timeline file-path updates, preserving the currently viewed item and clearing local pending download affordances once the file path arrives
- Gallery items now carry failed-download state for photo/video/album entries, and `ChatMediaDownloadController.syncResolvedDownloads()` clears photo/album failures when local media appears
- Added `ChatTimelineVO.test.ets` coverage for gallery refresh state preservation and `FilePipeline.test.ets` coverage for failed-download status, resolved-path cleanup, photo/album cleanup, and reset cleanup
- Device AppFreeze capture `appfreeze-com.telegram.harmonyos-20260520025805.425.txt` showed `THREAD_BLOCK_6S` during cold start while TDLib delivered many 50-response batches and `DownloadMedia` repeatedly enqueued background downloads on the main thread
- `DownloadMessageMediaUseCase` now defers/throttles scans, caps background auto-download enqueues per scan, and stops startup full-photo auto-download; full photo/video/document/audio remain explicit tap/download flows

## Recent Changes (2026-05-18 calls follow-up)

### Calls real data flow
- `searchCallMessages` now follows the local TDLib `td_api.tl` contract: request `offset:string`, response `FoundMessages.next_offset:string`
- `LoadCallsUseCase` and `CallsPage` use opaque offset pagination instead of chat-history-style `from_message_id`
- `LoadCalls.test.ets` now covers parser behavior for real `foundMessages`, missed/outgoing mapping, `next_offset`, and direct `chat`/`user` hydration
- `CommandSerializer.test.ets` now covers the `searchCallMessages` serializer path

## Recent Changes (2026-05-18 consolidated batch)

### Runtime / gateway
- `TdGateway.ets`: `getMethodTimeout()` uses `Record<string, number>` map lookup
- `CommandSerializer.ets`: switched from one large `switch` to command-type dispatch handlers
- Gateway cleanup hardened for initialize failure and shutdown races
- Dispatcher stats now include dropped/handler-error counts

### Composer / media
- Emoji quick panel (`TgComposerEmojiPanel`)
- Attachment picker: real `PhotoViewPicker` / `DocumentViewPicker`
- Send-media: TDLib `sendMessage` with `inputFileLocal` for photo/video/document
- Download/cancel path: real `downloadFile` / `cancelDownloadFile` commands
- `ChatMediaDownloadController.ets` extracted from `TgChatScreenPage` and now reads direct TDLib `file` responses through `TdObject` accessors
- `ChatComposerController.ets` extracted composer send/edit/forward handoff, emoji panel, attachment picker, and picked-file preparation
- `ChatMessageActionsController.ets` extracted reply/edit/copy/forward/pin/delete action menu and action-mode orchestration
- `ChatScreenRouteParams.ets` now owns chat route params shared by page/actions controller
- `ChatSearchController.ets` extracted debounced in-chat search and result navigation

### Chat UI
- Unread counters: Telegram-style compact `K`/`M` instead of `99+`
- Unread badge: custom Row/Text capsule inside `TgChatMeta`, replacing stock ArkUI `Badge` and removed standalone `TgUnreadBadge`
- Root shell uses API23 `HdsTabs` / `HdsNavigation`; old custom `TgTabBar` is not the active shell
- Removed active standalone atoms/demos for obsolete wrappers: `TgFilterBar`, `TgSearchBar`, `TgTextBubbleV2`, `TgTabBar`, `TgUnreadBadge`
- Active rich text path is `TgTextBubbleV3` / `TgTextBodyV3`

### Tests
- New/active: `TdGateway`, `EventNormalizer`, `CommandSerializer`, `UseCases`, `AuthSideEffect`, `AppStateModels`, `TextEngine`, `ChatTimelineVO`, `MessagesReducer`, `StateClone`, `ChatCommands`, `FilePipeline`, `LoadCalls`, `MessageDtoParser`, `UserDto`, `AppError`
- Deleted legacy service/controller tests that no longer match current architecture

### Performance / cleanup
- Memoized selectors: `selectOrderedChats`, `selectPinnedChats`, `selectUnpinnedChats`, `selectTotalUnreadCount`
- Removed noise files and trimmed oversized working docs
- `chatSelectors.ets` line endings normalized after review

## Known Issues

- `TgChatScreenPage.ets` still owns timeline/playback/safe-area coordination; composer, message actions, and search are now extracted
- Calls page data flow is build-verified against TDLib API shape, but real account/device runtime still needs signed device/emulator verification
- Tests now cover basic `AuthSideEffect` singleton/store seam and common use-case validation/dispatch; deeper side-effect runtime tests still need device/integration seam
- `libtdlib_napi.so` is externally built and not verified by current CI/smoke boundary
- Device/emulator runtime behavior still requires a signed deployment pass; local check found no hdc target and no signing config
- Startup AppFreeze should be re-tested on emulator/device with fresh faultlogger capture after `DownloadMessageMediaUseCase` throttling (per docs, AppFreeze detection applies to release-version apps — match the original capture's build type)
- `DownloadMessageMediaUseCase` throttle/budget logic has no unit test; scan still iterates the full messages map per pass (budget caps enqueues, not iteration)

## Emulator loop (unlocked 2026-07-02)

- Эмулятор стартует из CLI: `"C:\Program Files\Huawei\DevEco Studio\tools\emulator\Emulator.exe" -start "Pura 90 Pro Max"` (инстансы зарегистрированы, imageRoot берётся из реестра)
- hdc: использовать SDK-бинарь `DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe`; таргет `127.0.0.1:5555`
- **Unsigned HAP устанавливается на эмулятор** (`hdc install -r entry-default-unsigned.hap`) — подпись нужна только для реального устройства (R2)
- Git Bash: для device-путей обязателен `MSYS_NO_PATHCONV=1`; `file recv` — с относительным путём из целевой папки
- Telegram-сессия на эмуляторе жива (userdata сохраняется между запусками)

## Working Tree

- Throttling patch committed as `eb1fac1`; Release Track v2 docs pivot + первый MVP-прогон committed follow-up
- R0 завершён 2026-07-02: MVP-чеклист прогнан, дефекты P0-P3 записаны в `TASKS/TODO.md` R1 backlog
- Активная фаза теперь R1: первоочередной дефект — P0 cold-start `THREAD_BLOCK_6S` (uvLoopTask/TDLib batch pipeline на main thread)

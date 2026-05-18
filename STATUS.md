# STATUS — Telegram-HarmonyOS

Snapshot date: 2026-05-18

## Current State

- **Branch:** `dev`
- **Phase:** Phase 2 — Consolidate current working batch (per `TASKS/AGENT_EXECUTION_PLAN.md`)
- **Last committed baseline:** `b762cf1` (`fix: repo cleanup + TdGateway refactor + tests + selector memoization`)
- **Current follow-up:** uncommitted review-fix + Phase 2 decomposition patch (media response parsing, chat composer/actions controllers, CommandSerializer dispatch handlers, docs/spec hygiene)
- **Build:** `scripts/smoke-build.ps1` — green on last run
- **Smoke:** `scripts/smoke-ui-phase0.ps1` — green; `bash ./scripts/smoke-ui-phase0.sh` — green on last run
- **Warnings:** unverified `libtdlib_napi.so`, missing signing config
- **Device/emulator verification:** not performed in this pass

## Architecture

```text
TDLib (C++ NAPI) → TdGateway → MainThreadDispatcher → EventNormalizer → AppStore → AppStoreBridge → UI
```

- Clean Architecture + Redux-like store (serial dispatch, reducer-driven)
- UI: `@ComponentV2` decorators, token-first via `TgUiTokens.ets`
- Root shell: API23 `HdsTabs` + `HdsNavigation` (D14)
- Chat-list unread badge is now a project-owned inline `TgChatMeta` capsule, not a standalone `TgUnreadBadge` atom

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

### Chat UI
- Unread counters: Telegram-style compact `K`/`M` instead of `99+`
- Unread badge: custom Row/Text capsule inside `TgChatMeta`, replacing stock ArkUI `Badge` and removed standalone `TgUnreadBadge`
- Root shell uses API23 `HdsTabs` / `HdsNavigation`; old custom `TgTabBar` is not the active shell
- Removed active standalone atoms/demos for obsolete wrappers: `TgFilterBar`, `TgSearchBar`, `TgTextBubbleV2`, `TgTabBar`, `TgUnreadBadge`
- Active rich text path is `TgTextBubbleV3` / `TgTextBodyV3`

### Tests
- New/active: `TdGateway`, `EventNormalizer`, `AppStateModels`, `TextEngine`, `ChatTimelineVO`, `MessagesReducer`, `StateClone`, `ChatCommands`, `FilePipeline`, `LoadCalls`, `MessageDtoParser`, `UserDto`, `AppError`
- Deleted legacy service/controller tests that no longer match current architecture

### Performance / cleanup
- Memoized selectors: `selectOrderedChats`, `selectPinnedChats`, `selectUnpinnedChats`, `selectTotalUnreadCount`
- Removed noise files and trimmed oversized working docs
- `chatSelectors.ets` line endings normalized after review

## Known Issues

- `TgChatScreenPage.ets` still owns timeline/search/playback/safe-area coordination; composer and message actions are now extracted
- Tests still missing for `AuthSideEffect` and most use cases
- `libtdlib_napi.so` is externally built and not verified by current CI/smoke boundary
- Device/emulator runtime behavior still requires a signed deployment pass

## Working Tree

- Expected after this follow-up: uncommitted patch containing review fix + Phase 2 decomposition/refactor + docs/spec hygiene
- No broad dirty-tree backlog should remain after `b762cf1`

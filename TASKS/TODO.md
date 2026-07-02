# TODO — Telegram-HarmonyOS

Last updated: 2026-07-02

Canonical execution order: `TASKS/AGENT_EXECUTION_PLAN.md` (Release Track v2: R0 → R1 → R2 → R3+)

## Active Phase: R1 — MVP-стабилизация

### R0 — Консолидация и чистка (завершена 2026-07-02)

- [x] Закоммитить верифицированный throttling-патч `DownloadMessageMediaUseCase`: `eb1fac1` (build/smoke green 2026-07-02)
- [x] Архивировать старый план → `TASKS/ARCHIVE/AGENT_EXECUTION_PLAN_2026-05-18.md`; записан Release Track v2
- [x] `.gitignore`: добавить `.cpl/`, `hs_err_pid*.log`
- [x] Обновить `TASKS/CURRENT_PATCHSET_BOUNDARY.md` под релизный трек
- [x] Прогнать MVP-чеклист первый раз на эмуляторе (2026-07-02): эмулятор поднят из CLI (`Emulator -start "Pura 90 Pro Max"`), unsigned HAP установлен через hdc, дефекты записаны в R1 backlog

## R1 backlog (дефекты первого прогона 2026-07-02)

- [ ] **[P0] Cold-start `THREAD_BLOCK_6S` сохраняется** (fresh capture `appfreeze-...-20260703013437580`): main thread занят `uvLoopTask` 8+ секунд, стек внутри `libtdlib_napi.so`, TDLib шлёт батчи по 50 ответов каждые ~90 мс; фриз происходит ДО старта media-вотчера (01:34:26 vs 01:35:48) — виновник разбор батчей в конвейере Dispatcher→Normalizer→Store, не загрузки. Направление: чанкинг/yield обработки батчей на main thread, backpressure на NAPI-мосту, отложить тяжёлые редьюсеры холодного старта
- [ ] **[P1] Пагинация вглубь не срабатывает**: чат открылся на верхе загруженного окна («22 июн»), свайпы вверх не подгружают старую историю (вниз к новым — скроллится нормально)
- [ ] **[P2] Приложение открывается на вкладке Contacts** вместо Chats после запуска — проверить дефолтный таб
- [ ] **[P3] Сверить open-position семантику**: открытие на «22 июн» без видимого unread-разделителя — сравнить с эталоном Telegram (unread boundary + divider)
- [ ] Полный проход оставшихся пунктов чеклиста: фото полноэкран, войсы, видео/док по тапу, стикеры/GIF, отправка (текст — с санкции пользователя), день догфуда
- [ ] Re-run AppFreeze scenario после фикса P0 (замечание: fresh freeze детектился и на debug-провизии эмулятора, вопреки release-only оговорке в доках)
- [ ] Add pure unit coverage for `DownloadMessageMediaUseCase` throttle/budget behavior (scheduleScan dedupe, budget cap + rescan chain, stop() timer cleanup) — рантайм-поведение подтверждено hilog: Enqueued 4→4→2 с шагом 600 мс
- [ ] Propagate asynchronous TDLib transfer failures if a concrete `updateFile` failure shape is captured on emulator/device

## History (завершённые фазы старого плана)

### Phase 4 completed this session (2026-05-18)
- [x] Inspected current Calls real-data path (`CallsPage`, `LoadCallsUseCase`, `TgCallRow`) and Telegram references
- [x] Verified TDLib source contract in local `td_api.tl`: `searchCallMessages(offset, limit, only_missed) -> FoundMessages.next_offset`
- [x] Fixed `SearchCallMessagesPayload` / `CommandSerializer` to use opaque `offset:string` instead of chat-history-style `_from_message_id_json`
- [x] Fixed `LoadCallsUseCase` and `CallsPage` pagination state to consume `next_offset`
- [x] Added `CommandSerializer.test.ets` coverage for `searchCallMessages`
- [x] Expanded `LoadCalls.test.ets` to cover foundMessages parsing, missed/outgoing mapping, pagination, and direct `chat`/`user` hydration
- [x] Build: `scripts/smoke-build.ps1` — BUILD SUCCESSFUL on last run
- [x] Smoke: `scripts/smoke-ui-phase0.ps1` + `.sh` — passed on last run

### Phase 2 completed this session (2026-05-18)
- [x] `TdGateway.ets`: replaced `getMethodTimeout()` if/else chain with `Record<string, number>` Map
- [x] Removed 15+ noise files (heartbeat/runtime-sweep scripts, index.html, etc.)
- [x] Trimmed docs: STATUS.md (1220→compact), TODO.md (428KB→compact), LESSONS.md (527→compact)
- [x] Staged/committed valuable files from the broad batch (tests, specs, demos, sendMediaMessage, forward/, TgComposerEmojiPanel)
- [x] Added `TdGateway.test.ets` (timeout mapping, state machine, send validation, subscribeUpdates)
- [x] Added `EventNormalizer.test.ets` (handler dispatch, stats, unknown types, singleton)
- [x] Added `ChatMediaDownloadController.ets` — extracted from TgChatScreenPage
- [x] Fixed `ChatMediaDownloadController.ets` direct TDLib response parsing to use `TdObject` accessors instead of treating responses as plain records
- [x] Extracted `ChatComposerController.ets` from `TgChatScreenPage.ets` (composer send flow, emoji panel, attachment picker, picked-file local copy)
- [x] Extracted `ChatMessageActionsController.ets` from `TgChatScreenPage.ets` (reply/edit/copy/forward/pin/delete menu, forward target flow, action-mode state)
- [x] Added `ChatScreenRouteParams.ets` so chat route params are shared outside the page file
- [x] Refactored `CommandSerializer.ets` from one large `switch` into command-type dispatch handlers
- [x] Extracted `ChatSearchController.ets` from `TgChatScreenPage.ets` (debounced search + first-result navigation)
- [x] Added `CommandSerializer.test.ets` coverage for dispatch handlers and raw nested JSON expansion
- [x] Added `UseCases.test.ets` coverage for send/media/edit/delete/forward validation and dispatch
- [x] Added `AuthSideEffect.test.ets` basic singleton/store seam coverage without native TDLib startup
- [x] Selector memoization: `selectOrderedChats`, `selectPinnedChats`, `selectUnpinnedChats`, `selectTotalUnreadCount`
- [x] Cleaned stale docs/spec references to removed standalone atoms (`TgUnreadBadge`, `TgMessageTextBodyV2`, custom `TgTabBar` shell)
- [x] Normalized `chatSelectors.ets` line endings / `git diff --check` hygiene
- [x] `TASKS/CURRENT_PATCHSET_BOUNDARY.md` aligned with the actual current follow-up patch and verification boundary
- [x] Build: `scripts/smoke-build.ps1` — BUILD SUCCESSFUL on last run
- [x] Smoke: `scripts/smoke-ui-phase0.ps1` + `.sh` — passed on last run

### Phase 2 remaining work
- [x] Current review-fix/decomposition/tests follow-up patch committed locally

### Phase 5 next candidates
- [x] Media behavior completion: reviewed remaining photo/video/document/voice playback/download gaps against `TASKS/AGENT_EXECUTION_PLAN.md`
- [x] Narrow runtime slice selected and implemented: tap unloaded document/audio/voice → `downloadFile` → resolve local path → open/play
- [x] Added pure coverage for pending media open intent resolution and stale lifecycle/chat guards
- [x] Explicit failed-download/retry state in `ChatMediaDownloadController` + bubble params, without UI-polish expansion
- [x] Media gallery download/retry continuation for photo/video: refresh open gallery after timeline file-path updates, preserve current index, propagate failed state into gallery items, clear photo/album failed states when resolved
- [x] AppFreeze mitigation from emulator faultlogger: throttle/cap startup `DownloadMessageMediaUseCase` background scans and keep full photo/video/document/audio on explicit tap/download flow
- Открытые пункты перенесены в `## R1 backlog` (см. выше)

### Technical debt (пост-R1)
- [ ] Deeper integration tests for `AuthSideEffect` ready/warmup flow once TDLib/app-context test seam exists
- [x] `services/` legacy cleanup check: only `ConfigLocal.ets` + example remain; no removable legacy service layer found
- [x] Evaluated `LazyForEach` → `Repeat` / `@ReusableV2`: current live usages are `ChatListPage` and `TgChatScreenPage` with `reuseId`; keep as-is until a measured perf phase/device target exists
- [ ] Signing config (`signingConfigs` в `build-profile.json5`) — теперь это R2 (релизная упаковка), не блокер текущей работы
- AppFreeze baseline artifact: `THREAD_BLOCK_6S` at `2026-05-20 02:58:05.425` (re-check — в R1 backlog)

### Known blockers
- Missing signing config for HarmonyOS device/emulator deployment; no connected hdc target detected in this pass
- `libtdlib_napi.so` — external build, not verified in current CI/smoke boundary
- CodeRabbit CLI is not usable from native Windows Git Bash installer (`Unsupported operating system: mingw64_nt-*`); use WSL/Linux/macOS or another review path if CodeRabbit is required

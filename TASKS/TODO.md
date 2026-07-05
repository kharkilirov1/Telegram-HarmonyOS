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

- [x] **[P0] FIXED `eb81eca`**: cold-start `THREAD_BLOCK_6S` — TdGateway теперь ставит NAPI-батчи в очередь и осушает слайсами по 8 мс с yield через `setTimeout(0)`. Witness: холодный старт на эмуляторе 80+ секунд без нового appfreeze (раньше фриз через ~17 с), конвейер жив (Pipeline ready, чаты обновляются)
- [x] **[P1] FIXED `eb81eca`** (код + частичный рантайм): edge-lock пагинации — unlock `blockAutoPaginationUntilUserScroll` по touch-drag (на статичном крае `onDidScroll` не стреляет) + перепланирование recheck сквозь suppress-окно. Runtime: unlock по drag подтверждён hilog; сценарий «якорь ровно на краю окна» переподтвердить в догфуде
- [x] **[P2] FIXED `eb81eca`**: `HdsTabs({ index })` — `changeIndex` в `aboutToAppear` уходил до привязки контроллера. Witness: `MainTabsPage appeared with tab index: 2` + скриншот, приложение открывается на Chats
- [ ] **[P3] Divider «Не прочитано» в группах — интермиттентный** (реплей 05:28 собрал divider корректно, провал 05:04 не воспроизвёлся): диагностика вшита `a5fda9e` — при пропуске divider с unread-состоянием лог пишет sticky/lastRead/окно id. Ждём следующего репро с цифрами
- [x] **MVP-чеклист: отправка текста ✓** (2026-07-03): набор через композер, mic→send переключение, отправка, «Сегодня»-пилюля, двойные галочки, автоскролл, очистка поля — всё штатно (тест в свой чат File)
- [ ] **[P4] Медиа-конвейер видимого чата** (наблюдения прогона 2026-07-02, канал HarmonyOSHub):
  - тумба видимого фото не загрузилась за 2+ мин — фоновая очередь не приоритизировала открытый чат; **частичный фикс внесён**: `DownloadMessageMediaUseCase` сканирует активный чат первым (+ юнит-тесты)
  - плейсхолдер фото не рендерит minithumbnail (просто серый прямоугольник с кнопкой)
  - тап по незагруженному фото шлёт `downloadFile` (hilog witness), но не даёт визуального отклика (нет спиннера) и не открывает галерею
  - re-check после фикса приоритета: открыть канал → тумбы видимых сообщений должны приходить в первые секунды — **заблокировано**: эмулятор разлогинен (см. инцидент ниже)
- [x] **[Инцидент 2026-07-02] Эмулятор разлогинен** — закрыт: пользователь вошёл заново 2026-07-03; fresh-install логин-экран и повторный вход работают (пункт 1 MVP-чеклиста частично подтверждён)
- [x] **[P0-b] FIXED `d3d7883`: пост-логиновый фриз-килл** — нулевой setTimeout, взведённый из таймерного колбэка, дозревал в той же uv-таймерной фазе: цепочка дрейн-слайсов сливалась в один `uv_timer_task` (5+ с) и валила watchdog на шторме свежей синхронизации. Yield переведён на 1 мс. Witness: 100 с ресинка после логина — ни одного нового appfreeze, чат-лист синхронизировался
- [x] **[P4-a] Приоритет активного чата — runtime witness получен**: при открытии канала вотчер ставит видимые файлы сразу (hilog: Enqueued 4→4→4→1 за 2 секунды против пары файлов раз в ~90 с раньше)
- [x] **[P4-b] FIXED `531a677`: живое обновление медиа в открытом таймлайне** — трасса подтвердила: `fileDownloaded` не матчится в контент по fileId (msgMatch=0 стабильно; TDLib пере-нумерует file id между постановкой и завершением), пути доезжали только при переоткрытии чата. VO-билдер теперь добирает пустые пути фото/альбома/видео-тумб из `files.transfers` (заполняется всегда), перерисовка по transfers уже была. Witness: свежий канал — фото отрендерилось живьём при msgMatch=0
- [x] **[P4-c] FIXED `b8cb7d8`: канон resolve по `remote.unique_id`** — TDLib пере-нумерует file id между парсом и завершением. Решение: unique_id тянется parser→content→events→filesReducer(реестр `aliases[uniqueId]→fileId[]`, append-only, шарится по ссылке)→resolveContentPath(фоллбэк по алиасу). Рантайм-диагностика подтвердила: `content.photoUniqueId` доходит из парсера на реальных данных канала (`uid=[AQAD...]`). 6 юнит-тестов в FilePipeline (normalizer/реестр/alias-фоллбэк/precedence/no-match/clone). **Честно:** конкретный live-кейс «вечная кнопка на скачанном фото исчезла» не воспроизведён в этой сессии (тап-загрузки во fresh-сессии не стреляли в UI-автоматике); инструментальный прогон юнитов заблокирован эмулятором (`aa test` не отдаёт репорт), сьют компилируется зелёным
- [ ] **[P4-c ext] unique_id для остальных слотов**: video+thumb, document, audio, voice, sticker, animation, videoNote — сейчас только photo full/thumb; прочие держатся на прямом transfers-фоллбэке. Механический разнос по той же цепочке
- [ ] **[P4-d] Freeze-устойчивость дрейна — наблюдать**: пейсинг (задержка ≥ длительности слайса, `531a677`/`d3d7883`) пережил 2×90с холодных старта; при новых `THREAD_BLOCK_6S` с `uv_timer_task` — следующий шаг выносить парс батчей в taskpool
- [x] Тестовая инфраструктура восстановлена (`d22f628`): target `ohosTest` зарегистрирован в `entry/build-profile.json5`, синтаксическая гниль всего сьюта починена (`async 0`, unknown-cast), сьют компилируется зелёным; добавлен `DownloadMessageMedia.test.ets` (5 кейсов). Прогон юнитов на устройстве: `hvigorw onDeviceTest` требует подписанный HAP (R2); `aa test` вручную завис — прогонять пока из DevEco
- [ ] **R1.5: дефект-лист внешки** (разрешение пользователя получено — «разрешаю все»; прогресс 2026-07-03):
  - [x] Топ-бар: пилюля тайтла/круги back+avatar убраны — чистый текст и плоские иконки (`6ec4fb7`, скриншот-witness)
  - [x] Композер: скрепка/микрофон — плоские иконки, синяя заливка только у активного send (`6ec4fb7`)
  - [x] ~~Разделители чат-листа~~ — снято: инсет 80 уже соответствует Telegram (наблюдение было ошибочным)
  - [ ] Бейдж непрочитанного на табе Chats (данные есть: `selectTotalUnreadCount`; проверить badge-возможности HdsTabs/BottomTabBarStyle по БД)
  - [x] Медиа-плейсхолдер (`6b1fef4`): blur-minithumbnail из TDLib для фото/альбомов по всем трём путям рендера (router/shell/page); кольцо прогресса уже существовало в TgPhotoBubble. Follow-up закрыт `f4168da`: minithumb для video/GIF/videoNote тоже рендерится (witness: размытое превью с кнопкой загрузки и длительностью)
  - [ ] **[Критика hot-path логов]**: 4-й `THREAD_BLOCK_6S` (13:29) — main thread заблокировался внутри `HiLogPrint` (writev в hilog-сокет) при медиа-шторме из-за per-file info-логов (мои трейсы + старый лог FileNormalizer). Логи убраны/понижены до debug (`6b1fef4`), шторм-ретест чистый. Правило: никакого per-file info-лога в горячих путях
  - [ ] Хвостики (tails) у крайних пузырей группы; реакции — отдельным треком
  - [ ] Свайп-экшены чат-листа (архив/мьют/пин)
- [ ] **Медиа-волна (текущая область — работаем до конца):** следующие дефекты по порядку:
  1. [x] Тап — мгновенный отклик: фикс `e387795` (requestMediaDownload → notifyItemChangedByMessageId; pending-состояние контроллера теперь перерисовывает строку). Runtime-witness кольца — первым делом в следующем заходе
  1b. [x] Скачанное видео/GIF/кружок не выходили из download-состояния: полный путь теперь добирается из transfers (`e387795`). Witness: альбомы и видео в ленте рендерятся живыми тумбами
  2. Галерея не открывается по тапу, пока файл не скачан (ожидание: открыться с blur+прогрессом)
  3. **[x] P4-c канон решён `b8cb7d8`** (unique_id alias, см. R1 backlog). Осталось: live-подтверждение «вечная кнопка исчезает» + расширение unique_id на прочие слоты
  4. **[следующий №1] Live-witness P4-c + починка тап-загрузки**: во fresh-сессии тап по кнопке загрузки фото не инициировал `downloadFile` (в hilog пусто) — проверить wiring `onMediaDownloadRequest`→`requestMediaDownload`→gateway для одиночного фото vs альбома/видео; на исправном пути подтвердить, что скачанное фото теряет кнопку через alias-резолв
  4. Видеоплеер/полноэкран фото — прогнать и записать дефекты
  5. Войсы: play/pause/прогресс — прогнать
  6. Документы: скачивание/открытие — прогнать
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

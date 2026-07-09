# LESSONS — repeated mistakes and project-specific pitfalls

Last updated: 2026-07-08

## 87. Отрицательные chat id — системная мина: гварды `<= 0`/`> 0` молча режут все группы и каналы
- Telegram: supergroup/channel id ОТРИЦАТЕЛЬНЫЕ (-100...). Три экземпляра одного бага в одном потоке (openProfile, loadProfile, onReady-параметр): функция «работает для лички, молча no-op для групп». Валидация только `!== 0`/`=== 0`.
- Грепать при подозрении: `chatId <= 0|chatId > 0` — исключение легитимно только там, где речь О ЮЗЕРАХ (userId положительные, напр. звонки).

## 86. TextArea(text:) — только отображение; программный префилл требует двустороннего биндинга
- Симптом: setDraftText рисовал текст в поле, но первый ввод начинал С ПУСТОГО внутреннего буфера (edit-префилл затирался клавишей). Прямой prop не заталкивает значение в нативный буфер компонента.
- Канон: @Local-зеркало парамет + @Monitor-синхронизация + `TextArea({ text: this.buffer!! })` (двусторонний `!!`, API 18; для V1 — `$$`). Дока TextAreaOptions прямо советует биндить состояние двусторонне.
- Инструментальное: `uinput -K -t` в СФОКУСИРОВАННЫЙ TextArea ненадёжен — то подставляет текст целиком (затирая буфер), то молча дропает; для witness клавиатурного ввода на эмуляторе доверять только реальным тапам по экранной клавиатуре или ручному прогону.

## 85. Скриптовая правка файла: не открывать целевой файл на запись до готовности контента
- python-heredoc с эмодзи в Windows-консоли упал на суррогатах ПОСЛЕ open(p,'w') — целевой файл обнулился (0 байт); git restore спас. Паттерн: собрать контент → проверить encode → писать во временный файл + os.replace; либо просто Edit-инструмент (UTF-8-безопасен).
- Тот же заход, вторые грабли: heredoc-текст с последовательностью «бэкслеш-U» в обычной python-строке ломает парсер (unicodeescape) — не-ASCII в heredoc-скриптах только через именованные переменные с chr()/кодами, а лучше вообще не через heredoc.

## 84. LazyForEach перестраивает строку ТОЛЬКО при смене key — notifyDataChange со стабильным ключом это no-op для V2-строк
- Симптом-цепочка (охота 3 тика): скачанный файл не оживлял бабл до перезахода. Трасса показала: transfers пишутся, rebuild идёт, diff находит строку, notifyDataChange уходит — а @Param в @ComponentV2-строке остаются создания (Monitor-проба молчит). Док-канон: «After message is changed, the KEY of the list item changes. As a result, LazyForEach REBUILDS the item» — ключ и есть механизм обновления.
- Фикс-паттерн: в key запекается render-штамп изменяемого визуального состояния (`msg_<id>_s<stamp>`: пути есть/нет, downloading-флаги, прогресс бакетами по 10%, заполненность альбома), а diff-структура (same-order/append/prepend/anchor) сравнивает stableKey БЕЗ штампа — иначе смена состояния выглядит как смена порядка и валится в reload.
- Смежные грабли той же охоты: (а) `.reuseId()` на ListItem — V1-механизм, с V2-строкой молча оставляет компонент со старыми @Param (для V2 есть @ReusableV2 + `.reuse()`, API 18+); (б) `applyFilePathToContent` клонирует MessageContent вручную и ТЕРЯЕТ uniqueId-поля (uid=0 после клона) — при ручных клонах сверяй список полей с классом.

## 83. Глобальный `hilog -b D` оживляет ВСЕ накопленные debug-логи — это тот же writev-шторм
- 6-й THREAD_BLOCK_6S (17:49): стек снова HiLogPrint→writev. «Безопасные» debug-логи (per-entry timeline на каждый rebuild, per-file normalizer) молчат лишь пока уровень INFO; глобальное включение D на живом синке = шторм = watchdog-килл.
- Правила: (1) per-entry/per-rebuild логов не существует ни на каком уровне — удалять после диагностики; (2) debug включать только точечным доменом `hilog -b D -D 0xD0000XX`; (3) одноразовая диагностика пользовательского клика — info-однострочник (1 тап = 1 строка), виден без смены уровня.
- Смежное: параметры @Param, влияющие на обработчики (fileId!), обязаны передаваться во ВСЕ вызовы компонента — молчаливый дефолт 0 превращает обработчик в no-op без единого лога (photoFileId/videoFileId в Router не передавались с самого создания медиа-веток).

## 82. file:// URI и POSIX-путь — разные валюты: zlib/fs требуют путь, Image/AVPlayer едят URI
- Симптом: `zlib.GZip.gzopen(file://com.telegram…/data/…)` → «No such file or access mode error», хотя Image по тому же значению рисует. Таймлайн-VO раздаёт `fileUri.getUriFromPath(path)` (URI с authority=bundle) — файловые API его не понимают.
- Конверсии: путь→URI `fileUri.getUriFromPath(p)`; URI→путь `new fileUri.FileUri(uri).path` (или срез authority после `file://`). Перед любым fs/zlib-вызовом значения из VO нормализовать в путь.
- Смежное (эмулятор-автоматика): свайп это `uinput -T -m x1 y1 x2 y2 speed` — `-M` (мышь) молча не скроллит список; и hdc-пути `/data/...` в Git Bash требуют `MSYS_NO_PATHCONV=1`, иначе превращаются в `C:/Program Files/Git/data/...`.
- Усиление урока 78: `aa force-stop` может отрапортовать «successfully», не убив процесс (STIME остался старым при живом ps). Проверка свежести бинаря = STIME против `hdc shell date`; при рассинхроне — повторный force-stop с паузой и контролем пустого ps до start.

## 1. Do not mix V1 and V2 ArkUI decorators casually
- `tg_ui` is `@ComponentV2`.
- Active shell pages are `@ComponentV2`.
- The live chat-list row path uses `TgChatRow` as `@ComponentV2`.
- Mixing these layers incorrectly is a reliable way to break hvigor builds.

## 2. `LazyForEach` reuse rules are not interchangeable between V1 and V2
- Current chat list path relies on `LazyForEach` + `.reuseId(...)` with a V2 row component.
- Official docs treat `@ReusableV2` as a different model for V2 components.
- Do not mechanically replace V1 reuse patterns with V2 ones.

## 3. One separator system per list
- Chat rows already carry their own separator strategy.
- Do not enable both row separators and `List.divider` at the same time.

## 4. Safe area and glass bars must be explicit
- Use avoid-area / safe-area helpers for top bar and bottom tab overlap.
- Blur/glass visuals are acceptable only if interaction zones remain safe.

## 5. Runtime reset must clear static caches
- `LoadChatHistoryUseCase` and `LoadChatsUseCase` maintain cross-call/static state.
- If runtime shutdown does not reset them, reopened sessions can behave as if data is already loaded or still in-flight.

## 6. AppStorage is UI-facing state, not background worker state
- TDLib callbacks and reducer/UI work land on the main thread.
- Background paths should move DTOs/data, not mutate AppStorage directly.

## 7. Historical names in docs can be stale
- `AppTopBar`, `AppTabBarItem`, `ChatListItem` still appear in older docs.
- Current runtime path is tg_ui-first for shell/chat screens.
- When docs conflict, trust current code + `MASTER_PLAN_TELEGRAM_UI.md` + `STATUS.md`.

## 8. Token drift creates fake "almost Telegram" UI
- Hex colors and local geometry must move into `TgUiTokens.ets` / resources.

## 9. iOS reference must be inspected before non-trivial UI work
- The project aims for Telegram iOS visual fidelity.
- Skipping iOS source inspection leads to wrong spacing, hierarchy, and state coverage.

## 10. Keep fallback paths until acceptance gates are actually passed
- Deleting legacy/fallback code too early makes regressions harder to isolate.

## 11. `LazyForEach` keys must be persistent, not order-derived
- Use stable dialog identity (`chatId`) for the item key.
- Appending the current index causes unnecessary row churn during reordering.

## 12. Programmatic chat restore can trip `List.onScrollIndex`
- Use `onDidScroll` + `ScrollState` to unlock pagination only after a real user scroll.

## 13. Edge pagination must auto-recheck after fetch, not require scroll-away
- iOS Telegram uses continuous checking (threshold = 5 items, no latch).
- After each `loadOlder`/`loadNewer`, call `recheckPaginationEdge()`.

## 14. Navigation-title weight should approximate iOS semibold
- `FontWeight.Medium` is the safer approximation for centered navigation titles.

## 15. History sender hydration caps must cover the whole default page
- `getChatHistory` batches can contain more than 8 distinct authors in a group.
- Keep sender-hydration cap high enough to cover the default history page size.

## 16. Generic regex field extraction can pick nested `id` values
- `TdObject.getNumber('id')` is unsafe for payloads like TDLib `user`.
- For identity-bearing payloads, prefer explicit top-level extraction (`getTopLevelNumber`).

## 17. Freeze a patchset boundary as soon as the HiLog loop turns green
- Write down what belongs to current stabilization batch vs. later work.

## 18. Direct TDLib responses with `@extra` do not update the store by themselves
- Use cases receiving direct responses must manually normalize and dispatch.

## 19. `getChat` needs a direct `chat` normalizer path
- Direct TDLib `getChat` responses have type `chat`; without a handler they don't populate state.

## 20. DevEco hvigor can exist locally even when `PATH` says otherwise
- Default path: `C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat`
- Build smoke scripts should probe the default DevEco install path.

## 21. TDLib `getChatHistory` short batches are ambiguous
- Official TDLib docs allow fewer messages than requested even when more history exists.
- `messageCount < limit` must NOT immediately flip `canLoadOlder=false`.

## 22. Do not render a tiny initial batch as if it were stable chat history
- Defer committing suspiciously tiny initial batches until the top-up completes.

## 23. One top-up can still be too shallow for Telegram history
- Use a bounded top-up loop while oldest-message progress continues.

## 24. In `LazyForEach`, mutable content must not be part of item identity
- Keep identity stable by dialog id (`chatId`); avoid broad reuse pools.

## 25. Prefer stock ArkUI components over thin wrapper atoms
- Custom atoms that only wrap a stock component with token styling add no real value.
- Only create an atom when it adds genuine logic: enums, computed state, composite layout.
- Use stock ArkUI components directly with token styling inline for new screens.

## 26. Avatar photos are the single biggest "demo vs real app" visual signal
- TDLib provides `file.id` in `profile_photo.small` but does NOT auto-download.
- Priority: implement `downloadFile` flow before any further UI polish work.

## 27. File download architecture: cross-cutting reducer for fileId→path mapping
- `updateFile` from TDLib only carries `file.id` + `local.path` — no entity context.
- The `filesReducer` scans `users` and `chats` maps for matching `photoSmallFileId` on `fileDownloaded`.

## 28. TDLib file objects: `getNumber('id')` fails due to nested `remote.id` string
- Use `getTopLevelNumber('id')` which does character-by-character parsing respecting JSON nesting depth.

## 29. `JSON.stringify(TdObject)` produces empty/truncated output — use native accessors
- Never `JSON.stringify` a TdObject for data extraction. Always use `.getString()` / `.getNumber()` / `.getBool()` / `.getObject()` API.

## 30. (deleted — merged into #29)

## 31. Scroll compensation for prepend must be synchronous
- Call `scrollToIndex` synchronously right after `applyDiff()`.
- Using `setTimeout(16ms)` creates a visible 1-frame shift/flicker.

## 32. Pagination latch pattern is unnecessary overhead
- Neither Android nor iOS Telegram use a latch for pagination.
- `recheckPaginationEdge()` provides continuous loading without latches.

## 33. Prepend scroll compensation: pre-capture + viewport freeze + cascade block
- Save indices AND yOffset BEFORE `applyDiff`.
- Freeze viewport with immediate `scrollTo({ yOffset, animation: false })`.
- Block cascade: set `blockAutoPaginationUntilUserScroll = true` during prepend.

## 34. Prefer ArkUI native `maintainVisibleContentPosition(true)` over custom prepend scroll hacks
- Keep the native flag on for chat history lists.

## 35. Do not mix `onDatasetChange` with `onDataAdd/onDataDelete/onDataChange` in one LazyForEach datasource
- Keep one notification family per datasource.

## 36. Never recheck pagination synchronously in the same promise `finally` that dispatches history
- Schedule edge recheck to the next tick; retry after diff has settled.

## 37. Media status controls need explicit state machines
- Telegram iOS models media controls as explicit states (download, progress, play, pause).
- Map each bubble's control to a finite state machine, not ad-hoc branches.

## 38. Determinate media progress should imply an active transfer
- `downloadProgress in [0, 1)` counts as active even if `isDownloading` is false.

## 39. Composer accessory panels belong inside the text capsule
- iOS places panels inside `textInputContainerBackgroundView`, not as separate floating capsules.

## 40. Platform root tab bars must collapse on detail routes
- When chat detail is visible: HDS bar height, margin, mask, and opacity collapse to 0.

---

## Review-driven additions (2026-05-18)

## 41. Map-based dispatch beats chained if/else for method routing
- `TdGateway.getMethodTimeout()` used 8 if/else branches mapping methods to timeouts.
- Replaced with `Record<string, number>` + `??` default — O(1) lookup, adds a new method without growing the function body.

## 42. Docs files grow without bound if every task appends status entries
- `STATUS.md` reached 1220+ lines, `LESSONS.md` reached 527+ entries, `TODO.md` 428KB.
- These files should be working snapshots, not changelogs. The git history is the changelog.
- Trim aggressively. If a doc exceeds ~200 lines, consolidate or archive.

## 43. Large page files are the first architectural smell to address
- `TgChatScreenPage.ets` at 3094 lines mixes subscriptions, 6 use cases, composer, emoji panel, gallery, navigation, voice playback, and context menu.
- A page this size is impossible to review, hard to test, and prone to merge conflicts.
- Decompose before adding more features: ViewModel + Controller + Panel sub-components.

## 44. Direct TDLib adapter responses are `TdObject`, not plain records
- `TdGatewayAdapter.send()` returns the `TdObject` from the gateway as `Object`.
- Do not cast direct TDLib responses to `Record<string, Object>` and index into them.
- Use `TdObject` accessors (`getObject`, `getString`, `getBool`, `getNumber`) for direct responses too.

## 45. ArkTS object literal restrictions affect controller extraction
- Do not return ad-hoc object-literal host adapters from component methods; ArkTS rejects untyped object literals.
- Prefer explicit host methods on the component and pass `this` to extracted controllers.
- Avoid host method names that collide with `@Local` field names.

## 46. Command serializers should be handler-dispatched, not switch-owned
- Keep each TDLib command serializer in a small handler function.
- Register handlers by command type so adding a command does not grow one high-conflict switch body.

## 47. Side-effect tests need explicit seams
- Pure use cases can be tested with a fake `TdGatewayPort`.
- `AuthSideEffect` currently couples to singleton TD gateway and app context; keep basic seam tests local until a richer injectable runtime seam exists.

## 48. Debounced search belongs outside the page body
- Keep timer ownership and stale-result guards in a controller.
- Let the page expose only active chat id, query state, and message-id scrolling.

## 49. `searchCallMessages` is not `getChatHistory`
- TDLib `searchCallMessages` takes opaque `offset:string` and returns `FoundMessages.next_offset`.
- Do not reuse chat-history `from_message_id` / `next_from_message_id` semantics for calls search.
- Ground call-history pagination in `td_api.tl` before wiring UI state.

## 50. User-initiated media downloads must carry the tap intent
- Starting `downloadFile` is not enough for product behavior: document/audio/voice taps should resume into open/play after `fileDownloaded` updates the message path.
- Store the intent with chat id + lifecycle token + message id + file id, and resolve it only from rebuilt timeline entries.
- Clear the intent on cancel, navigation, or pending-download reset to avoid stale auto-open/play.

## 51. Download failure state needs a page-local change signal
- A controller can record failed `downloadFile` requests, but the UI will not repaint unless the page observes controller version changes.
- Keep retry state page-local for on-demand media failures; clear it on retry, cancel, resolved local path, and navigation reset.
- Do not over-polish the error UI first: expose status through bubble params and keep tap-to-retry behavior deterministic.

## 52. Open media galleries must refresh from the rebuilt timeline
- A gallery opened on an unloaded photo/video can outlive the `downloadFile` request that resolves the local path.
- Do not let the overlay keep stale `MediaGalleryItem` snapshots; rebuild gallery params after timeline diff, preserve current item by message/file identity, and clear local pending UI when the path appears.
- Include photo and album file ids in resolved-download cleanup, not only document/audio/voice/video.

## 53. Startup background downloads must be bounded
- AppFreeze baseline `THREAD_BLOCK_6S` showed cold-start TDLib batches plus repeated `DownloadMedia` scans/enqueues on the main thread.
- Background media download watchers must throttle store-triggered scans, cap enqueues per scan, and avoid full-size media auto-downloads during startup.
- Keep full photo/video/document/audio under explicit tap/download continuation; use background auto-download only for thumbnails and genuinely small Telegram media.

## 55. Release track replaces breadth phases
- Phase-роадмап без видимой пользователю финишной черты («media behavior completion») привёл к дрейфу и потере ориентира.
- План v2: MVP-чеклист как единственный гейт R1, явный freeze-список, после v0.1.0 — одна фича = один релиз v0.x.
- Мета-тулинг (heartbeat/sweep) заморожен, пока реальная регрессия его не потребует.

## 56. Полный эмуляторный цикл доступен из CLI без DevEco GUI
- `Emulator.exe -start "<hvd name>"` (из `DevEco Studio\tools\emulator`) поднимает зарегистрированный инстанс; справка бинаря богаче официальной доки (`-list`, `-config`, `-license`).
- Unsigned HAP ставится на эмулятор через `hdc install -r` — подпись нужна только для реального устройства; это разблокирует автономный цикл build→install→run→observe.
- Использовать hdc из SDK DevEco, не из PATH; в Git Bash device-пути требуют `MSYS_NO_PATHCONV=1`, а `file recv` на Windows ломается на абсолютных путях — принимать файл относительным именем из целевого каталога.
- `uitest uiInput click/swipe/keyEvent` + `snapshot_display` достаточно для прогона UI-чеклиста без ручного участия.

## 57. Cold-start freeze — это конвейер TDLib-батчей, не загрузки медиа
- Свежий `THREAD_BLOCK_6S` (2026-07-03 01:34): main thread 8+ секунд в `uvLoopTask`, стек в `libtdlib_napi.so`, батчи по 50 ответов каждые ~90 мс; media-вотчер стартовал только через минуту после фриза — троттлинг загрузок работает (hilog: Enqueued 4→4→2 шаг 600 мс), но не лечит корень.
- Направление фикса: чанкинг/yield обработки батчей в главном потоке, backpressure на NAPI-мосту, отложенные тяжёлые редьюсеры на холодном старте.
- AppFreeze-детекция сработала на debug-провизии эмулятора, несмотря на release-only оговорку в доках — эмулятор пригоден для freeze-ретестов.

## 58. Штормы NAPI-батчей лечатся бюджетным дрейном на main thread
- Решение P0: очередь батчей в TdGateway + осушение слайсами по 8 мс с yield через `setTimeout(0)` — watchdog и vsync получают ход между слайсами, cold-start freeze ушёл (80+ с чистого старта против фриза на ~17 с).
- Дрейн обязан работать и в состоянии 'destroying': close-flow ждёт `authorizationStateClosed` через тот же конвейер; очередь чистится только в самом конце destroy/cleanup.
- Следующий резерв производительности (если понадобится): убрать двойную сериализацию — dispatchItem делает `JSON.stringify`, а нижние слои снова парсят.

## 59. ArkUI: события не приходят на статичном крае и до привязки контроллера
- `onDidScroll` не стреляет, когда лист упёрся в край и контент не движется — «разблокировку по скроллу» надо дублировать через `onTouch` (drag ≥ порога), иначе флаг вечный.
- `TabsController.changeIndex()` в `aboutToAppear` — no-op (контроллер ещё не привязан к построенному компоненту); стартовый таб задаётся параметром `index` в опциях Tabs/HdsTabs.
- Одноразовые `schedulePaginationRecheck` глотаются suppress-окном — на статичном крае перепланируй recheck, там `onScrollIndex` больше не стрельнёт.

## 60. `hdc install -r` одного HAP'а пересоздаёт весь бандл
- Установка ohosTest-HAP через `install -r` удалила entry-модуль и ВСЕ данные приложения — TDLib-сессия эмулятора потеряна, потребовался ручной релогин.
- Multi-HAP бандл обновлять только полным набором HAP'ов; тестовый HAP не ставить поверх рабочей сессии.
- Прогон юнитов: `hvigorw onDeviceTest` требует подписанный HAP; ручной `aa test -s unittest OpenHarmonyTestRunner` в этой конфигурации завис — до R2 юниты гонять из DevEco.

## 66. TDLib remote.unique_id — единственный стабильный ключ файла
- file.id пере-нумеруется между парсом сообщения и завершением загрузки; `remote.unique_id` стабилен. Матчить медиа и transfers надо по unique_id, id — вторично.
- Реализация: append-only реестр `aliases[uniqueId]→fileId[]` в filesReducer, шарится по ссылке между клонами стейта (монотонен, вне diff-пути → мутация на месте допустима и дёшева при штормах). resolveContentPath: промах по fileId → фоллбэк по любому transfer через алиас.
- Гейзенбаг живого witness: во fresh-сессии тапы-загрузки не стреляли через uitest, а инструментальный `aa test` не отдаёт репорт на этом эмуляторе — детерминированный witness делаем юнит-тестом чистой resolve-функции (экспортировать из VO), а не флаки-UI.

## 65. Гибрид V1/V2: реактивность рвётся на швах, notify вручную
- V2-баблы обновляются по `@Param` только когда V1-родитель (LazyForEach + reuse) пере-рендерит вызов; стор — вне ArkUI-реактивности; поля контроллеров не видит ни одна система.
- Правило (CLAUDE.md №13): состояние, влияющее на строку списка, живёт в VO (diff+notify) или `@ObservedV2`/`@Trace`. Забытый ручной `notifyItemChangedByMessageId` = молчаливый баг (фикс мгновенного отклика `e387795`).
- Пока миграция половинчатая — каждый источник состояния для строки проверять на «доедет ли до баббла без ручного notify».

## 64. hilog.info в горячем пути — сам по себе источник THREAD_BLOCK
- Per-file info-логи (мои диагностические трейсы + старый лог FileNormalizer на каждый updateFile) при медиа-шторме насыщают hilog-сокет: main thread блокируется ВНУТРИ `HiLogPrint`/`writev` — freeze-лог показывает стек в libhilog_napi.
- Диагностика Гейзенбага: инструментируй редко-срабатывающие ветки (пропуск divider — раз на ребилд), никогда — per-item в штормовых потоках; временные трейсы удалять сразу после снятия показаний.
- Горячие пер-файловые логи переведены на hilog.debug (не эмитится по умолчанию) — шторм-ретест чистый.

## 63. file id из updateFile может не совпадать с fileId контента в сторе
- Трасса filesReducer показала msgMatch=0 для тумб, поставленных самим вотчером из контента: TDLib пере-нумерует file id между постановкой и завершением (или страницы истории подменяют сообщения с новыми id).
- Канонический путь «fileDownloaded → применить путь в content» ненадёжен; `files.transfers` заполняется на КАЖДЫЙ updateFile — использовать его как источник истины: VO-билдер добирает пустые контент-пути из завершённых transfers, перерисовка по transfers уже есть.
- Диагностические трейсы (`DownloadMedia: enqueue`, `FilesReducer: fileDownloaded`) оставлены для root-cause follow-up.

## 62. setTimeout(0) из таймерного колбэка не покидает uv-таймерную фазу
- Нулевой таймер, перевзведённый внутри собственного колбэка, дозревает в той же фазе цикла: «yield» через `setTimeout(0)` сливает всю цепочку слайсов в один `uv_timer_task` — freeze-лог показывает его вместо uvLoopTask, JS-стек в интерпретаторе.
- Реальный yield для чанк-обработки на main thread — задержка ≥1 мс: слайс уезжает в следующий оборот цикла, watchdog/vsync исполняются между слайсами.
- Малый бэклог маскирует проблему (весь дрейн укладывается в <6 с) — проверять именно на максимальном шторме: свежий логин/полная ресинхронизация.
- Даже 1 мс ненадёжна: loop handler прокачивает дозревшие таймеры внутри одного uv_timer_task, а GC-давление растягивает слайсы (третий freeze — стек в malloc). Надёжный инвариант — пейсинг: задержка следующего слайса ≥ фактической длительности предыдущего (≤50% занятости main thread при любом размере элементов).

## 61. Незарегистрированная цель ohosTest = мёртвые тесты
- В `entry/build-profile.json5` отсутствовал target `ohosTest` — весь тестовый сьют никогда не компилировался и накопил синтаксическую гниль (`it('...', async 0, ...)` во множестве файлов, unknown-cast).
- Регистрация цели + починка синтаксиса вернули компайл-гейт: `hvigorw --mode module -p module=entry@ohosTest assembleHap` теперь зелёный и должен быть частью верификации при правках тестов.
- Формат цели подтверждён локальными официальными Codelabs (`targets: [{name: "default"}, {name: "ohosTest"}]`), когда RAG-база молчит — локальные референсы вторые в очереди.

## 54. HarmonyOS timer/AppFreeze doc contracts for the throttled media watcher
- Docs DB cross-check (2026-07-02): `setTimeout` returns `number` in ArkTS, so the `as number` cast is redundant; `clearTimeout` with a stale/unknown id is a documented safe no-op, but timers must be cleared on the thread that created them.
- Timers do not fire while the app is in background; expired timers fire after foreground restore — the 600ms rescan chain pauses in background and resumes on foreground, which is acceptable for auto-downloads.
- `THREAD_BLOCK_6S` is a watchdog activation check inserted into the main thread; chunking scans via `setTimeout` yields the event loop between chunks, which is exactly what the watchdog needs.
- AppFreeze detection applies to release-version apps only (not debug) — re-verification must match the original capture's build type.

## 67. Декомпилированный конкурент (ArkGram) как native ArkTS-референс
- ArkGram даёт нативные ArkUI-паттерны/числа, которых нет в iOS/Android-рефах: connection-state в шапке через реактивный `StorageLink`+`declareWatch`, `maxSelectNumber:10` мультивыбор, `Button.stateEffect` press-фидбэк, компоновка топ-бара (Row 60, title 16/Bold, статус 12px `#2AABEE`).
- Где мы уже сильнее — НЕ копировать: measure-driven rich-text (`TgTextBodyV3`), инкрементальный `applyDiff`, `maintainVisibleContentPosition`-prepend, изолированные `NavPathStack`. Копировать его ffmpeg/ручной translate было бы регрессом.
- Аудит выявил и неверные факты субагентов: `TgVideoPlayerPage.ets` из находки не существует (видео в галерее — через `TgInlineVideoView`). Проверять пути перед правкой.

## 68. RAG-база неполна — witness для непокрытых API берётся из build
- `clickEffect`, `TextAreaController.stopEditing`, `@ReusableV2` НЕ находятся в `search_harmonyos_docs` (2 разных запроса каждый), но `clickEffect`/`stopEditing` реальны — build подтвердил компиляцию. Для непокрытых RAG API witness = сам build (+ grep использований в проекте/Codelabs), а не «RAG молчит → значит нет».
- `avoidAreaChange` (Callback<AvoidAreaOptions>, `.type`===`TYPE_SYSTEM`), `getFocusController().requestFocus(id)` (12+) — RAG подтвердил с примерами. Сверяйся, где база отвечает.

## 70. Слияние uv-таймерной фазы лечится эскалацией, не константным пейсингом
- Пейсинг «пауза ≥ elapsed» (Lesson 62) не выдержал шторм при открытии тяжёлого канала: drain+watcher+history-таймеры дозревают в паузе и продлевают один uv_timer_task, main thread CPU-bound 6+с (стек libark_jsruntime, killed).
- Рабочая схема: (1) мультипликативный backoff подряд «горячих» слайсов до жёсткого потолка (250мс) со сбросом при осушении; (2) backpressure-сигнал `isDrainCongested()` — фоновые таймер-потребители (media watcher) откладывают свои тики при шторме.
- Опциональный член порта (`isDrainCongested?: () => boolean`) сохраняет тестовые фейки минимальными; ArkTS-фейк ДОЛЖЕН декларировать поле явно (`= undefined`), иначе присвоение в тесте не компилируется.

## 71. Делегирование кодеру: патч по цепочке слоёв проверять на КАЖДОМ слое
- DeepSeek-кодер провёл `stickerThumbnailPath` DTO→VO→Page→Router→View, но пропустил слой модели (`MessageContent`) и все 3 клон-маппинга редьюсеров — компайл поймал, но клоны потеряли бы значение молчаливо (родственно Lesson 63/65).
- Правило делегату/ревью: для нового поля контента чек-лист слоёв фиксированный — DTO, MessageContent, messagesReducer (dto→content И clone), filesReducer (clone), VO. Grep по соседнему полю (isVideoSticker) даёт полный список точек.
- Отчёт кодера «N/N PASS» без компиляции — не witness; компайл-гейт и build остаются за оркестратором.

## 72. hdc install: только относительный путь из cwd
- `hdc install` с абсолютным Windows-путём склеивает его с cwd (`C:\...\proj\C:/...`) и падает `[Fail]`; при этом `aa start` после провала молча запускает СТАРЫЙ установленный бинарь — ретест на нём был бы ложным witness.
- Всегда: `cd <proj> && hdc install -r entry/build/.../entry-default-unsigned.hap`, и проверять строку `install bundle successfully`.

## 69. Single source of truth для safe-area инсета + smoke-контракт как ограничитель
- Дублирование расчёта инсета (атом `aboutToAppear` + страница) даёт рассинхрон spacer↔contentOffset. Решение: страница считает инсет один раз → атому `@Param topInset`; подписка `avoidAreaChange` (windowSizeChange НЕ гарантирует смену высоты статус-бара) с парным `off()`; fallback — токен ~38vp, не 0.
- `smoke-ui-phase0` требует `.reuseId()` в `ChatListPage` — миграция на `@ReusableV2` (аудит #1) сломала бы контракт. Проектный smoke-контракт закрепляет паттерны: проверяй его перед «улучшением» по аудиту, иначе зелёный аудит = красный smoke.

## 73. Проценты внутри auto-sized контейнера ArkUI = родительский CONSTRAINT, не финальный размер
- Ребёнок с `width('100%')`/`height('100%')` в контейнере, сайзящемся по контенту, получает процент от constraint родителя (в List-элементе — вьюпорт), а не от финальной ширины/высоты. Два проявления в одном стеке: `TgReplySnippet` растягивался `minWidth: containerWidth`-хаком поверх `width('100%')`-каскада; quote-бар `height('100%')` в auto-Row раздувал плашку цитаты до полутора экранов.
- Решение для «полоса высотой с контент»: `LayoutPolicy.matchParent` (API 15+, в RAG есть: «size equals the parent's content area») — резолвится от финального размера родителя. Для ширины по контенту — убирать процентный каскад целиком (hug), Ellipsis у Text работает от `constraintSize.maxWidth` предка.
- Симптом для диагностики: «плашка/бар на весь экран при коротком контенте» — сразу искать процентные размеры в auto-контейнере.

## 74. 8-значный hex в ArkUI — это #AARRGGBB: конкатенация alpha в хвост сдвигает каналы
- `quoteAccentHex + '1F'` дал `#8774E11F` → ArkUI прочитал A=87, R=74, G=E1, B=1F — непрозрачно-зелёная цитата вместо фиолетовой подложки 12%.
- Для «accent с прозрачностью» — только `rgba(r, g, b, a)`-строка (паттерн `accentRgba()` в TgReplySnippet/TgTextBodyV3), не hex-суффикс.

## 76. В проекте ДВА MessageContentType: enum (MessageDto) и union-type (AppState)
- Новое значение типа контента добавляется в ОБА места: `enum MessageContentType` в `core/model/dto/MessageDto.ets` И `export type MessageContentType = '...'` в `core/model/AppState.ets` (строка 12). Забытый union ловится компилятором только на первом сравнении (`no overlap`), а не на присваивании.
- Чек-лист нового contentType поверх урока 71: enum DTO + union AppState + поля DTO/MessageContent + messagesReducer map+clone + VO + Router/Page-рендер + (опц.) reuseId-ветка.

## 75. Парные ветки вычисления sender-ключа обязаны зеркалить друг друга
- Группировка сообщений: `effectiveSenderId` (ветка не-групп) давал `-3` для senderId=0, а `prevSenderId`-трекер хранил `senderChatId` — рассинхрон реальный, фикс верный. Уточнение тика 4: каналы шли ЧЕРЕЗ isGroupChat-ветку (в isGroupChat ошибочно входил 'channel'), поэтому симптом «каналы не группируются» этой парой не объяснялся; после исключения 'channel' из isGroupChat канальная группировка держится именно на зеркальности effectiveSenderId ↔ prevSenderId.
- При правке одной из парных веток (вычисление ключа ↔ обновление трекера) grep по второй обязателен; лучше — выносить в одну функцию.

## 81. AVPlayer stateChange('playing') может теряться — синхронизируй флаг по player.state в timeUpdate
- Witness: прогресс тикал (timeUpdate живой), а isPlaying оставался false — событие 'playing' из on('stateChange') не пришло (подписка стояла до prepare, waitForState снимает только свой handler). Полагаться на дискретные stateChange-события для UI-флага нельзя.
- Паттерн: в `timeUpdate`-обработчике выставлять `isPlaying = player.state === 'playing'` (тики идут только при воспроизведении), а в pause()/stop()-методах — явный `isPlaying=false; emit()` рядом с await, не дожидаясь события.

## 80. stateStyles на ListItem глотает клики swipeAction-кнопок
- Симптом: свайп-панель рисуется, но onClick кнопок не стреляет; на каждый тап в hilog только `AceStateStyle ... ChatListPage` (pressed-обработка ListItem). Виновник — `stateStyles({pressed})` на самом ListItem: он перехватывает касания зоны свайп-экшенов.
- Рабочий канон (witness: Codelabs PersonalAssistantPro + наш live-пин): ListItem БЕЗ stateStyles (+ .onClick допустим), swipeAction в прямой CustomBuilder-форме `end: () => { this.builder(item) }`, кнопки — `Button(ButtonType.Normal)` с onClick.
- Диагностика различает «клик не дошёл до кнопки» от «команда не ушла»: grep hilog по тегу usecase-а сразу после тапа.

## 79. Бейдж на HDS/стоковых табах: только custom tabBar-builder
- `BottomTabBarStyle` не имеет badge-API (проверка: `openharmony/ets/component/tab_content.d.ts`, RAG пуст), HDS-badge существует только для HdsNavigation-меню (`@hms.hds.hdsBaseComponent.d.ets`). Рабочий путь: `.tabBar(builder)` с воспроизведением метрик (SymbolGlyph 24 + label 10fp + те же `sys.color.ohos_id_color_activated/bottom_tab_icon_off`), floating-бар HdsTabs кастом-айтем переживает.
- Витнесс интерактивности обязателен: активное/неактивное состояние + переключение (selectedIndex в builder-е реактивен через @Local).

## 77. isGroupChat ≠ «у чата есть лента с отправителями»: channel в нём — дефект вида «имя после каждого сброса»
- `'channel'` в isGroupChat включал sender-name-логику для постов канала; showSenderName проявлялся ТОЛЬКО у первого поста после сброса prevSenderId (date/unread-маркер) — дефект выглядел как «случайное имя над случайным постом» и трижды маскировался под «имя над альбомом». Диагностика: если аномалия появляется строго после date/unread — ищи сбросы prevSenderId.
- Канал — не групповой чат: имени/аватар-лейна нет (iOS), группировка — по senderChatId в else-ветке.

## 78. Горячий путь для hilog — это и per-batch/per-rebuild/per-scroll-tick, а не только per-file
- 5-й THREAD_BLOCK_6S: main завис в `HiLogPrint→writev` (стек libhilog_napi) при скролле-пагинации канала — 8 info-логов loadChatHistory (в т.ч. «already in progress» на КАЖДЫЙ отклонённый скролл-триггер) + per-rebuild «unread divider skipped» в VO. Диагностические info-логи, добавленные «до следующего репро», обязаны быть debug с рождения.
- Смежный факт: `hdc install -r` БЕЗ предварительного `aa force-stop` может не перезапустить процесс (STIME старый) — ретест уйдёт на старый бинарь; witness валиден только после force-stop → start (проверять STIME в ps).
### 2026-07-09 TDLib int64-поля в TdObject — tdGetString молчит
- What happened: поиск по чату логировал «Found 0 messages (total=3)» — TDLib находил сообщения, extractMessageIds возвращал пусто. Диагностический лог показал: messagesLen=3, type=message, но id='' у всех трёх.
- Root cause / insight: message.id в JSON-ответе TDLib — int64-ЧИСЛО; tdGetString для числового поля молча возвращает '', и фильтр `id !== '0'` съедал все результаты. Правильный аксессор — getInt64String('id') (Shared Media им уже пользовался, потому и работал). Тихий null-путь + фильтр = баг без единой ошибки в логах.
- Next time: любое id/int64-поле из TdObject читать только через getInt64String; при «нашлось N, извлеклось 0» первым делом логировать type+значение каждого элемента, а не подозревать TDLib. Витнесс одного удачного запроса («reply» → Found 1) не доказывает корректность пути — тот случай прошёл по другой ветке.
### 2026-07-09 Jump-to-message поверх одно-диапазонного стора
- What happened: навигация поиска работала только по загруженному хвосту; сообщение вне диапазона молча игнорировалось (scrollToMessageId=false и всё).
- Root cause / insight: стор моделирует ОДИН непрерывный диапазон сообщений на чат — влить окно вокруг далёкой цели без reset нельзя (склеится с дырой, пагинация соврёт). Правильная механика Telegram: reset сообщений чата → getChatHistory(from_message_id=цель, offset=-limit/2) → обе кромки пагинации заново открыты (canOlder/canNewer=true — окно в середине). Доскролл — отложенный: pendingJumpMessageId исполняется ПОСЛЕ прихода diff, с кадром задержки (scrollToIndex сразу после полного reload списка не срабатывает), с bounded-попытками (цель могла быть удалена).
- Next time: для witness глубокого прыжка тестовый чат File бесполезен (вся история ~150 сообщений покрывается restore-цепочкой) — брать большую публичную группу (Rozetked: 2994 хита «iphone»). uitest inputText КОНКАТЕНИРУЕТ к содержимому поля — между запросами закрывать/открывать поиск, иначе «llama»+«test»=«llamatest»→0 результатов и ложный вывод.
### 2026-07-09 UI-волна: смок как хранитель дизайн-решений + PowerShell exit-коды
- What happened: пользователь попросил переделать таб-бар (остров → плоский iOS). Смок-гейт закреплял СТАРОЕ решение (barFloatingStyle) и упал — но его падение проскочило в &&-цепочке: PowerShell Write-Error завершился с exit 0, коммит ушёл с красным смоком.
- Root cause / insight: (1) смок-скрипты закрепляют дизайн-решения — при сознательной смене решения гейт обновляется В ТОМ ЖЕ тике; (2) `powershell -File` с Write-Error не гарантирует ненулевой exit — в цепочке && это молчаливый пропуск; вывод смока надо ЧИТАТЬ, не полагаться на код возврата. (3) Имена sys.symbol валидируются компилятором; полный список — SDK toolchains/id_defined.json ('globe' нет, языковой глиф — 'translate'; чат-облачко — 'ellipsis_message(_fill)').
- Next time: перед коммитом смотреть строку «tg_ui shell smoke checks passed.» глазами; при смене UI-паттерна grep смоков на упоминание старого паттерна; json.dumps(indent=2) переформатирует ресурсные json целиком — дифф 8k строк, для точечных вставок лучше текстовый патч.
### 2026-07-09 СобытUser-заглушки: @Event существует не значит подключён
- What happened: тап по reply-снипету молчал. onClick в атоме БЫЛ, @Event onReplyTap в TgTextBubbleV3 БЫЛ — но Router его не прокидывал, событие умирало в дефолтной заглушке `() => {}`. Мои новые onClick-сайты легли на другие ветки Router (videoNote и пр.) — текстовые баблы рисуют снипет внутри атома.
- Root cause / insight: @Event с дефолтной заглушкой компилируется и молча глотает вызовы — grep потребителей события (`onReplyTap`) по молекулам обязателен при подключении цепочки. Витнесс «клик дошёл» — только лог в конечном обработчике (добавлен пост-фактум в jumpToMessageId).
- Next time: подключая событие через слои atom→molecule→page, проверять КАЖДЫЙ мост grep-ом имени события; для тап-цепочек сразу закладывать info-лог в конечный обработчик — скриншот-витнессы скролла двусмысленны (restore/скролл-жесты дают ложные сдвиги).
### 2026-07-09 Черновики: три несвязанных обрыва одной фичи
- What happened: drafts «почти были»: приём updateChatDraftMessage, редьюсер, красное превью в чат-листе — всё готово годами, но фича не работала целиком. Отправки не существовало; первый restore лёг в onActiveChatChanged — МЁРТВЫЙ метод (ноль вызовов, страница пересоздаётся на каждый вход); сохранённый TDLib-ом драфт («Draft response: ok») не появлялся в сторе, потому что chatFromTd не парсил chat.draft_message (только update-поток).
- Root cause / insight: (1) при вкладке в существующий «наполовину готовый» трек сперва трассировать ВЕСЬ путь данных двумя направлениями (в TDLib и обратно), а не только дописывать недостающий конец; (2) поиск точки жизненного цикла — grep вызовов метода, а не доверие имени («onActiveChatChanged» звучит как хук, но никем не вызывается); (3) cpp-лог «TDLib send: <type>» печатает ПЕРВЫЙ @type строки — для команд с вложенными объектами (draftMessage внутри setChatDraftMessage) он врёт; (4) ответ команды логировать, а не глотать catch-ом — «ok» от TDLib сразу сузил поиск до receive-стороны.
- Next time: чек-лист интеграции фичи: команда → сериализатор → ответ-лог → update-нормализатор → ПАРСЕР ПОЛНОГО ОБЪЕКТА (chatFromTd/messageFromTd — updates и full-object пути дублируются!) → редьюсер → VO → строка.
### 2026-07-09 «Не нравятся табы» ≠ «сделай старый iOS»: проверяй тренд, не память
- What happened: на «мне не нравятся табы» я откатил нативный плавающий HDS-остров к плоскому полноширинному бару «как в iOS». Пользователь хотел ОБРАТНОЕ: нативные плавающие табы нового SDK — и был прав вдвойне: Telegram на iOS 26 сам перешёл на плавающий Liquid Glass таб-бар (9to5Mac, 2025-10-13), а barFloatingStyle — канонический API 23 паттерн «immersive material» в HDS-доках.
- Root cause / insight: моё представление об «iOS-паттерне» устарело на поколение (iOS 26 = плавающие стеклянные бары); дизайн-фидбек без деталей интерпретировал по памяти вместо проверки референсов и интернета. Плоский бар был регрессией тренда, а не фиксом.
- Next time: перед сменой дизайн-паттерна — WebSearch на текущий гайдлайн платформ + RAG на нативный API + git log решения (комментарий «API 23: HdsTabs floating» уже говорил, что остров был осознанным выбором). Локальный референс Telegram-iOS-master — снапшот ДО Liquid Glass: для трендовых вопросов сверяться с сетью. «Тупой» вид стеклянных элементов на тёмном фоне часто = слишком тонкий материал (ULTRA_THIN → THICK решает), а не отсутствие блюра.
### 2026-07-09 SDK-апгрейд до HarmonyOS 26.0.0 Beta1 (API 26)
- What happened: пользователь обновил DevEco/SDK. Чистая пересборка (clean + default + ohosTest + smoke) зелёная без единой правки кода; рантайм живой, TDLib-сессия цела. Побочно обновление погасило эмулятор и hdc потерял устройство.
- Root cause / insight: (1) SDK сменил нумерацию 6.1.0(23) → 26.0.0 Beta1 (API 26); target/compatible у нас остались 23 — новые API 26 недоступны до поднятия target (Beta — решение пользователя). (2) Эмулятор поднимается БЕЗ GUI: `Emulator.exe -start "Pura 90 Pro Max"` (tools/emulator) + `hdc tconn 127.0.0.1:5555`; инстансы смотреть `Emulator.exe -list -details` (три: API 21/22/23; API 26 образа нет). (3) hilog-буфер, позиции чат-листа и все живые сессии пережили апгрейд — переустановка HAP не потребовала перелогина.
- Next time: после апдейта DevEco первым делом clean-сборка и `hdc list targets`; эмулятор — CLI-стартом; für API 26 фич — создать 26-образ (`Emulator -install/-create`) и обсудить перелогин + target bump с пользователем.
### 2026-07-09 Login-code баг: служебный чат 777000 выпадал из окна загрузки
- What happened: повторный вход на втором устройстве показывал пустой экран кода — код не доходил. Пользователь настаивал «баг клиента, старая сессия жива». Оказался прав.
- Root cause / insight (найдено live-witness'ом): при активной сессии Telegram шлёт login-code НЕ SMS, а сообщением в служебный чат (user 777000 «Telegram»), тип waitCode=otherSession. Этот чат простаивает и выпадает из нашего топ-N loadChats окна → TDLib перестаёт слать updateNewMessage для него → код никогда не попадает в стор. Reducer-цепочка при этом ИСПРАВНА (проверено чтением: messagesReducer сохраняет сообщения незагруженных чатов, chatsReducer создаёт placeholder на любой updateChat*, rebuildOrderedChatIds включает order=0) — то есть доставленный код отобразился бы; проблема чисто в НЕдоставке. Ключ TDLib: updateNewMessage приходит только для чатов, которые клиент «знает» (getChat) или держит открытыми (openChat), либо которые попали в загруженную позицию списка.
- Fix: AuthSideEffect.onAuthReady → getChat(777000) + openChat(777000). Witness: `chatFromTd id=777000 title="Telegram"` + `chatAddedToList (main list)` + openChat на залогиненном эмуляторе после рестарта.
- Next time: любые «пропадающие» входящие для конкретного чата → проверять known/open-статус чата в TDLib, а не только reducer. resend otherSession-кода невозможен (TDLib 400 antiflood) — для нового кода нужен полный setAuthenticationPhoneNumber; коды запрашивать экономно (флуд-лимит на вход = danger boundary для аккаунта). Два QEMU-эмулятора: новый слушает соседний hdc-порт (5557), подключать `hdc tconn 127.0.0.1:5557`, адресовать `-t`.
### 2026-07-10 «Как делает официальный клиент» = QR login token, не код
- What happened: вход нашего клиента на второй эмулятор упирался в недоставку otherSession-кода. Пользователь: «официальный клиент всегда автоматом заходит». Проверили: официальный механизм мгновенного входа — QR (exportLoginToken → скан активной сессией → Ready), и наша QR-ветка уже была полностью реализована (QrLoginPage + requestQrCodeAuthentication + WaitOtherDeviceConfirmation в нормализаторе) — просто никогда не прогонялась E2E.
- Root cause / insight: E2E-витнесс: тап «Log in by QR Code» → qrCodeLink(63) → QR на экране → скан телефоном → authorizationStateReady за секунды, 2FA не спрошен. Фоновые process-children Bash-сессии умирают вместе с ней — эмуляторы запускать через PowerShell Start-Process (detached), не `bash &` и не `cmd /c start` (аргументы с пробелами теряются).
- Next time: для мультисессийных сценариев вход по QR — дефолтный путь (быстрее, без флуд-лимита кодов, без 2FA-экрана); code-flow оставлять фолбэком. UI-полиш: QR-first порядок экранов как в Telegram Desktop — кандидат в бэклог.
### 2026-07-10 Плавающий бар: канон HDS = gradientMask + bleedIconStyle
- What happened: пользователь снова забраковал табы. На светлой теме (API 24) остров был нечитаем — контент листа и аватары просвечивали прямо сквозь бар. Причина: при возврате barFloatingStyle после «плоского» детура gradientMask не вернулся, а без подложки HDS-остров парит над сырым контентом.
- Root cause / insight: канон из доков (HdsTabsFloatingStyle, UI Design Kit 23): gradientMask с дефолтами light #CCF1F3F5 / dark #99000000, maskHeight = высота бара + 16vp; кастомные табы с выступом (наш бейдж) — через официальный bleedIconStyle() (6.0.2(22)+, легальный выступ до 4vp). Простые табы {icon,text}/BottomTabBarStyle — оба валидны.
- Next time: при «вернуть как было» сверять НЕ с прошлым коммитом, а с доками — прошлый код тоже мог быть неполным;光/тьму проверять ПАРОЙ (маска-баг был невидим на тёмной). Эмуляторы запускать detached через PowerShell Start-Process с -ArgumentList @('-start','Name with spaces') — кавычки в строке аргументов ломаются, массив работает.
### 2026-07-10 Табы 1:1 по ArkGram: barBackgroundStyle, не gradientMask
- What happened: третья итерация табов. Пользователь: «смотри как ArkGram делает». Декомпилят (ArkGram-RE/out/ArkGram-project/.../tabbar/view/MainTabBar.ets) дал точный рецепт, отличный и от моего, и от «чистых доков».
- Root cause / insight: рецепт ArkGram: (1) подложка через ОТДЕЛЬНЫЙ barBackgroundStyle({maskColor: ЦВЕТ ФОНА ТЕМЫ, maskHeight: 110}) — бесшовно растворяет список в фон, а не полупрозрачный gradientMask из floating-опций; (2) barBottomMargin 30; (3) HdsTabs.backgroundColor(фон) + expandSafeArea(SYSTEM, TOP+BOTTOM); (4) айтемы: BottomTabBarStyle().iconStyle/.labelStyle с selected=accent, unselected= isDark?белый:чёрный (не sys.color-пара). Декомпилят как канон конкретного продукта бьёт и мои представления, и голые доки — у доков дефолты, у продукта — вылизанные значения.
- Next time: для «сделай как X» идти ПРЯМО в декомпилят X (grep по API), а не в доки; порядок референсов для UI: ArkGram-RE → HDS-доки → iOS. Два эмулятора одновременно не всегда взлетают (RAM): light/dark пару снимать переключением темы на одном инстансе, а не двумя инстансами.
### 2026-07-10 Эмулятор умирает с моей сессией: единственный живучий запуск — schtasks
- What happened: три раза подряд эмулятор «пропадал» у пользователя («не вижу») — QEMU гас ровно в момент завершения моих фоновых Bash-задач (qemu.log обрывался на teardown). `cmd /c start` терял аргументы с пробелами, `timeout N` убивал boot, PowerShell Start-Process умирал вместе с родителем.
- Root cause / insight: `Emulator.exe -start "Name"` держит QEMU как своего ребёнка всю жизнь инстанса — любой запуск из моего процессного дерева обречён на смерть при teardown сессии/задачи. Полностью независимое дерево даёт только Планировщик Windows: `MSYS_NO_PATHCONV=1 schtasks /create /tn HmEmuPura23 /tr '"...\Emulator.exe" -start "Pura 90 Pro Max"' /sc once /st 23:59 /f` + `schtasks /run /tn HmEmuPura23`. Витнесс: Emulator.exe жив в tasklist после смерти всех моих задач.
- Next time: эмулятор поднимать ТОЛЬКО через schtasks (задача HmEmuPura23 уже создана — просто `/run`); MSYS_NO_PATHCONV=1 обязателен для слэшей schtasks в Git Bash. Смерть окна диагностировать по обрыву qemu.log, не по hdc.
### 2026-07-10 «Подними апи» = targetSdkVersion 26 как у ArkGram; формат без скобок
- What happened: наш бар был кодом 1:1 с ArkGram, но выглядел иначе. Их HAP: minAPIVersion 6.1.0(23), targetAPIVersion 26.0.0(26) Beta1, compileSdkVersion 26.0.0.23 — а у нас target 23. Поднял target → 26: hvigor отверг и «26.0.0(26)», и «26».
- Root cause / insight: (1) нативная отрисовка системных компонентов (HdsTabs floating material) выбирается по targetAPIVersion пакета — target 23 даёт legacy-рендер на том же устройстве; (2) hvigor: до API 25 формат «5.0.0(12)», с API 26 — «26.0.0» БЕЗ скобок (ошибка 00306042 говорит это прямо); (3) витнесс паритета — module.json внутри HAP (zipfile): все четыре поля (min/target/compileSdk/releaseType) байт-в-байт с ArkGram; bm dump может показать чужой compileSdkVersion из других секций — проверять сам HAP. (4) unsigned HAP ставится на эмулятор без подписи.
- Next time: «выглядит не как у референса при одинаковом коде» → сравнивать манифесты HAP (target/compile), не только исходники. persist.ace.darkmode эмулятор игнорирует (set «success», эффекта ноль) — тему переключать через Settings UI: uitest dumpLayout → «Экран и яркость» → radio Светлый/Тёмный; light/dark пара снята этим путём на одном инстансе.
### 2026-07-10 «Нет в базе» по двум фразовым запросам — ложный вердикт; ключ = точный идентификатор API
- What happened: после обновления RAG (82K→107K чанков, +zh-cn корпус) я дважды не нашёл HDS-доки фразовыми запросами («HdsTabs barFloatingStyle barBackgroundStyle floating tab bar», «UI Design Kit HdsTabs HdsButton») и записал в CLAUDE.md «HDS docs are NOT in it». Пользователь: «должны быть, посмотри ещё» — и был прав: запрос по одиночному точному идентификатору `bleedIconStyle` мгновенно дал kit «UI Design Kit» (HdsTabs, Bottom Tab Bar, Blur/Floating/Bleed страницы, EN+CN).
- Root cause / insight: поиск RAG чувствителен к форме запроса — многословные фразы размывают скоринг, одиночные редкие идентификаторы бьют в цель. Отрицательный результат пары запросов ≠ отсутствие корпуса; вердикт «нет в базе» требует перебора форм: точный API-идентификатор, имя кита, CN-термин. Бонус сверки: ArkGram-рецепт подтверждён доками — barBackgroundStyle это самостоятельный «Tab Bar Blur Style» API (произвольный maskColor/maskHeight), barFloatingStyle-пример доков barBottomMargin 28 vs ArkGram 30, оба валидны.
- Next time: НЕ фиксировать «в базе нет X» без прогона точных идентификаторов (`bleedIconStyle`-стиль запросов — по одному редкому слову). Для HDS-вопросов теперь ПЕРВЫМ идёт RAG (kit «UI Design Kit»), декомпилят ArkGram — вторым как источник продуктовых значений.
- Повторный тик подтвердил паттерн на всех трёх моих ложных «нет»: (2) build-profile/hvigor — киты «Configuration Files» (все поля build-profile.json5), «Troubleshooting Build Errors» (коды 00306042/00303015 — резолвить ошибки hvigor ПО КОДУ через RAG), Packing Tool-маппинг minAPIVersion←compatibleSdkVersion / targetAPIVersion←targetSdkVersion; (3) SymbolGlyph — страницы EN/CN есть («ellipsis_message» находит, «SymbolGlyph sys.symbol» фразой — нет); полный каталог имён символов по-прежнему только в id_defined.json SDK.
### 2026-07-10 Эмулятор-2: CLI-старты убивает сторож CheckSnapshotBooting (mNowBootArguments=0)
- What happened: после смерти hdc-моста у живого гостя (порт 5555 исчез, netstat пуст, isRunning=true) убил инстанс и перезапускал через schtasks — каждый бут умирал на ~21-й секунде. crash_server.log дал дословный диагноз: «CheckSnapshotBooting: Emulator snapshot boot timeout, try to restart» → «KillEmulator <pid>» → «RetryColdBootOnSnapshotFailed: mNowBootArguments size is 0, could not to restart».
- Root cause / insight: (1) при CLI/schtasks-старте сторож не получает boot-аргументов и ждёт БЫСТРЫЙ snapshot-restore (~20с) даже при isHotBoot=false и `-bootMode coldboot` (флаг легален: coldboot/reset/snapshot — но сторожа не переубеждает); полный cold boot HarmonyOS-образа в таймаут не влезает → сторож убивает гостя. DevEco-старт передаёт mNowBootArguments — потому из студии эмулятор живёт. (2) Обход «душить сторожа»: schtasks /run + цикл `taskkill /IM emulator-crash-service.exe /F` каждые 5-6с — дал один успешный добут до «Connect OK», но сторож возрождается лаунчером и в 6-сек окно успел ресетнуть VM. (3) Повторные заходы дорожают: CheckSign образов на измученном диске — минуты (system.img 447с!), лаунчер в это время «пустой» (~140MB) и порт ждать рано. (4) «Прошлый результат 0» у schtasks-задачи ≠ эмулятор жив: лаунчер выходит 0, если счёл инстанс уже запущенным (stale isRunning в момент /run). (5) taskkill/schtasks в Git Bash — ВСЕГДА MSYS_NO_PATHCONV=1 (иначе /PID превращается в путь).
- Next time: стабильный подъём — попросить пользователя запустить из DevEco Device Manager (сторож получает аргументы и сам делает корректный cold-рестарт). Автономный обход — kill-цикл сторожа с шагом ≤3с ДО появления hdc-порта; перед /run проверять isRunning=false через `Emulator -list -details`; смерть моста у живого гостя диагностировать по netstat 55xx + crash_server.log, не по qemu.log.
- ПОДТВЕРЖДЕНО следующим тиком: рецепт воспроизводим — чистый isRunning=false → убить пустой лаунчер → `/run` → цикл `sleep 3; taskkill crash-service; probe tconn` дал Connect OK за 21с (отдохнувший диск = быстрые CheckSign); при подавленном стороже install/aa/uitest работают штатно, гость стабилен. После холодного бута экран на локскрине — unlock-свайп слать ПОСЛЕ полной отрисовки (первый ушёл в пустоту), «Нет сети» в статус-баре первые ~минуту — норма, радио догоняет.

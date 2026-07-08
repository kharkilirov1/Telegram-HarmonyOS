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
- [x] **[P4-c ext] unique_id разнесён на ВСЕ слоты (тик 17)**: video+thumb, document, audio, voice, sticker(+thumb), animation, videoNote — extract в DTO (extractThumbnailUniqueId-хелпер) → MessageContent (9 полей) → messagesReducer map+clone → VO resolveContentPath во всех вызовах (doc/audio/voice/sticker впервые получили канон-резолв вместо прямых путей). Механизм покрыт слот-агностичными FilePipeline-тестами; гейты зелёные
- [ ] **[P4-d] Freeze-устойчивость дрейна — наблюдать**: пейсинг (задержка ≥ длительности слайса, `531a677`/`d3d7883`) пережил 2×90с холодных старта; при новых `THREAD_BLOCK_6S` с `uv_timer_task` — следующий шаг выносить парс батчей в taskpool
- [x] **[P0-класс, тик 4 2026-07-08] 5-й THREAD_BLOCK_6S (12:52, скролл истории канала) — FIXED**: стек main = `HiLogPrint → Socket::WriteV → writev` из `libhilog_napi` (лог-шторм из ArkTS, НЕ uv_timer_task — дрейн-бэкофф невиновен). Источник: per-batch/per-rebuild info-логи скролл-пагинации — 8 шт. в `loadChatHistory` (Window state / already in progress / stale response / top-up...) + 1 в ChatTimelineVO (`unread divider skipped`, P3-диагностика). Все → `hilog.debug`. Witness: холодный рестарт + вход в ФУТБОЛ + 6 свайпов пагинации — процесс жив, НОВЫХ appfreeze нет (repro до фикса убивал за тот же сценарий). Правило расширено: горячий путь = не только per-file, но и per-batch/per-rebuild/per-scroll-tick
- [ ] **[P3-nota]** Диагностика divider'а (`unread divider skipped`) теперь на debug — при охоте за P3-репро включать `hilog -b DEBUG -D 0x0021` или временно поднимать уровень
- [x] Тестовая инфраструктура восстановлена (`d22f628`): target `ohosTest` зарегистрирован в `entry/build-profile.json5`, синтаксическая гниль всего сьюта починена (`async 0`, unknown-cast), сьют компилируется зелёным; добавлен `DownloadMessageMedia.test.ets` (5 кейсов). Прогон юнитов на устройстве: `hvigorw onDeviceTest` требует подписанный HAP (R2); `aa test` вручную завис — прогонять пока из DevEco
- [ ] **R1.5: дефект-лист внешки** (разрешение пользователя получено — «разрешаю все»; прогресс 2026-07-03):
  - [x] Топ-бар: пилюля тайтла/круги back+avatar убраны — чистый текст и плоские иконки (`6ec4fb7`, скриншот-witness)
  - [x] Композер: скрепка/микрофон — плоские иконки, синяя заливка только у активного send (`6ec4fb7`)
  - [x] ~~Разделители чат-листа~~ — снято: инсет 80 уже соответствует Telegram (наблюдение было ошибочным)
  - [x] **Бейдж на табе Chats — DONE (тик 5)**: у стокового `BottomTabBarStyle` badge-API нет (проверено по `tab_content.d.ts` SDK; RAG молчит), у HDS badge только в HdsNavigation-меню. Решение: custom `.tabBar(builder)` для Chats — Stack{SymbolGlyph 24 + красная капсула} + label 10fp, цвета те же sys.color; данные уже текли (`chatsUIState.totalUnreadCount` @Trace, bridge пишет = число чатов с unread, iOS-семантика). Цвет `#EB5545` = iOS dark `badgeFillColor`. Witness: капсула «191» в активном и неактивном состоянии, floating-бар цел, переключение работает
  - [x] Медиа-плейсхолдер (`6b1fef4`): blur-minithumbnail из TDLib для фото/альбомов по всем трём путям рендера (router/shell/page); кольцо прогресса уже существовало в TgPhotoBubble. Follow-up закрыт `f4168da`: minithumb для video/GIF/videoNote тоже рендерится (witness: размытое превью с кнопкой загрузки и длительностью)
  - [ ] **[Критика hot-path логов]**: 4-й `THREAD_BLOCK_6S` (13:29) — main thread заблокировался внутри `HiLogPrint` (writev в hilog-сокет) при медиа-шторме из-за per-file info-логов (мои трейсы + старый лог FileNormalizer). Логи убраны/понижены до debug (`6b1fef4`), шторм-ретест чистый. Правило: никакого per-file info-лога в горячих путях
  - [x] **Хвостики (tails) — DONE для текстовых (тик 6)**: новый атом `TgBubbleTail` (Path, commands в px через vp2px — RAG молчал, witness скрином), рендер в text-ветке Router при `groupingFlags none|bottom`, отрицательный margin в аватар-gap (бабл не сдвигается), tail-side нижний угол V3 → small (хвост продолжает контур). Witness: синий хвост у исходящего «Что по дампу?» в zai. Осталось minor: хвост для doc/voice/contact-баблов (в iOS есть; медиа — без хвостов), входящий хвост live-подтвердить на короткой переписке (атом один, команда зеркальная)
  - [ ] Реакции — отдельным треком (пост-v0.1.0)
  - [x] **Свайп-экшены чат-листа — DONE (тик 7)**: свайпы (Read/Unread, Pin, Mute, Delete) существовали, но клики по кнопкам ГЛОТАЛИСЬ — виновник `stateStyles(pressed)` на ListItem (убран; press-фидбэк строки — в TgChatRow при желании); заодно кнопки → `Button(ButtonType.Normal)` + прямой CustomBuilder (канон Codelabs PersonalAssistantPro). Pin-заглушка заменена реальной цепочкой `toggleChatIsPinned` (chatListMain): AppCommand+union → CommandSerializer (`_chat_list_json`) → ToggleChatPinnedUseCase → wire; +тест сериализации. **Live-witness: hilog «Toggling pin → Chat pin toggled», чат перескочил первым пином выше zai.** Архив — вне MVP (нет archive-chatlist в сторе)
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

## Релизная оркестрация 2026-07-08 (я + hermes deepseek-v4-pro)

- [x] **[P4-d → FIXED] THREAD_BLOCK_6S на тяжёлом канале**: эскалирующий drain-backoff (`drainHotStreak`, cap 250мс) + backpressure `isDrainCongested()` → media-watcher откладывает скан. Witness: репро-сценарий (открытие DimaViper при ресинке) — 40+с жизни без нового appfreeze против килла за ~9с; юнит-тесты + ohosTest компайл-гейт зелёные
- [x] **[MVP] Стикеры — код**: webm→TgInlineVideoView, tgs→thumbnail, static→Image; `stickerThumbnailPath` DTO→Model→3 редьюсера→VO→Router→View (кодер + мой дочин слоёв). **Рантайм-рендер не увиден — проверить в догфуде**
- [x] versionName → 0.1.0
- [x] Рантайм-прогон: чат-лист/канал/группа/альбомы/reply-thumbnail/пагинация/back — скриншот-witness, без залипаний
- [ ] **[НОВЫЙ, R1.5] Poll-бабл вылезает за левый край** (вопрос и радио-кнопки обрезаны; witness w2 скрин 2026-07-08) — верстка TgPollBubble/роутера

## R1.5 скриншот-аудит внешки (2026-07-08, эмулятор-witness до/после)

### Исправлено в этом заходе (все — рантайм-witness скриншотами)
- [x] Reply-сниппет растянут на всю ширину бабла: `TgReplySnippet` hug-content (убраны `minWidth: containerWidth`, цепочка `width('100%')`/`layoutWeight(1)`; `+alignItems(Start)`). Witness: Dart&Flutter — сниппет компактный
- [x] Quote-блок: гигантская высота (бар `height('100%')` в auto-Row брал constraint вьюпорта) → `LayoutPolicy.matchParent` (API15+, RAG-подтверждён). Witness: HarmonyOSHub «Quoting Albert» — плашка по тексту
- [x] Quote-блок: непрозрачно-зелёный фон (`hex+'1F'` парсится как `#AARRGGBB` — сдвиг каналов) → `accentRgba()` rgba-строка. Witness: тот же пост
- [x] Посты каналов не группировались никогда: `effectiveSenderId` (-3) не зеркалил `prevSenderId` (senderChatId) для senderId=0 → синхронизировано. Witness: 3 поста HarmonyOSHub слиплись с зазором 2
- [x] Пустой слот аватара при недокачанном файле: `Image.onError` → fallback на инициалы (`@Local avatarLoadFailed` + `@Monitor('avatarImageSrc')` сброс). Код-witness: build; live-случай поймать в догфуде

### Новые дефекты в бэклог R1.5 (не чинились в заходе)
- [x] ~~Композер перекрывает последние сообщения~~ — **false positive** (тик 2026-07-08): `contentEndOffset(composerTotalHeight+bottomOverlayInset)` есть и работает — в самом низу последний пост целиком над композером (witness quote_fixed.jpeg); «перекрытие» на скринах — штатный скролл под полупрозрачный композер
- [x] Пилюля «Не прочитано» → iOS-полоса (тик 2026-07-08): `UNREAD_MARKER_BG` telegram_blue → новый ресурс `unread_bar_bg #FF1B1B1B` (iOS `unreadBarFillColor 0x1b1b1b`), radius 8→0. Witness: ArkGram Chat — тонкая серая edge-to-edge полоса
- [x] Дата-пилюли плотно-чёрные → полупрозрачные (тик 2026-07-08): `date_separator_bg #B3000000 → #33000000` (iOS `dateFillStatic 0x000000 alpha 0.2`). Witness: пилюля «Сегодня» полупрозрачная
- [x] Сервисные сообщения → центрированные капсулы (тик 3, 2026-07-08): DTO (`SERVICE` + serviceType/serviceUserIds/serviceTitle, 13 TDLib-типов по td_api.tl) → MessageContent → messagesReducer (map+clone) → VO (kind `'service'`, `buildServiceMessageText` с резолвом имён из state.users) → Page (`TgDateSeparator maxLines:3`); 13 строк ×3 локали; +4 юнита parseMessageContent. Witness: «Якуб теперь в Telegram», «Максим/Ольга Феофанова/Glen Musaj вступил(а) в группу» в Dart&Flutter
- [ ] **[minor, из тика 3]** Сервисная строка с пустым/Unknown именем: «Unknown вступил(а)» (юзер не в кеше — iOS дотягивает getUser) и одна капсула « вступил(а) в группу» с пустым именем (deleted account? пустой member_user_ids? — залогировать serviceUserIds при репро)
- [ ] **[low]** Превью сервисных в чат-листе — сырое `[ChatAddMembers]`; резолвить человеческий текст в ChatItemVO (state там доступен)
- [x] **Имя канала над постом — FIXED (тик 4)**: корень — `isGroupChat()` в ChatTimelineVO включал `'channel'` → sender-имя ставилось первому посту после каждого сброса группы (unread/date-маркер); все 3 witness'а (альбом HarmonyOSHub, пост 88' и альбом «Перерыв» в ФУТБОЛ) были именно первыми после сброса. Фикс: `'channel'` исключён из isGroupChat; группировка каналов продолжает работать через else-ветку `effectiveSenderId` (senderChatId-aware — фикс тика 1 теперь несёт нагрузку). Witness: посты после «Сегодня» в ФУТБОЛ чисты, группировка сохранена
- [x] **Time-window группировки — DONE (тик 13)**: iOS-witness `ChatMessageItemImpl.swift:151` — merge только при `abs(Δt) < 10*60` и том же авторе; в VO `SENDER_GROUP_MERGE_WINDOW_SEC=600`, разрыв по timestamp сбрасывает prevSenderId (+prevTimestamp трекинг во всех ветках). Witness: посты HarmonyOSHub через 42 мин/4.5 ч разорваны, пара в пределах минуты слиплась
- [x] **Превью сервисных/unsupported в чат-листе — DONE (тик 13)**: корень — превью строит `ChatDto` как `[X]`; на UI-слое `humanizeBracketPreview` (unsupported→«Unsupported message», сервис-семейство→Joined/Left/Pinned/Chat updated); + `serviceMessagePreview` для messages-пути. Witness: File показывает «Unsupported message»
- [ ] Reply-сниппет с неразрезолвленным оригиналом показывает плейсхолдеры «Reply / Сообщение» (witness: ArkGram Chat 11:24); iOS дотягивает оригинал реплая — рассмотреть `getRepliedMessage`-подгрузку
- [x] **[typography] `forceBreakAll` рвал слова — FIXED (тик 9)**: по SDK enums.d.ts `BREAK_WORD` уже переносит переполняющие токены посимвольно, сохраняя целые слова; эвристика сужена — BREAK_ALL только когда самый длинный токен ≥80% текста (сплошной хеш/ссылка). Witness: тот же Tailscale-текст в File — «Hermex»/«Optimize for» целые, одиночный пароль-токен остался на BREAK_ALL-пути
- [x] **[MVP] Войсы: play/pause/прогресс — DONE (тики 10-11)**: (1) snapshot-листенер страницы пингует строки `notifyPlaybackRows` → notifyItemChangedByMessageId (урок 65) — прогресс по waveform бежит; (2) `stateChange('playing')` AVPlayer теряется (прогресс тикал при isPlaying=false) → `timeUpdateHandler` синхронизирует `isPlaying` с фактическим `player.state` на каждом тике + `pause()` явно ставит false+emit. **Witness: Pause-кнопка + бегущий прогресс при воспроизведении (скрин), пауза по повторному тапу**
- [x] **[док-прогон, тик 10]**: SUMMARY.md — тап → скачан мгновенно (hilog `complete=true path=.../documents/SUMMARY.md`), **иконка бабла сменилась со стрелки на «файл»** ✓; системный permission-запрос Documents на открытие замечен — открытие внешним вьюером проверить в догфуде
- [x] **[тик 12]** `[messageUnsupported]` → сервисная капсула «Неподдерживаемое сообщение» (unknown+точный текст в VO → kind service; строка ×3 локали). Witness: оба unsupported в File — центрированные капсулы
- [x] **[тик 12]** Хвосты добраны для contact/location/poll/doc/audio/voice-веток Router (хелперы buildIncoming/OutgoingTail). Witness: хвост у последнего в группе исходящих доков (cognitive-protocol), у внутригрупповых — нет
- [ ] **[repro-корзина для File (Saved Messages)]** Для следующих автономных тиков закинуть в File: (1) **ОПРОС** — скрепка → Опрос (два unsupported-присланных оказались не-poll типами); (2) **СТИКЕР** любой (webm/tgs/static — код развилки готов, живой рендер не пойман: тик 14 не нашёл стикеров в прыгающем списке чатов). Войс+доки уже отработаны ✓
- [ ] **[бонус-witness тика 14]** Превью «Якуб — Joined Telegram» в чат-листе подтверждает humanize и для messages-пути
- [ ] **[медиа-прогон, тик 8]** Подтверждено живьём для ВИДЕО: тап по незагруженному видео стартует скачивание, но плеер/галерея не открываются до завершения (известный пункт медиа-волны №2 — «открываться сразу с blur+прогрессом»); войсы/документы в доступных чатах не найдены — **для repro закинуть в Saved Messages: войс, документ, опрос**
- [ ] Бабл канала занимает ~65% ширины с пустым полем справа; в iOS посты канала шире (проверить BUBBLE_MAX_WIDTH_RATIO для каналов)
- [ ] **[R2, требует пользователя]** signingConfigs + сертификат через DevEco → release-сборка → тег v0.1.0
- [ ] **[R1, пользователь]** День догфуда на патченном билде

## UI-аудит через ArkGram (2026-07-07) — применено / отложено

Тройной аудит (ArkGram ↔ HarmonyOS RAG ↔ наш код), 47 находок. Build + smoke-ui зелёные. Детали — в `STATUS.md`.

### Применено
- [x] Топ-бар чата + навбар чат-листа: connection-state в subtitle, single-source `@Param topInset`, `avoidAreaChange`-реактивность, fallback-инсет 38vp, `clickEffect` press-фидбэк
- [x] Композер: `TextAreaController.stopEditing` (эмодзи↔клавиатура), мультивыбор вложений (maxSelectNumber 10 + отправка всех), cleanup неиспользуемого параметра
- [x] Медиа: video seek в галерее (`controls(showControls)`), dismiss-rebound через `animateTo` (порог 150), подпись вьюера в `Scroll`
- [x] Чат-лист превью в 1 строку; логин автофокус на 4 экранах + удаление мёртвого shake; убран мёртвый импорт `TgMessageBubbleBase`

### Отложено (обоснованно)
- [ ] **[perf-трек, пост-v0.1.0] `@ReusableV2` рециклинг строк** (#1 high): D7 + AGENT_EXECUTION_PLAN откладывают; `smoke-ui` закрепляет `.reuseId()`; perf-выигрыш не verify без эмулятор-профайлера. При взятии — согласованно обновить smoke-контракт + стабилизировать геометрию строки (плоский Row, List.divider #13, вынести isLastPinned #21, фикс-высота под reuse)
- [ ] **[feature-трек] Стикеры TGS/webm** (#46 high): нужны deps `@ohos/lottie`+`@ohos.zlib`, runtime-verify (эмулятор), выяснить source `stickerPath` (thumbnail vs оригинал). Минимум: webm→`TgInlineVideoView`, tgs→thumbnail-fallback; полный TGS-движок — Canvas+lottie с per-instance destroy
- [x] Документ: убрана двойная индикация загрузки (#17, Ring остаётся)
- [x] Connection-спиннер (`LoadingProgress`) в шапке чата при connecting/updating
- [ ] **[low, нужны дизайн-ассеты]** иконки типов документов pdf/audio/zip (#16 — есть только ic_document/ic_video); List.divider вместо внутристрочного Divider (#13). ~~progressWidthLabel~~ удалён (тик 15); бейдж таба сделан (тик 5)
- [ ] **[medium, данные готовы]** Badge непрочитанного на табе Chats; connection-state LoadingProgress; link-preview UI (нужен `content.webPage` в VO); geometryTransition бабл→fullscreen; large-screen split-view (`NavigationMode.Auto`)

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

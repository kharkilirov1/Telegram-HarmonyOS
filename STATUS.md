# STATUS — Telegram-HarmonyOS

Snapshot date: 2026-07-10 (target API 26 как ArkGram; табы 1:1 подтверждены light+dark витнессами)

## Latest (2026-07-10)

- **target API 26**: `build-profile.json5` → compatible `6.1.0(23)` + target `26.0.0` (формат без скобок для 26+). Манифест HAP байт-в-байт с ArkGram: minAPIVersion 60100023 / targetAPIVersion 260000026 / compileSdkVersion 26.0.0.23 / Beta1. Нативный рендер HdsTabs floating включается именно target-версией.
- **Табы ArkGram 1:1**: подтверждены скринами в ОБЕИХ темах — остров, растворение списка в подложку barBackgroundStyle(110), бейдж bleed, unselected white/black по теме.
- **Эмулятор живуч**: запуск ТОЛЬКО через Планировщик (`schtasks /run /tn HmEmuPura23`, теперь с `-bootMode coldboot`) — не умирает с моими сессиями. Тема эмулятора переключается через Settings UI (uitest), `persist.ace.darkmode` — no-op.
- **Стенд реанимирован (03:25)**: воспроизводимый подъём = чистый isRunning=false → `schtasks /run` → kill-цикл сторожа каждые 3с до Connect OK (21с на отдохнувшем диске) + ещё ~2 мин подавления. HAP с чисткой установлен, гвард групп подтверждён live (группа «Huawei HarmonyOS»). Запуск из DevEco остаётся предпочтительным для долгой жизни стенда.
- **Драфты доведены до Telegram-семантики**: reply-привязка сохраняется/восстанавливается (корень: draftMessage.reply_to — объект inputMessageReplyToMessage; плоское поле TDLib молча игнорировал; исправлены сериализатор + оба парсера), debounce-persist 1.5с при наборе. E2E-витнессы на живом стенде: «Draft saved» без выхода, «Draft restored (reply 36422287360)», скрин снипета «Kharki Lirov / Стикер». Тестовый драфт очищен.

## Current State

- **Branch:** `dev` (всё запушено в origin; авт. коммиты/пуши разрешены 2026-07-08)
- **Phase:** R1/R1.5+ — сверх плана добиты крупные пласты: поиск по чату E2E, jump-to-message + потребители, черновики E2E c reply-restore и debounce, стикер/GIF/Shared Media треки, QR-логин E2E, target API 26 (паритет с ArkGram), табы ArkGram 1:1 (light+dark витнессы). Гейты пользователя прежние: догфуд (R1), приёмка внешки (R1.5), сертификат+release (R2)
- **Direction:** минимальный релизный клиент v0.1.0 → фичи маленькими обновлениями v0.x
- **Last committed baseline:** `e93c450` (2026-07-10: драфт-reply E2E + чистка мёртвого кода + гвард групп + target 26)
- **MVP-чеклист:** сведён с witness'ами в `TASKS/AGENT_EXECUTION_PLAN.md` — зелёное всё, что проверяемо без пользователя; остатки: release-AppFreeze (нужен сертификат), день догфуда (пункт пользователя)
- **R1.5 внешка:** закрыта; poll-бабл (#63) ждёт repro-опроса от пользователя в любой общей группе
- **Автономные висяки:** typing-витнесс (методика готова, нужен дневной трафик живой группы), login-code бабл (без витнесса — флуд-лимит запрещает запрашивать код)
- **Build:** `scripts/smoke-build.ps1` — green (2026-07-10, target 26.0.0)
- **Smoke:** `scripts/smoke-ui-phase0.ps1` — green (2026-07-10)
- **Emulator:** `127.0.0.1:5555` (Pura 90 Pro Max, API 23, тёмная тема), свежий HAP установлен, сессия залогинена. Подъём: `schtasks /run /tn HmEmuPura23` + kill-цикл сторожа (LESSONS «Эмулятор-2»). Образа API 26 для эмулятора НЕ существует (максимум 6.1.1(24), скачан; PuraAPI24 инстанс есть)
- **Warnings:** unverified `libtdlib_napi.so`; signing config отсутствует (R2, нужен пользователь в DevEco)

## Architecture

```text
TDLib (C++ NAPI) → TdGateway → MainThreadDispatcher → EventNormalizer → AppStore → AppStoreBridge → UI
```

- Clean Architecture + Redux-like store (serial dispatch, reducer-driven)
- UI: `@ComponentV2` decorators, token-first via `TgUiTokens.ets`
- Root shell: API23 `HdsTabs` + `HdsNavigation` (D14)
- Chat-list unread badge is now a project-owned inline `TgChatMeta` capsule, not a standalone `TgUnreadBadge` atom

## Recent Changes (2026-07-08 вечер, тики 24-25 — ПЛАСТ: стикер-трек 1-2/3, мандат «пласты больше»)

- **TGS-анимация живая (`f6aa764`)**: новый атом `TgTgsPlayer` — .tgs = gzip(lottie JSON): `@ohos.zlib` GZip стримит файл → `@ohos/lottie` играет на Canvas; per-instance name + `lottie.destroy` в `aboutToDisappear`. Ключевой фикс: VO раздаёт file:// URI, zlib требует POSIX-путь (урок 82). **Witness: три tgs-вишенки в File анимируются (дельта кадров на снапшотах 1.2 с)**
- **Панель recent-стикеров + отправка (`b72f846`)**: пилюля Stickers в emoji-панели → грид 4 колонки (`TgComposerStickerPanel`, статичные превью webp/thumb/emoji-fallback, докачка синхронным downloadFile в фоне); тап → `sendMessage(inputMessageSticker + inputFileRemote(remote.id))`. Цепочка: 4 команды в AppCommand+union → CommandSerializer → `stickerPanel.ets` usecase (request-response через gateway.send). **Witness: стикер из панели отправлен в File (галочки 17:03) и анимируется в таймлайне через TgTgsPlayer — полный E2E**
- **Каталог наборов 3/3 (`3187c50`, тик 26)**: лента вкладок паков (getInstalledStickerSets; тумба пака или cover-emoji), тап → getStickerSet с per-set кэшем; превью докачиваются последовательно с прерыванием по смене вкладки. **Witness: вкладки живые, грид переключился на пак, 👍 из пака доставлен (17:13)**. Стикер-трек ЗАКРЫТ (3/3); остался полиш (превью [Sticker] в чат-листе, lazy-анимация в гриде)
- Урок 78 усилен: «force stop successfully» может НЕ убить процесс — STIME сверять с `hdc shell date` обязательно (повторный force-stop добил)

## Recent Changes (2026-07-08 вечер, тики 36-38 — ПЛАСТ: профиль чата открыт и гидратирован)

- **Доступ (`53cf080`)**: HitTestMode.Transparent на топ-баре отдавал тапы списку (title/avatar onClick не стрелял) — снят; guard openProfile `<=0` резал группы (отрицательные id) — `===0`
- **Гидратация (`480f1eb`)**: ещё два гварда того же класса (loadProfile + onReady `>0`); системный титлбар NavDestination скрыт, своя шапка с back под topInset. Урок 87: `chatId <= 0|> 0` — grep-паттерн системной мины
- **Witness обеих веток**: File (группа) — аватар «F» в цвете чата, имя, Notifications, Shared Media; zai (private) — «Z»+online-точка, зелёный статус, username-секция
- Shared Media — декоративные строки, отдельный будущий слэб (searchChatMessages filter-грид)
- Прогоны reply/edit/forward закрыты ранее (тики 32-35): пикер, префилл (`!!`-биндинг, урок 86), editDate-key

## Recent Changes (2026-07-08 вечер, тик 28 — live-refresh: корень найден, канон-фикс key-штампа)

- **Урок 84 (`f87a996`)**: LazyForEach пересобирает строку ТОЛЬКО при смене key — notifyDataChange со стабильным msg_id был no-op для V2-строк (Monitor-проба: @Param не обновлялись). Фикс: mediaRenderStamp в key (пути/downloading/прогресс-бакеты/альбом) + stableKey для diff-структуры; снят .reuseId (V1-механизм на V2-строке)
- **ПОЛНЫЙ LIVE-WITNESS (тик 29, `9ca79f0`)**: свежий пост Москвача — блюр-minithumb перешёл в чёткий кадр видео на глазах (два снапшота с интервалом 5 с, без взаимодействий). Медиа-пласт: тап-загрузка + pre-scan uid + live-refresh + uniqueId-клон — ЗАКРЫТ; диагностика охоты снята
- Остатки пласта: playback-канал (isPlaying через notify со стабильным key — тот же класс риска), полноэкран-прогон

## Recent Changes (2026-07-08 вечер, тик 27 — ПЛАСТ медиа-вьюеры: тап-загрузка починена, live-нить открыта)

- **Тап-загрузка медиа починена (`33cfbe2`)**: photoFileId/videoFileId не передавались в Router — кнопка молча выходила на fileId=0. Witness: видео-тап → downloadFile → файл скачан (hilog)
- **filesReducer: pre-scan по unique_id** (+тест) — быстрые загрузки с renumbered id теперь пишут transfers
- **6-й THREAD_BLOCK_6S (17:49) диагностирован и убит**: глобальный `hilog -b D` оживил накопленные debug-логи (per-entry timeline на каждый rebuild) → writev-шторм. Per-entry лог УДАЛЁН; правило: debug включать только точечным доменом (`hilog -b D -D 0xD0000XX`), диагностика тапов — info-однострочники
- **[ОТКРЫТ]** Live-обновление бабла при открытом чате после скачивания не происходит (до перезахода). Следующая нить: rebuildTimeline/diff-notify трасса

## Recent Changes (2026-07-08 вечер, тики 20-21 — стикер-repro отработан, emoji-fallback)

- **Диагноз «опросы не видятся»**: их в File физически нет (per-entry debug-лог стора) — Telegram запрещает polls в Saved Messages; ждём от пользователя чат с опросом. Тред: два старых unsupported — не опросы
- **Стикеры (7 шт) дошли, файлы скачаны**: 4 webm → видео-ветка (surface не попадает в snapshot_display — на живом экране, вероятно, играют; спросить пользователя), 3 tgs → thumbnail-fallback без тумбы от TDLib
- **Emoji-fallback (тик 21)**: tgs/нескачанные стикеры показывают КРУПНЫЙ emoji стикера (96fp) вместо серой иконки — stickerEmoji прокинут content→VO→page→router→TgStickerView. **Witness: 🍑😧🤤 в File вместо трёх «лун»** (`31511f8`)
- Debug-лог таймлайна оставлен на debug-уровне (`f56f5f7`, включение: hilog -b DEBUG -D 0x0021)

## Recent Changes (2026-07-08 вечер, тик 17 — P4-c ext: unique_id на все медиа-слоты)

- Канон remote.unique_id разнесён с фото на video(+thumb)/document/audio/voice/sticker(+thumb)/animation/videoNote: DTO-extract → 9 полей MessageContent → reducer map+clone → resolveContentPath во всех VO-вызовах; doc/audio/voice/sticker впервые получили канон-резолв (были прямые пути)
- Механизм покрыт слот-агностичными FilePipeline-тестами; smoke-build/smoke-ui/ohosTest зелёные; закоммичено/запушено (`f0d3e5d`)
- Тики 14-16 — холостые проверки repro-корзины (File): опрос/стикер так и не приехали

## Recent Changes (2026-07-08 вечер, тик 13 — 10-минутное окно группировки + человеческие превью)

- **Time-window**: группировка отправителя рвётся при Δt ≥ 600с (точный iOS-контракт `ChatMessageItemImpl.swift:151`); prevTimestamp трекается во всех ветках билд-цикла VO. Witness: HarmonyOSHub — посты через 42 мин/4.5 ч раздельные, минутная пара слиплась
- **Превью чат-листа**: `humanizeBracketPreview` на UI-слое конвертирует `[X]`-плейсхолдеры ChatDto (Unsupported → «Unsupported message», сервисные → Joined the group/Left/📌 Pinned/Chat updated); DTO остаётся locale-free
- Гейты зелёные; закоммичено/запушено этим тиком
- **Автономный бэклог исчерпан**: остались poll-repro (нужен настоящий опрос), догфуд/приёмка/сертификат — пункты пользователя

## Recent Changes (2026-07-08 вечер, тик 12 — хвосты добраны + unsupported-капсула)

- `TgBubbleTail` хелперами (`buildIncomingTail/buildOutgoingTail`) разнесён на contact/location/poll/doc/audio/voice-ветки Router (медиа/кружки/стикеры — без хвостов, iOS)
- `[messageUnsupported]` (TDLib-тип новее нашего tdlib) → центрированная сервисная капсула «Неподдерживаемое сообщение» (×3 локали)
- **Witness: хвост у последнего исходящего дока в группе; unsupported-капсулы в File** (скрин tick12)
- Гейты: smoke-build/smoke-ui/ohosTest зелёные; закоммичено и запушено этим же тиком

## Recent Changes (2026-07-08 вечер, тик 11 — Play/Pause добит, войс-MVP зелёный)

- Корень: `stateChange('playing')` AVPlayer терялся (урок 81) — прогресс тикал при isPlaying=false. Фикс: `timeUpdateHandler` синхронизирует `isPlaying` с фактическим `player.state`; `pause()` ставит false+emit явно
- **Witness: Pause-кнопка + бегущий waveform-прогресс на живом воспроизведении** (скрин pause_btn2)
- **MVP-пункт «Войсы: play/pause/прогресс» — ЗЕЛЁНЫЙ** (в связке с notify-фиксом тика 10)
- Гейты: smoke-build + ohosTest-компайл зелёные
- Примечание: пользователь прислал второй `[messageUnsupported]` (14:14) — если это была попытка прислать опрос, то дошёл не-poll тип (checklist?); опрос создаётся в чате через скрепку → Poll

## Recent Changes (2026-07-08 вечер, тик 10 — войс-нотификация строк + док-прогон)

- **Войс-UI, шаг 1 FIXED**: snapshot-листенер `TgChatScreenPage` теперь пингует строки через `notifyPlaybackRows` (prev voice/audio + current) — LazyForEach-строка перерисовывается на тиках воспроизведения (урок 65). **Witness: waveform-прогресс бежит** (до фикса бабл был статичен при играющем звуке)
- **Остаток (точный след в TODO)**: кнопка Play/Pause не переключается — контроллер эмитит `isPlaying=false` при живом воспроизведении (прогресс из тех же снапшотов долетает); копать выставление `isPlaying=true` в `VoicePlaybackController` (~35-51) vs async prepare
- **Документ**: скачивание по тапу ✓ (мгновенно, hilog complete=true), смена иконки бабла на «скачан» ✓; открытие вьюером — в догфуд
- Гейты зелёные (smoke-build; ohosTest-компайл от тика 9 актуален — тестовые файлы не менялись)

## Recent Changes (2026-07-08 вечер, тик 9 — фикс разрыва слов + войс-прогон на живом repro)

- **Typography FIXED**: `shouldForceBreakAll` сужен (BREAK_ALL только когда самый длинный токен ≥80% текста; SDK-факт: `BREAK_WORD` сам переносит переполняющие токены, сохраняя слова). Witness: Tailscale-текст в File читабелен, слова целые
- **Пользователь закинул repro в Saved Messages**: войс 0:12 + 2 md-документа (+ `[messageUnsupported]` — новый TDLib-тип, вероятно чек-лист)
- **Войс-прогон**: рендер бабла ✓ (waveform/длительность), тап → скачивание → **звук играет (hilog AudioSink, pts растёт)**; НО **UI не переходит в playing** (Play-кнопка/прогресс/таймер статичны) — новый дефект класса урока 65, след в TODO
- Все гейты зелёные; следующий тик: документы (repro есть) + войс-UI-фикс

## Recent Changes (2026-07-08 вечер, тик 8 — медиа-прогон MVP, без правок кода)

Прогон-тик (дефекты записаны, код не трогался):
- **Новый дефект typography**: `forceBreakAll` от одного длинного токена рвёт все слова сообщения («Se arch», «acco unt») — witness чат File; план фикса в TODO
- **Видео по тапу** (живое подтверждение известного пункта медиа-волны №2): скачивание стартует, но плеер до завершения не открывается — ожидание «открыться сразу с blur+прогрессом»
- **Пин из тика 7 стойкий**: после ресинка Rozetked Plus Chat остаётся первым пином
- Войсы/документы/опрос в доступных чатах не найдены — **просьба к пользователю: закинуть в Saved Messages войс + документ + опрос** для дешёвого repro следующих тиков

## Recent Changes (2026-07-08 вечер, тик 7 — свайп-экшены чат-листа добиты + пин чата)

- Свайпы существовали, но кнопки не кликались: виновник `stateStyles(pressed)` на ListItem (глотал тапы свайп-зоны) — убран; кнопки переведены на `Button(ButtonType.Normal)` + прямая CustomBuilder-форма (канон Codelabs). Урок 80
- **Пин чата реализован по-настоящему** (была hilog-заглушка): `toggleChatIsPinned` (контракт сверен по td_api.tl:12108) — AppCommand+AnyAppCommand-union (грабля arkts-no-structural-typing: новый класс ОБЯЗАН войти в union) → CommandSerializer (`_chat_list_json` chatListMain) → `ToggleChatPinnedUseCase` → ChatListPage wire; +кейс в CommandSerializer.test
- **Live-witness: hilog «Toggling pin for chat … → Chat pin toggled», чат перескочил первым пином выше zai** (reorder через updateChatPosition)
- Все гейты зелёные: smoke-build, smoke-ui, ohosTest-компайл

## Recent Changes (2026-07-08 вечер, тик 6 — хвостики пузырей)

- Новый атом `TgBubbleTail` (Path-лепесток цвета бабла; commands в px → vp2px, RAG по единицам молчал — witness скрином по уроку 68)
- Рендер в text-ветке `TgMessageRouter` при `groupingFlags none|bottom` (последний в группе, iOS-паттерн); отрицательный margin утапливает хвост в аватар-gap — колонка баблов не сдвигается
- `TgTextBubbleV3.bubbleRadius`: tail-side нижний угол → small для none/bottom (хвост продолжает контур бабла)
- Токены `BUBBLE_TAIL_WIDTH/HEIGHT` (8/14)
- **Witness: синий хвост у исходящего в zai; smoke-build/smoke-ui зелёные**
- Не в этом тике: хвост для doc/voice/contact (iOS их имеет); входящий live-witness (атом общий)

## Recent Changes (2026-07-08 вечер, тик 5 — бейдж непрочитанного на табе Chats)

- У стокового `BottomTabBarStyle` badge-API нет (witness: `tab_content.d.ts` SDK, RAG молчит — урок 68 путь); HDS-badge только в HdsNavigation-меню
- Решение: custom `.tabBar(this.buildChatsTabBar())` в MainTabsPage — Stack{SymbolGlyph house_fill 24 + капсула} + label, те же sys.color для active/inactive; データ уже текли: `chatsUIState.totalUnreadCount` (@Trace, число чатов с unread — iOS-семантика)
- Токены `TAB_BADGE_*` (bg `#EB5545` = iOS dark `badgeFillColor`, белый текст, 16vp капсула)
- **Witness: красная капсула «191» на табе; в неактивном состоянии таб серый, бейдж остаётся; floating HDS-бар цел; переключение табов работает** (скрины tab_badge/tab_settings)
- Верификация: smoke-build + smoke-ui зелёные (smoke-контракт шелла не пострадал), install с force-stop

## Recent Changes (2026-07-08 вечер, тик 4 — 5-й фриз пойман и убит + имя канала)

Тик планировался под poll-бабл, но по дороге поймал и закрыл два более горячих дефекта.

- **[P0] 5-й THREAD_BLOCK_6S (12:52, killed при скролле ФУТБОЛ-канала)**: стек — `HiLogPrint→writev` из ArkTS (лог-шторм; дрейн-бэкофф невиновен). Источник: 8 per-batch info-логов `loadChatHistory` + per-rebuild лог VO (P3-диагностика). Все → debug. **Witness: холодный рестарт → тот же скролл-шторм — процесс жив, новых appfreeze нет**
- **Имя канала над постом — корень найден и убит**: `isGroupChat()` включал `'channel'` → имя у первого поста после каждого date/unread-сброса (это был и «HarmonyOSHub над альбомом»). `'channel'` исключён; группировка каналов теперь через `effectiveSenderId` (senderChatId-aware). Witness: посты после «Сегодня» чисты, слипание сохранено
- **Poll-бабл**: опрос не найден в доступных чатах (repro нет) — код-инспекция расхождений не выявила; ждёт чата с опросом (можно переслать опрос в Saved Messages)
- Уроки 77 (isGroupChat/channel + «аномалия после date/unread → ищи сброс prevSenderId») и 78 (per-batch логи; install -r без force-stop не рестартует процесс — проверять STIME)
- Верификация: smoke-build/smoke-ui/ohosTest-компайл зелёные; шторм-ретест на правильном (свежем) процессе

## Recent Changes (2026-07-08 вечер, тик 3 — сервисные сообщения)

Фича R1.5 «сервисные сообщения» end-to-end. Witness: «Якуб теперь в Telegram» (contactRegistered), «Максим/Ольга Феофанова/Glen Musaj вступил(а) в группу» (chatAddMembers) — центрированные капсулы, имена из state.users.

- 13 TDLib-типов chat-событий (контракт сверен по локальному `td_api.tl`): addMembers, joinByLink/Request, deleteMember, changeTitle/Photo/DeletePhoto, pin, basicGroup/supergroupCreate, contactRegistered, videoChatStarted/Ended
- Цепочка слоёв целиком (урок 71): MessageDto (`SERVICE` + serviceType/serviceUserIds/serviceTitle) → MessageContent → messagesReducer map+clone → ChatTimelineVO (kind `'service'`, `buildServiceMessageText`, сброс sender-группы) → Page → `TgDateSeparator` (+`@Param maxLines`)
- 13 строк ×3 локали (`{name}/{target}/{title}` подстановки); +4 юнита `parseMessageContent` (паттерн `TdObject.fromJSON`)
- **Грабля:** в проекте ДВА `MessageContentType` — enum в MessageDto и union-type в AppState; расширять надо ОБА (компайл поймал: «no overlap»)
- Верификация: smoke-build + smoke-ui + ohosTest компайл зелёные; эмулятор-witness
- Новые minor: пустое/Unknown имя в сервисной строке (не в кеше/deleted); превью чат-листа сырое `[ChatAddMembers]`

## Recent Changes (2026-07-08 вечер, тик 2 — разделители таймлайна по iOS-числам)

Продолжение R1.5-цикла. Все witness'ы — скриншоты эмулятора (ArkGram Chat).

- **Unread-бар**: `telegram_blue` капсула → iOS-полоса: новый ресурс `unread_bar_bg #FF1B1B1B` (реф: `unreadBarFillColor 0x1b1b1b` из DefaultDarkPresentationTheme.swift), `UNREAD_MARKER_RADIUS 8→0`
- **Дата-пилюля**: `date_separator_bg #B3000000 → #33000000` (реф: `dateFillStatic alpha 0.2`)
- **Снят false positive** «композер перекрывает контент»: `contentEndOffset` работает, в самом низу последний пост целиком над композером; «перекрытие» — штатный скролл под полупрозрачный композер
- **«Имя над альбомом в канале»** — не локализован дистанционно (все рендеры имени гейтятся showSenderName, VO для каналов его не ставит); в TODO план hilog-диагностики, вслепую не чинился
- Новый минор в бэклог: reply-плейсхолдеры «Reply / Сообщение» при неразрезолвленном оригинале
- Верификация: smoke-build + smoke-ui зелёные, переустановка, скриншот-witness

## Recent Changes (2026-07-08 вечер — R1.5 скриншот-аудит + 5 фиксов внешки)

Заход по жалобе пользователя «сообщения не сливаются, цитаты в каналах широкие». Скриншот-аудит на эмуляторе (до/после в scratchpad), 5 фиксов, 7 новых дефектов в бэклог (`TASKS/TODO.md` → «R1.5 скриншот-аудит»).

- **TgReplySnippet**: hug-content вместо принудительной ширины (`minWidth: containerWidth` + каскад `width('100%')`) — сниппет теперь по контенту. Witness: Dart&Flutter reply компактный
- **TgTextBodyV3 quote**: (1) бар `height('100%')` в auto-Row раздувал плашку до вьюпорта → `LayoutPolicy.matchParent`; (2) фон `hex+'1F'` = сдвиг каналов `#AARRGGBB` (ядовито-зелёный) → `accentRgba()`. Witness: пост HarmonyOSHub — плашка по тексту, фон нормальный
- **ChatTimelineVO**: группировка постов каналов чинится синхронизацией `effectiveSenderId` ↔ `prevSenderId` (senderId=0 → senderChatId). Witness: 3 поста слиплись с зазором 2vp
- **TgMessageRouter**: `Image.onError` → fallback на инициалы (пустые слоты аватаров в группах при недокачанных файлах)
- Верификация: smoke-build + smoke-ui + ohosTest компайл-гейт зелёные; переустановка на эмулятор, скриншоты «после»
- Новые дефекты (не чинились): композер перекрывает контент, «Не прочитано»-плита, сервисные `[messageChatAddMembers]`, имя над альбомом в канале, чёрные дата-пилюли, группировка без time-window, ширина канальных баблов

## Recent Changes (2026-07-08 — anti-freeze P4-d + стикеры + рантайм-прогон)

Оркестрация: я + hermes deepseek-v4-pro как кодер (стикеры, юнит-тесты). Витнессы: build/smoke/ohosTest зелёные + эмуляторный прогон со скриншотами.

### P0-класс: THREAD_BLOCK_6S при открытии тяжёлого канала — FIXED
- Репро на старом бинаре: открытие канала при ресинке → фриз-килл через ~9с (`appfreeze-...-20260708031349888.log`, uv_timer_task, стек libark_jsruntime, CPU-bound)
- Корень: слияние таймер-цепочек (drain-пейсинг + media-watcher 600мс + history) в один нескончаемый uv_timer_task; пейсинг elapsed×1 недостаточен
- Фикс: (1) эскалирующий backoff в `TdGateway.drainSlice` — `drainHotStreak`, пауза `min(250, elapsed*(1+streak))`, сброс при осушении; (2) backpressure: `isDrainCongested()` в интерфейсе TdGateway + опционально в `TdGatewayPort`; media-watcher откладывает скан на 1500мс при шторме
- **Witness: тот же канал, та же фаза ресинка — 40+ секунд жизни, pid стабилен, НОВЫХ appfreeze НЕТ** (против килла за ~9с до фикса)
- Юнит-тесты (кодер, мной верифицированы + компайл-гейт ohosTest зелёный): congested→скан отложен; false/undefined→скан идёт; свежий gateway→false

### Стикеры (MVP «стикеры отображаются») — код готов, рантайм не подтверждён
- Развилка в `TgStickerView`: webm→`TgInlineVideoView` (autoPlay/loop/muted), tgs→thumbnail-fallback, static→Image, пусто→placeholder
- `stickerThumbnailPath` по всей цепочке: MessageDto (extractThumbnailPath) → MessageContent → 3 маппинга редьюсеров → VO (toFileUri) → Page → Router → View
- Кодер пропустил слой MessageContent+редьюсеры — дочинено мной (урок: делегат-патчи проверять по всем слоям клона)
- **Честно: рантайм-рендер стикера не увиден** (стикер-сообщение глубоко в истории; погоня свайпами остановлена) — проверить в догфуде

### Рантайм-прогон патченного билда (эмулятор, скриншот-witness)
- Чат-лист: превью 1 строка ✓, аватары грузятся ✓, unread-бейджи/пины ✓, mark-read гасит бейдж ✓
- Канал: альбом 2×2 с живыми тумбами + «+6» ✓, blur-плейсхолдеры ✓, divider «Не прочитано» ✓ (P3 тут собрался)
- Группа: sender-имена/цвета, reply-сниппеты с thumbnail, bot-команды, ссылки, пагинация вглубь без залипаний ✓
- Back из чата и повторное открытие ✓
- **Новый дефект (R1.5): poll-бабл вылезает за левый край экрана** (вопрос и радиокнопки обрезаны) — в TODO

### R2-подготовка
- `versionName` 1.0.0 → **0.1.0** (AppScope/app.json5); versionCode 1 сохранён
- Осталось (danger boundary — только с пользователем): signingConfigs/сертификат, release-сборка, тег

## Recent Changes (2026-07-07 — UI-аудит через ArkGram + правки)

Тройной UI-аудит (нативные решения ArkGram ↔ HarmonyOS RAG-доки ↔ наш код), 47 находок. Применено; `scripts/smoke-build.ps1` — BUILD SUCCESSFUL, `scripts/smoke-ui-phase0.ps1` — passed.

### Топ-бар (чата + навбар чат-листа)
- connection-state (Connecting/Updating/Waiting for network) проброшен в subtitle шапки чата с accent-цветом и приоритетом над typing (паттерн ArkGram `refreshSubtitle`); строки добавлены в base/ru_RU/zh_CN
- Single source of truth для status-bar инсета: `@Local topInset`+`aboutToAppear` убраны из `TgChatTopBar` и `TgChatListNavigationBar`; инсет считается на странице и прокидывается `@Param topInset`
- Реактивность через `avoidAreaChange` (on/off с парным снятием в `removeWindowSizeListener`) — раньше только `windowSizeChange`, который не гарантирует смену высоты статус-бара
- Fallback инсета `0 → STATUS_BAR_FALLBACK_INSET (38vp)` вместо прилипания к статус-бару
- `.clickEffect(LIGHT)` на back/title/avatar (press-фидбэк, аналог `stateEffect` у ArkGram)
- `LoadingProgress`-спиннер перед subtitle при connecting/updating — завершение connection-фичи (`showSubtitleSpinner` @Param)

### Композер
- `TextAreaController.stopEditing()` при открытии эмодзи-панели — клавиатура и панель больше не конфликтуют
- Мультивыбор вложений: `maxSelectNumber 1→10` (photo+document), отправка ВСЕХ выбранных (caption/reply — на первом); было `attachmentUris[0]`
- Убран неиспользуемый параметр `buildActionButton(isInsideCapsule)`

### Медиа
- Video seek в галерее: `TgInlineVideoView.controls(this.showControls)` вместо хардкод `false` (нативная панель перемотки; галерея уже передавала `showControls:true`)
- Dismiss-свайп галереи: rebound через `getUIContext().animateTo` (было мгновенное «щёлк»), порог `100→150`
- Подпись вьюера в `Scroll` (`MEDIA_GALLERY_CAPTION_MAX_HEIGHT`) — длинные подписи прокручиваются, не режутся на 4 строках
- Документ: убрана двойная индикация загрузки (линейный бар) — остался Ring в плитке + % в metaLine (#17). Осиротевший `progressWidthLabel` в `TgDocumentRow` — minor cleanup follow-up

### Чат-лист / логин / cleanup
- Превью чат-листа `CHAT_ROW_PREVIEW_MAX_LINES 2→1` (паритет Telegram/iOS/ArkGram)
- Логин: автофокус поля на 4 экранах (Phone/Code/Password/Registration) через `getUIContext().getFocusController().requestFocus(id)`+`.onAppear()`; удалён мёртвый shake (`shakeOffset`/`animateError`) из `CodeInputView`
- Убран мёртвый импорт `TgMessageBubbleBase` из `TgMessageRouter`

### Отложено (обоснованно, не недоделка)
- **`@ReusableV2` рециклинг (#1 high)**: проект осознанно откладывает `Repeat`/`@ReusableV2` на пост-v0.1.0 perf-трек (D7 + AGENT_EXECUTION_PLAN); `smoke-ui-phase0` закрепляет контракт `.reuseId()`; perf-выигрыш не verify без эмулятор-профайлера
- **Стикеры TGS/webm (#46)**: L-фича, нужны deps (`@ohos/lottie`/`@ohos.zlib`) + runtime-verify (эмулятор), source `stickerPath` неопределён — отдельный трек
- Документы #16 (иконки типов)/#17 (двойной прогресс), List.divider #13 — low, отдельным проходом

### Новый референс
- **ArkGram** (декомпилированный конкурент): карта в `ARKGRAM_REFERENCE.md`, проект в `C:\Users\Kharki\Desktop\ArkGram-RE\out\ArkGram-project`

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
- **ОСТОРОЖНО:** `install -r` с ОДНИМ HAP'ом пересоздаёт бандл целиком — установка ohosTest-HAP этим путём стёрла entry-модуль и данные приложения (TDLib-сессию). Тестовый HAP ставить только вместе с entry или не ставить вовсе
- Git Bash: для device-путей обязателен `MSYS_NO_PATHCONV=1`; `file recv` — с относительным путём из целевой папки
- Telegram-сессия на эмуляторе жива (userdata сохраняется между запусками)

## Working Tree

- Throttling patch committed as `eb1fac1`; Release Track v2 docs pivot + первый MVP-прогон committed follow-up
- R0 завершён 2026-07-02: MVP-чеклист прогнан, дефекты P0-P3 записаны в `TASKS/TODO.md` R1 backlog
- Активная фаза теперь R1: первоочередной дефект — P0 cold-start `THREAD_BLOCK_6S` (uvLoopTask/TDLib batch pipeline на main thread)

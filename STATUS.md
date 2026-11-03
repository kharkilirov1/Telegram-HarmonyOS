# STATUS — Telegram-HarmonyOS

Current state only. Every superseded dated snapshot, and the pre-compaction version of this file,
lives in `TASKS/ARCHIVE/STATUS-history-2026-10-18.md`. Reports referenced here are immutable
checkpoints — see `docs/reviews/INDEX.md` for all 81 of them.

## Where it stands — 2026-10-23

| Area | State |
|---|---|
| Receive scheduling (drain) | **Accepted.** Bounded correction, 15/15 regressions, independent Astra review. |
| Receive-drain topology / slice budget | **Closed — no change.** Null result on threads; shipped pacing measured 2026-10-23 (~2.8–3.1× slower than the zero-delay model, −18 % from 8→64 ms, frame ordering non-monotone); `DRAIN_BUDGET_MS` stays 8. |
| Main reliability (request timeouts) | **PARTIAL.** 2/4 observed timeouts on the exact official package; root cause not established. |
| Source publication | `dev` pushed to `origin/dev`, CI green on `d706143`; six probe/docs commits since, not yet pushed. |
| Install over authenticated main | **Not done** for the correction. Not released, not signed. |
| Notifications / push | **Absent.** No `notificationManager` / `wantAgent` / push code in `entry/`. |
| Authenticated delivery / providers / shipped-iOS / signing | **Open** since 2026-09-27. |

## Latest checkpoint — 2026-10-21…23

**Receive-drain investigation closed, and its own measurement corrected.** Three days of synthetic
work asked whether the drain should move off the main thread and whether its slice budget should
change. A Worker arm and a main arm were indistinguishable once arrival timing was fixed; a budget
sweep then reported that 8 ms was the worst setting. On 2026-10-23 that sweep was corrected: it
yielded with a zero delay while the shipped drain schedules its next slice at
`max(2, min(250, elapsed × 2))`, so its time column belongs to a model the app does not implement. The
"measured hop counts" were arithmetic (no counter existed), and the "8 ms consumer work" quantum was an
injected artificial delay, not an observation. **Recommendation withdrawn; `DRAIN_BUDGET_MS` stays 8;
no receive-drain work is open.** [Topology](docs/reviews/2026-10-20-drain-topology-spike.md) ·
[sweep](docs/reviews/2026-10-21-drain-budget-sweep.md)

**The shipped pacing was then measured, not just predicted.** An isolated bundle ran both yield models
back-to-back on the emulator, n = 3 per budget: the shipped drain costs ~2.8–3.1× the zero-delay model
(5461 vs 1950 ms at 8 ms on the same 1288 ms of work), its budget curve is −18 % from 8 → 64 ms
instead of −27 %, and its frame gaps are non-monotone (207 / 285 / 216 / 130 ms). The 2026-10-21
headline "8 ms is worst on both axes" is therefore not reproduced; the constant still does not move,
because the gain is half the claimed one and the host is an emulator. The host itself is a 2014 Xeon
with a 97 %-full disk, so every absolute millisecond in that run is an upper bound.
[Re-run](docs/reviews/2026-10-23-drain-yield-model-rerun.md)

**Worker NAPI door opened, then not needed.** The native TDLib module loads and answers inside an
ArkTS Worker on the emulator, and the running process reports TDLib 1.8.61 — which closed the
"is the shipped binary 1.8.60?" half of the provenance question.
[Report](docs/reviews/2026-10-20-worker-napi-probe.md)

**TDLib pin aligned, provenance still open.** The submodule is pinned at `11e254af6`, whose
`CMakeLists.txt` declares 1.8.61; the exact upstream revision that built the shipped `.so` remains
unrecorded. [Report](docs/reviews/2026-10-19-tdlib-version-provenance.md)

**Competitor artifact re-checked.** The ArkGram note was corrected on 2026-10-23: the analysed package
is 1.0.1 (not 3.2), `compileSdk 26.0.0.23 / Beta1`, several previously listed platform APIs are absent
from every retained artifact, and the concurrency result — no ArkTS worker/taskpool usage — is the part
that stands. [Report](docs/reviews/2026-10-21-arkgram-analysis.md)

## Repository tidy-up — 2026-10-24

Documentation and repository structure were reconciled; no product code changed.

- **Roadmap rewritten.** `TASKS/AGENT_EXECUTION_PLAN.md` now states the current route only. Release
  Track v2 (R0→R3+, `v0.1.0` as the goal, "pixel fidelity is not a goal") moved to
  `TASKS/ARCHIVE/AGENT_EXECUTION_PLAN_release-track-v2_2026-07-02.md` and is not to be executed.
  `DECISIONS.md` D24 records the mandate change, D25 records which documents are authoritative.
- **Authority resolved.** `docs/ai/*` is an archive (`docs/ai/README.md`); the `tg_ui` master plan keeps
  only its visual-contract role. The open "canon winner" question in `TASKS/TODO.md` is closed.
- **`TASKS/` decluttered.** 10 historical slice plans moved to `TASKS/ARCHIVE/` with an index; 7 active
  documents remain.
- **Docs made truthful.** `README.md` rewritten (API 23 compatible / 26 target, x86_64-only ABI,
  verification matrix, documentation map, emulator gotchas); `ARCHITECTURE.md` scope and reference list
  fixed; test counts corrected to 87 `.test.ets` files; dead links repaired; policy for dead links in
  dated reports documented in `docs/reviews/INDEX.md`.
- **Hygiene.** Removed a stale crash dump and an empty `presentation/viewmodels/` stub; documented that
  `AGENTS.md`/`CLAUDE.md` are intentionally not versioned.

## Engineering protocol — 2026-10-25

Введён обязательный цикл среза и инструменты планирования; код продукта не менялся.

- `TASKS/SLICE_PROTOCOL.md` — преflight (статус/референс/доки), разбор iOS-эталона, швы для
  связанных фич без спекулятивных абстракций, тест до реализации, implementation, gates,
  side-by-side с iOS, Definition of Done, реестр долга.
- `TASKS/SLICE_TEMPLATE.md` — шаблон плана среза (референс → контракт → швы → состояния → тест →
  приёмка).
- `TASKS/CAPABILITY_MATRIX.md` — 105 строк по пользовательским возможностям iOS: 35 `available`,
  51 `partial`, 15 `missing`, 3 `frozen`, 1 `blocked`; `unverified` = 0. У каждой строки —
  код-доказательство и связанные фичи; `available` без witness не ставится.
- `TASKS/WORKMAP.md` — M0 (верифицировать 9 `unverified` строк), S1 (typing indicator, C2),
  S2 (стикеры/TGS, D13).
- `TASKS/TODO.md` — добавлен раздел **Debt**: долг с владельцем и триггером, иначе срез не закрыт.
- Правила зашиты в `AGENT_EXECUTION_PLAN` (preflight + глобальные правила), `AGENTS.md`/`CLAUDE.md`
  (memory pack), `README` (карта документов).

## Slice wave — 2026-10-25

Первый прогон по `SLICE_PROTOCOL`, три агента параллельно + design-срез от lead.

- **S3a (lead).** Данные реакций: `Message.reactions` + чистая модель в `AppState` (порядок chosen →
  count → key, кап 6 + «+N», инкрементальный `applyReactionDelta`), парсер TDLib-снимка и типов в
  `MessageDto`, события `messageReactionsUpdated`/`messageReactionChanged` в normalizer и reducer,
  VO `ReactionChipVO` с stamp'ом в ключе строки только при наличии реакций. Host-тест
  `test-reactions-model.cjs`; D10 → `partial` (рендер и постановка — S3b/S3c). Гейты: host **98/98**,
  оба smoke, hvigor BUILD SUCCESSFUL.
- **S3b (lead).** Подвал реакций: атом `TgReactionsFooter` на примитивах (Flex wrap, «+N»,
  кастомный эмодзи → нейтральный глиф, акцент только для своей реакции), токены и цвета light/dark,
  паспорт и demo. Врезан в текстовый бабл через `TgChatTimelineRow → TgMessageRouter →
  TgTextBubbleV3`; строка пересобирается по reaction-stamp. Host-контракт
  `test-reactions-footer.cjs`. **D10 остаётся `partial`:** медиа-баблы (S3b.1), пикер (S3d) и
  witness не сделаны. Гейты: host **99/99**, оба smoke, hvigor BUILD SUCCESSFUL.
- **S3c (lead).** Постановка/снятие реакции: `SetMessageReactionsCommand` + сериализатор
  (`reactionTypeEmoji` / `reactionTypeCustomEmoji`, int64 строкой, `is_big=false`), use case и
  `ChatReactionController` — оптимистичный снимок записывается до отправки, при ошибке
  восстанавливается предыдущий, guard по токену страницы и по парному тапу, в TDLib уходят только
  chosen-ключи. Тап по чипу доведён от атома до контроллера через session/ports. Host-контракт
  `test-reactions-send.cjs`. Гейты: host **100/100**, оба smoke, hvigor BUILD SUCCESSFUL.
  **D10 остаётся `partial`:** S3b.1 (медиа-баблы) и runtime-witness.
- **S3d (lead).** Пикер реакций: `chat.available_reactions` парсится в `ChatDto`/`Chat`
  (`chatAvailableReactionsAll` / `Some`, `updateChatAvailableReactions`), модель
  `availableReactionKeys` берёт дефолтный ряд iOS (12 реакций) при «all»/неизвестном чате, иначе —
  серверный список с капом 12; `chatAllowsReactions` скрывает пикер, когда чат запрещает реакции.
  Атом `TgReactionPicker` (горизонтальный скролл, токены, spec+demo) врезан над меню действий:
  long-press → попап → тап закрывает меню и уходит в S3c-контроллер. Host-контракты
  `test-reactions-availability.cjs` + `test-reactions-picker.cjs`. Гейты: host **102/102**, оба
  smoke, hvigor BUILD SUCCESSFUL. **D10 остаётся `partial`:** S3b.1 (медиа-баблы), теги,
  runtime-witness.
- **S3d.1 (lead).** Пикер стал per-message: `GetMessageAvailableReactionsCommand` +
  сериализатор (`getMessageAvailableReactions`, int64 сообщения строкой, `row_size=12`), парсер
  `availableReactions` (`top`/`recent`/`popular` + `allow_custom_emoji`/`are_tags`),
  use case, который не бросает исключение (ошибка → пустой снимок). Модель `pickerReactionKeys`
  сливает top→recent→popular с дедупом и капом 12, пустой ответ падает на чатовый ряд. Попап при
  открытии синхронно сеет чатовый ряд и асинхронно заменяет его ответом TDLib; устаревший ответ
  отсекается по generation + lifecycle + chatId + messageId, чат с запретом реакций не получает их
  из ответа. Host-контракт `test-reactions-picker-data.cjs`. Гейты: host **103/103**, оба smoke,
  hvigor BUILD SUCCESSFUL. **D10 остаётся `partial`:** рендер кастомных эмодзи (D16), теги,
  runtime-witness.
- **S3b.1 (lead).** Подвал реакций добрался до медиа: роутер рисует `TgReactionsFooter` под
  фото/видео/альбомом/кружком/гиф, документами/аудио/голосом, контактом/локацией/опросом — вне
  медиа-контейнера, с выравниванием по стороне бабла (как в iOS), и не дублирует подвал текстового
  бабла. Стикер-ветка без подвала: у её колонки фиксированная высота картинки — записано долгом.
  Host-контракт `test-reactions-media-footer.cjs` (наличие 6+ вызовов, отсутствие проводки в
  `TgMediaBubbleShellV2`, сохранение inline-подвала текста). Гейты: host **104/104**, оба smoke,
  hvigor BUILD SUCCESSFUL. **D10 остаётся `partial`:** стикер, геометрия медиа-ряда без witness,
  рендер кастомных эмодзи (D16), теги, runtime-witness.
- **S4 (lead).** Мёртвые контролы из аудита закрыты: Toggle «Notifications» в профиле теперь отправляет
  `SetChatMuteCommand` (откат при ошибке, токен страницы), строка «Data and Storage» удалена до
  появления экрана, мёртвая проводка `attachmentMenuLabels` вырезана из шести файлов, неиспользуемые
  DTO `TdAutoDownloadSettings`/`Presets` удалены. Новый host-guard `scripts/test-dead-controls.cjs`
  не даёт им вернуться. Гейты: host **97/97**, оба smoke, hvigor BUILD SUCCESSFUL.
- **M0 (matrix-verifier).** Девять `unverified` строк верифицированы по коду: B6/C10/D20/D24/H4 —
  `missing`, D29/E1/J5/J7 — `partial`. `unverified` = 0.
- **S9 (lead).** H5 «Устройства/сессии» из `missing` → `partial`. Новый экран `TgSessionsPage`
  (Settings → Devices; строка уже была, добавлен `onOpenDevices` → push на root-стек):
  `getActiveSessions` → `SessionDto`, текущий сеанс помечен и не завершается, `terminateSession`
  после подтверждения и с перезагрузкой списка. Попутно: `TdObject.getTopLevelRawObjectArrayStrict`
  — старый `getTopLevelObjectArrayStrict` пересобирает дочерние объекты через JSON.parse и теряет
  точность int64 (id сессии `9007199254740993` превращался в `...992`); слайсы исходного текста
  сохраняют литерал. Контракт `test-sessions.cjs`: DTO (точный int64, флаги, пустые поля, null-слоты,
  неправильные payloads), команды/сериализатор, use case (валидация id до gateway, пустой ответ не
  роняет), экран/route/settings/локали. Гейты: host **111/111**, оба smoke, hvigor BUILD SUCCESSFUL.
  **Осталось (H5):** завершить все остальные сеансы, разделить web-сессии, привязка к 2FA,
  iOS-раскладка секций, witness.
- **S8b.2 (lead).** B6: «Add to folder». `AddChatToListPayload`/фабрика/сериализатор получили
  `chatList: folder` + `folderId` (`chatListFolder` JSON), `MoveChatToListUseCase.addToFolder(chatId,
  folderId)` валидирует вход и шлёт `addChatToList`; `selectAddToFolderTargets` отдаёт только папки,
  где чата ещё нет; меню рисует секцию с названиями папок (`chat_context_add_to_folder` в base/ru/zh).
  Удаление из папки в этой версии TDLib отсутствует — пункт не предлагается. Контракт
  `test-chat-list-context-menu.cjs` расширен: команда/фабрика/сериализатор (регрессия archive),
  `addToFolder` (включая отказ при неверных id и то, что main). Гейты: host **110/110**, оба smoke,
  hvigor BUILD SUCCESSFUL. **Осталось (B6):** Join chat/channel, Select, Add to contacts, Remove from
  recents.
- **S8b.1 (lead).** Bugfix: «mark as unread» не был двусторонним. TDLib держит `is_marked_as_unread`
  отдельно от `unread_count`, присылает `updateChatIsMarkedAsUnread`, а приложение этот апдейт
  игнорировало — после переключения состояние в списке оставалось прежним, а меню предлагало
  «mark as unread» повторно. Добавлены парсинг `chat.is_marked_as_unread`, обработчик
  `updateChatIsMarkedAsUnread`, поле `Chat.isMarkedAsUnread` (создание + оба merge-пути reducer),
  `ChatItemVO`/diff строки, условие меню и обработчик (`markAsRead`, если есть unread или ручная
  метка). Контракт `test-chat-list-context-menu.cjs` расширен: парсинг full chat, dispatch через
  реальную registration-map, установка/снятие флага в reducer, «mark as read» для помеченного чата,
  VO и diff. Гейты: host **110/110**, оба smoke, hvigor BUILD SUCCESSFUL.
- **S8a (lead).** B6 «Контекстное меню чата» из `missing` → `partial`. Long-press по строке списка
  открывает меню (`bindContextMenu`, `ResponseType.LongPress`) с iOS-порядком действий: mark
  read/unread → archive/unarchive → pin/unpin → mute/unmute → delete (destructive). Модель — чистый
  селектор `chatContextMenuSelectors.ets` (Saved Messages меню не получает), действия делегируются
  существующим use case, архив/разархив через `handleMoveToArchive`/`handleMoveToMain`. Лейблы
  `chat_context_*` в base/ru/zh, токены `CHAT_CONTEXT_MENU_*`, контракт
  `test-chat-list-context-menu.cjs` (труth table по состояниям, иконки-ассеты, проводка, локали,
  токены). Гейты: host **110/110**, оба smoke, hvigor BUILD SUCCESSFUL. **Осталось (B6):**
  пункты по типу чата (Add to contacts, Join chat/channel, Add/Remove from folder, Select, Remove
  from recents), выделение нескольких чатов.
- **S7b.3 (lead).** B7: пагинация по папке. `LoadChatsPayload` получил `chatList: folder` +
  `folderId` (фабрика `createLoadChatsCommand(limit, chatList, folderId)`), сериализатор отправляет
  `chatListFolder` JSON; новый `LoadFolderChatsUseCase` держит один запрос на папку в полёте, cooldown
  1.5 c после ответа (TDLib может ответить пусто), отменяется вместе со страницей; `ChatListPage`
  запрашивает первую страницу при выборе папки и догружает её на скролле вместо основного списка.
  Контракт `test-chat-folders.cjs`: проводка команды/фабрики/сериализатора (включая регрессию archive),
  дедупликация в полёте, cooldown, folder 0, отмена, проводка страницы. Гейты: host **109/109**,
  оба smoke, hvigor BUILD SUCCESSFUL. **Осталось (B7):** экран настроек папок, folder link preview.
- **S7b.2 (lead).** B7: полоса папок подключена к списку. `TgChatListFilterBar` получил
  `TgChatListFilterTab` (id/title/unread), режим реальных папок с горизонтальной прокруткой и
  бейджами (легаси All/Unread/Personal остаётся фолбэком при одной вкладке), `TgChatListNavigationBar`
  пробрасывает `filterTabs`/`selectedFolderId`/`onFolderFilterChange`, `ChatListPage` строит вкладки
  из `selectChatFolderTabs` и при выборе папки перестраивает список из `selectChatIdsForFolder`
  («All chats» — прежний `orderedChatIds`). Счётчики: `updateUnreadChatCount` →
  `chatListUnreadCountUpdated` (`main`/`archive`/`folder:<id>`) → `ChatFoldersState.unreadByList` →
  бейджи. Строка «All» локализована (`chat_folders_all`, base/ru/zh). Контракт `test-chat-folders.cjs`
  дополнен: клавиши списков (folder id 0 отбрасывается), сохранение папок при обновлении счётчика,
  бейджи вкладок, контракты atom/navbar/page и три локали. Гейты: host **109/109**, оба smoke,
  hvigor BUILD SUCCESSFUL. **Осталось (B7):** пагинация `loadChats(chatListFolder)`, экран настроек
  папок, folder link preview.
- **S7b.1 (lead).** B7: принадлежность чатов к папкам. `ChatDto` парсит **все** `chatListFolder`
  позиции (`folderOrders`, типизированный `extractFolderPosition`), `Chat` их зеркалит,
  `updateChatAddedToList`/`updateChatRemovedFromList` обновляют членство (`folderId`/`folderOrder`/
  `folderRemoved` → `applyFolderUpdate` в `chatsReducer`), `selectChatIdsForFolder` отдаёт состав
  папки в её собственном порядке (`chatListMain` намеренно не используется). Контракт
  `test-chat-folders.cjs` расширен: парсер позиций, оба update-а (включая `folder_id = 0`),
  добавление/удаление членства без изменения main/archive order, сортировка состава. Гейты: host
  **109/109**, оба smoke, hvigor BUILD SUCCESSFUL. **Дальше (S7b.2):** data-driven
  `TgChatListFilterBar` + фильтрация списка и пагинация `chatListFolder` + unread по папкам.
- **S7a (lead).** B7 «Папки чатов» из `missing` → `partial` (слой данных). TDLib-контракт
  `updateChatFolders` (td_api.tl:9683) нормализуется в `chatFoldersUpdated` (папки, позиция
  «All chats», флаг тегов); состояние зеркалируется в `AppState.chatFilters`
  (`ChatFolderInfo`/`ChatFoldersState`), роутинг через `chatFoldersReducer` (полная замена,
  `cloneStateForChats`), селектор `selectChatFolderTabs` ставит «All chats» на позицию TDLib и
  клампит выход за границы. Контракт `test-chat-folders.cjs`: разбор нормализатора (включая
  malformed/unknown записи), замена состояния без мутации, все позиции вкладки, проводка
  регистрации/роутинга + сверка с `td_api.tl`. Гейты: host **109/109**, оба smoke, hvigor
  BUILD SUCCESSFUL. **Дальше (S7b):** data-driven панель фильтров, фильтрация списка по
  `chatListFolder` + `updateChatAddedToList/RemovedFromList`, счётчики непрочитанного по папкам.
- **S6c (lead).** D7: аватар-закладка в шапке чата. `ChatAvatarPresentation.isSavedMessages`
  вычисляется по `state.auth.userId` (токен/приватный чат), идёт через port
  `chatIsSavedMessages` → `ChatChromeState` → `TgChatTopBar.avatarIsSavedMessages` →
  `TgAvatar.symbolIcon`, т.е. вместо инициалов аккаунта рисуется `sys.symbol.bookmark_fill`.
  Гейты: host **108/108**, оба smoke, hvigor BUILD SUCCESSFUL.
- **Witness-блокер (снят фактически).** Эмулятор доступен (`hdc list targets` → `127.0.0.1:5555`,
  API 26), **unsigned HAP ставится** (`hdc install -r` → success), приложение запускается свежим
  процессом (PID 20175, STIME 02:36:55 < now 02:37:26), но сессия **не авторизована**: экран ввода
  номера. Т.е. блокер witness-ов — не подпись и не сборка, а отсутствие залогиненного аккаунта
  (нужен номер + код). Доказательство: скриншот `snapshot_display` 1280×2832 (auth-экран).
- **S5c (lead).** Долги C9 закрыты частично: выбранная строка теперь подсвечивается
  тинтом (`SELECTION_ROW_TINT` → `selection_row_tint` в base/dark), а диалог удаления называет
  размер выбора — «Delete %d messages?» / «Удалить %d сообщений?» / «删除 %d 条消息？»
  (`delete_messages_count`, `messageCount` в `NativeDeleteMessageConfirmation`, один диалог и один
  `deleteMessages` на весь выбор). Хост-контракт `test-selection-mode.cjs` расширен: поведенческая
  проверка заголовка для 1 и N сообщений, токен/цвет тинта, проводка строки. Гейты: host **108/108**,
  оба smoke, hvigor BUILD SUCCESSFUL. **Остаётся:** Copy глифом (нет ассета), device-witness.
- **S6b (lead).** D7 получил точку входа: строка «Saved Messages» в настройках больше не
  мёртвая — `SettingsPage` эмитит `onOpenSavedMessages`, `MainTabsPage` открывает уже существующий
  чат либо создаёт его через `createPrivateChat(my_id)` (td_api.tl:8726), гидрирует стор
  `createNewChatEvent` и пушит экран чата. Транзакция открытия (запись navigation/chat-состояния,
  nav-lock, откат при исключении, защита от нового владельца) вынесена в общий
  `ChatOpenTransaction.pushChatScreenRoute`; на неё переведены и `ChatListPage`, и
  `TgArchivedChatsPage` — три копии блока свёрнуты в одну. Host-контракты
  `test-chat-open-transaction.cjs` (4 сценария транзакции + проводка) и обновлённый
  `test-saved-messages.cjs`. Гейты: host **108/108**, оба smoke, hvigor BUILD SUCCESSFUL.
  **Долг:** пункта в меню iOS нет (только настройки), аватар в шапке чата не обновлён, device-witness.
- **S6a (lead).** D7 «Избранное» из `missing` → `partial` (представление): предикат
  `isSavedMessagesChat` (private-чат с `peerUserId === state.auth.userId`), заголовок «Saved Messages»
  в списке и в шапке чата вместо имени аккаунта, аватар-закладка через новый `TgAvatar.symbolIcon`
  (`sys.symbol.bookmark_fill`), флаг `isSavedMessages` в VO и в diff строки списка. Host-контракт
  `test-saved-messages.cjs`. Гейты: host **107/107**, оба smoke, hvigor BUILD SUCCESSFUL. **Долг:**
  точки входа нет (строка в настройках без `onRowClick`, нет пункта меню/создания чата), верхняя
  панель чата и строки других экранов не проверены, device-witness.
- **S5b (lead).** C9 «панель выделения сообщений» из `missing` → `partial`. Вход — пункт
  «Select» в меню действий; состояние `selectionActive`/`selectedMessageIds` в
  `ChatTimelineViewState` с alias-геттерами; делегаты входа/тоггла/выхода, `selectionTitle`,
  copy (тексты в порядке таймлайна), forward (тот же `startForwardMessages`), delete
  (`ChatDeleteMessageController.requestMany` — одна доступность, один диалог, один
  `deleteMessages`); панель `TgSelectionPanel` с паспортом/demo и токенами заменяет композер; строка
  в режиме выделения показывает чек-индикатор и блокирует тапы бабла (`.enabled(false)`), тап строки
  — тоггл. Строки «Select»/«%d selected» в base/ru/zh. Гейты: host **106/106**, оба smoke, hvigor
  BUILD SUCCESSFUL. **Долг:** иконки вместо текстовых действий, подсветка выбранных баблов, диалог
  pass по apple-design + iOS-источнику: панель = строка input-панели 40 px, действия — круги
  40×40 (иконки close/forward/delete, Copy — глиф ⧉), стекло через `TgGlassPolicy`, press-feedback —
  нативный эффект `Button`, счётчик SemiBold по центру.
  удаления с формулировкой для N сообщений, device-witness.
- **S5a (lead).** C6 «разделитель непрочитанных» верифицирован и доведён: модель уже создавала
  запись `kind='unread'` (`firstUnreadIncomingIndex`, sticky-граница, `'0'` как валидная граница,
  сброс sender-group), но строка матрицы висела `missing` без тестов. Добавлены паспорт
  `TgUnreadMarker` (геометрия сверена с iOS `ChatUnreadItem.swift`: 25 px, радиус 0, отступы 6/5),
  отдельный ресурс `chat_unread_messages` («Unread messages», ru/zh — было «Unread» из строки
  фильтра чатов) и host-контракт `test-unread-divider.cjs` (6 сценариев + геометрия + локали).
  Гейты: host **105/105**, оба smoke, hvigor BUILD SUCCESSFUL. C6 → `partial`: witness скролла к
  непрочитанному на устройстве не снят (долг в TODO).
- **S1 + S1.1 (typing-slice).** TTL активности 8 s по iOS, откат по дедлайну без новых store-change,
  группа — только имя, приватный — текст активности, статические точки из токенов, «печатает…» в
  трёх локалях, единый TTL в шапке и списке. Восстановлен harness `chat-screen-source.cjs` для
  не-delegate helper'ов. Host 96/96, smoke и build зелёные. **C2 остаётся `partial`:**
  визуальный witness требует второго аккаунта/клиента.
- **S2 (sticker-slice).** `TgsPlaybackPolicy`: играть только видимое, поверхность (панель — никогда),
  LRU-кеш распакованного Lottie по `fileId`, бюджет 4 инстанса, `@Monitor('tgsPath')`, pass-through
  `fileId` до плеера, warn-лог провала декода. Найдены причины «живой рендер не пойман» и перегруза
  API23. Build + 4 статических TGS-контракта зелёные. **D13 остаётся `partial`** до witness.
- **S3 (lead).** Дизайн reactions: контракт TDLib (`setMessageReactions`, `updateMessageReactions`),
  швы в VO/команды, состояния, разбиение S3a–S3d —
  `docs/specs/2026-10-25-reactions-design.md`.
- **Долги** внесены в `TASKS/TODO.md` §Debt: пульсация точек, мульти-typing, статичная панель стикеров,
  нативный TGS-рендерер, witness C2/D13; плюс мёртвые контролы из аудита — отдельными дефектами.
- `harmonyos_docs` MCP в этой сессии недоступен (только colab/rea/rea-linux) — оба агента
  зафиксировали это ограничением, новых ArkUI API не вводили.
- **Witness: D13 закрыт, C2 открыт.** Второй подъём HVD (watchdog подавлен) дал стабильный гост;
  HAP + ohosTest установлены, сессия залогинена. On-device тесты: `ChatHeaderStatus` 8/8,
  `TgsPlaybackPolicy` 12/12. В чате `HUAWEI Chat` пойман живой TGS-цикл: `tgs playback started
  key=file:11696 players=1`, повторный вход — снова старт, но без повторного декода (кеш по `fileId`);
  diff двух кадров через 700 мс различается только в области стикера (3 274 px) — анимация живая.
  **D13 → `available`.** Для C2 третья попытка (группа `HUAWEI Chat`, 906 участников, 25 дампов
  layout за ~4 мин) не поймала ни одного события набора — нужен второй участник, поэтому C2 остаётся
  `partial`, а цель помечена блокером по этому пункту.
- **Наблюдение:** первый `aa start` на этом прогоне дал `sysfreeze ... LIFECYCLE_TIMEOUT` (debug HAP,
  эмулятор); второй запуск поднялся нормально. Записано наблюдением в `TASKS/TODO.md` §Debt, не
  диагнозом: release-сборки нет, на устройстве не проверялось.

## Checkpoint — 2026-10-18

**Receive scheduling correction.** The drain tested its 8 ms budget before transferring, so a single
clock access or batch parse could consume a quantum with zero progress; an escalating multiplier
`elapsed * (1 + drainHotStreak)` stretched pauses to 250 ms even for a finite already-admitted
backlog. Now one transfer is guaranteed per turn, bounded by 50 transfers / 4 new batches, with the
inter-turn delay at twice the measured work and no backlog-age multiplier. Same-fixture native
comparison: admission→dispatch 31 847 → 5 598 ms, 37 rejected → 0. Four-variant split: baseline
6/15, progress-only 14/15, pacing-only 7/15, combined 15/15. FIFO, deadlines, byte/batch limits,
ownership, ACK ordering and no-uncertain-replay unchanged. [Report](docs/reviews/2026-10-18-receive-latency.md)

**Main acceptance stays PARTIAL.** The exact official package was installed over the existing session
(UID/install identity retained) and getMe, profile, chat list, existing history, Back and same-PID
background/resume were observed across two instances. But 2/4 unique observed request timeouts
(loadChats/getChat/setOption) remained, against historical 87/5 under different windows and workload.
No speedup is claimed. [Report](docs/reviews/2026-10-18-main-receive-acceptance.md)

**Diagnostic main localized, did not explain.** Two cold processes (PIDs 9355/10050) reproduced 4/10
timeout tokens. Selected batches reach Ark admission *after* their deadlines, and native send→copy
intervals overlap four-batch capacity waits by 17.8–36.5 s (88–93%). The second 3 456-record trace
stays PARTIAL at its 120 s cutoff; its initial history failed after an openChat timeout and a later
ordinary reopen displayed messages. Observer cost and TDLib response-ready timing remain unknown, so
**no further production fix is proposed**. [Runtime](docs/reviews/2026-10-18-main-diagnostic-runtime.md) ·
[build/isolated gates](docs/reviews/2026-10-18-bounded-timeout-diagnostics.md)

**Cleanup.** Thirty old Telegram HAPs permanently deleted under explicit authorization after exact
path/size/SHA-256 checks (1 508 061 896 bytes); all ten retained HAPs hash-verified.

## Carried forward — 2026-10-15

Scoped receive/privacy corrections are accepted locally: candidate12 host 95/95 plus static checks,
both official SDK builds inherited from source11, isolated native-postfull-v3 pair install, final
native focus 19/19 and full 1208/1208. Native/ArkTS credits cover active parsing; uncertain delivery
is never replayed. Photo observation remains PARTIAL despite a separate Hypium PASS; the older
unlogged keyboard mismatch and Slowmode title-wait cause remain UNCLASSIFIED.
[Report](docs/reviews/2026-10-15-receive-stabilization.md)

## What is not proven

Source, host and compile checks do not substitute for device, SDK, delivery or visual acceptance.
The unresolved boundary on main is *why consumer progress is too slow*: requested pacing, synchronous
parse/dispatch/store/listener/render work, scheduler contention and synchronous logging are not
partitioned, and TDLib response-ready timing is unobserved. Capacity being full is a symptom, not a
diagnosis; deadlines and memory bounds must not be relaxed to hide an admitted-wait timeout.

The iOS reference was refreshed on 2026-10-18 (`master` @ `f1dd7a2`, 31 572 commits). All 82 source
paths cited from these docs still resolve, but **59 of the 82 files changed upstream**, so their
line-number citations are unverified until re-read. See the refresh log in `REFERENCES.md`.

## Project facts

- **Branch:** `dev` is canonical, tracks `origin/dev`. `main` untouched; dev→main decision deferred.
- **Phase:** production quality against the iOS reference (user mandate 2026-08-31; v0.1.0 tag as a
  goal withdrawn).
- **Tests:** 87 `.test.ets` files under `entry/src/ohosTest/ets/test/` (DevEco `entry@ohosTest`);
  96 host behavioural suites in `scripts/`, run by `node scripts/run-host-tests.cjs` —
  **Node ≥ 24 required**.
- **Architecture:** solo mode, no `presentation/viewmodels/`; chat-page controllers centralized.

## Key documents

| Document | Purpose |
|---|---|
| `TASKS/TODO.md` | **Active queue**: open gates, backlog, decisions needed from the user |
| `TASKS/AGENT_EXECUTION_PLAN.md` | Canonical route (order of phases) |
| `TASKS/PRODUCTION_PARITY_PLAN.md` | Per-phase exit criteria and evidence boundaries |
| `TASKS/LESSONS.md` | Dated blocks + numbered lessons (83–163) |
| `docs/reviews/INDEX.md` | All review reports, newest first (78) |
| `probe/README.md` | Receive-drain harness, status, recorded runs |
| `TASKS/ARCHIVE/INDEX.md` | History — read-only, not instructions |
| `REFERENCES.md`, `ARKGRAM_REFERENCE.md` | External reference registry and competitor notes |
| `ARCHITECTURE.md`, `DECISIONS.md` | Structure and recorded decisions (D1–D25) |
| `README.md` | Build, verification, documentation map |
| `AGENTS.md`, `CLAUDE.md` | Local assistant rules (not versioned, see `.gitignore`) |

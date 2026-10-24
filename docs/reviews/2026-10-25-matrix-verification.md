# Matrix verification — nine `unverified` rows (M0) — 2026-10-25

Задача: снять `unverified` с девяти строк `TASKS/CAPABILITY_MATRIX.md` (B6, C10, D20, D24, D29,
E1, H4, J5, J7) и поставить честный статус с доказательством `файл:строка`.

Это read-only ревью кода: ни сборки, ни эмулятора, ни install, ни commit/push. Поэтому ни одна
строка **не** могла получить `available` — по правилам матрицы `available` требует трёх условий
(код + тест + работающий сценарий), а witness в этом срезе не снимался.

## Метод

1. Preflight: `TASKS/SLICE_PROTOCOL.md` §1 (preflight), `TASKS/CAPABILITY_MATRIX.md`,
   `TASKS/WORKMAP.md` (M0), `STATUS.md`.
2. Полный обзор поверхности: 374 `.ets` в `entry/src/main/ets`, 87 `.test.ets` в
   `entry/src/ohosTest/ets/test`, 96 host-сьютов `scripts/test-*.cjs` (всего 103 `.cjs` в `scripts/`).
3. По каждой строке — не одиночный keyword-запрос, а проверка **примитива**, без которого
   возможность физически не может существовать:
   - меню → `Menu` / `MenuItem` / `bindMenu` / `bindContextMenu` / `bindPopup` / `bindSheet` /
     `promptAction` / `LongPressGesture` / `gesture(` по всему `ets`;
   - действия → соответствующие `@Event`/`onClick` на реальной поверхности и проводка до use-case;
   - данные → парсинг DTO → reducer → VO → рендер (для «есть ли фича на самом деле»);
   - отправка → ветка `inputMessage*` в `CommandSerializer.ets`.
4. `missing` ставился только после ручного чтения файла-кандидата (не по «0 совпадений»):
   для B6 прочитан `TgChatRow.ets` целиком (280 строк) и место вставки строки в
   `ChatListPage.ets`; для C10 — `TgChatTopBar.ets` (enum + `@Event` + трейлинг-билдер) и проводка
   в `TgChatScreenPage.ets`; для D20/D24/H4 — файлы DTO, сериализатора и экрана настроек.

Границы этого ревью (важно для чтения статусов):

- **Нет runtime-witness.** Всё, что помечено `partial`, подтверждено только статикой — «код есть,
  поведение не наблюдалось».
- **`harmonyos_docs` MCP в этой сессии недоступен** (доступны только REA-серверы). Поэтому
  единственное платформенное утверждение — «числовой `fontSize` в ArkUI трактуется как `fp` и
  масштабируется системной настройкой размера шрифта» — взято из локального знания семантики
  ArkUI и **не** сверено с RAG. Оно влияет только на J7, и J7 всё равно помечен `partial`, а не
  `available`.
- iOS-референс перепроверялся точечно: для B6 открыт
  `submodules/ChatListUI/Sources/ChatContextMenus.swift` (это и есть меню по long-press строки
  чата: mark all as read / archive settings и т.д.), для C10 —
  `submodules/TelegramUI/Sources/Chat/ChatControllerOpenPeer.swift` (`openBotForumMoreMenu`
  собирает `ContextMenuItem`-ы: `Conversation_ContextMenuOpenProfile`, `Conversation_Search`,
  edit title / create topic). Остальные iOS-пути в колонке «iOS-референс» не переоткрывались —
  они не влияли на вердикт.
- **Номера строк — на момент 2026-10-25 04:20 (+08:00).** Часть файлов из цитат (TgChatTopBar.ets, TgMessageRouter.ets, ChatTimelineVO.ets, TgUiTokens.ets, TgChatTimelineRow.ets) параллельно правят другие агенты в этом же рабочем дереве. Якоря перепроверены и приведены к текущему состоянию файлов; при следующем чтении кода их надо сверять заново — номера строк здесь не контракт, контракт — имена символов.

## Итоговая таблица

| Строка | Было | Стало | Главное доказательство |
|---|---|---|---|
| B6 Контекстное меню чата | `unverified` | `missing` | `ChatListPage.ets:1453-1467` — только swipe + click; `TgChatRow.ets` без событий |
| C10 Меню действий шапки | `unverified` | `missing` | `TgChatTopBar.ets:23-27,46-51,619-621`; `TgChatScreenPage.ets:96-107` |
| D20 TTL / self-destruct | `unverified` | `missing` | `CommandSerializer.ets:940,944,949` (`"self_destruct_type":null`); DTO без потребителя |
| D24 Перевод сообщений | `unverified` | `missing` | `translateText` — 0 вызовов; `SettingsPage.ets:283` — иконка локали |
| D29 Кружки | `unverified` | `partial` | `TgInstantVideoBubble.ets:1-249`, `TgMessageRouter.ets:724-743`; отправки нет |
| E1 Меню вложений | `unverified` | `partial` | `TgComposerInput.ets:861-883,1500-1514`; 3 из 6 категорий |
| H4 Данные и хранилище | `unverified` | `missing` | `SettingsPage.ets:260-266` — строка без `onRowClick` |
| J5 Планшет/2in1 | `unverified` | `partial` | `MainTabsPage.ets:952-968`, `ChatSplitGeometry.ets:32` |
| J7 Масштаб шрифта | `unverified` | `partial` | `TgComposerInput.ets:1265-1270` — единственная политика |

---

## B6. Контекстное меню чата → `missing`

**Что искали.** Примитив меню/долгого нажатия на строке списка чатов: `bindContextMenu`,
`Menu`/`MenuItem`, `bindMenu`, `bindPopup`, `LongPressGesture`, `gesture(`, `onTouch` в
`entry/src/main/ets`; затем — ручное чтение строки чата и её места в списке.

**Что нашли.**

- `LongPressGesture` в проекте ровно три: `TgComposerInput.ets:371,427` (удержание для записи
  голосового) и `TgChatTimelineRow.ets:227` (long-press по **сообщению** → `bindPopup`
  `TgChatTimelineRow.ets:211`, это message actions D5/D8, не меню чата).
- `bindContextMenu`, `Menu`, `MenuItem`, `bindMenu` — 0 совпадений во всём `entry/src/main/ets`.
- `TgChatRow.ets` (280 строк, прочитан целиком) — чисто презентационный атом: `@Param`-ы и
  `@Builder`-ы, **ни одного** `onClick`/`@Event`/жеста.
- Единственная интерактивность строки живёт в `ChatListPage.ets:1453-1467`: `.swipeAction({start,
  end})` и `.onClick(() => this.openChat(item))`. В комментарии `:1463-1464` явно записано, почему
  на `ListItem` нет `stateStyles` — прижатие перехватывало тапы свайп-кнопок.
- Что свайпы умеют (`ChatListPage.ets:903-977`): Read/Unread, Pin/Unpin, Mute/Unmute, Delete,
  Archive — то есть **операции** меню существуют, а **меню** нет.

**Вывод.** `missing`. Контекстного меню чата (long-press) в коде нет ни в каком виде; это не
«одно ключевое слово не нашлось» — проверен весь набор примитивов ArkUI для меню и прочитан
файл-кандидат.

**Чем доказано.** `entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets:1453-1467` (только
swipe+click), `entry/src/main/ets/ui/tg_ui/atoms/TgChatRow.ets:236-279` (рендер без событий),
`entry/src/main/ets/ui/pages/chat/TgChatTimelineRow.ets:211,227` (long-press принадлежит
сообщению, не чату). iOS-аналог: `submodules/ChatListUI/Sources/ChatContextMenus.swift`.

**Шов для будущего среза.** Операции уже инкапсулированы в use-case-ах (`pin`, `mute`,
`deleteChatHistory`, `moveChatToList`) и вызываются из свайпов — меню может их переиспользовать,
не дублируя логику.

---

## C10. Меню действий чата (шапка) → `missing`

**Что искали.** Поверхность меню в шапке чата: трейлинг-действия `TgChatTopBar`, какие `@Event`
шапка отдаёт наружу, чем они проводятся в `TgChatScreenPage`, и есть ли где-то «more/overflow»
меню с mute / clear history / delete.

**Что нашли.**

- `TgChatTopBarTrailingAction` (`TgChatTopBar.ets:23-27`) содержит ровно три значения:
  `None`, `Search`, `Avatar`. Никакого `More`/`Overflow`.
- `@Event`-ы шапки (`TgChatTopBar.ets:46-51`): `onBackPress`, `onTitlePress`, `onAvatarPress`,
  `onSearchPress`, `onSearchQueryChange`, `onSearchClose`. Меню-события нет.
- Проводка (`TgChatScreenPage.ets:96-107`): back → `handleBackPress`; title и avatar →
  `openProfile` (`ChatPageNavigationCoordinator.ets:30`); search → `openSearch`.
- `TgChatTopBar.ets:619-621` — трейлинг-билдер умеет только `Avatar` либо `Search`.
- Действия чата в приложении существуют только как свайп в списке чатов (B5). В профиле,
  который открывается тапом по шапке, есть лишь `Notifications`-переключатель
  (`TgProfilePage.ets:749-752`), и он **нефункционален**: `buildSwitchRow` строит
  `Toggle({ type: ToggleType.Switch, isOn })` без `.onChange` — то есть даже этот обходной путь
  мёртв. Это отдельный дефект профиля (не строка C10), но он снимает гипотезу «меню заменили
  профилем».

**Вывод.** `missing`. Шапка не отдаёт наружу действий чата, меню нет ни в шапке, ни в
профиле-обходе.

**Чем доказано.** `entry/src/main/ets/ui/tg_ui/atoms/TgChatTopBar.ets:23-27,46-51,619-621`;
`entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets:96-107`;
`entry/src/main/ets/ui/pages/profile/TgProfilePage.ets:749-752` (+ `buildSwitchRow` без `onChange`).
iOS: `submodules/TelegramUI/Sources/Chat/ChatControllerOpenPeer.swift` (`openBotForumMoreMenu`).

---

## D20. TTL / self-destruct → `missing`

**Что искали.** `ttl`, `messageTtl`, `MessageTtl`, `setChatMessageTtl`, `selfDestruct`,
`SelfDestruct`, `self_destruct_in`, `auto_delete`, `ttlSeconds`, `ChatMessageTtl`.

**Что нашли.** Совпадения по `ttl` оказались производственными (`settled`, `settle`,
`closeWaitSettled`) — это шум. Реальные попадания только два вида:

1. Модель: `internal interface TdSelfDestructType` — `models/td/messages/index.ets:80-81`, поле
   `self_destruct_type?: TdSelfDestructType` — `models/td/messages/index.ets:49`, экспорт в
   `models/TdTypes.ets:54`. Потребителей у поля нет: оно не читается ни в `MessageDto`, ни в
   reducer-ах, ни в VO.
2. Сериализатор: `CommandSerializer.ets:940,944,949` отправляет медиа/голосовые с жёстко
   зашитым `"self_destruct_type":null` — то есть self-destruct не просто не реализован, он
   сознательно выключен в payload-е.

`setChatMessageTtl` (метод TDLib для chat-TTL) не вызывается; в UI нет ни настройки TTL, ни
отсчёта/плашки времени жизни на сообщении (`TgMessageMeta`, `TgChatMeta` — без TTL-полей).

**Вывод.** `missing`. Есть только DTO-объявление и явный `null` в исходящем payload-е — это не
частичная реализация, а её отсутствие (в т.ч. для TTL, который в обычных чатах делается через
`setChatMessageTtl`, а не только в секретных чатах D22/`frozen`).

**Чем доказано.** `entry/src/main/ets/models/td/messages/index.ets:49,80-81`;
`entry/src/main/ets/infra/td/serialization/CommandSerializer.ets:940,944,949`; отсутствие
`setChatMessageTtl` по всему `entry/src/main/ets` (0 совпадений), `entry/src/main/ets/models/TdTypes.ets:54`.

---

## D24. Перевод сообщений → `missing`

**Что искали.** `translate`/`Translation`, `translateMessage`, `translateText`, `translate_text`
в ArkTS; отдельно — есть ли метод в TDLib (`td_api.tl`).

**Что нашли.** Все 12 совпадений `translate` — не про перевод сообщений:

- `SettingsPage.ets:283` — `symbolRes: $r('sys.symbol.translate')` у строки **Language**
  (иконка локали, H7);
- `TgNewChannelPage.ets:24,28`, `TgComposerMotionPolicy.ets:6,15,28,32`, `TgAvatar.ets:69`,
  `TgChatListNavigationBar.ets:495`, `TgMediaGalleryPage.ets:290,585`, `TgPhotoViewerPage.ets:42`
  — `TransitionEffect.translate(...)`/`.translate({...})`, то есть анимация сдвига.

`translateText`/`translate_text` в `entry/src/main/ets` — 0 совпадений: ни `AppCommand`, ни
`CommandSerializer`, ни `TdGateway` этот метод не знают. UI перевода (кнопка в message actions,
выбор языка, состояние «переведено/перевод…») отсутствует.

TDLib-метод при этом есть: `tdlib/td/generate/scheme/td_api.tl:11054`
(`translateText text:formattedText to_language_code:string = FormattedText`), то есть строку
можно закрывать без внешнего блокера.

**Вывод.** `missing` (не `blocked`): метод TDLib доступен, кода нет.

**Чем доказано.** 0 совпадений `translateText`/`translate_text` в `entry/src/main/ets`;
`entry/src/main/ets/ui/pages/settings/SettingsPage.ets:283` (единственный `translate`-символ —
иконка языка); `tdlib/td/generate/scheme/td_api.tl:11054` (доступность метода).

---

## D29. Кружки (video messages) → `partial`

**Что искали.** `InstantVideo`, `videoNote`, `VideoNote`, `roundVideo`, `sendVideoNote`, а затем —
сквозной путь: парсинг DTO → reducer → VO → рендер → скачивание → воспроизведение, и отдельно
**отправка** (`inputMessageVideoNote` в сериализаторе, запись с камеры).

**Что нашли — приём и показ реализованы сквозным путём.**

- Парсинг: `MessageDto.ets:784-797` (`messageVideoNote` → `videoNotePath/FileId/UniqueId`,
  `duration`, `length`, minithumbnail, thumbnail).
- Состояние: `AppState.ets:234-237`, `messagesReducer.ets:105,153-156`, `filesReducer.ets:25,49,141-160`.
- Скачивание: `downloadMessageMedia.ets:185` (`scanFileSlot(content.videoNoteFileId,
  content.videoNotePath, MEDIA_PRIORITY, budget)`).
- VO: `ChatTimelineVO.ets:1012-1024` (кружок маппится в video-поля ряда).
- Рендер: `TgMessageRouter.ets:724-743` → `TgInstantVideoBubble.ets:1-249` — круглая поверхность,
  thumbnail, badge длительности, радиальный прогресс скачивания, отмена, play/download overlay.
  `onPlayToggle` уходит в тот же `onVideoTap` (`TgMessageRouter.ets:735`), то есть воспроизведение
  идёт через видео-плеер.
- Галерея и действия: `TgMediaGalleryPage.ets:84`, `ChatMediaGalleryCoordinator.ets:31,99`,
  `ChatSharedMediaActionCoordinator.ets:84`, `ChatMessageActionsController.ets:326,618`
  (кружок исключён из редактирования).
- Права: `canSendVideoNotes` парсится (`GroupAccessDto.ets:82,95`) и учитывается в политике
  панели (`ChatInputPanelPolicy.ets:14`), в списках типов (`ChatPermissionCoordinator.ets:87`).

**Чего нет — отправки и записи.**

- `CommandSerializer.ets:937-951` знает `inputMessageVoiceNote`, `inputMessagePhoto`,
  `inputMessageVideo`, `inputMessageDocument` (плюс sticker/animation в других ветках), но
  **не** `inputMessageVideoNote`. Кружок отправить нечем.
- Запись кружка (камера + AVRecorder с video-профилем) отсутствует: `ChatVoiceRecordingController.ets`
  — аудио-путь (`media.createAVRecorder` с voice-профилем); `@kit.CameraKit` в
  `ChatComposerController.ets:8` используется для `cameraPicker` (фото), а не для записи видео.
- Живой рендер/воспроизведение не наблюдались (witness нет).

**Вывод.** `partial`: приём, отображение, скачивание и открытие — есть; создание/отправка — нет.
Это не `available`, потому что нет ни теста, ни witness (host-сьюта по кружкам нет; упоминание
`recordingVideoNote` в `scripts/test-chat-top-bar-presentation.cjs` относится к строке превью
чата, не к воспроизведению).

**Чем доказано.** `entry/src/main/ets/ui/tg_ui/atoms/TgInstantVideoBubble.ets:1-249`;
`entry/src/main/ets/ui/tg_ui/molecules/TgMessageRouter.ets:724-743`;
`entry/src/main/ets/core/model/dto/MessageDto.ets:784-797`;
`entry/src/main/ets/domain/usecases/downloadMessageMedia.ets:185`;
`entry/src/main/ets/infra/td/serialization/CommandSerializer.ets:937-951` (нет `inputMessageVideoNote`);
`entry/src/main/ets/ui/pages/chat/ChatVoiceRecordingController.ets:163-180` (только аудио).

---

## E1. Меню вложений → `partial`

**Что искали.** `Attachment`, `attachmentMenu`, `attachmentMenuOpen`, `bindSheet`, `Menu`, плюс
проводку пунктов меню до реальных пикеров.

**Что нашли — меню есть и работает на реальных пикерах.**

- Триггер и состояние: `TgComposerInput.ets:885-893` (`handleAttachPress` переключает
  `attachmentMenuOpen`), презентация — `bindSheet(this.attachmentMenuOpen, …)` на
  `TgComposerInput.ets:1500-1514`.
- Поверхность: `TgAttachmentSheet.ets` — сетка последних медиа (реальные `PhotoAsset` URI,
  `ChatComposerController.ets:100-125`) и рельс из 6 категорий
  (`TgAttachmentSheet.ets:34-49,237-260`): gallery / camera / file / location / poll / contact.
- Проводка: `TgComposerInput.ets:861-883` (`onCategoryPress` → `onAttachmentMenuItemPress`) →
  `ChatScreenSession.ets:407` → `ChatComposerController.ets:83-98`, где
  index 0 → пикер фото/видео, 1 → камера, 2 → пикер документов. Индексы совпадают с порядком
  рельса (0 gallery, 1 camera, 2 file) — расхождения нет.

**Чего нет.**

- Работают 3 из 6 категорий: 3/4/5 (location, poll, contact) выключены дефолтом
  `categoryEnabled = [true, true, true, false, false, false]` (`TgAttachmentSheet.ets:28`) и
  нигде не переопределяются; в `ChatComposerController.ets:95-96` для них `default: break`.
  Визуально они отрисованы с `ATTACHMENT_SHEET_DISABLED_OPACITY` — то есть это не молчаливый
  фейл, но и не функционал.
- `attachmentMenuLabels` (`TgComposerInput.ets:70`, вычисляется в
  `ChatComposerActionBindings.ets:96-103`, прокидывается `TgChatComposerDock.ets:115` и
  `ChatScreenSession.ets:407`) **нигде не рендерится** — подписи берутся из `$r('app.string.attach_*)`
  внутри `TgAttachmentSheet`. Мёртвый параметр + мёртвая функция (мусор, не дефект).
- Теста и witness нет: демо `TgAttachmentSheetDemo` отсутствует, host-сьюта по меню вложений нет
  (`ChatAttachmentFilePreparer` покрыт тестами, но это подготовка файла, а не меню).

**Вывод.** `partial`: меню вложений как поверхность и 3 рабочих категории есть, половина
категорий не реализована, witness нет.

**Чем доказано.** `entry/src/main/ets/ui/tg_ui/atoms/TgComposerInput.ets:70,861-883,885-893,1500-1514`;
`entry/src/main/ets/ui/tg_ui/atoms/TgAttachmentSheet.ets:28,34-49,237-260`;
`entry/src/main/ets/ui/pages/chat/ChatComposerController.ets:83-98,100-125`;
`entry/src/main/ets/ui/pages/chat/ChatComposerActionBindings.ets:96-103` (мёртвые подписи).

---

## H4. Данные и хранилище → `missing`

**Что искали.** `clearCache`, `storageStats`, `databaseSize`, `cacheSize`, `dataAndStorage`,
`optimizeStorage`, `networkUsage`, `AutoDownload`/`auto_download`, `downloadSettings`,
`saveToGallery`; затем — ручное чтение секции настроек и проверка, есть ли за строкой экран.

**Что нашли.**

- Первые семь запросов — 0 совпадений во всём `entry/src/main/ets`.
- Строка «Data and Storage» в настройках **есть**, но без обработчика:
  `SettingsPage.ets:260-266` — `TgSettingsRow({ title: $r('app.string.settings_data_storage'), …,
  trailingType: Arrow })` и **нет** `onRowClick`. Сравнение: у «Recent Calls» `onRowClick` есть
  (`SettingsPage.ets:215-217`). То есть тап по строке ничего не делает — мёртвый контрол
  (нарушение `SLICE_PROTOCOL` §9: disabled-контрол без объяснения).
- Отдельного экрана нет: `entry/src/main/ets/ui/pages/settings/` содержит ровно один файл —
  `SettingsPage.ets`; в `entry/src/main/resources/base/profile/route_map.json` (10 системных
  маршрутов) ни `Storage`, ни `Data` маршрута нет.
- DTO `TdAutoDownloadSettings` / `TdAutoDownloadSettingsPresets` объявлены
  (`models/td/system/index.ets:13-26`, экспорт `models/TdTypes.ets:108-109`), но **нигде не
  используются** — ни запроса, ни редьюсера, ни настройки.

**Вывод.** `missing` для возможности: нет ни одного элемента «данных и хранилища» (use-кейса,
настройки авто-скачивания, размера кеша, очистки). Единственный артефакт — мёртвая строка
настроек, которую надо либо реализовать, либо убрать. Это `missing`, а не `partial`, потому что
за строкой нет поведения — только витрина.

**Чем доказано.** `entry/src/main/ets/ui/pages/settings/SettingsPage.ets:260-266` (без
`onRowClick`) против `:215-217` (живая строка); 0 совпадений `clearCache|storageStats|cacheSize|
dataAndStorage|optimizeStorage|networkUsage` по `entry/src/main/ets`;
`entry/src/main/ets/models/td/system/index.ets:13-26` (неиспользуемый DTO).

---

## J5. Планшет/2in1 адаптив → `partial`

**Что искали.** `breakpoint`, `windowSize`, `windowSizeChange`, `isWide`, `twoPane`,
`NavigationMode.Split`, `navBarWidth`, `minContentWidth`, `split`, `getWindowProperties`.

**Что нашли — split-навигация чатов реализована по-настоящему.**

- `MainTabsPage.ets:952-968`: `Navigation(...).mode(NavigationMode.Auto)` +
  `.navBarWidth(this.chatNavBarWidth)` + `.navBarWidthRange([CHAT_SPLIT_NAV_MIN_WIDTH,
  chatNavBarMaxWidth])` + `.minContentWidth(CHAT_SPLIT_MIN_CONTENT_WIDTH)` +
  `.onNavigationModeChange(...)`, который переключает режим и сбрасывает поиск при входе в Split.
- Геометрия вынесена в чистую функцию: `ui/utils/ChatSplitGeometry.ets:32`
  (`resolveChatSplitGeometry(componentWidth, minNavWidth)`), вызывается из
  `MainTabsPage.ets:558-566` по `.onAreaChange`.
- Пустая правая панель: `MainTabsPage.ets:731-740` рисует
  `TgChatSplitPlaceholder` (`TgChatSplitPlaceholder.ets:7-20`: фон чата + «Start Messaging»),
  когда `chatNavigationMode === NavigationMode.Split`.
- Токены границ: `TgUiTokens.ets:417-418` (`CHAT_SPLIT_NAV_MIN_WIDTH = 320`,
  `CHAT_SPLIT_MIN_CONTENT_WIDTH = 360`).
- Адаптивность по ширине есть и вне split: `ChatWindowGeometryCoordinator.ets:148-156` слушает
  `windowSizeChange` и пересчитывает ширину таймлайна; `SafeAreaUtils.ets:143` —
  `mainWindow.on('windowSizeChange', …)`.

**Чего нет.**

- Адаптивны только чаты (список ↔ чат). Настройки, профиль, звонки, контакты — одноколоночные,
  без брейкпоинтов: поиск `breakpoint`/`Breakpoint` дал 0, `LineBreaker.ets` — это перенос строк
  текста, а не адаптив (в матрице он был указан как «единственное доказательство» — это было
  неверно).
- Нет witness: ни одного запуска на широком окне/2in1 в `STATUS.md`/отчётах не зафиксировано;
  теста на `ChatSplitGeometry` нет (в `scripts/*.cjs` и `ohosTest` файл не упоминается).
- Границы (`CHAT_SPLIT_*`) заданы константами, а не брейкпоинт-системой ArkUI/HDS.

**Вывод.** `partial`: механизм есть, покрытие — только chat-split, подтверждения с устройства нет.

**Чем доказано.** `entry/src/main/ets/ui/pages/MainTabsPage.ets:558-566,731-740,952-976`;
`entry/src/main/ets/ui/utils/ChatSplitGeometry.ets:32`;
`entry/src/main/ets/ui/tg_ui/atoms/TgChatSplitPlaceholder.ets:7-20`;
`entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets:417-418`;
`entry/src/main/ets/ui/pages/chat/ChatWindowGeometryCoordinator.ets:148-156`.

---

## J7. Масштаб шрифта → `partial`

**Что искали.** `fontScale`, `FontScale`, `maxFontScale`, `minFontScale`, `fontSizeScale`,
`onConfigurationUpdate`, `ConfigurationConstant`, а также юниты размеров шрифта (`fp` vs `vp`).

**Что нашли.**

- Приложения-кода, который **читает** системный масштаб шрифта или реагирует на его изменение,
  нет: `onConfigurationUpdate` в `EntryAbility.ets:122-125` обрабатывает только `colorMode`.
- Размеры шрифта задаются числами-токенами (`TgUiTokens.ets:159-165`: `FONT_TITLE_SIZE = 16`,
  `FONT_PREVIEW_SIZE = 15`, `FONT_META_SIZE = 13`, `FONT_BADGE_SIZE = 13`, …), а компоненты
  вызывают `.fontSize(TgUiTokens.X)`. Строк вида `fontSize('16vp')` в проекте нет (0 совпадений)
  — значит шрифт идёт дефолтным `fp`-путём ArkUI и системная настройка размера шрифта на него
  действует по платформенному правилу. (Платформенное утверждение не сверено с `harmonyos_docs` —
  сервер недоступен в этой сессии.)
- Единственное место, где масштаб **явно отключён**: таймер записи голосового —
  `TgComposerInput.ets:1265-1270` (`Text(formatVoiceRecordingDuration(...))` +
  `.minFontScale(1)` + `.maxFontScale(1)`). Это осознанное решение для узкой пилюли записи, но
  больше таких политик в коде нет.
- Адаптации раскладки под увеличенный шрифт нет: нет ни одного расчёта высот/отступов от
  масштаба, ни `Breakpoint`-логики; строки/строки-токены фиксированы (например
  `CHAT_ROW_HEIGHT`, `CHAT_META_TOP_ROW_HEIGHT`). При крупном системном размере шрифта
  переполнение/обрезка вероятны, но это не проверялось.
- Теста и witness нет: в `ohosTest`/`scripts` нет ни одного сьюта про масштаб шрифта; в
  `STATUS.md` нет ни одного прогона с изменённым размером шрифта.

**Вывод.** `partial`, а не `unverified`: код-факт установлен (размеры в fp-числах → платформенное
масштабирование работает; собственной обработки нет; в одном месте масштаб заблокирован). Но это
и не `available`: нет ни адаптации раскладки, ни проверки на реальном устройстве при
увеличенном шрифте. Именно J7 — главный кандидат на runtime-witness в следующем шаге.

**Чем доказано.** `entry/src/main/ets/ui/tg_ui/atoms/TgComposerInput.ets:1265-1270` (единственная
явная политика масштаба); `entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets:159-165` (числовые
размеры шрифта); `entry/src/main/ets/entryability/EntryAbility.ets:122-125` (в
`onConfigurationUpdate` учитывается только `colorMode`); чтения системного масштаба нет нигде в `entry/src/main/ets` (`fontSizeScale`/`fontScale` не читаются; есть только пара `.minFontScale/.maxFontScale` выше); 0 совпадений `fontSize('…vp')`, т.е. все размеры идут в `fp`.

---

## Итог

Было (на момент старта): `available` 34, `partial` 41, `missing` 17, `unverified` 9, `frozen` 3,
`blocked` 1 — всего 105 строк. После верификации:

| Статус | Было | Стало |
|---|---|---|
| `available` | 34 | **34** (не изменилось: witness не снимался) |
| `partial` | 41 | **45** (+D29, E1, J5, J7) |
| `missing` | 17 | **22** (+B6, C10, D20, D24, H4) |
| `unverified` | 9 | **0** |
| `frozen` | 3 | 3 |
| `blocked` | 1 | 1 |

**Ни одна из девяти строк не стала `available`** — по правилам матрицы для этого нужен
работающий сценарий/witness, а срез был read-only.

### Требуют runtime-witness (в порядке полезности)

1. **J7 Масштаб шрифта** — прогон при увеличенном системном размере шрифта (например 1.3×, 1.5×,
   2.0×): проверить строку чата, шапку, композер, бабл, настройки; зафиксировать обрезку/наезды.
   Ожидаемый первый дефект — фиксированные высоты строк (`CHAT_ROW_HEIGHT`,
   `CHAT_META_TOP_ROW_HEIGHT`) при выросшем fp.
2. **J5 Планшет/2in1** — запуск на широком окне/2in1: split-режим, `navBarWidthRange`,
   placeholder, поведение поиска при входе в Split (`MainTabsPage.ets:960-968`).
3. **E1 Меню вложений** — открыть шит, проверить 3 живые категории (галерея/камера/файл) и что
   3 выключенные выглядят как выключенные, а не как мёртвые.
4. **D29 Кружки** — при наличии кружка в чате: превью, скачивание, прогресс, воспроизведение,
   поведение при ошибке/отмене.

### Побочные дефекты, найденные по пути (не строки этого среза)

- `SettingsPage.ets:260-266` — строка «Data and Storage» без `onRowClick`: мёртвый контрол.
  Либо реализовать вместе с H4, либо убрать.
- `TgProfilePage.ets:749-752` + `buildSwitchRow` — переключатель «Notifications» без `.onChange`:
  визуально живой, фактически мёртвый. Это делает недоступным обходной путь к mute и вредит C10/H3.
- `TgComposerInput.ets:70` / `ChatComposerActionBindings.ets:96-103` /
  `TgChatComposerDock.ets:115` — `attachmentMenuLabels` вычисляется и прокидывается, но не
  рендерится (мёртвая проводка).
- `models/td/system/index.ets:13-26` — `TdAutoDownloadSettings*` объявлены без потребителя.

### Что изменено в репозитории

Изменён только `TASKS/CAPABILITY_MATRIX.md`, и только то, что относится к девяти строкам:

- девять строк: колонка статуса + колонка доказательства (и минимально — `Связанные / шов` и
  iOS-референс там, где старый указатель был неточен: B6 → `ChatListUI/Sources/ChatContextMenus.swift`,
  C10 → `ChatControllerOpenPeer.swift`);
- блок «Итог и следующий шаг»: пересчитаны счётчики и заменён абзац «Приоритет верификации»,
  который перечислял ровно эти девять строк (иначе документ врал бы о состоянии).

Остальные 96 строк матрицы не тронуты. `docs/reviews/INDEX.md` не обновлялся — по условию
задачи писать можно только в матрицу и этот отчёт; строку в индексе должен добавить тот, у кого
этот файл в скоупе.

Ничего не собиралось, не устанавливалось и не коммитилось.

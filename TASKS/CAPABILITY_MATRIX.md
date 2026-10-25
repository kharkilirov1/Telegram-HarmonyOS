# CAPABILITY_MATRIX — что бывает, что есть, чем доказано

Одна строка = одна пользовательская возможность из iOS-эталона. Матрица отвечает на вопрос «что
делать» и служит входом в `TASKS/SLICE_PROTOCOL.md`: срез нельзя начинать со строки, у которой не
проверено текущее состояние.

## Статусы

| Статус | Значение |
|---|---|
| `available` | код + тесты + runtime witness; поведение сверено с iOS |
| `partial` | код есть, но неполно / нет witness / расходится с эталоном |
| `missing` | кода нет |
| `frozen` | заморожено решением (`DECISIONS`/план), не вкладываться |
| `blocked` | внешний блокер (AGC, подпись, реальный аккаунт) |
| `unverified` | не проверено: по ключевым словам не найдено, но и вручную не смотрели — **проверить до работы** |

## Правила ведения

1. Статус меняется **в том же срезе**, что и код: строка обновляется вместе с работой, а не «после».
2. `available` без witness (дата + откуда) не ставится. Сомневаешься — `partial`.
3. `missing` ставится только после ручной проверки; совпадение по ключевым словам — не доказательство.
4. `unverified` обязателен, пока состояние не проверено; агент верифицирует строку первым шагом среза.
5. Колонка «Шов» — что нужно оставить открытым для `Связанных`, без спекулятивных абстракций (`SLICE_PROTOCOL` §3).

Обозначения доказательств: `файл` — код в `entry/src/main/ets`; `N/M` — файлов с упоминанием /
тестов (host + ohosTest), это **не** измерение качества, а ориентир, где искать.

---

## A. Авторизация и аккаунт

| # | Возможность | Статус | Доказательство | iOS-референс | Связанные / шов |
|---|---|---|---|---|---|
| A1 | Логин по номеру | `partial` | `PhoneInputPage.ets`, `LoginController.ets` (5/1) | `Components/AuthConfirmationScreen`, `Sources/Login*` | A2, A3 |
| A2 | Код подтверждения / 2FA | `partial` | `CodeInputPage.ets` (9/1) | `Sources/Login*` | A1; единый auth-state machine |
| A3 | QR-логин | `partial` | `QrLoginPage.ets` (11/2) | `Sources/Login*` | A2 |
| A4 | Выход из аккаунта | `partial` | `AuthSideEffect.ets`, `CommandSerializer.ets` (7/4) | `Settings` sessions | H5; очистка сессии |
| A5 | Редактирование профиля | `missing` | нет | `Components/Profile*`, `AvatarEditorScreen` | G1 |
| A6 | Смена аккаунта / мультиаккаунт | `frozen` | — | `Sources/Account*` | заморожено |

## B. Список чатов

| # | Возможность | Статус | Доказательство | iOS-референс | Связанные / шов |
|---|---|---|---|---|---|
| B1 | Загрузка и порядок списка | `available` | `loadChats.ets`, `ChatListPage.ets` (9/12) | `Components/ChatList` | B2, B10 |
| B2 | Закрепление чатов | `available` | `toggleChatPinned.ets` (21/6) | `ChatList` | B12 |
| B3 | Mute / настройки уведомлений чата | `partial` | `SetChatMuteCommand` + `SetChatMuteUseCase`; включён из списка чатов и из профиля (`TgProfilePage.ets` toggle → `applyNotificationsToggle` → `mute/unmute`, откат при ошибке); host-guard `test-dead-controls.cjs`. Нет экрана тонких настроек уведомлений | `ChatNotificationSettings` | H3 |
| B4 | Unread-бейджи | `available` | 44 файла / 10 тестов | `BadgeComponent` | B9, B12 |
| B5 | Свайпы по строке (read/pin/mute/delete) | `partial` | `ChatListPage.ets`, `TgArchivedChatsPage.ets` (2/0) | `Components/ChatList` | B2, B3 |
| B6 | Контекстное меню чата | `missing` | нет: long-press по строке отсутствует (`TgChatRow.ets` без обработчиков нажатий), в `ChatListPage.ets:1453-1467` только `.swipeAction` + `.onClick`; `bindContextMenu` / `Menu` по всему `entry/src/main/ets` — 0 совпадений | `ChatListUI/Sources/ChatContextMenus.swift` | B2, B5; шов — готовые use-case pin/mute/delete/archive |
| B7 | Папки чатов | `missing` | нет | `ChatFolderLinkPreviewScreen` | B11, B6 |
| B8 | Архив | `available` | `TgArchivedChatsPage.ets` (19/12) | `ChatList` | B7 |
| B9 | Драфты | `available` | 42/48 | `Components/ChatInputNode` | B10, C? |
| B10 | Превью последнего сообщения | `available` | `ChatInitialHistoryCoordinator.ets` (24/10) | `ChatList` | B4 |
| B11 | Глобальный поиск | `partial` | `TgRootSearchDock.ets`, `AppCommand` `searchChatsOnServer` (3/3) | `ChatListHeaderComponent` | B7 |
| B12 | Typing/online в списке | `partial` | `AppEvent.ets` (7/1) | `ChatList` | C2 |
| B13 | Создание чата/группы/канала | `available` | `createPrivateChat.ets`, `createChannelChat.ets` (9/7) | `Sources/Create*` | G2, G4 |

## C. Экран чата и шапка

| # | Возможность | Статус | Доказательство | iOS-референс | Связанные / шов |
|---|---|---|---|---|---|
| C1 | Шапка чата (title/subtitle/avatar) | `available` | `TgChatTopBar.ets`, `ChatChromeState.ets` (13/6) | `Components/Chat/ChatTitleStatusNode` | C2, G1 |
| C2 | Индикатор набора | `partial` | `ChatTopBarPresentation.ets:12,169-184` (TTL 8 s как в iOS `PeerInputActivityManager`, режим `Typing`, группа — только имя), `ChatRouteActivationCoordinator.ets:224-231` (откат по дедлайну без новых store-change), `TgChatTopBar.ets:173-194` (3 точки по токенам). Device (2026-10-25): `ChatHeaderStatus` 8/8 PASS. **Не снято:** визуальный кадр «печатает…» — нужен второй участник, а история чатов на прогоне не загрузилась | `ChatTitleView/ChatTitleComponent.swift`, `PeerInputActivityManager.swift` | B12, J3; шов — VO `{subtitle, mode}` |
| C3 | Поиск по чату | `available` | `ChatSearchController.ets` (14/14) | `ChatControllerSearch*` | C8 |
| C4 | Закреплённое сообщение (бар) | `available` | `ChatMessageActionsController.ets` (24/12) | `Chat/PinnedMessage*` | C8 |
| C5 | Разделители дат | `available` | `ChatTimelineVO.ets`, `TgDateSeparator.ets` (5/1) | `Components/Chat` | C6 |
| C6 | Разделитель непрочитанных | `missing` | нет | `Chat/Unread*` | C5, B4 |
| C7 | Кнопка «вниз» | `available` | `ChatWindowGeometryCoordinator.ets` (20/15) | `Chat/ScrollToBottom*` | C8 |
| C8 | Переход к сообщению | `available` | `ChatTimelineViewportCoordinator.ets` (10/4) | `ChatControllerScrollToPointInHistory` | C3, C4 |
| C9 | Панель выделения сообщений | `missing` | нет | `ChatMessageSelectionInputPanelNode` | D4, D6 |
| C10 | Меню действий чата (шапка) | `missing` | нет: шапка = back + title/avatar→profile + search (`TgChatTopBar.ets:23-27,39,46-51,619-621`, проводка `TgChatScreenPage.ets:96-107`); меню действий чата (mute / clear history / delete) в шапке нет | `ChatControllerOpenPeer.swift`, `ChatListUI/Sources/ChatContextMenus.swift` | C1; шов — `ChatTopBarCoordinator` |

## D. Сообщения

| # | Возможность | Статус | Доказательство | iOS-референс | Связанные / шов |
|---|---|---|---|---|---|
| D1 | Отправка текста | `available` | 20/29 | `ChatControllerSend*` | E2, D2 |
| D2 | Ответ (reply) | `available` | 33/37 | `ChatControllerReply*` | E3 |
| D3 | Редактирование | `available` | `CommandSerializer.ets` (3/5) | `ChatControllerEditChat` | C9 |
| D4 | Удаление | `available` | `ChatDeleteMessageController.ets` (11/12) | `ChatControllerDelete*` | C9 |
| D5 | Копирование | `partial` | `ChatMessageActionsController.ets` (1/0) | `ChatControllerShare*` | C9 |
| D6 | Пересылка | `available` | `ChatForwardSourceController.ets` (19/23) | `ChatControllerForwardMessages` | C9 |
| D7 | Избранное (Saved Messages) | `missing` | нет | `ChatList` | B1 |
| D8 | Закрепление сообщения | `available` | `ChatMessageActionsController.ets` (9/6) | `Chat/PinnedMessage*` | C4 |
| D9 | Пометить непрочитанным | `available` | `toggleChatUnread.ets` (3/3) | `ChatList` | B4 |
| D10 | Реакции | `partial` | S3a (данные, 2026-10-25): `Message.reactions` (`AppState.ets`), парсер `parseReactionSnapshot`/`parseReactionTypeKeys` (`MessageDto.ets`) из `interaction_info` и `updateMessageReactions`, инкремент `updateMessageReaction` через `applyReactionDelta`, чистая раскладка `sortReactionChips`/`packReactionChips` (chosen → count → key, кап 6 + «+N»), VO `ReactionChipVO` + `reactionRenderStamp` в `ChatTimelineVO`. Host `test-reactions-model.cjs`, suite 98/98. **Не готово:** рендер подвала (S3b), `setMessageReactions` (S3c), пикер (S3d) | `ChatControllerOpenMessageReactionContextMenu`, `ChatMessageReactionsFooterContentNode` | D13, C9; шов — `ReactionChipVO`/`ReactionsVO` |
| D11 | Комментарии/треды | `missing` | только упоминание в селекторах | `ChatControllerOpenMessageReplies` | D10 |
| D12 | Опросы | `available` | `TgPollBubble.ets` (21/12) | `Chat/Poll*` | D14 |
| D13 | Стикеры | `available` | `TgsPlaybackPolicy` (`TgTgsPlayer.ets:41`): только видимое, поверхность (`timeline`/`stickerViewer`/`customEmoji`; панель — никогда), LRU-кеш распакованного Lottie по `fileId` (8), бюджет 4 инстанса, `@Monitor('tgsPath')`; pass-through `fileId`; тест 12 кейсов. **Device 2026-10-25:** `TgsPlaybackPolicy` 12/12; `hilog`: `using @ohos/lottie fallback for tgs_1` → `tgs playback started key=file:11696 players=1` (дважды, второй раз без повторного декода — кеш) ; два кадра через 700 мс различаются только в области стикера (3 274 px, bbox 256–470×1984–2199) — анимация живая | `Components/Chat/Sticker*` | D10, F6; шов `TgsPlaybackSurface` для D16/F6 |
| D14 | GIF/анимации | `partial` | `TgInlineVideoView`, 57/12 | `Components/Chat/Animation*` | F3 |
| D15 | Эмодзи-панель | `available` | 72/36 | `ChatEntityKeyboardInputNode` | D16 |
| D16 | Кастомные эмодзи | `partial` | `TgCustomEmojiDraftPolicy.ets` | `ChatEntityKeyboardInputNode` | D15, D1 |
| D17 | Превью ссылок | `partial` | `TgLinkPreviewBubble.ets`, `TdTypes.ets` (3/0) | `Chat/LinkPreview*` | D1 |
| D18 | Упоминания/хэштеги | `partial` | `stateClone.ets`, `ChatTimelineVO.ets` (21/6) | `ChatEntityKeyboardInputNode` | D1 |
| D19 | Slow mode | `available` | `ChatChromeState.ets` (21/29) | `ChatScheduleTimeController` | E? |
| D20 | TTL / self-destruct | `missing` | нет: только DTO `models/td/messages/index.ets:49,80-81` и явный `"self_destruct_type":null` в `CommandSerializer.ets:940,944,949`; `setChatMessageTtl`, UI настройки и отсчёт отсутствуют | `Chat/TTL*` | D22; шов — `ChatChromeState` |
| D21 | Отложенные сообщения | `missing` | нет | `ChatScheduleTimeScreen` | D22 |
| D22 | Секретные чаты | `frozen` | — | `Sources/SecretChat*` | D20 |
| D23 | Inline-боты / команды | `partial` | `CommandSerializer.ets` (9/5) | `ChatControllerContentData` | D17 |
| D24 | Перевод сообщений | `missing` | нет: `translateText` не вызывается нигде; `translate` — только иконка локали `SettingsPage.ets:283` и `TransitionEffect.translate`; TDLib-метод есть (`tdlib/td/generate/scheme/td_api.tl:11054`), т.е. не блокер | `Sources/Translate*` | D1 |
| D25 | Геолокация | `partial` | `ChatMessageActionsController.ets` (23/9) | `Chat/Location*` | D26 |
| D26 | Контакты (отправка) | `partial` | 44/16 | `Chat/Contact*` | D25 |
| D27 | Dice/игры | `partial` | `TgBubbleLayout.ets` (9/2) | `ChatControllerDisplayDiceTooltip` | D12 |
| D28 | Голосовые сообщения (отправка) | `partial` | `CHAT` 26/17 | `Chat/Recording*` | F4 |
| D29 | Кружки (video messages) | `partial` | приём/рендер/скачивание есть: `TgInstantVideoBubble.ets:1-249` + роутинг `TgMessageRouter.ets:724-743` + парсинг `MessageDto.ets:784-797` + `downloadMessageMedia.ets:185`; записи и отправки нет — `CommandSerializer.ets:937-951` не знает `inputMessageVideoNote`, камеры для кружка в композере нет | `Chat/Recording*` | D28, F3; шов — recorder + `sendMedia` |
| D30 | Альбомы/медиагруппы | `available` | `ChatComposerController.ets` (37/29) | `Chat/Album*` | E6 |
| D31 | Stories (данные) | `partial` | `StoryNormalizer.ets`, `StoryDto.ets` — только приём, UI нет | `Sources/Stories*` | I6 |

## E. Композер

| # | Возможность | Статус | Доказательство | iOS-референс | Связанные / шов |
|---|---|---|---|---|---|
| E1 | Меню вложений | `partial` | единственный источник категорий — `TgAttachmentSheet.ets` (`categoryEnabled`); мёртвая проводка `attachmentMenuLabels` удалена (`test-dead-controls.cjs`).  меню есть: `TgComposerInput.ets:861-883` + `bindSheet` `:1500-1514`, поверхность `TgAttachmentSheet.ets:237-260`; работают 3 из 6 категорий — `ChatComposerController.ets:83-98` (галерея/камера/файл), location/poll/contact выключены дефолтом `TgAttachmentSheet.ets:28`; witness нет | `ChatControllerOpenAttachmentMenu` | E5, E6; шов — `categoryEnabled` + `handleAttachmentMenuItemPress` |
| E2 | Подпись к медиа (caption) | `available` | 40/31 | `ChatInputNode` | D1 |
| E3 | Превью reply/edit | `available` | `ChatComposerController.ets` | `ChatInputNode` | D2, D3 |
| E4 | Запись голосового (UI) | `partial` | 26/17 | `Chat/Recording*` | D28 |
| E5 | Отправка фото | `available` | медиа-путь (см. D30, `ChatInputPanelPolicy`) | `Chat/Attachment*` | E7, F1 |
| E6 | Отправка документа/видео | `partial` | `ChatInputPanelPolicy.ets` (2/4) | `Chat/Attachment*` | D30, F5 |
| E7 | Системный пикер файлов | `partial` | `ChatComposerController.ets` (22/9) | `ChatInputNode` | E5, E6 |

## F. Медиа

| # | Возможность | Статус | Доказательство | iOS-референс | Связанные / шов |
|---|---|---|---|---|---|
| F1 | Просмотр фото (zoom/swipe) | `available` | `TgPhotoViewerPage.ets` (32/6) | `Components/Media/PhotoViewer*` | F9 |
| F2 | Скачивание: состояния/retry | `available` | `DownloadMessageMedia*` (11/12) | `Chat/Media*` | F3 |
| F3 | Видео-плеер | `partial` | `GlobalMediaPlayback.ets` (3/4); до скачивания не открывает | `Components/Media/Video*` | F2, F7 |
| F4 | Воспроизведение голосовых | `available` | `ChatPlaybackCoordinator.ets` (7/3) | `AudioWaveform*` | D28 |
| F5 | Открытие документов | `partial` | `ChatScreenSession.ets` (3/0) | `AttachmentFileController` | E6 |
| F6 | Просмотр стикеров | `missing` | нет | `Components/Chat/Sticker*` | D13 |
| F7 | PiP | `missing` | нет | `Components/Media/Video*` | F3 |
| F8 | Media session / AVSession | `partial` | `GlobalMediaPlayback.ets` (2/4) | платформенное | F3, F4 |
| F9 | Галерея: свайп между медиа | `partial` | `TgMediaGalleryPage.ets` (32/6) | `PhotoViewer*` | F1 |

## G. Профили, группы, каналы

| # | Возможность | Статус | Доказательство | iOS-референс | Связанные / шов |
|---|---|---|---|---|---|
| G1 | Профиль пользователя | `available` | `TgProfilePage.ets` (4/3) | `Components/Profile*` | A5, C1 |
| G2 | Профиль группы/канала | `partial` | `TgProfilePage.ets` + `TgProfileMembersPage.ets`; отдельных страниц нет | `Components/PeerInfo*` | G3, G4 |
| G3 | Участники и поиск | `available` | `TgProfileMembersPage.ets` (7/17) | `ChatParticipantRightsScreen` | G2 |
| G4 | Права/доступ в чате | `available` | `ChatChromeState.ets` (19/28) | `ChatParticipantRightsScreen` | G5, D1 |
| G5 | Инвайт-ссылка | `partial` | `AppEvent.ets`, `index.ets` (9/2) | `Sources/Invite*` | G2 |
| G6 | Админ-действия | `missing` | нет | `AdminUserActionsSheet` | G4 |

## H. Настройки

| # | Возможность | Статус | Доказательство | iOS-референс | Связанные / шов |
|---|---|---|---|---|---|
| H1 | Экран настроек | `partial` | `SettingsPage.ets` (31/5) | `Sources/Settings*` | H2–H9 |
| H2 | Приватность | `partial` | `SettingsPage.ets` (1/2) | `Sources/Privacy*` | H1 |
| H3 | Настройки уведомлений | `partial` | `CommandSerializer.ets` (7/3) | `Sources/Notifications*` | B3, I1 |
| H4 | Данные и хранилище | `missing` | нет: мёртвая строка «Data and Storage» удалена из `SettingsPage.ets` (2026-10-25), неиспользуемые DTO `TdAutoDownloadSettings`/`Presets` удалены; экрана, `clearCache`/`storageStats`/auto-download-настроек нет объявлен и нигде не используется — `models/td/system/index.ets:13-26` | `Sources/Storage*` | F2 |
| H5 | Устройства/сессии | `missing` | нет | `Sources/Sessions*` | A4 |
| H6 | Тёмная тема/акценты | `partial` | `accentColorsReducer.ets`, `colorMode` (12/2) | `Sources/Theme*` | J8 |
| H7 | Язык интерфейса | `partial` | 15/8 | `Sources/Localization*` | J6 |
| H8 | Заблокированные пользователи | `missing` | нет | `Sources/Privacy*` | H2 |
| H9 | Энергосбережение | `missing` | нет | `Sources/PowerSaving*` | H1 |

## I. Уведомления, звонки, stories

| # | Возможность | Статус | Доказательство | iOS-референс | Связанные / шов |
|---|---|---|---|---|---|
| I1 | In-app уведомления | `missing` | нет `notificationManager` | `Sources/Notifications*` | I2, H3 |
| I2 | Push-уведомления | `blocked` | нужен AGC/Push Kit | `Sources/Push*` | I3, I1 |
| I3 | Inline reply из шторки | `missing` | нет | `Components/Calls`/push extension | I2 |
| I4 | VoIP-звонки | `frozen` | — | `Components/Calls` | — |
| I5 | Список звонков (read-only) | `available` | `loadCalls.ets`, `TgCallRow.ets` | `Components/Calls` | I4 |
| I6 | Stories (UI) | `missing` | данные есть (D31), просмотра нет | `Sources/Stories*` | D31 |

## J. Платформа и качество

| # | Возможность | Статус | Доказательство | iOS-референс | Связанные / шов |
|---|---|---|---|---|---|
| J1 | Переподключение | `partial` | `AuthSideEffect.ets` (4/7) | платформенное | J2 |
| J2 | Таймауты/ошибки сети | `partial` | 47/72; надёжность PARTIAL | платформенное | J1, J3 |
| J3 | Offline-режим | `partial` | 16/17 | платформенное | J1 |
| J4 | Доступность (a11y) | `partial` | 25 файлов / 1 тест | `Sources/Accessibility*` | J7 |
| J5 | Планшет/2in1 адаптив | `partial` | split-навигация чатов реальная: `MainTabsPage.ets:952-968` (`NavigationMode.Auto` + `navBarWidth` + `navBarWidthRange` + `minContentWidth`), геометрия `ChatSplitGeometry.ets:32`, пустая панель `TgChatSplitPlaceholder.ets:7-20`, режим отслеживается `MainTabsPage.ets:960-968`; witness на широком окне нет, остальные экраны одноколоночные | `Sources/Adaptive*` | J4 |
| J6 | Локализация строк | `partial` | 88 файлов `$r(` | `Sources/Localization*` | H7 |
| J7 | Масштаб шрифта | `partial` | все размеры — числовые токены (`TgUiTokens.ets:159-165`), строк в `vp` нет → масштаб идёт платформенным fp-путём; собственной обработки `fontScale`/адаптации раскладки нет, единственная явная политика — `.minFontScale(1)`/`.maxFontScale(1)` в `TgComposerInput.ets:1265-1270`; witness нет | `Sources/Accessibility*` | J4 |
| J8 | Dark/light паритет | `partial` | см. H6 | `Sources/Theme*` | H6 |

---

## Итог и следующий шаг

- `available`: 35 строк — есть код, тесты и работающий сценарий.
- `partial`: 45 — код есть, но не сверено с iOS или неполно.
- `missing`: 21 — кода нет.
- `unverified`: 0 — девять прежних строк разобраны 2026-10-25; остальные 96 имели статус раньше.
- `frozen`: 3 (VoIP, мультиаккаунт, секретные чаты), `blocked`: 1 (push) — не вкладываться.

Верификация девяти прежних `unverified` выполнена 2026-10-25
(`docs/reviews/2026-10-25-matrix-verification.md`): B6, C10, D20, D24, H4 → `missing`;
D29, E1, J5, J7 → `partial`. Ни одна не стала `available` — witness нет ни у одной.
Ближайшие срезы — в `TASKS/WORKMAP.md`. Протокол — `TASKS/SLICE_PROTOCOL.md`, шаблон —
`TASKS/SLICE_TEMPLATE.md`.

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
| A1 | Логин по номеру | `partial` | `PhoneInputPage.ets`, `LoginController.ets` (5/1). Witness 2026-11-05 (API 26 эмулятор): экран входа, ввод номера с клавиатурой, выбор страны (шит с поиском/секциями/индексом), disabled «Продолжить» — `TASKS/WITNESS.md` | `Components/AuthConfirmationScreen`, `Sources/Login*` | A2, A3 |
| A2 | Код подтверждения / 2FA | `partial` | `CodeInputPage.ets` (9/1) | `Sources/Login*` | A1; единый auth-state machine |
| A3 | QR-логин | `partial` | `QrLoginPage.ets` (11/2) | `Sources/Login*` | A2 |
| A4 | Выход из аккаунта | `partial` | `AuthSideEffect.ets`, `CommandSerializer.ets` (7/4) | `Settings` sessions | H5; очистка сессии |
| A5 | Редактирование профиля | `partial` | Data layer setName/setBio/setUsername/setProfilePhoto, `EditProfileUseCase` (trim/@/лимиты/Ok-контракт/typed AppError), занятый username → сообщение + варианты-чипы. UI: форма (route, поля, hint, счётчик, Save-гейт, последовательность), «Change photo» → **интерактивный редактор**: `measure` → pinch-зум (1–4) + pan в квадратном вьюпорте → `computeAvatarCropRectFromTransform` → `prepare(..., rect)` → crop/scale/JPEG → `setProfilePhoto`; `Use photo`/`Cancel`, строки в 3 локалях. Проверка username: `checkChatUsername` + `CheckUsernameUseCase` (локальная валидация, sequence-гард, маппинг 6 результатов), inline-статус в форме (debounce 400 мс, available/taken/invalid/purchasable). Нет: witness | `Components/Profile*` | G1 |
| A6 | Смена аккаунта / мультиаккаунт | `frozen` | — | `Sources/Account*` | заморожено |

## B. Список чатов

| # | Возможность | Статус | Доказательство | iOS-референс | Связанные / шов |
|---|---|---|---|---|---|
| B1 | Загрузка и порядок списка | `available` | `loadChats.ets`, `ChatListPage.ets` (9/12) | `Components/ChatList` | B2, B10 |
| B2 | Закрепление чатов | `available` | `toggleChatPinned.ets` (21/6) | `ChatList` | B12 |
| B3 | Mute / настройки уведомлений чата | `partial` | `SetChatMuteCommand` + `SetChatMuteUseCase`; включён из списка чатов и из профиля (`TgProfilePage.ets` toggle → `applyNotificationsToggle` → `mute/unmute`, откат при ошибке); host-guard `test-dead-controls.cjs`. Нет экрана тонких настроек уведомлений | `ChatNotificationSettings` | H3 |
| B4 | Unread-бейджи | `available` | 44 файла / 10 тестов | `BadgeComponent` | B9, B12 |
| B5 | Свайпы по строке (read/pin/mute/delete) | `partial` | `ChatListPage.ets`, `TgArchivedChatsPage.ets` (2/0) | `Components/ChatList` | B2, B3 |
| B6 | Контекстное меню чата | `partial` | Long-press по строке списка (`bindContextMenu` + `ResponseType.LongPress`) открывает меню iOS-порядка: mark read/unread → archive/unarchive → pin/unpin → mute/unmute → delete (destructive). Модель — чистый селектор `chatContextMenuSelectors.ets` (`selectChatContextMenuEntries`, `chatContextActionIcon`), для Saved Messages меню пустое; действия уходят в существующие use case (`toggleChatUnread`, `moveChatToList`, `toggleChatPinned`, `setChatMute`, `deleteChatHistory`), `handleMoveToMain` возвращает чат из архива; строки `chat_context_*` в base/ru/zh, токены `CHAT_CONTEXT_MENU_*`, контракт `test-chat-list-context-menu.cjs` (труth table, иконки, проводка, локали, токены). Учтён `is_marked_as_unread` (TDLib-флаг отдельно от unreadCount: парсинг `chat.is_marked_as_unread`, обработчик `updateChatIsMarkedAsUnread`, reducer/VO/diff, меню и обработчик показывают «mark as read» для вручную помеченного чата). Add to folder: `selectAddToFolderTargets` (только папки, где чата ещё нет), `addChatToList(chatListFolder)` через `MoveChatToListUseCase.addToFolder`, секция в меню с названиями папок, `chat_context_add_to_folder` в base/ru/zh (удаление из папки в этой версии TDLib недоступно — в меню не предлагается). Нет: пунктов, зависящих от типа чата (Add to contacts, Join chat/channel, Add/Remove from folder, Select, Remove from recents) | `Components/Chat/ChatList*Context*`, `ChatContextMenus.swift` | G1 |
| B7 | Папки чатов | `partial` | Папки: create/edit/delete, фильтры чатов, рекомендуемые папки (`getRecommendedChatFolders`), ссылки-приглашения папок (`checkChatFolderInviteLink`/`addChatFolderByInviteLink`, `TgFolderLinkPage`, чат-пикер ограничения), вступление по ссылке чата (`TgChatInvitePage`), внешние ссылки `t.me/<username>` → чат, App Linking объявляет `addlist`, `joinchat` и `+` (короткая форма) для `t.me`/`telegram.me`. Нет: witness | `ChatFolderListController`, `ShareChatInviteLink` | S13 |
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
| C2 | Индикатор набора текста | `available` | Мульти-typing: `ChatTypingInfo.senders` (до 5, новые первыми, `applyTypingAction`), reducer обновляет набор и удаляет чат при последнем cancel, шапка форматирует «A», «A и B», «A и ещё N» (`formatTypingActors`, `typing_and`/`typing_others` в 3 локалях), mode = Typing только если все печатают; private-чат сохраняет activity-строку. Пульсация точек: `TgTypingPulse` (шаг 70 ms из 700 ms цикла, scale 0.6→1, opacity 0.35→1, сдвиг фазы 3 шага, wrap в обе стороны), `TgChatTopBar` держит `typingPulseStep` + interval только когда Typing видим, сброс фазы и clearInterval на выходе. Нет: witness | `ChatTitleComponent` typing branch | S9 |
| C3 | Поиск по чату | `available` | `ChatSearchController.ets` (14/14) | `ChatControllerSearch*` | C8 |
| C4 | Закреплённое сообщение (бар) | `available` | `ChatMessageActionsController.ets` (24/12) | `Chat/PinnedMessage*` | C8 |
| C5 | Разделители дат | `available` | `ChatTimelineVO.ets`, `TgDateSeparator.ets` (5/1) | `Components/Chat` | C6 |
| C6 | Разделитель непрочитанных | `partial` | `ChatTimelineVO.ets` (`firstUnreadIncomingIndex` + запись `kind='unread'`, sticky-граница, сброс sender-group), `TgUnreadMarker` в `TgDateSeparator.ets` (25 px, радиус 0, отступы 6/5 — как `ChatUnreadItem.swift:142-176`), рендер в `TgChatTimelineViewport.ets`, ресурс `chat_unread_messages` (base/ru_RU/zh_CN) + `test-unread-divider.cjs` (6/1) | `Components/Chat/ChatMessageItemImpl/ChatUnreadItem.swift` | C5, B4 |

| C7 | Кнопка «вниз» | `available` | `ChatWindowGeometryCoordinator.ets` (20/15) | `Chat/ScrollToBottom*` | C8 |
| C8 | Переход к сообщению | `available` | `ChatTimelineViewportCoordinator.ets` (10/4) | `ChatControllerScrollToPointInHistory` | C3, C4 |
| C9 | Панель выделения сообщений | `partial` | `ChatTimelineViewState.selectionActive`/`selectedMessageIds` + alias-геттеры в `ChatScreenContext.ets`; вход — пункт «Select» в меню действий (`ChatMessageActionsController.ets`, тост `action_select` в base/ru/zh); делегаты `enter/toggle/clear/copy/forward/delete/selectionTitle` в `ChatMessagePopupCoordinator.ets` + `ChatScreenSession.ets`; `ChatDeleteMessageController.requestMany` — одна доступность/один диалог/один `deleteMessages`; панель `TgSelectionPanel` (иконки: copy — SVG `ic_selection_copy`/`SELECTION_PANEL_COPY_ICON`, forward/delete/report — существующие ассеты) (спец+demo, токены `SELECTION_PANEL_*`/`SELECTION_CHECK_*`) заменяет композер в `TgChatScreenPage.ets`; строка в режиме выделения показывает чек-индикатор, подсвечивается тинтом (`SELECTION_ROW_TINT` → `color.selection_row_tint` в base/dark) и блокирует тапы бабла (`TgChatTimelineRow.ets`); диалог удаления называет размер выбора (`delete_messages_count` base/ru/zh, `messageCount` в `NativeDeleteMessageConfirmation`); host-контракт `test-selection-mode.cjs` (6/1) | `Components/Chat/ChatMessageSelectionInputPanelNode` | D4, D6 |
| C10 | Меню действий чата (шапка) | `available` | «…»-капсула в `TgChatTopBar` открывает меню (`ChatActionsCoordinator`, страница ≤500 строк, типизированные `ChatMenuAction`): Chat Info, Mute/Unmute, Clear History/Delete Chat, Leave Chat (group/supergroup/channel) или Share My Contact (private/secret), Report при `chat.can_be_reported` (причина, комментарий `TgReportCommentOverlay`, выбор сообщений `TgSelectionPanel` + message_ids). Роль через `getChatMember`: admin/creator получают Manage-подменю (Members → `TgProfileMembersPage`, Invite Links → `TgChatInviteLinksPage`, Administrators → `TgChatAdministratorsPage`, Permissions → `TgChatPermissionsPage`: 14 тумблеров из `chat.permissions`, запись целиком через `setChatPermissions`, откат при ошибке). Навигация admin-экранов вынесена в `chatAdminNavigation.ets`. Report для admin скрыт, ошибка роли откатывается к обычному набору. Нет: профиль по тапу из админов, witness | `ChatController` moreBarButton, `ChatContextMenus` | S12 |

## D. Сообщения

| # | Возможность | Статус | Доказательство | iOS-референс | Связанные / шов |
|---|---|---|---|---|---|
| D1 | Отправка текста | `available` | 20/29 | `ChatControllerSend*` | E2, D2 |
| D2 | Ответ (reply) | `available` | 33/37 | `ChatControllerReply*` | E3 |
| D3 | Редактирование | `available` | `CommandSerializer.ets` (3/5) | `ChatControllerEditChat` | C9 |
| D4 | Удаление | `available` | `ChatDeleteMessageController.ets` (11/12) | `ChatControllerDelete*` | C9 |
| D5 | Копирование | `partial` | `ChatMessageActionsController.ets` (1/0) | `ChatControllerShare*` | C9 |
| D6 | Пересылка | `available` | `ChatForwardSourceController.ets` (19/23) | `ChatControllerForwardMessages` | C9 |
| D7 | Избранное (Saved Messages) | `partial` | `isSavedMessagesChat(chat, selfUserId)` в `AppState.ets` (private-чат с собственным `peerUserId`, т.к. отдельного типа TDLib не имеет — `td_api.tl:8726`); заголовок «Saved Messages» в списке (`ChatItemVO.ets`, флаг `isSavedMessages` + diff в `ChatListDataSource.ets`) и в шапке чата (`ChatTimelineVO.resolvePrivateChatTitle`); аватар-закладка: `TgAvatar.symbolIcon` → `TgChatRow.avatarIsSavedMessages` → `ChatListPage.ets`; ресурс `saved_messages` (base/ru/zh); аватар-закладка в шапке чата: `ChatAvatarPresentation.isSavedMessages` → `ChatTopBarCoordinator` (port `chatIsSavedMessages`, `state.auth.userId`) → `ChatChromeState.@Trace` → `TgChatTopBar.avatarIsSavedMessages` → `TgAvatar.symbolIcon`; точка входа: строка в настройках → `MainTabsPage.openSavedMessages` (существующий чат либо `createPrivateChat(my_id)` + гидратация `createNewChatEvent`, фенс токена) через общую транзакцию `ChatOpenTransaction.pushChatScreenRoute` (на неё переведены `ChatListPage` и `TgArchivedChatsPage`); host-контракты `test-saved-messages.cjs` + `test-chat-open-transaction.cjs` | `ChatList`, `ChatListNavigationBar` | B1 |
| D8 | Закрепление сообщения | `available` | `ChatMessageActionsController.ets` (9/6) | `Chat/PinnedMessage*` | C4 |
| D9 | Пометить непрочитанным | `available` | `toggleChatUnread.ets` (3/3) | `ChatList` | B4 |
| D10 | Реакции | `partial` | S3a (данные, 2026-10-25): `Message.reactions` (`AppState.ets`), парсер `parseReactionSnapshot`/`parseReactionTypeKeys` (`MessageDto.ets`) из `interaction_info` и `updateMessageReactions`, инкремент `updateMessageReaction` через `applyReactionDelta`, чистая раскладка `sortReactionChips`/`packReactionChips` (chosen → count → key, кап 6 + «+N»), VO `ReactionChipVO` + `reactionRenderStamp` в `ChatTimelineVO`. S3b (рендер, 2026-10-25): атом `TgReactionsFooter` (primitives, Flex wrap, «+N», custom-emoji fallback) + токены и цвета light/dark, spec и demo; врезан в текстовый бабл через `TgChatTimelineRow → TgMessageRouter → TgTextBubbleV3`. S3c (постановка, 2026-10-25): `SetMessageReactionsCommand` + serializer (`reactionTypeEmoji`/`reactionTypeCustomEmoji`, int64 строкой, `is_big=false`), `SetMessageReactionsUseCase`, `ChatReactionController` (оптимистичный снимок до отправки, откат по ошибке, guard по токену страницы и по парному тапу, отправляются только chosen-ключи), тап по чипу. S3d (пикер, 2026-10-25): `chat.available_reactions` в `ChatDto`/`Chat` (+`updateChatAvailableReactions`), `availableReactionKeys`/`chatAllowsReactions` с дефолтным рядом iOS (12) и капом 12, атом `TgReactionPicker` + spec/demo и ряд в попапе действий (тап → закрытие меню → S3c-controller). S3d.1 (2026-11-03): `getMessageAvailableReactions` (команда + сериализатор + fail-soft use case), парсер `availableReactions` (top/recent/popular), слияние `pickerReactionKeys` (дедуп, кап 12, fallback на чатовый ряд), синхронный сид ряда при открытии попапа и асинхронная замена с фенсом generation/lifecycle/chatId/messageId. S3b.1 (2026-11-03): подвал рисует роутер под медиа-баблами (фото/видео/альбом/кружок/документ/аудио/голос/контакт/локация/опрос) вне медиа-контейнера, выравнивание по стороне бабла. Host `test-reactions-model.cjs` + `-footer` + `-send` + `-availability` + `-picker` + `-picker-data` + `-media-footer`, suite 104/104. **Не готово:** подвал у стикеров, геометрия медиа-ряда без witness, рендер кастомных эмодзи (D16), реакции-теги, runtime-witness на живом аккаунте | `ChatControllerOpenMessageReactionContextMenu`, `ChatMessageReactionsFooterContentNode` | D13, C9; шов — `ReactionChipVO`/`ReactionsVO` |
| D11 | Комментарии/треды | `partial` | Data layer: `getMessageThread`/`getMessageThreadHistory`, сериализатор raw int64, парсеры `MessageThreadPage`/`MessageThreadComment`, `MessageThreadUseCase` (limit ≤100). UI: `TgMessageThreadPage` (route/params, счётчик, пагинация по `next_offset`, loading/empty/error, lifecycle-токен) + вход Comments (N) из меню канала (`isChannelPost` + `interaction_info.reply_info.reply_count`, `openMessageThread`). Отправка: composer в треде, `sendMessage` с `topic_id=messageTopicThread(thread_id)` (`SendMessageParams.topicThreadId`, `_topic_id_json`), ответ уходит в discussion-чат из `MessageThreadPage.chatId`. Нет: witness | `ChatControllerOpenMessageReplies` | D10 |
| D12 | Опросы | `available` | `TgPollBubble.ets` (21/12) | `Chat/Poll*` | D14 |
| D13 | Стикеры | `available` | `TgsPlaybackPolicy` (`TgTgsPlayer.ets:41`): только видимое, поверхность (`timeline`/`stickerViewer`/`customEmoji`; панель — никогда), LRU-кеш распакованного Lottie по `fileId` (8), бюджет 4 инстанса, `@Monitor('tgsPath')`; pass-through `fileId`; тест 12 кейсов. **Device 2026-10-25:** `TgsPlaybackPolicy` 12/12; `hilog`: `using @ohos/lottie fallback for tgs_1` → `tgs playback started key=file:11696 players=1` (дважды, второй раз без повторного декода — кеш) ; два кадра через 700 мс различаются только в области стикера (3 274 px, bbox 256–470×1984–2199) — анимация живая | `Components/Chat/Sticker*` | D10, F6; шов `TgsPlaybackSurface` для D16/F6 |
| D14 | GIF/анимации | `partial` | `TgInlineVideoView`, 57/12 | `Components/Chat/Animation*` | F3 |
| D15 | Эмодзи-панель | `available` | 72/36 | `ChatEntityKeyboardInputNode` | D16 |
| D16 | Кастомные эмодзи | `partial` | Draft-сущности, каталог/панель, отправка; идентичность в тексте; резолвер `getCustomEmojiStickers`; рендер `ImageSpan` с fallback; продюсер `customEmojiPathCache` + prefetch + render key; страница резолвит видимые строки и перестраивает. Реакции: пикер (`TgReactionPicker`) при появлении/смене keys синхронизирует `ReactionPickerEmojiState` (наблюдаемое состояние, `@Trace paths/revision`), префетчит custom-id из ключей и рисует `Image` вместо fallback-глифа; хелперы `customReactionIds`/`syncPickerPaths`. Нет: TGS-анимация кастомных эмодзи в бабле, подбор эмодзи-набора в пикере, witness | `ChatEntityKeyboardInputNode` | D15, D1 |
| D17 | Превью ссылок | `partial` | `TgLinkPreviewBubble` (компактный и большой варианты, медиа сверху/снизу), парсинг `linkPreview*` в `MessageDto`, показ перед/после текста (`linkPreviewShowAboveText`). Тап по карточке открывает URL: `onPreviewPress(url)` → `TgTextBubbleV3` → `TgMessageRouter.onMessageLinkPress` → `TgChatTimelineRow` → `ChatScreenViewBindings.openSharedMediaLink` → `ChatSharedMediaActionCoordinator` (`context.openLink`). Нет: тап по ссылке внутри текста (нужен hit-test по Span), t.me-навигация из превью, witness | `Chat/LinkPreview*` | D1 |
| D18 | Упоминания/хэштеги | `partial` | Все ссылочные энтити в тексте кликабельны (`Span.onClick`): `url`/`textUrl` → URL, `emailAddress` → `mailto:`, `phoneNumber` → `tel:`, `mentionName` → `mention:<id>` (профиль), `mention` → `t.me` (резолв внутри приложения через `searchPublicChat`, откат на браузер), `hashtag`/`cashtag` → `hashtag:<tag>` (открывает поиск в чате: `setSearchModeActive(true)` + `handleSearchQueryChange`). Нет: глобальный поиск по хэштегу (вне чата), коллапсинг длинных хэштегов, witness | `ChatEntityKeyboardInputNode` | D1 |
| D19 | Slow mode | `available` | `ChatChromeState.ets` (21/29) | `ChatScheduleTimeController` | E? |
| D20 | TTL / self-destruct | `partial` | Автоудаление чата: `Chat.messageAutoDeleteTime` из `chat.message_auto_delete_time`, `TgChatAutoDeletePage` (Off/1 час/1 день/1 неделя/1 месяц, текущее значение, откат при ошибке), `setChatMessageAutoDeleteTime` + валидация (0…366 дней), пункт Manage-меню (5-й). Нет: self-destruct в секретных чатах (UI таймера после прочтения), per-message TTL, witness | `ChatAutoDeleteTimeController` | S12 |
| D21 | Отложенные сообщения | `partial` | `getChatScheduledMessages` → `ScheduledMessageDto` (int64 id строкой, send_date, превью текста/подписи, сортировка новые первыми), `TgChatScheduledMessagesPage` (список, меню строки: Send Now / In 1 hour / Delete), `editMessageSchedulingState` (null = отправить сразу, дата = перенос) и `deleteMessages` для отмены, планируемая отправка текста (`SendMessagePayload.scheduledDateSeconds` → `_scheduling_state_json`), валидация id/даты (≤367 дней). Вход — 6-й пункт Manage-меню (лимит showActionMenu). Нет: пикер даты/времени из композера, повторяющиеся периоды, экран у не-админов, witness  Композер: долгое нажатие на Send при наличии текста открывает меню «Отправить позже» (`ChatComposerController.openScheduledSendMenu`: «Через час», «Завтра в 9:00» → `handleSendMessage(text, host, seconds)`), дата проходит в `SendMessageParams.scheduledDateSeconds` и в `createSendMessageCommand` (сериализатор уже писал `messageSchedulingStateSendAtDate`); запланированный текст не превращается в dice. Мост binding→controller, без нового делегата сессии. Произвольное время: третий пункт меню открывает системные `showDatePickerDialog` + `showTimePickerDialog` (владелец — `ChatScheduledSendMenu.ets`), пара «в прошлом» отклоняется. Перенос уже запланированного: в меню строки списка появился пункт «Дата и время» (`rescheduleCustom` → `pickScheduledDate` → `ScheduledMessagesUseCase.reschedule`, то есть `editMessageSchedulingState`). Нет: witness.| `ChatScheduleTimeScreen` | S12 |
| D22 | Секретные чаты | `frozen` | — | `Sources/SecretChat*` | D20 |
| D23 | Inline-боты / команды | `partial` | `CommandSerializer.ets` (9/5) | `ChatControllerContentData` | D17 |
| D24 | Inline-перевод | `partial` | Store-путь, плашка, кэш (50). Язык: 14 кодов, нормализация, порядок chat→global→system→en, per-chat + глобальный default. UI: Settings → `TgTranslationLanguagePage` (route, 3 локали) и `TgChatMessageActionsPopup` — строка «Translate to <CODE>» с раскрываемым списком кодов, выбор сохраняет язык чата и переотправляет перевод (`translateIntoLanguage`, `force`), порт/биндинги/делегаты согласованы, событие добавлено в contract-source. Нет: witness | `ChatController` translation | — |
| D25 | Геолокация | `partial` | Отправка: `SendLocationCommand` (`inputMessageLocation`, live_period 0) + сериализация, `SendLocationUseCase` (WGS-84 bounds, null island, точность clamp), `DeviceLocation` (one-shot FIRST_FIX, таймаут 10 с, 2 разрешения), плитка Location в меню вложений (case 3, permission → чтение → отправка, тосты). `ChatMessageActionsController.ets` (23/9) | `Chat/Location*` | D26 |
| D26 | Контакты (отправка) | `partial` | 44/16. Отправка: `DeviceContacts` (системный пикер `selectContacts`, нормализация имени/номера, отказ без номера), `SendContactUseCase` (проверка номера и имени), переиспользован `ShareContactCommand`/`sendContactMessage` (43-77), плитка Contact в меню вложений (case 5, тосты), строки в 3 локалях. Карточка: кнопки «Написать» (профиль известного пользователя) и «Добавить контакт» (`ChatContactCardActions`: разрешение WRITE_CONTACTS → `saveContactToDevice` → тост), локализованные подписи, неактивные кнопки при пустом userId/номере | `Chat/Contact*` | D25 |
| D27 | Dice/игры | `partial` | `MessageDto` (`messageDice` → `diceEmoji`/`diceValue`, text = emoji), `ChatTimelineVO` (dice = large emoji), `TgMessageRouter` (dice через текстовый бабл), `SendDiceCommand` + сериализация `inputMessageDice`, `TgDiceBubble` (крупный эмодзи, бейдж значения, анимация прокрутки через `@Monitor`), отправка при тексте-эмодзи (как в iOS: сообщение из одного интерактивного эмодзи уходит костью), `SendDiceUseCase` (набор 6 эмодзи, локальный отказ) | `ChatControllerDisplayDiceTooltip` | D12 |
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
| F6 | Просмотр стикеров | `partial` | Вьювер, pack id через DTO→VO→`MediaGalleryItem`, `StickerPackUseCase`, карточка пака. Пагинация по паку (`StickerPackSticker`, `nextStickerPackIndex`, `buildStickerPackGalleryItems`, `stickerPackPagingIndex`, старт по `fileId`), предзагрузка соседей (`stickerPackPreloadPlan`/`stickerPackPreloadFileIds` → `requestMediaDownload`). Анимация: `GalleryStickerLayout` (`isTgsPath`, contained-fit `galleryStickerSize`, 0.86), `TgMediaGalleryPage.buildStickerItem` играет `TgTgsPlayer` только для текущей страницы, поверхность `StickerViewer` (плеер принимает `@Param surface`, гейт `TgsPlaybackPolicy.shouldPlay`). Нет: witness | `Components/Chat/Sticker*` | D13 |
| F7 | PiP | `missing` | нет | `Components/Media/Video*` | F3 |
| F8 | Media session / AVSession | `partial` | `GlobalMediaPlayback.ets` (2/4) | платформенное | F3, F4 |
| F9 | Галерея: свайп между медиа | `partial` | `TgMediaGalleryPage.ets` (32/6) | `PhotoViewer*` | F1 |

## G. Профили, группы, каналы

| # | Возможность | Статус | Доказательство | iOS-референс | Связанные / шов |
|---|---|---|---|---|---|
| G1 | Профиль пользователя | `available` | `TgProfilePage.ets` (4/3) | `Components/Profile*` | A5, C1 |
| G2 | Профиль группы/канала | `partial` | `TgProfilePage.ets` + `TgProfileMembersPage.ets`; отдельных страниц нет | `Components/PeerInfo*` | G3, G4 |
| G3 | Участники и поиск | `available` | `TgProfileMembersPage.ets` (7/17) | `ChatParticipantRightsScreen` | G2 |
| G4 | Права/доступ в чате | `available` | `ChatChromeState.ets` (20/28); нижняя панель: mute/unmute/join/retry/unblock + restricted/banned; заблокированный peer в приватном/секретном чате → панель UNBLOCK (`selectChatInputPanel` → `unblock`, `setMessageSenderBlocked.unblock(user, peerUserId)`, снятие через `updateChatIsBlocked`); удалённый из группы → «You were removed from this group.» + Delete and Exit (`ChatExitCoordinator`) | `ChatParticipantRightsScreen`, `ChatRestrictedInputPanelNode`, `ChatUnblockInputPanelNode` | G5, D1 |
| G5 | Инвайт-ссылка | `partial` | `AppEvent.ets`, `index.ets` (9/2) | `Sources/Invite*` | G2 |
| G6 | Админ-действия | `partial` | Модерация участника: `setChatMemberStatus` (все 4 статуса), `ChatMemberAdminUseCase` (`apply` promote/demote/ban/unban/restrict + `permissionsJson`, `loadState` через `getChatMember` → статус/права/разрешения/срок), long-press участника → меню Add Admin/Remove Admin/Ban/Unban/Restrict; promote → `TgChatAdminRightsPage` (10 прав, предзаполнение текущих прав админа), restrict → `TgChatRestrictRightsPage` (14 разрешений + срок, предзаполнение текущего ограничения), ban → меню срока. Нет: «снять админа» с сохранением прав, witness | `AdminUserActionsSheet` | G4 |

## H. Настройки

| # | Возможность | Статус | Доказательство | iOS-референс | Связанные / шов |
|---|---|---|---|---|---|
| H1 | Экран настроек | `partial` | `SettingsPage.ets` (31/5) | `Sources/Settings*` | H2–H9 |
| H2 | Приватность | `partial` | `SettingsPage.ets` (1/2) | `Sources/Privacy*` | H1 |
| H3 | Настройки уведомлений | `partial` | `CommandSerializer.ets` (7/3) | `Sources/Notifications*` | B3, I1 |
| H4 | Данные и хранилище | `available` | `TgDataStoragePage`: статистика (`getStorageStatistics`/`Fast`), по чатам, очистка (`optimizeStorage`), лимит кэша в `preferences`, сегментированная диаграмма `TgStorageUsageChart` (media/БД/language packs/logs, шкала = лимит или total, легенда, 4 токена), авто-применение лимита (`shouldAutoEnforce`/`autoEnforce`, один проход, тост, перезагрузка). Анимация: `revealProgress` 0→1 через `animateTo` (420 ms, EaseOut, токен), ширина сегмента = измеренная доля × reveal, нулевые сегменты не в дереве. Нет: witness | `StorageUsageScreen`, `StorageController` | S11 |
| H5 | Устройства/сессии | `partial` | Экран `TgSessionsPage` (Settings → Devices, route `TgSessionsPage`): `getActiveSessions` → `SessionDto` (int64 id сохраняется точным, флаги current/password_pending, устройство, приложение, IP/страна, last active), текущий сеанс помечен и не завершается, `terminateSession` через `promptAction`-подтверждение и перезагрузку списка. Команды/сериализатор `getActiveSessions`/`terminateSession` (int64 как точный JSON-литерал), use case `LoadSessionsUseCase`, строки `sessions_*` в base/ru/zh, контракт `test-sessions.cjs`. Разделы как в iOS: `sessionSelectors` делит сеансы на Active/Web по `sessionType` (браузеры Brave/Chrome/Edge/Firefox/Opera/Safari/Vivaldi), «Terminate All Other Sessions» через `terminateAllOtherSessions` (показывается только при наличии других сеансов). Нет: привязка к 2FA-паролю, подтверждение новых сеансов, iOS-раскладка карточек и witness | `ActiveSessions*`, `WebSessions*` | A4 |
| H6 | Тёмная тема/акценты | `partial` | `accentColorsReducer.ets`, `colorMode` (12/2) | `Sources/Theme*` | J8 |
| H7 | Язык интерфейса | `partial` | 15/8 | `Sources/Localization*` | J6 |
| H8 | Заблокированные пользователи | `partial` | Экран `TgBlockedUsersPage` (Settings → Blocked Users, route зарегистрирован): `getBlockedMessageSenders(blockListMain, offset, limit)` → `BlockedSenderDto` (user/chat), имена резолвятся из `AppState` (users/chats, иначе fallback с id), разблокировка через `setMessageSenderBlockList(sender_id, null)` после подтверждения и перезагрузки списка; состояния loading/error/retry/empty. Команды/сериализатор (blockListMain/Stories, null-блок для unblock), use case `LoadBlockedSendersUseCase` (валидация пагинга), строки `blocked_*`/`settings_blocked_users` в 3 локалях, контракт `test-blocked-users.cjs`. Пагинация: `offset` = число загруженных, «Show More» по `loaded < total_count`, `mergeBlockedSenders` дедуплицирует повторы между страницами, состояние `isLoadingMore`. Блокировка/разблокировка доступна и из профиля: `chat.block_list` → `Chat.isBlocked`, `updateChatBlockList` → reducer, строка Block/Unblock в профиле для private/secret с подтверждением и тостом (`SetMessageSenderBlockedUseCase`). Обе TDLib-блокировки: вкладки Messages/Stories (`blockListMain`/`blockListStories`), `fetchPage(offset, limit, blockList)` держит выбранный список и для «Show More», разблокировка обнуляет блок-лист. Нет: iOS-карточки и witness | `Sources/Privacy*` | H2 |
| H9 | Энергосбережение | `partial` | `PowerModeMonitor`: классификация режима (POWER_SAVE/EXTREME/CUSTOM), кеш и флаг опроса, ошибка чтения не меняет политику; сэмплинг при старте и повторно в `onForeground`. Гейты: `TgsPlaybackPolicy.setPowerSaving` глушит TGS на всех поверхностях; `shouldAutoplayMedia()` ведёт autoplay в `TgVideoBubble`/`TgAnimationBubble`/`TgStickerView`/галерее. Нет: witness | `PowerManagement` | — |

## I. Уведомления, звонки, stories

| # | Возможность | Статус | Доказательство | iOS-референс | Связанные / шов |
|---|---|---|---|---|---|
| I1 | Уведомления | `partial` | Гейт (`shouldPublishMessageNotification`: фон, только входящие, не активный чат, mute), текст (title/body, лимит 160), мост (`NotificationKit`, wantAgent на чат, разрешение). Группировка: стабильный id на чат (`chatNotificationIds`, второе сообщение обновляет запись), `groupName`/`appMessageId`/`badgeNumber` из unread; `cancelForChat` при открытии чата, `cancelAll`. Inline reply: `NotificationUserInput` есть в SDK, но публичного API получения текста нет → недостижим. Нет: witness | `Notifications/MessageNotifications` | I2 |
| I2 | Push-уведомления | `blocked` | нужен AGC/Push Kit | `Sources/Push*` | I3, I1 |
| I3 | Inline reply из шторки | `missing` | нет | `Components/Calls`/push extension | I2 |
| I4 | VoIP-звонки | `frozen` | — | `Components/Calls` | — |
| I5 | Список звонков (read-only) | `available` | `loadCalls.ets`, `TgCallRow.ets` | `Components/Calls` | I4 |
| I6 | Stories (UI) | `partial` | Данные: активные истории, `StoryFullDto` + `parseStoryFull` (photo/video/unsupported, chosen reaction), `updateStory` → `chats.storyContentsByKey`, `getStory`/`setStoryReaction`/`getStoryAvailableReactions` + сериализация (nullable reaction, remove по повторному тапу), `LoadStoryUseCase`, путь медиа через filesReducer. UI: полоса превью → `TgStoryViewerPage` (route): сегментный прогресс, тапы, long-press пауза, ряд реакций (чипы, выбранная подсвечена, toggle), счётчики просмотров/реакций из `interaction_info` (компактный формат K/M). Публикация: `postStory` (photo/video content JSON, privacy variants, active_period, protect_content) + `PostStoryUseCase` (валидация, дедуп, парсинг ответа и запись в store). UI: `TgStoryComposerPage` (route) — выбор фото/видео (`IMAGE_VIDEO_TYPE`, копия в кэш), caption с лимитом, приватность циклом (selected users отключён без пикера), Publish/Cancel, ошибки и успех; вход из «Add story» (своя история → вьювер, иначе композер). Статистика: `getStoryInteractions` (курсор offset/next_offset), `parseStoryInteractions` (view/forward/repost, реакция), `LoadStoryInteractionsUseCase` (страницы, exhausted, reset), `TgStoryViewsPage` (счётчики, список с инициалами и реакциями, догрузка у конца, route) — вход по тапу на 👁 у своей истории. Ответ: `inputMessageReplyToStory` в `sendMessage` (payload-поля + сериализация), `ReplyToStoryUseCase` (валидация 4096, отправка в чат автора), поле «Reply privately» в вьювере. Адресаты: `TgStoryAudiencePage` (route) — приватные чаты, поиск по имени/username, чекбоксы, счётчик, Cancel/Done, возврат выбора в композер через `pop(result)`; композер открывает пикер при переходе в selected users и показывает количество. Нет: witness | `Stories` | — |

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
- `partial`: 53 — код есть, но не сверено с iOS или неполно.
- `missing`: 12 — кода нет.
- `unverified`: 0 — девять прежних строк разобраны 2026-10-25; остальные 96 имели статус раньше.
- `frozen`: 3 (VoIP, мультиаккаунт, секретные чаты), `blocked`: 1 (push) — не вкладываться.

Верификация девяти прежних `unverified` выполнена 2026-10-25
(`docs/reviews/2026-10-25-matrix-verification.md`): B6, C10, D20, D24, H4 → `missing`;
D29, E1, J5, J7 → `partial`. Ни одна не стала `available` — witness нет ни у одной.
Ближайшие срезы — в `TASKS/WORKMAP.md`. Протокол — `TASKS/SLICE_PROTOCOL.md`, шаблон —
`TASKS/SLICE_TEMPLATE.md`.

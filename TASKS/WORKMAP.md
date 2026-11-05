# WORKMAP — карта работ на сейчас

Живёт только «сейчас»: 1–3 активных среза и ближайший backlog. Каждый срез — по
`TASKS/SLICE_PROTOCOL.md`; вход — строка `TASKS/CAPABILITY_MATRIX.md`. Перегенерируется после
каждого закрытого среза. Долг — в `TASKS/TODO.md` (§Debt).

**Обновлено:** 2026-11-03 (S3d.1)

## Закрыто в этой волне

| # | Срез | Строка | Результат |
|---|---|---|---|
| M0 | Верификация 9 `unverified` | B6, C10, D20, D24, D29, E1, H4, J5, J7 | `unverified` = 0; матрица 105 строк с доказательствами |
| S1 | Typing indicator | C2 | TTL 8 s, откат по дедлайну, группа — имя, приватный — текст, точки; **чает witness** (нужен второй аккаунт) |
| S1.1 | Тексты и TTL списка | C2/B12 | «печатает…» в ресурсах, один TTL в шапке и списке; harness починен, host 96/96 |
| S2 | Стикеры/TGS | D13 | политика видимости, кеш по `fileId`, бюджет 4, `@Monitor`; witness снят на устройстве, D13 → `available` |
| S3 | Reactions | D10 | дизайн-документ `docs/specs/2026-10-25-reactions-design.md`, код не писался |
| S4 | Мёртвые контролы | B3, E1, H4 | профильный Toggle → `SetChatMuteCommand`; строка «Data and Storage» удалена; мёртвая проводка `attachmentMenuLabels` удалена; DTO `TdAutoDownloadSettings` удалены; guard `test-dead-controls.cjs` |
| S3a | Reactions — данные | D10 | модель чипов + парсер TDLib + события/reducer + VO + `test-reactions-model.cjs`; D10 → `partial` |
| S3b | Reactions — подвал (текст) | D10 | атом `TgReactionsFooter` + токены/цвета + spec/demo + интеграция в текстовый бабл + `test-reactions-footer.cjs` |
| S3c | Reactions — постановка | D10 | команда + сериализатор + use case + `ChatReactionController` (optimistic/откат, guard) + тап по чипу + `test-reactions-send.cjs` |
| S3d | Reactions — пикер (быстрый ряд) | D10 | `available_reactions` в `ChatDto`/`Chat` + `availableReactionKeys`/`chatAllowsReactions` + атом `TgReactionPicker` + spec/demo + ряд в попапе действий + `test-reactions-availability.cjs`/`-picker` |
| S3d.1 | Reactions — пикер (per-message) | D10 | `getMessageAvailableReactions` + команда/сериализатор/use case + слияние `pickerReactionKeys` (top→recent→popular, кап 12, fallback на чат) + фенс устаревших ответов + `test-reactions-picker-data.cjs` |
| S3b.1 | Reactions — подвал в медиа | D10 | подвал рисует роутер под медиа-баблами (фото/видео/альбом/кружок/документ/аудио/голос/контакт/локация/опрос), стикер — долг из-за фиксированной высоты + `test-reactions-media-footer.cjs` |
| S5a | Непрочитанный разделитель (верификация C6) | C6 | строка была `missing`: код (`firstUnreadIncomingIndex`, `kind='unread'`, sticky, сброс sender-group) уже был, но без тестов; добавлены паспорт `TgUnreadMarker` (iOS-геометрия 25/0/6/5), ресурс `chat_unread_messages` (base/ru/zh вместо «Unread») + `test-unread-divider.cjs`; C6 → `partial` |
| S5b | Панель выделения сообщений (C9) | C9 | `selectionActive`/`selectedMessageIds` + пункт «Select» + удаление многих через `requestMany` + панель `TgSelectionPanel` (spec/demo/токены) вместо композера + чек-индикатор и блокировка тапов в строке + `test-selection-mode.cjs`; C9 → `partial` |
| S6a | Избранное — представление (D7) | D7 | `isSavedMessagesChat` + заголовок «Saved Messages» в списке и шапке + аватар-закладка (`TgAvatar.symbolIcon`) + флаг в diff + `test-saved-messages.cjs`; D7 → `partial` |
| S6b | Избранное — точка входа (D7) | D7 | строка в настройках → `MainTabsPage.openSavedMessages` (существующий чат или `createPrivateChat(my_id)` + гидратация) через общий `ChatOpenTransaction.pushChatScreenRoute` (чат-лист и архив переведены) + `test-chat-open-transaction.cjs` |
| S7a | Папки чатов — слой данных (B7) | B7 | `ChatFolderInfo`/`ChatFoldersState` в AppState, `ChatFolderNormalizer` (`updateChatFolders`), `chatFoldersReducer`, селектор вкладок с позицией All chats, `test-chat-folders.cjs`; B7 → `partial` |
| S7b.1 | Папки чатов — членство (B7) | B7 | `ChatDto.folderOrders`/`extractFolderPosition`, `Chat.folderOrders`, добавление/удаление через `updateChatAddedToList`/`RemovedFromList`, `selectChatIdsForFolder` + контракт |
| S7b.2 | Папки чатов — полоса и фильтрация (B7) | B7 | `TgChatListFilterTab` в полосе, проброс через nav bar, `ChatListPage` выбирает папку и строит список из `selectChatIdsForFolder`, unread-счётчики по спискам и бейджи, `chat_folders_all`; контракт расширен |
| S7b.3 | Папки чатов — пагинация (B7) | B7 | `loadChats(chatListFolder)` в payload/сериализаторе, `LoadFolderChatsUseCase` (in-flight + cooldown + cancel), запрос на выбор папки и на скролл, контракт |
| S8a | Контекстное меню чата (B6) | B6 | `chatContextMenuSelectors` + `bindContextMenu` long-press, iOS-порядок действий, делегирование use case, `chat_context_*` в 3 локалях, токены, контракт; B6 → `partial` |
| S8b.1 | Mark-as-unread: двусторонний флаг (B6) | B6 | `is_marked_as_unread` в DTO/модели/normalizer (`updateChatIsMarkedAsUnread`)/reducer/VO/diff, меню и обработчик используют флаг; контракт расширен |
| S8b.2 | Add to folder в контекстном меню (B6) | B6 | `addChatToList(chatListFolder)` в payload/сериализаторе, `MoveChatToListUseCase.addToFolder`, `selectAddToFolderTargets`, секция папок в меню, `chat_context_add_to_folder`; контракт расширен |
| S9 | Устройства/сессии (H5) | H5 | `getActiveSessions`/`terminateSession` (команды, сериализатор), `SessionDto` + точный int64 через `getTopLevelRawObjectArrayStrict`, `LoadSessionsUseCase`, `TgSessionsPage` + route + строка Settings → Devices, `sessions_*` в 3 локалях, контракт; H5 → `partial` |
| S9b | Сессии — Active/Web и завершение всех (H5) | H5 | `sessionType` в DTO, `sessionSelectors` (web-типы, секции, canTerminateOthers), `terminateAllOtherSessions` (команда/сериализатор/use case), две секции и destructive-строка в странице, строки в 3 локалях, контракт расширен |
| S10 | Заблокированные пользователи (H8) | H8 | `getBlockedMessageSenders`/`setMessageSenderBlockList` (block → main, unblock → null), `BlockedSenderDto`, `LoadBlockedSendersUseCase`, `TgBlockedUsersPage` + route + строка Settings, `blocked_*` в 3 локалях, контракт; H8 → `partial` |
| S11 | Данные и хранилище (H4) | H4 | `getStorageStatisticsFast`/`getStorageStatistics`/`optimizeStorage` (команды, сериализатор), `StorageStatisticsDto` + `formatStorageBytes`, `LoadStorageStatisticsUseCase`, `TgDataStoragePage` + восстановленная строка Settings + route, `data_storage_*` в 3 локалях, контракты data-storage и dead-controls; H4 → `partial` |
| S11b | Авто-скачивание по сетям (H4) | H4 | `getAutoDownloadSettingsPresets`/`setAutoDownloadSettings` (команды, сериализатор с 9 полями и NetworkType), `AutoDownloadSettingsDto` (пресеты+выбор), `LoadAutoDownloadSettingsUseCase`, `TgAutoDownloadPage` + route + вход из Data and Storage, `auto_download_*` в 3 локалях, контракт; ограничение: нет getter’а текущих настроек |
| S10b | Заблокированные — пагинация (H8) | H8 | `blockedSenderSelectors` (ключ, merge с дедупом, hasMore по loaded-vs-total), offset-пагинация «Show More» в `TgBlockedUsersPage`, `blocked_show_more` в 3 локалях, контракт расширен |
| S10c | Заблокированные — блокировка из профиля (H8) | H8 | `Chat.isBlocked` из `chat.block_list`, `updateChatBlockList` → reducer, `SetMessageSenderBlockedUseCase`, строка Block/Unblock в профиле (private/secret) с подтверждением и тостом, 4 строки в 3 локалях, контракт расширен |
| S10d | Заблокированные — вкладки Messages/Stories (H8) | H8 | `fetchPage(offset, limit, blockList)`, вкладки и сброс пагинации в `TgBlockedUsersPage`, `blocked_tab_*` в 3 локалях, контракт расширен |
| S12 | Меню действий чата (C10) | C10 | «…» в `TgProfileNavigationBar` + `showActionMenu` в профиле: mute/unmute, clear history, delete chat (подтверждения, тосты), ужесточение валидации `DeleteChatHistoryUseCase`, контракт `test-profile-actions.cjs`; C10 → `partial` |
| S13 | Настройки папок (B7/S7b.4) | B7 | `createChatFolder`/`editChatFolder`/`deleteChatFolder` (команды, сериализатор с полным `chatFolder` JSON), `ManageChatFoldersUseCase` (валидация имени/folderId), `TgChatFoldersPage` + route + строка Settings, `folders_*` в 3 локалях, контракт |
| S13b | Папки — чтение полной папки (B7) | B7 | `getChatFolder` (команда, сериализатор), `ChatFolderDto` (все флаги + int53-вектора через raw items), `fetchFolder` в use case, подгрузка флагов перед сохранением в `TgChatFoldersPage`, контракт расширен; долг «флаги сбрасываются» закрыт |
| S13c | Папки — include-флаги в редакторе (B7) | B7 | 5 include-флагов в `TgChatFoldersPage` (state, reset, загрузка из `ChatFolderDto`, `buildDraft`), 5 строк в 3 локалях, контракт расширен (wire true-значения, edit-payload) |
| S13d | Папки — выбор чатов (B7) | B7 | `includedChatIds` в payload/сериализаторе, `TgFolderChatsPage` (чекбоксы, pop-результат), загрузка выбора в редактор, route, строки, контракт расширен |
| S13e | Папки — invite-ссылки (B7) | B7 | 3 команды ссылок + сериализатор, `ChatFolderInviteLinkDto`, `ManageChatFolderInviteLinksUseCase`, секция Invite Links в редакторе (создание/копирование/удаление), 12 строк в 3 локалях, контракт расширен |
| S13f | Папки — переименование ссылки (B7) | B7 | `editChatFolderInviteLink` (команда/сериализатор), `editLink` в use case, инлайн-редактор имени в редакторе папки, 2 строки в 3 локалях, контракт расширен |
| S13h | Ссылка папки — набор чатов (B7) | B7 | `chatIds` в payload/фабриках/сериализаторе, валидация до gateway, выбор чатов при создании, сохранение набора при переименовании, счётчик в строке, контракт расширен |
| S11c | Лимит кэша (H4) | H4 | `OptimizeStoragePayload` + сериализатор, `enforceCacheLimit`, строка «Maximum Cache Size» с выбором и `preferences`, контракт `test-cache-limit.cjs`; H4 остаётся `partial` (график/авто-применение/witness) |
| S13i | Рекомендованные папки (B7) | B7 | `getRecommendedChatFolders` + `RecommendedChatFolderDto` + use case, секция RECOMMENDED с Add (через `createChatFolder`), контракт расширен |
| S13j | Превью папки по ссылке (B7) | B7 | `checkChatFolderInviteLink`/`addChatFolderByInviteLink`, `ChatFolderInviteLinkInfoDto`, `FolderInviteLinkUseCase`, экран `TgFolderLinkPage` + строка «Open Folder Link», контракт `test-folder-link-preview.cjs` |
| S14 | Внешние ссылки `t.me/addlist` (B7) | B7 | `ExternalLink` + intake, `EntryAbility.onCreate/onNewWant`, `MainTabsPage.consumeExternalLink`, `FolderLinkRouteParams` + автопроверка в `TgFolderLinkPage`, browsable-skill в `module.json5`, контракт `test-external-links.cjs`, харнесс stabilization обновлён |
| S14b | Внешние `t.me/<username>` (B7) | B7 | `ResolveUsernameUseCase` (`searchPublicChat`), ветка username в `MainTabsPage.consumeExternalLink` → гидрация чата + chat screen, тост об ошибке, контракт расширен |
| S14c | Внешние chat-invite ссылки (B7) | B7 | `checkChatInviteLink`/`joinChatByInviteLink`, `ChatInviteLinkInfoDto`, `ChatInviteLinkUseCase`, экран `TgChatInvitePage` + pop-result → открытие чата, App Linking `joinchat`, контракт расширен |
| S12e | Report — шаг комментария (C10) | C10 | `submitComment`, `submitReportComment` + host-колбэк, `TgReportCommentOverlay`, страница на `@Local`, контракт расширен; остаток — выбор сообщений и admin-пункты |
| S12f | Report — выбор сообщений (C10) | C10 | `messageIds` в payload/сериализаторе, `submitMessages`, режим выделения + Report в `TgSelectionPanel`, контракт расширен; остаток — admin-пункты |
| S12g | Ролевые admin-пункты меню (C10) | C10 | `getChatMember` + `ChatMemberRoleUseCase`, типизированные `ChatMenuAction`, Members для admin/creator, Members → `TgProfileMembersPage`, контракт расширен; остаток — остальные admin-разделы |
| S12h | Ссылки-приглашения группы (C10) | C10 | `getChatInviteLinks`/`createChatInviteLink`/`revokeChatInviteLink`, DTO+use case, экран `TgChatInviteLinksPage`, Manage-подменю, суита `test-chat-invite-links.cjs`; остаток — права/администраторы |
| S12i | Администраторы группы (C10) | C10 | `getChatAdministrators`+DTO+use case, экран `TgChatAdministratorsPage`, пункт в Manage-подменю, суита `test-chat-administrators.cjs`; остаток — права участников |
| S12j | Права участников (C10) | C10 | `setChatPermissions`+`ChatPermissionsDto`+use case, экран с 14 тумблерами, Manage-пункт, `chatAdminNavigation.ets`, суита `test-chat-permissions.cjs`; остаток — профиль из админов |
| S12k | Профиль из списка администраторов (C10) | C10 | экспорт `DirectUserProfileRouteParams`, `captureProfileLoadContext`, тап → `TgProfilePage`, контракт расширен |
| S15 | Короткая форма `t.me/+…` в App Linking (B7) | B7 | `pathStartWith: "+"` для `t.me`/`telegram.me`, контракт внешних ссылок расширен |
| H4b | Кэш: график и авто-лимит (H4) | H4 | `shouldAutoEnforce`/`autoEnforce`, полоса занятости total/limit, авто-применение после статистики, контракт расширен; остаток — диаграмма по категориям |
| H4c | Сегментированная диаграмма кэша (H4) | H4 | `StorageUsageSegment` + `storageChartScale`/`storageSegmentPercent`, `TgStorageUsageChart` с легендой, токены категорий; остаток — анимация/пропорции |
| C2b | Мульти-typing в группе (C2) | C2 | `ChatTypingInfo.senders`, `applyTypingAction`, формат «A и ещё N», суита `test-multi-typing.cjs`; остаток — пульсация точек |
| C9b | Иконка Copy в панели выделения (C9) | C9 | SVG `ic_selection_copy` + `SELECTION_PANEL_COPY_ICON`, copy через `buildIconButton`, паспорт обновлён; остаток — witness |
| D20b | Автоудаление сообщений (D20) | D20 | `messageAutoDeleteTime` в Chat/DTO/reducer, `setChatMessageAutoDeleteTime`, экран пресетов, Manage-пункт, суита `test-chat-auto-delete.cjs`; остаток — self-destruct/секретные чаты |
| D21b | Отложенные сообщения (D21) | D21 | `getChatScheduledMessages`/`editMessageSchedulingState`/`deleteMessages`, DTO+use case, экран списка, 6-й пункт Manage; остаток — пикер даты, repeat |
| G6b | Модерация участника (G6) | G6 | `setChatMemberStatus` + use case, long-press меню Ban/Unban/Restrict в списке участников, суита `test-chat-member-admin.cjs`; остаток — promote/demote/частичные права |
| G6c | Promote/demote (G6) | G6 | `ChatAdminRightsPayload` + статус `administrator`, действия promote/demote, меню из 5 пунктов; остаток — тоглы прав, частичные ограничения, сроки |
| G6d | Экран прав администратора (G6) | G6 | `TgChatAdminRightsPage` + route, 10 тоглов прав, promote через экран; остаток — частичные ограничения, сроки, предзаполнение |
| G6e | Сроки бана/ограничения (G6) | G6 | меню срока + `moderationUntilDate`, timed restrict/ban в wire; остаток — частичные права, предзаполнение |
| G6f | Частичные ограничения (G6) | G6 | `TgChatRestrictRightsPage` (14 разрешений + срок), `permissionsJson` в статусе restricted; остаток — предзаполнение прав админа |
| G6g | Предзаполнение прав (G6) | G6 | `loadState`/`parseMemberModerationState`, предзаполнение прав админа и текущего ограничения; остаток — demote с сохранением прав |
| F6b | Просмотр стикеров (F6) | F6 | стикер в общем вьювере (галерея + tap), суита `test-sticker-viewer.cjs`; остаток — карточка пака, TGS |
| F6c | Данные стикер-пака (F6) | F6 | `stickerSetId` в модели/VO/галерее, `StickerPackUseCase` (load/setInstalled), суита `test-sticker-pack.cjs`; остаток — UI-карточка |
| F6d | Карточка пака во вьювере (F6) | F6 | `ChatStickerPackCoordinator` + поля состояния + порт + плитка Add/Remove; остаток — TGS, листание по паку |
| G4b | Delete and Exit для удалённого (G4) | G4 | панель banned-group, красная кнопка, `ChatExitCoordinator`; остаток — witness |
| H8b | Панель UNBLOCK (H8/G4) | H8 | политика unblock, `SetMessageSenderBlockedUseCase`, суита `test-chat-unblock.cjs`; остаток — witness |
| D11a | Слой данных тредов (D11) | D11 | команды/сериализатор/парсеры/use case, суита `test-message-thread.cjs`; далее страница треда |
| D11b | Страница треда (D11) | D11 | `TgMessageThreadPage` + route + парсер комментариев; далее вход из поста |
| D11c | Вход в тред из поста (D11) | D11 | Comments (N) в меню, поля `isChannelPost`/`replyCount`, `openMessageThread`; далее отправка комментария |
| D11d | Отправка комментария (D11) | D11 | `topicThreadId` в sendMessage, composer треда; остаток — witness |
| D24a | Перевод сообщений (D24) | D24 | `translateText` + use case + пункт меню; далее inline-перевод |
| C2a | Пульсация typing-точек (C2) | C2 | `TgTypingPulse` + таймер в `TgChatTopBar`, суита; остаток — witness |
| D24b | Кэш переводов и Show Translation (D24) | D24 | bounded-кэш, лейбл меню; далее inline-перевод |
| D24c | Inline-перевод в бабле (D24) | D24 | store-event → reducer → row → bubble, плашки; остаток — выбор языка и witness |
| I1a | Локальные уведомления о сообщениях (I1) | I1 | policy + bridge + sink; далее wantAgent и inline reply |
| I1b | Тап по уведомлению открывает чат (I1) | I1 | wantAgent + intake + MainTabsPage; далее inline reply |
| H4a | Анимация диаграммы хранилища (H4) | H4 | reveal через animateTo + токен; остаток — witness |
| A5a | Слой данных профиля (A5) | A5 | setName/setBio/setUsername + use case; далее страница редактирования |
| A5b | Экран редактирования профиля (A5) | A5 | route + форма + вход из настроек; остаток — аватар и witness |
| A5c | Смена аватара (A5) | A5 | setProfilePhoto + picker/copy; остаток — кроп и witness |
| A5d | Кроп аватара (A5) | A5 | квадрат + JPEG-пайплайн; остаток — редактор и witness |
| A5e | Занятый username (A5) | A5 | typed errors + варианты + чипы; остаток — редактор и witness |
| D16a | Идентичность кастомного эмодзи в тексте (D16) | D16 | DTO→AppState→clone; далее резолв стикера и рендер |
| D16b | Резолвер кастомных эмодзи (D16) | D16 | getCustomEmojiStickers + кэш + download; далее рендер |
| D16c | Рендер кастомного эмодзи (D16) | D16 | splitter + ImageSpan + карта путей; далее координатор |
| D16d | Продюсер карты путей (D16) | D16 | cache + prefetch + VO fill; далее вызов из страницы |
| D16e | Prefetch со страницы + перестройка (D16) | D16 | coordinator + хук + render key; далее TGS/реакции |
| D16f | Кастомные реакции в пикере (D16) | D16 | observed state + prefetch + Image; далее TGS и witness |
| S12b | Меню действий в шапке чата (C10) | C10 | `showMoreAction`/`onMorePress` в `TgChatTopBar`, меню Chat Info / Mute / Clear History / Delete в `TgChatScreenPage`, live-store состояние, контракт `test-chat-header-actions.cjs`, smoke-пин на 4 действия; C10 → `available` |
| S12c | Leave Chat и Share My Contact (C10) | C10 | `leaveChat` + `inputMessageContact` (команды/сериализаторы), `LeaveChatUseCase`/`ShareMyContactUseCase`, пятый контекстный пункт меню в шапке, 6 строк в 3 локалях, контракт расширен |
| S12d | Report с причинами + `ChatActionsCoordinator` (C10) | C10 | `reportChat`/`ReportChatDto`/`ReportChatUseCase`, `canBeReported` в модели/DTO/reducer, шестой пункт меню, меню вынесено в координатор (страница ≤500 строк), контракт расширен |

## Следующие срезы (в порядке)

1. **S13g. Папки — folder link preview (B7).** `checkChatFolderInviteLink`, маршрутизация `t.me/addlist/...`, рекомендованные папки.
2. **S12e. Report — комментарий и выбор сообщений (C10).** Ввод текста жалобы и выбор сообщений, затем ролевые админ-пункты.
2. **S12b. Меню действий в шапке чата (C10).** Действия в шапке/панели чата, роли, Share Contact/Report.
2. **S10b. Заблокированные — пагинация и блокировка из профиля (H8).**
2. **S9c. Сессии — 2FA и подтверждение новых сеансов (H5).**
2. **S8b.3. Контекстное меню — пункты по типу чата (B6).** Join (только search-контекст в iOS), Select.
2. **S7b.4. Папки чатов — экран настроек и folder link preview (B7).**
2. **S7b.4. Папки чатов — экран настроек и folder link preview (B7).**
2. **C9-долг** (иконка Copy) и **D7-долг** (пункт меню).
3. **Witness-очередь:** D10 (реакции), C2 (typing), C6 (разделитель), D13 (стикеры). Иконки панели, подсветка выбранных баблов, формулировка диалога удаления для N сообщений, device-witness.

## Требуют внешних условий (не начинать)

- **Witness D10:** поставить/снять реакцию на живом аккаунте (эмулятор + чат с сообщениями);
  до этого S3a–S3d.1 и S3b.1 проверены host-контрактами, не устройством.
- **Witness C2:** второй аккаунт/устройство, которое начнёт печатать.
- **Witness D13:** стабильный запуск эмулятора + стикер в доступном чате; логи
  `tgs playback started key=file:<id>`.
- Push (AGC), подпись (сертификат), VoIP/секретные чаты (заморожены).

## Не в этой карте

- `@ReusableV2`/perf — после измерений, отдельным решением.
- Полный аудит оставшихся `partial`-строк — по мере приближения к их экранам.

| F6a | Листание по стикер-паку (F6) | F6, D13 | парсинг пака + элементы вьювера + пейджинг; далее TGS/предзагрузка |
| F6b | Предзагрузка соседних стикеров (F6) | F6 | next-first план + download-запросы; далее TGS в вьювере |
| F6c | TGS-анимация стикера во вьювере (F6, D13) | F6 | surface + fit + текущая страница; остаток — witness |
| D24a | Язык перевода (D24) | D24 | поддерживаемые коды + per-chat префы + инвалидация кэша; далее UI-пикер |
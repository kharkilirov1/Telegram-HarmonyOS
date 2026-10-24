# TgChatHeaderStatus Component Passport

Паспорт строки статуса шапки чата (subtitle lane): typing / online / last seen / группа.
Владелец вертикали — срез S1 (`TASKS/WORKMAP.md`), строка матрицы **C2**.

## 1) Scope

- Lane: subtitle внутри `TgChatTopBar` + derivation слой `ChatTopBarPresentation`.
- Target layer: `atoms` (`TgChatTopBar`) + page-owned presentation (`ChatChromeState` / координаторы).
- Статус: `partial` → кандидат в `available` после runtime-witness (снимает lead).
- UI only: ни один из слоёв не делает сетевых вызовов и не владеет TDLib-операциями.

## 2) iOS source mapping

Актуальный аналог `ChatTitleStatusNode` — компонентный `ChatTitleComponent`; сам
`ChatTitleStatusNode` в текущем `Telegram-iOS-current` отсутствует.

| Роль | Файл | Строки |
|---|---|---|
| Шапка: title + activities + presence + network | `submodules/TelegramUI/Components/ChatTitleView/Sources/ChatTitleComponent.swift` | 626–838 |
| Приоритет состояний: network → activities → presence/участники | там же | 628–838 |
| Дефолтный цвет подзаголовка / акцент активности | там же | 690–691, 754 |
| Приватный чат: текст активности (`Conversation_typing`, `Activity_*`) | там же | 652–676 |
| Группа, несколько печатающих: `Chat_MultipleTypingPair` / `Chat_MultipleTypingMore` | там же | 678–685 |
| Группа, один печатающий: **только** `compactDisplayTitle` | там же | 686–688 |
| Presence (`online` / «был(а) недавно») | там же | 744–755 |
| Участники группы / подписчики канала / метка при нуле | там же | 760–826 |
| Подписка на activities + spring 0.4 | `submodules/TelegramUI/Sources/Chat/ChatControllerLoadDisplayNode.swift` | 5157–5214 |
| Порт activities | `submodules/TelegramCore/Sources/Account/Account.swift` | 1664–1669 |
| **TTL активности** | `submodules/TelegramCore/Sources/State/PeerInputActivityManager.swift` | 327–339 |
| Снятие typing при `choosingSticker` | там же | 337–339 |
| Авто-удаление по таймеру | там же | 35–107 |
| Состояния подзаголовка (тип + акцент) | `submodules/ChatTitleActivityNode/Sources/ChatTitleActivityNode.swift` | 18–58, 79–130 |
| Точки typing: 3 шт., 3–4.5pt, шаг 5.5pt, цикл 0.7s | `submodules/ChatTitleActivityNode/Sources/ChatTypingActivityContentNode.swift` | 11–25, 38–40, 63–66, 112 |
| Crossfade подзаголовка 0.2s | `submodules/ChatTitleActivityNode/Sources/ChatTitleActivityContentNode.swift` | 7, 107–123 |
| Legacy layout (номиналы title/subtitle, glass) | `submodules/TelegramUI/Components/ChatTitleView/Sources/ChatTitleView.swift` | 556–600 |

Константы, которые перенесены в код:

| iOS | Значение | Куда |
|---|---|---|
| `ActivityRecord` timeout (default) | **8.0 s** | `CHAT_ACTIVITY_TTL_MS` |
| `interactingWithEmoji` | 2.0 s | не используется (нет такого action в модели) |
| `speakingInGroupCall`, `seeingEmojiInteraction` | 3.0 s | не используется |
| typing dot `minDiameter` / `maxDiameter` | 3.0 / 4.5 | `CHAT_TOP_BAR_TYPING_DOT_SIZE` |
| typing dot `distance` | 11.0 / 2.0 = 5.5 | `CHAT_TOP_BAR_TYPING_DOT_PITCH` |
| typing dot cycle | 0.7 s | долг (анимация не включена) |
| subtitle font | 12.0 pt | `CHAT_TOP_BAR_SUBTITLE_SIZE` |
| `Conversation_typing` («typing…») | с многоточием | ресурс `app.string.typing` = `typing…` / `печатает…` / `正在输入…` |

## 3) Шов: единый VO шапки

Подзаголовок **не** выводится в `TgChatScreenPage` отдельной веткой. Страница передаёт в атом уже
готовые значения из `ChatChromeState`:

```ets
TgChatTopBar({
  title: this.view.chrome.title,
  subtitle: this.view.chrome.chatSubtitle,
  subtitleMode: this.view.chrome.chatSubtitleMode,
  showSubtitleSpinner: this.view.chrome.chatSubtitleSpinner,
  isOnline: this.view.chrome.chatIsOnline,
  ...
})
```

Единственная точка вывода — `ChatSubtitlePresentation { subtitle, mode, spinner, isOnline }`
(`ui/pages/chat/ChatTopBarPresentation.ets`, `chatSubtitlePresentation()`). Через неё уже идут
presence, участники, сеть и typing; новые состояния (reactions-активность, «X печатает…» в списке)
подключаются там же, без правок страницы и атома.

`schema`: `TgChatTopBarSubtitleMode` = `Secondary | Online | Typing | Activity`:
- `Typing` — peer-активность с точками (только `chatActionTyping`);
- `Activity` — прочие активности (uploading/recording/…) и состояние сети; акцентный цвет без точек;
- `Online` — присутствие «в сети»; `Secondary` — нейтральный текст.

## 4) Источник данных, владение, guard'ы

| Слой | Владелец |
|---|---|
| TDLib `updateChatAction` → `ChatActionEvent` (`timestamp = Date.now()`) | `core/events/normalizers/ChatNormalizer.ets` |
| `chats.typingActions: Map<ChatId, ChatTypingInfo>` (единственный источник) | `core/reducers/chatsReducer.ets` (`chatAction`) |
| Свежесть + выбор текста/режима | `chatSubtitlePresentation` (pure) |
| Публикация в V2-состояние | `ChatChromeState` (`@Trace chatSubtitle/chatSubtitleMode/...`) |
| Отложенный откат по TTL | `ChatRouteActivationCoordinator` (`chatActivityRefreshDelay` + `scheduleLifecycleTask`) |
| Отрисовка | `TgChatTopBar` |

Guard'ы:
- **Открытый чат**: `activeChatId === 0` → откат не планируется; чужой чат не меняет шапку,
  потому что сравнивается `typingActions.get(activeChatId)`.
- **Активный аккаунт**: подписка живёт на account-scoped store маршрута (`route.accountStore`),
  после срабатывания таймера дополнительно проверяется `host.accountStore !== store`.
- **Жизненный цикл**: `scheduleLifecycleTask` захватывает `pageLifecycleToken`; выход из чата
  инвалидирует таймер, `clearTransientTimers()` чистит набор.
- **Позднее событие**: если `timestamp + TTL <= now` (событие уже протухло к моменту прихода),
  задержка = 0, текст typing не показывается.
- **Отмена**: `chatActionCancel` удаляет запись → следующий расчёт сразу откатывается к presence.
- **Сеть**: состояние соединения перекрывает typing (как в iOS) и включает спиннер.

## 5) State matrix

| # | Состояние | mode | Текст | Точки |
|---|---|---|---|---|
| 1 | приватный, `typing`, свежо | `Typing` | `печатает…` (ресурс с многоточием) | да |
| 2 | приватный, recording/uploading/… | `Activity` | локализованный label действия | нет |
| 3 | приватный, `online` | `Online` | `online` | нет (зелёная точка на аватаре) |
| 4 | приватный, `recently/lastWeek/lastMonth/longTimeAgo` | `Secondary` | «был(а) …» | нет |
| 5 | приватный, бот | `Secondary` | роль бота | нет |
| 6 | группа/канал, один печатающий, отправитель известен | `Typing` | **только имя** (firstName или username) | да |
| 7 | группа/канал, отправитель не разрешён (нет в `users`) | `Typing` | label действия (деградация, не пусто) | да |
| 8 | группа → участники; канал → подписчики; `memberCount == 0` → `group`/`channel` | `Secondary` | clDR-plural / метка | нет |
| 9 | `connection.status != ready` | `Activity` | connecting/updating/waiting | нет (спиннер) |
| 10 | активность истекла (`>= 8 s` от последнего update) | 3/4/8 | presence/участники | нет |
| 11 | `cancel` | 3/4/8 | немедленный откат | нет |
| 12 | активность в чужом чате | без изменений | — | — |
| 13 | маршрут закрыт / `activeChatId == 0` | без изменений | — | — |

Покрыто тестом `entry/src/ohosTest/ets/test/ChatHeaderStatus.test.ets` (кейсы 1, 3, 4, 6, 7, 10, 11,
12, 13 + контракт TTL и расписания отката).

## 6) Token mapping

Источник: `entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets`.

| Токен | Значение | Назначение |
|---|---|---|
| `CHAT_TOP_BAR_SUBTITLE_SIZE` | 12 | размер текста подзаголовка |
| `CHAT_TOP_BAR_SUBTITLE_ACCENT` | `color.telegram_blue` | акцент Online/Typing/Activity |
| `COLOR_TEXT_PREVIEW` | ресурс | нейтральный Secondary |
| `CHAT_TOP_BAR_TYPING_DOT_SIZE` | 3 | диаметр точки typing |
| `CHAT_TOP_BAR_TYPING_DOT_PITCH` | 5.5 | шаг центров точек (iOS `distance`) |
| `CHAT_TOP_BAR_TYPING_DOT_GAP` | pitch − size | `Row.space` между точками |
| `CHAT_TOP_BAR_SPINNER_GAP` | 4 | зазор до текста |

В атоме нет числовых литералов: геометрия и цвета берутся только из токенов.

## 7) Что сделано нативно и почему

- Точки — `Circle()` внутри `Row` с токенизированными размером/шагом. Отдельный «индикатор»
  компонент не заводится: в iOS это рисуемый узел внутри текстового слоя, в ArkUI достаточно
  строки с тремя кругами (нет дополнительного состояния и подписок).
- Анимация пульсации 0.7 s **не** включена (см. §9): `animateTo({ iterations: -1 })` в шапке
  нельзя проверить на стоимость кадров и на корректную остановку без эмулятора.
- Crossfade подзаголовка обеспечивает существующий `chatTopBarContentTransition()` (200/150 ms),
  близкий к iOS 0.2 s.

## 8) Приёмка

- [x] iOS-источник и константы зафиксированы (файлы + строки).
- [x] единая точка derivation; страница и атом не знают о typing-событии.
- [x] TTL = 8 s как единственная константа (`CHAT_ACTIVITY_TTL_MS`).
- [x] откат по таймауту без нового store-change.
- [x] guard'ы: открытый чат, аккаунт, жизненный цикл, позднее событие, отмена.
- [x] токены вместо магических чисел; статические точки по iOS-геометрии.
- [x] focused тест (`ChatHeaderStatus.test.ets`) в реестре `List.test.ets`.
- [x] host-проверка derivation/расписания с мутациями (см. отчёт среза).
- [x] строка «печатает…» с многоточием в самом ресурсе (base/ru/zh), без ручной склейки в списке.
- [x] общий TTL: шапка и список читают `CHAT_ACTIVITY_TTL_MS`.
- [x] host-гейт: `node scripts/run-host-tests.cjs` = 96/96.
- [ ] runtime-witness «печатает…» — **внешний блокер**: нужен второй аккаунт/устройство, который начнёт печатать; снимает lead.
- [ ] матрица `C2` → `available` только после этого witness.

## 9) Долг и известные ограничения

| Что | Почему не сейчас | Триггер возврата | Видимое последствие |
|---|---|---|---|
| Пульсация 0.7 s у точек typing | нет способа проверить стоимость кадров и остановку `animateTo({iterations:-1})` | появится runtime-witness стоимости кадров | точки статичны, iOS — пульсируют |
| Мульти-typing в группе (2 / 3+) | модель хранит одного отправителя на чат; нужен список в `AppState` + reducer | отдельный срез по typing-модели | в группе видно только одного печатающего |
| Глифы прочих активностей (upload/record/playing game/choosing sticker) | в iOS это отдельные узлы; в срезе нет ни ресурсов, ни токенов | вертикаль composer/media | показывается текст + акцент, без глифа |
| `harmonyos_docs` MCP недоступен в сессии | инфраструктура сессии | MCP снова подключён | ArkUI-решения опираются на локальный код и доки репозитория |

TTL списка чатов и строка «печатает…» больше не расходятся с шапкой: `ChatItemVO.ets` читает
`CHAT_ACTIVITY_TTL_MS` из этого же модуля, а многоточие живёт в самом ресурсе `app.string.typing`
(ручная склейка `'...'` удалена).

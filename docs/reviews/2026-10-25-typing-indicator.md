# Срез S1 — typing indicator в шапке чата

- Дата: 2026-10-25
- Строка матрицы: `C2 — Индикатор набора` (статус до: `partial`)
- Тип: UI-атом + рантайм-сигнал (presentation-слой)
- Фаза (PARITY): качество UI / надёжность
- Связанные строки: `B12` (typing в списке), `C1` (шапка чата), `J3`

## 1. Референс

- iOS: `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\ChatTitleView\Sources\ChatTitleComponent.swift`
  - приоритет состояний `network → activities → presence/участники` — строки 628–838;
  - приватный чат: `Conversation_typing` / `Activity_*` — 652–676;
  - группа, несколько печатающих: `Chat_MultipleTypingPair` / `Chat_MultipleTypingMore` — 678–685;
  - группа, один печатающий: **только** `compactDisplayTitle` — 686–688;
  - presence (`online` / last seen) — 744–755; акцентный цвет активности — 690–691, 754.
- iOS: `submodules/TelegramUI/Sources/Chat/ChatControllerLoadDisplayNode.swift:5157–5214` — подписка на activities.
- iOS: `submodules/TelegramCore/Sources/State/PeerInputActivityManager.swift:300–347` — **TTL активности: 8.0 s** (emoji-interaction 2 s, group-call/emoji-seeing 3 s), авто-удаление по таймеру 35–107, `choosingSticker` снимает `typingText` 337–339.
- iOS: `submodules/ChatTitleActivityNode/Sources/ChatTitleActivityNode.swift:18–130` — состояния узла и crossfade 0.2 s.
- iOS: `submodules/ChatTitleActivityNode/Sources/ChatTypingActivityContentNode.swift:11–25,38–40,63–66,112` — три точки 3–4.5 pt, шаг 5.5 pt, цикл 0.7 s, слева от текста.
- «ChatTitleStatusNode» в актуальном `Telegram-iOS-current` **отсутствует**; актуальный аналог — `ChatTitleComponent` + `ChatTitleActivityNode`.
- Скриншоты: срез опирается на ранее снятые пользовательские iOS-кадры (2026-07-10, private/group шапка); новый кадр «печатает» в этой сессии снимает lead.
- Fallback (Android/Nekogram) не потребовался: iOS-источник однозначен.
- Платформенные доки: **MCP `harmonyos_docs` в этой сессии недоступен** (доступны только `colab`, `rea`, `rea-linux`). Это ограничение зафиксировано в `spec/TgChatHeaderStatus.md`; новых ArkUI-API в срезе не вводится — только `Row`/`Text` и существующий `LoadingProgress`.

## 2. Текущее состояние (код, до среза)

- Единая точка derivation уже существовала: `ui/pages/chat/ChatTopBarPresentation.ets`, `chatSubtitlePresentation()`; страница передаёт в атом `chatSubtitle` / `chatSubtitleMode` — отдельной typing-ветки в `TgChatScreenPage` не было.
- Дефекты:
  1. `ChatTopBarPresentation.ets:160` — `(now() - typingInfo.timestamp) < 6000`, магическое число, расходится с iOS 8 s; то же `6000` в `ui/pages/chatlist/ChatItemVO.ets:552`.
  2. Свежесть проверялась только в момент вызова → после typing-события шапка висела на «печатает» бесконечно, пока не придёт другой store-change. Отката по таймауту не было.
  3. Группа показывала `Имя + " печатает"` вместо iOS-варианта «только имя».
  4. Визуала индикатора не было вовсе (только текст + акцент).
- Подтверждение редьюсера: `core/reducers/chatsReducer.ets:466–480` (`chatAction`), нормалайзер `ChatNormalizer.ets:355–382` (`timestamp = Date.now()`), модель `AppState.ets:80–85` (`ChatTypingInfo{senderUserId, actionType, timestamp}`), `ChatsState.typingActions: Map<ChatId, ChatTypingInfo>`.

## 3. Контракт

- TDLib: `updateChatAction` (`chat_id`, `sender_id`, `action`), `action` = `chatActionTyping` … `chatActionCancel`. Форма подтверждена локальным `tdlib/td/generate/scheme/td_api.tl` (используется существующим `ChatNormalizer`, изменений нет).
- Владелец состояния: `AppStore.chats.typingActions` (account-scoped).
- Владелец времени жизни: `ChatRouteActivationCoordinator` (единственный отложенный пересчёт на открытый чат).
- Guard'ы: открытый чат (`activeChatId === 0` → нет работы), account identity (`host.accountStore !== store`), lifecycle token (`scheduleLifecycleTask`), позднее событие (`remaining <= 0` → typing не показывается и таймер не планируется), отмена (`chatActionCancel` удаляет запись).
- Отмена/поздние колбэки: отложенная задача проверяет `pageLifecycleToken`; выход из чата инвалидирует её, `clearTransientTimers()` чистит набор таймеров.

## 4. Швы и связанные фичи

- Related: online/offline presence, «был(а) недавно», заголовок группы с typing-контактом, typing в списке чатов (`ChatItemVO`).
- Шов: VO `ChatSubtitlePresentation {subtitle, mode, spinner, isOnline}` + `TgChatTopBarSubtitleMode {Secondary, Online, Typing, Activity}`. Новое состояние подключается только в `chatSubtitlePresentation` — страница и атом не меняются.
- Что **не** делаем: мульти-typing (2/3+ отправителя) — модель хранит одного отправителя на чат; долг (см. §9).
- Риски для соседей: `Typing` — новое значение enum; все сравнения через `===`, exhaustive-switch отсутствует, поэтому добавление значения безопасно (проверено grep по `TgChatTopBarSubtitleMode.`).

## 5. Состояния

| # | Состояние | mode | Текст | Индикатор |
|---|---|---|---|---|
| 1 | приватный, typing | `Typing` | `typing` | 3 точки |
| 2 | приватный, recording/uploading | `Activity` | label действия | нет |
| 3 | приватный, online | `Online` | `online` | нет (зелёная точка аватара) |
| 4 | приватный, last seen | `Secondary` | «был(а) …» | нет |
| 5 | приватный, бот | `Secondary` | роль бота | нет |
| 6 | группа, 1 печатающий | `Typing` | только имя | 3 точки |
| 7 | группа, отправитель не разрешён | `Typing` | label (не пусто) | 3 точки |
| 8 | группа/канал без активности, `memberCount=0` | `Secondary` | участники/подписчики/метка | нет |
| 9 | сеть не ready | `Activity` | connecting/updating/waiting | спиннер |
| 10 | активность истекла (≥ 8 s) | 3/4/8 | presence | нет |
| 11 | cancel | 3/4/8 | немедленный откат | нет |
| 12 | чужой чат | без изменений | — | — |
| 13 | маршрут закрыт | без изменений | — | — |

- long text: `maxLines(1)` + ellipsis у title и subtitle (без изменений); emoji-RTL: текст не парсится, идёт как строка.
- light/dark: цвет акцента и нейтральный текст — из ресурсов (`telegram_blue`, `text_preview`), отдельных dark-веток не добавлено.
- font scale / safe area / keyboard: геометрия шапки не менялась; точки 3 vp добавляются в существующий ряд и не влияют на safe area.
- Источник данных для каждого состояния: `AppState` (`chats`, `users`, `connection`, `chats.typingActions`) → `chatSubtitlePresentation` → `ChatChromeState` (`@Trace`) → `TgChatTopBar`.

## 6. Тест до реализации (RED)

- Файл: `entry/src/ohosTest/ets/test/ChatHeaderStatus.test.ets` (зарегистрирован в `List.test.ets`).
- Кейсы: TTL = 8 s; typing → `Typing` до границы `TTL-1` и откат ровно на `TTL`; откат при cancel; группа показывает только имя; группа без разрешённого отправителя деградирует в label; ровно один отложенный пересчёт из remaining-времени; чужой чат и закрытый маршрут игнорируются; «по таймеру без нового store-change шапка становится presence».
- RED-доказательство (до реализации): тест ссылается на ещё не существующие `CHAT_ACTIVITY_TTL_MS`, `typingActivityRemainingMs`, `chatActivityRefreshDelay`, значение enum `Typing`, токены точек → не компилируется; поведенчески — старая граница 6000 даёт `Online` там, где ожидается `Typing` (показано мутантом, §8).
- Ограничение: Hypium-тесты исполняются только на устройстве/эмуляторе (`entry@ohosTest`); в этой сессии прогон невозможен (эмулятор не поднимаю — witness за lead). Вместо этого выполнена эквивалентная host-проверка той же техникой, что `scripts/test-*.cjs`.

## 7. Изменения

| Файл | Изменение |
|---|---|
| `entry/src/main/ets/ui/pages/chat/ChatTopBarPresentation.ets` | `CHAT_ACTIVITY_TTL_MS = 8000` (iOS `PeerInputActivityManager.swift:327-335`), `typingActivityRemainingMs()`; замена магического `6000`; группа → только имя; `mode = Typing` для `chatActionTyping`; `formatTypingSubtitle()` сведён к одному параметру (мёртвый `subjectName` удалён) |
| `entry/src/main/ets/ui/pages/chat/ChatRouteActivationCoordinator.ets` | `chatActivityRefreshDelay()` (чистая функция) + один `scheduleLifecycleTask` на открытый чат → пересчёт шапки на дедлайне |
| `entry/src/main/ets/ui/tg_ui/atoms/TgChatTopBar.ets` | `TgChatTopBarSubtitleMode.Typing`, акцентный цвет для него, 3 статические точки слева от текста |
| `entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets` | `CHAT_TOP_BAR_TYPING_DOT_SIZE/PITCH/GAP` (iOS 3 / 5.5) |
| `entry/src/main/ets/ui/pages/chatlist/ChatItemVO.ets` | S1.1: `CHAT_ACTIVITY_TTL_MS` вместо `6000` для typing в списке; строка «печатает…» без ручного `+ '...'` |
| `entry/src/main/resources/base|ru_RU|zh_CN/element/string.json` | S1.1: многоточие в самом ресурсе `typing` |
| `scripts/chat-screen-source.cjs` | S1.1: `probeSource()` включает не-delegate helper'ы owner-модулей; новый `helperBindings()` для исполняемой инъекции |
| `scripts/test-chat-lifecycle-account-scope.cjs` | S1.1: подключает `helperBindings` + `ChatTopBarPresentation` (без изменения проверяемого поведения) |
| `scripts/test-chat-top-bar-presentation.cjs` | S1.1: ожидания под новый контракт (группа — имя, mode `Typing`, TTL 8 s, `typing…`) |
| `entry/src/ohosTest/ets/test/ChatHeaderStatus.test.ets` | новый focused-тест (S1 + fallback `typing…` в S1.1) |
| `entry/src/ohosTest/ets/test/List.test.ets` | регистрация сьюта |
| `entry/src/main/ets/ui/tg_ui/spec/TgChatHeaderStatus.md` | паспорт статуса шапки |

- Токены: только добавлены, существующие не менялись.
- Legacy-путь: `ChatChromeState` остаётся единственным владельцем публикации, страница не менялась; старый `ChatTitleStatusNode`-аналог не удалялся (его и нет).

## 8. Приёмка

- [x] `powershell -ExecutionPolicy Bypass -File .\scripts\smoke-ui-phase0.ps1` — зелёный (`tg_ui shell smoke checks passed.`)
- [x] `bash ./scripts/smoke-ui-phase0.sh` — зелёный (`tg_ui shell smoke checks passed.`)
- [x] `powershell -ExecutionPolicy Bypass -File .\scripts\smoke-build.ps1` — зелёный (`Smoke build completed successfully.`)
- [x] `node scripts/run-host-tests.cjs` — **96/96** (после S1.1 и правки harness'а, см. §12)
- [x] Host-проверка derivation/расписания (ad-hoc загрузчик как в `scripts/test-*.cjs`, вне репозитория): **10/10** проверок зелёные.
- [x] Мутанты (доказательство, что тесты не вакуумные):
  - `old-ttl` (8 s → 6 s): 3 падения, в т.ч. `Online` вместо `Typing` на границе;
  - `group-label` (группа снова с label): 1 падение — «только имя»;
  - `no-deadline` (свежесть не проверяется): 2 падения;
  - `no-refresh` (откат не планируется): 2 падения.
- [ ] `entry@ohosTest` (Hypium) — требует устройства/эмулятора; прогоняет lead вместе с witness.
- [ ] runtime witness: свежий процесс, кадр «печатает…» в приватном чате и в группе + side-by-side с iOS.
  **Внешний блокер:** нужен второй аккаунт/устройство, который начнёт печатать (см. §12).
- [ ] матрица `C2` обновляется после witness (предложенная строка — §10); до witness — `partial`.

## 9. Долг / ограничения

| Что | Почему не сейчас | Триггер возврата | Видимое последствие |
|---|---|---|---|
| Пульсация точек 0.7 s (iOS) | нет способа проверить стоимость кадров и остановку `animateTo({iterations:-1})` без runtime-witness | появится witness стоимости кадров/остановки | точки статичны, в iOS пульсируют |
| Мульти-typing в группе (2 / 3+) | `typingActions: Map<ChatId, ChatTypingInfo>` хранит одного отправителя; нужен список в `AppState` + reducer | отдельный срез по typing-модели | в группе видно только одного печатающего |
| Глифы прочих активностей (upload/record/playing game/choosing sticker) | в iOS это отдельные узлы; нет ресурсов/токенов в этом срезе | вертикаль composer/media | текст + акцент без глифа |
| `harmonyos_docs` MCP недоступен | инфраструктура сессии | MCP снова подключён | ArkUI-решения по локальному коду |

Строка «печатает» без многоточия и TTL списка чатов (`6000`) **закрыты в S1.1** — см. §12.

## 10. Строка матрицы C2

Было:

```
| C2 | Индикатор набора | `partial` | `ChatRouteActivationCoordinator.ets` (19/9); корневая причина исправлена, witness не снят | `ChatTitleStatusNode` | B12, J3 |
```

Сейчас (witness не снят — второй аккаунт, §12) — статус остаётся `partial`, меняется только evidence:

```
| C2 | Индикатор набора | `partial` | `ChatTopBarPresentation.ets:12,169-187` (TTL 8s, VO `Typing`, группа — имя); `ChatRouteActivationCoordinator.ets:270-284` (откат по таймауту); `TgChatTopBar.ets:173-194` (3 точки); `ChatItemVO.ets:553` (общий TTL в списке) | `Components/ChatTitleView/ChatTitleComponent.swift` | B12, J3 |
```

После witness (второй аккаунт/устройство) — `available` с датой:

```
| C2 | Индикатор набора | `available` | <те же пути> | `Components/ChatTitleView/ChatTitleComponent.swift` | B12, J3 |
```

## 11. Ответы на замечания ревью

1. **Приватный чат не дублирует имя.** `actorName` вычисляется только при `chat.peerUserId <= 0`
   (`ChatTopBarPresentation.ets:176-180`), поэтому для private/secret это пустая строка и подзаголовок
   берёт текст активности (`typing`), а имя остаётся только в title. В тест добавлены явные негативные
   проверки: приватный чат — `subtitle` не содержит имя собеседника; группа — `subtitle` не содержит
   текст активности.
2. **Сигнатура.** `formatTypingSubtitle(actionType: string)` — один параметр, мёртвый `subjectName`
   удалён; единственный вызов — `ChatTopBarPresentation.ets:181` (сверено grep по репозиторию).
3. **Точки только для `Typing`.** `TgChatTopBar.buildTitleContent()` рисует `buildTypingDots()` только
   под `subtitleMode === TgChatTopBarSubtitleMode.Typing`; для `Activity` (сеть, upload/record) точек нет,
   спиннер — только по `showSubtitleSpinner`. `Text(this.subtitle)` — единственный текстовый узел, двойного
   «печатает… печатает…» нет: текст формируется один раз в `chatSubtitlePresentation`.
4. **Откат без новых store-change.** В подписке на store (`ChatRouteActivationCoordinator.ets:224-231`)
   один `scheduleLifecycleTask(host, remaining)` на typing-событие открытого чата; по срабатыванию
   вызывается `host.updateChatTopBarData(store.getState())` — derivation видит истёкший timestamp и
   возвращает presence. Очистка: `aboutToDisappear()` инкрементирует `pageLifecycleToken` (строка 119) и
   вызывает `clearTransientTimers()` (строка 153), который делает `clearTimeout` всем id из
   `transientTimerIds`; отложенная задача дополнительно проверяет token перед выполнением.

## 12. S1.1 — строка «печатает…» и общий TTL списка/шапки

Найдено на S1 и закрыто отдельным срезом (task-4), потому что это одна и та же пользовательская строка.

**Тексты.** Многоточие перенесено в сам локализованный ресурс, ручная склейка удалена:

| Локаль | Было | Стало |
|---|---|---|
| `base` | `typing` | `typing…` |
| `ru_RU` | `печатает` | `печатает…` |
| `zh_CN` | `正在输入` | `正在输入…` |

- `ChatItemVO.ets:169` — `localizedString($r('app.string.typing').id, 'typing…')`, без `+ '...'`.
- `ChatTopBarPresentation.ets:67,106` и `ChatHeaderStatus.test.ets:24` — fallback выровнен на `typing…`,
  чтобы при неинициализированном ResourceManager не появлялось ASCII-многоточие.
- Других строк не меняли.

**TTL.** `ChatItemVO.ets:553` больше не содержит `6000`: `(Date.now() - typingInfo.timestamp) <
CHAT_ACTIVITY_TTL_MS` (импорт из `ChatTopBarPresentation`). Шапка и список читают один источник (iOS 8 s).

**Harness (scripts/, по решению lead — вариант A).** `scripts/chat-screen-source.cjs` теперь знает про
не-delegate helper'ы owner-модулей: `probeSource()` добавляет их в контрактный текст с тем же
`host`→`this` bridge, а новый `helperBindings(graph, deps)` компилирует их настоящими модулями с той же
изоляцией зависимостей, что и `compileExports` (включая правило «инъекция не перекрывает
module-level `const`»). Без этого `activateChatRoute`, извлечённый из контрактного текста, вызывал
`chatActivityRefreshDelay` как неопределённый идентификатор: 12 кейсов Wave18 падали на
«actual store subscription must queue the rebuild».

- `scripts/test-chat-lifecycle-account-scope.cjs` подключает `helperBindings` и загружает
  `ChatTopBarPresentation` для `typingActivityRemainingMs`; поведенческого кода в тесте не менялось.
- `scripts/test-chat-top-bar-presentation.cjs` обновлён под новый контракт: группа — только имя (без
  label), `mode = Typing` для `chatActionTyping`, TTL берётся из самого модуля (`helper.CHAT_ACTIVITY_TTL_MS`),
  тексты `typing…`; добавлена проверка «приватный чат показывает текст активности, а не имя».

**Гейты S1.1 (все зелёные):**

- `node scripts/run-host-tests.cjs` — **96/96** (было 94/96 из-за двух файлов выше).
- `bash ./scripts/smoke-ui-phase0.sh` — `tg_ui shell smoke checks passed.`
- `powershell -ExecutionPolicy Bypass -File .\scripts\smoke-ui-phase0.ps1` — то же.
- `powershell -ExecutionPolicy Bypass -File .\scripts\smoke-build.ps1` — `BUILD SUCCESSFUL in 1m 46s`,
  `Smoke build completed successfully.` (33/33 задачи; сборка сделана после всех правок кода S1.1,
  последующие изменения — только в `scripts/` и документации, HAP они не затрагивают).

**Внешний блокер witness (не «не проверяли», а физическая невозможность на одном устройстве).**
Состояние «печатает…» требует второго участника: нужен второй аккаунт (или второе устройство/клиент),
который начнёт печатать в открытом чате. Локально есть один аккаунт и один эмулятор, поэтому этот кадр
не снимается изнутри сессии среза. Пока witness не снят, строка матрицы **C2 остаётся `partial`**;
откат по таймауту, guard'ы и точные тексты закрыты тестами и host-проверкой, но визуальная приёмка
состояния «печатает» не выполнена.

## Runtime evidence — device (2026-10-25)

Устройство: API24 x86_64 HVD (`Pura 90 Pro Max`), HAP 87 447 088 B + ohosTest HAP, свежий процесс
`com.telegram.harmonyos` PID 4509 (STIME 05:16:47).

- `aa test -b com.telegram.harmonyos -m entry_test -s unittest OpenHarmonyTestRunner -s class ChatHeaderStatus`
  → **Tests run: 8, Failure: 0, Error: 0, Pass: 8**. Runtime-подтверждение логики: единый TTL 8 s,
  откат по дедлайну, приватный/групповой подзаголовок, cancel.
- Приложение запущено на залогиненной сессии, список чатов отрисован:
  [скриншот](2026-10-25-witness-app-state.jpeg).
- **Визуальный кадр «печатает…» не получен.** В первых двух попытках история чатов не загружалась
  («Сообщений пока нет»); в третьей попытке история в `HUAWEI Chat` загрузилась, но за ~4 минуты
  опроса (25 дампов `uitest dumpLayout`) ни один участник не начал печатать.
- Итог: C2 остаётся `partial`; нужен второй участник/аккаунт.

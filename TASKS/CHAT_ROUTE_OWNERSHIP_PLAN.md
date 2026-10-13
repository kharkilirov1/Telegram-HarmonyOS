# Chat route ownership — выполненные сценарии и оставшиеся gates

Дата: 2026-09-06. Статус: **частично реализован и проверен в Wave17**; late-first-chat, native count и device gates открыты. Отчёт: `docs/reviews/2026-09-06-reliability-wave17.md`.

## Зачем это нужно

Baseline Wave16: params не несли происхождение первого отложенного route, а aboutToAppear мог читать globals до onReady. Wave17 ввёл canonical captured store/gateway/epoch и navigation token; page effects начинаются только после binding. Воспроизведённые route-less/same-chat-owner regressions включены в lifecycle86/86; это не native lifecycle witness.

Локальный TDLib `MessagesManager.cpp:16407–16419,16521–16544` использует open_count: два open + один close оставляют 1; unowned stale close может уменьшить чужое единственное открытие 1→0. Присваивание lastOpenedChatId не является acquisition witness.

## Три прямых входа — подтверждено source lookup

- `entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets`: canonical params и captured owner до deferred open/Compose result; caller-open удалён.
- `entry/src/main/ets/ui/pages/chatlist/TgArchivedChatsPage.ets`: те же params; caller-open удалён.
- `entry/src/main/ets/ui/pages/chat/ChatMessageActionsController.ets`: captured source capability → picker → guarded pop callback → token-bound handoff/push; caller-open удалён. Actual caller witness69/69.

## Выбранный integration contract

1. Унифицировать route context: immutable chatId/title + captured source accountStore/gateway + уникальный navigation owner. Создавать до async boundaries. Не заменять неизвестный/stale owner текущим global account.
2. Инициализировать account effects только после binding валидного route context. Отделить component aboutToAppear от NavDestination onReady/onShown; проверить официальные lifecycle docs и native witness.
3. Перенести open ownership в одну page/route-owned сущность **одновременно с удалением всех трёх caller-open**. Preserve peer/history hydration и unread initialization; не добавлять второй open для прохождения tests.
4. Strict received Ok подтверждает только API-call acknowledgement. Реализованы single attempt и release-once через captured gateway; native increment/принадлежность decrement этим НЕ доказаны. TDLib noRead может пропустить increment и вернуть Ok. Close failure не replay; native coordination/unknown outcomes остаются отдельным contract.
5. Global navigation visibility/clear/back/rollback выполняются только владельцем navigation token. Account + chatId equality недостаточно для overlapping same-chat pages.
6. Account reset/rejected route должны быть явной invalidation, не автоматическим rebind. Сохранить Wave16 предотвращение повторной привязки живого компонента к B.
7. Системный runtime gate остаётся отдельным: HDC [Empty], SceneBoard crash до Telegram. Host simulation не доказывает реальное пересечение callbacks.

## Baseline и acceptance

- Сначала actual caller→params→page witness: delayed A route после switch B, одинаковый chatId и разные chatId.
- Две страницы same account/chat: только current token меняет globals — host PASS. Logical successful-call balance проверен; физический native balance при изменении Read access остаётся OPEN.
- Pending open→disappear→late Ok; duplicate close; rejected/fulfilled Error/malformed result; adapter generation change.
- Real normalizers/store + history: unread snapshot, aroundUnread offset/limit, hydration, created chat ещё отсутствует в reducer; mark-read не раньше подтверждённого open.
- Return from profile/forward picker, Back failure rollback, invalid/rejected route, route-less compatibility — явно выбрать контракт, не silently use globals.
- Повторить все existing host/source suites, focused native tests/compile, main/ohosTest builds **последовательно**; hashes до/после. Затем реальный device/emulator scenario и process/screenshot/log witness.
- Visual/production/iOS-equivalence gates не снимать без соответствующего runtime evidence.

## Следующий узкий patch и условия принятия

1. Воспроизвести сохранённый late-first-chat probe из `docs/reviews/2026-09-06-reliability-wave17-evidence.json`: actual openChat → viewMessages → getChatHistory сейчас даёт 0/0/50 вместо303/-10/60.
2. Различить отсутствие первого owned chat и реально полученный нулевой unread. Первый настоящий snapshot захватывать до read, не замораживать default из отсутствующего state. Добавить оба порядка state/Ok, поздний state после первого history, account revoke, duplicate events и bounded missing-state outcome. Не создавать бесконечный retry/двойную загрузку ради теста.
3. Сохранить cached-route snapshot и исправленный early-read-before-history сценарий. RED→GREEN на одном witness, затем lifecycle/draft/callers, общие source suites и final serial builds.
4. Отдельно спроектировать session/all-holder coordination по `docs/reviews/2026-09-06-native-open-count-gap.md`: noRead A / restoredRead B / release A, pending ack, newcomer во время drain, unknown outcomes и смена session. Не объявлять native count gate закрытым одним logical lease.
5. Native lifecycle, overlays/back, unread positioning и signed device runner требуют реального runtime. Shared media/jump/search signals остаются отдельным account-isolation audit.

## Референс

`C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Sources/ChatController.swift:252,8040–8044`: immutable AccountContext; interface state сохраняется через self.context.engine. Это account-scoped behavioral reference, не готовая реализация ArkUI Navigation.

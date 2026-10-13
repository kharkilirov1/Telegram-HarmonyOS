# Reliability Wave12 — проверки пересылки до побочных действий

2026-09-06. **Два воспроизведённых дефекта исправлены на source/host/compile уровне. Device acceptance и публикационная готовность не заявляются.**

## Что действительно изменилось

1. `TgChatScreenPage.getForwardUseCase` проверял типы выбранных сообщений только для basic group. В ordinary supergroup разрешённый текст оставлял composer доступным, и запрещённое photo могло пройти getter. Теперь captured source IDs проверяются для обоих видов групп, в том числе после очистки forward preview.
2. До Wave12 проверялись структура ID и результат `forwardMessages`, но не source eligibility. Controller мог отправить comment, а затем получить отказ для защищённого/недоступного исходного сообщения. Теперь actual `getChat` + `getMessageProperties` preflight выполняется **до comment**, затем повторяется перед forwarding dispatch.

Первоначальный focused witness: **1 PASS / 3 FAIL**, exit 1. Два FAIL — известное photo и неизвестный source kind в supergroup; третий — реальные controller/use cases передавали в fake transport `sendMessage` и `forwardMessages` при запрещённой source eligibility. После минимальной правки — 4/4. Финальная расширенная проверка — **75/75**.

## Контракт и границы решения

- Добавлена typed-команда `getMessageProperties`; serializer сохраняет int53 ID числом в JSON. Проверены exact source ID, source chat и target identity.
- Target обязан быть strict `TdObject` с `@type=chat`, совпадающим числовым `id` и известным `chatType`. Properties обязаны быть strict `messageProperties`; нужный flag — literal `true`, не строка, число, nested fallback или plain record.
- Обычный server forward требует `can_be_forwarded`; explicit copy и non-server ID — `can_be_copied`; secret target — `can_be_copied_to_secret_chat`. Не используется ошибочное универсальное `F || C`.
- Server ID распознаётся арифметически по локальному `MessageId.h` (factor 1048576, int32 server-ID bound), без обрезающих int53 JavaScript bitwise операций. Public API не даёт отдельного признака forced local copy; это намеренная зависимость от vendored TDLib, которую необходимо пересматривать при его обновлении.
- `removeCaption` нормализуется в `sendCopy && removeCaption`, как предписывает публичный schema-контракт. У локальной bulk implementation есть расхождение для `false,true`; приложение не полагается на этот неоговорённый эффект.
- Properties не имеют ID/revision/TTL внутри ответа. Ответ привязан к captured request; постоянного permission cache нет. Проверяется вся selection, без тихого отбрасывания недоступных сообщений.
- После каждого async read и непосредственно перед mutation проверяются текущие account/page/operation/target capabilities. После comment проверка source повторяется. Потеря source permission не повторяет уже принятый comment; новая draft/edit/attachment/operation не перезаписывается ошибкой старого запроса.
- Сохранены strict positional `Messages/null` handling и retry только непринятых IDs. Accepted-for-sending не означает доставку.

### Что ещё НЕ закрыто

1. Context menu пока не скрывает/дизейблит Forward по source properties: отказ показывается при выполнении. Для полного UX нужен отдельный lifecycle-bound action snapshot со стабильными action IDs.
2. Неизвестный cached source kind в ограниченной группе остаётся conservative deny; hydration metadata и понятный retry ещё нужны.
3. Старый temporary source ID может получить false negative: TDLib forwarding умеет remap в persistent ID, а `getMessageProperties` по старому ID — нет. Нельзя маскировать missing как разрешение.
4. Flags необходимы, но недостаточны: например, copy quiz может не иметь пригодного input media. Две mutation-команды не атомарны; серверный отказ после comment всё ещё возможен.
5. Edit/expiry/discussion-thread exceptions, migration/Delete UX, full runtime/visual/soak и publication gates остаются в очереди.

## Проверки, выполненные основным агентом

| Witness | Результат |
|---|---|
| Focused actual-source suite | 75/75, включая 25 native Hypium bodies через host adapter |
| Все существующие и новый `test*.cjs` | 28/28 |
| PowerShell source-contract + UI smoke | 38/38 |
| Исходный review witness | 8/8 |
| Syntax | 28 CJS + review script, exit 0 |
| Main forced CompileArkTS | 52 s 61 ms; build 1 min 13 s 994 ms; exit 0 |
| OhosTest forced CompileArkTS | 34 s 797 ms; build 55 s 203 ms; exit 0 |
| Dirty + untracked `.ets` SHA256 | 51 before/after, без изменений во время обеих сборок |
| `git diff --check` | exit 0 |

Обе сборки: `assembleHap --no-incremental --no-daemon`, соответствующий CompileArkTS task реально выполнен. Hypium bodies в Node не равны запуску Hypium на устройстве. Другие native suites, не включённые в host adapters, здесь только скомпилированы.

Мутации применяются только в памяти; каждая зафиксировала engagement=1 и закончилась exit 1:

| Отключённая проверка | FAIL из 75 |
|---|---:|
| Source flag gate | 24 |
| Copy/local mode flag selection | 11 |
| Supergroup per-kind gate | 2 |
| Preflight до comment | 14 |
| Dispatch cancellation guards | 9 |

У dispatch mutant одна native проверка намеренно оставляет второй fixture read pending. Runner теперь сообщает timeout как FAIL через 3000 ms, а не завершает процесс с незавершённым набором. Production validation ради старых fixtures не обходилась: три старых CJS и три native fixtures получили отдельные metadata replies и assertions read trace, сохранив deferred mutations и прежние ownership/result assertions.

Raw-derived результаты, source hashes и build witnesses: [evidence JSON](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-06-reliability-wave12-evidence.json).

## Изменённые файлы

Production (корень `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/`):
- `entry/src/main/ets/core/model/AppCommand.ets` — typed request.
- `entry/src/main/ets/infra/td/serialization/CommandSerializer.ets` — numeric wire ID.
- `entry/src/main/ets/domain/usecases/forwardMessages.ets` — strict eligibility, copy modes, dispatch cancellation.
- `entry/src/main/ets/ui/pages/chat/ChatMessageActionsController.ets` — pre-comment validation, guarded execution, failure feedback.
- `entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets` — supergroup per-kind forwarding guard.

Tests: новый `scripts/test-forward-eligibility.cjs`, новый `entry/src/ohosTest/ets/test/ForwardEligibility.test.ets` и регистрация `List.test.ets`; обновлены `scripts/test-basic-group-media.cjs`, `scripts/test-forward-result-contract.cjs`, `scripts/test-forward-send-ownership.cjs` и native `ForwardMessagesContract.test.ets`, `ForwardSendOwnership.test.ets`, `UseCases.test.ets`. Working docs: STATUS, TODO, LESSONS, CHAT_ACCESS_PLAN, PRODUCTION_PARITY_PLAN.

Исходное dirty дерево сохранено; commits/reset/legacy deletion отсутствуют. Это узкий runtime-срез, не переработка архитектуры и не visual atom.

## Референсы и независимая проверка

- Локальный TDLib: `tdlib/td/generate/scheme/td_api.tl` (MessageProperties/getMessageProperties/forwardMessages); `td/telegram/MessageId.h`; `MessagesManager.cpp:7875–7906,14753–14801,23871–23899`. Проверены режимы copy, source protection/secret/scheduled/missing и positional response.
- iOS: [ChatMessageSelectionInputPanelNode.swift](C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Components/Chat/ChatMessageSelectionInputPanelNode/Sources/ChatMessageSelectionInputPanelNode.swift), `forwardButtonPressed`: secret source не передаётся, copy protection показывает explanation вместо forwarding. Это source behavior reference, не новый visual witness.
- `harmonyos_docs`: запрос `"@Local" AND "Array"`. CPL HTTP снова connection refused; использован прямой поиск/чтение известных исходников, без повторения старых 300-секундных MCP timeouts.
- Cicero проверил TDLib contract и финальный source integration; Godel обновил stale compatibility fixtures; Turing добавил 25 native tests. Основной агент прочитал изменения и самостоятельно исполнил итоговые witnesses. Все три агента закрыты.

## Runtime и следующий срез

Свежий `hdc list targets`: **[Empty]**. В Wave12 новых boots/install/account actions нет. Ранее isolated API24 трижды падал в SceneBoard до установки Telegram; подробности в [Wave10](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-06-reliability-wave10.md). Этот OS blocker не объявляется исправленным и не переобъясняется без нового evidence.

Далее: lifecycle-bound source action availability + metadata hydration/retry; затем edit/expiry/thread exceptions. Device validation продолжать при исправной guest OS или доступном устройстве. Общая задача надёжности/UI/feature/publication остаётся активной.

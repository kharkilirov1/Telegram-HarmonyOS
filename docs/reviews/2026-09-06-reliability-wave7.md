# Reliability wave7 — пересылка: запрос, частичный результат и повтор

2026-09-06, `dev`; накопленный рабочий diff сохранён, commit/push не выполнялись.

## Результат

Исправлены два подтверждённых разрыва в настоящем send-пути: неподготовленный список IDs попадал в TDLib, а fulfilled `forwardMessages` считался полным успехом даже при `null` результатах. Теперь запрос проверяется **до отправки комментария**, IDs сортируются численно/дедуплицируются, каждый результат сопоставляется с исходным ID. При частичном принятии повтор содержит **только не принятые сообщения**, без уже отправленного комментария. Неверный ответ не превращается в полный повтор с риском дубликатов; пользователь получает локализованное пояснение.

Focused actual-source witness: **14 PASS / 42 FAIL → 65/65 PASS** с расширением набора. Ownership regression: **53/53 PASS**. Все **24 CJS**, **37 PS+UI smoke**, review **8/8**, syntax **25/25**; main/ohosTest build успешны. Device acceptance и полная цель остаются открыты.

## Почему этот срез перед group/media policy

При продолжении аудита permissions проверен отмеченный в wave6 forward contract. Это не косметическая сортировка: текущий use case отправлял произвольные IDs через serializer с raw JSON vector, а затем игнорировал возвращённый `Messages`. Без исправления partial response терял часть пользовательского намерения; наивное «всё повторить» создало бы дубликаты. Срез завершает подтверждённую проблему действующего отправления; не заменяет оставшуюся group/media и publication работу.

## Контракт и изменения

- Локальный `tdlib/td/generate/scheme/td_api.tl:10872–10881`: strictly increasing `vector<int53>`, максимум 100 сообщений; ответ в том же порядке, `null` вместо непересылаемого сообщения. `MessagesManager.cpp:23829–23842` действительно отклоняет некорректный/неупорядоченный ID.
- Прочитан `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Sources/Chat/ChatControllerLoadDisplayNode.swift:2064–2066`: selection set преобразуется в sorted IDs перед forward. Это source reference, не новая проверка iOS runtime.
- `ForwardMessagesUseCase.prepare`: строгие nonzero safe-integer chat IDs, положительные канонические decimal message IDs в диапазоне int53; отдельная копия, численная сортировка, дедупликация, предел 100 distinct IDs. Никакого silent truncation/автоматического массового batching.
- `ChatMessageActionsController`: synchronous preflight до очистки буфера/начала busy/comment. Wave6 operation/lifecycle/chat/account guards сохранены.
- `TdObject.getTopLevelObjectArrayStrict`: exact top-level object array с сохранением `null` и индекса; malformed/nested shadow не принимаются. Legacy `getArray` не подходит: теряет null slots и допускает nested lookup.
- `ForwardMessagesUseCase.execute`: ожидает настоящий `TdObject` типа `messages`, вектор правильной длины; каждый non-null slot имеет `@type=message`, положительный safe-integer id и нужный target chat. `total_count` не используется как число принятых сообщений.
- `ForwardMessagesResultError`: `retryMessageIds`, `acceptedCount`, `outcomeKnown`. Partial/null failure обрабатывается отдельно от malformed/uncertain response. Успешный ответ означает **принято к отправке**, не доставлено сервером: delivery state остаётся за update pipeline.
- Controller восстанавливает только retry IDs и только в нетронутый текущий compose buffer; account reset, новый draft/edit/attachment/forward/owner не затираются. Unknown response не восстанавливает весь список. Ошибка показа toast не мешает cleanup.
- Три новые строки обратной связи добавлены в base/ru_RU/zh_CN; JSON валиден, дубли ключей отсутствуют.

Production: `entry/src/main/ets/domain/usecases/forwardMessages.ets`, `entry/src/main/ets/ui/pages/chat/ChatMessageActionsController.ets`, `entry/src/main/ets/models/td/common/index.ets`, три locale `string.json`. Новые/обновлённые тесты: `scripts/test-forward-result-contract.cjs`, `scripts/test-forward-send-ownership.cjs`, `ForwardMessagesContract.test.ets`, `ForwardSendOwnership.test.ets`, `UseCases.test.ets`, регистрация в `List.test.ets`.

## Верификация и пределы

Новый harness исполняет actual page/controller/use-case/scoped store и actual serializer. Transport/native file I/O/presentation — явные fixtures, реальных сообщений не отправлялось. Проверены numeric versus lexical order, duplicates, 1/100/101 IDs, unsafe/invalid/raw JSON fragments, strict chat IDs, positional partial/all-null results, wrong count/type/destination/nested payload, UI preflight, partial retry без duplicate comment, новые owner/account/draft/attachment/forward.

Baseline после исправления ошибочного имени метода в самой новой fixture: **14 PASS / 42 FAIL**, 56 случаев. После source fix и добавления 8 native bodies + serializer witness: **65/65**. Соседний ownership suite расширен двумя native cases до **53/53**. Старые fake «успех = `{}`/`ok`» заменены настоящим shape `messages`; ожидания пользовательского поведения не ослаблены. Всего через два host adapters исполнены 16 native bodies; это **не запуск Hypium на HarmonyOS**.

| In-memory mutation | PASS / FAIL | Exit | Применено |
|---|---:|---:|---:|
| `result-ignored` | 44 / 21 | 1 | 1 |
| `lexical-sort` | 58 / 7 | 1 | 1 |
| `replay-all` | 63 / 2 | 1 | 1 |
| `skip-preflight` | 64 / 1 | 1 | 1 |
| `legacy-array` | 58 / 7 | 1 | 1 |

Mutations затрагивают только загруженную копию; проверка engagement обязательна. Общая свежая регрессия: 24 CJS / 37 PS+smoke, review 8/8, syntax 25/25, `git diff --check` exit 0.

Отдельно исполнены реальные 6 bodies соседнего `UseCases.test.ets` через временный host adapter: **6/6 PASS**, включая обновлённую typed forward response fixture. Это дополнительная host-проверка, не device runner.

Первая сборка поймала настоящий `arkts-no-any-unknown` после `Array.isArray` narrowing в новом accessor. Итерация явно типизирована `Object[]`; после этого повторены тесты и обе сборки с `--no-incremental --no-daemon`:

- main CompileArkTS **29 s 880 ms**, build **49 s 782 ms**, exit 0;
- OhosTestCompileArkTS **39 s 665 ms**, build **1 min 2 s 324 ms**, exit 0;
- **44 modified/new `.ets` SHA256** совпадают до/после финальных сборок; source после сборки не менялся.

Warnings остаются (включая `icudtl.dat missing`, отсутствие signingConfigs); HAP unsigned. Свежий HDC check: 10001 и 5555 **Offline**. Повторных boots, установки HAP, account actions и device tests в wave7 не было. Предыдущая диагностика SceneBoard panic — в wave6, не новый runtime witness этого кода.

Все счётчики, hashes и build output: `docs/reviews/2026-09-06-reliability-wave7-evidence.json`.

## Открытая работа

1. **Effective group/per-media permissions**: default send bits, роли, individual/default intersection, live subscriptions и unknown group hydration. Прочитанный TDLib booster path не равен безусловному AND: при отсутствии cached full-info TDLib считает non-bot megagroup booster; при известных данных сравнивает my boost count и threshold. UI policy не должна выдумывать эти данные. В этом срезе group policy не менялась.
2. Forward UI eligibility по `messageProperties.can_be_forwarded` / copy / secret flags, topic semantics; не заявлены выполненными. Response processing не заменяет eligibility UI.
3. Неопределённый transport failure и последующие delivery failures требуют отдельного рассмотрения повторов; существующая обработка rejected gateway promise не переделана. Защита от дубликатов этого среза относится к **известным partial и malformed result**, не ко всем сетевым исходам.
4. Native/device acceptance, свежая визуальная сверка с iOS, оставшиеся функции и публикационная готовность. Полная цель не завершена.

Grounding: `harmonyos_docs` ответил про V1 Watch/V2 Monitor и допустимые state types; CPL context повторно завершился timeout 300s, использовано точное локальное чтение. Независимый subagent review в этом срезе не выполнялся; выводы основаны на source/host/mutation/compile witnesses.

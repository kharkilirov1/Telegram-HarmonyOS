# Завершение TDLib clients без потери владельца — 28 сентября 2026

## Результат

**В проверенных source/host-сценариях устранены четыре ранее воспроизведённых случая потери client ID.** Receive path теперь создаётся до выделения ID. Timeout закрытия больше не выдаёт ложный успех: владелец и consumer сохраняются до текущего `authorizationStateClosed`. Поздний Closed завершает retirement даже после отключения application dispatcher.

Одновременно исправлены runtime shutdown/reset: ошибка не лишает пользователя возможности повторить остановку, concurrent/reentrant callers ждут одно завершение, singleton сохраняется при failed reset. Новая initialize не создаёт account scope и не включает hooks, пока старый gateway находится в destroying.

Финальный gate: **57/57 host suites, 38/38 PowerShell-проверок + Bash smoke; обе последовательные сборки PASS; 780 source/test hashes неизменны.** Это source/host/compile-срез, **не проверка реального аккаунта, памяти полного TDLib или надёжности на устройстве**. Полная production parity цель остаётся активной.

## Изменения

- [TdGateway](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/infra/td/gateway/TdGateway.ets): start-before-create, stop barrier для частично запущенного receive, ожидание Closed независимо от close Ok, сохранение ownership при timeout, private close-only route в destroying, автоматическое завершение после late Closed. Перед native stop флаг retirement снимается: отказ самого stop не запускает бесконечные автоматические попытки.
- [AppCoreRuntime](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/app/bootstrap/AppCoreRuntime.ets): ранний initialize gate; explicit shutdown retry при non-idle gateway; публикация shared Promise до синхронного отзыва scopes; reset возвращает общее completion/rejection и не теряет singleton при ошибке. Dispatcher detach в finally и account invalidation сохранены.
- Новые actual-source suites: [client retirement](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-td-client-retirement.cjs), [runtime retirement](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-runtime-client-retirement.cjs), [queued Closed](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-retirement-queued-closed.cjs).
- [Client lifetime audit](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/audit-td-client-lifetime.cjs) проверяет теперь и корректный результат, и прежние findings, сохраняя независимый manager oracle и strict failure mode.
- Existing [gateway](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-td-gateway-recovery.cjs) / [stop](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-td-stop-barrier.cjs) assertions приведены к новому контракту: failed receive создаёт **0**, а успешный retry — **первый**, не второй ID; initialize больше не запускает скрытую попытку shutdown. В [runtime fixture](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-app-core-runtime.cjs) добавлен отсутствовавший `getState` с реальными переходами idle/ready, не константный обход guard.
- [ARCHITECTURE](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/ARCHITECTURE.md) описывает узкий transport-only retirement path; обычный поток account updates через dispatcher/normalizer/store не переписан.

## Свидетельства

Parent перед изменением Gateway повторил `audit-td-client-lifetime.cjs --strict`: **6 controls / 4 findings, exit 1**. После изменения тот же source-manager oracle: **10 controls / 0 findings, exit 0**.

| Сценарий | До | После |
|---|---|---|
| Три ошибки receive startup | 3 manager slots без владельца | 0 выделенных IDs |
| Runtime cleanup после startup failure | 1 забытый manager slot | 0 выделенных IDs |
| Close Ok без Closed до timeout | idle, consumer остановлен, slot остаётся | destroying/error, owner сохранён; late Closed → slot 0 → stop |
| Timeout close request | тот же преждевременный idle | owner/receive сохранены; current-client Closed завершает retirement |

Audit компилирует дословный threaded `ClientManager::Impl` из локального TDLib, но заменяет actor/scheduler/queue dependencies fixtures и воспроизводит native-boundary trace. Oracle различает internal Closed и последующий sentinel: один receive ещё оставляет ID, второй удаляет и публикует Closed. Это **не исполнение полного TDLib с БД**, не измерение байтов утечки.

Runtime worker отдельно наблюдал RED **2/11** до своей production-правки; parent повторил финальные **13/13 + 7 negative controls**. Новая Gateway suite впервые запускалась уже после parent patch: её baseline RED не выдумывается, до/после для Gateway даёт исходный strict audit.

| Итоговая проверка | Результат |
|---|---|
| Client retirement | 24/24 PASS + 8/8 named-assertion mutations |
| Runtime retirement | 13/13 PASS + 7/7 mutations |
| Queued Closed / stale batch generation | 13/13 PASS + 3/3 mutations |
| Existing gateway / stop barrier | 45/45 и 11/11 PASS; stop 4/4 mutations |
| Client manager trace audit --strict | 10 controls, 0 findings, exit 0 |
| Полный host gate | 57/57 suites PASS |
| PowerShell contracts + UI smoke / Bash smoke | 38/38 PASS / PASS |
| Forced serial main / ohosTest assembleHap | exit 0 / exit 0; 25.932 s / 19.777 s |
| Source/test snapshot / whitespace | 780/780 hashes совпадают; diff --check exit 0 |
| Новый HAP на устройстве | Не установлен |

Мутации проверяют early allocation, ложную очистку при timeout, потерю private route/late Closed/catch-race continuation, ожидание Ok после Closed, ошибочную автоматическую stop retry и использование Closed предыдущего lifecycle. Runtime controls проверяют retry, initialize gate, singleton/reset, reentrant shutdown, detach и отзыв scopes. Требуется конкретный behavioral assertion, не compile error или зависший Node.

Во время интеграции найден дополнительный дефект: `hasClientToClose` вычислялся по оставшемуся Closed предыдущего запуска. Исправлено вычислением **после** reset текущего lifecycle; repeated-instance scenario и mutation это проверяют.

### Независимое ревью: queued Closed терялся при recovery failure

Reviewer обнаружил P1: native уже выдал единственный public Closed для client2, но envelope ещё ожидал bounded drain. Истечение bootstrap timeout вызывало `reportRecoveryFailure → resetBatchDrain`, удаляя свидетельство окончательного закрытия. Последующий close не может получить его повторно.

Parent лично повторил один и тот же порядок до/после правки:
- До: `destroying`, `clientId=2`, `stop=0`, shutdown отклонён с `TDLib client is still closing. Retry shutdown.`
- После: `idle`, `clientId=0`, `stop=1`, shutdown завершён.

Исправление сохраняет pending batches и остаток partial drain, переустанавливает таймер после смены generation. Каждый batch несёт исходную generation; stale обычные updates/responses отклоняются даже если немедленный retry уже стал ready. Исключение — Closed **текущего client ID**, не чужого. Синхронный разбор всей очереди на failure stack не добавлен: прежний бюджетированный drain сохранён.

Reviewer проверил batch/single/partial delivery, reverse-order control и fresh traffic после retry: новых findings в этом scope не нашёл. Parent повторил все 13 сценариев и 3 mutation controls: discard очереди, отсутствие rearm, отсутствие generation guard. Два последних controls исключают «исправление» с зависшим старым таймером или ожившими stale updates. Финальные builds/tests выполнены уже после этой production-правки.

### Артефакты проверки

Полные результаты команд, ограничения fixtures, 780 hashes и build/package witnesses: [evidence JSON](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-28-client-retirement-evidence.json).

| Артефакт | SHA256 |
|---|---|
| TdGateway.ets | `b73a0bddca825274a20a9d37fc2106e9376b1aa3463352a7b6b01f8cfc6057ca` |
| AppCoreRuntime.ets | `795a8ba94cd5eee38ebb5551349c261bf1b7d9a712471c0fce9bc89a3d43ecd2` |
| entry-default-unsigned.hap | `a5fadc6c158c407415a8230138dfe18495ca2bc7f7fbd78ed8547d5c23b6cd94` |
| entry-ohosTest-unsigned.hap | `1e7615095edba11cc22b6baf9cd5373726778650334c5a9aad990d9fdda963fc` |

В `ets/modules.abc` обоих HAP найдены новые `rearmBatchDrain`, `drainItemsGeneration`, late-retirement path и сообщения retry-gates. Упакованный x86_64 `libtdlib_napi.so` совпадает по SHA256 с предыдущим async-stop срезом; native C++ в этой работе не изменялся. Это подтверждение упаковки нужного кода, не его device-исполнения. Обе сборки unsigned: signingConfigs отсутствует; compiler warnings о NAPI verification/throwing APIs и microphone permission не превращены в «чистую сборку без предупреждений».

## Границы и следующий участок

- Не исправлялись и не считаются закрытыми TSFN enqueue ownership / env teardown и dialog openChat/closeChat count. `open_count` не поддержанная метрика количества clients.
- Нет actual SDK/device stress, arm64 release или полного clean-checkout validation. Не установлены HAP, не изменены emulator data/session, не выполнялись сообщения/микрофон/logout/reset аккаунта, commit/push или публикация.
- Если TDLib никогда не выдаст Closed, gateway остаётся visibly destroying и запрещает новый client; timeout не доказывает release. Explicit shutdown может повторить close. Этот безопасный отказ нельзя выдавать за подтверждённое завершение native ресурсов.
- Произвольные ошибки внутри native createClient marshalling и полное уничтожение JS env этим trace fixture не покрыты. Для них требуется отдельный native ownership/SDK witness.

Основания: локальные `td_api.tl` и `Client.cpp` через actual-source audit; `harmonyos_docs` для async-work/thread boundary; предыдущий [SDK lifetime report](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-28-native-lifecycle-contract.md). UI/iOS атомы в этом срезе не менялись.

Работа выполнена поверх существующего dirty `dev`, без смены HEAD/index. Нельзя откатывать весь файл или дерево: это удалило бы и предыдущие проверенные изменения. Откат — только reviewed узкий diff.

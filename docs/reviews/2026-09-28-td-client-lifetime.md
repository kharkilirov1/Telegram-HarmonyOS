# TDLib client lifetime / open_count + ETS async-stop barrier

Дата: 2026-09-28. Scope: source audit и исполняемый host witness, не устройство/полный TDLib runtime.

## Результат

1. **Утечка владения ID подтверждена на host:** три startup failures оставляют три записи в настоящем `ClientManager::Impl`; native TD actors ещё не созданы. Это не доказательство утечки трёх БД/потоков или конкретного числа байтов.
2. **Timeout shutdown теряет ID без подтверждённого Closed.** Host manager сохраняет запись при остановленном receive. Это незавершённый lifetime, но не доказательство бесконечно работающего actor: дальнейший receive способен завершить release.
3. **Штатный `close → Ok + Closed` корректен:** manager освобождает ID; gateway принимает оба порядка доставки Ok/Closed. Утечка на штатном пути не воспроизведена.
4. **`open_count` не является поддержанной option или счётчиком клиентов.** Обнаруженный dialog field принадлежит другой проблеме `openChat/closeChat`. Этот gate не закрыт данным client-lifetime аудитом.
5. После отдельного разрешения parent выполнен **только ETS async-stop integration**. Stop pending/rejected удерживает `destroying`; concurrent destroy и startup rollback ждут общий Promise. Client-close policy намеренно не исправлена.

## Проверенный контракт

Локальный TDLib: `cb863c1600082404428f1a84e407b866b9d412a8`, clean TDLib working tree при проверке; `OptionManager.cpp` сообщает версию `1.8.60`. Совпадение с установленным `.so` **не проверялось**.

| API/сигнал | Что поддержано источником |
|---|---|
| `td_create_client_id() -> int` | Opaque ID. Нет updates до первого request; client автоматически уничтожается после закрытия. |
| `td_send(id, request)` | Асинхронная отправка. Один global `td_receive`; одновременно из двух потоков его вызывать нельзя. Responses/updates применяются в порядке получения. |
| `close = Ok` | Недеструктивное закрытие с flush БД; разрешено до initialization. Ok не доказывает завершение закрытия. |
| `authorizationStateClosed` | Финальное состояние; БД закрыты, ресурсы освобождены, для продолжения нужен новый client. В threaded manager публичный Closed выходит **после erase ID**. |
| `td_json_client_destroy(void*)` | Другой, legacy pointer API. **Не** способ уничтожить integer ID из `td_create_client_id`. |
| `td_execute` | Только explicitly synchronous functions. Для `getOption` локально синхронны лишь `version` и `commit_hash`, не произвольное имя. |
| `getOption("open_count")` | Нет поддержанного контракта. Не измеряет число clients. Отсутствующее значение проходит generic getter и преобразуется в `optionValueEmpty`, а не подтверждённый ноль клиентов. |
| native `stopReceiveLoop()` | Project API остановки consumer, не TDLib close. Новый согласованный контракт — `Promise<void>`; completion должен означать завершение native stop, failure оставляет retryable Stopping. |

Первичные источники:
- [JSON API header:29–37,67–98,128–199](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/telegram/td_json_client.h#L29); [C wrappers:14–47](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/telegram/td_json_client.cpp#L14); [ClientJson.cpp:115–160](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/telegram/ClientJson.cpp#L115).
- [td_api.tl:188–190](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/generate/scheme/td_api.tl#L188), [close:10169–10174](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/generate/scheme/td_api.tl#L10169), [options:14033–14040](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/generate/scheme/td_api.tl#L14033).
- [Requests.cpp:2189–2193](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/telegram/Requests.cpp#L2189): `send response before actually closing`; [Td.cpp:753–794](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/telegram/Td.cpp#L753), [on_closed:593–598](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/telegram/Td.cpp#L593).
- [OptionManager.cpp:548–554,719–778,1039–1074](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/telegram/OptionManager.cpp#L548): sync allowlist, getter, writable-option rejection/custom `x` namespace, Empty conversion.
- Проверены также [официальные options](https://core.telegram.org/tdlib/options) — `open_count` отсутствует — и [JSON API](https://core.telegram.org/tdlib/docs/td__json__client_8h.html). Для данной сборки приоритет у pinned local source.
- `harmonyos_docs` выполнен: `napi_create_async_work napi_queue_async_work`, **Asynchronous Task Development Using Node-API**. Подробный SDK lifetime audit принадлежит другому агенту; native implementation — parent.

## Почему это не option open_count

Поиск по локальным TDLib source и схеме не нашёл такой option. Найдено:
- [MessagesManager.h:1279](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/telegram/MessagesManager.h#L1279): `Dialog::open_count`.
- [MessagesManager.cpp:15926–15943](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/telegram/MessagesManager.cpp#L15926): wrappers возвращают OK для существующего dialog, независимо от фактического increment.
- [open_dialog:16407–16419](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/telegram/MessagesManager.cpp#L16407): нет Read access / насыщение — выход до increment.
- [close_dialog:16521–16527](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/telegram/MessagesManager.cpp#L16521): ненулевой count уменьшается без owner token.
- Другие одноимённые counters существуют для stories/gift auctions; они тоже не global client count.

Отчёт [09-06 native-open-count-gap](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-06-native-open-count-gap.md) относится к logical chat leases. Его countermodel **не запускался** здесь как полноценный native MessagesManager test; не выдаём его за результат client witness.

## Исполняемый witness, границы и null twins

[audit-td-client-lifetime.cjs](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/audit-td-client-lifetime.cjs):
- Выполняет actual ETS Gateway + Dispatcher + Runtime через существующие read-only fixtures; production methods не подменены моделью.
- Записывает native-boundary trace и воспроизводит его в C++17 executable с **дословно извлечённым целым threaded `ClientManager::Impl`** ([Client.cpp:478–592](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/telegram/Client.cpp#L478)). Изменения statements отсутствуют; `private` открыт только для чтения состояния.
- TD actors/scheduler/locks/queue/pool — явно заданные fixtures; `FlatHashMap` заменён `std::map`. События actor completion задаёт сценарий, не исполняется настоящий `Td`. Реальный manager определяет retain/close/erase. Это двухслойный trace witness, **не** исполненный полный JSON/NAPI/TDLib stack и не профилировка памяти.
- SHA256 извлечённого класса: `914b1ed71da242ce306fc78aad3ce6bbd103878158b68bf412ac19ae12400ae8`.
- Oracle: create + stop + receive сохраняет 1 entry; internal Closed + **один** receive сохраняет 1; ещё receive sentinel → 0 и публичный Closed. Так проверка отличает stop/частичный drain от release.
- Важная тонкость: первый `ClientManager::receive` может вернуть пустой response, **поглотив internal Closed**, ещё до sentinel. `td_receive == nullptr` не является доказательством завершения закрытия всех clients.

Фактический итог после ETS patch:

| Сценарий | Наблюдение |
|---|---|
| 3 × create → start throws → stop | `slots=3, initialized=0`, gateway `idle`, generation=3; closes=0 |
| Actual Runtime initialize failure → cleanup | `slots=1`, closes=0; runtime не может вернуть уже забытый ID |
| Те же 3 сохранённых ID → close + полный drain | `slots=0`, publicClosed=3 — положительный контроль |
| graceful Ok→Closed / Closed→Ok | `slots=0`, publicClosed=1; оба порядка проходят |
| close Ok, затем 5000ms без Closed | `slots=1, initialized=1`, stop, gateway idle |
| close request timeout 10000ms | то же: потеря владельца, а не доказанное закрытие |
| Дополнительный Closed + receive после timeout | `slots=0`: retention не доказывает бесконечную активность actor |
| concurrent destroy / deferred stop через Runtime | исправлены: оба callers ждут; create2 отсутствует до stop completion |

`initialized` — ненулевой `MultiImpl` в manager, а не измеренное число настоящих TD threads/DB.

## ETS patch: state/generation и зависимость от parent

Изменены только [TdGateway.ets](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/infra/td/gateway/TdGateway.ets) и [libtdlib_napi.d.ts](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/types/libtdlib_napi.d.ts), плюс два новых scripts и этот отчёт. Existing tests, AppCoreRuntime и C++ не редактировались этим агентом.

- `beginShutdown` публикует общий `shutdownPromise` **до** синхронного выполнения pipeline. Reentrant/concurrent destroy получает тот же Promise, а не немедленный success.
- Вход в shutdown/startup rollback: `destroying`, `clientGeneration++`, pending requests отклонены. Startup failure теперь тоже инвалидирует старую generation.
- Graceful destroy сохраняет response/update path до прежнего close/Closed wait. Перед **await native stop**: dispatcher отключён, `receiveLoopGeneration++`, receive flag сброшен, drain/timers/handlers очищены.
- Stop resolve → только тогда clientId=0, idle; normal destroy освобождает singleton, successful startup rollback сохраняет прежнюю retry-семантику singleton.
- Stop reject/throw → AppError, **остаётся destroying**, ID пока сохранён. `initialize/retryClosedClient` отклоняются; новый create/start невозможен. Повторный destroy начинает лишь stop retry, без повторного close и без повторного clientGeneration++.
- [AppCoreRuntime initialize:72–86](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/app/bootstrap/AppCoreRuntime.ets#L72) уже ждёт shutdownTask; [shutdown:391–430](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/app/bootstrap/AppCoreRuntime.ets#L391) уже awaits gateway.destroy. Поэтому runtime менять не потребовалось. Runtime failure cleanup вправе повторить stop, но не создать client до успешного barrier.
- Зависимость: parent реализует `stopReceiveLoop(): Promise<void>` с worker join, native Stopping до completion, busy throw при Start, shared native stop и retryable queue failure. ETS host tests проверяют **ожидание** этого контракта, не доказывают его native реализацию.

**Намеренная граница:** после успешного stop существующая policy всё ещё может публиковать idle без подтверждения client Closed при startup failure/close timeout. Stop safety и client-release safety — разные gates. Для client lifetime предложено отдельное согласование owned/retiring ID и drain до Closed; не добавлены speculative destroyClient/open_count option API. `logOut`/`destroy` не являются безопасной заменой close.

## Проверки

Из project root, Node `v24.12.0`, MinGW g++ `13.2.0`:

```text
node scripts/test-td-stop-barrier.cjs
  before patch: 0/9 PASS, exit 1 (early success / idle / missing rejection)
  after patch + two extra boundary cases: 11/11 PASS, exit 0
node scripts/test-td-stop-barrier.cjs --negative-controls
  11/11 PASS + 4/4 уникальные in-memory mutations пойманы точными ERR_ASSERTION; exit 0
node scripts/test-td-gateway-recovery.cjs       45/45 PASS (включая existing ETS 14/14)
node scripts/test-runtime-lifecycle.cjs         5/5 PASS
node scripts/test-runtime-account-recovery.cjs  7/7 PASS
node scripts/test-full-account-recovery.cjs     3/3 PASS
node scripts/test-native-bridge.cjs
  после parent native integration: baseline 32/32, thread-constructor injection 34/34 PASS
node scripts/audit-td-client-lifetime.cjs
  6 controls, 4 residual findings; exit 0 означает завершённый audit, НЕ lifetime acceptance
node scripts/audit-td-client-lifetime.cjs --strict
  те же 4 findings, exit 1: client lifetime gate остаётся RED
```

Diagnostic lifetime script перенесён через `apply_patch Move` в `audit-*.cjs`, поэтому не входит в discovery `test-*.cjs` общего all-green host gate. Negative controls запускаются только с `--negative-controls`: remove await stop → `stop completion is part of destroy`; early idle on reject → `rejected stop must retain destroying`; concurrent destroy early success → `same shutdown Promise before close completes`; remove await cleanup → `startup rejection must wait for cleanup stop`. Проверяются класс/code/operator assertion, конкретные actual/expected (для Promises — identity и early settlement), уникальность каждого изменения, реальное чтение мутированного source loader и неизменность production bytes. Compile errors, неожиданные exceptions, зависания и другие assertions не засчитываются.

До patch lifetime audit отдельно воспроизвёл early concurrent destroy и premature Runtime restart при deferred stop; после patch оба стали controls. Последний focused rerun включал новые native tests parent и все перечисленные ETS/runtime suites; каждый завершился exit 0. Это отдельные host witnesses, не единый SDK/NAPI/ArkTS runtime. Никаких broad builds, emulator/install/data/accounts/commits. ArkTS SDK compile и device/native SDK acceptance оставлены parent; здесь не заявлены.

Source SHA256 после patch:
- Gateway: `902c2b3baa2c121f221945681dfbfd25f73cfe3ab4d8251aeac24c51c7fe9adc` (до: `44ee917f331c767b116ef68a2bbe9f6da5c7128fadc50401be07d59b2f13300a`).
- Types: `327461c21e790a9f41e2046813eeb01e944f3db0d13629cd410993dba74b4f37`.
- AppCoreRuntime неизменён: `4bd3d300123253a0d505cc999a3b62715a73171eebd6e87e58eca8000b60ca82`.
- Client.cpp: `d0406b708ad6127b5be0c4db147ab5107950ba0e0a019dfabd8425a7ec870ccb`.

Необоснованные гипотезы исключены: «open_count — live client option»; «stop закрывает clients»; «Ok значит Closed»; «healthy shutdown всегда течёт»; «зелёный ETS barrier доказывает native lifetime». Возвращаться к ним только с новым конкретным source/runtime witness.

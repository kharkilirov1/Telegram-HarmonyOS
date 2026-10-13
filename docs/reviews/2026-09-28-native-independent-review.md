# Независимое adversarial review: native startup / callback ownership

Дата: 2026-09-28. База diff: `faf66b3e066afccdbbfa36442eb9122073f509b2`.

**Актуальный статус после повторной проверки harness: F1/P2 и F2/P3 закрыты в проверенной host-границе. Current — 14/14; все три прежних false-green counterexample теперь RED.** Подробности и новые hashes — в разделе «Resolution findings» в конце. Исходные findings, результаты 13/13 и передача parent ниже сохранены как история первого review.

## Вердикт

**Нового блокирующего production-дефекта в заявленном diff не обнаружено.** Независимо воспроизведены native **7 passed / 6 failed → 13 passed / 0 failed** и финальный gateway **45/45**. Startup throw не проглатывается проверенным ETS-путём: initialization отклоняется, gateway возвращается в `idle`, отправка запрещена; повторная initialization восстанавливает response delivery.

**Два замечания к harness:** P2 — он не проверяет соединение TSFN → `CallJs` → JS-аргумент; P3 — delete tracker доказывает освобождение storage объекта, но не внутреннего буфера строки. Для обоих получены конкретные false-green мутации и проверены минимальные усиления oracle. Это недостатки покрытия, **не найденные утечки/потери данных в текущем production diff**.

Production/tests не изменялись. Единственный созданный репозиторный файл — этот отчёт. Компиляция только SDK-free host-тестов; временные binaries создавал и удалял штатный native runner. In-memory варианты исходников поступали compiler через stdin. HarmonyOS builds, emulator, аккаунты, публикация и commits не запускались.

**Финализация bounded review:** F1/P2 и F2/P3 приняты пользователем и переданы parent для усиления harness: JS argc/argv/env/callback oracle, registration и delivery через зарегистрированный callback, external-buffer destruction. Эти будущие изменения данным review ещё не проверены; findings не помечены исправленными. Production менять не требуется в рамках этой передачи. Пользователь уточнил, что `NapiWrapper` был общим предположением, а в repo используются direct native exports; дальнейший поиск закрыт. Scope review не расширяется.

## Findings

### F1 — [P2] Счётчик JS-вызовов пропускает потерянный callback и потерянный аргумент

**Места:** [bridge_test.cpp:46–59](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/native-bridge/bridge_test.cpp:46), [bridge_test.cpp:77–84](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/native-bridge/bridge_test.cpp:77), [bridge_test.cpp:121–125](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/native-bridge/bridge_test.cpp:121).

Stub `napi_call_function` только увеличивает `calls`: `func`, `argc`, `argv`, receiver и env не проверяются. Все handles обозначены одинаковым `marker`. Assertion `marshalled == expected` проверяет вход `napi_create_string_utf8`, но не передачу созданного значения в JS.

Stub `napi_create_threadsafe_function` игнорирует `call_js_cb`. Callback cases вызывают `tdlib_napi::CallJs` напрямую; `td_receive` всегда возвращает `nullptr`, поэтому успешный старт настоящего host receive-thread не доказывает подключение этого callback.

**Два независимо запущенных counterexample, по одной мутации production bytes в памяти:**

```cpp
// M1: в CallJs, текущая строка 228
napi_call_function(env, undefined, js_callback, 0, nullptr, nullptr)
// вместо (..., 1, argv, nullptr)

// M2: в StartReceiveLoop, текущая строка 274
nullptr, &threadsafe_callback
// вместо CallJs, &threadsafe_callback
```

Оба варианта: **`Native bridge: 13 passed, 0 failed`, exit 0**. M2 не является просто невалидным вызовом N-API: переданный JS `func` остаётся ненулевым. В upstream при отсутствии custom callback default callback вызывает JS без аргументов; локальный SDK также не требует одновременно ненулевые `func` и `call_js_cb`.

**Минимальное исправление только harness:**

1. Выдать созданной строке отдельный handle; в `napi_call_function` проверять callback/receiver/env, `argc == 1`, `argv != nullptr`, `argv[0] == string_handle`; состояние ошибки включить в `Check`, сбрасывая перед каждым callback case. Проверить и значение, связанное с handle, а не только промежуточную строку.
2. Сохранить `call_js_cb` из успешного `napi_create_threadsafe_function`; в successful-start assertion проверить `registered_call_js == tdlib_napi::CallJs`. Это узкий registration contract, **не** расширение в enqueue/stop redesign.

Оба минимальных oracle проверены in-memory: аргументный oracle оставляет current **13/13**, M1 становится **11/13, exit 1**; registration oracle оставляет current **13/13**, M2 становится **12/13, exit 1**. Это закрывает показанные holes, но не подменяет проверку реального platform TSFN dispatch.

### F2 — [P3] Object delete tracker не доказывает освобождение string backing storage

**Места:** [bridge_test.cpp:19–33](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/native-bridge/bridge_test.cpp:19), [bridge_test.cpp:80–86](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/native-bridge/bridge_test.cpp:80).

`tracked` хранит только адрес `std::string`. `deleted == 1` фиксирует вызов глобального deallocator для объекта, а не исполнение деструктора/освобождение его внешнего character buffer.

**Counterexample:** заменить только владельца payload в памяти:

```cpp
struct StorageOnly {
    void operator()(std::string* p) const { ::operator delete(p); }
};
std::unique_ptr<std::string, StorageOnly> batch(static_cast<std::string*>(data));
```

Деструктор строки не вызывается; текущий harness всё равно выдаёт **13/13, exit 0**. Для фактического MinGW `std::string` проверено: тестовый JSON имеет length 16, его `data()` находится вне storage объекта.

**Минимальное усиление:** отдельный длинный, гарантированно не-SSO payload; отслеживать освобождение адресов объекта и `data()`, проверять оба, сбрасывать tracking до следующей allocation. Важно сначала подтвердить перехват deallocation именно на выбранной toolchain.

Здесь это существенно: добавленный in-memory buffer counter с обычной динамической libstdc++ видел `chars=0` **даже у правильного current RAII**. Этот неработающий oracle отвергнут, production leak из него не выведен. При host-компиляции с `-static-libstdc++` тот же контроль различает варианты:

```text
current:       object=1 chars=1 во всех шести payload cases; 13/13, exit 0
StorageOnly:   object=1 chars=0 во всех шести payload cases;  7/13, exit 1
```

То есть проверяемый вариант усиления для этой MinGW-среды — buffer tracking плюс статическая libstdc++; одной новой проверки `chars_deleted` недостаточно. Для остальных toolchains этот oracle здесь не выполнялся. Текущий `unique_ptr<std::string>` production менять не требуется: усиленная проверка подтвердила его правильное освобождение.

## Startup throw: экспорт, gateway и новый integration case

- [napi_init.cpp:5–12](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/cpp/napi_init.cpp:5): `startReceiveLoop` экспортирован непосредственно как `tdlib_napi::StartReceiveLoop`; swallowing wrapper/catch в этом export отсутствует.
- Отдельный символ/класс `NapiWrapper` в `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main` не найден: `rg -n -i napiwrapper entry/src/main` завершился exit 1. Непроверенному wrapper вне этого source tree поведение не приписывается.
- [tdlib_napi.cpp:260–283](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/cpp/tdlib_napi.cpp:260): оба новых failure-пути устанавливают `Stopped`, вызывают `napi_throw_error` и возвращают `nullptr` до публикации `Running`/создания receive-thread. TSFN handle на ошибке создания обнуляется под mutex.
- [TdGateway.ets:201–216](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/infra/td/gateway/TdGateway.ets:201): inner catch относится к **последующему исполнению relay callback**, не к синхронному вызову `startReceiveLoop`. Startup exception попадает во внешний catch, затем cleanup и новый `AppError(NETWORK, ..., retryable=true)`; присваивания `receiveLoopStarted = true` и `state = ready` не исполняются.
- [TdGateway.ets:220–241](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/infra/td/gateway/TdGateway.ets:220): cleanup инвалидирует generation, снимает subscriptions, сбрасывает drain и transport state. Native error `code` не переносится в `AppError`, но само отклонение и message сохраняются; это не swallowing и не новый ETS-дефект.
- [AppCoreRuntime.ets:103–127](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/app/bootstrap/AppCoreRuntime.ets:103) владеет update subscription. [AppCoreRuntime.ets:154–190](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/app/bootstrap/AppCoreRuntime.ets:154) для актуальной initialization делает cleanup и rethrow. Сценарий superseded runtime имеет отдельную осознанную ветку и здесь не переаудирован.

Финальный новый case в [test-td-gateway-recovery.cjs:88–113](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-td-gateway-recovery.cjs:88) прочитан и выполнен: fault injection `startReceiveLoop` → rejects по `kind/retryable/message` → `idle`/не ready/нет callbacks и pending → `send` rejects без native send → retry → один настоящий response через dispatcher разрешает `getMe` ровно один раз.

**Личный запуск:** `45/45 PASS`, exit 0; вложенные существующие ETS bodies — `14/14 PASS`. Независимый in-memory negative control — убрать только `this.cleanupAfterInitializeFailure();` — дал ровно `44/45`, exit 1:

```text
FAIL native receive startup failure rejects initialization; retry restores the response path
AssertionError: actual 'initializing', expected 'idle'
44/45 PASS
```

Предыдущие ожидания `technicalMessage` и автоматического update rewire не использованы как production findings. Финальный response-based oracle соответствует ownership. Новый case подтверждает существующий ETS catch/cleanup, а не исправление ETS в данном native patch. Он моделирует NAPI throw через JS fixture: фактический переход compiled N-API → Ark VM этим тестом не исполнен.

## Allocation и thread synchronization: что проверка действительно доказывает

- Production callback приобретает ownership до проверок env/callback/data; ранние returns при marshalling failure уничтожают payload. После `napi_call_function` нет повторной доставки или удаления уже освобождённого payload. Удаление самого owner из current bytes даёт `7/13`, exit 1: tracker умеет ловить полное отсутствие освобождения.
- Scalar `operator new` и unsized/sized `operator delete` в harness используют согласованную пару `malloc/free`; для созданного scalar `std::string` allocator mismatch не найден. Это не общая проверка всех allocation forms/heap: array/aligned allocation и N-API heap здесь не моделируются.
- В текущем расписании `tracked/deleted` используются callback cases **до** создания worker. Начальная публикация происходит до thread creation; reads `releases` после worker termination — после `join`. `receives` и `loop_state` atomic. В этом конкретном harness несинхронизированного одновременного доступа к этим counters не найдено.
- Состояния failure проверяются **до** `StopAndJoin`, поэтому cleanup теста не делает сломанный rollback зелёным. Дополнительный join в test helper означает, что самостоятельную корректность всего production stop-контракта из зелёного cleanup case выводить нельзя — она вне scope.
- Один current binary успешно выполнен **25 раз подряд**, каждый раз exit 0 и 13/13. Это smoke повторяемости, не TSan-доказательство отсутствия гонок и не проверка platform timing.
- Host headers намеренно не ABI-faithful: `napi_env`/handles — `void*`, status enum сокращён, finalize callback объявлен как `void*`. Используемые в этом diff null finalizer и проверки `!= napi_ok` этому не противоречат. Device ABI, pending-exception runtime и actual TSFN lifetime не объявляются проверенными.

## Runner / CI: fail-closed там, где есть assertion

[test-native-bridge.cjs:10–33](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-native-bridge.cjs:10) проверяет `error`, `signal` и exit status compiler/binary; catches устанавливают exitCode 1. Независимые fixture-прогоны **самого runner** в VM дали exit 1 для каждого:

| Инъекция результата процесса | Итог runner |
|---|---:|
| compiler ENOENT | 1, binary не запускался |
| compiler exit 1 | 1, binary не запускался |
| binary exit 1 | 1 |
| binary SIGABRT | 1 |
| binary ETIMEDOUT | 1 |

В этих пяти проверках filesystem/process results были fixtures; реальный hang/compiler failure специально не создавался. Реальный nonzero binary exit отдельно проверен native RED и owner-removal mutation.

[run-host-tests.cjs:6–26](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/run-host-tests.cjs:6): discovery действительно включает `test-native-bridge.cjs`; fixture native exit 1 даёт aggregate exit 1, пустой набор suites тоже exit 1. [smoke.yml:27–41](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/.github/workflows/smoke.yml:27) запускает этот aggregate в host job без `continue-on-error` и без Harmony build flag. Условным является отдельный Harmony build job, а не host job.

**Ограничение поставки, не новая ошибка:** на момент review native harness, его headers и runner ещё untracked (`git ls-files` для них пуст). Поэтому локальная CI wiring проверена, но присутствие этих файлов в будущем checkout и remote CI success не подтверждены. Автоматическое discovery не требует конкретно native suite и само по себе не заметит её отсутствие среди других suites. Этот отчёт не утверждает, что uncommitted patch уже защищён удалённым CI.

## Platform grounding и пределы вывода

`harmonyos_docs` использован в начале проверки и повторно для `napi_create_threadsafe_function`, `call_js_cb`, `napi_throw_error`, pending exceptions: Node-API Status Codes; Node-API Data Types and APIs; Error Handling Using Node-API. Документация описывает `napi_throw_error` как создание ArkTS Error, а не успешный silent return.

Сверены установленные headers: [native_api.h:854–871](C:/Program%20Files/Huawei/DevEco%20Studio/sdk/default/openharmony/native/sysroot/usr/include/napi/native_api.h:854), [throw:1318–1327](C:/Program%20Files/Huawei/DevEco%20Studio/sdk/default/openharmony/native/sysroot/usr/include/napi/native_api.h:1318), [call_function:2650–2662](C:/Program%20Files/Huawei/DevEco%20Studio/sdk/default/openharmony/native/sysroot/usr/include/napi/native_api.h:2650). В частности, `napi_call_function` допускает `napi_pending_exception`; сокращённый host stub не моделирует pending exception как VM-состояние.

Для независимой сверки source contracts прочитан OpenHarmony `arkui_napi`, commit `500de075e7debd442f7893bb84118d7502d90e65`:

- [napi_throw_error](https://github.com/openharmony/arkui_napi/blob/500de075e7debd442f7893bb84118d7502d90e65/native_engine/native_api.cpp#L2747-L2765) вызывает VM `ThrowException`.
- [TSFN creation](https://github.com/openharmony/arkui_napi/blob/500de075e7debd442f7893bb84118d7502d90e65/native_engine/native_node_api.cpp#L372-L400) публикует output handle после успешного `Init`.
- [default callback](https://github.com/openharmony/arkui_napi/blob/500de075e7debd442f7893bb84118d7502d90e65/native_engine/native_safe_async_work.cpp#L56-L73) и [cleanup callback](https://github.com/openharmony/arkui_napi/blob/500de075e7debd442f7893bb84118d7502d90e65/native_engine/native_safe_async_work.cpp#L408-L424) объясняют различие custom registration и direct callback test; cleanup действительно передаёт null env/callback.

Upstream source **не доказывает идентичность установленному SDK/device binary**. Production SDK build и real Ark VM test намеренно не выполнялись. Unrelated native enqueue/stop, client-count и session/media ownership остаются OPEN и не превращены в findings этого review. Рекомендации blindly delete payload при любом `napi_call_threadsafe_function != napi_ok` здесь нет.

## Воспроизведение без изменения production/tests

Обычные команды, рабочий каталог `C:/Users/Kharki/Desktop/Telegram-HarmonyOS`:

```powershell
node C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-native-bridge.cjs
node C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-td-gateway-recovery.cjs
```

Toolchain review: Node `v24.12.0`; `C:/Strawberry/c/bin/g++.exe`, MinGW-W64 x86_64-ucrt-posix-seh GCC `13.2.0`.

Для мутаций использован следующий механизм: прочитать настоящий harness и production text; вместо его `#include "../../entry/src/main/cpp/tdlib_napi.cpp"` подставить выбранные production bytes. Запустить неизменённый JS runner через VM, перехватив только первый `spawnSync`: заменить аргумент `bridge_test.cpp` на `-x c++ -`, добавить include-directory production CPP и передать translation unit как `input`. Binary execution, timeout, exit handling и удаление unique temp directory остаются штатными. RED берётся из `git show HEAD:entry/src/main/cpp/tdlib_napi.cpp`; M1/M2/StorageOnly — точные замены из Findings, с assertion единственности каждой замены. Файлы на диске не подменялись.

### Матрица лично выполненных проверок

| Вариант | Harness | Результат |
|---|---|---|
| HEAD native | текущий | 7/13, exit 1 |
| current native | текущий | 13/13, exit 0 |
| current native, 25 последовательных запусков | текущий | все 25: 13/13, exit 0 |
| owner полностью удалён | текущий | 7/13, exit 1 |
| M1: zero JS args | текущий | **13/13, false green** |
| M2: null custom callback | текущий | **13/13, false green** |
| StorageOnly | текущий | **13/13, false green** |
| current / M1 | аргументный oracle | 13/13 / 11/13 |
| current / M2 | registration oracle | 13/13 / 12/13 |
| current / StorageOnly | buffer oracle + static libstdc++ | 13/13 / 7/13 |
| current gateway | финальный новый case | 45/45, exit 0 |
| gateway без failure cleanup | тот же suite | 44/45, exit 1 |

### Идентичность review snapshot

Повторное хеширование после экспериментов подтвердило неизменность CPP, C++ harness, всех трёх stub headers, native runner, gateway production, native export и CI/aggregate runner относительно снятого snapshot. Gateway test обновлялся родителем во время review; выполнен и оценён **финальный response-path вариант**, hash ниже. Промежуточные oracle не объявлены production defects.

| Файл | SHA-256 |
|---|---|
| [tdlib_napi.cpp](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/cpp/tdlib_napi.cpp) | `9e68c25ac63d59e98d0cfa43ab91300a9fe4606f4cffa95a49c236777a4fc293` |
| [bridge_test.cpp](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/native-bridge/bridge_test.cpp) | `0256fb33e0d6b36af56d2a6ea957d61b754f7d0f5d711a29b7b2bfe279dbe5f9` |
| [test-native-bridge.cjs](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-native-bridge.cjs) | `b4a3e8e168032453e5b4b8614ae9547413a3d8b0efb8354c1389d7b14d4bfccf` |
| [TdGateway.ets](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/infra/td/gateway/TdGateway.ets) | `44ee917f331c767b116ef68a2bbe9f6da5c7128fadc50401be07d59b2f13300a` |
| [test-td-gateway-recovery.cjs](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-td-gateway-recovery.cjs) | `817e8f05053c1eecaeb3fdf08d0aa6918c1c6e02a421d78be6af4b2ad522c401` |

**Итоговая граница acceptance:** narrow startup rollback и direct callback ownership подтверждены host witnesses; ошибок swallowing в проверенной source chain нет. F1/F2 ограничивают полноту regression oracle. Полная native delivery, ABI и device teardown этим review не закрываются.

## Resolution findings — повторная узкая проверка, 2026-09-28

**F1/P2 — RESOLVED; F2/P3 — RESOLVED для текущего Windows host harness.** Production CPP сохранил SHA-256 `9e68c25ac63d59e98d0cfa43ab91300a9fe4606f4cffa95a49c236777a4fc293`. Повторного полного аудита, поиска wrappers, Harmony builds/emulator и повторного gateway suite не выполнялось.

Прочитаны изменённые [bridge_test.cpp](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/native-bridge/bridge_test.cpp), [test-native-bridge.cjs](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-native-bridge.cjs) и текущий stub header. Лично выполнен штатный native runner и три прежние production-мутации только в памяти:

| Вариант с усиленным harness | Фактический результат | Exit |
|---|---|---:|
| Current production, штатный runner | **14 passed, 0 failed** | 0 |
| M1: `argc=0, argv=nullptr` | **10 passed, 4 failed** | 1 |
| M2: `call_js_cb=nullptr` при TSFN registration | **12 passed, 2 failed** | 1 |
| M3: `StorageOnly`, без деструктора строки | **8 passed, 6 failed** | 1 |

Все negative controls дошли до assertions исполняемого binary: это не compiler errors и не ошибки reviewer scaffolding.

- **F1:** [JS oracle:65–71](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/native-bridge/bridge_test.cpp:65) проверяет env/receiver/callback, argc/argv, отдельный `string_handle` и main host thread; проверяется доставленное содержимое. [Registration/delivery:160–178](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/native-bridge/bridge_test.cpp:160) требует именно `tdlib_napi::CallJs`, один enqueue и один JS-вызов с точным batch. Настоящий production receive-thread собирает batch из TDLib fixture, stub сохраняет payload под mutex, а main host thread вызывает **зарегистрированный** callback после `StopAndJoin`. В этот момент worker уже joined, поэтому iteration очереди не конкурирует с её наполнением. M1 ломает и direct callback, и delivery; M2 ломает registration и delivery — прежний обход через direct-only checks устранён.
- **F2:** [payload/tracker:104–120](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/native-bridge/bridge_test.cpp:104) использует JSON с 4096 символами текста, отслеживает объект и его внешний character buffer, проверяет оба deallocation **до** cleanup теста. [Runner:19–25](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-native-bridge.cjs:19) добавляет `-static-libstdc++` на Windows. Current проходит; M3 проваливает все шесть payload cases. Interposition теперь подтверждён различающим executable witness, а не предположением.

Новые review hashes: `bridge_test.cpp` — `7da059ab15f102fcfea5d1b3bc939e6c1d2f3a305b4f3ae6ab6bbf539b159900`; `test-native-bridge.cjs` — `7f8351acd09a1e64c6e561e937ac3ab0d1c4ba0122bf9dbef3fc9358a2282d04`. Stub `native_api.h` остался `a8f0ea256f52b13cc51e68ca283564f8fe614b28836d293ac029d3e265c9458d`.

**Граница resolution:** закрыты конкретные доказанные holes F1/F2; подтверждена host delivery через зарегистрированный callback. Stub accepted queue не является HarmonyOS TSFN runtime: enqueue failures, platform teardown/timing, ABI и remote CI по-прежнему не объявляются проверенными. Reviewer изменил только этот отчёт; production/tests на диске не менял.

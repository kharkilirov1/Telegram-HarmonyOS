# Native TSFN: граница env teardown

Дата: 2026-09-28. Независимый read-only sidecar; продолжение lifecycle review, не повтор enqueue-исследования.

## Вывод для интеграции

**Installed headers и просмотренная официальная документация не устанавливают универсального порядка `async cleanup hook → TSFN finalizer`.** В pinned OpenHarmony source для обычного env доказан более узкий порядок: запуск hooks → обслуживание loop до завершения async-cleanup handshake → общий `uv_walk`/закрытие loop. Это позволяет построить **условно безопасный** teardown: закрыть admission, join producers вне owner thread, отдать последнюю TSFN lease, дождаться finalizer и только затем подтвердить cleanup. Само наличие hook не удерживает TSFN и не останавливает producers.

Два существенных ограничения:

1. **Finalizer может исполниться до hook или во время ожидания hook.** Перед hooks уже есть loop pumping; async-hook callback вызывается синхронно, остальные hooks запускаются без ожидания завершения его отложенной работы. LIFO — порядок запуска hooks, не их завершения и не порядок всех finalizers.
2. **`Ark Context Engine` — другой teardown.** В обеих просмотренных ревизиях он вызывает `RunCleanupHooks(false)`, не ждёт async cleanup и проверяет незавершённые requests/TSFN через `HILOG_FATAL`. Для этого пути нужен завершённый stop **до уничтожения context**, а не join, начатый из cleanup hook.

Это **B-source + C-design, не acceptance installed HarmonyOS binary**. SDK API 26, OpenHarmony release 6.1 и ОС устройства — разные идентификаторы; их соответствие здесь не установлено. Parent может независимо завершать enqueue ownership fix; этот документ задаёт отдельный integration gate.

## 1. Область и лично прочитанные inputs

- [Native implementation](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/cpp/tdlib_napi.cpp): снимок 504 строки, SHA-256 `5a00f53505de9360441468137478c979ab56f31251e63e52a1fa448fe139ea0c`.
  - Строки 26–46: process-global loop/thread/TSFN и отдельные mutex; не per-env cleanup owner.
  - 284–288: TSFN создаётся с count=1, без finalize callback/context. 303–348: receive thread использует TSFN и сам release-ит его на выходе. 306–334: после `td_receive(1.0)` нет повторного admission check непосредственно перед call под общим stop/submit gate.
  - 393–425, 428–476: штатный stop уже переносит join в async-work execute, но completion управляет Promise; это не отдельный env-teardown handshake. В этом файле регистрации cleanup hooks нет.
  - Это только исходный снимок данного чтения, **не оценка параллельного патча parent**. При финальной сверке native файл уже имел другой SHA-256: `be9988f5012213cdb9e04db373abc473b1e8a9344d53d5f4590860e81012684f`; его новые строки здесь не переаудировались. Sidecar этот файл не редактировал. Enqueue ownership здесь заново не исследуется.
- [Предыдущее исследование](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-28-native-lifecycle-contract.md): SHA-256 `3bafd2a07818923050f11fd1303d4343b7c3c8c2677a5916e114cf27f77df9a1`; за основу взяты scope и открытый вопрос §6, source premises ниже проверены заново.
- Project context/реестр references прочитаны. В `C:/Refs/Telegram/HarmonyOSComponentUXExamples` и `C:/Refs/Telegram/HarmonyOS-Codelabs` поиск `napi_add_async_cleanup_hook|napi_remove_async_cleanup_hook` в C++/headers: `rg` exit 1, совпадений нет. iOS UI-reference не определяет этот platform contract.
- `harmonyos_docs` доступен: выполнены целевые запросы add/remove async cleanup, TSFN cleanup и cross-thread restrictions. Использован context-mode для чтения/отбора, fetch/index и поиска. Прямой fetch Huawei guide дал только SPA-заголовок; не считается чтением тела страницы. Документируемый fallback — MCP snippets + pinned первичные OpenHarmony docs/source.
- **Единственная управляемая запись sidecar — этот файл через `apply_patch`.** Production/native/tests, status/task/memory files не редактировались; build/test/install/emulator, Telegram/TDLib API/account/user-data действия и commit не выполнялись.

## 2. Installed SDK: что есть, но чего headers не доказывают

Лично прочитан `C:/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/native/oh-uni-package.json`: API `26`, platform `26.0.0`, version `26.0.0.23`, `Beta1`. Это metadata SDK, не fingerprint target runtime.

Include root: `C:/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/native/sysroot/usr/include/`.

| Header | Проверенные строки / смысл | SHA-256 |
|---|---|---|
| `napi/native_api.h` | 189–241: sync/async cleanup add/remove, since 11; 824–835: UV loop; 837–871: TSFN/finalizer; 914–958: release/ref/unref | `c7d241f14ecd4d3e7c9b9ae34eff1f5da40bec53686717870227285b2e97f56a` |
| `node_api.h` | 267–278: async-cleanup declarations при `NAPI_VERSION >= 8` | `c5df241e2763173df40814838db12705c33835ce1c8d9900396eb8aa8a040a56` |
| `node_api_types.h` | 44–48: opaque handle, callback `(handle, void* data)`; callback не получает `env` | `69297f804fd2680e6339ab661391ae07755cda1473a28934003aa432e0060793` |
| `uv.h` | 331–332, 1073–1087: work/after-work callbacks, `uv_work_t`, `uv_queue_work` | `d6ef6312ef12a74460091cd690dc5e1a82a106163c7768ebafe6f036682deaf2` |

В этих declarations/comments **нет** обещания порядка TSFN-vs-hooks, автоматического producer join, thread-safety произвольного использования cleanup handle или гарантии выполнения hook при аварийном завершении процесса. `ref/unref` — liveness loop; counted TSFN lease — другой механизм. Ни одно не заменяет другое.

## 3. Доказанный порядок в pinned source

Ревизии:

- **S**: `openharmony/arkui_napi@500de075e7debd442f7893bb84118d7502d90e65`.
- **R61**: `openharmony/arkui_napi@827f9e4e8cbd74e40633a17374008d076a1f7508` — ранее закреплённый OpenHarmony-6.1-Release.
- **D**: `openharmony/docs@f41b9345badd47c7ab0c263344cd7f4b5a549afb`.
- **U**: `openharmony/third_party_libuv@75b173fd284d7b77a910fb9abf4c87c7ef5cdf88`; не установлен факт включения U в S или installed ОС.

### Обычный env с собственным loop

В [S: `Deinit`, 157–186][deinit] и [S: `RunCleanup*`, 863–938][engine-cleanup]:

```text
Deinit
  close engine uvAsync
  RunCleanup
    CleanupHandles: while requestWaiting > 0, uv_run(ONCE)   [ДО hooks]
    RunCleanupHooks(true)
      snapshot hooks; sort descending registration counter
      invoke each hook inline; erase its registration
      CleanupHandles: pump loop while requestWaiting > 0    [ПОСЛЕ группы]
    uv_run(NOWAIT)
    uv_walk: uv_close(unclosed_handle, nullptr)
    uv_run(DEFAULT) until drained
  NotifyVMIgnoreFinalizeCallback
  DeinitWithoutUV
  SetDead; SetStopping(true)
  close/delete loop
```

Для `napi_add_async_cleanup_hook` [S: 269–368][async-hook]:

- Регистрация создаёт self-owned `AsyncCleanupHookInfo` и добавляет обычный `RunAsyncCleanupHook` в тот же реестр hooks.
- При входе в wrapper: `IncreaseWaitingRequestCounter()` → `started_=true` → **inline** user hook. Слово async не означает, что тело hook уже работает на background thread.
- `napi_remove_async_cleanup_hook(handle)` удаляет handle. **До запуска** это unregister; **после запуска** destructor вызывает saved `done_cb`, который уменьшает waiting counter и снимает self-owner.
- `RunCleanupHooks` стирает registration при возврате hook, но outstanding async operation остаётся учтена waiting counter до remove. Повторный remove недопустим: это уже удалённый opaque handle.
- Поэтому started hook с неотданным handshake задерживает переход к общему `uv_walk` на этом пути. Но не блокирует выполнение других hooks и callbacks во время `uv_run`.

R61 повторяет [порядок запуска hooks][r61-hooks], [предварительный drain, ожидание и общий sweep][r61-cleanup], [Deinit][r61-deinit]. Это проверка второй source-ревизии, не второй независимый runtime witness.

### Почему отсюда не следует «hook всегда раньше finalizer»

1. Предварительный `CleanupHandles()` может исполнять уже готовые TSFN callbacks/finalizer, если есть waiting requests. Штатный stop мог вообще завершиться до начала teardown.
2. TSFN **не регистрирует cleanup hook автоматически**: это явно записано в [D: 524–538][doc-no-hook] и согласуется с просмотренными constructor/`Init` в [S: 75–155][tsfn-init]. Нет скрытого TSFN hook, чей порядок можно исправить только временем своей регистрации.
3. Другой hook может сделать abort того же handle. Async handshake нашего hook не останавливает этот hook; LIFO не является async completion barrier.
4. Обычный TSFN close: queue empty + count=0 → `CloseHandles` → `uv_close` callback → finalizer → trailing null-env callbacks → `delete this` ([S: 375–427][tsfn-cleanup]). При abort closing-ветка идёт к `CloseHandles` без ожидания count=0 ([S: 308–320][tsfn-closing]). Anchor защищает только от **обычного** premature final release, не от abort.
5. Общий sweep делает `uv_close(handle, nullptr)`, не `NativeSafeAsyncWork::CloseHandles`. Поэтому **нельзя рассчитывать на этот sweep как на способ дождаться своего TSFN finalizer**. До ACK нужно завершить TSFN собственным путём; иначе вероятен leak, а не доказанная корректная finalization.

Официальный [cleanup guide D: 173–234][doc-cleanup] показывает native UV callback → `uv_close` → close callback → `napi_remove_async_cleanup_hook`. Это свидетельство deferred cleanup/loop-thread completion, не обещание порядка TSFN. Его пример не делает producer join. Формулировка guide о неблокирующем exit не означает гарантированное время выхода: source явно ждёт waiting requests, обслуживая loop.

### Отдельный Context env: стоп-условие для этой конструкции

[S: destructor, 624–645][ark-destructor] выбирает `Deinit()` только для `isMainEnvContext_`; иначе — [S: `DeconstructCtxEnv`, 700–739][ctx-teardown]. Последний вызывает `RunCleanupHooks(false)`, затем `DeinitWithoutUV`, проверяет `HasWaitingRequest()`/`HasActiveTsfn()` через fatal и маркирует engine dead. [R61: 704–727][r61-context] содержит тот же существенный запрет ожидания.

**Здесь async hook, запустивший долгий join, не даёт lifetime fence.** Наличие ненулевого UV loop не доказывает подходящий env: TSFN context-env использует parent loop ([S: 129–138][tsfn-init]). `isMainEnvContext_` также не тождественно UI/main thread приложения: важен тип engine/его teardown path. На неподтверждённом env нельзя заявлять достаточность одной регистрации hook.

## 4. Минимальная конструкция без join на owner thread — C-design

Предлагается **один native lifecycle control block на owner env/receive epoch**, один async cleanup hook и один reaper operation. Не новый TSFN для завершения stop. Payload policy/null wakeups остаются областью parent.

### Обязательные premises

| Premise | Для чего нужен / граница доказательства |
|---|---|
| P1. Реальный teardown ждёт started async hook и обслуживает owner loop | Handshake проверен в S, порядок ordinary-env loop — в S/R61; **не доказано для installed binary**, опровергнуто для указанного Context path. |
| P2. Hook успешно зарегистрирован до публикации handle/запуска producer; native owner/code живут до ACK | Частичный start должен откатываться без запуска незащищённого thread. Module unload/process kill не покрыты headers. |
| P3. Есть положительная coordinator anchor lease; отдельный явный учёт producer leases; никто не abort-ит/не отдаёт anchor до quiescence | Не разрешать normal stop, teardown и другой hook независимо выполнять terminal action. После `closing` нет call/acquire/release retry по старому handle. |
| P4. Submit admission и выдача handle синхронизированы с shutdown gate | Producer проверяет gate непосредственно перед каждым обращением, включая после receive. Raw pointer не выносится за защищённый submit/in-flight lifetime. Atomic stop flag без этого недостаточен. |
| P5. Join не зависит от JS/TSFN delivery или будущего hook | Native wait должен закончиться самостоятельно/по native cancel. Нет lock, удерживаемого owner во время join. Submit под gate только nonblocking; отсутствие blocking enqueue само по себе не гарантирует нулевую задержку mutex. |
| P6. Есть live loop work/ref до completion и finalizer | Waiting counter сам не является `uv_handle`/loop ref. Не unref-ить последний обслуживающий TSFN/cleanup handle, пока ожидается finalizer. Lease count и loop ref учитывать раздельно. |
| P7. Все users control block имеют самостоятельное native ownership | Hook, reaper, normal stop и TSFN finalizer не уничтожают state друг у друга. Trailing null-env callback возвращается **до** любого context access, как требует предыдущий lifecycle review. |

### Порядок действий

1. **Setup, живой owner env:** подготовить control block/UV loop/reaper storage; зарегистрировать async hook, TSFN с finalizer, anchor/producer leases и требуемый loop ref. Проверить каждый результат до запуска producer. Hook лучше сохранять на жизнь owner env; снятие hook после normal stop безопасно только после полного native retirement, с повторной регистрацией до нового start.
2. **Hook entry на owner thread:** сохранить cleanup handle; под коротким gate выставить `tearing_down/stopping`, закрыть admission/новые acquires и JS delivery. Разбудить native waits. Захватить/присоединиться к **единственному** reaper и сразу вернуть управление. Ни `join`, ни waiting CV, ни Promise, ни новый JS async-resource в теле hook.
3. **Reaper вне owner thread:** реально join-ить всех producers и дождаться остальных submit borrowers. Минимальный кандидат — `uv_queue_work` с настоящим join в `work_cb`, а не пустая work-функция для пересылки сообщения. `after_work_cb` приходит на loop thread по [upstream libuv contract][libuv-work]; installed `uv.h` объявляет этот API. Pinned [U: queue work/done][uv-work-source] также имеет этот split, но не связывает его с installed runtime. Планирование/доставка, libuv linkage и pool starvation требуют проверки. В текущем `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/cpp/CMakeLists.txt` явного `libuv` entry поиском не найдено; здесь CMake не менялся.
4. **Owner-loop native completion:** только при реально выполненном join выставить `joined=true`; producer leases уже отданы ровно один раз по согласованному протоколу. Забрать coordinator handle в terminal action, удалить публичную доступность; отдать anchor **один раз** обычным release. Abort допустим лишь после того же барьера при согласованной discard-policy. Нет retry terminal release даже при generic failure, нет Promise settlement после начала teardown. Любой существующий `StopWork` должен разделять с hook один результат join: не перемещать/не join-ить тот же `std::thread` повторно.
5. **TSFN finalizer:** только записать milestone/снять свой native owner; никакого join. Политика unconsumed application queue должна быть согласована с parent. После `joined && finalizer_observed && no_other_native_cleanup_users` подтвердить hook **ровно один раз** через remove на owner thread. Если normal stop уже всё завершил до hook, подтвердить по сохранённым milestones без обращения к прежнему TSFN.

ACK внутри finalizer допустим лишь при P7 и отсутствии reentrant `uv_run`: runtime продолжит текущий close callback, включая null-env tail, прежде чем внешний cleanup pump вернётся. Finalizer держит локальный owner на время своей работы; ACK не означает, что `delete this` уже выполнен. Если интеграция требует отдельного milestone «finalizer вернулся», нужен самостоятельный loop callback/fence; это не следует из входа в finalizer.

Искомая application ordering при P1–P7:

```text
last admitted submit finishes → all producers/borrowers quiescent
    → terminal TSFN action → finalizer observed → cleanup ACK
```

**Это запрет доступа после reclamation, а не проверка stale handle по return code.** Finalizer flag/обнуление pointer/наш mutex отдельно не pin-ят runtime object: engine не обязан брать наш mutex. За lifetime отвечают P1 + P3; gate закрывает новые обращения, reaper завершает старые.

## 5. Failure paths и недопустимые сокращения

- **Нельзя ждать в предварительно queued NAPI async-work, пока teardown hook отменит producer.** [S: async-work Queue][async-work] увеличивает waiting counter до execute, [AfterWork][async-after-work] уменьшает его на complete; предварительный `CleanupHandles` может не дойти до hook. Уже начатый normal stop обязан сам подавать cancel, не ждать hook.
- **Флаг `tearing_down`, установленный только в hook, не покрывает pre-drain.** Существующий `CompleteStop` может выполниться раньше hook, уже внутри engine teardown. Совместимость его Promise/JS операций с этим состоянием — отдельная незакрытая проверка; один новый флаг не доказывает отсутствие JS во всём teardown. Native retirement нельзя связывать с успешным Promise settlement.
- **Queue/reaper failure, отмена до execute, зависший producer, не пришедший finalizer:** не ставить joined/ACK и не освобождать потенциально используемые owners. Это incomplete teardown; удержание handshake может задержать exit неограниченно. Timeout не разрешает удалить живой state. Нужен явный диагностируемый failure policy; bounded exit этим проектом не доказан.
- **Early abort → ждать `napi_closing` от producer:** недопустимо; opaque handle может быть уже освобождён до очередного вызова. Register-late/LIFO это не чинит.
- **Finalizer как первый stop signal:** слишком поздно для lifetime fence. `shared_ptr` control block не продлевает жизнь самого opaque TSFN.
- **Remove hook на background thread только потому, что API не принимает env:** не обосновано installed header. Дизайн выше делает terminal remove на owner loop, как официальный пример; cross-thread permission не предполагается.
- **Join/detach в finalizer либо переиспользование обычного JS Promise stop при env exit:** не решение. Detached thread требует отдельного доказательства жизни data и module code; такого доказательства здесь нет.

## 6. Следующие проверки parent — здесь НЕ выполнялись

| Проверка | Положительное свидетельство | Контрпример, который проверка обязана различать |
|---|---|---|
| Installed env/engine path | Fingerprint ОС/NAPI + фактический owner type; trace `hook enter → native after-work → finalizer → remove → env exit` | Context-env path/forced exit не выдаются за ordinary-env success. Header API number недостаточен. |
| Nonblocking join | В синтетическом изолированном env thread IDs показывают join не на owner, hook быстро возвращается; задержанный producer не мешает native loop tick | Main-thread join, пустой work callback и fallback без producer не проходят. |
| Handle lifetime gate | Producer задержан после receive и перед call; hook закрывает gate; после finalizer TSFN API calls=0 | Ранний abort, сырой pointer вне gate, снятая anchor должны ломать проверку, а не «успевать» на удачном schedule. |
| Общий stop ownership | Concurrent normal stop/teardown: один join, один terminal release, один remove; finalizer до hook также обработан | Двойной move/join/remove; cancelled execute ошибочно трактуется как joined. |
| Остальные hooks / pre-drain | Нет другого владельца terminal action; outstanding work не ждёт будущий hook; marker доказывает выбранный cleanup path | Ранний foreign abort и cyclic pre-drain дают ожидаемый отрицательный результат. |
| Completion liveness | Проверены root-loop ref, реальная libuv linkage, queue failure/cancel, starvation, release failure и missing finalizer | ACK при незавершённом native state / busy spin из-за последнего unref недопустимы. |
| Context/data/code lifetime | Null-env tail не разыменовывает context; владельцы живут до последнего native access; normal completed cleanup отдельно от abnormal termination | Finalizer-before-tail, unload при живом producer, повторное использование generation/адреса. |

Для первого device witness достаточно отдельного synthetic native module/worker без аккаунта, TDLib запросов и user data; его безопасность/разрешение и запуск остаются следующей задачей. Нынешний результат — source/header contract и условная конструкция, **не runtime test, build или исправление production**.

## Источники

[deinit]: https://github.com/openharmony/arkui_napi/blob/500de075e7debd442f7893bb84118d7502d90e65/native_engine/native_engine.cpp#L157-L186
[engine-cleanup]: https://github.com/openharmony/arkui_napi/blob/500de075e7debd442f7893bb84118d7502d90e65/native_engine/native_engine.cpp#L863-L938
[async-hook]: https://github.com/openharmony/arkui_napi/blob/500de075e7debd442f7893bb84118d7502d90e65/native_engine/native_node_api.cpp#L269-L368
[r61-hooks]: https://github.com/openharmony/arkui_napi/blob/827f9e4e8cbd74e40633a17374008d076a1f7508/native_engine/native_engine.cpp#L845-L879
[r61-cleanup]: https://github.com/openharmony/arkui_napi/blob/827f9e4e8cbd74e40633a17374008d076a1f7508/native_engine/native_engine.cpp#L882-L919
[r61-deinit]: https://github.com/openharmony/arkui_napi/blob/827f9e4e8cbd74e40633a17374008d076a1f7508/native_engine/native_engine.cpp#L157-L186
[doc-no-hook]: https://github.com/openharmony/docs/blob/f41b9345badd47c7ab0c263344cd7f4b5a549afb/en/application-dev/reference/native-lib/napi.md#L524-L538
[tsfn-init]: https://github.com/openharmony/arkui_napi/blob/500de075e7debd442f7893bb84118d7502d90e65/native_engine/native_safe_async_work.cpp#L75-L155
[tsfn-cleanup]: https://github.com/openharmony/arkui_napi/blob/500de075e7debd442f7893bb84118d7502d90e65/native_engine/native_safe_async_work.cpp#L375-L427
[tsfn-closing]: https://github.com/openharmony/arkui_napi/blob/500de075e7debd442f7893bb84118d7502d90e65/native_engine/native_safe_async_work.cpp#L308-L320
[doc-cleanup]: https://github.com/openharmony/docs/blob/f41b9345badd47c7ab0c263344cd7f4b5a549afb/en/application-dev/napi/use-napi-about-cleanuphook.md#L173-L234
[ark-destructor]: https://github.com/openharmony/arkui_napi/blob/500de075e7debd442f7893bb84118d7502d90e65/native_engine/impl/ark/ark_native_engine.cpp#L624-L645
[ctx-teardown]: https://github.com/openharmony/arkui_napi/blob/500de075e7debd442f7893bb84118d7502d90e65/native_engine/impl/ark/ark_native_engine.cpp#L700-L739
[r61-context]: https://github.com/openharmony/arkui_napi/blob/827f9e4e8cbd74e40633a17374008d076a1f7508/native_engine/impl/ark/ark_native_engine.cpp#L704-L727
[async-work]: https://github.com/openharmony/arkui_napi/blob/500de075e7debd442f7893bb84118d7502d90e65/native_engine/native_async_work.cpp#L91-L123
[async-after-work]: https://github.com/openharmony/arkui_napi/blob/500de075e7debd442f7893bb84118d7502d90e65/native_engine/native_async_work.cpp#L238-L281
[libuv-work]: https://docs.libuv.org/en/v1.x/threadpool.html#c.uv_queue_work
[uv-work-source]: https://github.com/openharmony/third_party_libuv/blob/75b173fd284d7b77a910fb9abf4c87c7ef5cdf88/src/threadpool.c#L582-L639

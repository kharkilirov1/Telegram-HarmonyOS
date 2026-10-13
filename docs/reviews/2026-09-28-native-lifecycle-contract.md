# HarmonyOS TSFN: ownership, lifetime и asynchronous stop

Дата исследования: 2026-09-28. Независимый sidecar для маршрута reliability → UI → feature parity.

## Вывод

**Минимальная консервативная рекомендация: app-owned queue с owning payloads; TSFN переносит только `data == nullptr` как уведомление; stop закрывает приём, асинхронно дожидается всех native producers и только затем завершает владение TSFN.** Это рекомендация по конструкции, а не подтверждённая исправность production/binary.

Три причины:

1. Installed header **не обещает**, что любой `non-ok` означает отсутствие enqueue. В просмотренном OpenHarmony source есть `queue_.emplace_back(data)` перед `uv_async_send`; при ошибке send отката очереди нет. Поэтому универсальное `non-ok → delete payload` не обосновано. [S1:181–216][send], [S2:403–434][call-wrapper].
2. В просмотренном source **finalizer выполняется раньше callbacks с `env == nullptr`** для оставшихся элементов. Finalizer, удаляющий registry/context/payloads, несовместим с последующим callback, который их разыменовывает или снова удаляет. [S1:408–427][cleanup].
3. `abort` не является барьером завершения producers: ветка closing закрывает handle без проверки положительного `threadCount_`. Документация отдельно предупреждает о UAF после abort. Следовательно, нельзя сначала abort, а потом разрешать worker ещё раз обратиться к TSFN. [S1:235–276][release], [S1:308–320][drain], [D1:93–97][doc-abort].

**Оговорка о достижимости:** просмотренный Unix `uv_async_send` для валидного ненулевого handle возвращает `0`; его DFX-ветка `-1` требует `handle == NULL`, тогда как TSFN передаёт адрес своего поля. Post-insertion failure подтверждён как условная ветка NAPI, но не как воспроизведённый или доказанно достижимый дефект установленного HarmonyOS runtime. [U1:110–138][uv-unix].

## 1. Границы работы и источники

- Production, native implementation, harness и stop integration не изменялись и здесь не аудировались: это область parent.
- Не запускались native tests, сборки, emulator, install, устройства, accounts/credentials, commits и глобальная настройка.
- Единственная управляемая файловая запись sidecar — этот документ. Project status/task/memory-файлы не обновлялись. Существующие изменения рабочего дерева принадлежат другим работам.
- Сначала выполнен поиск `harmonyos_docs`: TSFN call/release, `napi_generic_failure`, abort/UAF, finalizer, async cleanup hooks. После повторного discovery оба MCP — `harmonyos_docs` и `context-mode` — доступны; далее использовались `ctx_execute`, `ctx_fetch_and_index`, `ctx_search`, отбор строк вместо больших raw documents.
- MCP search выдаёт фрагменты без пригодного для permalink document ID/commit. Поэтому проверяемые ссылки ниже закреплены на первичном OpenHarmony source/docs, а MCP не используется как доказательство версии установленного runtime.
- Прочитаны project context и registry references. В `C:/Refs/Telegram/HarmonyOSComponentUXExamples` и `C:/Refs/Telegram/HarmonyOS-Codelabs` поиск TSFN create/call/release по C++ headers/sources не дал совпадений. iOS UI-reference к этому платформенному ownership-контракту неприменим.

Классы свидетельств:

- **A-local:** лично прочитанные installed SDK headers/metadata и номера строк.
- **B-source:** лично просмотренный первичный source/docs с pinned commit; доказывает содержание этой ревизии, **не поведение установленного binary**.
- **C-design:** вывод о безопасной конструкции и её предпосылках; не runtime verification.

### Фактически установленный SDK — не предполагаемый API 22

В `C:/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/native/oh-uni-package.json`:

| Поле | Наблюдаемое значение |
| --- | --- |
| apiVersion | `26` |
| platformVersion | `26.0.0` |
| version | `26.0.0.23` |
| releaseType | `Beta1` |

В `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/build-profile.json5:9–11`: compatible `6.1.0(23)`, target `26.0.0`, runtimeOS `HarmonyOS`. Это состояние файлов на момент чтения, не проверка фактически выбранного SDK предыдущей сборки и не идентификация ОС устройства. Настройки не менялись.

Installed include root: `C:/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/native/sysroot/usr/include/`.

| Файл относительно include root | SHA-256 прочитанного файла |
| --- | --- |
| `napi/native_api.h` | `c7d241f14ecd4d3e7c9b9ae34eff1f5da40bec53686717870227285b2e97f56a` |
| `node_api.h` | `c5df241e2763173df40814838db12705c33835ce1c8d9900396eb8aa8a040a56` |
| `node_api_types.h` | `69297f804fd2680e6339ab661391ae07755cda1473a28934003aa432e0060793` |

### Закреплённые ревизии внешних источников

| ID | Репозиторий / ref при чтении | Commit |
| --- | --- | --- |
| S1/S2 | `openharmony/arkui_napi`, master | `500de075e7debd442f7893bb84118d7502d90e65` (2026-09-24) |
| R60 | тот же, OpenHarmony-6.0-Release | `6d3ed291955b92016e6135f537c5f87a02d9643e` (2025-12-15) |
| R61 | тот же, OpenHarmony-6.1-Release | `827f9e4e8cbd74e40633a17374008d076a1f7508` (2026-03-16) |
| D1/D2/D3 | `openharmony/docs`, master | `f41b9345badd47c7ab0c263344cd7f4b5a549afb` (2026-05-26) |
| U1 | `openharmony/third_party_libuv`, master | `75b173fd284d7b77a910fb9abf4c87c7ef5cdf88` (2026-09-14) |

S1 — `native_engine/native_safe_async_work.cpp`; S2 — `native_engine/native_node_api.cpp`. SHA получены через GitHub API, содержание — из OpenHarmony repositories. Совпадение версии commercial HarmonyOS SDK с названием OpenHarmony release **не устанавливает соответствия binary↔source**. Также не доказано, что именно U1 входит в сборку S1 или в установленную ОС.

## 2. Что гарантирует installed header, а что он не определяет

В `C:/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/native/sysroot/usr/include/napi/native_api.h`:

- **844–858, 861–871:** create принимает `max_queue_size`, `initial_thread_count`, `thread_finalize_data`, `thread_finalize_cb`, `context`, `call_js_cb`. Context — данные для callback; finalizer вызывается при release. Порядок finalizer относительно очистительных callbacks не задан.
- **885–901:** `data` передаётся в `call_js_cb`; перечислены `napi_ok`, `napi_invalid_arg`, `napi_queue_full`, `napi_closing`, `napi_generic_failure`. Нет обещания rollback/непринятия data для всех non-ok; нет автоматического `free/delete` payload.
- **914–928:** release прекращает использование текущим участником; abort закрывает очередь, после чего call может вернуть closing. Это не разрешение разыменовывать уже уничтоженный opaque handle и не lifetime-barrier для native threads.
- **930–958:** ref/unref касаются жизни event loop, а не владения payload или регистрации producer. S1 действительно вызывает `uv_ref/uv_unref`, отдельно от `threadCount_`. [S1:279–300][ref-unref].
- **217–241:** объявлены async cleanup hooks, `@since 11`.
- **2784–2809:** `napi_create_async_work`: execute выполняется в worker pool, complete — на main event loop. Это подходящий примитив для join вне JS-потока, но не гарантия завершения произвольного зависшего worker.

В `C:/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/native/sysroot/usr/include/node_api_types.h:13–34` определены enum release/abort, blocking/nonblocking и callback `(env, js_callback, context, data)`. Отдельного ownership-протокола эта сигнатура не содержит.

## 3. Точный разбор call: результат не равен ownership receipt

Все source-утверждения этой таблицы относятся к S1/S2, при **валидном живом TSFN**. Вызов через stale pointer уже вне допустимого контракта; проверка статуса после него не исправляет UAF.

| Результат / ветка | Что произошло в S1/S2 | Следствие для payload и caller |
| --- | --- | --- |
| `napi_ok` | `Send` сохранил pointer и `uv_async_send` вернул 0 | TSFN хранит pointer, не владеет его C++ destructor. Cleanup/delivery обязана обеспечить application. Это не подтверждение выполнения JS. |
| `napi_queue_full` | nonblocking возвращается до вставки, S1:184–192 | Для этой ветки data не принято; direct-payload owner сохраняет владение. Не переносить этот вывод на все non-ok. |
| `napi_closing`, status closing/closed, count > 0 | count уменьшается на один, return до вставки, S1:195–201 | Data не принято; caller прекращает использование. Нельзя затем вслепую делать ещё один release/acquire/call по этому handle. |
| `napi_closing`, engine generation mismatch | `ValidEngineCheck` возвращает CLOSED до вставки, S1:171–176, 204–206 | Здесь count **не уменьшается**. Один статус closing не доказывает, какая внутренняя ветка и сколько leases осталось. Всё равно прекратить обращения. |
| `napi_invalid_arg` | null func в API либо, в Send, closing/closed при count == 0 | Для просмотренных веток enqueue нет. Ненулевой stale handle статусом не валидируется. |
| `napi_generic_failure`, dead engine | `ValidEngineCheck` возвращает FAILED до вставки, S1:166–170 | Data не принято в этой ветке. Status сам по себе не отличает её от следующей. |
| `napi_generic_failure`, `uv_async_send != 0` | pointer уже вставлен в S1:208; ошибка возвращается в 212; удаления элемента нет | При условии достижения ветки pointer остаётся в очереди. Он может позже попасть в обычный либо null-env callback. Немедленный delete или повторная отправка того же owning pointer небезопасны. |

Основания: [S1:158–216][send], [S2:403–434 — полное отображение статусов][call-wrapper]. Для `acquire` и `release` wrapper, наоборот, сводит любой внутренний non-OK в `napi_generic_failure`, теряя причину: [S2:437–464][lease-wrapper].

### Насколько реальна ошибка после вставки

- S1 содержит именно такой порядок; он повторяется в [R60:208–221][r60-send] и [R61:208–220][r61-send]. Это не только новая master-ветка.
- D2 отдельно описывает generic failure при ошибке `uv_async_send`, но не обещает rollback. [D2:540–546][doc-differences].
- U1 Unix возвращает 0 на нормальных путях и при уже pending уведомлении. DFX-проверка null handle здесь не доказывает достижимости nonzero для валидного TSFN. Windows U1 имеет другой путь ошибки; он не доказывает поведение HarmonyOS device. [U1 Unix][uv-unix], [U1 Windows][uv-win].
- Поэтому корректный статус исследования: **ownership-неоднозначность не исключена опубликованным контрактом; dangerous branch подтверждён чтением source; runtime fault не воспроизведён**. Fake/harness с принудительным nonzero был бы adversarial witness для application logic, не свидетельством частоты или достижимости ошибки установленной ОС.

## 4. Release, abort, finalizer и null-env callbacks

### Обычный release

S1 сначала проверяет состояние и count, затем уменьшает count. Если count стал 0, проверяет engine и отправляет wakeup. Следовательно, **generic failure из release может произойти после изменения count**; повторить release «пока не napi_ok» — не корректный retry-протокол. [S1:235–276][release].

При нормальном drain closure происходит, когда queue пуста и count == 0. `uv_close` асинхронно вызывает `CleanUp`; `napi_ok` от release не означает, что finalizer уже исполнился. [S1:375–427][cleanup-close]. Неравны: «producer закончил», «lease отдан», «finalizer вошёл», «сам NativeSafeAsyncWork уничтожен».

### Abort

Abort уменьшает count и выставляет closing, даже если другие counted users ещё существуют. На следующем входе в `ProcessAsyncHandle` closing приводит прямо к `CloseHandles`, **без ожидания count == 0**. Удерживаемая другим worker counted lease сама по себе не защищает от такого abort. [S1:252–269][release], [S1:308–320][drain].

Abort также не отзывает уже выполняющийся callback. Внутри текущего drain snapshot статус closing не перепроверяется на каждой итерации; normal callbacks могут продолжиться после конкурентного/reentrant abort. Поэтому прекращение application delivery должно контролироваться собственными stopping/generation guards, а не только abort. [S1:341–372][drain].

### Порядок cleanup — критическое отличие от удобной модели «finalizer всегда последний»

Просмотренная последовательность S1:

1. `finalizeCallback_(engine, finalizeData, context)` через callback wrapper.
2. Для каждого оставшегося элемента — custom `callJsCallback_(nullptr, nullptr, context, data)`.
3. Удаление TSFN object.

Тот же порядок есть в [R60:398–417][r60-cleanup] и [R61:411–430][r61-cleanup], а не только в [S1:408–427][cleanup]. **Finalizer завершает normal delivery в просмотренной конструкции, но не является последним обращением к custom callback.**

Риски:

- Finalizer удаляет context, а null-env callback сначала читает `context->...`, даже только логируя поле: UAF.
- Finalizer удаляет pending payloads, а null-env callback сразу конструирует owning smart pointer из data: double-free. Проверка env после конструирования owner уже поздняя.
- Null-env callback ничего не освобождает, а никто иной не владеет pending data: leak. Поэтому «просто return при null env» безопасен только с независимым владельцем payloads.
- Default `CallJs` на null engine/function просто возвращается и не освобождает application data. [S1:56–73][default-call]. Custom `js_callback == nullptr` возможен по create API, если задан custom call_js_cb; это не то же самое, что teardown `env == nullptr`. [S2:372–384][create-wrapper].

Для null wakeups callback обязан проверять `env == nullptr` **до любого обращения к context, registry, generation, mutex или логированию их полей** и возвращаться без их использования. Data всегда null, освобождать в этом callback нечего. Сам context освобождается его настоящими владельцами, а не по числу уведомлений. Если finalizer снимает последнюю ссылку на context, оставшиеся null callbacks не должны даже пытаться восстановить из него `shared_ptr`.

## 5. Payload registry против app-owned queue + null wakeups

| Критерий | Registry owning payloads + TSFN data/token | App-owned queue + TSFN data=nullptr |
| --- | --- | --- |
| Generic failure после возможной вставки | Нельзя удалять entry/token по одному status. Нужна сохранность до callback либо terminal reclamation. | Payload остаётся в своей очереди независимо от результата wake. Нет queued dangling payload pointer. |
| Callback успел раньше возврата call | Нужен зарегистрированный owner до call и атомарный claim; sender больше не трогает claimed object. | Queue item передаётся consumer под собственным ownership-протоколом; sender не трогает item после publish. |
| Registry cleanup в finalizer | Null callbacks могут ещё не прийти. Нужен early null-env return плюс централизованная очистка, либо более долгоживущий control block. | Finalizer может снять TSFN-owner очереди; trailing null callbacks ничего в ней не читают. Другие owners защищают ещё работающий native код. |
| ABA и повторный callback | Raw address как key опасен при reuse. Нужны stable tokens/generation, tombstones либо запрет reuse до конца эпохи. Membership check без защиты ABA недостаточен. | Старое уведомление не содержит identity payload. Избыточные wakeups допустимы: drain пустой очереди ничего не делает. Нужна изоляция очередей между session epochs. |
| Непришедший callback | Pending entry удерживается; terminal sweep нужен и для случаев, не принятых до ошибки. | Данные остаются у application; нужен независимый recovery/stop path, иначе очередь может застрять. |
| Сложность доказательства | Состояния submitting/claimed/ambiguous/finalized, токены, exactly-once и lifetime registry. | Queue ownership, wake-state без lost wakeup, lifecycle context/producer и bounded stop. |

**Registry не запрещён.** Он может быть безопасным, если entries/tokens не освобождаются при ambiguous error, claim синхронизирован, null-env путь не обращается к удалённому registry, finalizer sweep не конкурирует с producers и исключён ABA. Но простая замена `delete payload` на `pending.erase(pointer)` не доказывает ни один из этих пунктов.

**Выбор для узкого reliability-среза — app-owned queue (C-design).** Он устраняет передачу owning payload pointer в неоднозначный NAPI канал. При этом:

- Application queue хранит owning объекты; нормальный callback извлекает ownership, а stop/finalizer освобождает невыданное согласно явной политике discard/drain. Нельзя одновременно держать второго raw-owner у producer.
- TSFN `data == nullptr` допустим в просмотренном wrapper: проверяется func, data передаётся без запрета null. Custom callback нужен обязательно, если требуется drain native queue. [S2:403–412][call-wrapper].
- Очередь и dispatch-state принадлежат конкретной session/epoch, а не глобальному указателю «текущий клиент». Старое уведомление никогда не обслуживает новую session.
- Wake — не сообщение и не receipt. Нужен протокол publish/pending/drain/re-arm без lost wakeup. On non-ok нельзя навсегда оставлять pending=true, предполагая будущий callback; но и слепой сброс без синхронизации с параллельным drain небезопасен.
- При ambiguous wake можно получить ноль, один или несколько будущих **попыток уведомления** при retry; каждая лишь проверяет ту же очередь. Это не разрешение повторно publish payload и не обещание exactly-once внешнего эффекта.
- Producer использует nonblocking wake. Очередь должна иметь собственный предел items/bytes и политику overload; TSFN queue не ограничивает память app-owned payloads. Для UI responsiveness drain нужен ограниченный batch/time budget и re-arm.
- Если последний wake отказал и producers больше ничего не публикуют, liveness не восстановится сама. Нужен независимый owner-thread recovery/controlled stop либо ограниченный retry при доказанно живом handle. Для closing/разрушенного env retry TSFN запрещён. UI stop-completion не должен зависеть от повреждённого wake-канала.

Это не попытка починить неизвестную runtime ABI или обеспечить delivery после уничтожения env. Queue решает ownership; lifecycle и liveness остаются отдельными обязательствами.

## 6. Минимальный безопасный asynchronous stop: контракт для parent

Ниже — требования, не implementation и не утверждение о текущем production. Рассматривается управляемый stop при ещё живом owner env; teardown описан отдельно.

1. **Закрыть admission синхронно.** Под общей синхронизацией отметить session stopping, запретить новых producers/publish/acquire и последующую JS delivery этой epoch. Повторный stop присоединяется к той же stop operation; не создаёт второй terminal release.
2. **Разбудить native ожидания cancellation-сигналом.** Worker не должен для выхода ждать JS callback, новый TSFN wake или mutex, удерживаемый owner thread до complete. Использовать bounded/cancellable native wait, где это возможно; timeout — ошибка/незавершённый stop, а не разрешение разрушить живой state.
3. **Дождаться quiescence вне JS thread.** Join/reaping всех workers и ожидание всех in-flight submitters/borrowers выполняются background coordinator/async-work execute. Сам `stop()` и finalizer не делают блокирующий join. Не заменять join на detach с доступом к module/context после их уничтожения.
4. **Сохранить TSFN до этого барьера.** Учёт initial_thread_count/acquire/release явный: отдельная coordinator anchor lease и известные producer leases; каждый штатный producer relinquishes свою lease ровно один раз. Anchor остаётся до конца всех NAPI обращений producers и их join. Ранее наблюдённый closing нельзя «компенсировать» ещё одним release: переход должен уйти в error/teardown path с отдельным учётом.
5. **Только после барьера завершить TSFN.** Для штатного пути предпочтителен обычный final release: stopping callback отбрасывает/очищает app queue по политике, harmless null notifications могут дренироваться. Abort нужен только при явной discard-policy и также после quiescence; это не способ остановить ещё использующие TSFN threads. После передачи последней lease не обращаться к opaque handle, даже если release вернул non-ok.
6. **Не освобождать context по факту return из release.** У context/queue отдельные owners: coordinator, workers/operations и TSFN finalizer-owner. Finalizer снимает только своё владение; trailing null-env callback возвращается до context access. Активные native операции не зависят от жизни JS object.
7. **Разделить completion milestones.** `producers joined`, `application queue disposed`, `finalizer entered/observed` — разные события. Если API обещает полный logical stop, оно должно определить и дождаться нужных из них. Finalizer вызывается до хвостовых null callbacks и `delete this`; нельзя утверждать, что весь runtime handle уже физически уничтожен в момент входа finalizer. Не держать последний release за ожиданием finalizer — это цикл.
8. **Не retry terminal API вслепую.** Release generic failure может уже изменить count. Если finalizer не приходит, не делать повторный release и не удалять потенциально используемый context. Зафиксировать incomplete teardown и удержать/quarantine непроверенно освобождённый owner с ограничением на новые sessions, вместо бесконечного накопления или UAF. Утечка при такой ошибке не называется успешным stop.

Installed `napi_create_async_work` задаёт worker/complete thread split, но parent должен проверить отказ create/queue, отмену до execute и недоставленный complete. Если execute не запускался, producers не считаются joined. Обычная остановка не должна ждать completion через ту TSFN, которую сама уничтожает.

### Env teardown — отдельный путь, не «ещё один stop через Promise»

D2 прямо говорит: create TSFN сам не регистрирует cleanup hook. [D2:524–546][doc-differences]. Нельзя полагаться на GC/finalizer как единственный сигнал остановки producers.

Installed header объявляет `napi_add_async_cleanup_hook`; D3 описывает его для asynchronous cleanup. В S2 async hook имеет self-ownership, увеличивает waiting-request counter при запуске и уменьшает его через completion; удаление started cleanup handle вызывает done callback. Это самостоятельный handshake, а не разрешение произвольно использовать JS/NAPI из background. [S2:244–368][async-cleanup-source], [D3:173–255][doc-cleanup].

Для teardown нужен заранее зарегистрированный native cleanup owner: закрыть admission, отменить ожидания, дождаться quiescence без JS dependency, закончить cleanup handshake на допустимом потоке. Не предполагать работоспособность Promise/обычного JS complete после начала teardown. Exact ordering относительно TSFN finalizer и unload, разрешённость конкретных NAPI операций и гарантированная доставка completion на установленном binary здесь **не подтверждены**. Hook нужно проектировать/проверять отдельно; перенос обычного async-work stop в teardown без этой проверки не является решением.

## 7. Неизвестное и необходимые свидетельства принятия

**Не установлено:**

- Runtime build ID и соответствующий commit/patchset `libace_napi`/libuv установленной ОС; SDK headers этого не дают.
- Достижимость post-insertion send failure при валидном handle на этом binary, включая platform-specific libuv changes.
- Точный порядок cleanup при env destruction и module unload на binary; гарантированное выполнение finalizer при failed wake/release.
- Ownership, фактический thread count, bounded receive/stop и account generation текущего native production: намеренно оставлены parent.
- Реальные memory/time bounds, отсутствие deadlock/leak и UI responsiveness: source inspection не заменяет runtime witness.

**Минимальный список контрактных witnesses для parent (здесь не реализованы/не запущены):**

| Сценарий | Что должно быть наблюдаемо |
| --- | --- |
| Error до insertion / error после insertion | Payload освобождается ровно один раз в обоих расписаниях, при отсутствии callback и при позднем callback. Результат не зависит от универсального `non-ok means rejected`. |
| Callback выигрывает гонку с возвратом call | Sender не разыменовывает уже потреблённый payload; queue ownership transfer однозначен. |
| Finalizer до null-env callbacks; обратный порядок | Оба порядка не вызывают context access после free, double-free или потерю owning payload. Это adversarial portability check, не утверждение, что оба порядка встречаются на binary. |
| Abort/closing при активном producer | Normal design не допускает abort до quiescence; error path прекращает обращения к handle. Проверяется реальный порядок действий, а не только конечный счётчик. |
| Stop во время JS drain и повторный/reentrant stop | Нет новой delivery старой epoch, JS thread не ждёт join, terminal release не дублируется. |
| Единственный wake отказал, больше publish нет | Независимый recovery/stop завершает application ownership; queue не остаётся без обслуживания навсегда. |
| Stop scheduling failure/cancel до execute | Нет ложного «joined», удаления живого context и fallback на блокирующий join в JS. |
| Последний release non-ok / finalizer не доставлен | Нет retry-decrement и premature free; состояние явно incomplete, новые epochs ограничены. |
| Env cleanup и session restart | Нет JS dependency при teardown и смешения queues/owners разных epochs. |

Binary acceptance требует отдельного runtime trace с идентификацией ОС, а не сравнения с движущимся master. В этой работе такой gate сознательно не проходился.

## 8. Отвергнутые упрощения

- **`non-ok → delete` для всех статусов:** нет header guarantee, source содержит post-insertion failure без rollback. Пересмотреть только при доказанном более сильном контракте конкретной поддерживаемой ABI.
- **«Generic failure обязательно случается после enqueue»:** неверно; есть pre-insertion dead-env path, а достижимость post-insertion error в Unix не установлена.
- **«Registry сам решает lifetime»:** нет; нужны stable identity, synchronized claim, terminal sweep и null-env guard до доступа к registry.
- **«Finalizer — последний callback»:** опровергнуто S1/R60/R61. Можно освобождать context там только если trailing callbacks его не используют и других owners уже нет либо они независимы.
- **Abort сначала, join потом:** нарушает verified source lifetime. Использовать app stopping/cancellation, а TSFN terminal action — после quiescence.
- **«Async stop» через blocking join в finalizer/JS completion:** переносит freeze, а не устраняет его. Finalizer — notification/release ownership, не worker reaper.
- **Null wakeups без backpressure/recovery:** устраняют queued raw-pointer риск, но не lost wakeups, переполнение и teardown races.

## Проверка самого review

Installed header hashes и pinned source ranges получены в этой сессии; ключевые ветки перепроверены прямыми пронумерованными excerpt, а не только поисковыми snippets. Проверены две release-ревизии и контрпример к предположению о достижимости ошибки (`uv_async_send` Unix). Рекомендация имеет класс C-design. Native runtime/tests/build результата этот документ не заявляет.

[send]: https://github.com/openharmony/arkui_napi/blob/500de075e7debd442f7893bb84118d7502d90e65/native_engine/native_safe_async_work.cpp#L158-L216
[release]: https://github.com/openharmony/arkui_napi/blob/500de075e7debd442f7893bb84118d7502d90e65/native_engine/native_safe_async_work.cpp#L235-L276
[ref-unref]: https://github.com/openharmony/arkui_napi/blob/500de075e7debd442f7893bb84118d7502d90e65/native_engine/native_safe_async_work.cpp#L279-L300
[drain]: https://github.com/openharmony/arkui_napi/blob/500de075e7debd442f7893bb84118d7502d90e65/native_engine/native_safe_async_work.cpp#L308-L384
[cleanup-close]: https://github.com/openharmony/arkui_napi/blob/500de075e7debd442f7893bb84118d7502d90e65/native_engine/native_safe_async_work.cpp#L375-L427
[cleanup]: https://github.com/openharmony/arkui_napi/blob/500de075e7debd442f7893bb84118d7502d90e65/native_engine/native_safe_async_work.cpp#L408-L427
[default-call]: https://github.com/openharmony/arkui_napi/blob/500de075e7debd442f7893bb84118d7502d90e65/native_engine/native_safe_async_work.cpp#L56-L73
[create-wrapper]: https://github.com/openharmony/arkui_napi/blob/500de075e7debd442f7893bb84118d7502d90e65/native_engine/native_node_api.cpp#L372-L384
[call-wrapper]: https://github.com/openharmony/arkui_napi/blob/500de075e7debd442f7893bb84118d7502d90e65/native_engine/native_node_api.cpp#L403-L434
[lease-wrapper]: https://github.com/openharmony/arkui_napi/blob/500de075e7debd442f7893bb84118d7502d90e65/native_engine/native_node_api.cpp#L437-L464
[async-cleanup-source]: https://github.com/openharmony/arkui_napi/blob/500de075e7debd442f7893bb84118d7502d90e65/native_engine/native_node_api.cpp#L244-L368
[r60-send]: https://github.com/openharmony/arkui_napi/blob/6d3ed291955b92016e6135f537c5f87a02d9643e/native_engine/native_safe_async_work.cpp#L208-L221
[r60-cleanup]: https://github.com/openharmony/arkui_napi/blob/6d3ed291955b92016e6135f537c5f87a02d9643e/native_engine/native_safe_async_work.cpp#L398-L417
[r61-send]: https://github.com/openharmony/arkui_napi/blob/827f9e4e8cbd74e40633a17374008d076a1f7508/native_engine/native_safe_async_work.cpp#L208-L220
[r61-cleanup]: https://github.com/openharmony/arkui_napi/blob/827f9e4e8cbd74e40633a17374008d076a1f7508/native_engine/native_safe_async_work.cpp#L411-L430
[doc-abort]: https://github.com/openharmony/docs/blob/f41b9345badd47c7ab0c263344cd7f4b5a549afb/en/application-dev/napi/napi-data-types-interfaces.md#L75-L97
[doc-differences]: https://github.com/openharmony/docs/blob/f41b9345badd47c7ab0c263344cd7f4b5a549afb/en/application-dev/reference/native-lib/napi.md#L524-L566
[doc-cleanup]: https://github.com/openharmony/docs/blob/f41b9345badd47c7ab0c263344cd7f4b5a549afb/en/application-dev/napi/use-napi-about-cleanuphook.md#L173-L255
[uv-unix]: https://github.com/openharmony/third_party_libuv/blob/75b173fd284d7b77a910fb9abf4c87c7ef5cdf88/src/unix/async.c#L110-L138
[uv-win]: https://github.com/openharmony/third_party_libuv/blob/75b173fd284d7b77a910fb9abf4c87c7ef5cdf88/src/win/async.c#L84-L100

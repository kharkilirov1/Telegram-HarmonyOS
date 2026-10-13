# Native delivery: безопасное владение payload — 28 сентября 2026

## Результат и граница

В actual-source host-сценарии отказа enqueue **до вставки** устранены потеря первого batch и забытые C++ allocations. TSFN теперь несёт только `nullptr`-уведомления; строки принадлежат отдельной очереди текущего receive loop. Результат N-API больше не используется как неявная передача владения payload.

Parent лично повторил один и тот же `reject-before` до/после: untouched **8 PASS / 3 FAIL → 12 PASS / 0 FAIL**, heap-oracle **10 PASS / 4 FAIL → 15 PASS / 0 FAIL**. В откалиброванной host-фикстуре после join/finalize/delivery: **2 allocations / 8263 bytes → 0 / 0**. Это не измерение памяти полного TDLib или устройства.

Финальный gate: **58/58 host suites, 38/38 PowerShell-проверок + Bash smoke; обе последовательные SDK-сборки PASS; 782 source/test hashes неизменны во время итогового прогона.** Независимое ревью не обнаружило новых дефектов в проверенном live-env delivery scope. На устройстве новая сборка не проверялась.

Для исключения дрейфа тестов parent также повторил RED на архивном неизменённом native source `5a00f535…` уже с финальным fixture: те же **8/3**, **10/4**, **2 allocations / 8263 bytes**. Подменялся только source read в отдельном test process; production-файл на диске не откатывался.

## Что изменено

- [tdlib_napi.cpp](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/cpp/tdlib_napi.cpp): `ReceiveDelivery` с per-loop очередью строк и shared ownership между producer, TSFN finalizer и выполняющимся callback. Не используется глобальная current queue для старых callbacks.
- `CallJs` проверяет null env/callback **до** чтения context; finalizer может уже уничтожить holder. Один callback извлекает максимум один batch и освобождает queue mutex перед вызовом JS. Частично выполненный JS batch не повторяется при ошибке.
- `NotifyReceiveBatch` повторяет только безопасное `nullptr`-уведомление с паузой 50 ms, не читая следующие TDLib responses во время отказа. Это одинаково безопасно для rejection до вставки и неоднозначного non-ok после вставки; лишний wake на пустой очереди безвреден.
- При closing/invalid handle producer прекращает обращения к нему, не делает слепой дополнительный release и требует прежнего stop/join barrier перед restart. Это не доказательство корректности всей процедуры уничтожения env.
- [Новый runner](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-native-delivery.cjs) / [C++ fixture](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/native-bridge/delivery_test.cpp): untouched production source, отдельный откалиброванный heap-oracle, управляемые return statuses и ordering. Нет подмены production delivery логики.
- [Existing native fixture](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/native-bridge/bridge_test.cpp) адаптирован к context-owned queue: callbacks и finalizer проверяются отдельно. [Host header](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/native-bridge/include/napi/native_api.h) использует точную typed `napi_finalize` сигнатуру вместо старого `void*`; stop/constructor regression assertions сохранены.

## Почему не delete-on-error

Installed header перечисляет статусы, но не обещает rollback payload для любого non-ok. Предыдущее [исследование TSFN](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-28-native-lifecycle-contract.md) обнаружило условную source-ветку с вставкой до возврата ошибки. Поэтому новый fixture явно моделирует **обе** стороны границы, включая исполнение callback до возврата rejected call. Эти adversarial interleavings проверяют application ownership, а не доказывают достижимость/частоту ошибок установленной ОС.

Parent отдельно прочитал pinned [NativeSafeAsyncWork](https://github.com/openharmony/arkui_napi/blob/500de075e7debd442f7893bb84118d7502d90e65/native_engine/native_safe_async_work.cpp): `Send` добавляет data до проверки результата wakeup, а `ProcessAsyncHandle` передаёт custom callback извлечённый элемент без проверки `data != nullptr`. Поэтому null-wakeup путь обоснован не только нашим fake. Это подтверждение указанного source commit, не соответствия установленного binary этому commit.

## Итоговая проверка

| Witness | Результат |
|---|---|
| Delivery: 14 сценариев, untouched source | 162/162 checks, 14/14 scenarios PASS |
| Те же 14 сценариев с heap oracle | 204/204 checks; во всех `live=0, bytes=0` |
| Delivery negative controls | 12/12: 10 assertion RED + 2 ожидаемых poisoned-context access violations в изолированных test processes |
| Existing bridge / thread-constructor injection | 32/32 и 34/34; 5/5 mutation controls |
| Gateway / stop / client retirement / runtime / queued Closed | 45/45; 11/11+4; 24/24+8; 13/13+7; 13/13+3 |
| Client manager audit --strict | 10 controls / 0 findings, exit 0 |
| Полный host / PowerShell / Bash gate | 58/58; 38/38; PASS |
| main / ohosTest assembleHap, последовательно | exit 0 / exit 0; 19.930 s / 17.052 s |
| Source/test snapshot | 782/782 hashes совпали |

Матрица включает pre/post-insertion failure, callback до возврата non-ok, постоянный отказ без read-ahead/hot spin, queue-full, closing/invalid handle, finalizer-before-null callback, conversion/JS errors и old/new loop isolation. **JS reentry проверен исполнением:** producer отправляет следующий wakeup, пока JS callback приостановлен; reentrant stop остаётся pending до main completion, restart до него отклонён. Мутация удержания queue mutex через JS даёт конкретный RED, а не только source grep.

Reviewer независимо исполнил первоначальные 22 delivery variants и existing bridge/controls на том же production SHA; последующие дополнительные cases и все 12 controls parent повторил в окончательном gate. Полные outputs, fingerprints и границы: [evidence JSON](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-28-native-delivery-evidence.json).

### Сборка действительно содержит новый native path

- Native source SHA256: `be9988f5012213cdb9e04db373abc473b1e8a9344d53d5f4590860e81012684f`.
- Упакованный `libs/x86_64/libtdlib_napi.so`: `baa9cbf4a0bc8547c56c461fb32d042413c6b4197d3bfb946e874956073c3337`; отличается от прежнего `3707383b…`, содержит новые queue-allocation/retry-wakeup строки и прежний async-stop marker.
- [Main HAP](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/build/default/outputs/default/entry-default-unsigned.hap): `908fb0662654dca2487003fdb4a61641612dca9fbac047131dab7fc2d97aff97`.
- [ohosTest HAP](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/build/default/outputs/ohosTest/entry-ohosTest-unsigned.hap): `3942e003f3aa764fadbc78664095e742c3c078525a2dd27322cc86b1d957c001`.

ArkTS bytecode обоих HAP совпадает с предыдущим client-retirement срезом: в production менялся только native C++. Сборки unsigned; signingConfigs отсутствует, имеющиеся SDK warnings не объявляются устранёнными. Это packaging/compile witness, не runtime-исполнение нового `.so`.

Для узкого отката сохранён [native diff](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-28-native-delivery.patch) относительно исходника этого среза, а не старого Git HEAD. `git apply --check --reverse --ignore-space-change` прошёл; обратный patch **не применялся**. Только пять source/test файлов отличаются от предыдущего 780-file snapshot: native C++, existing fixture/header и два новых тестовых файла.

## Открытые требования

- Env teardown / lifetime opaque TSFN handle остаётся отдельным integration gate. Подготовлен [sidecar-контракт cleanup](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-28-native-env-cleanup-contract.md); его исходные предпосылки должны быть проверены для фактического runtime перед изменением teardown. Один finalizer или async hook не объявляется барьером producer.
- Native queue по-прежнему не имеет лимита при нормально принимаемых уведомлениях: backpressure для медленного ArkTS и queue-watermark stress не проверены. При постоянном отказе retry не читает TDLib вперёд; это другой, проверяемый случай.
- Прежняя политика ошибок конвертации/JS сохранена: неудавшийся batch удаляется, частично выполненный JS не повторяется. Проверка at-most-once не является гарантией доставки всех TDLib updates при N-API marshalling/JS exceptions; recovery после таких ошибок требует отдельного контракта.
- Нет device/SDK-runtime stress, arm64 release, полного clean-checkout или сравнительного iOS-прогона. Client retirement, dialog open/close count, account/media acceptance и UI parity не закрываются этим host-тестом.
- Не устанавливались HAP, не менялись аккаунт/эмуляторные данные, не выполнялись mic/messages/logout, commit/push, публикация или глобальная настройка.

Цель production parity остаётся активной. Откат возможен только узким reviewed diff поверх прежнего dirty дерева, не reset всего файла.

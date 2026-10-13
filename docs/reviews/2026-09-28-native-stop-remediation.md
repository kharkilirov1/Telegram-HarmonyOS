# Асинхронная остановка TDLib — 28 сентября 2026

## Результат

**Блокирующий join убран из ArkTS-вызова stop.** Native `stopReceiveLoop()` возвращает `Promise<void>` и передаёт join в NAPI async work. Gateway ждёт этот барьер при destroy и откате неудачного запуска. Пока stop не завершился, новый запуск запрещён; при ошибке остаётся возможность повторить остановку.

Это source/host/compile-срез надёжности, **не доказательство отсутствия зависаний на устройстве и не завершение проекта**. Порядок «надёжность → существующий UI → функции → публикация» сохранён. Новый HAP не устанавливался, Telegram-аккаунт и сохранённая сессия не затрагивались.

## Что изменено

- [Native bridge](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/cpp/tdlib_napi.cpp): отдельный владелец перемещённого `std::thread`; один async work для concurrent/late stop; Stopped публикуется только в completion после join. Resource/work creation failure сохраняет Running; queue failure и cancellation возвращают владение потоком, сохраняя Stopping для retry. Start во время остановки или из другого env отклоняется. Ошибка конструктора потока освобождает TSFN lease и откатывает состояние, не выпуская C++ exception наружу.
- [Native header](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/cpp/tdlib_napi.h) и [ArkTS declaration](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/types/libtdlib_napi.d.ts): документирован Promise-контракт.
- [Gateway](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/infra/td/gateway/TdGateway.ets): shared shutdown Promise публикуется до reentrant callbacks; старые callbacks/requests отзываются до native await. Успех stop разрешает idle; rejection оставляет destroying и запрещает create/start. Повторный destroy повторяет stop, а не close. Existing graceful close/Closed observer сохранён.
- [Native runner](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-native-bridge.cjs), [C++ fixture](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/native-bridge/bridge_test.cpp), [NAPI boundary](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/native-bridge/include/napi/native_api.h): контролируемая задержка receive, отдельные compile untouched source и thread-constructor injection, opt-in negative controls.
- [ETS stop tests](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-td-stop-barrier.cjs): реальный Gateway/Dispatcher/Runtime с заменённой NAPI-границей; четыре in-memory mutations, не подмена production methods.
- [Client lifetime audit](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/audit-td-client-lifetime.cjs): отдельная диагностика незакрытых client IDs. Преднамеренно **не** входит в зелёный `test-*.cjs` discovery. `--strict` остаётся RED до исправления этих дефектов.

AppCoreRuntime не изменён в этом срезе: существующее ожидание gateway.destroy уже передаёт новый барьер до restart.

## Доказательства и границы

До native-правки тот же контролируемый receive gate дал **15 PASS / 5 FAIL, exit 1**: stop возвращался лишь после открытия gate, Promise/concurrent wait/busy restart/completion barrier отсутствовали. Это наблюдение parent, не предположение по коду.

| Проверка | Результат |
|---|---|
| Untouched production C++ + NAPI/TDLib host fixtures | 32/32 PASS |
| Тот же source с единственной подменой конструктора потока | 34/34 PASS |
| Native negative controls | 5/5 пойманы: соответственно 3/1/2/2/1 failing checks |
| ETS stop/restart integration | 11/11 PASS; 4/4 mutations дают ожидаемые behavioral assertions |
| Все host suites, окончательный прогон | 54/54 PASS, exit 0; lifetime audit исключён из test-discovery |
| PowerShell contract suites + UI smoke | 38/38 PASS; Bash UI smoke PASS |
| Forced serial main / ohosTest assembleHap | PASS / PASS, exit 0 |
| Device / actual SDK lifecycle | Не выполнено |

Финальный strict client audit: **6 controls / 4 residual findings, exit 1**. Их названия: startup-failure-orphans-manager-IDs, actual-AppCoreRuntime-init-cleanup-does-not-rescue-ID, close-Ok-without-Closed-discards-owner, close-timeout-discards-owner. Отдельный RED не скрыт зелёным aggregate.

777 hashes файлов `entry/src` и `scripts` совпали до/после финальных host/negative-control прогонов. Между сборками и финальными проверками production files не менялись; обновлялись только host fixtures/diagnostic script. Команды, выводы, hashes и packaged markers сохранены в [evidence JSON](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-28-native-stop-evidence.json).

Native fixtures проверяют реальный production control flow, но **не эмулируют реализацию HarmonyOS NAPI**, не доказывают достижимость каждого injected error и не измеряют пользовательскую задержку. Constructor failure создан boundary injection, не реальным истощением OS threads. Gate имеет watchdog; успех требует возврата stop до освобождения заблокированного receive, а не попадания в произвольный порог миллисекунд.

Независимый reviewer Mencius проверил native/gateway/test boundary и лично повторил ETS11/11: подтверждённых регрессий в этом scope не нашёл. SDK researcher Erdos отдельно исследовал lifetime-контракт; Ampere выполнил ETS integration и client audit. Parent повторяет финальные проверки; чужие результаты не заменяют их.

### Сборка действительно содержит новый путь

В основном HAP `libs/x86_64/libtdlib_napi.so` содержит **все четыре** маркера: `TDLibReceiveStop`, `napi_queue_async_work`, `napi_create_promise`, `ERR_TDLIB_RECEIVE_BUSY`. Это свидетельство включения нового native-пути, а не только зелёного compile. В ohosTest HAP отдельной native-библиотеки нет; его сборка не считается исполнением NAPI или Hypium suites.

- Main HAP SHA-256: `25964e1202aa5026a53c9a7ff930437767d6616a332969733329055ecfa34dfa`.
- Test HAP SHA-256: `91a2906b9d7513f463c8cc980f227e7f27d0c5bf47f3d5f65e03f826bddfc9de`.
- Packaged native SHA-256: `3707383b67d7c22e456674e8f13530e6affa27216b4c04ba8721ab506dce2508`.

Собран текущий x86_64 debug target. Это не arm64/release/clean-checkout validation. Предупреждения сборки, включая отсутствующий previewer `icudtl.dat`, не приравниваются к runtime-успеху.

## Что остаётся неисправленным

1. **Lifetime client ID.** Audit исполняет дословно извлечённый threaded `ClientManager::Impl` с actor/scheduler fixtures. Три неудачных startup оставляют три manager slots без созданных TD actors. Close timeout также позволяет gateway забыть ID до подтверждённого Closed. Штатные Ok→Closed и Closed→Ok освобождают ID. Это retention/ownership witness, не измерение утечки памяти полного TDLib. Подробности: [client lifetime report](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-28-td-client-lifetime.md).
2. **TSFN enqueue и env teardown.** Stop Promise доказывает join producer, **не TSFN finalization и не полное осушение callback queue**. Для gateway старые callbacks отзываются generation guard. Enqueue non-ok нельзя безусловно считать непринятым payload: просмотренный upstream имеет post-insertion error path. Его достижимость в установленном binary не доказана. Finalizer-before-null-env-callbacks также требует отдельного решения ownership: [SDK report](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-28-native-lifecycle-contract.md).
3. **`open_count` не число clients.** В локальном TDLib это поле dialog для openChat/closeChat; client audit не закрывает баланс этих операций. Несуществующий `getOption("open_count")` не годится как метрика.
4. **Device/UI/publication gates** и ранее открытые функциональные вопросы сохраняются. Не выполнялись install/reset/logout, отправка сообщений, микрофон, commit/push или публикация.

Следующий обоснованный reliability-срез — сохранение owned/retiring client IDs и доведение close/drain до подтверждённого Closed, включая startup failure и timeout; отдельно безопасное TSFN enqueue/env teardown и баланс dialog open/close. Недостаточно просто остановить consumer или получить `close → Ok`.

## Воспроизведение

Из `C:/Users/Kharki/Desktop/Telegram-HarmonyOS`:

```text
node scripts/test-native-bridge.cjs --negative-controls
node scripts/test-td-stop-barrier.cjs --negative-controls
node scripts/run-host-tests.cjs
node scripts/audit-td-client-lifetime.cjs --strict
```

Последняя команда намеренно возвращает exit 1 при незакрытых lifetime findings. Node должен быть >=24: `process.execPath` внутри context-mode может указывать на Bun; первоначальный запуск fixtures через него упал на отсутствующем `stripTypeScriptTypes`. Повтор через проверенный `node v24.12.0` исполнил actual ETS tests. Это ошибка выбора host runtime, не ошибка приложения.

SDK grounding: `harmonyos_docs` → Asynchronous Task Development Using Node-API; installed `native_api.h` (create Promise/async work/queue/cancel). Pinned upstream и оговорки binary equivalence сохранены в SDK report. Локальные HarmonyOS examples/codelabs не дали подходящего C++ async-work примера; iOS visual reference к этому не-UI срезу неприменим.

Работа велась в существующем dirty `dev@faf66b3e066afccdbbfa36442eb9122073f509b2`; index не менялся. Откат — только узкого согласованного patch, не `git restore/reset` всего файла/дерева: там остаётся предыдущая проверенная работа. Полная цель остаётся активной.

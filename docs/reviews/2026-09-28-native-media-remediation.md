# Надёжность native bridge и записи голоса — 28 сентября 2026

## Итог

**Исправлены два узких участка: отказ запуска native receive loop и гонки владения ресурсами записи голоса.** Финальная проверка: **46/46 host-наборов, 38/38 PowerShell-проверок, Bash smoke и обе последовательные forced HAP-сборки — PASS**.

**Приёмка новой сборки на устройстве остаётся открытой.** Эмулятор запущен, старая установленная версия показывает список чатов с сохранённой Telegram-сессией. Новый HAP не установлен: запрошено разрешение на обновление с риском повторного входа, ответа пока нет. Это не подтверждение работы исправлений на устройстве.

Этот срез продолжает фазу надёжности из [PRODUCTION_PARITY_PLAN](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/TASKS/PRODUCTION_PARITY_PLAN.md). Общая цель проекта, UI parity и публикация не завершены. Вопрос «сначала фичи, потом полировка» не принят как изменение дорожной карты.

## 1. Что изменено

### Native bridge

В [tdlib_napi.cpp](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/cpp/tdlib_napi.cpp):

- Ошибка создания имени ресурса или TSFN возвращает состояние в Stopped и бросает ERR_TDLIB_RECEIVE_START. Running не публикуется, TDLib receive не запускается без callback; повторный запуск проверен.
- Принятый callback payload сразу получает владельца через unique_ptr: освобождается и при null env/callback, и при неудачной подготовке JS-аргумента.
- Проверяются результаты создания строки/receiver. При ошибке JS не вызывается с неготовыми аргументами; ошибка вызова не вызывает повторную доставку и не заменяет pending JS exception.
- Публичный ETS/native интерфейс не менялся.

Это **не полное исправление native lifecycle**: enqueue ownership, stop/join, complete environment teardown, thread-constructor failure и TDLib open_count остаются вне этого patch.

### Запись голоса

В [ChatVoiceRecordingController.ets](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/ChatVoiceRecordingController.ets):

- Recorder, FD, путь и releasePromise принадлежат конкретной операции. Поздний результат A после cancel A → begin B не перехватывает и не освобождает ресурсы B.
- Незавершённый startup держит ресурсы локально; перед prepare и после async стадий проверяется актуальность операции. Неопубликованные ресурсы освобождаются в finally.
- Cleanup захватывает свои recorder/FD/path до ожиданий; конкурирующие cancel/dispose присоединяются к одному освобождению.
- Завершение старой операции не сбрасывает timer/UI новой. Ошибка startup публикуется после cleanup.
- Уникальный суффикс файла общий для загруженного модуля: два контроллера с одинаковым временем не получают один путь.

Ранее существовавший voice/mediaKind guard сохранён и **не приписывается этому срезу**. Изоляция имён между процессами/перезапусками, реальные отказы SDK и не завершающиеся SDK-вызовы не доказаны.

## 2. Доказательства до/после

| Проверка | До / отрицательный контроль | Финальный результат |
|---|---|---|
| Native, реальный production C++ с host NAPI/TDLib stubs | Тот же усиленный harness на HEAD: 8 PASS / 6 FAIL, exit 1 | 14/14, exit 0 |
| Native: убрать JS-аргумент | 10 PASS / 4 FAIL | Мутация отвергнута |
| Native: снять регистрацию callback | 12 PASS / 2 FAIL | Мутация отвергнута |
| Native: освободить storage без string destructor | 8 PASS / 6 FAIL | Мутация отвергнута |
| Recorder, реальный ETS controller + управляемые SDK/fs boundaries | Реконструированный pre-slice: 10 PASS / 12 FAIL, exit 1 | 22/22, exit 0 |
| Recorder, мутации ownership/cleanup/filename | 8 мутаций в памяти | 8 отвергнуты, 0 пережили проверки |
| Gateway startup failure/retry | Добавлен сценарий throw → idle/not ready → retry → доставка response | 45/45, включая существующие ETS bodies 14/14 |
| Page → voice/send/permission integration | Fixture переведён с удалённых private полей на настоящий start flow | 53/53, exit 0 |

**Ограничение baseline recorder:** это HEAD плюс ранее существовавший mediaKind/voice guard, реконструированные в памяти, а не точная копия исходного dirty checkout. Сравнение с чистым HEAD давало несовместимость старого интерфейса; такой результат не используется как доказательство этого исправления.

Host native witness действительно проводит batch из production receive thread в зарегистрированный callback, проверяет env/receiver/callback/argc/argv и точный JSON. Длинная строка проверяет освобождение и объекта, и внутреннего буфера. Это **не** проверка настоящей SDK TSFN queue/ABI.

### Независимое ревью

- Native reviewer обнаружил две реальные слабости первоначального harness: отсутствие проверки регистрации/аргумента и отсутствие контроля string buffer destructor. Тесты усилены; reviewer и основной агент повторили проверки, прежние false-green мутации стали RED. [Ревью и resolution](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-28-native-independent-review.md).
- Отдельный reviewer записи не нашёл новых blockers в проверенном ownership-slice; SDK/hardware ограничения оставлены явными. [Независимое ревью recorder](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-28-recording-independent-review.md).
- [Подробный отчёт реализации recorder](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-28-recording-ownership.md) сохраняет первоначальную RED-серию; итоговые родительские проверки и реконструированный baseline приведены выше.
- Промежуточный общий прогон имел 45/46: два happy-path случая voice fixture обращались к удалённым private полям. Fixture исправлен на публичный page/controller start, ожидаемая отправка не ослаблена. Финал — 46/46.

## 3. Общая проверка и сборки

| Проверка | Наблюдаемый результат |
|---|---|
| Host runner | 46 suites, 46 passed, 0 failed; exit 0 |
| PowerShell | 37 test scripts + smoke: 38/38; exit 0 |
| Bash smoke | tg_ui shell smoke checks passed; exit 0 |
| main, no-incremental / no-daemon | CompileArkTS 12.301 s; BUILD SUCCESSFUL 21.278 s; exit 0 |
| ohosTest, затем отдельно | OhosTestCompileArkTS 9.293 s; BUILD SUCCESSFUL 18.008 s; exit 0 |
| Стабильность входов | 606/606 зафиксированных source/test/resource hashes совпали после проверок и сборок |
| Whitespace с учётом существующего CRLF | git -c core.whitespace=cr-at-eol diff --check: exit 0 |

Обе сборки **unsigned**: signingConfigs не настроен. Предупреждения о NAPI declarations, throwable APIs, MICROPHONE и отсутствующем previewer ICU не превращены в «warning-free». ohosTest HAP собран, но тесты на устройстве не запускались. Локальный forced build не доказывает воспроизводимость clean clone или remote CI.

Обычный git diff --check вернул exit 1: C++ файл уже был CRLF в HEAD и остался CRLF, а Git трактует CR добавленных строк как trailing whitespace. Пробелов/табов перед переносом в этом файле не найдено. Git config не менялся, массовой нормализации line endings не было.

### Артефакты

- [Main unsigned HAP](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/build/default/outputs/default/entry-default-unsigned.hap) — 86 502 844 bytes; SHA-256:
  e2a3d7054f984a7078cc969abecbb89aa77c4f174aacc4a2960a5f27dcd2520a
- [ohosTest unsigned HAP](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/build/default/outputs/ohosTest/entry-ohosTest-unsigned.hap) — 6 613 325 bytes; SHA-256:
  cc26049259a422d7dc12e38953509331ca93f07664344d70ff4339fef9f3923a
- Внутри main HAP проверен libs/x86_64/libtdlib_napi.so: 86 424 bytes; SHA-256:
  fc43a4bbc9b3ca79f32474784600c3d108ebfe152be0bb84862148a0da1c107c
  Новые строки Cannot create TDLib receive callback, Cannot create TDLib receive resource name и TDLib callback string creation failed присутствуют. Значит изменённый native-код действительно попал в пакет; один BUILD SUCCESSFUL такого доказательства не давал.

## 4. Эмулятор: что подтверждено, а что нет

- Запущен существующий Pura 90 Pro Max; HDC 127.0.0.1:5555, API 24.
- Запущено установленное приложение; наблюдался PID 3020, список чатов и сохранённая сессия.
- Bundle version 0.1.0, x86_64; updateTime = 2026-09-06T19:06:15.252Z. Это **старая сборка**, не HAP от 28 сентября.
- Переустановка, очистка данных, выход/вход в аккаунт, запись микрофона и отправка сообщений **не выполнялись**. Эмулятор оставлен запущенным.
- Личный screenshot проверен локально, но исключён из отчёта из-за содержимого чатов.
- Разрешение на обновление с риском повторного входа запрошено отдельно; пока не получено. Даже разрешение установить HAP само по себе не разрешает отправку сообщений.

Исторический emulator boot blocker больше не воспроизводится в этом конкретном запуске. Его исходная OS/GPU/RAM причина **не установлена**; стабильность под нагрузкой и текущий patch не приняты.

## 5. Изменённые файлы этого среза

Production:
- [tdlib_napi.cpp](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/cpp/tdlib_napi.cpp)
- [ChatVoiceRecordingController.ets](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/ChatVoiceRecordingController.ets)

Новые host tests/stubs:
- [test-native-bridge.cjs](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-native-bridge.cjs)
- [bridge_test.cpp](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/native-bridge/bridge_test.cpp)
- [native_api.h](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/native-bridge/include/napi/native_api.h)
- [log.h](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/native-bridge/include/hilog/log.h)
- [td_json_client.h](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/native-bridge/include/td/telegram/td_json_client.h)
- [test-voice-recording-ownership.cjs](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-voice-recording-ownership.cjs)

Адаптированные существующие проверки:
- [test-td-gateway-recovery.cjs](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-td-gateway-recovery.cjs)
- [test-edit-only-send-guard.cjs](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-edit-only-send-guard.cjs) — уже был untracked до этой работы.

Обновлены [STATUS](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/STATUS.md), [TODO](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/TASKS/TODO.md), [LESSONS](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/TASKS/LESSONS.md) и [план среза](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/TASKS/RELIABILITY_NATIVE_MEDIA_2026-09-28.md); созданы связанные отчёты и [машиночитаемые доказательства](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-28-native-media-evidence.json).

Это не полный diff относительно GitHub: до среза уже было 196 modified/untracked paths. Чужие/предыдущие изменения не сбрасывались. HEAD остался faf66b3e066afccdbbfa36442eb9122073f509b2, staging пустой; commit/push и новый remote fetch не выполнялись.

## 6. Что остаётся

1. Native enqueue ownership и полноценный teardown/асинхронный stop; TDLib open_count и session coordination.
2. Playback и account-wide media lifecycle; исходы forward со статусом unknown.
3. Приёмка новой сборки на устройстве, runtime recording/playback и UI regressions; отдельно согласовать операции с аккаунтом/сообщениями.
4. Clean-checkout build, затем остальные UI/feature gates канонического roadmap и публикация.

**Почему enqueue не исправлен «простым delete»:** в [upstream OpenHarmony NativeSafeAsyncWork::Send/CleanUp](https://github.com/openharmony/arkui_napi/blob/master/native_engine/native_safe_async_work.cpp) generic failure возможен после помещения payload в очередь; такой delete способен создать use-after-free. Finalizer также нельзя наивно считать последним обращением callback к данным. Источник сопоставлен с локальными SDK headers и harmonyos_docs; upstream master не доказывает идентичность установленного SDK binary.

Recorder grounding: harmonyos_docs AVRecorder state/release и [реализация](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/ChatVoiceRecordingController.ets) сопоставлены с локальным [HarmonyOS AVRecorder codelab](C:/Refs/Telegram/HarmonyOS-Codelabs/Media/AVRecorder_Audio/entry/src/main/ets/services/RecorderService.ets). UI не менялся; визуальный parity не заявляется.


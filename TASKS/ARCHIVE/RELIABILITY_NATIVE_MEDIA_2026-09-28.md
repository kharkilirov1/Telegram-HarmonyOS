# Надёжность: startup native bridge и владение recorder

Активный маршрут: `TASKS/PRODUCTION_PARITY_PLAN.md`, фаза надёжности. Это очередной срез общей цели, не новая граница готовности продукта.

## План и проверяемые ожидания

- [x] Native bridge: отказ создания TSFN/resource-name и callback ownership воспроизведены. Финальный host harness: HEAD 8/14 → current 14/14; startup rollback/retry и отсутствие receive без callback проверены.
- [x] Callback: null env/callback, N-API marshalling failure, точные JS args/JSON и освобождение string buffer проверены; три намеренные мутации отвергнуты.
- [x] Recorder (независимый worker): operation-owned cleanup и уникальность путей — 22/22; восемь мутаций отвергнуты. Родительский baseline реконструирован из HEAD + прежнего voice guard: 10/22 → 22/22, не точная исходная dirty-копия.
- [x] Независимые ревью и родительские проверки; 46/46 host suites, 38/38 PowerShell, Bash smoke и последовательные forced main/ohosTest builds PASS. 606 source/test/resource hashes совпали.
- [x] Обновлены STATUS/TODO/LESSONS; результаты и ограничения сохранены в docs/reviews/2026-09-28-native-media-remediation.md и native-media-evidence.json.
- [ ] Приёмка нового HAP на устройстве: эмулятор запущен со старой сборкой и сохранённой сессией; разрешение на обновление с риском повторного входа запрошено, но пока не получено. Host/compile gates не заменяют runtime acceptance.

## Границы изменений

Parent: `entry/src/main/cpp/tdlib_napi.cpp`, новый native host harness/runner, общая документация. Worker: `ChatVoiceRecordingController.ets`, его новый host test и отдельный отчёт. Не менять текущий UI, playback, аккаунты, signing, не выполнять commit/push.

## Развилки и ограничения

- Не менять TDLib `open_count` по догадке: проблема описана в `docs/reviews/2026-09-06-native-open-count-gap.md`; нужен отдельный согласованный client/session coordination contract, gate открыт.
- Отклонено «delete payload при любом enqueue status != napi_ok»: в upstream OpenHarmony `NativeSafeAsyncWork::Send` generic failure возможен как до enqueue (env), так и после queue insertion (`uv_async_send`). Такой delete может стать use-after-free. Перестройка enqueue/teardown lifetime и асинхронный Stop — отдельный незакрытый контракт, не маскировать этим patch.
- Проверенные источники: локальные SDK N-API headers; `harmonyos_docs` по napi_env/TSFN/status codes; [upstream Send/CleanUp](https://github.com/openharmony/arkui_napi/blob/master/native_engine/native_safe_async_work.cpp). Upstream master не доказательство идентичного бинарника установленного SDK.
- Исторические GitHub review probes ожидают наличие багов; их exit 0 не является acceptance исправления.
- Откат — точечный обратный diff только этого среза. Старые 196 modified/untracked paths сохраняются; HEAD исходно `faf66b3e066afccdbbfa36442eb9122073f509b2`, staging пустой.

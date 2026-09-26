# Воспроизведения ревью 2026-09-26

База: `dev@2d2f68391e259fa83e4c3e09f38841cc08c235d1`. [Отчёт R01–R23](../../../TASKS/CODE_REVIEW_2026-09-26.md).

**Это исторические probes известных дефектов. Успешный exit означает, что дефект воспроизведён, а не исправлен.** После исправлений соответствующий probe должен перестать подтверждать дефект; нужные fixtures следует перенести в обычные tests с assertions ожидаемого корректного поведения. Не подключать этот runner как зелёный release gate.

Требования: Node 24+ с `node:module.stripTypeScriptTypes`, Bash, grep, C++17 compiler с POSIX threads (`CXX`, по умолчанию `c++`). Установка пакетов и сеть не нужны. Команда из корня репозитория:

```bash
bash scripts/review/2026-09-26/run.sh
```

Runner использует настоящие production ETS/C++ исходники, не их переписанные копии. ETS imports/exports/types удаляются для host execution; платформенные зависимости и отдельные ports подменены mocks. Некоторые UI page setters смоделированы по исходникам: это не запуск ArkUI. Native headers — минимальные заглушки, не копия SDK ABI. Реальные TDLib, Telegram, SDK, микрофон и файловое хранилище приложения не используются. Native binary создаётся через `mktemp` в `/tmp` и удаляется `trap`; production-код не меняется.

| Probe | Что подтверждает | Что подменено / ограничение |
|---|---|---|
| `check_gateway.cjs` | Closed без нового клиента, stale adapter, delayed callback после timeout (R01) | Fake TDLib, ускорен только close watchdog; runtime wiring повторяет production |
| `data_parsing.cjs` | DTO sending/mentions, JSON scope/escapes/exponent, serializer controls (R03/R06/R07/R13) | Реальные parser/DTO/commands; logger stub |
| `state_repro.cjs` | Root routing, position removal, reply clone (R08/R09/R12) | Actual AppStore/reducers/normalizer; logger stub |
| `state_usecases.cjs` | Negative IDs, stale history window, manual mark-read (R02/R10/R11) | Actual use cases/commands, управляемые gateway/store ports |
| `ui_composer_repro.cjs` | Draft overwrite, partial retry, caption command (R14–R16) | Actual controllers + EditMessageUseCase/AppCommand; send/forward ports, Promise responses и platform APIs mocked |
| `media_races.cjs` | Recording, playback, download ownership (R04/R17/R18) | Actual controllers; AVPlayer/AVRecorder/file APIs mocked |
| `auth_logging.cjs` | OTP prefix в public log (R21) | Actual LoginController; synthetic code, captured logger |
| `build_guards.cjs` | Отсутствующий bootstrap, неверный grep mode (R05/R23) | Проверка файлов и grep fixture; не Hvigor build |
| `native/run.sh` | TSFN startup failure, env-null leak, blocking stop (R19/R20) | Actual C++ с минимальными N-API/TDLib mocks |

Отдельный диагностический performance probe, вне основного runner:

```bash
node --disable-warning=ExperimentalWarning scripts/review/2026-09-26/state_perf.cjs
```

Он считает обходы invariants на 30 000 синтетических сообщений и 100 progress events (R22). Время зависит от машины; порога FPS/ANR устройства или performance acceptance gate здесь нет.

Ожидаемый результат исходной базы: все probes завершаются с exit 0 и печатают `CONFIRMED`/`REPRO` либо явные наблюдения. В native timed stream Stop занимает около 3,4 с, число ответов fault probe зависит от планирования. При несовпадении assertion проверить изменение исходника/host assumptions; не менять expectation ради зелёного результата.

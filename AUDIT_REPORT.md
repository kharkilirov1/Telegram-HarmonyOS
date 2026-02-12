# Аудит 11 последних коммитов — alpha-core stabilization

**Дата:** 2026-02-12
**Ветка:** `main` (коммиты `b9eee4d`..`698b232`)
**Автор коммитов:** Claude
**Рецензент:** Claude Opus 4.6

---

## Общая характеристика

Серия из 11 коммитов представляет собой стабилизацию ядра Telegram-клиента для HarmonyOS (alpha-core). Основные направления:

1. **Безопасность** — шифрование БД через HUKS, миграция со старой незашифрованной схемы
2. **Надёжность** — lifecycle guards, TOCTOU protection, fail-fast NAPI, таймауты
3. **Диагностика** — структурированное логирование, error taxonomy, runtime info API
4. **Документация** — QA runbook, smoke checklist, build guide

---

## Поcommитный разбор

### 1. `b9eee4d` — fix: stabilize TDLib foundation (9 файлов, +282/−45)

**Что сделано:**
- CMakeLists.txt: приоритет разрешения TDLIB_DIR (CLI > env > default), диагностический блок
- NAPI: `getTdlibInfo()` — JSON с mode/tdlibDir/soname
- NAPI fail-fast: валидация argc + типов для всех 5 методов (send, receive, execute, startReceiveLoop, getTdlibInfo)
- TDLibClient: интеграция SecurityService для `database_encryption_key`
- `initialize()` стал `async`, `destroy()` — guard от double-call
- `send()` — TOCTOU-защита: snapshot state + double-check внутри Promise
- ConfigLocal.ets: реальные API-ключи заменены на плейсхолдеры

**Замечания:**

| # | Severity | Файл:строка | Описание |
|---|----------|-------------|----------|
| 1.1 | **CRITICAL** | `ConfigLocal.ets` | Ранее в репозитории были закоммичены реальные API-ключи (`api_id=37230596`, `api_hash=f2aba96fb8939e6aa24cd8d42973c83a`). Замена на плейсхолдеры корректна, но **ключи остались в git-истории**. Необходимо: (a) отозвать скомпрометированные ключи на my.telegram.org, (b) рассмотреть `git filter-branch` или BFG для очистки истории. |
| 1.2 | MEDIUM | `tdlib_napi.cpp:873` | `GetTdlibInfo()` строит JSON вручную через конкатенацию строк. Если `TDLIB_DIR_PATH` содержит `"` или `\`, JSON будет невалидным. Compile-time define обычно безопасен, но формально стоит экранировать. |
| 1.3 | LOW | `tdlib_napi.cpp:600` | `napi_check_type`: каст `napi_valuetype` к int для индексации массива `type_names[]` — корректен для текущих значений enum (0–9), но хрупок при расширении enum в будущих SDK. |
| 1.4 | LOW | `TDLibClient.ets:246` | `SEC_MODE` логируется *после* закрытия ASCII-box (строка 222 `└──`), что ломает визуальное форматирование лога. Строка `│ SEC_MODE: ... (resolved)` выглядит как orphan строка вне box. |

---

### 2. `99a40c2` — fix(P0-A): guarded one-time DB encryption key migration (+74)

**Что сделано:**
- Marker-файл `.enc_key_v1` для определения первого запуска с шифрованием
- При обнаружении legacy-БД (без маркера) — удаление каталога, пользователь пере-аутентифицируется

**Замечания:**

| # | Severity | Файл:строка | Описание |
|---|----------|-------------|----------|
| 2.1 | **HIGH** | `TDLibClient.ets:815` | `fileIo.rmdirSync(TDLIB_DB_DIR)` — в HarmonyOS `rmdirSync` удаляет только **пустую** директорию (поведение аналогично POSIX `rmdir`). Для непустой БД TDLib вызов упадёт с ошибкой. Нужен рекурсивный вариант (напр. `fileIo.rmdirSync(path, true)` если API поддерживает рекурсию, иначе — ручной обход). Коммит #8 (3fe7cc7) не исправил это. |
| 2.2 | MEDIUM | `TDLibClient.ets` | `ensureDbEncryptionMigration()` — синхронный метод с файловым I/O, вызванный внутри `async initialize()`. Блокирует main thread. Для мобильного приложения допустимо при старте, но стоит зафиксировать осознанность этого решения. |

---

### 3. `0d7e705` — fix(P0-B): add waitForReady() barrier (+30)

**Что сделано:**
- Promise-based barrier `_readyPromise` / `_readyResolve`
- `waitForReady()` — повторные вызовы безопасны (возвращают тот же промис)
- После `destroy()` — reset барьера для потенциального re-init

**Замечания:**

| # | Severity | Файл:строка | Описание |
|---|----------|-------------|----------|
| 3.1 | MEDIUM | `TDLibClient.ets` | В этом коммите `_readyPromise.catch()` отсутствует — unhandled rejection возможен если `destroy()` вызван без waiters. Исправлено в коммите #7 (d4d282f). Порядок коммитов создаёт промежуточное нерабочее окно. |

---

### 4. `a9d3ead` — docs(P1-C): BUILDING_TDLIB.md (+126)

**Что сделано:**
- Полное руководство по сборке TDLib из исходников для HarmonyOS
- Архитектурная диаграмма submodule vs prebuilt artifacts
- Таблица приоритетов TDLIB_DIR

**Замечания:**

| # | Severity | Описание |
|---|----------|----------|
| 4.1 | LOW | Документ ссылается на `OHOS_SDK` без объяснения, как найти SDK path в DevEco Studio. Новички могут не знать переменную. |
| 4.2 | INFO | Хороший документ, но привязан к версии 1.8.61. Стоит упомянуть процедуру обновления SONAME при смене версии TDLib. Это упомянуто, но мелким шрифтом внизу. |

---

### 5. `90024cd` — fix(P2-D): expose SecurityMode enum (+25)

**Что сделано:**
- `SecurityMode` enum: `UNINITIALIZED | HUKS_HARDWARE | SOFTWARE_FALLBACK`
- Getter `mode` в SecurityService
- Логирование режима после инициализации

**Замечания:**

| # | Severity | Описание |
|---|----------|----------|
| 5.1 | OK | Чистый, минимальный коммит. Enum экспортирован корректно. |

---

### 6. `8dd197a` — fix(P2-E): replace detached stub reply thread (+60/−15)

**Что сделано:**
- `std::thread(...).detach()` заменён на tracked `stub_reply_thread`
- Join при shutdown (`StopReceiveLoop`) и при создании нового reply thread
- `stub_enqueue_if_running()` — guard против post-shutdown enqueue
- Sleep разбит на 100ms-инкременты с проверкой `loop_state`

**Замечания:**

| # | Severity | Файл:строка | Описание |
|---|----------|-------------|----------|
| 6.1 | MEDIUM | `tdlib_napi.cpp:244-248` | `stub_reply_mutex` захватывается в `stub_handle_send()`, а `stub_handle_send()` вызывается из `Send()`, который вызывается из ArkTS main thread. Одновременно `StopReceiveLoop()` тоже захватывает `stub_reply_mutex` (строка 849). Если `stub_reply_thread.join()` заблокируется (thread в sleep), `StopReceiveLoop` будет ждать. Это допустимо (max 2 сек = 20 × 100ms), но стоит задокументировать максимальное время блокировки StopReceiveLoop. |
| 6.2 | LOW | `tdlib_napi.cpp:251` | `loop_state` используется без `memory_order` — `std::atomic<LoopState>` по умолчанию `seq_cst`, что корректно, но избыточно для флага. `memory_order_acquire` был бы точнее по семантике. Не баг, но указывает на неоптимальность. |

---

### 7. `d4d282f` — feat(P0): waitForReady timeout + error taxonomy (+65)

**Что сделано:**
- `waitForReady(timeoutMs)` с таймаутом 30 сек по умолчанию
- `_readyReject` для отклонения при `destroy()` во время init
- `_readyPromise.catch(() => {})` для suppression unhandled rejection
- `TDLIB_INIT_TIMEOUT` и `TDLIB_CLIENT_DESTROYED` в AppError taxonomy

**Замечания:**

| # | Severity | Файл:строка | Описание |
|---|----------|-------------|----------|
| 7.1 | MEDIUM | `TDLibClient.ets:156-166` | `setTimeout` внутри `waitForReady()` создаёт timer, который не отменяется если `_readyPromise` rejects (через `destroy()`). Формально: если `destroy()` вызывается, `_readyPromise.catch` ветка отменяет timer (`clearTimeout`), так что проблемы нет. Код корректен. |
| 7.2 | LOW | `AppError.ets:62-77` | Новые error-классификаторы `TDLIB_INIT_TIMEOUT` и `TDLIB_CLIENT_DESTROYED` проверяются через `message.startsWith()` — magic string coupling. При изменении формата строки в TDLibClient нужно синхронно менять AppError. Стоит рассмотреть enum-based errors вместо строковых паттернов. |
| 7.3 | LOW | `AppError.ets:80` | Старый код `message.includes('Client destroyed')` теперь частично дублирует новый `TDLIB_CLIENT_DESTROYED`. Реально конфликта нет (startsWith проверяется раньше), но мёртвая ветка для новых ошибок — потенциальная путаница. |

---

### 8. `3fe7cc7` — feat(P0): versioned encryption schema migration dispatcher (+70/−30)

**Что сделано:**
- Константная схема версионирования: `DB_ENC_CURRENT_VERSION`, `DB_ENC_MARKER_PREFIX`
- `readEncSchemaVersion()` — scan marker-файлов от max к min
- `writeEncSchemaMarker(version)` — запись маркера
- `migrateEncV0toV1()` — вынесен из inline-кода
- Switch-based dispatcher для будущих v1→v2, v2→v3 миграций

**Замечания:**

| # | Severity | Файл:строка | Описание |
|---|----------|-------------|----------|
| 8.1 | **HIGH** | `TDLibClient.ets:815` | Проблема из 2.1 **не исправлена**: `fileIo.rmdirSync(TDLIB_DB_DIR)` всё ещё не рекурсивный. TDLib создаёт вложенные файлы в директории БД. |
| 8.2 | MEDIUM | `TDLibClient.ets:759-772` | `readEncSchemaVersion()` сканирует от `DB_ENC_CURRENT_VERSION` вниз. Если по ошибке существуют маркеры нескольких версий (v1 и v2), возвращается наибольшая. Логика корректна, но стоит добавить предупреждение о множественных маркерах — это признак аномалии. |
| 8.3 | LOW | `TDLibClient.ets:749` | `default` case в switch логирует ошибку и делает `break` — `for` loop продолжит итерации, но состояние не обновится (маркер не записан). Это может привести к бесконечным попыткам миграции при каждом запуске. Стоит добавить `writeEncSchemaMarker(from + 1)` или прервать цикл. |

---

### 9. `184cd51` — feat(P1): release guard for SOFTWARE_FALLBACK (+20)

**Что сделано:**
- `_degradedSecurity` флаг + getter `isDegradedSecurity`
- Error-блок в логах если REAL TDLib + SOFTWARE_FALLBACK
- Info-уровень если STUB + SOFTWARE_FALLBACK (dev/emulator)

**Замечания:**

| # | Severity | Описание |
|---|----------|----------|
| 9.1 | LOW | `_degradedSecurity` не сбрасывается при `destroy()`. Если re-init произойдёт с HUKS_HARDWARE, флаг останется `true`. Маловероятный сценарий, но формально некорректен. |
| 9.2 | INFO | Хорошо: guard не блокирует запуск, только логирует. Правильное решение для alpha. |

---

### 10. `7a1098a` — docs(P1): release notes + QA runbook (+162)

**Что сделано:**
- `RELEASE_NOTES.md` — описание изменений, upgrade behavior таблица, troubleshooting
- `QA_RUNBOOK.md` — 8 тест-кейсов, hilog cheat sheet

**Замечания:**

| # | Severity | Описание |
|---|----------|----------|
| 10.1 | LOW | QA_RUNBOOK тест #4 (waitForReady timeout) предлагает добавить `while(true) {}` в код для симуляции — опасная инструкция, может быть случайно закоммичена. Лучше предложить настраиваемый `INIT_TIMEOUT_MS=1`. |
| 10.2 | INFO | Документы хорошо структурированы и полезны для QA-команды. |

---

### 11. `698b232` — docs(P1): regression smoke suite checklist (+41)

**Что сделано:**
- `SMOKE_TEST_CHECKLIST.md` — 10 пунктов с таблицей Pass/Fail, blocking issues, sign-off

**Замечания:**

| # | Severity | Описание |
|---|----------|----------|
| 11.1 | INFO | Чистый документ. Формат удобен для ручного QA. |

---

## Сводная таблица проблем

| # | Severity | Commit | Проблема | Статус |
|---|----------|--------|----------|--------|
| 1.1 | **CRITICAL** | b9eee4d | API-ключи в git-истории | Открыта — требует отзыва ключей + очистки истории |
| 2.1 / 8.1 | **HIGH** | 99a40c2 / 3fe7cc7 | `rmdirSync` не рекурсивный — миграция не удалит непустую БД | Открыта |
| 8.3 | MEDIUM | 3fe7cc7 | default-ветка в migration switch не записывает маркер | Открыта |
| 1.2 | MEDIUM | b9eee4d | JSON injection в GetTdlibInfo при спецсимволах в path | Открыта |
| 7.2 | LOW | d4d282f | Magic string coupling между TDLibClient и AppError | Открыта |
| 1.4 | LOW | b9eee4d | SEC_MODE лог вне ASCII-box | Открыта |
| 9.1 | LOW | 184cd51 | `_degradedSecurity` не сбрасывается при re-init | Открыта |

---

## Архитектурная оценка

### Положительные стороны

1. **Single source of truth** — TDLib-параметры, DB paths, encryption key сосредоточены в одном месте
2. **Fail-fast** — NAPI-уровень теперь отклоняет некорректные аргументы с понятными ошибками вместо UB/crash
3. **Lifecycle state machine** — чёткие состояния `Idle → Initializing → Ready → Stopping → Stopped` с guards на каждом переходе
4. **TOCTOU protection** — `send()` делает snapshot + double-check, `handleResponse()` re-check после async gap
5. **Versioned migration** — расширяемая схема для будущих изменений шифрования
6. **Diagnostic logging** — ASCII-box при инициализации с полной информацией о режиме работы

### Области для улучшения

1. **Тестируемость** — ни один коммит не включает unit-тесты. TDLibClient жёстко связан с NAPI-модулем, нет dependency injection для тестирования
2. **Error typing** — magic strings вместо enum-based errors между TDLibClient и AppError
3. **Синхронный файловый I/O** — `ensureDbEncryptionMigration()` блокирует, хотя вызывается из async-контекста
4. **Singleton pattern** — `TDLibClient.instance` и `SecurityService.instance` затрудняют тестирование и повторную инициализацию
5. **Коммиты не атомарны** — коммит #3 создаёт unhandled rejection, исправленный только в #7. Промежуточные состояния сломаны

---

## Рекомендации (по приоритету)

1. **[P0] Отозвать API-ключи** на my.telegram.org и очистить git-историю
2. **[P0] Исправить `rmdirSync`** — использовать рекурсивное удаление для миграции БД
3. **[P1] Добавить запись маркера** в default-ветке migration switch (или break с ошибкой)
4. **[P1] Сбрасывать `_degradedSecurity`** в `destroy()` или начале `initialize()`
5. **[P2] Экранировать спецсимволы** в `GetTdlibInfo()` JSON-сборке
6. **[P2] Добавить unit-тесты** для: migration logic, waitForReady timeout, TOCTOU send/destroy race
7. **[P3] Рассмотреть enum-based error codes** вместо magic strings для inter-module coupling

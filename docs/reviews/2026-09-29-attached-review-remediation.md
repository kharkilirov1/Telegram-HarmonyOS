# Проверка приложенного код-ревью — 2026-09-29

Вход: пользовательский файл `C:\Users\Kharki\.codex\attachments\912f2544-f91e-49fd-9f17-a1c703ba1e51\Вставленный текст.txt` (вывод на строках 538–695). Проверка выполнена против текущего dirty `dev@faf66b3`, а не против чужих `.claude/worktrees`. Исходные незакоммиченные изменения не сбрасывались; commit/push и установка HAP не выполнялись.

## Подтверждено и исправлено

| Дефект и исходный witness | Узкая правка | Повторный witness |
|---|---|---|
| `CommandSerializer.escapeForJson` и `TdObject.escapeJsonString` пропускали управляющие символы U+0000–U+001F. NUL проходил use case и давал невалидный JSON / обрезание на C-string boundary. | Экранирование отдельных строк через `JSON.stringify` без пересериализации целого TDLib-запроса: `entry/src/main/ets/infra/td/serialization/CommandSerializer.ets`, `entry/src/main/ets/models/td/common/index.ets`. | `scripts/test-command-serializer-escaping.cjs`: 198/198, exit 0; возврат старого декодера: 28 FAIL, exit 1. |
| `TdObject.unescapeJsonString` повторно интерпретировал уже декодированный backslash: литеральные `\n` / `\u0000` менялись при получении TDLib-строк. | Однократное декодирование исходных JSON escape-токенов в `entry/src/main/ets/models/td/common/index.ets`. | Та же focused suite и отрицательный контроль; `tdGetText`, вложенные объекты, массивы и cache включены. |
| `SafeAreaUtils.removeWindowSizeListener` вызывал `Window.off` без callback и снимал подписки других страниц. Контракт SDK: `off(event)` снимает все, `off(event, callback)` — только указанную. | `addWindowSizeListener` возвращает idempotent disposer с callback-specific `off`; шесть страниц владеют собственным disposer, partial bind откатывается, late callback fenced. | `scripts/test-ui-window-search-lifecycle.cjs`: 48/48, exit 0; `global-off` mutation: exit 1. |
| `searchFlashTimerId` переживал `aboutToDisappear` и поздно менял timeline. | Cleanup при teardown плюс проверка lifecycle token и identity таймера в `TgChatScreenPage.ets`. | Та же focused suite: teardown/supersession/replacement проходят; обе timer mutations: exit 1. |

## Утверждения ревью, которые не стали задачами

- `TgChatScreenPage.ets` действительно содержит 5921 строку, но размер сам по себе не доказывает bug. Широкий рефакторинг перед функциями добавил бы риск в уже dirty route/account/media код. Исправлены конкретные lifecycle-дефекты без переноса всего экрана.
- «Нет retry/reconnect» неверно для текущего дерева: TDLib reconnect, `TdGateway` terminal-Closed recovery и `AppCoreRuntime` hooks существуют. Host recovery-сценарии прошли; реальный network handover остаётся device gate. Автоматически повторять неидемпотентные запросы опасно.
- `vp2px` — обратное направление для существующего `px2vp`. Глобальный `px2vp` можно отдельно оценить на multi-window/runtime, но замена из ревью некорректна.
- `AppCommand`/`AppEvent` не продублированы в domain, reducer/DTO tests уже существуют; DI-контейнер без проверяемого выигрыша не добавлен.
- Оценка `8.5/10`, «branded IDs», «около 100 ETS» и API target 22 не подтверждают текущую готовность. Фактический `build-profile.json5`: compatible API 23, target API 26.
- Hardcoded пользовательские строки действительно встречаются; не смешивать их с `localized(resource, English fallback)`. Локализация остаётся отдельным UI-срезом, не частью этих lifecycle/security фиксов.
- Ревью называло JSON-проблему XSS, но HTML/XSS-путь не установлен. Подтверждённый дефект — JSON string escaping на TDLib boundary.

## Итоговые проверки и границы

- После всех code edits: `node scripts/run-host-tests.cjs` → **60/60, exit 0** (новые `test-*.cjs` входят через autodiscovery).
- `powershell -ExecutionPolicy Bypass -File scripts/smoke-ui-phase0.ps1` → **exit 0**; `git -c core.whitespace=cr-at-eol diff --check` → **exit 0**.
- Последовательные `hvigorw` debug `entry@default` и `entry@ohosTest`, `--no-incremental --no-daemon --no-parallel` → **BUILD SUCCESSFUL, exit 0/0**. Тестовый HAP скомпилирован, а не исполнен на устройстве; подпись не настроена.
- Независимые Astra Ultra reviewers не нашли P1/P2 в двух исправленных срезах. Их host-модели не являются проверкой установленного SDK, реального ArkUI lifecycle или NAPI/TDLib round-trip.
- Остался отдельный дефект permissive regex-парсера `TdObject.getString`: при `{"nested":{"text":"nested"},"text":"top"}` он может выбрать вложенное поле; `getTopLevelStringStrict` выбирает верхний уровень. Не переписывать парсер без отдельного scope и red/gate для потребителей.
- Текущий HAP не устанавливался поверх сохранённой emulator-сессии. Device/UI acceptance, clean-checkout и ранее открытые native lifetime/forward gates не закрыты этим ревью.

# Reliability Wave13 — доступность source actions и безопасный picker

2026-09-06, `dev@faf66b3`, исходное dirty дерево сохранено. **Source availability и связанные гонки меню/picker исправлены на source/host/compile уровне. Проверки на устройстве и visual acceptance не выполнены.**

## Результат

- Forward не открывает получателей до проверки исходных сообщений. Read-only source capability отделена от права отправлять в открытый чат: доступный источник из read-only канала не блокируется composer guard этого канала.
- Меню имеет loading / allowed / denied / retry. Известный запрет отличается от отсутствующих/malformed properties и transport error; retry только явный. Проверки не становятся постоянным permission cache.
- Передаются route flags всей selection: ordinary destination требует server `can_be_forwarded` или non-server `can_be_copied`; secret destination требует `can_be_copied_to_secret_chat`. Каждый маршрут пересекается по **всем** IDs. Нет ошибочного per-item `F || S` и нет скрытого включения `sendCopy`.
- Target picker фильтрует ordinary/secret классы по flags, повторно проверяет выбранный chat по текущему state. Compose mode не фильтруется этими flags. `.onReady` принимает отрицательный source chat ID и перестраивает список после получения route params.
- Действие передаётся как stable action ID + source message ID + opening token, не индекс. Page проверяет account/use-case identity, source chat, lifecycle и текущую availability; старое действие не изменяет новый composer.
- Dismiss callback захватывает generation при bind. Поздний `isVisible=false` от предыдущего открытия того же сообщения не закрывает новое меню.
- Новые Reply/Edit/Forward/Cancel и повторное открытие actions инвалидируют ожидающий picker. Старый результат не стирает новое намерение. Duplicate-open fence привязана к account/use-case; результат picker потребляется один раз даже до смены lifecycle исходной страницы.
- Сохранены проверки Wave12 непосредственно перед comment и forwarding dispatch, positional results и безопасный retry. Source menu snapshot не заменяет destination-specific revalidation.

## Воспроизводимые изменения witness

| Проверяемое поведение | До | После |
|---|---:|---:|
| Начальные menu/picker cases | 0 PASS / 3 FAIL | 3/3 |
| Старое действие после account/chat/lifecycle/capability change | 4 FAIL | 4 PASS |
| Два P2 независимого review: late dismiss + Reply/Edit/Cancel supersession | 4 FAIL | 4 PASS |
| Повторный picker result до lifecycle advance | 1 FAIL | 1 PASS |
| Финальный расширенный actual-source suite | — | **62/62**, включая 12 native bodies через host adapter |

Начальный stable-ID case проверял требуемый новый contract; это не утверждение, что старое синхронное меню уже меняло порядок само по себе. Опасность индекса возникает при асинхронном изменении списка. Late dismiss, заменяющие действия и duplicate result воспроизведены через фактические callback/method bodies с контролируемыми fixture responses.

Batch route counterexample — синтетическая проверка редукции, не захваченный payload реального user-account. Clipboard/navigation/platform boundaries — fixtures; реальные сообщения не отправлялись.

## Финальная проверка

| Gate | Результат |
|---|---|
| Focused suite | 62/62; 12 неизменённых Hypium bodies выполнены через host adapter |
| Все `scripts/test*.cjs` | 29/29, включая прежний Wave12 suite 75/75 |
| PowerShell/source-contract + UI smoke | 38/38 |
| Исходный review witness | 8/8 |
| Syntax | 29 CJS + review script, exit 0 |
| Main CompileArkTS | 26 s 99 ms; build 45 s 802 ms, exit 0 |
| OhosTestCompileArkTS | 21 s 454 ms; build 44 s 567 ms, exit 0 |
| SHA256 before/after final builds | 57 файлов: 54 dirty/new `.ets` + 3 resource JSON; без изменений |
| Localization | 9 значений, каждое имя ровно один раз в base / ru_RU / zh_CN |
| `git diff --check` | exit 0 |

Обе финальные сборки принудительные: `assembleHap --no-incremental --no-daemon`; actual CompileArkTS tasks присутствуют. Предыдущие зелёные сборки до review/one-shot fixes устарели и не используются как итоговый witness.

Мутации только в памяти, engagement каждой = 1, каждая завершилась exit 1:

| Отключённый путь | FAIL из 62 |
|---|---:|
| Batch route intersection | 13 |
| Popup request generation | 4 |
| Rendered action context token | 1 |
| Pre-picker source gate | 2 |
| Picker route filtering | 3 |
| Stateful render key | 1 |
| Dismiss opening generation | 1 |
| Replacing-intent cancellation | 4 |

Render-key/bind assertions — **структурные** проверки wiring, не эмуляция ArkUI renderer. Остальные соответствующие behavioral tests выполняют actual source methods. Native Hypium execution на устройстве не заявляется.

Полные derived results, hashes и build witnesses: [evidence JSON](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-06-reliability-wave13-evidence.json).

## Изменённые файлы

Корень: `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/`.

- `entry/src/main/ets/domain/usecases/forwardMessages.ets` — target-independent batch availability.
- `entry/src/main/ets/ui/pages/chat/ChatForwardSourceController.ets` — новый bounded popup request controller.
- `entry/src/main/ets/ui/pages/chat/ChatMessageActionsController.ets` — stable action dispatch, fresh pre-picker check, route flags, supersession, duplicate/one-shot fences.
- `entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets` — reactive menu states, identity/lifecycle ownership, callback factory и stateful render key.
- `entry/src/main/ets/ui/pages/forward/TgForwardTargetPickerPage.ets` — route params/filtering/readiness/fresh selection guard.
- `entry/src/main/resources/{base,ru_RU,zh_CN}/element/string.json` — checking/denied/retry labels.
- `entry/src/ohosTest/ets/test/ForwardSourceActions.test.ets` — 12 новых tests; `List.test.ets` — регистрация. Existing native hosts в `ForwardEligibility.test.ets` и `ForwardSendOwnership.test.ets` получили source getter, сохранив send guards.
- `scripts/test-forward-source-actions.cjs` — новый actual-source harness; `scripts/test-ios-native-liquid-composer.ps1` — вместо устаревшего index contract проверяет item, enabled и identity guards.
- `entry/src/main/ets/ui/tg_ui/spec/TgIosNativeLiquidComposer.md` — menu contract; STATUS/TODO/LESSONS/CHAT_ACCESS_PLAN/PRODUCTION_PARITY_PLAN и этот отчёт — working snapshots/evidence.

## Источники и независимое review

- iOS: [ChatInterfaceStateContextMenus.swift](C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Sources/ChatInterfaceStateContextMenus.swift), Forward `1896–1903`, selection intersection `2748–2751`. Чтение выполнено основным агентом; source reference не равен текущему установленному iOS runtime.
- TDLib: `tdlib/td/generate/scheme/td_api.tl:10315–10316,10872–10881`, `MessagesManager.cpp:14797–14801,23871–23885`, `MessageId.h:121–123`. Сохранён API-specific mode contract из Wave12.
- `harmonyos_docs`: `"@Local" AND "Array"`, ForEach/key/itemGenerator, `PopupStateChangeParam` (API 18+). CPL HTTP health завершился коротким timeout; использован direct known-source fallback, не повторялись длительные MCP calls основным агентом.
- Darwin независимо сверил iOS/TDLib и нашёл два P2; основной агент воспроизвёл, исправил и повторно проверил их. Финальное read-only review этих взаимодействий не выявило дополнительных P1/P2. Fermat обновил native fixtures/localizations, Lovelace добавила 12 native tests; основной агент проверил результаты инструментами. Все три агента закрыты.

## Ограничения и следующий шаг

**Не заявляется совпадение UI с iOS.** iOS скрывает недоступный Forward; сохранённая disabled-строка здесь — намеренная Harmony adaptation для стабильного async menu. Ее визуальная и accessibility-приёмка ещё нужна. Реальная смена состояний ForEach/Popup и touch geometry требуют device witness, а не только compile/host tests.

Свежий `hdc list targets`: **[Empty]**. Новых boots, HAP installs, account actions, sends, commits, system changes или публикации нет. Ранее SceneBoard падал до установки Telegram: [Wave10](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-06-reliability-wave10.md); root cause не объявляется установленной или исправленной.

Остаются: hydration неизвестного source content kind для target per-kind guards; recovery старых temporary IDs; messageProperties policies для остальных действий/expiry/thread contexts; визуальная приёмка и длительный device/account сценарий. Properties necessary, not sufficient для server/input-media acceptance; comment + forward не атомарны. Общая цель reliability → UI → features → publication остаётся активной.

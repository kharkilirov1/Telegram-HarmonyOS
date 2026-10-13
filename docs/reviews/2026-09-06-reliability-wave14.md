# Reliability Wave14 — безопасное удаление сообщений

Дата: 2026-09-06. Ветка `dev@faf66b3`; рабочие изменения не закоммичены.

## Результат

Устранено немедленное удаление `revoke=true` из message actions без подтверждения. Теперь native dialog предлагает только разрешённые для сообщения режимы; выбор не расширяется и не подменяется после изменения прав. Повторная проверка непосредственно перед dispatch обязательна. Старый async intent, смена чата/аккаунта/lifecycle и повторные нажатия не разрешают новый delete.

**101/101 focused проверок; 30/30 CJS suites; 38/38 PowerShell + UI-smoke; исходный review witness 8/8. Обе final forced ArkTS compilation прошли. Это source/host/compile-срез, не runtime acceptance и не доказанная надёжность всего клиента.**

Машиночитаемое свидетельство: [evidence](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-06-reliability-wave14-evidence.json).

## Baseline → исправление → проверка

| Проверка | До | После |
|---|---:|---:|
| Исходные confirmation / invalid ID / fulfilled error / mode / default cases | 0 PASS / 5 FAIL | проходят в final suite |
| Новый Forward во время loading / confirming / rechecking удаления | 3 FAIL, воспроизведены родителем после находки reviewer | 3 PASS |
| Final focused suite, включая реальные Hypium bodies через Node adapter | — | 101 PASS / 0 FAIL |
| Native-test fixture compilation | `10605038 arkts-no-untyped-obj-literals`, строка 226 | исправлен plain-object fixture, final compile PASS |

Был также обнаружен и исправлен ложный fixture: helper default превращал `params(undefined)` в валидные IDs. Проверка теперь явно присваивает undefined. Это ошибка теста, не исправление production-кода.

## Что изменено

- [deleteMessages.ets](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/domain/usecases/deleteMessages.ets): safe integer chat/ID, nonempty selection, literal boolean mode; snapshot и dedup с сохранением порядка. Fresh strict `getMessageProperties` каждого сообщения до confirmation и повторно перед mutation. Пересечение `can_be_deleted_only_for_self` / `can_be_deleted_for_all_users`; неизвестное не равно разрешению. Strict received `TdObject @type=ok`, неопределённый исход не retryable и не приводит к automatic replay.
- [AppCommand.ets](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/core/model/AppCommand.ets): default `revoke=false` в payload/factory, как и в params. UI передаёт выбранный режим явно.
- Новый [ChatDeleteMessageController.ets](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/ChatDeleteMessageController.ets): native `UIContext.getPromptAction().showDialog`; Cancel первым, максимум три кнопки, captured mode map. Cancel/Back/rejection/malformed index не разрешают удаление. Typed injectable confirmation port отделяет платформенную презентацию от flow.
- [ChatMessageActionsController.ets](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/ChatMessageActionsController.ets) и [TgChatScreenPage.ets](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets): общий cancel pending actions; delete flow инвалидируется при новом Reply/Edit/Forward и открытии другого menu. **Прямой channel-share Forward** тоже отменяет старый delete до первого async lookup; этот путь не проходил через menu.
- [DeleteMessagesSafety.test.ets](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/ohosTest/ets/test/DeleteMessagesSafety.test.ets): 14 Hypium cases, зарегистрированы в [List.test.ets](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/ohosTest/ets/test/List.test.ets). Native-тела исполнены через host adapter, но **не на устройстве**.
- [UseCases.test.ets](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/ohosTest/ets/test/UseCases.test.ets): существующие шесть cases исполняют обновлённый read/mutation protocol; failure injection по-прежнему относится к mutating request.
- [test-delete-message-safety.cjs](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-delete-message-safety.cjs): actual-source loader, source hashes, bounded tests, native-body adapter и 8 engaged mutation modes.
- По шесть resource keys в [base](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/resources/base/element/string.json), [ru_RU](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/resources/ru_RU/element/string.json), [zh_CN](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/resources/zh_CN/element/string.json). Все 18 значений прочитаны родителем; duplicate keys отсутствуют.

Production architecture, composer draft и application-store deletion pipeline не переписаны. Application UI не делает собственного optimistic delete; это не означает, что TDLib ждёт server receipt перед локальным удалением.

## Проверка, что защитный код действительно задействован

Все мутации применяются только in-memory loader, не к рабочим файлам. У каждой `engagement=1`, exit=1:

| Удалённая защита | FAIL |
|---|---:|
| Explicit confirmation | 38 |
| Exact selected mode | 5 |
| Strict received Ok | 8 |
| Flow/account/chat/lifecycle context | 17 |
| Own-generation cleanup | 3 |
| Cancel index mapping | 1 |
| Dispatch guards | 6 |
| Direct Forward cancels pending delete | 3 |

Покрыты также batch intersection, >100 несортированных IDs без заимствованного forward-лимита, copied params, repeated taps, supersession, stale finally, denial after confirmation, transport failure без replay, serializer numeric IDs и self→global escalation.

## Build и границы исполнения

Final, после исправления native fixture:

- `entry@default`: `CompileArkTS 29 s 35 ms`; `BUILD SUCCESSFUL 50 s 491 ms`, exit 0.
- `entry@ohosTest`: `OhosTestCompileArkTS 23 s 151 ms`; `BUILD SUCCESSFUL 45 s 118 ms`, exit 0.
- `--no-incremental --no-daemon`; задачи реально исполнились, не просто UP-TO-DATE.
- **60 SHA256: 57 dirty/new ArkTS файлов + 3 resource JSON** до/после final builds совпадают. В hash set включены untracked файлы, которые обычный git diff не показывает.
- Syntax: 30 CJS scripts + original review harness, 31/31. `git diff --check`: exit 0.
- 20 Hypium bodies входят в 101 focused: 14 новых + 6 compatibility, не отдельные дополнительные 20 успешных device-тестов.
- Сохранились SDK warnings: отсутствующий `icudtl.dat` в SDK/previewer и future NAPI verification; warning-free build не заявляется.

Свежий `hdc list targets`: **[Empty]**. В этом срезе не было emulator boots, HAP installs, реального TDLib delete или действий с пользовательским аккаунтом. Предыдущий [Wave10](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-06-reliability-wave10.md) уже воспроизвёл SceneBoard startup crash до установки Telegram; root cause остаётся не установленной. Новый пустой HDC не доказывает новый crash.

## Основание решений и независимая проверка

- [td_api.tl](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/generate/scheme/td_api.tl): message properties 5354–5391, `getMessageProperties` 10316, `deleteMessages` 10905–10909.
- [MessagesManager.cpp](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/telegram/MessagesManager.cpp): 8012–8068, 8093–8152, 14765–14790. Exact message flags важнее blanket forced-chat-type предположения: локальные/неотправленные/Saved/Secret случаи различаются. У delete нет forward-style sorted/max100 контракта. Positive int53 — лишь format check, не полная C++ MessageId validity.
- iOS [ChatControllerLoadDisplayNode.swift](C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Sources/Chat/ChatControllerLoadDisplayNode.swift), 1969–2056: recompute actions → deletion options, отдельные paid/scheduled branches.
- iOS [ChatControllerAdminBanUsers.swift](C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Sources/ChatControllerAdminBanUsers.swift), 410–740: explicit scope / Cancel / Undo и специальные варианты.
- HarmonyOS docs MCP запросы showDialog + PromptAction / ShowDialogOptions buttons; локальные SDK declarations [promptAction](C:/Program%20Files/Huawei/DevEco%20Studio/sdk/default/openharmony/ets/api/@ohos.promptAction.d.ts) и [UIContext](C:/Program%20Files/Huawei/DevEco%20Studio/sdk/default/openharmony/ets/api/@ohos.arkui.UIContext.d.ts). Follow-up Record query не дал результатов; исправление fixture подтверждено настоящим ArkTS compiler.
- CPL HTTP в начале среза не ответил за короткий timeout; использован direct known-source fallback, без повторных долгих scans.
- Три субагента: contract/reviewer, native tests, compatibility/resources. Родитель сам воспроизвёл найденную гонку, выполнил actual test bodies, проверил ресурсы и final builds; найденную компилятором ошибку теста не скрыл.

## Что ещё не принято

1. **Реальный native dialog**: Cancel/Back/dismiss, длинные переводы, Light/Dark, safe areas, fresh process и TDLib update flow требуют device witness. Native screenshot этого среза отсутствует.
2. **iOS deletion parity**: Undo/delayed commit, специальные Saved/scheduled/repeating/paid/giveaway labels и последствия пока не реализованы. Generic confirmation — safety improvement, не полная семантическая/визуальная эквивалентность.
3. **Неатомарность TDLib**: Ok не per-ID server receipt; исчезнувший после последней properties-проверки ID может завершиться Ok. TDLib может удалить локально до server failure. Scope следует public properties; для Secret/local нельзя обещать отсутствие любого remote protocol effect.
4. Properties для остальных actions, edit/expiry/thread cases и forward metadata hydration остаются следующей reliability-работой. Затем прежний UI → функции → publication roadmap.
5. Device acceptance, signed publication и сравнение надёжности с оригиналом **открыты**. Общая цель не завершена.

## Повторить локальную проверку

```powershell
node --disable-warning=ExperimentalWarning C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-delete-message-safety.cjs
node --disable-warning=ExperimentalWarning C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-delete-message-safety.cjs --mutant=forward-intent
```

Первый exit=0 / 101 PASS; второй должен дать exit=1 / 3 FAIL. Это только fake transport/confirmation; реальные сообщения не затрагиваются. Полные final build commands сохранены в evidence JSON.


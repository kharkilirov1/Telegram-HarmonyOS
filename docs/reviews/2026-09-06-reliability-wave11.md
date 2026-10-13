# Wave11 — права супергрупп, boosts и восстановление после ошибки

**Исправлена проверяемая цепочка ordinary-supergroup permissions: TDLib update / FullInfo → scoped AppStore → per-kind policy → composer / send guards. 32/32 focused, 27/27 CJS, 38/38 PowerShell + smoke, review 8/8; финальные main/ohosTest compile прошли. Device и visual acceptance не выполнены: HDC `[Empty]`, системный blocker Wave10 остаётся.**

Корень путей: `C:/Users/Kharki/Desktop/Telegram-HarmonyOS`. Полная цель reliability → имеющийся UI → функции/UI → публикационная готовность остаётся активной. Это законченный source/host/compile-срез, не доказательство равенства iOS или готовности всего клиента к публикации.

## До / после

Baseline до production-правок: **1 PASS / 16 FAIL**. Ordinary supergroup использовал старый basic-text fallback: не было полноценной membership/per-kind policy, boost snapshot, update route и FullInfo hydration. Например, разрешённая фотография при запрещённом тексте не сохраняла composer; известный qualifying booster не получал разрешённый ему text path.

После основной реализации и native suite было **31/31**. Независимое ревью нашло дополнительный P2: когда text разрешён, photo зависит от неизвестных boosts, а FullInfo load завершился ошибкой, общий panel остаётся composer. Единственная Retry-кнопка раньше появлялась только при общем `unknown`, поэтому восстановление media rights было недоступно до переоткрытия страницы или live update.

Основной агент воспроизвёл этот дефект новым тестом: **31 PASS / 1 FAIL** (`working composer needs its own discoverable retry`). После добавления отдельного Retry без замены работающего composer — **32/32**. Тест исполняет извлечённый из текущего atom обработчик, фактический parent callback, controller и use case с mock transport; проверяет disabled guard, отсутствие дублирующего запроса, сохранение черновика и восстановление photo capability. Это не simulated device tap и не visual witness.

## Реализация

1. **Typed snapshot.** `SupergroupBoostsDto` хранит `groupId`, `myBoostCount`, `unrestrictBoostCount`. Принимаются только literal top-level `supergroupFullInfo` / nonnegative int32 counts / safe positive group ID. Nested lookalikes, строки, дробные/отрицательные/небезопасные числа не дают privilege. Snapshot отсутствует отдельно от валидного `0/0`.
2. **Live data.** `updateSupergroupFullInfo` использует строгий outer `supergroup_id`, новый typed event проходит combined reducer, данные сохраняются до `newChat`. Producer DTO клонируется; map сохраняется при других chat updates; account reset очищает snapshot.
3. **Политика.** Exact group identity и membership проверяются раньше privilege. Creator/admin имеют отдельный bypass. Для ordinary member/restricted все девять send kinds проверяются независимо. Qualifying boost (`threshold > 0 && my >= threshold`) отменяет только defaults, но не individual restriction. Один разрешённый kind сохраняет composer; caption следует типу media. Basic group, broadcast channel и private/secret не получают booster bypass.
4. **Unknown.** Отсутствующий AppStore FullInfo не объявляется отсутствующим внутренним TDLib cache. Уже разрешённый default kind работает без запроса; неизвестный boost, который мог бы разрешить запрещённый default kind, остаётся unknown до hydration. Известный booster может обойти отсутствующие defaults, но не individual deny.
5. **Hydration.** Последовательность membership → missing defaults → нужный boost snapshot. `getSupergroupFullInfo` уже существовал в command/serializer layer; переиспользован без изменения wire shape. FullInfo не содержит собственного group ID, поэтому ответ привязан к captured request ID. Singleflight публикуется до send, очищается и при ошибке; live snapshot выигрывает у позднего ответа при dequeue; account scope не позволяет восстановить старый аккаунт.
6. **UI и действия.** Page подписывается на access/boost изменения активной супергруппы, публикует `@Local` массив разрешённых kinds; реальные send getters снова читают scoped store. Ошибка partial hydration показывает native Retry над сохраняющимся composer. Полностью unknown panel использует прежний Retry. Нет automatic retry loop или реальной отправки из тестов.

## Проверки

| Gate | Результат |
|---|---|
| Focused actual-source suite | 32/32; 9 native test bodies через host adapter |
| Все `test-*.cjs` | 27/27 |
| PowerShell/source-contract + UI smoke | 38/38 |
| Исходный review witness | 8/8 |
| Syntax | 27 CJS scripts + review script, exit 0 |
| Финальный main CompileArkTS | 39 s 930 ms; build 1 min 2 s 638 ms, exit 0 |
| Финальный OhosTestCompileArkTS | 18 s 371 ms; build 41 s 399 ms, exit 0 |
| SHA256 всех dirty/new `.ets` | 50 before/after, без изменений во время final build |
| `git diff --check` | exit 0 |

Обе финальные сборки запускались с `--no-incremental --no-daemon`, actual CompileArkTS task присутствует в выводе. Предыдущая сборка до Retry-правки была зелёной, но не используется как финальное доказательство.

Мутации выполнялись только в памяти, каждое изменение действительно применилось один раз:

| Отключённый путь | FAIL из 32 |
|---|---:|
| Individual restriction | 5 |
| Booster bypass | 11 |
| Boost snapshot в page dispatch gate | 6 |
| Live-over-late-response guard | 1 |
| Map preservation при clone | 3 |
| Page subscription на boosts | 1 |
| Реальный UI retry callback | 1 |

Полные результаты и hashes: `docs/reviews/2026-09-06-reliability-wave11-evidence.json`.

### Исправленные ошибки тестового окружения

- Strict getter читает received `rawJson`, а serializer строит `TdObject` через cache setters. Поэтому wire assertion проверяет `JSON.parse(params.toJSON())`, включая числовой ID 77. Serializer ради теста не менялся.
- Старый controller test считал supergroup вне hydration scope. Scope расширен намеренно; добавлен положительный case exact supergroup membership request, private/secret exclusions сохранены.
- Старые live-permission fixtures не задавали реальную membership и known-zero boosts; теперь они проходят через actual normalizer updates. Panel fixture получил новую state map.
- В source-extracted page harness добавлена фактическая dependency `needsSupergroupBoosts`. Production fallback ради неполного mock не добавлялся; после исправления все 27 CJS suites повторно выполнены.

## Субагенты и references

- **Feynman:** написал только `SupergroupBoosts.test.ets` с девятью cases. Основной агент прочитал, исполнил native bodies через host adapter, зарегистрировал suite и проверил свежий compile. Агент закрыт.
- **Arendt:** независимое read-only integration review; P2 partial Retry подтверждён и исправлен основным агентом. Агент закрыт.
- TDLib: `tdlib/td/generate/scheme/td_api.tl:2404–2416,9564,10276–10277`; `DialogParticipant.cpp:456–490`; `ChatManager.cpp:8477–8496,8743–8745`. FullInfo response может быть cached; live-update fencing обязателен.
- iOS: `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Sources/ChatInterfaceStateInputPanels.swift:234–255` (membership) и `.../Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift:2849–2860` (отдельное accessory/input содержание). Новый Retry — явно HarmonyOS recovery affordance, не якобы скопированный iOS control.
- `harmonyos_docs`: observed primitive arrays в `@Local`, official Button `.enabled` / `.onClick` usage. CPL HTTP повторно отказал в соединении; использован прямой read известных файлов, без очередного blind retrieval timeout.

## Изменённые файлы

Production/runtime:
- `entry/src/main/ets/core/model/dto/GroupAccessDto.ets`
- `entry/src/main/ets/core/model/AppState.ets`
- `entry/src/main/ets/core/model/AppEvent.ets`
- `entry/src/main/ets/core/events/normalizers/ChatNormalizer.ets`
- `entry/src/main/ets/core/reducers/chatsReducer.ets`
- `entry/src/main/ets/core/reducers/index.ets`
- `entry/src/main/ets/core/utils/stateClone.ets`
- `entry/src/main/ets/domain/usecases/loadChatAccess.ets`
- `entry/src/main/ets/ui/pages/chat/ChatInputPanelPolicy.ets`
- `entry/src/main/ets/ui/pages/chat/ChatAccessController.ets`
- `entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets`
- `entry/src/main/ets/ui/tg_ui/atoms/TgComposerInput.ets`
- `entry/src/main/ets/ui/tg_ui/demos/TgComposerInputDemo.ets`

Native: новый `SupergroupBoosts.test.ets`, registry `List.test.ets`, fixture `LiveChatPermissions.test.ets` под `entry/src/ohosTest/ets/test/`.

Host: новый `scripts/test-supergroup-boosts.cjs`; обновлены `test-chat-access-controller.cjs`, `test-chat-input-panel.cjs`, `test-live-chat-permissions.cjs`, `test-basic-group-access.cjs`, `test-basic-group-media.cjs`. Синхронизированы composer passport и компактные project status/plan/lesson pointers.

## Demo / diff / открытые gates

Открыть `entry/src/main/ets/ui/tg_ui/demos/TgComposerInputDemo.ets` в DevEco Preview (`TgComposerInput`), case **19**: partial failure, Retry, сохранённый draft. Нажатие меняет только demo state, без сети. Новый native Button имеет id `tg_composer_access_retry` для будущего device witness. Работающий legacy/composer fallback не удалён.

Unified UI diff: `docs/reviews/2026-09-06-reliability-wave11-composer-cumulative.patch`. Это честно **накопленный diff двух UI-файлов к текущему Git index**, включающий прежние незакоммиченные изменения; не изолированный diff только Wave11 и не инструкция применять его поверх нынешнего дерева.

Не закрыты: real device/Hypium run, новый visual witness (light/dark/keyboard/focus/touch zones), source-forward eligibility, group edit eligibility/expiry и left discussion/thread exceptions, migration/Delete CTA, оставшаяся функциональная полнота, сравнительная iOS reliability и публикационная готовность. В Wave11 новых emulator boots/install не делалось; предыдущий системный SceneBoard blocker не исправлен и не маскируется host-тестами. Следующий reliability-срез — source-forward eligibility; runtime диагностика только с новым различающим измерением, не одинаковым coldboot.

Нет реальных sends, boost purchasing/applying, account actions, commit/push/deploy/publication. Глобальные prompts/memories не менялись.

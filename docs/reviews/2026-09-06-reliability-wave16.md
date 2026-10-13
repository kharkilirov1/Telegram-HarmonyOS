# Reliability Wave16 — account ownership страницы чата

Дата: 2026-09-06. `dev@faf66b3`, незакоммиченный рабочий tree.

## Результат

**Исправлены межаккаунтный closeChat, восстановление чужого draft, stale navigation cleanup и повторная привязка уже существующей страницы A к B.** При повторном appear сохранённый текст A больше не отправляется в B через вновь связанный runtime.

**49/49 focused host checks; 33 CJS suites, 38 PowerShell + UI-smoke, исходный review 8/8. Final main и ohosTest compile прошли последовательно; 65 source/resource hashes стабильны.**

Это проверка конкретного lifecycle-среза, **не доказательство полной account isolation или надёжности уровня iOS**. Первый delayed route, overlapping same-chat pages и native open-count ownership остаются открыты.

[Машиночитаемое evidence](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-06-reliability-wave16-evidence.json) · [Следующий route-ownership план](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/TASKS/CHAT_ROUTE_OWNERSHIP_PLAN.md).

## Дефекты и наблюдаемый delta

| Сценарий | До | После |
|---|---|---|
| Disappear A после переключения на B, одинаковый chatId | Parent probe: 32 прежних PASS + 2 FAIL; close отправлялся через global adapter B | Captured client/account capability; при смене scope закрытие не переходит в B |
| Restore A/global B; restore без owner | После первого close patch лично получены 17 PASS / 6 FAIL: 3 restore + 3 navigation | Чтение только через связанный accountStore; recheck до записи текста/entities/reply |
| Old A teardown стирает B navigation/visibility; старый chat 7 стирает новый 8 | Три воспроизведённых FAIL | Current account + scoped lifetime + chat ownership перед clear/visibility/Back |
| Первый navigation guard запретил Back после удаления chat из cache | Отдельный parent probe: 32 PASS + 1 FAIL | Проверяется scope generation, не наличие chat; удалённый chat можно закрыть |
| Повторный appear переводит retained A composer на B | Parent probe: 0 PASS / 1 FAIL, зафиксирован draft request B | Persistent routeAccountStore переживает disappear; другой/revoked scope не перепривязывается |

Исходный baseline субагента был 12 PASS / 11 FAIL; он не выдаётся за отдельный повторный прогон основного агента. Parent independently reproduced close, промежуточные 6 failures, deleted-chat regression и reappear breach.

Изначальный reappear probe представлял уже связанную A-страницу fixture. Финальные regression/mutation проверки исполняют **полный первый aboutToAppear**, затем switch/disappear/reappear — это более сильное подтверждение пути.

## Реализация

- `aboutToAppear` один раз захватывает runtime store и gateway **до** sync/restore. Все создаваемые use cases используют тот же adapter. Scope проверяется до и после acquisition.
- `routeAccountStore` — identity на весь срок жизни компонента. Поле не очищается при disappear; повторный компонент не может принять account B с retained state A. Это не заменяет provenance первого navigation intent.
- `aboutToDisappear` использует captured `chatGateway`, не получает новый глобальный adapter. Повторное закрытие не повторяет lastOpenedChatId. Устаревший native generation отсекается самим реальным TdGatewayAdapter.
- `restoreDraftFromChat` читает accountStore, проверяет runtime/owner/chat/lifecycle до записи. Nonempty/edit/forward buffers не заменяются. Порядок entities → text → selection → reply сохранён.
- `AppStore.isScopeCurrent()` сделан публичным без изменения generation semantics. Это отличает valid account с удалённым chat от revoked scope с пустым snapshot.
- `ownsNavigationContext` защищает global cleanup и Back от другого аккаунта/другого чата. **Две страницы одного account/chat он ещё не различает**: для этого нужен unique navigation owner в следующем срезе.
- Старый draft mutation harness ограничен фактическим телом persistDraft: новые restore guards не должны случайно менять число mutation sites.

## Проверка intended path, не fallback

Новый self-contained harness исполняет полные реальные page methods, AppStore scopes и generation-fenced adapter. Native transport, runtime lookup, timers, unrelated UI/media teardown и presentation fixtures — явные границы. Тест полного appear проверяет достижение последнего `bindWindowSizeListener`, отсутствие swallowed initialization error, порядок owner binding и один gateway для всех factories.

| Negative control | Engaged sites | FAIL |
|---|---:|---:|
| close-owner → прежний global dispatch | 1 | 7 |
| restore-owner → global state/отключённые owner guards | 4 | 6 |
| navigation-owner → guard всегда true | 1 | 6 |
| reappear-owner → убран lifetime owner check | 1 | 4 |

Все четыре результата лично воспроизведены; normal run 49/49. Focused reappear: 7/7; исторический CLI alias `--known-gap=reappear` теперь требует PASS и не скрывает failure. Сохранённый Wave15 account-draft mutant: 2 sites, 1 FAIL; обычный draft suite 32/32.

## Сборки и полнота свидетельства

- 33 CJS suites: все exit 0; новый lifecycle suite 49/49.
- 38 PowerShell/UI-smoke; исходный review 8/8; syntax 34 CJS — PASS.
- **Accepted main:** CompileArkTS **52 s 766 ms**, BUILD SUCCESSFUL **1 min 20 s 264 ms**.
- **Accepted ohosTest:** OhosTestCompileArkTS **24 s 211 ms**, BUILD SUCCESSFUL **50 s 807 ms**.
- Accepted builds выполнены **последовательно**, после production freeze. До/после — одинаковые 62 ArkTS + 3 resource hashes накопленного dirty tree. От Wave15 production delta только в двух файлах.

Первые две сборки ошибочно пересеклись по времени; затем изменился source. Хотя обе завершились exit 0, **они не использованы как acceptance evidence**: обе дождались terminal state, затем main/ohosTest полностью пересобраны последовательно. Сборки не названы warning-free.

Новых Hypium suites в этом срезе не добавлено. Host execution page methods и native compilation **не являются запуском native тестов или приложения на устройстве**.

## Grounding и критика

CPL HTTP context timeout 2 s → known-source fallback. `harmonyos_docs`: component/page lifecycle, onReady/aboutToAppear. Это grounding API, не доказательство реально произошедшего callback interleaving.

Лично прочитаны:
- [TDLib MessagesManager.cpp](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/telegram/MessagesManager.cpp): 16407–16419 увеличивает open_count; 16521–16544 уменьшает его и выполняет closing effects на нуле.
- [iOS ChatController.swift](C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Sources/ChatController.swift): immutable AccountContext на 252; сохранение interface state через self.context.engine на 8040–8044.

Независимый reviewer нашёл более широкий contract gap: caller делает open, page лишь присваивает lastOpenedChatId; route params не несут source account. Его narrow review предшествовал последнему persistent-owner дополнению; финальное дополнение проверено parent regressions/mutations и пересборкой, не выдано за повторное независимое review.

## Эмулятор и остаточный риск

Свежий HDC: **[Empty]**. Новых boots/install/account actions не было. Предыдущее [Wave10 свидетельство](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-06-reliability-wave10.md): SceneBoard timeout → kernel panic до установки Telegram; причина ОС не установлена. [Empty] сейчас не считается новым crash reproduction.

Следующий обязательный срез — [CHAT_ROUTE_OWNERSHIP_PLAN](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/TASKS/CHAT_ROUTE_OWNERSHIP_PLAN.md): captured account до async push, единый route context, корректная граница onReady, unique navigation owner, один acquired open/release и сохранённая history/unread initialization. Все три callers найдены: ChatList, Archive, Forward.

Открыты также edit entry/prior compose restoration, rich-text/dynamic limits, thread/expiry/special actions, runtime/visual/soak и publication gates. Общая цель остаётся активной.

## Изменённые файлы

- [AppStore.ets](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/core/store/AppStore.ets) — публичная проверка scope generation.
- [TgChatScreenPage.ets](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets) — account/client binding, lifecycle identity, restore/close/navigation guards.
- [test-chat-lifecycle-account-scope.cjs](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-chat-lifecycle-account-scope.cjs) — 49 focused cases, четыре mutations, полный appear/reappear.
- [test-chat-draft-account-scope.cjs](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-chat-draft-account-scope.cjs) — actual owner method в fixture и scoped mutation anchor.
- Рабочие STATUS/TODO/LESSONS, access/parity/route планы, этот report и evidence. Старые незакоммиченные изменения сохранены; commit/push/install не выполнялись.

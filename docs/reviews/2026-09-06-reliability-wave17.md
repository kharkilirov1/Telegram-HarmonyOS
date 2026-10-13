# Wave17 — route/account ownership и проверка границ

**Усилены маршруты и lifecycle чата; основные host/source suites и последовательные main/ohosTest сборки проходят. Полная надёжность ещё не достигнута: отдельно воспроизведены P2 позднего unread snapshot и native-count counterexample. Эмулятор сейчас отсутствует в HDC.**

Ветка `dev@faf66b3`; существующий dirty working tree сохранён. Измерения: [evidence JSON](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-06-reliability-wave17-evidence.json).

## Исправлено и лично перепроверено

- Единый immutable route context захватывает account scope, gateway, chat ID/title и уникальный navigation token **до** deferred callback/push. Stale route не импортирует новый аккаунт.
- Page не выполняет account effects до valid route binding. Старый экземпляр того же account/chat не очищает globals, visibility или Back state нового владельца.
- Три caller-open удалены одновременно с переносом логического open/release в route lease. Strict `TdObject/ok`, single attempt, pending release, captured gateway; ошибки не воспроизводятся автоматическим retry.
- Forward handoff привязан к target route token. Поздний picker callback не перехватывает новый navigation owner; rollback очищает только свой payload.
- History dispatch/continuations проверяют актуальность route scope. Captured unread boundary не исчезает после раннего read-inbox reducer update, если chat уже известен к open acknowledgement.
- Source assertions перенесены с старого global unread/pendingItem на canonical route; exact returned ID и captured owner проверки сохранены.

### Измеренные дельты

| Witness | До | После |
|---|---:|---:|
| Route-less appear / same-chat replacement owner | 49 PASS / 2 FAIL | включены в 86/86 lifecycle |
| Pending forward route ownership | 2 PASS / 7 FAIL | 9/9 |
| History после scope invalidation/reset | 80 PASS / 3 FAIL | включены в 86/86 lifecycle |
| Missing-cache chat известен **до Ok**, read update до history | 85 PASS / 1 FAIL | 86/86 |
| Старые PS source contracts | 36 PASS / 2 FAIL | 38/38 |

Последний исправленный сценарий реально проходит `openChat → viewMessages → reducer → getChatHistory`: ожидаемые `from=303, offset=-10, limit=60` вместо `0/0/50`.

## Проверки

- Стандартные **36 CJS suites**, **38 PS + smoke**, **37 syntax checks**, review **8/8** — PASS.
- Focused: lifecycle **86/86**, draft **32/32**, callers **69/69**, logical lease **78/78** (55 host + 23 actual Hypium bodies через host), pending forward **9/9**.
- 11 negative controls действительно изменяют исполняемый путь и завершаются exit 1: lifecycle **21/6/13/2**, draft **1**, callers **1/1/3**, lease **30/47/21** assertion failures. Это не ошибки normal suites.
- Final main: CompileArkTS **1m07.726s**, build **1m44.489s**.
- Только после terminal main exit 0 запущен final ohosTest: CompileArkTS **27.076s**, build **56.357s**.
- До/после обеих сборок совпадают **72 hashes: 69 ArkTS + 3 resource JSON**. Это cumulative changed-source set, не hash всего репозитория. Exploratory builds не приняты как final evidence.
- `git diff --check` PASS; три локализованных resource JSON читаются, новый toast key присутствует по одному разу.

**Ограничение зелёных suite totals:** дополнительный probe следующего раздела отдельно завершился FAIL и не спрятан внутри этих totals. Native Hypium bodies через host и компиляция не равны исполнению на устройстве. HAP unsigned; signing не настраивался.

## Открытые findings — следующий срез

### P2: chat появляется только после open Ok

Лично воспроизведено через actual page/store/lease host fixture: route создан без cached chat; Ok приходит раньше первого chat state; затем появляется unread=3/boundary303. Page уже сохранила default initial snapshot. Цепочка `openChat → viewMessages → getChatHistory` отправляет **0/0/50**, а не **303/-10/60**. Probe exit **1**, sourceStable=true; воспроизводимая команда сохранена в evidence JSON.

Следующий patch должен отличать «первого owned chat ещё нет» от «owned chat действительно без unread», захватывать snapshot до read и проверять оба порядка доставки, включая появление после первого history запроса. **History/unread parity gate остаётся OPEN.**

### Native open_count не принадлежит отдельному acknowledged lease

В локальном TDLib `openChat → Ok` возможен без increment при отсутствии Read access. Source-derived модель: A/noRead→0; B/Read→1; release A→**0 при живом B**. Модель исполнена, но это **не native runtime test**.

[Подробный контрпример и критерии coordinator](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-06-native-open-count-gap.md). Нужны session identity, all-holder coordination и определённая стратегия unknown outcomes; просто coalescing opens или перенос release в onHidden не доказывают безопасность. **Native-count gate OPEN.**

Shared media/jump/search globals, edit entry/prior compose restore, rich-text/dynamic limits и device/visual/iOS parity также не объявлены закрытыми.

## Эмулятор

Свежий `hdc list targets`: **[Empty]**. В этом срезе новых boot/install нет. В [Wave10](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-06-reliability-wave10.md) сохранены три isolated API24 boots, реальный HDC shell, SceneBoard lifecycle faults и kernel panic **до установки Telegram**. Эти файлы проверены на наличие; сам crash заново здесь не воспроизводился. Причина OS slowdown всё ещё не доказана. Профили и account data не сбрасывались.

## Файлы и grounding

Основные изменения: [route params](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/ChatScreenRouteParams.ets), [lease](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/domain/usecases/ChatOpenLease.ets), [page](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets), [forward controller](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/ChatMessageActionsController.ets), [handoff](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/PendingForwardTransfer.ets), ChatList/Archive callers, NavigationUIState/AppStoreBridge, три locale resources, четыре native test/registry файла. Полные 16 source/resource paths относительно projectRoot перечислены в evidence; обновлены также 7 CJS harnesses и 2 PS contracts.

Работали три субагента; основные результаты и найденные ошибки перепроверены родителем. CPL HTTP retrieval timeout → точный source fallback. `harmonyos_docs`: onReady/NavDestinationContext и getParamByIndex/NavPathStack. iOS immutable AccountContext — behavioral reference, не доказательство native counter policy. Версии обоих reference checkout сохранены в evidence.

Следующий маршрут: [CHAT_ROUTE_OWNERSHIP_PLAN](C:/Users/Kharki/Desktop/Telegram-HarmonyOS/TASKS/CHAT_ROUTE_OWNERSHIP_PLAN.md). Общая цель reliability → UI → features → publication остаётся **активной**, без объявления iOS-equivalence или готовности к публикации.


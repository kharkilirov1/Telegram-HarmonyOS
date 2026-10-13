# R10 — independent read-only review, 2026-09-27

## Finding 1: narrow implementation, frozen после GREEN

После отдельного разрешения пользователя исправлено **только владение jump**. Изменённые файлы этого среза:

- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets:370,855-887,930-949` — один монотонный `jumpRequestToken`; guards в then/catch и отложенном 16ms fulfillment. A→B→A различается по token, не только по messageId. Lifecycle guard сохранён.
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-chat-jump-ownership.cjs` — новый постоянный focused acceptance, 21 случай.
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-27-history-independent-review.md` — этот раздел отчёта.

**Loaded-target boundary проверена отдельно:** до исправления после A→visible B оба сценария (`reset-queued`, `inflight`) оставляли real store с `[90,100,110]` вместо B. Поэтому простой UI-token revoke недостаточен: при существующем pending intent loaded B проходит через уже имеющийся `loadAroundMessage(B)`, отзывая history window A. Без pending intent loaded target по-прежнему прокручивается без gateway send. Domain API и domain-файлы не менялись этим срезом.

```text
node --disable-warning=ExperimentalWarning C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-chat-jump-ownership.cjs
RED before production patch, exit 1:
FAIL same-turn 100->500: stale false cannot clear current intent
'' !== '500'
FAIL accepted rejection then 100->500->100: stale page catch is fenced
'' !== '100'
FAIL A->B->A: old 16ms callback cannot fulfill a new same-ID intent
'' !== '100'
FAIL real loaded-B store survives superseded A reset-queued response
'100' !== '500'
RESULT 7/21 passed; 14 failed; 17 production source hashes stable

GREEN, same 21 cases unchanged, exit 0:
RESULT 21/21 passed; 0 failed; 17 production source hashes stable
PAGE_SHA256 530921498a162e09cc15cd803248a47da01d5769e2fb7babb709dab94f59018c
HISTORY_SHA256 b1562e82a1e5e9db91dd8a11826479fe6c601681d6f4d7b43b3660fd36315998
```

Исполняются полные actual page methods `scrollToMessageId`, `jumpToMessageId`, `fulfillPendingJump`, `scheduleLifecycleTask`, настоящий timeline predicate, History/AppStore/normalizer/reducer. Подменены transport, viewport/scroll/flash sinks, timers, unrelated normalizers. Stale page.catch упражняется настоящим accepted History rejection **до** superseding microtask (проверен History error branch), а не заменой `loadAroundMessage`. Старый timer запускается до promise completions, отдельно доказывая именно 16ms token guard. Есть controls для current success/false/rejection и lifecycle change.

**Сохранность чужих правок:** reverse только семи собственных hunks в памяти воспроизвёл точный pre-edit dirty-page SHA256 `7b3fde1ec0cec386a69036912dad9747be55e81039f4fd7079bf42d26d6e30ea`. Иных page formatting/fields/methods не менял. `node --check` и scoped `git diff --check`: exit 0.

**Соседние проверки на том же History SHA:** history-generation **33/33 PASS**. Lifecycle suite при проверке дал **103/106, exit 1**, `sourceStable:true`, без swallowed/unhandled failures; не объявляется GREEN. Не прошли:
1. `Wave18: one correction after first state with default pending`;
2. `Wave18: one correction after first state with default completed-cached`;
3. `Wave18: default cached before state still preserves first boundary before mark-read reducer clears it`.

Во всех трёх ожидался второй history payload `['303', -10, 60]`, наблюдался только `['0', 0, 50]`. Причина этим срезом не локализована; файл suite не менялся. Требует проверки main/Ohm, которые владеют domain fixes 2/3 и общей интеграцией. Native builds/HAP/commits/push не выполнялись. Production-патч jump после GREEN не расширялся; build/device acceptance остаётся у main.

## Исходный read-only аудит (до отдельного разрешения на finding 1)

Ниже только новые обнаруженные defects/acceptance gaps. Production/test файлы не изменялись; legacy unread fixture не запускался и не дублировался; native build не запускался.

Проверенный history SHA256: `0b1f23782fd48e9c7dea42a5be994d5eb2c6ebd54592abfceb9c0b564018d70d`.
Лично повторён `node --disable-warning=ExperimentalWarning C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-chat-history-generation.cjs`: **22/22 PASS, exit 0**, 15 production hashes stable. Дополнительные probes выполнялись из stdin, без сохранения scripts: reuse fixture/loader данного теста, реальные History/AppStore/reducer/normalizer. Для первого finding дополнительно исполнен неизменённый production `jumpToMessageId()`; только viewport lookup заменён на «target not loaded».

## 1. [P2] Старый jump completion стирает новый UI target

Связка `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/domain/usecases/loadChatHistory.ets:653-667,696-699` → `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets:863-879`.

History корректно возвращает `false` для отозванного jump A, но `.then(!ok)` страницы проверяет только page lifecycle, не ownership jump. После A→B lifecycle тот же: A очищает `pendingJumpMessageId`, уже принадлежащий B. `fulfillPendingJump()` на строках 924-926 тогда немедленно выходит; B загружает нужный диапазон, но финальный scroll/highlight target потерян.

Лично воспроизведено двумя настоящими вызовами page method: `jumpToMessageId('100')`, затем `jumpToMessageId('500')`. Проверены same-turn и уже отправленный A, завершившийся до B:

```text
JUMP_OWNERSHIP {"timing":"same-turn","targetRequest":"500","pendingTargetBeforeTargetResponse":"","requests":1}
JUMP_OWNERSHIP {"timing":"in-flight","targetRequest":"500","pendingTargetBeforeTargetResponse":"","requests":2}
JUMP_AFTER_RESPONSE {"timing":"in-flight","pendingTarget":"","ids":["490","500","510"]}
READ_ONLY_PROBES_COMPLETED sourceStable=true
```

**Acceptance gap:** существующий multiple-jumps test проверяет store/window, но не потребителя нового `false` результата. Нужен per-jump token/ownership у UI completion (также A→B→A, а не только сравнение messageId); stale `.then/.catch` не должны очищать актуальный target. Это интеграционный gap R10, не предложение ослабить generation guard.

## 2. [P2] Late `aroundUnread` correction всё ещё смешивает два разорванных окна

`C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/domain/usecases/loadChatHistory.ets:636-639,676-679` заменяет окно только при `reason === 'aroundMessage'`. Реальная поздняя коррекция initial fallback в `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets:4940-4952,4980-5014` использует `aroundUnread`.

Probe: обычный initial `[970,980,990,1000]` завершён → настоящий `execute({direction:'initial', reason:'aroundUnread', fromMessageId:'100', offset:-2, limit:4})` → ответ `[110,100,90]`.

```text
CURRENT AROUND_UNREAD_AFTER_DEFAULT
ids=[100,1000,110,90,970,980,990] oldest=90 newest=1000
HEAD_BASELINE AROUND_UNREAD_AFTER_DEFAULT
ids=[100,1000,110,90,970,980,990] oldest=90 newest=1000
```

Между 110 и 970 остаётся незагруженный разрыв, но newer pagination стартует с 1000 (`TgChatScreenPage.ets:2710-2723`), older — с 90. Контракт одного непрерывного окна не выполнен; диапазон пропускается обоими курсорами.

**Классификация:** воспроизведён также на `git show HEAD:.../loadChatHistory.ets`, поэтому это не новый regression от патча, а незакрытый acceptance gap смежного late-correction пути. Не совпадает с известной заменой monkeypatch-execute fixture. Нужна проверка actual message map/cursors после default→aroundUnread correction, в том числе при outstanding older/newer; одного правильного request payload недостаточно.

## 3. [P3, non-blocking] Initial completion перезаписывает exhaustion своего older top-up

`C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/domain/usecases/loadChatHistory.ets:685-689,714` после дочернего older top-up повторно вызывает `refreshPaginationState` с initial response. На строках 301-313 непустой initial безусловно выставляет `canLoadOlder=true`, хотя top-up только что выставил `false` для empty/no-progress.

Probe: initial limit=4 → `[1000,990]` → автоматически отправленный top-up from=990 → `[]` либо `[990]` → дождаться initial:

```text
TOPUP_EMPTY      oldest=990 newest=1000 older=true loading=false
TOPUP_NOPROGRESS oldest=990 newest=1000 older=true loading=false
```

Empty-case также воспроизведён на HEAD baseline: существующий дефект, не regression патча. Следующий scroll/recheck лишний раз запросит уже исчерпанную границу. Положительный top-up test не проверяет сохранение отрицательного pagination результата дочернего запроса; добавить такой acceptance case при следующем изменении top-up policy.

## Граница проверки

Проверены source-level lifecycle/window/bucket ownership, queued dispatch/finally и runtime reset callers. Сценарий `invalidateScopes()` без обязательного `History.resetState()` не объявляется production-дефектом: реальные shutdown/recovery callers выполняют оба действия; это отдельный контракт. Прочитаны локальный TDLib `getChatHistory` contract (`C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/generate/scheme/td_api.tl:10552-10560`) и `harmonyos_docs` Async/Await. Device/UI rendering и ArkTS compile не проверялись. Единственная файловая запись — этот отчёт.

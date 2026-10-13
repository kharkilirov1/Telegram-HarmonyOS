# R10 — LoadChatHistory: jump и владение окном

## Результат

Исправлены lost jump при inflight initial, смешивание окон при jump **и поздней aroundUnread correction**, а также перезапись exhaustion дочернего top-up. Host RED→GREEN наблюдался на настоящем production use case. DevEco/hvigor, устройство и HAP не запускались. Production после follow-up снова заморожен.

## Follow-up независимого ревью: findings 2/3

Основание: `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-27-history-independent-review.md`. Finding 1/page jump ownership вне этого slice; page не менялся.

- `initial + aroundUnread` заменяет **уже fetched окно**, если primary свободен. Используется тот же generation/reset/queue guard, что и для jump; старые older/newer теряют владение. Первый aroundUnread сохраняет live cache, inflight primary по-прежнему дедуплицируется, correction повторяется существующим page flow после завершения fallback. Offset/limit и запрет default top-up для aroundUnread сохранены.
- Для короткого default initial pagination flags теперь устанавливаются **до** top-up. Итоговый empty/no-progress результат дочернего older не перезаписывается initial completion; rejected top-up оставляет older retryable и не мешает публикации initial batch.
- Добавлены 11 actual-production случаев: disjoint default→aroundUnread map/cursors; simultaneous older/newer success/empty/failure поверх новых buckets; first/inflight unread semantics; queued stale batch; correction failure/retry; empty/no-progress/rejected top-up.

Лично наблюдённая последовательность, одна production-причина за шаг:

```text
RED (до follow-up): RESULT 24/33 passed; 9 failed; exit 1
  correction must not combine disjoint windows:
    actual [100,1000,110,90,970,980,990], expected [100,110,90]
  new window must have fresh older and newer reservations: 4 !== 6
  initial must not overwrite its top-up exhaustion: true !== false
P2 fix only: RESULT 31/33 passed; 2 failed; exit 1
  остаются только empty/no-progress top-up exhaustion
P2 + P3: RESULT 33/33 passed; 0 failed; 15 production source hashes stable; exit 0
HISTORY_SHA256 b1562e82a1e5e9db91dd8a11826479fe6c601681d6f4d7b43b3660fd36315998
```

Текущие соседние проверки: runtime **6/6**, unread-routing **43/43**, `git diff --check` и `node --check` — exit 0. Legacy routing fixture уже исправлен основным агентом, здесь не менялся.

**Fixture integration закрыта:** основной агент добавил `ChatMessagesResetEvent: load('core/model/AppEvent.ets').ChatMessagesResetEvent` в history loader `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-chat-lifecycle-account-scope.cjs:269`, без изменения expectations. Прежние **103/106** были вызваны тремя `ReferenceError` отсутствующей fixture dependency; это ранее подтверждено двухмаршрутной in-memory проверкой. После постоянной правки лично повторён **actual script с диска: 106/106, exit 0, sourceStable:true, failures:[]**. Production SHA256 остался `b1562e82a1e5e9db91dd8a11826479fe6c601681d6f4d7b43b3660fd36315998`; в этом closeout изменён только собственный отчёт. Полный ArkTS/native build остаётся за основным агентом.

## Изменения (только этот slice)

- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/domain/usecases/loadChatHistory.ets` — per-chat window generation в существующей reservation; jump синхронно отзывает все три направления и резервирует primary **до** reset/уведомления listeners. Reset и history batch получают существующий `AppStore.shouldProcess` guard. Response, top-up loop, continuation, failure и finally проверяют lifecycle + window + bucket sequence. Новый window очищает fetched/cursors/edges. Отозванный store scope и старый use case не могут запустить reset.
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-chat-history-generation.cjs` — deferred transport и управляемая очередь **настоящего** AppStore; настоящие `LoadChatHistoryUseCase`, команды, `TdObject`, accessors, DTO parser, EventNormalizer/MessageNormalizer, messagesReducer. Методы use case не заменяются. 33 случая, ограничение зависания 1500 ms, проверка неизменности 15 production sources.
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/docs/reviews/2026-09-27-chat-history-generation-fix.md` — этот отчёт.

Pages/controllers, STATUS/TODO/LESSONS, чужие dirty changes не изменялись. Commits/push отсутствуют.

## Первоначальный RED / GREEN до follow-up (Node v24.12.0)

Команда: `node C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-chat-history-generation.cjs`.

**RED, до production patch, exit 1:**

```text
FAIL jump during initial load issues target request; old finally keeps new loading
AssertionError: jump must issue its own request despite an occupied initial bucket
1 !== 2
FAIL stale older nonempty response cannot alter new window
AssertionError: a superseded response is not a successful history load
true !== false
FAIL stale older failure cannot release a new older reservation
AppError: Failed to load history for chat 1
FAIL same-turn jumps fence queued reset and reserve primary before notifying listeners
AssertionError: superseded queued reset must not reach reducer/listeners
2 !== 1
RESULT 5/21 passed; 16 failed; 15 production source hashes stable
HISTORY_SHA256 b8b9402f23788d902005bf51c4c5a93f53bc1ffaf37568120ee2fdd529598b3b
```

**GREEN, те же 21 случая после production patch, exit 0:** `RESULT 21/21 passed; 0 failed`. Затем добавлен положительный случай negative chat ID: reset до **реального gateway.send**, immutable prior snapshot и фактическая нормализация ответа — без monkeypatch `execute`.

**GREEN первого среза, exit 0 (актуальный follow-up выше):**

```text
PASS negative chat ID: real jump resets store before transport, without replacing execute
PASS jump during initial load issues target request; old finally keeps new loading
PASS already queued old dispatch is rejected inside the actual serial AppStore queue
PASS initial top-up and deferred first batch both lose ownership on jump
PASS revoked store scope rejects response, static cursor writes and new jumps
RESULT 22/22 passed; 0 failed; 15 production source hashes stable
HISTORY_SHA256 0b1f23782fd48e9c7dea42a5be994d5eb2c6ebd54592abfceb9c0b564018d70d
```

Также покрыты пустые/stale older+newer responses, stale failure/finally поверх нового bucket, multiple jumps и same-turn resets, failure→retry того же target, fetched-cache после reset, рабочий initial top-up, независимость направлений/чатов и shared ownership между экземплярами, runtime reset с повторным chat ID, invalid inputs.

## Соседние проверки первого среза (исторические, до follow-up)

- `node C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-chat-lifecycle-account-scope.cjs`: **106/106, exit 0**, `sourceStable:true`. В том числе actual late-first default pending/completed/rejected → aroundUnread correction. Эти ветви/page не менялись.
- `node C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-app-core-runtime.cjs`: **6/6 PASS, exit 0**.
- Независимый read-only reviewer: bounded LGTM, конкретных production-регрессий не найдено; согласен перенести устаревший routing-test boundary на transport, не менять production ради stub. Его дополнительные in-memory проверки не включены в приведённые лично воспроизведённые числа.
- `git diff --check -- entry/src/main/ets/domain/usecases/loadChatHistory.ets`: **exit 0** (только предупреждение Git о LF→CRLF).
- `node C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-unread-count-routing.cjs`: **42/43 PASS, exit 1**, `0 swallowed errors`. Единственный FAIL — `actual loadAroundMessage resets the old window before requesting the new one`, assertion `true !== false` на строке 294. Тест на строках 292–301 заменяет весь `useCase.execute` и проверяет внутреннюю границу вызова, поэтому исключает теперь находящийся внутри execute reset. Production-семантика «reset до transport» независимо подтверждена новым negative-ID тестом. Основному агенту требуется перенести fixture boundary этого старого теста на gateway.send; файл оставлен без изменений как вне write scope. Не объявляю все соседние suites зелёными.

## Контракты и ограничения

- Прочитаны AGENTS/STATUS/DECISIONS/REFERENCES, architecture/current plan и historical `git show origin/codex/architecture-hardening-plan-2026-09-26:scripts/review/2026-09-26/state_usecases.cjs`.
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/tdlib/td/generate/scheme/td_api.tl:10552–10560`: reverse chronological messages, negative offset для newer, TDLib вправе вернуть меньше limit. Existing offset/top-up policy сохранена.
- `harmonyos_docs.search_harmonyos_docs("async await Promise ArkTS", en)` — официальная Async/Await документация; проверены Promise continuations/rejection handling. `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Sources/ChatHistoryListNode.swift:1454–1508` — versioned history view / location signal как source reference; Swift-код не переносился.
- Runtime обязан вызывать `LoadChatHistoryUseCase.resetState()` при shutdown/session reset; generation-map очищается вместе с существующими статическими caches.
- Host harness не является ArkTS compile, native TDLib/device/UI witness. Сборку и финальную интеграционную проверку выполняет основной агент. Сеть не отменяется: устаревшие ответы логически теряют владение окном и возвращают `false`.

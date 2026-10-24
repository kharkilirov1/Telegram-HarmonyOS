# Client retirement — reliability-срез 2026-09-28

Предыдущий goal turn: progress — async stop source/host/compile,54 host suites и обе сборки подтверждены. Полная production parity цель остаётся активной.

## Baseline / требования
- Diagnostic `audit-td-client-lifetime.cjs --strict`:4 findings, exit1. Startup выделяет ID до готового receive; destroy забывает owner на close timeout.
- Сначала создать receive path, потом integer client ID. Ошибка запуска не должна создавать сирот; уже запущенный/частично запущенный receiver всё равно ждёт stop barrier.
- Только current-client публичный authorizationStateClosed доказывает native manager release. Ok/null receive/stop этого не доказывают.
- Timeout отдаёт понятную ошибку, но сохраняет destroying/ID/close-only receive path. Старые account capabilities остаются отозванными; новый create запрещён.
- Late Closed завершает retirement и native stop без зависимости от уже отключённого app dispatcher. Ошибка самого stop требует explicit retry, не бесконечного автоматического цикла.
- Closed без Ok завершается по Closed; singleton/retry/concurrent shutdown остаются сериализованы.

## Scope / ownership
Parent: TdGateway и последующая адаптация existing gateway/stop tests + diagnostic audit. Worker1: новый client-retirement witness. Worker2: Runtime lifecycle analysis и при подтверждённой необходимости AppCoreRuntime + новый runtime witness. Затем fresh reviewer, focused→full host/static→serial builds→hashes.

Никаких emulator install, account/mic/messages, reset/clean/commit/push. TSFN enqueue/env teardown и dialog open_count остаются отдельными requirements, не закрываются клиентским host fixture.

## Выполнено / дополнительный reviewer P1
- Gateway start-before-create, retained close-timeout owner, private late-Closed route и shared shutdown; Runtime explicit retry, initialize gate, reentrant shared shutdown/reset с сохранением singleton при ошибке.
- Strict manager audit: 6 controls/4 findings → 10 controls/0 findings. Gateway 24/24+8 mutations; Runtime 13/13+7; existing gateway45/45 и stop11/11+4.
- Независимый reviewer нашёл потерю единственного queued Closed при recovery failure. Parent повторил до/после: destroying/clientId2/stop0 → idle/clientId0/stop1. Исправление сохраняет очередь и generation, переустанавливает bounded drain; reviewer suite13/13+3 проверяет batch/single/partial, foreign ID и stale ordinary traffic после немедленного retry. Повторное ревью не нашло новых findings в этом scope.
- Выбран generation-tagged drain; отвергнуты reset очереди (теряет Closed), сохранение без rearm (старый timer не исполняет drain) и сохранение без generation guard (оживляет stale updates). Возврат к иной реализации — только при контрпримере, не ради cleanup.
- Итоговые сборки, общий gate, hashes и оставшиеся границы фиксируются в `docs/reviews/2026-09-28-client-retirement-remediation.md` и соседнем evidence JSON. Полная project goal остаётся активной.

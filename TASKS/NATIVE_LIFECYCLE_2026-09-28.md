# Native lifecycle — reliability continuation

Предыдущий goal turn — progress: account/page media ownership и53 host suites/final builds подтверждены. Полная production parity цель остаётся активной.

## Порядок и основания

1. Сначала убрать synchronous join с ArkTS thread и провести await-barrier до gateway shutdown/retry. Это lifecycle-основание для дальнейшего безопасного enqueue/teardown, не замена полной native цели.
2. Enqueue ownership отдельно сопоставить с SDK contract: generic failure может быть после queue insertion. Нельзя добавлять delete на любой non-ok. Реальный installed binary не приравнивается к upstream master.
3. Проверить точное значение TDLib open_count и клиентские close paths по локальному исходнику; не чинить счётчик по названию.

## Gate для выбранной async-stop реализации
- [x] Host RED: до patch15PASS/5FAIL — stop не возвращается до окончания заблокированного td_receive.
- [x] Native stop возвращает Promise; join выполняется в NAPI async worker, resolved только после join producer. Это не TSFN-finalization barrier.
- [x] Concurrent/late stop, busy/cross-env start, queue/create/cancel failure и повторный stop проверены без double join/false Stopped.
- [x] Thread construction failure откатывает Running/TSFN lease; отдельная boundary injection, не OS exhaustion.
- [x] ETS gateway ждёт stop при destroy/init failure; invalidation синхронная, pending/rejected stop блокирует retry create/start.
- [x] Independent review; native32/32+injected34/34+5 controls, ETS11/11+4;54 host/38PS+Bash, обе serial builds;777 stable hashes. Отчёт `docs/reviews/2026-09-28-native-stop-remediation.md`.

## Следующие незакрытые lifetime gates
- [ ] Startup failure/close timeout: сохранять owner ID до подтверждённого Closed; `audit-td-client-lifetime.cjs --strict` сейчас6 controls/4 findings, exit1. Не терять ID после одного consumer stop.
- [ ] App-owned enqueue payload lifetime и полный env teardown; не считать non-ok гарантией непринятого payload.
- [ ] Реальный баланс dialog openChat/closeChat: Dialog::open_count не число TDLib clients и не поддержанная getOption.
- [ ] Device/native SDK acceptance после согласованного обновления emulator HAP.

## Границы

Parent владеет C++/native harness; gateway worker — TdGateway/types/новые focused tests; SDK contract worker — только scoped research report. Никаких emulator install, реальных account/message/mic операций, reset/clean/commit/push. Полный environment teardown, ambiguous enqueue outcome и actual TDLib open_count закрываются только отдельным соответствующим witness, не green host stop suite.

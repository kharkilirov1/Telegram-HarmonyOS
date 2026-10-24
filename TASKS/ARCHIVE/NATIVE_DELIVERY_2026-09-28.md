# Native delivery ownership — 2026-09-28

Предыдущий завершённый срез: progress — client retirement, 57 host suites и обе сборки. Следующий прерванный заход только перечитал контекст; новых результатов не дал. Активная фаза остаётся reliability, полная production parity не достигнута.

## Baseline и ожидаемый результат
- Текущий producer выделяет `new std::string` и игнорирует результат `napi_call_threadsafe_function`; callback единственный удаляет payload. Existing native bridge suite проходит, но fake всегда принимает enqueue: он не проверяет ownership при non-ok.
- Условная source-ветка OpenHarmony допускает non-ok после вставки; её достижимость в installed OS не доказана. Поэтому нельзя исправлять универсальным `non-ok -> delete`. Нужен явный adversarial host witness обеих сторон границы.
- Предсказание: после исправления TSFN несёт только nullptr wakeup, строки принадлежат отдельной per-loop очереди; pre/post-insertion failure не создают double-delete/leak. Retry уведомления не повторяет batch, не читает новые TDLib responses пока notification не принята. Null-env callback не разыменовывает context после finalizer. Old-loop notification не читает new-loop queue.

## Конструкция / владельцы
- Parent: `tdlib_napi.cpp`, адаптация existing native fixture/header, интеграция, проверки и рабочие документы.
- Worker: новые `test-native-delivery.cjs` / `native-bridge/delivery_test.cpp`: RED на исходнике, GREEN, exact behavioral controls после patch.
- Sidecar: отдельный контракт async cleanup hook ↔ TSFN finalizer; без production edits. Уничтожение env и lifetime opaque TSFN handle не объявлять решёнными только из-за безопасного payload.
- Per-loop shared queue: producer держит shared owner; finalizer владеет heap shared-pointer holder; callback копирует shared owner только при live env/callback. Один wakeup обрабатывает не более одного batch.
- При generic enqueue failure сохранять batch и повторять nullptr wakeup с паузой, не transfer/delete по статусу. При closing прекращать обращения к handle, не делать слепой дополнительный release.
- Отвергнуты: delete-on-any-non-ok (возможен accepted pointer), raw context после null-env (finalizer мог уже исполниться), общий current-loop queue в callback (old/new mixup), синхронный main-thread join (UI freeze).

## Проверки и безопасность
Actual-source native host + negative controls, existing native/gateway/stop suites, full host/static smoke, последовательные main/ohosTest builds, package markers и неизменные hashes после final edits. Host fixtures не доказывают installed SDK runtime или env teardown.

Не устанавливать HAP, не трогать аккаунт/микрофон/сообщения, emulator data, git HEAD/index и global config. Dirty tree сохраняется; patch обратим узким diff. SDK/env cleanup и dialog count остаются в полном маршруте, а не исчезают из задачи.

## Итог
- Actual-source `reject-before`: parent лично RED→GREEN; с финальным fixture дополнительно повторён RED на архивном native5a00f535 без изменения production-файла. Host retained allocations2/8263bytes→0/0; до правки ordinary batch терялся.
- 14 scenarios×2:162/162 untouched+204/204 heap,12 controls; JS-reentry/producer-progress проверяет отсутствие queue mutex через JS. Existing32/34+5 native controls, gateway/retirement/regression suites сохранены.
- 58 host suites/38PS+Bash и обе последовательные SDK builds PASS;782 hashes стабильны. Новый native .so найден в HAP; ArkTS ABC unchanged. Review не нашёл новых live-env delivery findings. Подробности и полный output: `docs/reviews/2026-09-28-native-delivery-remediation.md` / `native-delivery-evidence.json`.
- Env teardown не подменён finalizer guard: sidecar зафиксировал отдельные lifetime/cleanup premises и отсутствие installed mapping. Slow-consumer queue bound и recovery при conversion/JS error тоже остаются отдельными задачами. Полная project goal активна.

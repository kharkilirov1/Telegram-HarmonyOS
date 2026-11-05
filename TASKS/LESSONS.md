# LESSONS - repeated mistakes and project-specific pitfalls

Layout: five dated blocks come first, newest first. After them the numbered lessons run in
descending number order, 161 down to 83, with 162–163 appended at the end because they were written
after 161 rather than inserted. The numbers are stable identifiers — code, docs and reviews cite
them directly ("lesson 121", "LESSON 84") — so never renumber. A new lesson takes the next free
number and goes at the top of the numbered section.

## Docs drift and repository hygiene - 2026-10-24

- When the mandate changes, the old rule that contradicts it must be **deleted**, not merely outranked by a newer paragraph lower in the same file. `AGENTS.md`/`CLAUDE.md` said "production quality by the iOS reference" while `TASKS/AGENT_EXECUTION_PLAN.md` still carried "pixel-level fidelity is not a release goal" and a `v0.1.0` target that `STATUS.md` said was withdrawn; agents could follow either.
- Resolve authority with a **scoped** rule, not with another priority claim. `DECISIONS` D3 said the master plan wins, `CLAUDE.md` said `docs/ai` is archive, and `TASKS/TODO.md` carried the question as an open user decision for weeks. D25 fixed it by scope: active sources are the plan/queue/decisions, `docs/ai/*` is archive, and `MASTER_PLAN_TELEGRAM_UI.md` governs only the `tg_ui` visual contract.
- History needs a home and an index. `TASKS/` mixed 17 documents of which 10 were historical; moving them to `TASKS/ARCHIVE/` (with `ARCHIVE/INDEX.md` saying what each was and "do not execute") is what makes the active set readable. References from dated reports break on such moves — accept it and say so in the index, because a checkpoint records the tree as it was.
- Dead links in dated reports are **by design** (build outputs, offline evidence, absolute `C:/...` paths). Do not "fix" a checkpoint; write a new dated report. The same rule keeps `docs/ai/*` frozen.
- `git status` alone hides ignored junk: an untracked disk-cleanup crash dump and an empty `presentation/viewmodels/.gitkeep` survived for weeks. Check `git status --ignored`, empty directories, and whether the docs still reference files that no longer exist.
- Keep the local-only rule files honest: `AGENTS.md`/`CLAUDE.md` are gitignored by design, so the README has to say where a fresh clone finds the source of truth instead of assuming those files exist.

## Probe modelling and measurement labels - 2026-10-23

- A synthetic harness must copy the shipped policy, not just the work loop. The drain yields at `max(2, min(250, elapsed * 2))`; a probe that yields with a zero delay measures a different system, and a budget sweep run on it produced a gradient (37 % faster at 64 ms) that the real model cannot have — the saved scheduling returns as a longer mandated pause. Read `TdGateway.ets` against the harness before generalising from it.
- Never label a number "measured" unless an instrument records it. The sweep's "measured hop counts" were `ceil(work / budget)` computed by hand; adding a slice counter to the runner is what made that a measurement.
- Check the provenance of a calibration constant. The 8 ms "consumer work per response" started as an *injected artificial* delay in the 2026-10-18 diagnostics; a model calibrated on its own injection is only self-consistent, and two later notes quoted it as the project's measured figure.
- A harness outside the build and outside lint rots silently: a missing constructor argument survived two commits in `probe/TdProbeWorker.ets`. Keep a runnable entry point (`probe/ProbeEntry.ets`), update the worker when a signature changes, and say in the README that nothing compiles the directory.
- Competitor claims must be re-checked field by field against the retained artifact. The ArkGram note carried `3.2 / 3000002`, `compileSdk 26.0.0.105 / Release`, a push action that does not exist, a SQLite claim where only preferences are present, and "seven versions behind" for a five-version gap; the artifact says 1.0.1 / `26.0.0.23` / `Beta1`. Absence of a string in one file is also not absence from the product — record which file was scanned.
- A corrected model still has to be *run*, and a reasoned prediction can be directionally right and quantitatively wrong. The shipped yield model was predicted "roughly flat in the budget"; measured on the emulator it is −18 % from 8 → 64 ms, ~2.8–3.1× slower than the zero-delay model, with a non-monotone frame ordering (207 / 285 / 216 / 130 ms). Predictions about magnitude are not results: state them as predictions, then measure, then rewrite the conclusion.
- Emulator availability is not emulator stability: this HVD guest kernel-panicked twice while the host was stopping/restarting it, each cycle costing a full image re-verify, and the measurement only fits inside a stable boot window. Start the HVD, wait for `bootevent.boot.completed`, unlock the screen before `aa start` (a locked screen fails with code 10106102), and keep a continuous `hdc shell hilog` capture so a late guest panic does not erase the rows.
- Record the host with the measurement, not just the device. These timings came from a 2014 Xeon E5-2687W v3 with 8.7 GB free RAM and `C:` at 96.9 % full — that inflates exactly what a scheduling probe measures (timer cost), so its absolute numbers are an upper bound, not app behaviour, and the disk pressure is why only cold boots work and why a restart costs ~6 minutes. Host load, free RAM and free disk belong in the report beside the workload, and a timer-dominated result from such a host can only claim shape and ordering, never magnitudes.

## Receive scheduling and causal proof - 2026-10-18

- A native send-to-receive duration includes credit waiting before td_receive; it is not server latency. Clip and union wait intervals in the same clock domain, retain shared intervals across concurrent requests without summing them, and distinguish outstanding from already-admitted batches.
- If a selected batch reaches Ark only after timeout, its later admission-to-dispatch residence cannot alone explain that deadline failure. Preserve source-ready and observer-effect unknowns; wall-time spans are not CPU time.
- Keep a120s terminal cutoff PARTIAL even when earlier request prefixes are coherent. Preserve initial empty-history failure when a later ordinary UI reopen succeeds; neither outcome establishes continuous smoothness.

- Bounded diagnostic volume does not establish zero timing cost: synchronous HiLog, native locks, clocks and Promise observers can perturb the measured application. Trace evidence describes the instrumented candidate; historical causality needs controls when observer cost could explain delay.
- Match official/isolated diagnostic source hashes and SDK artifact/install/fresh-process receipts. Retain failed compiler attempts; ArkTS rejects static-method this references and may require explicit native-result type annotations. A run without capacity-wait/store records does not validate those runtime branches.

- Functional getMe/profile/history success does not clear remaining main request timeouts. Deduplicate overlapping captures by PID/correlation; unequal workloads/windows are not a speedup metric. Four queued batches at timeout do not establish the delivery-stage cause.
- Installed hilog accepts at most10 tags: split larger focused sets into disjoint groups, reject CLI errors, and retain invalid captures explicitly. A new PID plus post-launch onCreate is the app-init witness; ps STIME alone can predate the launch.
- HAP cleanup requires an exact extension/path/size/hash proposal and preservation of current/rollback/test pairs. Keep non-HAP evidence; do not turn approval of inventory into deletion authorization.
- A time-budget guard before the first transfer can starve work; parsing followed by continue is not transfer progress. Guarantee meaningful progress while retaining finite item/batch limits even with a frozen or backward clock.
- Admission capacity being full is a symptom, not a causal diagnosis. Trace selected native receive/publish/JS admission/dispatch/ACK/Promise and compare progress-only versus pacing-only. Do not extend deadlines or remove memory bounds to hide an admitted-wait timeout.
- The host runner must be executed with Node >=24, as CI does: five chat suites assert it and report HARNESS_ERROR with zero executed cases under Node 22, which reads like a regression in unrelated code. Reproduce a suspected suite failure at the previous commit before blaming the candidate, and never read a suite verdict from a piped `tail` — the pipe returns its own exit status and hides a failing run.
- Keep native steady-clock and Ark uptime durations separate. Frame callbacks must occur inside actual work, not only readiness/cleanup, and do not by themselves establish smooth presentation/input. Verify the expected baseline failure phase after safety gates; ordinary Hypium class-name noise is not a malformed diagnostic marker. Preserve failed captures and parser versions.

## Receive ownership and evidence - 2026-10-15

- Callback admission is not consumption. Keep count/UTF8-byte credit through active parsing and release references before exact epoch/batch ACK. Bound builder/lookahead separately and never call a payload cap total RSS.
- Join is not finalization. Wait for real TSFN finalizer plus producer/control/submission retirement; retain the owner on uncertain cleanup failures. Do not join the JS owner thread.
- Pre-JS conversion can retry a retained batch within a finite budget; possible JS effects and ambiguous insertion cannot be replayed. Faulted writes retain unknown outcome and must not auto-resend.
- Runtime trace interpreters need negative controls for missing/duplicate/mixed/order-inconsistent events and actual Closed consumption. Process disappearance does not prove env cleanup; a coherent Photo prefix remains PARTIAL without its own terminal marker.
- SDK compilation catches native-return type inference and event spelling missed by host transforms. Preserve assertions, source deltas and failed attempts. Main artifact reuse requires unchanged main inputs; a generated fixture in the isolated main still requires rebuilding.
- Hash verification preserves a prior test's scope and date; it is not a new test execution. Fresh candidate12 host95/95 covers the host-only follow-up; source11 SDK builds are inherited only through explicit input/artifact identity; preserved Photo52/29/footer3+15 controls retain October14 execution.
- Observe causal completion rather than a fixed sleep over dependently scheduled loaders. Keep exact order/publication assertions and bounded failure. Remove redundant UI RPC work inside the same ownership/deadline contract; do not reclassify a foreign owner as transient merely because a later run passes.
- Filter console markers by their real JSAPP tag and current PID/time; buffered historical failures and HDC exit0 are not the current result. Preserve failed attempts and state each acceptance boundary.


## Build and native verification - 2026-10-13

- Reproduce cache/permission failures in the actual checkout; a separate-copy EPERM does not prove the original build is blocked. Use normal approved execution without changing security/ACL settings.
- Bind source, generated projection, packaged HAP and fresh-process execution to explicit hashes/receipts. Force compilation when external test imports are omitted from incremental invalidation. HDC exit zero does not establish Hypium PASS.
- Zero-delay awaits may drain in one platform timer task. Preserve all callbacks/assertions and yield to a later event-loop turn; verify with native watchdog evidence.
- Native focus/keyboard samples can straddle transitions. Discard inconsistent samples within existing deadlines; retain ownership and no-replay guards. Native text replacement can expose real debounce prefixes: validate exact request identities and stale replies.
- A below-fold fixture text wait needs stable-ID visibility before an exact assertion. Capture failure state before finally cleanup; post-cleanup screenshots cannot establish the failing state.
- ArkUI local builders receiving changing primitive values can retain stale text. One direct object parameter produces reactive builder proxies; verify the official compiler output and unchanged native assertion.
- Await observable loader completion/publication instead of assuming timer duration proves completion. Keep concurrency/order assertions and negative controls.
- Separate whole-case Hypium budgets from component wait bounds. Photo functional acceptance used 240s after a preserved 120s timeout; this does not establish 120s performance. Hypium timeout does not cancel callbacks: stop only the isolated bundle and verify a fresh process before continuing.
- Preserve historical document bytes and local artifacts. Record current results in compact prefixes; authenticated delivery, synthetic fixtures and release readiness are separate claims.

Last updated: 2026-10-23

## 161. Mutation certainty belongs to each dispatched request

- Typed cause/retryability does not prove whether a write was rejected. Tag explicit TDLib and pre-dispatch rejection separately; timeout, post-dispatch client retirement and malformed acceptance remain uncertain. Copy contextual errors rather than mutate a shared original.
- Screen code406 before reading its message, both at gateway/adapter and nested send-failed normalizer. Keep safe bookkeeping; do not claim control over upstream native TDLib logs without binary/runtime evidence.
- Preserve the original draft, cloned entities, selection and reply only for the unchanged operation/revision/lifecycle. Unknown forwarding must not restore a replayable accepted comment/full batch. Known rollback releases only its own taint; bounded older uncertain markers survive.
- Real native dialog tests need the mounted top TestAbility and scrollSearch for below-fold fixtures. Cancel must preserve state with zero extra writes; explicit confirmation must dispatch exactly once. Host/source callbacks, synthetic SDK UI and real Telegram delivery are distinct evidence. Report: `docs/reviews/2026-10-02-send-forward-errors.md`.

## 160. Reconcile timeline identities and protect the resulting native callbacks

- The anchor absolute new index is not an insertion count: leading date/unread markers and edits beyond the first few rows can duplicate tails. Validate unique stable/render keys and retained order, then mutate before each add/delete/change signal; retain existing comparator and stamped render keys.
- Native maintainVisibleContentPosition applies outside-viewport LazyForEach insert/delete and excludes reload. Its delayed scroll events outlive the synchronous diff guard; protect a changed stable prefix before the visible surviving anchor, including deletion, rekey and net-zero replacement. Let real user scroll unlock the existing pagination block.
- Capture END-based bottom intent before the diff. A lifecycle-owned 16ms callback still needs a current visible-range check: small upward user movement can remain near bottom; large appends can make the old bottom look far away. No new global owner/counter is required.
- Native rectangles must resolve stable identity to its current index without scrolling to repair the result. Separate intentional gesture movement, deleted-anchor/height-change limits and synthetic fixture evidence from production/account acceptance. Witness: `docs/reviews/2026-10-01-chat-timeline-updates.md`.

## 159. Preserve typed causes and request provenance across Promise callbacks

- Preserve an existing AppError instance after current-owner validation; generic wrapping must remain only for untyped failures. Friendly message and technicalMessage are different fields; TDLib404 exhaustion requires the original numeric code.
- Returning from a terminal catch does not retire late snapshot correction. Clear the owned intent/timer, but first validate the exact existing Domain reservation identity in both success/error callbacks. isLoading is insufficient: a newer request may already have completed. Before/after synchronous reservation capture distinguishes skipped loads; lifecycle/window/sequence prevent reset ABA.
- Same correct callbacks must fail through assertions on source preimages and pass on the candidate; detect regressions with behavioral mutants. A swallowed fixture TypeError is not successful history loading: complete AppStore fixture shape and observe the actual Domain Promise. Evidence: `docs/reviews/2026-10-01-gateway-error-causes.md`.

## 158. A delayed fallback must keep the original owner and list snapshot

- Capture route/gateway before dispatch; use the existing current-route/account/lease predicate before fallback and every success/error cleanup. Same chat ID, unchanged lifecycle and account ABA cannot revive an old owner. Retained valid routes remain valid.
- Refresh invalidates page identity and cursor before dispatch. Page completion must match both its request and its base-summary request; old rejection cannot clear newer busy state. Preserve current-owner fallback, 404 absence, dedup, int64 cursor and retry controls.
- A reproduction asserting known bad output is not a regression RED. Run identical correct assertions on source preimages and candidate; mutation failures must be behavioral assertions, not loader errors. Native coordinator/store/lease fixtures and actual host Session integration have different boundaries; neither proves authenticated ordering. Evidence: `docs/reviews/2026-10-01-pinned-account-ownership.md`.

## 157. URI identity, native readiness и видимые пиксели проверять отдельно

- Selection остаётся одним canonical ordered array; UI callback несёт URI, а thumbnail ordinal/id вычисляется после reorder. Native test должен выбрать миниатюры именно в переставленном порядке. Busy — один Trace backing; Cancel/picker и accepted cleanup учитывают mode changes даже без revision bump.
- Consumed URI fence сохраняется для overlap/subset/single и concurrent attempts; known rollback не забывает старую taint, overflow 128 требует confirmation. Caption/reply не хранить в этом ledger.
- Hypium onCreate может опережать top ability/window: строго ждать actual TestAbility/Scroll с bounded timer, без fake context/ignored nullable waits. Component existence/text не доказывают контраст: просмотреть actual screenshots, особенно error state.
- `/proc/self/fd` может быть запрещён. Не skip/угадывать fd: narrow observer после real open даёт exact-owned handle; native stat positive control →strict EBADF после finally, без повторного close потенциально reused FD. Native bytes/decode, host injected partial-write failure и real provider grant — разные witnesses.
- История RED, замороженные hashes и acceptance scope: `docs/reviews/2026-10-01-photo-selection-preview.md`.

## 156. Album acceptance, input ownership и native dialog pixels проверять раздельно

- Album `messages` — принятие к отправке, не delivery. Pending IDs в локальной TDLib положительные int53; pre-dispatch validation и unknown post-dispatch требуют разных retry правил. Captured selected URIs сохраняют duplicate confirmation даже при новом draft/permission revoke после принятого ответа. ABA защищается revision, а не сравнением текущего значения.
- Prepare все файлы до одного dispatch; удаляй только собственные unsubmitted copies. Глобальный filename sequence защищает одинаковые basenames в одну миллисекунду.
- API24 native prompt отвергает пустой color; Resource color дал black button на dark dialog. Разрешай существующий themed token через mounted context и передавай unsigned ARGB. Снимай screenshot в app filesDir, жди bounded dismiss absence, а finally cleanup не должен маскировать исходный RED. История RED→GREEN и границы: `docs/reviews/2026-10-01-photo-album-sending.md`.

## 155. Разбивку page проверять по ownership, payload и реальным SDK assertions

- Одна Session, stable V2 slices и единственный Trace backing; Context хранит handles/aliases, feature получает narrow port, visual child — models/UI callbacks. LOC и source parity дополнять compiler/runtime, не считать host decorators native rendering.
- Nullable waitForComponent не assertion: проверить12 before/after значений native existence assertions и отсутствие6 старых. Native no-match может быть null/undefined даже у findComponents; только такой результат нормализуется к0, nonempty stale arrays проваливают assertion, API rejection не перехватывать. SDK negative controls должны исполнять настоящий callback.
- Forwarding gate покрывает и277 прежних, и7 новых UI delegates; actual ViewBindings исполнять с уникальными payload identities/order/return spies. Composer text loss и scroll swap обязаны быть RED; presentation-only omissions и controller bridges учитывать явно.
- applyDiff snapshot сохраняет старые positions/length при in-place prepend. Fixture URI/completion contract проверять точными assertions и false/missing cases. Runtime QA — separate dummy bundle; six fixture slices и empty-route mount не закрывают authenticated/iOS acceptance.
- Dirty baseline не равен HEAD:34 пересечения требуют before-images и рассмотренного predecessor. Snapshot/test PASS не разрешают commit. При ошибочном read-only отказе предъявить текущий transcript mandate в контексте и повторить ту же конкретную команду; не обходить rejection другим способом записи.

## 154. Внешний клиент закреплять как reference, а не готовую интеграцию

- Отдельный clone под `C:\Refs\Telegram`, URL/branch/SHA и лицензии в `REFERENCES.md`; проверять реальные UI→TDLib call sites, а не README. Root Apache-2.0 не покрывает автоматически native-зависимости/ресурсы. Сравнение dirty checkout обозначать как local working tree; host/static PASS не заменяет ArkTS build, device или iOS visual acceptance. Witness: `docs/reviews/2026-10-01-petrelgram-comparison.md`.

## 153. Source-text smoke должен следовать за владельцем поведения
- После выноса top-bar форматирования прежний smoke искал строки локализации в `TgChatScreenPage.ets` и ложно падал. Проверяй строки в новом `ChatTopBarPresentation.ets`, но отдельно требуй page→helper import/call и `@Local`→UI props; один grep по новому файлу не доказывает интеграцию. Behavioral baseline исполняй на старом и новом page **с переходами на одном экземпляре** и page-owned effect order/repeat guards. Astra Ultra ревью нашло, что 35/35 пропускали spinner latch, отсутствие observe и повторную hydration; после добавления проверок 51/51, соответствующие mutants красные. Компиляция двух HAP без установки — не runtime-приёмка.

## 152. При разбивке page проверяй реальный вызов, а не наличие строки
- До выноса `TgChatScreenPage.ets` имел 37 прямых script references; source-text smoke не доказывает работу нового контроллера. В focused test исполняй page wrapper вместе с production controller и требуй red при no-op page wiring и снятом request-id guard. Один срез — один owner, один проверяемый delta; не переносить все 5930 строк одним патчем.
- `@ComponentV2` page не скомпилировал `return { ... }` для импортированного host interface (`10605038`, object literal). В этом срезе typed host реализован явными методами страницы и передаётся контроллеру как `this`; после смены границы обязательна свежая main/ohosTest сборка. `@Local` presentation state при поведенческом выносе остался в page.

## 151. Подписка на общее окно принадлежит странице, а не типу события
- `Window.off(event)` снимает подписки всех владельцев; сохраняй callback/disposer и снимай только его. При partial bind откатывай уже зарегистрированное, повторный dispose должен быть безопасен, а late callback — инертен. Host A/B owner и mutation controls ловят глобальный `off`; реальный ArkUI lifecycle — отдельный gate.
- Отложенный UI timer должен очищаться при teardown и проверять lifecycle плюс identity перед изменением нового состояния. Проверяй replacement и queued callback, не называй конечные 1600 ms бесконечной утечкой. Witness: `scripts/test-ui-window-search-lifecycle.cjs`.

## 150. JSON-строки проверять на control chars и повторное декодирование
- Набор из `\\`, `\"`, LF/CR/TAB не покрывает U+0000–U+001F. Экранируй отдельные строки через `JSON.stringify`, не пересериализуя полный TDLib-запрос с int64. Полученный JSON проверяй на реальном пути `use case → serializer → TdObject → gateway send` и NUL/C-string boundary.
- Escape-токены входящей JSON-строки декодируй однократно: последовательные `.replace` могут превратить буквальные `\n` и `\u0000` в другие символы. Mutation tests должны возвращать именно эти дефекты; отдельную неоднозначность nested/top-level regex-поиска не маскировать названием «парсер исправлен». Witness: `scripts/test-command-serializer-escaping.cjs`.

## 149. TSFN status не является квитанцией передачи владения payload
- `non-ok -> delete` нельзя применять без доказанного no-enqueue контракта. Храни owning strings в per-loop queue, передавай через TSFN только nullptr wakeups; retry тогда безопасен для pre/post-insertion failure. Пока уведомление не принято, не читай TDLib вперёд и не крути hot loop.
- Context holder и producer имеют независимый shared ownership. Null-env/null-callback guard должен стоять ДО context access: finalizer мог уже исполниться. Старый callback использует только свою очередь; один callback не осушает всё накопленное, mutex снимается до JS.
- Отделяй enqueue, попытку JS invocation, producer join, TSFN finalizer и освобождение client ID. Не переигрывай частично выполненный JS; at-most-once не означает доставку при conversion/JS exceptions. Не выводи безопасность opaque handle при env teardown из безопасности application queue.
- Heap oracle калибруется retained-allocation null twin и cross-thread free; untouched source вариант запускается отдельно. Host allocation counts не являются измерением TDLib/SDK memory. Pinned source/null-data forwarding не доказывает installed binary mapping. Проверки и границы: `docs/reviews/2026-09-28-native-delivery-remediation.md`.

## 148. Сохранять owner до Closed и не терять Closed вместе со stale очередью
- Создавать receive path до выделения client ID; частично запущенный receiver всё равно требует stop barrier. Timeout close возвращает ошибку, но не освобождает owner и не разрешает новую initialize. Closed авторитетен без Ok; application dispatcher detach не должен перекрыть узкий transport-only retirement path.
- Recovery failure может застать единственный public Closed уже в pending batch или остатке частичного drain. Не очищать эту очередь: сохранить generation каждого batch и переустановить таймер. Старые обычные updates/responses отбрасывать даже если manual retry успел стать ready; current-client Closed сохранять, foreign ID не принимать. Не заменять bounded drain синхронным разбором всей очереди.
- Shared shutdown/reset Promise публикуется до синхронного отзыва scopes; при ошибке reset сохраняется singleton-owner. Native stop rejection допускает explicit retry, не автоматический цикл. При повторном lifecycle сбрасывать прежний Closed до вычисления необходимости нового close.
- Проверять timeout-before-drain и обратный порядок, single/batch/partial delivery, retry-before-drain с fresh positive control; mutations должны отдельно ловить discard, отсутствие rearm и stale traffic. Source/host evidence: `scripts/test-retirement-queued-closed.cjs` и `docs/reviews/2026-09-28-client-retirement-remediation.md`; не device/TSFN teardown acceptance.

## 147. Receive stop, TSFN finalization и TDLib client Closed — три разных барьера
- Join выполняется вне ArkTS; только async completion публикует Stopped. Queue failure/cancel возвращают владение joinable thread и оставляют Stopping для retry; нельзя объявлять Running обратно или уничтожать незавершённый std::thread. Gateway держит общий shutdown Promise и destroying до подтверждения.
- Уход producer не доказывает уничтожение TSFN/осушение callbacks. В просмотренном upstream non-ok может идти после enqueue, а finalizer — раньше null-env callbacks: blind delete/release retry небезопасны; установленный binary требует отдельной проверки.
- `close → Ok` и `td_receive == nullptr` не доказывают release client ID. Threaded ClientManager поглощает internal Closed, затем отдельным sentinel удаляет ID и публикует Closed. `Dialog::open_count` — другой счётчик, не getOption-метрика клиентов.
- Диагностика с незакрытыми findings называется audit, её strict RED не включается как «PASS тест» в общий runner. Negative controls должны ломать конкретное поведение, не compiler/runtime setup. В context-mode запускать Node fixtures через проверенный `node`, не `process.execPath` Bun. Evidence: `docs/reviews/2026-09-28-native-stop-remediation.md`.

## 146. Revocation и synchronous repaint требуют разных ownership guards
- Account scope отзывает звук/metadata/search и системные команды до queued UI notification. Новый handler B, зарегистрированный ранним invalidation observer, нельзя удалить поздним cleanup A: проверять актуальность captured scope, а не безусловно очищать общий слот.
- `release()` может синхронно вызвать repaint и новый playback intent тем же handle. Account/current guard не различает эти intents: metadata commit и следующий toggle должны проверять generation; устаревшая публикация возвращает отозванный token. Проверять initial bind и cross-chat handoff, включая outer toggle после вложенного запуска.
- AVSession create/activate/destroy сериализуются; callback проверяет captured revision и identity. Уход страницы снимает только её subscription, reset account отзывает playback. Rejected destroy доказывает лишь fencing команд, не освобождение native session.
- Mutation должна ломать проверяемый путь, а не setup: operation-only fixture явно задаёт account boundary, actual account/page integration отдельно исполняет реальную привязку. Итог/границы: `docs/reviews/2026-09-28-media-account-remediation.md`.

## 145. Native event и Promise settlement — разные каналы; generation не отменяет уже отправленный SDK effect
- Player может уже играть/завершиться до resolution play Promise. Подготавливаемые ресурсы локальны, но после prepare ownership и metadata публикуются до play: stop/pause видят ресурс, ранний completed не теряется. Проверять state/event и Promise независимо; в первом patch 18 зелёных tests скрывали три реальных reviewer regressions, затем они стали постоянными cases.
- Background stop относится ко всей UIAbility. Поздний guard после SDK stop не спасает новый start: эффекты сериализуются; отмена сразу ставит cleanup intent, linger защищён generation и отдельным timer token.
- Mocked dangling Promise без реального таймера может завершить Node с exit0 посреди suite. Нужен per-case deadline/keepalive и отрицательный контроль самого harness. Реальный seek возвращает void: deferred mock доказывает только continuation ownership.
- Итог и границы: `docs/reviews/2026-09-28-playback-remediation.md`. Controller/global guards не равны account isolation, AVSession lifecycle или физическому audio/device acceptance.

## 144. Async ресурсы принадлежат операции; native oracle обязан видеть доставку и деструктор
- Recorder/FD/path захватывать вместе до await; late create/cleanup A не публикует и не освобождает B. До публикации recorder после start — локальный owner/finally; cleanup single-flight, idle только после failure cleanup. Уникальный output suffix общий для всех controller одного модуля, не только page token. Tests готовят реальную запись через public begin/start/send, не присваивают private fields.
- TSFN startup failure должен отклонять инициализацию до начала вычитывания TDLib. Callback владеет accepted payload даже при null env. В OpenHarmony generic enqueue failure может означать уже выполненный queue insertion: нельзя без lifetime-контракта добавлять delete на любой non-ok.
- Счётчика вызовов JS и object delete недостаточно: отдельные handles, точные argc/argv, registered callback и освобождение длинного string buffer. MinGW dynamic libstdc++ обходила buffer delete tracker; Windows host test использует static libstdc++, положительный контроль и мутацию без деструктора. Это не SDK ABI/teardown test.
- Сохранённая в эмуляторе сессия обнаруживается свежим осмотром, не старым login screenshot. Boot существующего профиля не равен приёмке новой сборки; не переустанавливать ради теста без учёта сохранённых данных. Результаты/ограничения: `docs/reviews/2026-09-28-native-media-remediation.md`.

## 143. Generation guard должен доходить до UI completion; CI не должен зависеть от ignored SDK
- Отозванный history запрос возвращает false: его page continuation не должен стирать target нового jump. Token нужен и delayed scroll для A→B→A; loaded-target fast path при pending запросе обязан отозвать старое history-окно. Late unread correction заменяет range/cursors, а parent initial не перезаписывает exhaustion дочернего top-up.
- TDLib viewMessages Ok не доказывает read boundary для yet-unsent ID; last_message=null означает none **или unknown**. Разделять manual unread и inbox read; при отсутствии пригодной границы не объявлять успех. OTP не передавать logger вообще, включая error echo.
- Локальный host-test может тайно читать ignored Hypium. Проверять весь runner с запретом installed-dependency reads и контрольным запретом; mock boundary fail-closed, без копирования production, с negative controls. Static fixtures переносить на реальные integration boundaries, не ослаблять поведение.
- Свидетель09-27:44CJS/38PS+Bash,44CJS без installed dependencies, serial forced builds,397 stable hashes; подробности `docs/reviews/2026-09-27-remediation.md`. Без device/CI-cloud/clean-clone/release claim.

## 142. Свежий GitHub snapshot и зелёные тесты не заменяют проверку оставшихся дефектов
- Разделять remote base, local committed HEAD и dirty/untracked изменения. Новая ветка с ревью старой базы не содержит автоматически новых fixes; прогон historical probe с exit0 может подтверждать баг, а не успех исправления.
- Аудит09-27: 36CJS/38PS и обе forced сборки PASS, но свежие независимые probes сохранили create/history/mark-read/OTP defects. Проверять tracked build dependencies отдельно: локальный ignored bootstrap делает локальный build недостаточным witness для clean clone.
- Не доверять устаревшему STATUS больше текущего кода: late-first fix уже дал106/106, хотя старый snapshot ещё писал FAIL. Исторический login screenshot не равен runtime текущего HAP. Детали: `docs/reviews/2026-09-27-github-comparison.md`.

## 141. Route provenance не равен native acquisition; missing state не равен нулевому unread
- Захватить source account epoch/gateway до deferred callback/push; page effects только после valid canonical params. Разные страницы одного account/chat различает navigation token. Rollback/forward clear не должны трогать replacement owner.
- TDLib strict Ok подтверждает API-call acknowledgement, но не open_count increment: no Read может вернуть Ok без increment. Per-route single release не закрывает shared native counter gate; нужен отдельный session/group/uncertainty contract.
- Первый owned unread snapshot сохранить до viewMessages/reducer, иначе delayed history потеряет boundary. Default при отсутствующем chat нельзя считать полученным snapshot: Wave17 separate probe был FAIL; текущая реализация исправлена и аудит09-27 повторил106/106 lifecycle. Всегда тестировать оба порядка state/ack и не прятать прочие open findings за totals suites.
- Процедура Wave17: actual lifecycle86/callers69/lease78, 11 engaged negative controls, 36CJS/38PS/review8 и final serial builds/72 stable hashes. Host Hypium bodies не device execution. Устаревшие source assertions мигрировать на реальный integration path, сохраняя exact-ID/owner checks.

## 140. Account identity, navigation ownership и native open acquisition — разные контракты
- Сначала bind captured store/gateway, затем restore; close использует ту же capability, не новый global adapter. Уже связанный компонент хранит lifetime account identity через disappear и не переносит retained draft на B при reappear.
- Пустой getState() не доказывает revoke: chat мог быть удалён в живом аккаунте. Проверка scope generation нужна отдельно, иначе защитный guard блокирует обычный Back. Guard должен защищать и globals/visibility/pop, а не только gateway sends.
- Account+chatId не различают две страницы одного чата. TDLib open_count — счётчик: lastOpenedChatId не acquisition witness. Provenance первого route нужно захватить до async push; не добавлять второй open без удаления caller-open.
- Полный aboutToAppear host witness должен дойти до последнего boundary и проверить отсутствие swallowed exception. Reappear negative control исполняет первый bind, не просто рисует новые fields в fixture. Final main/ohosTest builds запускать последовательно; пересёкшиеся/устаревшие попытки не acceptance evidence.
- Wave16: 49/49, 4 engaged mutations 7/6/6/4 FAIL; full reappear 7/7, 33 CJS / 38 PS+smoke / review 8/8, final serial compile и 65 stable hashes. Initial route provenance/same-chat owner/native counts/device parity остаются в следующем срезе.

## 139. Edit buffer, received entities и account draft требуют разных owner-контрактов
- Edit submit не очищает ввод до strict matching Message; общий send token, lifecycle и edit generation защищают dispatch/result/cleanup. После нового ввода rebase меняет только canonical ID/baseline, не draft/selection/entities. Это намеренное отличие от прочитанного iOS commit flow.
- Received TdObject JSON не равен lazy getter cache/toJSON: nested entity URL терялся при внешне успешной сериализации. Проверять actual domain→command→wire metadata, обязательные payloads, surrogate boundaries и направленное nesting (quote→code не равно code→quote).
- Scheduled ID сравнивается по native server bits и scheduling state, а не JS bitwise/int32. Fresh native-cache properties не являются server freshness guarantee. Single-splice plain-composer fallback не доказывает full rich-text preservation при нескольких раздельных правках; dynamic text/caption limits отдельно.
- Lifecycle draft persistence сверяет captured page accountStore с runtime scope до acquisition и перед dispatch; revoked scope нельзя восстанавливать через global state. Back/disappear вправе сохранить closing draft после global navigation clear, но не отправить его через новый account gateway.
- Wave15: исходные 0/6 → расширенные 174/0 (46 Hypium bodies через host), UI-chain 53/53, account draft 32/32; 16 edit mutants engaged по 1, account mutant engaged 2 и даёт 1 FAIL. 32 CJS / 38 PS+smoke / review 8/8, final main/ohosTest compile и 65 stable hashes. Device UI, prior compose restore, edit entry и rich-text parity открыты.

## 138. Destructive scope нельзя выводить из дефолта, индекса кнопки или старой availability
- Delete начинается с per-message self/all flags и explicit confirmation. Captured mode map нужен даже при двух кнопках: index 1 может означать everyone, если self запрещён. Cancel/malformed/rejection никогда не дают разрешение; выбранный self не повышается до global и global не понижается до self после изменения прав.
- Fresh properties повторяются перед mutation, включая callback guards после await. Chat-type blanket rules не заменяют TDLib flags: local/unsent/Saved/Secret/scheduled различаются. Delete не наследует sorted/max100 контракт forward; int53 format check не доказывает native MessageId validity.
- Новый intent отменяет старую destructive flow во ВСЕХ входах, включая channel-share без popup. Generation защищает и final cleanup; confirmed Ok не per-ID receipt и не atomic batch, unknown outcome нельзя auto-replay. Application no-optimistic-delete не отменяет локальные TDLib side effects.
- Host execution native test bodies не заменяет ArkTS compile: plain-object negative fixture был отклонён native compiler и заменён на JSON.parse as Object, не на permissive TdObject mock.
- Wave14: baseline 0/5 → 101/0 (14 новых + 6 compatibility native bodies через host); reviewer race 3 FAIL → 3 PASS; 8 engaged mutations дают 38/5/8/17/3/1/6/3 FAIL. 30 CJS, 38 PS+smoke, review 8/8, final обе compile, 60 stable hashes. Native dialog и iOS Undo/special-delete/device parity не приняты.

## 137. Async actions требуют identity на каждом UI-переходе, не только до send
- Target-agnostic forward availability — intersection ordinary и secret routes по всей selection; per-item OR может допустить batch без общего адресата. Source read capability не равна праву отправлять в source chat.
- Stable action ID дополняется source message/opening token и account/use-case/chat/lifecycle guard. Передавать индекс нельзя; обычные class snapshots в ForEach требуют обновляемого render key либо наблюдаемых полей, а не надежды на прежнюю closure.
- Dismiss callback захватывает generation при bind: чтение текущего token только при событии не различает два открытия одного сообщения. Reply/Edit/Cancel инвалидируют pending picker, а его result потребляется однократно до navigation/lifecycle advance.
- Мalformed/missing required properties → explicit retry; literal false → known deny. Menu/picker snapshots не заменяют Wave12 pre-comment/dispatch checks. Disabled Forward — осознанная Harmony adaptation, не доказанная iOS visual parity.
- Witness Wave13: initial 0/3 → 62/0, 12 native bodies через host; дополнительно воспроизведены 4 action-context, 4 review и 1 duplicate-result FAIL до fixes. Mutations 13/4/1/2/3/1/1/4; 29 CJS, 38 PS+smoke, review 8/8, final compile, 57 stable hashes. Render-key assertions структурные; device gate открыт.

## 136. Forward eligibility проверяется до comment и повторно перед dispatch
- `can_be_forwarded`, `can_be_copied`, `can_be_copied_to_secret_chat` не взаимозаменяемы: server/explicit-copy/local/secret выбирают разные flags. Properties без identity/revision привязывать к captured request, не к текущему экрану; malformed/missing не превращать в разрешение.
- Async metadata reads добавляют новую race boundary: after-await guard обязателен внутри use case непосредственно перед mutation, а не только в controller перед вызовом. Comment + forward не атомарны; принятый comment не восстанавливать при последующем source deny.
- Per-kind forward gate нужен basic group И ordinary supergroup; доступный text composer не означает разрешение photo. Unknown source kind пока требует conservative deny, но полноценному UX нужны metadata hydration/retry и стабильные action IDs.
- При изменении transport protocol обновлять fixtures отдельными read replies/trace assertions, сохраняя прежние mutating-send races. Mutation, оставляющая read pending, должна дать bounded timeout FAIL, не незавершённый suite.
- Witness Wave12: baseline 1/3 → 75/0, 25 native bodies через host; mutations 24/11/2/14/9 FAIL. 28 CJS, 38 PS+smoke, review 8/8, обе forced compile, 51 stable hashes. Device/visual acceptance отдельно.

## 135. Boosts снимают defaults, а partial unknown требует собственного recovery path
- Supergroup defaults и individual permissions — разные слои. Qualifying boosts/admin не отменяют individual deny; default-allowed kind работает без FullInfo, неизвестный boost snapshot не равен `0/0` или отсутствующему внутреннему TDLib cache.
- FullInfo без ID привязывается к captured request ID; update — к strict outer ID. Хранить отдельную map, клонировать producer, сохранять identity при unrelated updates, проверять live-over-late response при dequeue и account scope при reset.
- Panel может оставаться composer при unknown media rights. Если load failed, Retry только для общего unknown недостаточен: нужен доступный retry рядом с работающими controls. Проверять через actual atom callback + parent binding → controller → use case, не напрямую через private retry. Demo 19 сохраняет draft, без сети.
- Strict incoming getters работают с received rawJson, не с cache-built command params; wire проверяется через фактический `toJSON()`. Новые imports должны попадать и в dependency injection source-extracted harness, а fixtures должны задавать настоящие membership/boost snapshots.
- Witness: `test-supergroup-boosts.cjs` 32/32, 9 native bodies через host; mutations individual/booster/page/live/clone/subscription/retry-ui дают 5/11/6/1/3/1/1 FAIL. 27 CJS, 38 PS+smoke, review 8/8; final main/ohosTest compile, 50 stable hashes. Device/visual acceptance отдельно. Отчёт: `docs/reviews/2026-09-06-reliability-wave11.md`.

## 134. OS fault capture: timestamp, содержимое ответа и Build ID важнее exit 0
- Reopened/appended kernel log получает свежий mtime со старым panic. Относить crash к boot только по timestamp строки >= фактического StartTime; не перезапускать живой wrapper из-за устаревшего monitor result.
- HDC может вернуть exit 0 с `[Fail] Device not found or connected`. Shell подтверждается точным remote sentinel, fault — фактическим HiviewDFX header; failed read не должен затирать ранее сохранённый payload. Native `-logZip` с collection failure — не backup. Windows `file recv` требует native absolute destination; `hilog -x` нельзя совмещать с `-z`.
- Получать sysfreeze в коротком Connected-окне; partial payload явно помечать partial. Перед символизацией сверять Build ID. Musl `.gnu_debugdata` можно XZ-decompress только в памяти и сопоставить ELF symbols; ближайший exported objdump label не обязательно имя функции.
- Разные startup-стеки SceneBoard (NAPI relocation, IPC, allocator) и чёрный UI до установки проекта локализуют OS blocker, но не доказывают GPU/RAM/одну библиотеку как root cause. Сохранять данные профилей, остановить terminal wrappers, не повторять одинаковые boots без нового измерения.
- Witness: `scripts/test-emulator-capture.ps1` 14/14; in-memory возврат старого fault predicate даёт exit 1 на HDC failure text; 38 PS+smoke PASS. Последний predicate fix только host-tested, не новый boot. Raw boot3 `faultCount=8` сохранён как историческая ошибка: 7 successful unique partial payloads, 6 failed reads. Отчёт: `docs/reviews/2026-09-06-reliability-wave10.md`.

## 133. Send permission — не один text bit и не только store getter
- Basic-group sendSomething — any из 9 default bits с per-kind individual intersection; active creator/admin bypass после activity/membership gates. Caption проверяется по media kind. Ordinary megagroup booster policy требует другого решения.
- Default snapshot проходит initial DTO, live event, reducer, deep clone и partial update. Missing snapshot не равен all-true: после status hydrate нужен bounded getChat с live-update/account fence; unrelated title change не должен его выбрасывать.
- Store object не является ArkUI @Local. Публикуй reactive capability snapshot для child @Param flags даже когда panel остаётся composer; actual dispatch после await всё равно сверяет свежий scoped store и точный kind, а не UI snapshot.
- Отделяй hasSendIntent от canSend: запрещённый текст не должен превращаться в microphone. Picker result проверяется по chat/lifecycle/generation и текущему типу; forward recheck использует захваченные source IDs после очистки preview.
- Свидетель: test-basic-group-media.cjs 52/52, 6 native bodies через host adapter; mutations transport/selection/dispatch/batch/hydration/picker/voice дают 36/26/19/1/1/2/1 FAIL. Ошибка dependency injection в harness исправляется до оценки production delta. Отчёт: docs/reviews/2026-09-06-reliability-wave9.md.

## 132. Basic group — отдельные identity, membership и активность
- Совпадающий numeric group ID не означает один объект: panel, current send getter, subscription и hydration должны одинаково выбирать GroupKind/map. Нельзя прочитать channel admin для basic group или всегда отправлять getSupergroup. Unknown — bounded getBasicGroup + explicit retry, не guessed membership.
- `basicGroup.is_active=false` запрещает отправку даже creator/admin; проверяй inactive/left/removed до role exceptions. Literal boolean проходит parser и clone без превращения false в default true. Для left/removed iOS basic-group panel — DeleteChat, не channel Join; до отдельной destructive parity используй unavailable.
- Negative fixtures должны иметь валидные остальные обязательные поля. После добавления strict is_active старый nested-ID test может стать зелёным по неверной причине. Добавь is_active:true в его valid base и проверь mutation нужного guard.
- Процедура: `test-basic-group-access.cjs` 42/42 (8 native bodies через host adapter); mutations ignore-activity/wrong-map/no-subscription/channel-hydration/drop-activity-clone/relax-active-parser дают 6/17/1/4/7/10 FAIL. Истинный subscription method нужно извлечь в harness, а не скопировать; первоначальный пропуск метода — ошибка harness, не production finding.
- Membership gate не заменяет per-media policy/sendSomething. Basic-group default 9 bits, per-kind dispatch/UI и media-only composer закрыты source/host/compile в Wave9; megagroup booster/full-info и device acceptance остаются открыты.

## 131. Fulfilled forward не означает принятие каждого сообщения
- TDLib `forwardMessages` принимает strictly increasing int53 IDs, максимум 100; проверяй/копируй/численно сортируй selection до отдельной отправки comment. Raw JSON serializer делает невалидные строки IDs особенно опасными; witness должен доходить до реального wire payload. Не полагайся на misleading int64-комментарий в EntityId — shape берётся из `td_api.tl`.
- `Messages.messages` позиционен, `null` означает непринятое сообщение. Legacy array accessor теряет null и может выбрать nested array: strict top-level accessor должен сохранить индекс. Возвращённая длина, type, id и target chat проверяются, `total_count` не считается числом успешных sends.
- Partial outcome восстанавливает только failed source IDs, не принятые сообщения и не отправленный comment. Malformed result — неопределённость, не разрешение «повторить всё». Сохраняй account/operation/новый buffer guards; это не решает автоматически неопределённый network rejection или будущие delivery failures.
- Процедура: `test-forward-result-contract.cjs` 65/65, ownership 53/53; mutations result-ignored/lexical-sort/replay-all/skip-preflight/legacy-array дают 21/7/2/1/7 FAIL. Старые success fixtures `{}`/`ok` заменяются настоящим Messages shape, не ослабленным validator. Native bodies через adapter отдельно от device runner.
- `Array.isArray` сужает значение до inferred any[]: Node host это пропускает, ArkTS compiler — нет. После проверки array используй явный `Object[]` при итерации и повтори обе сборки. Отчёт: `docs/reviews/2026-09-06-reliability-wave7.md`.

## 130. Общий busy требует общего владельца; boot success требует рабочего guest
- Forward и composer меняют один page busy: controller-local counters недостаточны. Используй общий operation token, захваченный после старта; проверяй его вместе с lifecycle/chat перед deferred dispatch и после await. Cleanup не зависит от отозванного права отправки.
- Failed buffer нельзя возвращать после account reset либо поверх нового draft/edit/forward/attachment; иначе старый текст может стать caption чужой операции. Непустой required comment нельзя молча пропускать без text capability; уже отправленный comment не дублируется при retry forward.
- Процедура: `test-forward-send-ownership.cjs` 51/51; mutations `no-dispatch-guards`, `permission-cleanup`, `shared-owner`, `account-restore` дают 17/26/12/6 FAIL. Actual page/scoped-store path проверяется отдельно от typed native host; 6 native bodies через host adapter не равны device runner. Общие suites и forced main/ohosTest compile обязательны.
- TCP Connect OK не равен рабочему shell, screenshot success без файла не witness. Новый isolated API24 до установки проекта дал реальный shell и чёрный JPEG, затем тот же SceneBoard panic, что API24/API26 existing. Это исключает объяснение только кодом проекта/старым userdata, но не устанавливает GPU/RAM/OS root cause. После panic останови свои процессы; следующий boot — только с новым focused capture-планом, без reset/security изменений.
- Отчёт и hashes: `docs/reviews/2026-09-05-reliability-wave6.md` и соседний evidence JSON.

## 129. Разделяй права из payload и реально разрешённые действия
- Group status, type, membership, rights и wrapper — authoritative поля: legacy regex/cache может выбрать вложенный creator вместо настоящего banned. Используй strict top-level access по всему пути; проверяй actual normalizer → combined reducer → panel, а не один accessor.
- Restricted permissions — девять независимых send bits, не basic boolean. Сохраняй отдельный typed payload и deep clone; transport сам по себе не исправляет UI/guards. Для effective policy сначала прочитай TDLib `apply_restrictions` и booster path: безусловный default AND individual неверен для всех ролей.
- Процедура: `test-group-permission-payload.cjs` (115/115, actual native bodies через host adapter), mutations `alias`/`legacy-status` (2/5 FAIL), общие suites, forced main/ohosTest build, отдельный device gate. Отчёт — `docs/reviews/2026-09-05-reliability-wave5.md`.
- У boot есть разные границы: SceneBoard panic и launcher `Commit charge is not enough!` — не одна причина. Переданный `-hdcPort` без listener не доказывает включённый port path; отсутствие `-noWindow` при preflight отказе не проверяет windowed guest. Не повторяй неизменные boots и не меняй system/pagefile/image ради догадки.

## 128. Проверяй соединения между слоями, не только каждый слой отдельно
- Наличие handler, event и sub-reducer не доказывает доставку: combined router молча терял unread aggregate и chatMessagesReset. Permanent witness должен начинаться с actual normalizer/use-case и проходить combined reducer/store до selector или наблюдаемой границы действия. Audit declared sub-reducer cases ловит новые пропуски, но не доказывает покрытие всего TDLib.
- `updateChatPermissions` — отдельное live событие. Поле initial chat недостаточно: partial DTO, reducer и ручной `applyChatUpdate` должны сохранить explicit false; пропущенное значение не означает false. Для authoritative полей используй strict top-level object/boolean/number, без nested fallback/coercion/cache.
- Воспроизводимая процедура: `test-live-chat-permissions.cjs` (44), `test-live-permissions-review.cjs` (31), `test-unread-count-routing.cjs` (43), все host/source suites, forced main/ohosTest compile, затем отдельный device gate. Mutation tests возвращают ошибки при удалении route/handler и потере revoke/immutability.
- Старый блокер среды перепроверяй: 09-05 места уже хватало, но новый Pura API24 boot дал SceneBoard exits 4times → kernel panic. `isRunning=true` launcher не означает готовый guest; stdout screenshot success без файла не свидетельство. После подтверждённого panic останови свой экземпляр, не запускай бесконечные retries и не удаляй image/session без разрешения.
- Отчёт: `docs/reviews/2026-09-05-reliability-wave4.md`; public iOS references — отдельный provenance inventory, не подмена current runtime.

## 127. Access разрешает начать действие, но не определяет владельца его cleanup
- Membership/posting rights канала берутся из текущего group status, не из main/archive order и не из default chat permissions. Unknown остаётся неизвестным; status до newChat хранится по group ID. Проверяй весь путь normalizer → combined reducer → subscription, а не только изолированный reducer.
- Hydration не должна перезаписать более новый live status: сравнение захваченной map-value identity выполняется при dequeue. Literal numeric ID читай строгим accessor: regex fallback может принять вложенное поле или усечь дробь и вернуть правдоподобный чужой ID.
- Возможность редактирования не разрешает new text/sticker/GIF/voice/media sends. Проверяй актуальный scoped state на входе действия и после await; пустой edit не превращается в микрофон.
- Gated use-case getter нельзя использовать как единственный guard в finally: revoke/edit делает его undefined и оставляет busy навсегда. Cleanup принадлежит operation + lifecycle + chat, независимо от права начать новый send. Старый media batch не продолжает отправку после новой операции; не восстанавливай failed draft поверх edit/forward/new buffer.
- Процедура: seven R6 host suites из wave3 → review-witness → forced main/ohosTest compile → source smoke → отдельный device witness. `test-send-cleanup-ownership.cjs`: 52/52; in-memory возврат двух finally к permission guard даёт 28 FAIL. Отчёт: `docs/reviews/2026-09-05-reliability-wave3.md`.

## 126. Recovery — отзыв account capabilities, а не только новый client ID
- Stable root store нужен bridge/login lifecycle; старые domain store/adapter references должны инвалидироваться. Очистить state, но оставить старому callback доступ к новому store через getter — межаккаунтная гонка. Захватывай scoped store/adapter до await, затем проверяй generation.
- Runtime barrier отзывает scopes синхронно, очищает state в serial queue и лишь после await выдаёт новый scope. Failure выполняет тот же barrier; ошибка на экране сама по себе не останавливает late getMe/download.
- Реальный current-client auth update подтверждает bootstrap поколения. Поздний error/timeout вспомогательного getAuthorizationState не должен демотировать уже подтверждённый Ready/Wait* client; Closing/LoggingOut и старый client подтверждением не считаются.
- Lifecycle-проверки включают overlap и reuse: initialize должен дождаться старого shutdown/cleanup; concurrent calls join single-flight; новый scope повторного initialize не читает старые buckets. Не ограничивай тест последовательностью logout → login.
- Повторяемый набор: `test-td-gateway-recovery.cjs`, `test-app-store-session.cjs`, `test-td-gateway-adapter-session.cjs`, `test-runtime-account-recovery.cjs`, `test-full-account-recovery.cjs`, `test-runtime-lifecycle.cjs`, `test-recovery-supersession.cjs`, `test-login-recovery.cjs`. Затем forced main/ohosTest compile; device witness — отдельный gate. Отчёт: `docs/reviews/2026-09-05-reliability-wave2.md`.

## 125. Очередь проверяет lifecycle при dequeue, не только при enqueue
- Live message delivery не должна ждать getUser enrichment: даже resolved/cached Promise меняет порядок create/edit. Normalize и enqueue выполняются до первого await; hydrator остаётся deduplicated и generation-aware.
- После такого изменения независимый reviewer воспроизвёл запись в stopped store: `emit(newMessage)` → немедленный shutdown. Исправление — optional guard внутри AppStore serial queue, включая single-event путь dispatchBatch. Runtime host suite: 6/6; прямые dispatch без guard автоматически защищёнными не считать.
- Download identity принадлежит попытке, не fileId: cancel/clear/retry инвалидируют старый callback. Сначала установить владение состоянием, затем уведомлять listener; listener может синхронно отменить/повторить запрос.
- Procedure: `scripts/test-app-core-runtime.cjs`, `scripts/test-state-clone-file-pipeline.cjs`, `scripts/test-chat-media-download-controller.cjs` → forced main/ohosTest compile → UI-smoke/source scripts → отдельный device witness. Отчёт первого среза: `docs/reviews/2026-09-05-reliability-wave1.md`.

## 124. Ревью: зелёный compile не подтверждает инварианты runtime
- Ручные clone-функции должны сохранять новые семантические поля: source-harness 09-05 показал потерю `replyToChatId` при fileDownloaded и сброс `canSendBasicMessages=false` при cloneChat. Тесты обычных полей это не замечают.
- Serial AppStore не спасает порядок, если async handler переставил TDLib updates до dispatch. Тестировать вход через AppCoreRuntime; отменённый download отличать от новой попытки того же fileId по request generation.
- Разделять compile, source-contract, host-harness и device-runtime: main/ohosTest compile и общий smoke прошли, но 6 behavioral regressions и 6 дополнительных textual checks красные. Процедура и пределы: `docs/reviews/2026-09-05-project-review.md`.

## 123. ohosTest-сьют гниёт без компиляции; AppStore.dispatch — асинхронный
- `EventPipeline.test.ets` (d3bf112) прожил 5 дней с 80 ошибками ArkTS (nested funcs, obj-literals, any): main-build зелёный, а ohosTest-сьют никто не пересобирал после добавления файла. Правило: новый/изменённый тест = `hvigorw --mode module -p module=entry@ohosTest assembleHap` в гейты, иначе «зелёный main» скрывает мёртвый сьют.
- Второй слой той же находки: тест вызывал `store.dispatchBatch(...)` без await и сразу читал `getState()` — стейт ещё не применён (dispatch живёт на promise-цепочке). Паттерн для пайплайн-тестов: `await store.dispatchBatch(events)` перед ассертами (hypium: `it('…', 0, async () => {…})`).
- Фикстуры TDLib-объектов в тестах — только `TdObject.fromJSON('{"@type":…}')` (паттерн EventNormalizer.test.ets); `Map<MessageId,…>` ключуется СТРОКАМИ (int64-as-string), `.has(10001)` не компилируется.

## 122. Аудит 08-31: токены централизуют значения, «рецепты» — нет; гейты и слоты проверять матрицей, не памятью
- Урок 121 (рецепт стекла) перенесли в 3 файла, а старый `backgroundBlurStyle` остался в ~10 поверхностях — включая «общий» примитив `TgTopChromeBackground` (мёртвый: consumer только demo). Токен-правка значения расходится везде автоматически; правка рецепта живёт рукописно в `build()` каждого атома и сама никуда не расходится. Стеклянные волны делать через централизованный примитив/политику, не точечными правками «по памяти».
- Гейт нативного материала вручную дублировался в 6 поверхностях как `apiAvailable('26') && useBlur()` БЕЗ emulator-чека (против `TgGlassPolicy.supportsNativeMaterial()`) — на API 26 эмуляторе такие поверхности уходят в плиту ImmersiveMaterial. Правило: платформенный гейт — только через централизованную политику; локальные копии условия = будущий рассинхрон.
- Компосер рендерился в ЛЮБОМ чате (единственный isDisabled = `activeChatId===0`), а в iOS нижняя панель — полиморфный слот из 8+ панелей по статусу/правам (`ChatInterfaceStateInputPanels.swift:13`: Subscriber/Restricted/DeleteChat/Unblock/Handshake/…). Формулировка «готово» в STATUS читалась шире реальности; «сделано» по фичам сверять греп-матрицей состояний, а не по памяти о срезе.

## 121. Стекло в ArkUI: backgroundBlurStyle ≠ стекло на эмуляторном GPU-пути
- Симптом «сплошных плашек»: капсулы топ-бара/компосера с `backgroundBlurStyle(COMPONENT_ULTRA_THIN)` + тинтом выглядели непрозрачными плитами, хотя на референсе iOS — стекло с просвечивающим контентом. При этом полосы фейда на `backdropBlur` БЛЮРИЛИ контент на том же экране.
- Корень: `backgroundBlurStyle` — системный материал окна; на эмуляторном GPU-пути он коллапсирует в непрозрачную плашку (стиль почти не влияет: и THICK, и ULTRA_THIN). `backdropBlur(radius)` сэмплит РЕАЛЬНО нарисованный контент за нодой внутри приложения — работает и даёт настоящее стекло.
- Правила: (1) стекло над контентом приложения = `backdropBlur` + полупрозрачный тинт (клип по радиусу обязателен, это обычный кейс); (2) `backgroundBlurStyle` — только для системных поверхностей (bindSheet blurStyle) и нативных material-путей API 26 (`ImmersiveMaterial`); (3) `renderGroup(true)` снимать с backdropBlur-нод — группа изолирует слой и может убить сэмпл бэкдропа; (4) тинт под стекло должен быть заметным, но не глухим: dark ~40-60%, light ~70-75% (стекло без тинта невидимо, с глухим тинтом — плита снова).
- Диагностический приём: сравни два механизма на одном экране — если градиентные полосы блюрят, а капсула нет, виноват механизм материала, а не GPU в целом.
- Смежное: (1) iOS-эталон (App Store Messages.png, 2026-08) — контент за рядом тайтла ОСТАЁТСЯ читаемым; густой фроз только в статус-стрипе → тиры blur сверху вниз: STRONG (status) → MID (title row) → SOFT → 0, не сплошная стена STRONG на весь бар. (2) Скрим/блюр компосера прижат к нижней кромке экрана (dock-look), а не висит над капсулой; над верхом капсулы — только одна зона растворения. (3) `aa force-stop -b <bundle>` на этом образе может падать «package not installed» при живом процессе — работает позиционный `aa force-stop <bundle>`; `kill -9` из hdc shell запрещён (не root).

## 120. Среда эмулятора после обновлений Windows: слои лжи и лестница фолбэка
- Принудительный ребут от TrustedInstaller (KB-пакет 2026-08-28, включилась VBS) сломал гостя API 26 Beta1 детерминированно: фриз на ~100-й секунде бута (3/3 прогонов, kernel.log обрывается mid-line в фазе init), при этом API 24 образ на том же хосте бутится нормально → взаимодействие образ/драйвер/гипервизор, не проектный код. Не дебажить гостя вечно — держать рабочий фолбэк-инстанс (API 24) и детектить фриз: stall kernel.log ≥3 мин + hdc shell по таймауту.
- Ошибка `devecocli emulator start`: «system image cannot be found, download it again» — обёртка минимум ТРЁХ разных корней: (а) разовый таймаут spawnSync на проверке подписи PowerShell (лечится повтором), (б) префлайт CLI не видит isPublic=0 Beta1 в своём каталоге (лечится прямым запуском `Emulator.exe -start "<name>"`), (в) реальный гейт места: `CheckRuntimeEnv: "No enough space to start Emulator"` в инстансовом `Log\Emulator.log` (порог `freedisk` из config.ini, KB). Истину искать в `deployed\<name>\Log\Emulator.log`, не в тексте CLI.
- Бут требует свободного места больше, чем `freedisk` (конфиг 6ГБ): 7.8ГБ свободно — отказ, 30ГБ — проходит. Образ ~4.4ГБ + userdata qcow2 растёт.
- НЕ смертельные строки каждого бута: `SnUtil "can not read uuid file"` / `"can not read sn"` (после BootComplete) и `BootComplete: "the image is non-public", "User not logged in"` — норма Beta1, не чинить и не выдумывать маркер-файлы в Temp (рукотворный `Temp\<uuid>\uuid.data` ломает ранний путь через ReadSnFromDevManager «отказано в доступе»).
- `sdk-pkg.json` образа: `data.path` обязан совпадать с именем папки на диске (обрыв распаковки оставил `HarmonyOS-7.0.0-B1` при регистрации `HarmonyOS-7.0.0`) — правится точечной правкой метаданных (backup в %TEMP%\deveco), но сам по себе старт не разблокирует.
- `qemu HeartBeat stop!` в Emulator.log = гость умер внезапно посреди сессии. TDLib-сессия переживает рестарт эмулятора + `aa start` без перелогина (проверено на API 24) — рестартовать дешевле, чем реанимировать зомби.

## 119. Петля измерения: высота контейнера из @Local, измеряемого ребёнком этого же контейнера
- Оборачивая компосер в Stack с `.height(composerTotalHeight)` ради бэкдропа-перелива, получил схлопывание компосера до TextArea 8px (witness: `uitest dumpLayout`): Stack фиксированной высоты ограничивает замер детей → компосер сжимается → `onAreaChange` докладывает сжатую высоту в `composerTotalHeight` → Stack сжимается ещё → петля сходится к минимуму контента.
- Правило: НЕ пинить высоту контейнера величиной, которая измеряется (`onAreaChange`) от ребёнка внутри этого же контейнера. Рецепт здесь: Stack обнимает контент (backdrop выше компосера просто переливается вверх — Stack не клипает), компосер сохраняет интринсик-высоту на дне оверлея.
- Диагностика лейаута за 2 минуты: `hdc shell uitest dumpLayout -p ...` даёт точные bounds нод; тапы `uitest uiInput click` — в СЫРЫХ px дисплея (1320x2232), не в vp и не в нормализованных координатах скриншота.
- Прогрессивный блюр в ArkUI: нативного градиентного блюра нет — рабочий паттерн «ступени + скрим»: 2 backdropBlur-полосы (14→7) + чисто градиентный хвост, стопы одного оттенка с wallpaper-base (`chrome_fade_*`). Семантика направления (урок 120-эра, сверено с доками и кодлабом): `direction` — сторона, КУДА движется градиент; стоп-0 стоит на ПРОТИВОПОЛОЖНОЙ стороне (`Bottom` = стоп-0 сверху). Сводить оба билдера к одному соглашению: `Bottom` + стопы по порядку сверху-вниз.

## 118. height('100%') в auto-sized контейнере — грабля, пойманная ТРИЖДЫ
- Процентная высота внутри контейнера без собственной высоты (Stack/Row по контенту) резолвится против РОДИТЕЛЬСКОГО CONSTRAINT: в списке это вьюпорт (рельса на весь экран, бабл-гигант с карточкой в центре пустоты — пользовательский репро), при unconstrained — 0 (рельса тихо исчезает). Отсюда «некоторые корректны, некоторые нет».
- Хронология одной и той же грабли: quote bar (TgTextBodyV3) → reply snippet (TgReplySnippet) → link preview rail (TgLinkPreviewBubble). Правило: вертикальные рельсы/акцентные полосы в атомах — ТОЛЬКО `LayoutPolicy.matchParent`; при добавлении атома с полосой грепать `height('100%')`.
- Побочный витнесс тяжести бага: appfreeze нашего приложения в faultlog совпал по времени с прокруткой гигантского бабла (лейаут на всю высоту вьюпорта в reuse-строке).
- Эмулятор-инсталлы при тесном диске: HAP с двумя ABI (по две копии libtdjson ~35MB) — половина мёртвая; abiFilters x86_64-only даёт 83M вместо 152M и проходит порог. Вернуть arm64 перед сборкой на устройство.

## 117. Системные медиа-команды и диск эмулятора: два коротких урока
- Системные play/pause обязаны быть СТРОГИМИ и идемпотентными, не toggle: иконка карточки Пункта управления живёт своей жизнью и при рассинхроне toggle инвертирует состояние вместо схождения. Рецепт: pause → метод контроллера с guard'ом «только из playing»; play → гейт по isPlaying + toggle (из паузы toggle строго играет). Витнесс цикла: `cmd pause→JsPause Task`, `cmd play→JsPlay Task`, итоговый state playing.
- Диск эмулятора, уровень 2: порог install ≈1ГБ свободного; когда `bm clean -c` не спасает — `bm uninstall -n <bundle> -k` (keep-data) + install: код пересоздаётся, data/el2 с TDLib-сессией остаётся (проверено — чат-лист без перелогина). Медиа-кэш TDLib (animations 300M+, photos 200M+) и /data/log недоступны на запись из hdc shell (undebuggable сборка, smode запрещён) — чистить их можно только изнутри приложения (optimizeStorage — кандидат в настройки).

## 116. Обложки треков: пользовательская гипотеза ≠ механизм, референс решает
- Гипотеза «iOS берёт обложку из фото канала» разбилась о референс: Telegram-iOS качает арт СЕРВИСОМ по title+performer (MusicAlbumArtResources → AlbumCoverResource → webDocuments DC). В TDLib это готовое поле `audio.external_album_covers` — каскад ID3→external закрыл кейс без всякой эвристики по фото.
- Когда поля нет в наших моделях и td_api.tl недоступен (вендорен только .so) — `strings libtdjson.so | grep <field>` мгновенно подтверждает поддержку полем этой сборки TDLib.
- Диск эмулятора (код 9568288 insufficient disk memory при install): `bm clean -n <bundle> -c` (кэш, НЕ -d — там сессия) + `rm /data/local/tmp/*.json|png` (мои дампы/скрины копятся десятками MB) — освобождает сотни MB без потери логина.

## 115. AVSession/bindSheet/фон: заметки v2+v3
- AVSession подключается к уже готовому глобальному плееру одним листенером: мета-словарь на смене assetId + троттленный playback-state (флипы + ≥3с позиции) — сессия «бесплатно» даёт карточку Пункта управления, локскрин и команды с наушников. Контекст берётся в aboutToAppear корневой страницы (`getUIContext().getHostContext() as common.UIAbilityContext`), не в EntryAbility.
- Витнесс «команда из системы дошла» — hilog в session.on-колбэке, а «пауза исполнена» — родные `JsPause Task Start/Out/End` логи AVPlayerNapi: `JsGetState`-строки живут только пока тикает прогресс-таймер, после паузы их просто нет (отсутствие ≠ не сработало).
- Промежуточная модель обязательна: DTO-поле без дублирования в MessageContent (AppState) и ОБОИХ редьюсерах (messagesReducer + filesReducer clone-путь) — компайл-ошибка в VO-маппере. Поля медиа-контента живут в ЧЕТЫРЁХ местах.
- Слепой «already»-чек в патч-скриптах (grep по второй строке replacement) молча пропускает файлы — после массовых python-патчей перепроверять каждый файл грепом цели.
- bindSheet(560vp, showClose) — самый дешёвый нативный «полноценный плеер»: drag-bar, жест закрытия и скругления бесплатно; onDisappear синхронизирует @Local-флаг при жестовом закрытии.

## 114. Island Player v1: три ловушки одного среза
- TDLib file id — ТОЛЬКО `getTopLevelNumber('id')`: generic вложенный `getNumber('id')` первым находит `remote.id` (строка) и молча возвращает 0 → «no newer track» при живом кандидате. Грабля уже была описана комментарием в parseSharedMediaItem — читай соседний рабочий парсер ДО написания своего.
- Открытие чата — ритуал ChatListPage (активный чат в navigationUIState+chatUIState+AppStorage, unread-снапшот, navLock, requestOpenChatData). Голый `pushPathByName('TgChatScreenPage')` из другой страницы рендерит сплит-плейсхолдер «Чат не выбран». Внешним инициаторам — tick-мост параметром в живой ChatListPage.
- Хронологию сообщений мерить ТОЛЬКО по message id (int64, длина+лексика), не по видимым таймстампам: «изменено 20:05» — время правки, а не поста; из-за этого два «провала» ⏭ были на самом деле корректным концом плейлиста. Диагноз дал полный дамп ста id из инструментированного цикла.
- searchChatMessages с ненулевым from_message_id + отрицательным offset + фильтром вернул пусто на живом TDLib; надёжный паттерн — from='0' (newest-first) и выбор соседа в коде.

## 113. HdsTabs miniBar: prop-состояние не должно опережать style-транзакцию (линза под плеером)
- Механика HDS miniBar двухканальная: prop `miniBarStyle`/`barWidth` рендерят состояние БЕЗ ширинной транзакции, а `applyMiniBarStyle()` анимирует оба бара только при ДЕЛЬТЕ внутреннего стиля. Если prop уже EXPAND (отрендерен пока бар скрыт) — поздний apply = no-op без колбэков; бар выходит рассинхронённым (mini широкий, таб полный, внахлёст).
- Три слоя фикса, каждый подтверждён инструментацией (`onBarStyleChange`/`onMiniBarAnimationStart`/`onTabBarAnimationStart` + hilog): (1) защёлка applied — prop COLLAPSE до транзакции на видимом баре, флаг+apply в одном кадре (паттерн активации Search); (2) транзакция из монитора, сработавшего внутри animateTo (rootBarHidden flip), вкладывается в чужую анимацию и ломает раскладку — признак: mode=NORMAL вместо APP_TRIGGER; отложить до конца show-анимации; (3) ручной `barWidth=48` prop давит РАЗВЁРНУТЫЙ таб-бар в 48px «вертикальными колонками букв» — 48vp-линза одного таба создаётся только транзакцией, prop держать полной шириной.
- Диагностический приём: bounds-дамп текстовых нод таб-бара мгновенно отличает «настоящую линзу» (один таб) от «раздавленных табов» (все лейблы узкими вертикальными колонками x≈143-178).
- `hilog -b D -D 0x0020` включает debug-уровень домена на живом устройстве — debug-инструментация компонентных границ бесплатна в проде и бесценна в дебаге.

## 112. Глобализация плейбека и HDS-транзакции стиля: три ловушки одного среза
- Зеркало состояния и «нулевые» эмиты: `openAndStart()` начинается с `release()`, который эмитит снапшот `messageId='0'` — листенер-зеркало честно чистило мету, затирая только что опубликованный тайтл нового трека. Мета обязана жить у владельца (wrapper) и повторно применяться на КАЖДОМ ненулевом снапшоте, а не записываться однажды в UI-стейт.
- `HdsTabsController.applyMiniBarStyle()` на скрытом (или только что пере-показанном) баре игнорируется без ошибки: prop `miniBarStyle` рендерит контент, но таб-бар не сжимается в линзу — плеер рисуется поверх табов. Один отложенный re-assert 360мс (паттерн search-фокуса) НЕ решает; открытый пункт — хендшейк через onTabBarAnimationStart/onBarStyleChange.
- Скролл-охота по прыгающему чат-листу — худший способ добраться до сообщения: живые обновления телепортируют строки между дампом и кликом. Надёжные пути: фильтры (Личные), профиль → Shared Media (Voice/Files/Links — стабильный список), guard «клик в той же итерации, что и дамп».
- Эмулятор способен уронить ХОСТ: temp-файл qemu раздулся до ~66ГБ → C: 0 байт → сборки падают на `MergeProfile` с кодом `00308018` («Unknown Error», на деле нет места), затем гибнет сам эмулятор (temp освобождается его крашем). Перед длинной сессией — `df -h /c`; `entry/build` с вендоренным нативом весит гигабайты и удаляется безопасно.

## 110. hdc install печатает «AppMod finish» и при ПРОВАЛЕ установки
- Repro: диск эмулятора заполнился (HAP вырос до 158MB из-за вендоренного нативного слоя) → `install failed due to insufficient disk memory. code:9568288`, но следом всё равно печатается `AppMod finish`. Усечённый `| tail -1` показывал только его — цепочка build→install→force-stop→start выглядела зелёной, а рантайм крутил СТАРЫЙ код: новые логи не появлялись, хотя строка была в собранном `modules.abc`.
- Диагностическая лестница, которая сработала: лог отсутствует → grep строки в built HAP/abc (строка есть) → значит стейл-рантайм → полный вывод install → ошибка места.
- Правила: (1) успех установки = grep «install bundle successfully», не «AppMod finish»; (2) при «фикс не проявился» первым делом сверять, что артефакт ДОЕХАЛ (строка-маркер в abc + успешный install), лишь потом дебажить код; (3) держать `/data/local/tmp` чистым — витнесс-артефакты прошлых сессий съели место.

## 111. Скролл-колбэки List получают и не-жестовые кадры
- `onScrollFrameBegin` стреляет и на layout/data-шторм кадрах при холодной синхронизации (прилетают с положительным offset) — авто-скрытие острова срабатывало без единого касания. Фильтр: реагировать только на `ScrollState.Scroll | Fling`.
- Паттерн «адаптивный бар»: дочерняя страница шлёт latch-free события по гистерезису (24vp аккумулированного направления), хост дедуплицирует против своего состояния и владеет guards/сбросами (поиск, сплит, вход в чат, смена таба). Латч на стороне отправителя рассинхронизируется с принудительными показами хоста.
- Анимируемость: свод всех входов в один `@Local`, меняемый внутри `animateTo` (`@Local`-ссылка на `@ObservedV2`-синглтон + `@Monitor('field.path')` — документированный паттерн) — дал анимированный hide/show нативного `HdsTabs` без кастомного рендера бара.

## 109. Git Bash молча конвертирует абсолютные аргументы hdc в C:/Program Files/Git/…
- Repro: `aa test … -s unittest /ets/testrunner/OpenHarmonyTestRunner` из Git Bash умирал с `Cannot find module '…entry_testC:/Program Files/Git/ets/testrunner/…'` («App died»), а `hdc file recv /data/local/tmp/x.png` падал с «no such file or directory, path:C:/Program Files/Git/data/…» — MSYS переписывает всё, что похоже на POSIX-путь.
- Fix: префикс `MSYS_NO_PATHCONV=1` для ЛЮБОЙ hdc-команды с remote-путями (`shell aa test`, `shell uitest dumpLayout -p`, `file recv/send`). Рецепт on-device раннера из урока 67 работает из Git Bash только с этим флагом.
- Также: перед инструментальным `aa test` нужен `aa force-stop` — живой процесс приложения даёт тот же «App died» без jscrash-подсказки.

## 108. Рендер-атом и measurement-движок дублируют геометрию — дрейф не ловится компилятором
- В паре TgReplySnippet/TgBubbleLayout полоса бара жёстко считала «1 тайтл + 2 превью», пока maxLines разрешали 2+3; ширина сниппета повторно умножалась на bubble-ratio поверх уже ужатой движком ширины (на regular-ширинах — до 0.42×). Оба дефекта невидимы для сборки и smoke.
- Правило: у каждого числа в атоме (высота, inset, ratio) должен быть ровно один владелец. Полосы/фоны, обязанные совпадать с контентом переменной высоты, — только `LayoutPolicy.matchParent` (паттерн quote-бара, урок про height('100%') остаётся в силе); ширины, уже посчитанные движком, передавать с `maxWidthRatio: 1.0`, а не давать атому «улучшать» их дефолтным ratio.
- При любом изменении атома сверять его констант-лист с соответствующим measure* в TgBubbleLayout; расхождение — дефект, даже если «на глаз похоже».

## 107. Компайл-гейт ohosTest маскирует красноту до первого настоящего прогона
- Первый полный on-device прогон после серии срезов 18–19 июля: 580 тестов и ДВЕ незадокументированные красноты (gallery-refresh читал `sourceMessageId` без фолбэка) поверх двух известных. Все срезы при этом были «зелёными» по OhosTestCompileArkTS.
- Правило из урока 67 усилено: после каждого пласта, трогающего core/domain/VO, гонять сьют на устройстве, а не только компилировать; «known failures» фиксировать поимённо в STATUS, чтобы новый фейл был отличим от фонового.
- Литералы UI-строк в гвардах — мина: `refreshRestoredReplySnippet` сравнивал с literal `'Message'`, тогда как источник ставит локализованное значение — ветка мертва во всех локалях, кроме английской. Гвард и источник обязаны брать одну и ту же локализованную константу.

## 106. A grouped-media row has two identities: the album container and the tapped member
- Telegram collapses several TDLib messages into one visual row, but selection, refresh and spatial transition belong to the exact member. Give every cell a stable real-or-synthetic member identity, attach `geometryTransition` to that cell, and hide only the active cell; binding the primary row id to the whole mosaic creates a smooth but spatially false morph.
- A non-empty album path can be only a thumbnail fallback. Carry `fileId`, `hasLocal`, `downloading`, `progress` and controller-derived failure as index-aligned arrays through Page → Router → live media shell → atom; do not infer transfer completion from `photoPaths[index]`.
- Count-only 2/3/4 grids cannot be polished into iOS parity. Keep mosaic calculation pure, dimension-driven and unit-tested for 2–10, then render deterministic frames with per-cell hit targets. Include album path/local/progress in the recycled-row fingerprint or thumbnail→full replacement can remain visually frozen.
- Runtime acceptance must prove that non-adjacent taps belong to the same hierarchy parent, not merely to visually adjacent mosaics. One verified six-member row produced `42 / 51`, `45 / 51`, `47 / 51` for indices `0`, `3`, `5`; the earlier `45 / 51`, `48 / 51`, `50 / 51` sequence crossed two three-cell rows and therefore could not prove same-row routing.

## 105. A Compose screen must select peers, not merely relabel a dialog picker
- Telegram iOS `ComposeControllerNode` uses contacts plus Group/Contact/Channel actions; showing `TgChatRow` previews under a `New Message` title was a plausible but behaviorally wrong reuse. Keep Forward and Compose as separate surfaces once their data semantics diverge.
- `createPrivateChat` is the source of truth for a known user: validate the returned `Chat` type and exact `peerUserId`, then carry its id through a typed pop result. The reducer update may arrive after the response, so navigation can use that exact returned id/name without inventing an id or choosing another stored dialog.
- On current API23, a typed zero-result pop is also a lifecycle contract: bare Back can remove a destination visually without releasing the caller's duplicate guard. Acceptance must include Back → reopen and distinct destination ids, not only the first successful open.
- Preserve honesty while building parity incrementally: defer Group/Contact/Channel rows until their route and TDLib use case exist, and label source-derived geometry as unverified pixel parity until a current shipped-iPhone Compose capture is available.

## 104. A shared transition ID is not enough to prove a shared-element animation
- ArkUI `geometryTransition` needs the same identity on exactly two in/out nodes, a parent `animateTo` transaction, and a `transition` on disappearing content so it is not destroyed before the morph completes. The project already had the ID and spring, but omitted endpoint retention; final screenshots alone could not expose that gap.
- Bind the media node, not the whole captioned bubble. This keeps sender/reply/caption chrome out of the expanding geometry and gives a natural opacity fallback when the original lazy-list row is no longer rendered.
- Verify motion with an intermediate frame, not only before/after screenshots. The API23 sequence caught the video between bubble and fullscreen sizes, then showed close returning to one source node; that is evidence the geometry path engaged rather than a plausible instant screen swap.

## 103. Remote visual-media open and download are parallel concerns
- A tap on remote visual media must not serialize navigation behind transfer completion. Open the existing gallery immediately and start exactly one idle download; if the transfer is already active, open without issuing a duplicate request. Keep cancel ownership on the transfer control rather than overloading the media-surface tap.
- Full local media, local thumbnail, and TDLib `minithumb` are three different states. Only the full path enables playback; the local thumbnail is the preferred preview, while a blurred minithumbnail is the final continuity fallback for the fullscreen pending state.
- A download log alone does not prove the user-visible path. The acceptance witness must show the gallery and active transfer simultaneously. Here item `8 / 10`, `LoadingProgress [598,1384][710,1496]`, and `ChatMediaDownload fileId=12085` were captured during the same remote-video interaction; the clean package then reopened the resolved video at the same index.

## 102. Peer role must gate ChatList presence before the avatar atom
- Raw `userStatusOnline` is not sufficient UI truth for every peer role. The live bot `zai` reached `ChatItemVO` as online, which produced a plausible but incorrect ordinary-user green dot; the shipped iOS row and the chat-title role both identify it as a bot.
- Keep this adaptation in the view-object projection (`online && !isBot`), not inside reusable `TgAvatar`: the atom should render the boolean it receives, while peer semantics stay with the mapper.
- Verify a semantic removal with stable geometry. Here the dot node `#FF4DCC5E [189,1060][238,1109]` disappeared while avatar `[35,906][245,1116]` and title `[273,945][344,1008]` remained unchanged; a focused test protects the positive ordinary-online branch.

## 101. Date header capsule height and date-header row height are different contracts
- Telegram iOS uses a `22pt` date pill inside a `34pt` list header. Reusing the header height as the pill minimum made Harmony render a `34vp` capsule inside a `46vp` row; the plausible token silently doubled the vertical air.
- Keep date and service-event geometry independent even when they share one atom. The compact date variant can be `22vp / radius 11`, while multi-line service events retain their roomier minimum and padding.
- Date text must follow the app language, not blindly the system locale. `Intl.DateTimeFormat(undefined, ...)` produced English `July 10` inside a Russian Telegram UI on the emulator; Telegram iOS uses presentation strings. App-qualified full month resources and localized order templates produced `10 июля / 11 июля / 14 июля` and preserve English/Chinese ordering separately.
- The reliable witness is a same-chat dump: pill `119px -> 77px`, enclosing item `161px -> 119px`, plus the live label delta. A correct-looking intermediate using the wrong locale gets no completion credit.

## 100. Chat-list density must come from the source formula, not screenshot guessing
- Current Telegram iOS derives the normal base-font row to 72pt and centers its capped 60pt avatar with 6pt vertical insets. The previous 76vp token looked plausible but produced a visibly looser list and only 8vp avatar insets.
- A one-token density change is safe only when Chat and Archive rows share that token and the runtime dump proves both row height and child bounds. Here API23 changed `266px -> 252px` while the avatar remained `210px`, giving the exact 21px/6vp inset.
- Keep horizontal meta/title work independent from vertical density: shrinking the row must not reintroduce the old shared right-meta reserve or alter native HDS chrome.

## 99. Chat-list title and preview do not share one right-side budget
- Telegram iOS measures the title against `date/status` (`titleRectWidth`) and the preview against `badge/mention/pin` (`textMaxWidth`) independently. A single fixed meta column is stable but visibly over-truncates both lines.
- In ArkUI, keep the native intrinsic width of two trailing Row atoms and give the corresponding title/preview body `layoutWeight(1)`. Preserve fixed line heights, not a worst-case horizontal placeholder, in the live row.
- The composed fixed-width `TgChatMeta` can remain for standalone jump probes or older integrations; do not force that conservative demo geometry back into `TgChatRow`.

## 98. TDLib active stories arrive as updates, not as the load response
- `loadActiveStories(storyListMain)` returns only `Ok`; the usable peers arrive through `updateChatActiveStories`. Store the complete typed snapshot and treat `order=0`, a non-main list or an empty story vector as removal.
- Preserve TDLib ordering exactly as `(order, story_poster_chat_id)` descending. Story ids within one peer are chronological, so the last id is the latest and unread is `latest > max_read_story_id`.
- Story poster chat ids can be negative groups/channels; only `0` is invalid. Hydrate missing posters with `getChat`, reuse the existing chat/avatar identity path, never synthesize title avatars, and keep the strip non-interactive until a real viewer route exists.
- `loadActiveStories` returns 404 when exhausted. An empty preview strip is a valid account state, not a reason to render samples.

## 97. Полный emoji-каталог нельзя держать в eager `ForEach`
- Telegram iOS задаёт hierarchy/search/entity behavior, но canonical neutral Unicode palette безопаснее генерировать clean-room из Unicode `emoji-test.txt` в CLDR order, а не копировать GPL-массивы Android/Nekogram. Для Unicode 17.0 после исключения skin-tone modifier rows остаётся 1914 fully-qualified base sequences в девяти keyboard groups.
- `Grid` + обычный `ForEach` создаёт сотни offscreen `Text` cells при открытии People/Flags. Для такого каталога нужен `IDataSource` + `LazyForEach`; category switch делает `onDataReloaded`, а recents остаются отдельным parent-owned набором.
- Source count сам по себе не доказывает engagement. Runtime witness должен выбрать отсутствовавшие раньше People/Flags, увидеть localized section title и проскроллить до изменившегося набора lazy cells; иначе UI мог остаться на старом Recent fallback.

## 96. Safe-area snapshot после adaptive rotation нельзя считать устойчивой геометрией
- При `NavigationMode.Auto` portrait `TYPE_SYSTEM.topRect` после split → stack может кратко вернуться как `0`, хотя runtime bounds по-прежнему начинаются после 137px status area. `Area.globalPosition` и `Area.height` здесь тоже не спасают: `onAreaChange` отдаёт original expanded geometry (`822.857vp`), а UI dump показывает уже clipped bounds.
- Для custom ChatList chrome сохраняй последний реальный portrait top inset вне пересоздаваемого component instance, используй свежие `windowSizeChange.width/height` для различения portrait/landscape и принимай положительный platform inset в любой ориентации. Landscape с нулём остаётся нулём; portrait с transient zero восстанавливает cached inset.
- Динамический `List.contentStartOffset` сам двигает top chrome, но не гарантирует re-alignment первого item после возврата. Если список действительно стоит на start (`headerCollapseOffset == 0`), после изменения inset на следующем layout tick вызови `scrollToIndex(0, false, START)`; scrolled list не сбрасывай. Acceptance — exact initial/round-trip bounds, а не только отсутствие status-bar overlap.

## 95. Link preview нужно вести как сквозной media-aware content path
- Текущий локальный `td_api.tl` определяет `messageText.link_preview`; старый `web_page` в typed-model слое не является актуальным runtime-контрактом. Перед UI-работой проверяй `td_api.tl`, а legacy field оставляй только явным fallback.
- Для preview poster недостаточно DTO/VO: thumbnail id должен попасть в bounded background-download, `filesReducer` обязан сохранить preview identity при clone, а `ChatTimelineDataSource` и media render stamp — инвалидировать recycled row после появления пути.
- В engine-driven text bubble preview задаёт минимальную ширину и отдельную meta-строку; иначе время/status может наложиться на нижнюю часть карточки. ArkUI helper внутри `@ComponentV2` не называй `backgroundColor` и другими common-attribute именами — это конфликтует с `CustomComponent` API уже на CompileArkTS.

## 94. `NavDestination` bounds do not prove that custom transparent chrome is below the status bar
- The old opaque `TgTopBar` measured `TYPE_SYSTEM` internally, so its runtime dump began below the 137px status area. Replacing it with transparent independent capsules and assuming `topInset = 0` moved Back/title directly under the clock even though the route and `NavDestination` were unchanged.
- Production custom/material chrome must measure the current window `getWindowAvoidArea(TYPE_SYSTEM)` itself (or receive the same single-source inset from the page). Keep an explicit `topInset: 0` only for isolated previews.
- Preserve the combined vertical contract while changing surfaces: after adding the measured inset, Forward Search stayed at 36vp, the List returned to the exact baseline `y=479`, and 76vp chat rows remained 266px. Runtime geometry, not a successful build, is the safe-area witness.

## 93. Custom-emoji entities live in UTF-16 text coordinates, not in panel state
- TDLib and Telegram iOS describe entity offsets/lengths in UTF-16 code units; ArkTS strings already expose compatible indexing, so reconciliation must preserve/shift spans around an edit and drop only spans intersected by it. Clearing every custom-emoji id on any `TextArea` change silently destroys valid draft semantics.
- Selection is part of the composer contract: use `TextArea.onTextSelectionChange` for the active range and `TextAreaController.caretPosition` after panel insertions or keyboard handoff. The entity array must travel through draft parsing, normalizer, reducer and deep clone alongside the text.
- Plain `TextArea` can preserve and send the exact custom-emoji id while rendering fallback Unicode. Animated inline media is a different rendering concern and should be a separately gated `RichEditor` migration, not mixed into entity correctness.

## 92. Source points are a hierarchy baseline, not a blind cross-device scale
- Telegram iOS source correctly defines 44pt actions and a 54pt Search collapse path, but copying every point 1:1 into a 1308×2880 Harmony runtime produced visually oversized chat-list chrome. The shipped screenshot plus actual emulator density is the acceptance witness.
- Preserve behavior and hierarchy constants that matter (independent islands, centered title, exact 54vp collapse, pinned filter). For cross-screen consistency, reuse the accepted in-chat control tokens directly (`38vp` visual + `44vp` response) instead of copying their values; derive subordinate rails proportionally (`32vp`) without touching list rows or the native HDS tab bar.
- Shipped dark Telegram iOS uses a semantic navy hierarchy, not the generic global `#1C1C1E / #2C2C2E` pair. Scope the palette to ChatList and inject row surfaces into reusable atoms; do not recolor unrelated screens. If an overlay background covers a collapsing child, shrink that background by the same collapse delta or it becomes an empty opaque plate over content.
- Direct `Text` children in a `Column` can remain cross-axis centered; list title/preview columns that must share the normal text axis need explicit `HorizontalAlign.Start`. Dark glass action glyphs use navigation primary foreground, not Telegram accent blue.

## 91. `contentStartOffset` меняет scroll-witness: проверяй полный возврат, а не один короткий swipe
- У chat-list верхний Search живёт в `List.contentStartOffset`: после collapse первый видимый Archive ещё не доказывает, что список вернулся в исходную expanded-позицию. Короткий автоматизированный swipe может оставить ровно consumed Search band, поэтому filter rail остаётся pinned корректно.
- Надёжный witness — начать жест внутри реального List (не на overlay rail), довести до spring/start boundary и увидеть Search снова. Для collapse state накапливать per-frame offset и clamp к 54vp; `onReachStart` сбрасывает состояние только на истинной границе. Не объявлять баг по промежуточному кадру.
- Title avatars в актуальном Telegram iOS — Story subscriptions, не случайные account avatars. Пока Story runtime/model отсутствует, компонент может принимать real preview inputs, но production page должен показывать обычный title и не рисовать fake circles.

## 90. API availability guard должен быть literal и двойным: `apiAvailable` + `@Available`
- Для API26-only ArkUI API компилятор отклоняет `deviceInfo.apiAvailable(CONSTANT)`, даже если константа равна `'26.0.0'`: версия должна быть literal `deviceInfo.apiAvailable('26.0.0')`, иначе `11706013 Invalid parameters for apiAvailable`.
- Надёжный cross-version паттерн: вынести API26 вызовы в builders с `@Available({ minApiVersion: '26.0.0' })`, а каждый call site держать под literal guard. Это одновременно сохраняет API23 runtime fallback и убирает compatibility warnings; сравнение только `sdkApiVersion >= 26` недостаточно строго для availability checker.

## 89. Gitignore не разгружает IDE: тяжёлые reference repos держать вне workspace
- `рефенсы/` был исключён из Git и CPL scan, но nested repositories всё равно доступны IDE indexers, antivirus и неосторожным recursive tools; один Nekogram уже даёт 31K файлов / ~708 MB. Канон: external root `C:\Refs\Telegram`, pinned registry `REFERENCES.md`, без junction обратно в проект.
- Для актуальности UI source недостаточен сам по себе: latest installed Telegram iOS runtime screenshot/video — shipped visual truth; `Telegram-iOS-current` даёт hierarchy/states/constants и может отставать от App Store. Старый snapshot хранить отдельно для воспроизводимости, не перезаписывать.

## 88. Конкурентный client — behavioral reference, не donor code
- Перед clone/сравнением доказать canonical identity через официальный сайт/README, затем зафиксировать commit, license, platform и backend. ArkGram оказался закрытым HAP-derived artifact без public source/license; Nekogram — GPL-2.0 Android fork с direct MTProto/TGNet, а не TDLib.
- Переносимый результат — feature/state matrix, UX semantics и edge cases. Decompiled ArkGram code/assets копировать нельзя; Android/GPL Nekogram code нельзя подмешивать в ArkTS/TDLib без отдельного licensing decision. Реализация только clean-room поверх локального `td_api.tl`, текущих use-cases/controllers и ArkUI docs.

## 87. Отрицательные chat id — системная мина: гварды `<= 0`/`> 0` молча режут все группы и каналы
- Telegram: supergroup/channel id ОТРИЦАТЕЛЬНЫЕ (-100...). Три экземпляра одного бага в одном потоке (openProfile, loadProfile, onReady-параметр): функция «работает для лички, молча no-op для групп». Валидация только `!== 0`/`=== 0`.
- Грепать при подозрении: `chatId <= 0|chatId > 0` — исключение легитимно только там, где речь О ЮЗЕРАХ (userId положительные, напр. звонки).

## 86. TextArea(text:) — только отображение; программный префилл требует двустороннего биндинга
- Симптом: setDraftText рисовал текст в поле, но первый ввод начинал С ПУСТОГО внутреннего буфера (edit-префилл затирался клавишей). Прямой prop не заталкивает значение в нативный буфер компонента.
- Канон: @Local-зеркало парамет + @Monitor-синхронизация + `TextArea({ text: this.buffer!! })` (двусторонний `!!`, API 18; для V1 — `$$`). Дока TextAreaOptions прямо советует биндить состояние двусторонне.
- Инструментальное: `uinput -K -t` в СФОКУСИРОВАННЫЙ TextArea ненадёжен — то подставляет текст целиком (затирая буфер), то молча дропает; для witness клавиатурного ввода на эмуляторе доверять только реальным тапам по экранной клавиатуре или ручному прогону.

## 85. Скриптовая правка файла: не открывать целевой файл на запись до готовности контента
- python-heredoc с эмодзи в Windows-консоли упал на суррогатах ПОСЛЕ open(p,'w') — целевой файл обнулился (0 байт); git restore спас. Паттерн: собрать контент → проверить encode → писать во временный файл + os.replace; либо просто Edit-инструмент (UTF-8-безопасен).
- Тот же заход, вторые грабли: heredoc-текст с последовательностью «бэкслеш-U» в обычной python-строке ломает парсер (unicodeescape) — не-ASCII в heredoc-скриптах только через именованные переменные с chr()/кодами, а лучше вообще не через heredoc.

## 84. LazyForEach перестраивает строку ТОЛЬКО при смене key — notifyDataChange со стабильным ключом это no-op для V2-строк
- Симптом-цепочка (охота 3 тика): скачанный файл не оживлял бабл до перезахода. Трасса показала: transfers пишутся, rebuild идёт, diff находит строку, notifyDataChange уходит — а @Param в @ComponentV2-строке остаются создания (Monitor-проба молчит). Док-канон: «After message is changed, the KEY of the list item changes. As a result, LazyForEach REBUILDS the item» — ключ и есть механизм обновления.
- Фикс-паттерн: в key запекается render-штамп изменяемого визуального состояния (`msg_<id>_s<stamp>`: пути есть/нет, downloading-флаги, прогресс бакетами по 10%, заполненность альбома), а diff-структура (same-order/append/prepend/anchor) сравнивает stableKey БЕЗ штампа — иначе смена состояния выглядит как смена порядка и валится в reload.
- Смежные грабли той же охоты: (а) `.reuseId()` на ListItem — V1-механизм, с V2-строкой молча оставляет компонент со старыми @Param (для V2 есть @ReusableV2 + `.reuse()`, API 18+); (б) `applyFilePathToContent` клонирует MessageContent вручную и ТЕРЯЕТ uniqueId-поля (uid=0 после клона) — при ручных клонах сверяй список полей с классом.

## 83. Глобальный `hilog -b D` оживляет ВСЕ накопленные debug-логи — это тот же writev-шторм
- 6-й THREAD_BLOCK_6S (17:49): стек снова HiLogPrint→writev. «Безопасные» debug-логи (per-entry timeline на каждый rebuild, per-file normalizer) молчат лишь пока уровень INFO; глобальное включение D на живом синке = шторм = watchdog-килл.
- Правила: (1) per-entry/per-rebuild логов не существует ни на каком уровне — удалять после диагностики; (2) debug включать только точечным доменом `hilog -b D -D 0xD0000XX`; (3) одноразовая диагностика пользовательского клика — info-однострочник (1 тап = 1 строка), виден без смены уровня.
- Смежное: параметры @Param, влияющие на обработчики (fileId!), обязаны передаваться во ВСЕ вызовы компонента — молчаливый дефолт 0 превращает обработчик в no-op без единого лога (photoFileId/videoFileId в Router не передавались с самого создания медиа-веток).

## 162. Retire only the accepted sequential prefix

- A partial sequential write must update its owned remaining selection after each validated acceptance. Consume the original first-item caption/reply/entities/caret once; update the captured revision after synchronous owned setters.
- Uncertain URI history belongs to the existing account/chat/lifecycle/use-case owner. Count current marks so known rejection releases only its own mark; keep older uncertainty and bound the ledger conservatively.
- Check the same current input around confirmation, preparation and acceptance. Delete only owned never-submitted or explicitly rejected copies; accepted/uncertain copies can still be used by TDLib.
- A boolean mode can change and return to its previous value while awaiting. Reproduce through actual public handlers and advance the existing input revision on real forward-mode changes. Equivalent setter values stay no-op.
- Native dialog evidence uses real mounted UI and deterministic transport; it does not establish provider grants, codec handling or Telegram delivery. Report: `docs/reviews/2026-10-02-document-video-resend.md`.

## 163. Timed slow mode and native Resource witness

- Anchor TDLib relative expiry once to STARTUP uptime, gate each new side effect after waits, and preserve accepted cleanup ownership separately. Stopped recording stays preview and expiry never sends.
- API24 entry_test rendered compiled Resource colors black although ResourceManager resolved them; identical main widgets rendered correctly. Reproduce with direct/imported/named/literal controls before changing production tokens. Exact installed runtime adapter root cause remains unproven.
- AA custom argument keys include `-s `; read the official contract. Set app-local color mode only after successful loadContent and gate UI readiness. Main validation must compile the whole registry and fixtures together to preserve singleton identity, target a dummy bundle, and retain strict owner/route/caret/modal assertions.
- Keep failed runs and stale-source receipts separate. A passing callback footer does not establish pixels, main ownership or theme. Unique screenshots, raw configuration trace, exact callback pairs and byte guards are required.

## 164. Per-message picker data and the contract-text harness

- `getMessageAvailableReactions` returns `availableReactions` with three ordered lists; parse each
  `availableReaction.type`, dedupe inside a list, drop unsupported types (paid/unsupported), and keep
  `allow_custom_emoji`/`are_tags` as flags. Merge top→recent→popular with a cross-bucket dedupe and a
  cap, then fall back to the chat-level row when the answer is empty — a failed request must never
  empty the picker.
- A new command that is not added to the `AnyAppCommand` union fails later with a confusing
  `arkts-no-structural-typing` error at the `send(...)` call site, not at the command declaration.
- Page-delegate bodies are compiled by host suites from reconstructed contract text with explicit
  `deps`. Adding a same-module sibling call (`chatLevelPickerKeys`) inside `showMessageActions`
  breaks every suite that compiles that boundary with `{}` — inject the siblings where the boundary
  is compiled, and bump the reactive-field counter when a new `@Trace` field appears.
- Fence an async answer with everything that can change while it is in flight: generation, lifecycle
  token, chatId and the open messageId. Also re-check the chat policy on arrival so a stale response
  cannot reintroduce reactions into a chat that forbids them.

## 165. Reactions footer under media bubbles lives in the router

- Media balloons (`TgPhotoBubble`, `TgDocumentBubble`, `TgAudioBubble`, …) each own a different
  container, so a per-atom footer would be six copies of the same row. The router already knows the
  content type, the bubble side and the avatar lane — render the row there, outside the media
  container, aligned to `isOutgoing`, and keep the balloon atoms free of reaction wiring.
- Text keeps its inline footer inside `TgTextBubbleV3`; a host contract must assert the router adds
  no second row in the text branch, otherwise a future refactor will double-render reactions.
- Stickers are the exception: their column has a fixed media height, so a footer needs a layout
  adapter first. Record it as debt instead of squeezing the row into a clipped column.
- Geometry under media is not verified by host tests: chips size themselves from content, so the
  row's width/padding needs a device screenshot before claiming parity.

## 166. Verification slice: a stale `missing` row hid a working feature

- C6 sat in the matrix as `missing`, yet the timeline already emitted `kind='unread'`, the viewport
  rendered `TgUnreadMarker`, and the geometry mirrored iOS (`ChatUnreadItem.swift`). What was missing
  was tests, a passport and honest evidence — not code. A verification slice should start by reading
  the suspect owner, and if the code exists, the deliverable is contracts + docs rather than a rewrite.
- The divider shared the chat-list filter string ("Unread"); iOS uses `Conversation_UnreadMessages`
  ("Unread messages"). Separate resources for separate meanings — reusing a short label silently
  changes user-visible wording.
- Sticky unread boundary is easy to break: the live `unreadCount`/`lastReadInbox` reset on read, so
  the captured entry-time boundary must win; assert both paths in the contract.

## 167. Selection mode touches every layer, and the harness slices between exports

- A modal row interaction (selection) is not one atom: state in \`ChatTimelineViewState\`, aliases in the
  context, port methods in two interfaces, seven session delegates, one controller item, a page swap and
  a row overlay. Budget the slice for the wiring, not for the panel widget.
- \`fullExport\` in \`chat-screen-source.cjs\` slices from \`export function X(\` to the next line that starts
  with \`export\`. A comment block placed immediately before the next export becomes the tail of the
  previous export's contract text and fails \`full.endsWith('}')\` — keep comments inside function bodies
  or above the previous export, never as a header for the next one.
- To make a row toggle without hijacking child taps, disable the bubble subtree in selection mode and own
  the tap on the outer row: \`.enabled(!selectionActive)\` + one \`onClick\`. Wrapping individual media
  callbacks would need a guard in every lambda and still misses empty areas.

## 168. Design skills are usefu as a lens, but iOS source still owns the numbers

- `apple-design` (WWDC fluid-interface principles) transfers to ArkUI at the level of intent: press
  feedback on touch-down (native `Button` state effect instead of custom handlers), materials as glass
  (`backdropBlur` + tint via `TgGlassPolicy`), 40-44 pt tap targets, and hierarchy from translucency.
  It does not provide ArkUI numbers — `ChatMessageSelectionInputPanelNode.swift` does (panel 40, buttons
  40x40, computed spacing).
- `FontWeight.SemiBold` does not exist in the target SDK's enum (only Lighter/Normal/Regular/Medium/
  Bold/Bolder), and an invalid enum member surfaces as a confusing `arkts-no-any-unknown` on the token
  line. Check the SDK enum before inventing a weight.
- A glass bar over scrolling chat needs the blur on the bar **and** on each floating control; stacking a
  light translucent surface on another light one kills legibility, so panels keep one tint layer.

## 169. Saved Messages has no type flag, and a VO flag needs a diff entry

- TDLib models Saved Messages as a private chat with the account's own user id (`td_api.tl:8726`
  says to call `createPrivateChat` with `getOption("my_id")`). Identity therefore needs `state.auth.userId`,
  which only arrives through `getMe` — before that every chat must stay a normal peer chat.
- A new `ChatItemVO` field is invisible until `ChatListDataSource.isSameChatRow` compares it; the diff is
  an allowlist, so the avatar glyph silently never appeared until the flag was added there.
- Presentation and entry point are separate slices: rendering the bookmark avatar and the title does not
  make the feature reachable. Record the open-chat transaction (nav lock, ownership, route params) as its
  own slice instead of copying it into the settings page.

## 170. Extracting a shared route transaction: keep the harness honest

- Three pages carried the same ~40-line open-chat transaction. Extracting it is only worth it if the
  yaml suite that tests rollback/owner semantics keeps exercising production code: inject the **real**
  module into the page contract (`deps.pushChatScreenRoute = openTransaction.pushChatScreenRoute`)
  instead of a stub, and retarget the rollback mutation to the new owner file.
- A page that imports a new free function from a new module breaks every suite that compiles its
  contract text with a fixed dep list — the same trap as LESSON 164. Always grep the suites that
  `page(...)` the touched page and inject the new names.
- The transaction must compare the current account store **passed by the caller**, not the params'
  own `accountStore` (that comparison is trivially true). Keep the guard explicit in the signature:
  `pushChatScreenRoute(params, navStack, currentStore)`.
- Smoke scripts assert the old inline push text; when a transaction moves, update the grep contracts in
  both smoke variants in the same commit, or the gate fails on a correct refactor.

## 171. A "one dialog" refactor is not finished until the dialog text matches the action

- Multi-delete reused the single-message confirmation unmodified: the flow was correct (one probe, one
  dialog, one deleteMessages) but the title said "Delete message?" for seven messages. Pass the count
  into the confirmation port and keep the single-message string for count 1.
- A localized count string needs the same resource in base/ru/zh, and `.replace('%d', n)` must be applied
  after `localized(...)` — otherwise the placeholder leaks into the dialog.
- Selected-row feedback on iOS is a tint, not just a check mark: a new color needs both
  `base/element/color.json` and `dark/element/color.json`, and the tint must be gated by
  `selectionActive && isSelected()` so normal rows stay transparent.

## 172. The device witness blocker was the account, not the signature

- `hdc list targets` has an emulator, unsigned `entry-default-unsigned.hap` installs with `hdc install -r`,
  and the app starts as a fresh PID — so "signing blocks runtime verification" was the wrong diagnosis
  for this emulator. The real blocker is that the session is unauthenticated (phone-number screen).
- Always separate the three layers when claiming a witness: build/install, process identity
  (PID + STIME vs `date`), and the authenticated UI state. Check the third with a screenshot before
  planning automation; otherwise hours go into coordinates for a login wall.
- Record the exact evidence (target serial, install result, PID/STIME, screenshot dimensions) in
  `STATUS.md` so the next round does not re-derive it.

## 173. Probe-class suites inline their dependencies

- `test-chat-top-bar-presentation.cjs` compiles selected page methods into a `PageProbe` class, not the
  whole module: a module-level helper (`selfUserIdOf`) is a free name there. Inline the expression
  (`state.auth ? state.auth.userId : 0`) or inject it as a binding; do not add helpers to the module.
- When a pure presentation module starts importing a model predicate, add it to the suite's fixed
  binding list (`isSavedMessagesChat`) and treat it as a fixture boundary covered by its own suite.

## 174. AppState is a self-contained model file, and suites that embed it are many

- Adding one import to AppState.ets broke 53 suites at once: each loads the model with its own
  fixed dependency list, so a new external class is a free name in every one of them. Keep model
  classes (ChatFolderInfo, ChatFoldersState) inside AppState.ets; only then does
  createInitialAppState() stay loadable with no deps.
- New normalizer registrations are also a harness boundary: suites that compile EventNormalizer.ets
  pass explicit register*Handlers stubs (and the lifecycle suite builds them from a name list), so
  every new domain needs a stub there — the failure surfaces as a misleading "Failed to load history".
- Object.assign is restricted in ArkTS (arkts-limited-stdlib). Clone state with the project helper
  (cloneStateForChats) instead of copying into a fresh AppState.

## 175. A chat has one position per list, and removals were never handled

- `chat.positions` is a vector with an independent order per list. Parsing only chatListMain/Archive
  silently loses folder membership; parse every chatListFolder position into a map keyed by folder id.
- `updateChatRemovedFromList` had no handler at all before this slice, so a chat that left a list kept
  its membership forever. For folders it must delete the map entry (folderRemoved), not write order 0.
- Selecting folder chats must sort by the folder position, not by chatListMain order: the same chat can
  be pinned in a folder while archived globally.

## 176. The shallow state clone lists fields explicitly

- A new AppState field is invisible to every reducer until shallowCloneAppState copies it: the helper
  builds a fresh AppState and assigns auth/connection/chats/messages/files/accentColors/users/lastEvent/
  version by name. A reducer that reads a new field from a cloned state silently sees the default value.
- The symptom looked like lost counters after the second update (only the first one survived) — a clone
  bug, not a reducer bug. When a field disappears between two actions, read the clone helper first.
- Clone helpers stay cheap: assign the whole sub-state by reference and let the owning reducer replace it.

## 177. buildTdlibRequestJson expands the _*_json params

- A serializer that stores `_chat_list_json` sends a nested object on the wire: assert
  `parsed.chat_list` (the expanded shape), not the raw `_chat_list_json` string — the raw key is
  undefined even though the payload is correct.
- Pagination guards belong to the use case, not the page: one in-flight request per folder plus a
  cooldown after the answer, because TDLib silently returns nothing for an exhausted folder while the
  user keeps scrolling.

## 178. A context menu is a selector plus a dispatch, not a new backend

- Every action a chat-row menu needs already had a use case (toggle unread, move to list, pin,
  mute, delete history). The slice is a pure `selectChatContextMenuEntries(chat, selfUserId)` plus a
  page switch that forwards the action, so the menu never invents its own TDLib path.
- `bindContextMenu(this.builder(item), ResponseType.LongPress)` renders a custom builder on long
  press without owning popup state or an anchor. Keep the existing ListItem tap for opening the chat.
- Saved Messages must return an empty menu: list management for a chat whose peer is the account
  itself (archive/pin/mute/delete) is nonsense and iOS does not offer it.

## 179. Mark-as-unread is a flag, not a counter round-trip

- TDLib keeps `is_marked_as_unread` separate from `unread_count` and reports it through
  `updateChatIsMarkedAsUnread`. A client that only reads `unread_count` looks correct until the user
  marks an empty chat unread: the command succeeds, the update is ignored, and the row never changes.
- The menu condition and the handler must use the same predicate (`unreadCount > 0 || isMarkedAsUnread`),
  otherwise "Mark as read" re-sends markAsUnread and appears to do nothing.
- Any new chat field needs all five seams: DTO parse, model field, update handler, reducer (create +
  both merge paths), and the row VO/diff pair — missing the diff keeps a stale row on screen.

## 180. Menu submenus need data that is true of the current chat

- "Add to folder" must offer only folders the chat is not already in, otherwise the action looks
  available but does nothing. `selectAddToFolderTargets` reads `Chat.folderOrders`, which the folder
  membership slice already maintains from chatListFolder positions.
- TDLib in this checkout has `addChatToList` for folders but no removal call, so "Remove from folder"
  cannot be offered honestly; a missing contract is better than a dead menu row.
- The folder section only renders when there is at least one target; an empty header would be noise.

## 181. JSON round-trips destroy int64 precision, including in "typed" helpers

- A TdObject child rebuilt as `TdObject.fromJSON(JSON.stringify(parsedChild))` no longer holds the
  original lexeme: `9007199254740993` becomes `...992`. The bug is invisible until an id crosses
  2^53, then an identity comparison silently fails.
- `getTopLevelObjectArrayStrict` does exactly that; `getTopLevelRawObjectArrayStrict` slices the raw
  text with a brace/string scanner instead. Prefer raw slices for any array of objects.
- In host tests, never build a fixture with JSON.parse → JSON.stringify either: emit the raw JSON
  text with the id as bare digits.

## 182. Flat lists hide their grouping contract

- A sessions list split into iOS Active/Web sections cannot be a single ForEach: the grouping is a
  pure selector (`splitSessionsByKind`), and the page renders one section builder per group. Keeping
  the split in the selector makes the browser-type table testable without mounting UI.
- Destructive "Terminate all" is only honest when `canTerminateOthers` is true; otherwise the row
  promises an action with no effect.
- Grouping by TDLib `sessionType*` (17 values) must default unknown/app types to Active, never to Web:
  misclassifying an app login as a browser session hides a real security entry.

## 183. TDLib unblocking is a null block list, not a separate method

- `setMessageSenderBlockList(sender_id, block_list)` blocks when block_list is blockListMain and
  unblocks when it is null (td_api.tl:13175). There is no remove/unblock method in this scheme.
- The `_block_list_json` param expands raw, so the serializer writes the literal `null`; quoting it
  would send `"null"` and TDLib would reject the request.
- List payloads carry identifiers only: the blocked-users page resolves names from AppState and
  falls back to a localized label plus the id rather than showing a blank row.

## 184. A "dead control" guard must flip into a wiring guard

- test-dead-controls.cjs asserted `doesNotMatch(/settings_data_storage/)`: a row with no destination
  must stay out. Once the destination exists, the same guard fails the suite — which is correct, but
  the test must be rewritten to assert presence AND wiring AND a registered route, not deleted.
- Keep the guard’s intent: a settings row is only allowed when opening it leads somewhere real. The
  new assertion checks the route map, so a future revert of the page fails the guard again.
- `optimizeStorage` with size/ttl/count zero is the TDLib way to clear every droppable cache file;
  the database and logs stay, so the screen must show them separately instead of promising zero.

## 185. Offset paging needs a merge, not an assignment

- TDLib returns total_count with every page; "show more" must compare loaded versus total, because a
  short page does not prove the end (the block list can change between requests).
- Appending must dedupe by the sender key: a sender blocked twice or a shifting list can repeat an
  entry, and ForEach keys must stay unique or the list throws.
- A shrinking total (unblocks elsewhere) must yield hasMore=false even when loaded < previous total.

## 186. Inserting before `export function X` steals the export keyword

- A script that matches the bare substring `function extractFolderPosition` and prepends a new
  function leaves `export ` dangling at the end of the previous line: `export // comment` then the
  new function. ArkTS compiles it (the export binds to the next declaration), so the build stays
  green while the helper silently stops being exported and a host test fails on `is not a function`.
- When inserting next to a function, match the full `export function name(` (or the whole signature
  line) and assert the export stays where it was.
- The `test-chat-folders.cjs` failure, not hvigor, caught it: keep module-surface tests for helpers
  other suites import.
- Also: `chat.block_list` (BlockList object) is the authoritative blocked flag; a stories-only block
  must not read as a message block.

## 187. A settings screen without a getter must say so

- This TDLib version exposes auto-download presets and an apply call but no getter for the settings in
  effect. Showing a selected preset as if it were the server truth would be a lie, and persisting the
  choice locally could silently diverge from the account.
- The honest shape: apply the preset, mark it "Applied" for the session, and put a visible note plus a
  debt entry explaining why the active state is unknown.
- Host-test loaders that also capture `export type` names try to return erased bindings; match only
  value exports (`class|function|enum|const`) and let `stripTypeScriptTypes` erase the rest.

## 188. One block_list field means the unblock action is shared

- TDLib keeps a single `block_list` per sender (main or stories), so the stories tab cannot have its
  own "remove from stories only" action: unblocking always clears the list. Presenting two tabs must
  not imply two independent blocks.
- Switching a paging tab must reset offset and total before reloading; otherwise "Show More" appends
  the next page of the previous list.

## 189. Builder annotations and menu APIs have hard shapes

- Inserting a `@Builder` method right before another method's body leaves the original annotation
  attached to the new method: two `@Builder` in a row, and the original loses its annotation →
  "does not meet UI component syntax". Match the whole `@Builder\n  private name(` block when inserting.
- `PromptAction` exposes `showActionMenu` (tuple of 1–6 `{ text, color }` buttons), not
  `showActionSheet`; the tuple type rejects a mapped `Button[]`, so build the literal inline.
- A `@Builder` call cannot be chained with `.margin()`; put layout modifiers on the rows inside the
  builder.
- Tightening `DeleteChatHistoryUseCase` validation (positive int53, not just non-zero) exposed that the
  old check let negative and fractional ids through to the gateway.

## 190. A settings editor must not silently reset state it cannot read

- ChatFolderInfo carries only name/icon/color, not the exclude/include flags. An editor that always
  sends false for them rewrites the folder whenever the user renames it. The honest options are to
  read state back (getChatFolder/full DTO) or to keep the flags out of the rename path; sending false
  silently is the worst of the three.
- The current slice sends the flags the user set in the form and records the limitation as debt; the
  editor starts from false only because TDLib does not expose the current values in this version.
- Raw JSON fields (`_folder_json`) need the same escaping as normal strings: use the existing
  escapeForJson helper and test quotes/backslashes explicitly.

## 191. Read-back closes the "editor resets state" class of bug

- The folder list carries only a summary (chatFolderInfo); the editor must call getChatFolder to get
  the flags it is about to send back. Saving a form whose initial values are guessed silently rewrites
  server state — read back first, then enable Save.
- int53 vectors in responses are best read with a raw item scanner: JSON.parse turns 9007199254740001
  into a rounded double, and a chat id is an identity, not a measurement.

## 192. A flag read from the server must also be written back

- The folder DTO already parsed the five include flags, but the editor neither showed them nor sent
  them, so every save silently reset them to false — the same class of bug as R191, one layer up:
  reading is only half the contract when the same object is rewritten on save.
- When a payload has N flags, make the editor own all N or explicitly mark the rest as untouched;
  partial editors on full-replacement payloads are data loss.

## 193. Page results need a typed pop contract, and Sets need replacement

- `pageStack.pushPathByName(name, params, onPop)` delivers results through `popInfo.result`; define
  route params/result classes in one file so both pages share the type instead of casting ad hoc.
- `pageStack.getParamByName` is typed as `Object[]`; `unknown[]` inference trips arkts-no-any-unknown,
  so cast the call, not the variable.
- A `Set` mutation is not observable: replace it (`this.selected = new Set(this.selected)`) or the
  checkbox rows never re-render.

## 194. Fixtures shared by two blocks must live at module scope

- A JSON fixture declared inside a `{}` block is invisible to the async use-case section further
  down the file; the failure surfaces as "X is not defined" wrapped in the use case's AppError, which
  reads like a production failure. Hoist shared fixtures next to the other module-level constants.
- Invite-link creation with `chat_ids: []` means "all folder chats"; the empty array is the TDLib
  contract, not an omission.

## 195. A silent string-anchor miss hides contract gaps

- The rename feature passed its test on the first run even though the "labels exist in three locales"
  assertion had not been added: the script that adds assertions threw on an anchor, and the already
  written parts of the test still passed. Run the doc/test patch script, read its stderr, and only
  then trust the suite result.
- Invite links keep `chat_ids: []` on create/edit from this UI, which TDLib reads as "all folder
  chats"; a restricted link needs explicit ids, so the UI must not pretend to offer the restriction.

## 196. Smoke pins are contracts — update them with the change, not around it

- `smoke-ui-phase0` counted exactly three theme-foreground tints in TgChatTopBar; a fourth legitimate
  action turned that into a failure. The right move is to bump the pinned count and the message to
  name the new action, in both the .sh and .ps1 variants — not to use a different token to dodge the
  check.
- Adding a second capsule next to the trailing one is a param (`showMoreAction`), not a new enum case:
  replacing `Search` with `More` would have removed search from the header.

## 197. showActionMenu tops out at six buttons — plan the menu as a whole

- The chat actions menu already had four entries; Leave/Share makes five. A sixth entry would still
  fit, but the iOS menu is longer, so further items need submenus or separate sheets rather than
  appending forever.
- Putting a context-dependent item in a fixed index is fine only when the guard and the action are
  read from the same chat snapshot (`canLeaveChat(chat)` used for both label and dispatch).
- `inputMessageContact` needs the full `contact` object including `vcard` and `user_id`; sending a
  phone-only payload makes TDLib reject the message.

## 198. Move growing page logic out before the decomposition test notices

- The bounded-owner test caps `TgChatScreenPage.ets` at 500 lines; the report flow pushed it to 568 and
  the failure appeared only in the host suite, not in hvigor. Watch the limit while adding, or extract
  first (ChatActionsCoordinator) and let the page delegate.
- When removing a page region by slicing from marker A to `build()`, lifecycle hooks and @Monitor
  methods that sit in that region are deleted silently — the build still compiles and only the
  decomposition test catches `this.session.aboutToAppear()` missing. Re-read the file after slicing.
- ArkTS rejects object literals for host interfaces; pass dependencies through a small class with a
  constructor instead of an interface literal.

## 199. A failed patch script leaves the suite green and the claims false

- Two rounds claimed contract coverage for invite-link rename; the patch scripts died on an anchor
  before writing, and no test failed, so the gap stayed invisible until the next slice touched the
  same file. After any scripted test edit, grep the new assertion text; never trust only the suite
  result.
- Validation placed inside the TDLib try block is re-wrapped as "Failed to …", which hides the real
  validation error from callers and tests. Validate before the try, then send.
- Renaming must resend the existing chat_ids: an empty array would widen a restricted invite link to
  every folder chat.

## 200. A serializer that ignores its command silently reuses the wrong request

- `serializeOptimizeStorage` took `_command` and always sent size/ttl/count = 0, so any limit request
  would have cleared the whole cache instead of trimming it. When a serializer ignores its command
  argument, adding the payload belongs to the same slice.
- Honest limit semantics: `optimizeStorage` has no persistent setting, so the UI says the limit is
  applied now and keeps the choice locally instead of pretending the cache stays bounded forever.
- Matrix rows use Russian titles; doc patch scripts must anchor on the row prefix (`| H4 | Данные и`),
  not an English guess, or the docs update is skipped after the code commit is already made.

## 201. The JSON bridge always adds @type — empty requests are not `{}` in tests

- A command with no arguments still serializes `{"@type":"method"}`, so asserting deepEqual to `{}`
  fails. Assert the key set (`['@type']`) instead.
- `TdObjectType` accessors are typed: `getTopLevelObjectStrict` already returns a parsed object, so
  feeding it to `TdObjectType.fromJSON` is a type error and passing it to the DTO factory directly is
  the intended path.
- Page anchors differ from screen to screen (folder page renders Rows inside a Column, not List and
  ListItem); re-read the region before scripting an insert, and split test/doc patches so one missed
  anchor does not discard the successful parts.

## 202. Link-preview slices need their own entry point when there is no URL router

- The app has no app-link/URL router, so a `t.me/addlist/...` tapped in a message cannot open a
  preview. Shipping the preview behind a manual "Open Folder Link" row is honest and useful, but the
  missing router must stay recorded as debt instead of being implied by the feature name.
- `isFolderInviteLink` must strip the scheme before matching; without it a pasted `t.me/addlist/x`
  and the `https://` form would need separate branches.
- Link validation errors must be raised before the TDLib try block, otherwise the callers see the
  generic transport message (same rule as the invite-link slice).

## 203. Changing an ability signature touches the stabilization harness

- `onCreate(want, launchParam)` broke two stabilization suites: the harness builds EntryAbility from a
  fixed method list with hand-made deps, so a new method (`captureExternalLink`) and the
  `externalLinkIntake` dep must be added there, and its calls must pass a `want`. The failure surfaced
  as "captureExternalLink is not a function" and as a negative-control crash, not as a compile error.
- Case-insensitive URL matching must not lowercase the slug: match on a lower-cased copy, slice the
  original text. Reserved paths (`addlist`, `joinchat`) must be excluded from username detection.
- Scripted file rewrites can duplicate a block when an anchor search ends in the wrong scope; when a
  patch corrupts a file, rewrite the whole file from a clean template instead of patching the damage.

## 204. Suites with different loaders need the real transitive deps

- The external-link suite loads ETS with a loader that collects exported names automatically and takes
  only a deps object. Passing a names array as the second argument produced
  `new Function(0,1,2,...)` and a confusing `Unexpected number`.
- ChatDto is not standalone: it needs `tdAccessors`, `GroupAccessDto` and `AppCommand`; a test that
  resolves a chat must pass them, and `TdObject` must be initialised before the modules that capture it.
- Top-level `await` is invalid in a `.cjs` suite; wrap async checks in a function and run it once.

## 205. App Linking pathStartWith cannot express t.me/+hash

- The browsable skill matches path prefixes, so `addlist` and `joinchat` are declarable but the short
  invite form `t.me/+hash` is not; declaring it as a prefix would swallow unrelated paths. Keep the
  class/route/UI ready and record the manifest limitation instead of claiming full App Linking.
- Prefix checks must test the remaining length (`t.me/+` alone is not a valid invite), otherwise the
  empty-slug case reaches the gateway and the error reads like a TDLib failure.
- A page that pops a class instance back to the caller gives MainTabsPage the full ChatDto, which is
  what `createNewChatEvent` needs; popping only id/title would force a second TDLib call.

## 206. ChatPanelsState is pinned by the decomposition contract

- Adding five @Trace fields to `ChatPanelsState` broke `test-chat-screen-decomposition.cjs`: the suite
  asserts an exact 118 reactive fields, each with a bidirectional `ChatScreenContext` alias. Page-local
  presentation state must either live in the page (`@Local`) or ship with its Context accessors and
  updated counts in the same slice.
- A scripted patch that replaces a shared @Trace line can silently drop it (emojiSearchLoading); the
  compiler caught it, but the field count is the thing to re-check after such edits.
- Report steps are typed results: route them to page-owned UI through a host callback instead of
  toasting, otherwise the flow dead-ends with a message the user cannot act on.

## 207. Matrix rows are long prose; a replace on a guessed fragment silently no-ops

- The C10 update targeted a substring that did not exist, so the docs commit shipped unchanged while
  the code commit already described the new step. Anchor on the row prefix and rewrite the whole row,
  then assert the written file contains the new marker (as the script did — but the log said false and
  the commit still went out; treat a false marker as a failed gate).

## 208. Selection-mode features must share the existing selection owner

- Report-by-messages reuses `view.timeline.selectionActive` / `selectedMessageIds` instead of a second
  selection model, and the panel gained one optional action instead of a new bar. Any second owner
  would desync the counter, copy/forward/delete and the report intent.
- `selectedMessageIds` is `string[]` while `reportChat` needs numbers: convert and filter safe
  integers at the boundary, never send the raw strings.
- Clear the report intent whenever selection closes, otherwise the next selection session silently
  offers Report for a stale chat.

## 209. Role lookups must never block the menu, and menu slots are literal

- `getChatMember` failing (offline, private chat, old account) must fall back to the plain member set
  instead of leaving the user with no menu; the use case returns `unknown` and logs a warning.
- `showActionMenu` takes a fixed six-slot tuple of `promptAction.Button` whose `color` is
  `string | Resource`: collect labels/colors into arrays, then build `b0..b5` explicitly — pushing
  into a `Button[]` and passing it does not type-check.
- Replacing an index-based menu switch with typed actions keeps the report/leave/share mapping
  readable and makes the admin variant a one-line insertion; update the contract test in the same
  slice instead of keeping both mappings alive.

## 210. This TDLib revision has no exportChatInviteLink; test loaders need an export list

- The primary invite link is not exported by a call: `getChatInviteLinks` returns it with
  `is_primary = true`, so the screen must not offer revoke for that row and must not invent an
  export command.
- The ad-hoc `load()` used by a new suite returned nothing because it only executed the module body.
  The suite loader must append `return {exports}` like the other suites, and every dependency module
  needs its own explicit name list; a missing name surfaces as `Cannot destructure ... of undefined`.
- Six-button action menus cannot absorb every admin entry: add a Manage submenu instead of dropping
  an existing entry, and update the header contract when the top-level item changes.

## 211. Administrator entries carry ids only; profile navigation is page-private

- `chatAdministrator` has user_id, custom_title and is_owner; names must come from the users store
  with a neutral placeholder for unknown ids, otherwise the list renders empty titles.
- `DirectUserProfileRouteParams` and `captureProfileLoadContext` live as file-private helpers in the
  members page, so a new screen cannot open a profile by importing them; either export the helper or
  omit the tap and record the debt (done here).
- Adding a third entry to the Manage submenu required updating two suites that pinned the exact
  action array; grep for the array literal after any submenu change instead of only the new suite.

## 212. @Builder with parameters and reserved member names in V2 components

- A `@Builder` method with parameters called fourteen times inside `ListItem()` produced
  "Argument of type 'X' is not assignable to parameter of type 'Object'". A small
  `@ComponentV2` row struct with `@Param`/`@Event` is the reliable shape for repeated rows.
- Naming a method `valueOf` overrides Object.prototype.valueOf and breaks call resolution; rename it
  (`permissionValue`). A `@Param enabled` also collides with the CustomComponent base member — use
  `isEnabled`.
- The bounded-owner check is exact: the chat page crossed 500 lines after four navigation helpers, so
  move navigation into a helper module and update every suite that pinned the old wiring in the same
  commit, otherwise four suites fail on stale anchors.
- A native-bridge compile failure under the parallel host runner can be transient: standalone run was
  green and the next full run passed; re-run before treating it as a regression.

## 213. A leading "+" is a safe App Linking prefix, and exports beat private helpers

- `pathStartWith: "+"` cannot collide with usernames (they start with a letter) or reserved paths
  (`addlist`, `joinchat`), so the short invite form is declarable after all; the earlier claim that it
  was inexpressible was wrong and is corrected by a manifest entry plus a contract assertion.
- Exporting `DirectUserProfileRouteParams` from the members page was enough to open a profile from the
  administrators screen; the profile context helper already existed in `domain/usecases/loadProfileInfo`,
  so check domain helpers before duplicating context capture.
- After closing a debt bullet, delete the TODO line instead of leaving it "closed" in prose; a stale
  open checkbox reads as pending work in the next round.

## 214. Automatic enforcement needs a one-shot guard and honest TDLib defaults

- Enforcing a cache limit right after a statistics load can loop when TDLib keeps bytes it cannot
  free; guard it with one attempt per load (reset on an explicit reload) and surface a toast only when
  a request actually ran.
- `optimizeStorage` leaves `ttl` and `count` at -1 by default, meaning "no bound"; asserting 0 in the
  contract was wrong. Assert the real defaults so the wire stays honest about which bound applies.
- Test helpers differ per suite: the cache-limit suite auto-collects exports (`storage.X`), so reusing
  an ad-hoc name (`loadMod`) fails with a ReferenceError that reads like a module bug.

## 215. Percentage bars need px-agnostic widths and a clamped scale

- ArkUI accepts a percentage width string for a `Row`, so a stacked bar can stay layout-driven
  (`percent.toString() + "%"`) instead of measuring pixels; clamping each segment at 100 keeps the bar
  honest when a category alone exceeds the limit.
- Scale selection belongs in a pure function (`storageChartScale`): a limit wins over the total, and a
  zero total must not divide by zero. That made the chart testable without mounting ArkUI.
- Keep chart colors in tokens (`STORAGE_CHART_*`) built from existing palette resources; do not inline
  color values in a molecule.

## 216. Mutable per-chat sets break old constructors; normalize at the boundary

- Adding `senders: ChatActivitySender[]` to `ChatTypingInfo` broke a suite that constructs the class
  with only the scalar fields (`typingInfo.senders is not iterable`). A normalization helper
  (`activeSenders`) that falls back to the scalars keeps old call sites and fixtures working.
- Presentation helpers loaded through an ad-hoc `new Function(...bindings)` harness need every new
  import injected explicitly; otherwise the suite fails with `X is not defined` at module-eval time.
- Keep the sender set and the legacy scalar fields in sync in one pure helper instead of duplicating
  the rules in the reducer and the header formatter.

## 217. New media assets go in base/media as SVG and reach the panel through a token

- HarmonyOS renders `Image($r('app.media.x'))` with `fillColor`, so a monochrome SVG mirroring an SF
  Symbol is enough for icon parity; no raster export step is needed.
- Do not delete the old text-glyph token when a demo still uses it; add the icon token beside it and let
  the contract assert that the production panel no longer calls the glyph builder.
- Regex replacements are safer than literal anchors for indented multi-line calls; a wrong leading-space
  count silently fails the anchor even when the text looks identical.

## 218. A new chat field needs the DTO, the reducer mapping and a tolerant anchor

- Adding `messageAutoDeleteTime` to `Chat` was not enough: `ChatDto` has its own class and the reducer
  maps DTO fields into `Chat` explicitly, so all three places must be updated together or the build
  fails with "does not exist on type ChatDto" / an empty value at runtime.
- Navigation for admin screens lives in `chatAdminNavigation.ets`, not in the page; follow that pattern
  instead of adding route imports to the page, and remember the host constructor gains an argument.
- Regex anchors with `^\s*` survive indentation drift; literal anchors in multi-line edits silently
  fail and leave a half-applied patch (missing comma) that only the build catches.

## 219. JSON.parse rounds int64 in tests; assert on the raw wire text

- A fixture with a bare int64 `id` was silently rounded by `JSON.parse` before it even reached
  `TdObject`; int64 fixtures must be quoted strings, matching TDLib JSON.
- Vector<int53> arguments are emitted as raw digits, so parsing the request back to JSON rounds them
  again; assert `raw.includes(<exact digits>)` instead of comparing a parsed number.
- A newline between a call and its `as TdObject` cast is rejected by ArkTS ("arkts-no-structural-typing");
  keep the cast on one line or extract the command into a local first.
- The six-slot `showActionMenu` cap is now exactly saturated; adding another admin entry requires
  restructuring the menu rather than appending, and every suite that pins the action array must change
  in the same commit.

## 220. Type aliases disappear in the host loader; only load runtime values

- `stripTypeScriptTypes` removes `export type X = ...`, so asking the loader for it throws
  `ReferenceError: X is not defined` even though the source declares it. Load only functions/classes.
- The member list initialises its use case from the route-context owner (`owner.gateway`), not from a
  global adapter; new use cases must follow that pattern or they will not see the account switch.
- A long-press on a row needs its own `@Event` plus `LongPressGesture`; `.onClick` alone silently drops
  the gesture on ArkUI rows.

## 221. A default parameter is a runtime dependency for the host loader

- Adding `rights: ChatAdminRightsPayload = new ChatAdminRightsPayload()` made the default expression a
  runtime reference; the CJS suite then failed with `ReferenceError: ChatAdminRightsPayload is not
  defined` even though the payload was only a type in the serializer. Load the class in the suite deps.
- `chatAdministratorRights` has 16 flags in this TDLib revision (including `is_anonymous`); mirror all of
  them explicitly instead of emitting a partial object, otherwise TDLib rejects the status JSON.
- `showActionMenu` still has room at five buttons, so administrator and moderation actions can share one
  member menu; the six-slot cap now leaves no space for a sixth entry.

## 222. ArkTS class field initialisers run before @Local defaults settle

- Building `ADMIN_RIGHT_ROWS` at module scope with `$r(...)` keeps the row table immutable and lets the
  page mirror it into a `boolean[]`; a plain `string[]` of labels plus a switch in `buildRights()` avoids
  indexed property assignment, which ArkTS forbids on class instances.
- A new page must register in `route_map.json` before the first build, otherwise the Navigation build
  fails at the push site, not in the page itself.
- Token names drift: `COMPOSER_SEND_BUTTON_SIZE` does not exist, the real token is `COMPOSER_BUTTON_SIZE`;
  grep `TgUiTokens.` before inventing a size.

## 223. showActionMenu needs a literal tuple, never a mapped Button[]

- Building `promptAction.Button[]` in a loop and passing it fails type-checking with
  "Type Button[] is not assignable to type [Button, Button?, ...]"; declare `d0..d3` and pass the literal.
- Keep the preset values in a pure array (`MODERATION_DURATION_SECONDS`) and map the index into the
  literal tuple, so tests can assert the ordering without duplicating labels.
- Time arithmetic belongs in a pure helper (`moderationUntilDate`) because `Date.now()` inside a page
  makes the wire contract untestable: 0 duration is "forever", invalid input collapses to 0.

## 224. Guard patches by class span, not by field name

- `if (!t.includes("permissionsJson: string = '';"))` matched the unrelated `SetChatPermissionsPayload`
  and reported "already patched", so the member-status payload silently kept the old shape and the build
  failed twice. Locate `export class <Name> {` and splice inside its span instead.
- The same applies to factories: find the function start, then its closing brace, and edit that slice.
- When a payload grows an optional JSON override, keep the previous hardcoded default as the fallback in
  the serializer so existing callers keep their behaviour, and assert both paths in the suite.

## 225. Every imported factory is a loader dependency

- The use case gained `createGetChatMemberCommand`; the CJS loader strips imports, so the symbol was
  undefined at runtime and the failure surfaced as a caught "Failed to load the member state" AppError,
  not as a ReferenceError. Add each new factory to the suite deps as soon as the module uses it.
- A string replace that inserts a dependency object can leave the old `{ ...C, ...errors, hilog }` line
  behind; the resulting `SyntaxError: Rest parameter must be last formal parameter` points at the
  `new Function(...names)` call, not at the duplicated line.
- Pre-filling a screen from TDLib must tolerate a different status than expected: `loadState` returns
  every status and each page only applies the branch it owns.

## 226. Reuse the existing viewer instead of adding a new event chain

- A sticker preview needed no new page, route or binding port: the media gallery already renders any
  `MediaGalleryItem`, so adding a `sticker` item type plus a tap handler reused the whole open/close and
  index machinery. Check the data-shape first, not the screen name.
- `TgMessageRouter.ets` lives in `ui/tg_ui/molecules/`, not `ui/components/`; a hardcoded path in a patch
  script silently targets nothing, so resolve files with a recursive search.
- Multi-replacement scripts must write only after all anchors matched; otherwise a missing third anchor
  discards the first two edits and the failure looks like "the collector was never patched".

## 227. A blanket "insert after stickerEmoji" patch hits every mapping site

- One `includes("stickerEmoji")` loop inserted a clone-shaped line into the DTO→content mapping and a
  mapping-shaped line into the clone function, because both functions copy the same fields. Iterate the
  two functions separately, or patch by exact neighbouring lines.
- `MessageDto` has its own `MessageContentDto` class plus the accessor-based mapping; the field must be
  declared in that class or the mapping line fails to compile even though `AppState.MessageContent` has it.
- `getStickerSet` serialises the id as a raw int64 literal, so a round-trip through `JSON.parse` in a test
  rounds the value; assert on the raw request text as with `deleteMessages` ids.

## 228. Page contract source is the transitive graph, so lifecycle methods multiply

- `readChatSource` for the page returns `contractSource(graph)`: every imported coordinator is inlined, so an
  `aboutToAppear` added to `TgChatMediaOverlay` made the page contract contain two and six ownership suites
  failed with "exactly one actual full page method". Trigger initial work from an existing page/session entry
  point (gallery open) instead of adding a lifecycle hook to a nested component.
- The same graph pins exact budgets: `graph.delegates.size`, owner line counts (<= 500) and aggregated `@Trace`
  field counts. Every new delegate/field must be accounted for in `test-chat-screen-decomposition.cjs` in the
  same commit, otherwise the suite fails with a numeric mismatch far from the change.
- `ChatScreenSession` sits exactly at the 500-line ceiling; compacting a multi-line import to one line and
  dropping a stale comment keeps it there. Prefer that over raising the ceiling.
- Fixture harnesses keep an explicit factory table (`factoryGatewayIndex`); a new `create*UseCase` in the
  activation path must be registered there or the fixture hides a ReferenceError behind its best-effort catch.

## 229. Delegates must land where the guard proves they do

- `includes("host.chatBottomBarDeleteAndExit) {")` matched the branch already added to a different
  function, so the label patch reported success and inserted nothing. Anchor insertions on the enclosing
  function span (`indexOf("export function X")`), not on a generic guard string.
- ArkTS forbids passing an interface-typed host to another interface type ("structural typing is not
  supported"); pass primitives plus a callback instead of a second host contract.
- The page contract requires every render callback to resolve to a Session delegate whose name equals the
  binding method. Before adding a binding method, check whether an existing session delegate can carry the
  action; reusing `handleChatBottomBarAction` avoided both a new delegate and the 500-line ceiling.

## 230. A panel kind has several union copies to keep in sync

- Adding `unblock` to the input panel required the same literal in `ChatChromeState`, the coordinator port,
  the context getter/setter and the top-bar port; missing one produced a type error only at the far end
  ("not assignable") because interfaces extending both ports must agree on the field type.
- A private chat is chosen by `type === private || type === secret`; the old branch also matched
  `peerUserId > 0`, which would have turned channel-with-peer rows into unblock panels. Split the branch
  before adding blocked state.
- Type aliases exported next to a pure module cannot be requested from the CJS loader; load only values.

## 231. Read the exact field owner before parsing a counter

- `messageThreadInfo` carries `unread_message_count` at the top level; `reply_info` only has
  `reply_count`. Parsing both from `reply_info` silently returned 0 and the suite caught it only because
  the fixture used the real schema. Dump the td_api.tl line for the object before writing a parser.
- Added trailing-newline and count assertions early in a new suite pay for themselves: two schema slips were
  found before the suite ever reached the wire assertions.

## 232. New page: copy the token names from the token file, not from memory

- `COLOR_TEXT_PRIMARY`, `CHAT_ROW_TIME_FONT_SIZE`, `COLOR_ACCENT`, `SPACE_32` do not exist; the live names
  are `COLOR_TEXT_TITLE`, `COLOR_TEXT_PREVIEW`, `CHAT_ROW_PREVIEW_FONT_SIZE`, `LINK_PREVIEW_ACCENT_INCOMING`,
  `COLOR_BG_PRIMARY`. Grep `TgUiTokens.ets` before writing a new page.
- `TgChatTopBar` exposes `@Event onBackPress`, not `onBack`, and `TdObject` has no `getTopLevelBool` — read
  booleans with `tdGetNumber` and compare to 1.
- Store singletons are reached through `getAppCoreRuntime().getStore()`; there is no module-level `getStore`.

## 233. Comments availability comes from interaction_info, not is_channel_post alone

- A channel post has `is_channel_post: true` even without a discussion; comments exist only when
  `interaction_info.reply_info.reply_count > 0`. Gate the menu item on both or every post grows a dead entry.
- The row fields live on the timeline row (`entry.message`), not on `ChatTimelineEntryVO`; patching
  `entry.isChannelPost` compiles nowhere. Follow the existing `entry.message.*` access style.
- Loading the full `MessageDto` parser in a CJS suite drags its content-parser dependency graph; assert the
  wire-level parse lines in source and keep runtime tests on the narrow parser under test.

## 234. `_*_json` params are rewritten, assert the emitted field

- `buildTdlibRequestJson` turns `_topic_id_json` into `"topic_id":<json>`; a suite asserting the underscore
  key never matches the wire. Assert the real field name.
- Sending into a thread needs `topic_id` on every send, so the helper writes explicit `null` for normal
  messages instead of omitting the key; keep that in mind when adding per-message fields.
- A guard like `includes("_topic_id_json")` matched an unrelated serializer, so the send path stayed
  unwired while the patch reported success. Edit inside the function span, not by global token search.
- Serializer helper types are `TdObject`, not a named params class.

## 235. Page-layer actions can own their use case when no session slot exists

- The chat session sits at the 500-line owner ceiling, so adding a host getter for translation would have
  required trimming unrelated lines. `ChatMessageActionsController` already lives in the page layer: it can
  create the use case from `getTdGatewayAdapter()` and read the locale from `i18n.System` without touching
  the session, bindings or ports.
- `promptAction.showToast` returns void in this SDK, so chaining `.catch` on it does not compile.
- The app has no settings.language field; the system language is the available target-language source.

## 236. Quantize widget animation into a pure step model

- A looping 0.7s pulse inside a `@ComponentV2` atom is hard to test and easy to leave running. Quantizing it
  (10 steps of 70ms) into `TgTypingPulse` gives exact assertions for bounds, peak, staggering and wrap while
  the widget only applies scale/opacity.
- Start the interval only when the typing subtitle is actually visible; reset the phase when stopping so a
  later appearance starts clean, and clear it in `aboutToDisappear`.
- Phase arithmetic: dot i at step s equals dot 0 at step s + i*3 modulo 10; write assertions from that
  identity rather than from hand-computed decimals.

## 237. Keep menu construction free of heavy module references

- Building menu labels called `targetLanguageCode`, which referenced the translation use-case module; the
  fixture suites that load the actions controller then failed with `isValidLanguageCode is not defined`.
  Move a small validator into the controller and keep use-case references inside the action handler.
- A bounded `Map` with oldest-key eviction is enough for the translation cache; the map must be keyed by
  chat because message ids are only unique per chat.
- Docs write scripts must avoid quoting tricks that break the JS string (the previous round shipped code
  without docs); write the docs in a separate commit when the code commit is already green.

## 238. A new AppEvent needs three registrations, not one

- Adding the event class and a reducer case is not enough: `core/reducers/index.ets` routes by explicit type
  list, and `test-unread-count-routing.cjs` pins the full type→reducer table independently. Both must be
  updated or the routing suite fails with a deep-equal mismatch.
- Rows are plain VOs; the inline translation only repaints because it lives in the message store. A
  page-layer flag would have needed a dataSource call the 500-line session cannot host.
- The row VO has no `chatId`; the active chat id comes from `chrome.activeChatId` inside the timeline row.
- Bubble/router files omit trailing semicolons on imports — anchor patches accordingly.

## 239. Test harnesses that copy methods do not run field initializers

- Adding `private bridge = new Bridge()` to EntryAbility broke three stabilization fixtures: the harness
  copies methods onto an object without running class field initializers, so `this.bridge` was undefined.
  A module-level lazy singleton (`getMessageNotificationBridge()`) survives that harness and keeps the
  ability stateless.
- Keeping NotificationKit out of AppCoreRuntime avoids eleven suite failures; inject a sink interface from
  the ability instead, and keep the runtime testable with a plain object.
- Chat ids are negative for groups and channels: `<= 0` guards silently drop every group. Compare to `=== 0`.

## 240. A notification wantAgent needs the ability identity captured at start

- `wantAgent.getWantAgent` needs `bundleName`+`abilityName`; the bridge takes both from the UIAbilityContext
  in `start()`, so publish stays a plain call later.
- Tapping routes through an intake store (validated chat id, take-once) rather than the ability pushing a
  route: navigation does not exist at `onNewWant` time, and an unauthorized session must keep the request.
- Harnesses that copy a fixed method list need the new `captureChatOpen` listed, and a stubbed intake module,
  or onCreate fails with a missing method.

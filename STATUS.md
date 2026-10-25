# STATUS — Telegram-HarmonyOS

Current state only. Every superseded dated snapshot, and the pre-compaction version of this file,
lives in `TASKS/ARCHIVE/STATUS-history-2026-10-18.md`. Reports referenced here are immutable
checkpoints — see `docs/reviews/INDEX.md` for all 81 of them.

## Where it stands — 2026-10-23

| Area | State |
|---|---|
| Receive scheduling (drain) | **Accepted.** Bounded correction, 15/15 regressions, independent Astra review. |
| Receive-drain topology / slice budget | **Closed — no change.** Null result on threads; shipped pacing measured 2026-10-23 (~2.8–3.1× slower than the zero-delay model, −18 % from 8→64 ms, frame ordering non-monotone); `DRAIN_BUDGET_MS` stays 8. |
| Main reliability (request timeouts) | **PARTIAL.** 2/4 observed timeouts on the exact official package; root cause not established. |
| Source publication | `dev` pushed to `origin/dev`, CI green on `d706143`; six probe/docs commits since, not yet pushed. |
| Install over authenticated main | **Not done** for the correction. Not released, not signed. |
| Notifications / push | **Absent.** No `notificationManager` / `wantAgent` / push code in `entry/`. |
| Authenticated delivery / providers / shipped-iOS / signing | **Open** since 2026-09-27. |

## Latest checkpoint — 2026-10-21…23

**Receive-drain investigation closed, and its own measurement corrected.** Three days of synthetic
work asked whether the drain should move off the main thread and whether its slice budget should
change. A Worker arm and a main arm were indistinguishable once arrival timing was fixed; a budget
sweep then reported that 8 ms was the worst setting. On 2026-10-23 that sweep was corrected: it
yielded with a zero delay while the shipped drain schedules its next slice at
`max(2, min(250, elapsed × 2))`, so its time column belongs to a model the app does not implement. The
"measured hop counts" were arithmetic (no counter existed), and the "8 ms consumer work" quantum was an
injected artificial delay, not an observation. **Recommendation withdrawn; `DRAIN_BUDGET_MS` stays 8;
no receive-drain work is open.** [Topology](docs/reviews/2026-10-20-drain-topology-spike.md) ·
[sweep](docs/reviews/2026-10-21-drain-budget-sweep.md)

**The shipped pacing was then measured, not just predicted.** An isolated bundle ran both yield models
back-to-back on the emulator, n = 3 per budget: the shipped drain costs ~2.8–3.1× the zero-delay model
(5461 vs 1950 ms at 8 ms on the same 1288 ms of work), its budget curve is −18 % from 8 → 64 ms
instead of −27 %, and its frame gaps are non-monotone (207 / 285 / 216 / 130 ms). The 2026-10-21
headline "8 ms is worst on both axes" is therefore not reproduced; the constant still does not move,
because the gain is half the claimed one and the host is an emulator. The host itself is a 2014 Xeon
with a 97 %-full disk, so every absolute millisecond in that run is an upper bound.
[Re-run](docs/reviews/2026-10-23-drain-yield-model-rerun.md)

**Worker NAPI door opened, then not needed.** The native TDLib module loads and answers inside an
ArkTS Worker on the emulator, and the running process reports TDLib 1.8.61 — which closed the
"is the shipped binary 1.8.60?" half of the provenance question.
[Report](docs/reviews/2026-10-20-worker-napi-probe.md)

**TDLib pin aligned, provenance still open.** The submodule is pinned at `11e254af6`, whose
`CMakeLists.txt` declares 1.8.61; the exact upstream revision that built the shipped `.so` remains
unrecorded. [Report](docs/reviews/2026-10-19-tdlib-version-provenance.md)

**Competitor artifact re-checked.** The ArkGram note was corrected on 2026-10-23: the analysed package
is 1.0.1 (not 3.2), `compileSdk 26.0.0.23 / Beta1`, several previously listed platform APIs are absent
from every retained artifact, and the concurrency result — no ArkTS worker/taskpool usage — is the part
that stands. [Report](docs/reviews/2026-10-21-arkgram-analysis.md)

## Repository tidy-up — 2026-10-24

Documentation and repository structure were reconciled; no product code changed.

- **Roadmap rewritten.** `TASKS/AGENT_EXECUTION_PLAN.md` now states the current route only. Release
  Track v2 (R0→R3+, `v0.1.0` as the goal, "pixel fidelity is not a goal") moved to
  `TASKS/ARCHIVE/AGENT_EXECUTION_PLAN_release-track-v2_2026-07-02.md` and is not to be executed.
  `DECISIONS.md` D24 records the mandate change, D25 records which documents are authoritative.
- **Authority resolved.** `docs/ai/*` is an archive (`docs/ai/README.md`); the `tg_ui` master plan keeps
  only its visual-contract role. The open "canon winner" question in `TASKS/TODO.md` is closed.
- **`TASKS/` decluttered.** 10 historical slice plans moved to `TASKS/ARCHIVE/` with an index; 7 active
  documents remain.
- **Docs made truthful.** `README.md` rewritten (API 23 compatible / 26 target, x86_64-only ABI,
  verification matrix, documentation map, emulator gotchas); `ARCHITECTURE.md` scope and reference list
  fixed; test counts corrected to 87 `.test.ets` files; dead links repaired; policy for dead links in
  dated reports documented in `docs/reviews/INDEX.md`.
- **Hygiene.** Removed a stale crash dump and an empty `presentation/viewmodels/` stub; documented that
  `AGENTS.md`/`CLAUDE.md` are intentionally not versioned.

## Engineering protocol — 2026-10-25

Введён обязательный цикл среза и инструменты планирования; код продукта не менялся.

- `TASKS/SLICE_PROTOCOL.md` — преflight (статус/референс/доки), разбор iOS-эталона, швы для
  связанных фич без спекулятивных абстракций, тест до реализации, implementation, gates,
  side-by-side с iOS, Definition of Done, реестр долга.
- `TASKS/SLICE_TEMPLATE.md` — шаблон плана среза (референс → контракт → швы → состояния → тест →
  приёмка).
- `TASKS/CAPABILITY_MATRIX.md` — 105 строк по пользовательским возможностям iOS: 34 `available`,
  41 `partial`, 17 `missing`, 9 `unverified`, 3 `frozen`, 1 `blocked`. У каждой строки — код-доказательство
  и связанные фичи; `available` без witness не ставится.
- `TASKS/WORKMAP.md` — M0 (верифицировать 9 `unverified` строк), S1 (typing indicator, C2),
  S2 (стикеры/TGS, D13).
- `TASKS/TODO.md` — добавлен раздел **Debt**: долг с владельцем и триггером, иначе срез не закрыт.
- Правила зашиты в `AGENT_EXECUTION_PLAN` (preflight + глобальные правила), `AGENTS.md`/`CLAUDE.md`
  (memory pack), `README` (карта документов).

## Slice wave — 2026-10-25

Первый прогон по `SLICE_PROTOCOL`, три агента параллельно + design-срез от lead.

- **S3a (lead).** Данные реакций: `Message.reactions` + чистая модель в `AppState` (порядок chosen →
  count → key, кап 6 + «+N», инкрементальный `applyReactionDelta`), парсер TDLib-снимка и типов в
  `MessageDto`, события `messageReactionsUpdated`/`messageReactionChanged` в normalizer и reducer,
  VO `ReactionChipVO` с stamp'ом в ключе строки только при наличии реакций. Host-тест
  `test-reactions-model.cjs`; D10 → `partial` (рендер и постановка — S3b/S3c). Гейты: host **98/98**,
  оба smoke, hvigor BUILD SUCCESSFUL.
- **S3b (lead).** Подвал реакций: атом `TgReactionsFooter` на примитивах (Flex wrap, «+N»,
  кастомный эмодзи → нейтральный глиф, акцент только для своей реакции), токены и цвета light/dark,
  паспорт и demo. Врезан в текстовый бабл через `TgChatTimelineRow → TgMessageRouter →
  TgTextBubbleV3`; строка пересобирается по reaction-stamp. Host-контракт
  `test-reactions-footer.cjs`. **D10 остаётся `partial`:** медиа-баблы (S3b.1), пикер (S3d) и
  witness не сделаны. Гейты: host **99/99**, оба smoke, hvigor BUILD SUCCESSFUL.
- **S3c (lead).** Постановка/снятие реакции: `SetMessageReactionsCommand` + сериализатор
  (`reactionTypeEmoji` / `reactionTypeCustomEmoji`, int64 строкой, `is_big=false`), use case и
  `ChatReactionController` — оптимистичный снимок записывается до отправки, при ошибке
  восстанавливается предыдущий, guard по токену страницы и по парному тапу, в TDLib уходят только
  chosen-ключи. Тап по чипу доведён от атома до контроллера через session/ports. Host-контракт
  `test-reactions-send.cjs`. Гейты: host **100/100**, оба smoke, hvigor BUILD SUCCESSFUL.
  **D10 остаётся `partial`:** S3b.1 (медиа-баблы) и runtime-witness.
- **S3d (lead).** Пикер реакций: `chat.available_reactions` парсится в `ChatDto`/`Chat`
  (`chatAvailableReactionsAll` / `Some`, `updateChatAvailableReactions`), модель
  `availableReactionKeys` берёт дефолтный ряд iOS (12 реакций) при «all»/неизвестном чате, иначе —
  серверный список с капом 12; `chatAllowsReactions` скрывает пикер, когда чат запрещает реакции.
  Атом `TgReactionPicker` (горизонтальный скролл, токены, spec+demo) врезан над меню действий:
  long-press → попап → тап закрывает меню и уходит в S3c-контроллер. Host-контракты
  `test-reactions-availability.cjs` + `test-reactions-picker.cjs`. Гейты: host **102/102**, оба
  smoke, hvigor BUILD SUCCESSFUL. **D10 остаётся `partial`:** S3b.1 (медиа-баблы), recent/popular
  и кастомные эмодзи в пикере (S3d.1), теги, runtime-witness.
- **S4 (lead).** Мёртвые контролы из аудита закрыты: Toggle «Notifications» в профиле теперь отправляет
  `SetChatMuteCommand` (откат при ошибке, токен страницы), строка «Data and Storage» удалена до
  появления экрана, мёртвая проводка `attachmentMenuLabels` вырезана из шести файлов, неиспользуемые
  DTO `TdAutoDownloadSettings`/`Presets` удалены. Новый host-guard `scripts/test-dead-controls.cjs`
  не даёт им вернуться. Гейты: host **97/97**, оба smoke, hvigor BUILD SUCCESSFUL.
- **M0 (matrix-verifier).** Девять `unverified` строк верифицированы по коду: B6/C10/D20/D24/H4 —
  `missing`, D29/E1/J5/J7 — `partial`. `unverified` = 0. Матрица: 35 `available`, 45 `partial`,
  21 `missing`, 3 `frozen`, 1 `blocked`.
- **S1 + S1.1 (typing-slice).** TTL активности 8 s по iOS, откат по дедлайну без новых store-change,
  группа — только имя, приватный — текст активности, статические точки из токенов, «печатает…» в
  трёх локалях, единый TTL в шапке и списке. Восстановлен harness `chat-screen-source.cjs` для
  не-delegate helper'ов. Host 96/96, smoke и build зелёные. **C2 остаётся `partial`:**
  визуальный witness требует второго аккаунта/клиента.
- **S2 (sticker-slice).** `TgsPlaybackPolicy`: играть только видимое, поверхность (панель — никогда),
  LRU-кеш распакованного Lottie по `fileId`, бюджет 4 инстанса, `@Monitor('tgsPath')`, pass-through
  `fileId` до плеера, warn-лог провала декода. Найдены причины «живой рендер не пойман» и перегруза
  API23. Build + 4 статических TGS-контракта зелёные. **D13 остаётся `partial`** до witness.
- **S3 (lead).** Дизайн reactions: контракт TDLib (`setMessageReactions`, `updateMessageReactions`),
  швы в VO/команды, состояния, разбиение S3a–S3d —
  `docs/specs/2026-10-25-reactions-design.md`.
- **Долги** внесены в `TASKS/TODO.md` §Debt: пульсация точек, мульти-typing, статичная панель стикеров,
  нативный TGS-рендерер, witness C2/D13; плюс мёртвые контролы из аудита — отдельными дефектами.
- `harmonyos_docs` MCP в этой сессии недоступен (только colab/rea/rea-linux) — оба агента
  зафиксировали это ограничением, новых ArkUI API не вводили.
- **Witness: D13 закрыт, C2 открыт.** Второй подъём HVD (watchdog подавлен) дал стабильный гост;
  HAP + ohosTest установлены, сессия залогинена. On-device тесты: `ChatHeaderStatus` 8/8,
  `TgsPlaybackPolicy` 12/12. В чате `HUAWEI Chat` пойман живой TGS-цикл: `tgs playback started
  key=file:11696 players=1`, повторный вход — снова старт, но без повторного декода (кеш по `fileId`);
  diff двух кадров через 700 мс различается только в области стикера (3 274 px) — анимация живая.
  **D13 → `available`.** Для C2 третья попытка (группа `HUAWEI Chat`, 906 участников, 25 дампов
  layout за ~4 мин) не поймала ни одного события набора — нужен второй участник, поэтому C2 остаётся
  `partial`, а цель помечена блокером по этому пункту.
- **Наблюдение:** первый `aa start` на этом прогоне дал `sysfreeze ... LIFECYCLE_TIMEOUT` (debug HAP,
  эмулятор); второй запуск поднялся нормально. Записано наблюдением в `TASKS/TODO.md` §Debt, не
  диагнозом: release-сборки нет, на устройстве не проверялось.

## Checkpoint — 2026-10-18

**Receive scheduling correction.** The drain tested its 8 ms budget before transferring, so a single
clock access or batch parse could consume a quantum with zero progress; an escalating multiplier
`elapsed * (1 + drainHotStreak)` stretched pauses to 250 ms even for a finite already-admitted
backlog. Now one transfer is guaranteed per turn, bounded by 50 transfers / 4 new batches, with the
inter-turn delay at twice the measured work and no backlog-age multiplier. Same-fixture native
comparison: admission→dispatch 31 847 → 5 598 ms, 37 rejected → 0. Four-variant split: baseline
6/15, progress-only 14/15, pacing-only 7/15, combined 15/15. FIFO, deadlines, byte/batch limits,
ownership, ACK ordering and no-uncertain-replay unchanged. [Report](docs/reviews/2026-10-18-receive-latency.md)

**Main acceptance stays PARTIAL.** The exact official package was installed over the existing session
(UID/install identity retained) and getMe, profile, chat list, existing history, Back and same-PID
background/resume were observed across two instances. But 2/4 unique observed request timeouts
(loadChats/getChat/setOption) remained, against historical 87/5 under different windows and workload.
No speedup is claimed. [Report](docs/reviews/2026-10-18-main-receive-acceptance.md)

**Diagnostic main localized, did not explain.** Two cold processes (PIDs 9355/10050) reproduced 4/10
timeout tokens. Selected batches reach Ark admission *after* their deadlines, and native send→copy
intervals overlap four-batch capacity waits by 17.8–36.5 s (88–93%). The second 3 456-record trace
stays PARTIAL at its 120 s cutoff; its initial history failed after an openChat timeout and a later
ordinary reopen displayed messages. Observer cost and TDLib response-ready timing remain unknown, so
**no further production fix is proposed**. [Runtime](docs/reviews/2026-10-18-main-diagnostic-runtime.md) ·
[build/isolated gates](docs/reviews/2026-10-18-bounded-timeout-diagnostics.md)

**Cleanup.** Thirty old Telegram HAPs permanently deleted under explicit authorization after exact
path/size/SHA-256 checks (1 508 061 896 bytes); all ten retained HAPs hash-verified.

## Carried forward — 2026-10-15

Scoped receive/privacy corrections are accepted locally: candidate12 host 95/95 plus static checks,
both official SDK builds inherited from source11, isolated native-postfull-v3 pair install, final
native focus 19/19 and full 1208/1208. Native/ArkTS credits cover active parsing; uncertain delivery
is never replayed. Photo observation remains PARTIAL despite a separate Hypium PASS; the older
unlogged keyboard mismatch and Slowmode title-wait cause remain UNCLASSIFIED.
[Report](docs/reviews/2026-10-15-receive-stabilization.md)

## What is not proven

Source, host and compile checks do not substitute for device, SDK, delivery or visual acceptance.
The unresolved boundary on main is *why consumer progress is too slow*: requested pacing, synchronous
parse/dispatch/store/listener/render work, scheduler contention and synchronous logging are not
partitioned, and TDLib response-ready timing is unobserved. Capacity being full is a symptom, not a
diagnosis; deadlines and memory bounds must not be relaxed to hide an admitted-wait timeout.

The iOS reference was refreshed on 2026-10-18 (`master` @ `f1dd7a2`, 31 572 commits). All 82 source
paths cited from these docs still resolve, but **59 of the 82 files changed upstream**, so their
line-number citations are unverified until re-read. See the refresh log in `REFERENCES.md`.

## Project facts

- **Branch:** `dev` is canonical, tracks `origin/dev`. `main` untouched; dev→main decision deferred.
- **Phase:** production quality against the iOS reference (user mandate 2026-08-31; v0.1.0 tag as a
  goal withdrawn).
- **Tests:** 87 `.test.ets` files under `entry/src/ohosTest/ets/test/` (DevEco `entry@ohosTest`);
  96 host behavioural suites in `scripts/`, run by `node scripts/run-host-tests.cjs` —
  **Node ≥ 24 required**.
- **Architecture:** solo mode, no `presentation/viewmodels/`; chat-page controllers centralized.

## Key documents

| Document | Purpose |
|---|---|
| `TASKS/TODO.md` | **Active queue**: open gates, backlog, decisions needed from the user |
| `TASKS/AGENT_EXECUTION_PLAN.md` | Canonical route (order of phases) |
| `TASKS/PRODUCTION_PARITY_PLAN.md` | Per-phase exit criteria and evidence boundaries |
| `TASKS/LESSONS.md` | Dated blocks + numbered lessons (83–163) |
| `docs/reviews/INDEX.md` | All review reports, newest first (78) |
| `probe/README.md` | Receive-drain harness, status, recorded runs |
| `TASKS/ARCHIVE/INDEX.md` | History — read-only, not instructions |
| `REFERENCES.md`, `ARKGRAM_REFERENCE.md` | External reference registry and competitor notes |
| `ARCHITECTURE.md`, `DECISIONS.md` | Structure and recorded decisions (D1–D25) |
| `README.md` | Build, verification, documentation map |
| `AGENTS.md`, `CLAUDE.md` | Local assistant rules (not versioned, see `.gitignore`) |

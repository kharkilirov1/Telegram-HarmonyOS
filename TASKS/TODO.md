# TODO — Telegram-HarmonyOS

Open work only. Completed items, closed checkpoints and the full pre-compaction list (521 lines)
are in `TASKS/ARCHIVE/TODO-history-2026-10-18.md`. Every open item from that archive is represented
below, some merged where they were duplicates; two of them (the 08-29 bars slice, the commit
decision over 265 dirty paths) are closed by later work and stay in the archive only.

## Рабочие инструменты

- `TASKS/CAPABILITY_MATRIX.md` — что бывает и в каком состоянии; вход в любой срез.
- `TASKS/WORKMAP.md` — 1–3 среза «сейчас»; перегенерируется после закрытия.
- `TASKS/SLICE_PROTOCOL.md` — как делается срез; `TASKS/SLICE_TEMPLATE.md` — шаблон плана.
- Строка матрицы в статусе `unverified` — сначала верификация, потом работа.

## Debt

Долг оформляется только здесь, по `SLICE_PROTOCOL` §9: что не сделано, почему не сейчас, владелец,
триггер возврата, видимое пользователю последствие. Пока долг открыт, строка матрицы остаётся
`partial` и срез не закрыт.

- (пока пусто)
- [ ] **C2 typing: пульсация точек 0,7 s.** Сейчас точки статические (tokens-first). Владелец:
  typing-slice. Триггер: появится witness стоимости кадров и способ проверить остановку
  `animateTo({iterations: -1})` при выходе из чата. Последствие: индикатор чуть менее «живой», чем iOS.
- [ ] **C2 typing: мульти-typing в группе (2/3+ печатающих).** Модель `chats.typingActions` хранит одного
  отправителя на чат; нужен список отправителей в `AppState` + reducer и формат
  «A и B печатают…» / «A и ещё N». Владелец: lead (отдельный срез). Триггер: первый дефект-репорт
  «в группе видно только последнего печатающего». Последствие: неполный паритет с iOS.
- [ ] **D13: панель стикеров статична.** iOS анимирует видимые ячейки грида
  (`ChatMediaInputStickerGridItem.swift:431`), у нас статично by design. Владелец: sticker-slice.
  Триггер: дешёвый способ измерить бюджет кадров на эмуляторе или нативная поверхность без
  Canvas-upload. Последствие: панель выглядит беднее iOS.
- [ ] **D13: нативный рендерер TGS за токеном.** Замерено 3.736 против 2.371 cores на API23; нужен
  surface/XComponent без `putImageData`. Владелец: sticker-slice. Триггер: появление такого
  surface в SDK. Последствие: загрузка CPU на слабых устройствах.
- [x] **Witness D13 (стикеры) — снят 2026-10-25.** На HVD API24 в чате `HUAWEI Chat`: живой старт TGS
  (`tgs playback started key=file:11696 players=1`), повторный старт после ухода/возврата без повторного
  декода (кеш по `fileId`), анимация подтверждена diff'ом двух кадров (3 274 px только в области
  стикера). D13 → `available`. Ограничение: покадровое соответствие iOS-таймингу не сверялось.
- [ ] **Witness C2 (typing) — блокер подтверждён тремя раундами.** Нужен второй участник, который
  начнёт печатать в открытом чате; на одном аккаунте состояние не воспроизводится. Попытки:
  2026-10-25 (1) эмулятор + on-device тесты 8/8 — визуального кадра нет; (2) повторный прогон — нет
  участника; (3) прогон в группе `HUAWEI Chat` (906 участников): 25 дампов `uitest dumpLayout` за
  ~4 минуты, ни одного `печатает`/`typing` в дереве. Владелец: lead. Триггер: второй аккаунт или
  второй клиент. C2 остаётся `partial`, срез не закрыт.
- [ ] **Наблюдение 2026-10-25: `LIFECYCLE_TIMEOUT` на холодном старте debug-сборки.** HVD API24,
  первый `aa start` после установки: `sysfreeze-com.telegram.harmonyos ... Reason:LIFECYCLE_TIMEOUT`,
  приложение не вышло на передний план, второй запуск поднялся нормально. Не воспроизводилось на
  release (её нет) и на устройстве. Владелец: lead. Триггер: появление подписанной release-сборки —
  прогнать холодный старт с faultlogger; до этого — наблюдение, не диагноз.
  **Попытка 2026-10-25 (вечер):** первая — гость завис (`Guest no response, delta: 32`,
  `FreezeCrash: system freeze`), HAP не установился. Вторая — при подавленном `emulator-crash-service`
  HVD поднялся, HAP + ohosTest установлены, устройство на залогиненной сессии; on-device тесты
  **`ChatHeaderStatus` 8/8** и **`TgsPlaybackPolicy` 12/12** прошли. Визуальный witness всё равно не
  снят: история чатов не загрузилась («Сообщений пока нет» + тост «Открытие чата не подтверждено»
  в двух чатах, даже через 30 s), поэтому в таймлайне не было ни стикеров, ни набора. Нужны:
  загружаемая история (или File chat со стикером) и второй участник для typing.

## Active checkpoint — 2026-10-23

- [x] (2026-10-18) Bounded first progress and admitted-backlog pacing without touching deadlines, FIFO
  or credits: 15 regressions, 96 host suites, static, official builds, isolated native comparison, 75
  SDK tests.
- [x] (2026-10-18) Install the exact official main over the existing session and observe getMe /
  profile / chat list / history / Back / cold and warm resume, with no messages and no new login.
- [x] (2026-10-18) Localize diagnostic-main delay across two separate processes; preserve the second
  initial history failure and the later ordinary reopen that succeeded.
- [x] (2026-10-18) Authorized 30-HAP permanent deletion after exact path/size/SHA-256 checks
  (1 508 061 896 bytes).
- [x] Decide whether the receive drain should move off the main thread: **no** — Worker arm and main
  arm are indistinguishable on a prefilled backlog; the cost follows the number of yields, not the
  thread. [Report](../docs/reviews/2026-10-20-drain-topology-spike.md)
- [x] Decide whether `DRAIN_BUDGET_MS` should change: **no** — the 2026-10-21 sweep was corrected on
  2026-10-23 (zero-delay yield vs the shipped `max(2, min(250, elapsed × 2))`, arithmetic hop counts,
  injected 8 ms quantum); recommendation withdrawn, constant stays 8.
  [Report](../docs/reviews/2026-10-21-drain-budget-sweep.md)
- [x] Re-check the competitor note against the retained artifact and correct it (1.0.1, not 3.2).
  [Report](../docs/reviews/2026-10-21-arkgram-analysis.md)
- [x] Re-run the budget sweep in the shipped yield model on the emulator (2026-10-23): shipped pacing
  is ~2.8–3.1× slower than the zero-delay model, 8 → 64 ms buys −18 % (not −27 %), frame gaps are
  non-monotone (207 / 285 / 216 / 130 ms), all 24 rows completed.
  [Report](../docs/reviews/2026-10-23-drain-yield-model-rerun.md)
- [ ] **Separate real consumer work (parse/dispatch/store/render) from intentional pacing,
  scheduler/logging overhead and TDLib response-ready timing.** The synthetic 8 ms quantum was
  injected, not observed, so it is not a consumer-cost figure; the shipped-pacing shape is now
  measured (2026-10-23), the work quantum is still not. A real-device scroll-under-load check comes
  next. Main reliability stays PARTIAL; no speedup claim across unequal windows.

## Open gates

### External acceptance — blocked on a real account or device

- [ ] Authenticated delivery: send / receive / media with a real account, plus picker and provider IO.
- [ ] Real provider, microphone and camera checks (the emulator has no microphone and returns no
  CameraPicker result).
- [ ] Current shipped-iOS comparison and a fresh visual matrix — the C2 capture has to be compared by
  the user against the supplied iPhone 16 Pro Max reference before the look is called accepted.
- [ ] Native `ImmersiveMaterial` on an API26 device.
- [ ] Authenticated messages/media/panels and account teardown.
- [ ] `signingConfigs` + certificate via DevEco → release build → tag `v0.1.0`.
- [ ] Dogfood day on the patched build (light theme, scroll performance with the blur budget,
  NavDestination transition flash, quote bubble and voice playback witnesses).

### Runtime unknowns — need measurement, not code

- [ ] The main-timeout boundary above (pacing vs parse/dispatch/store/render vs scheduler vs logging).
  Drain thread placement and slice budget are excluded — closed on 2026-10-23, see the active
  checkpoint.
- [ ] Older unlogged keyboard mismatch and Slowmode title-wait: **UNCLASSIFIED**, and later PASSes do
  not retroactively establish either cause.
- [ ] Photo marker coverage stays **PARTIAL**; a separate Hypium PASS does not create the missing
  instrumented terminal boundary.
- [ ] Direct active framework-main `napi_env` cleanup witness; ordinary retirement and Worker proofs
  do not substitute.
- [ ] Native env / opaque-handle teardown (contract exists, installed-binary mapping does not).
- [ ] `openChat`/`closeChat` dialog open-count; slow-consumer backpressure and conversion-error
  recovery; unknown forward outcome.
- [ ] TDLib pending Message/update semantics for authoritative pending-outgoing slow-mode feedback.
- [ ] Propagate asynchronous TDLib transfer failures if a concrete `updateFile` failure shape is
  captured on emulator or device.
- [ ] On-device unit runner hangs: `aa test` starts the TestAbility but no suite begins. Bisect the
  top-level imports that pull `AppCoreRuntime` singletons.
- [ ] Re-run the AppFreeze scenario after the P0 fix.
- [ ] P1 visible TGS playback still overloads the API23 emulator; the next credible path is a
  renderer-level native `rlottie` with the same visible-TGS trace gate.
- [ ] **[P4-d] Drain freeze resilience — observe.** The previous pacing survived two 90 s cold starts;
  the 2026-10-18 pacing change has not been through a new `THREAD_BLOCK_6S` watch yet.

### Product and UI backlog

- [ ] **Notifications and push with inline reply.** No `notificationManager` / `wantAgent` / push code
  exists in `entry/` (checked 2026-10-23), while the reachable competitor ships a push extension with
  an inline-reply token. Needs a provider/AGC decision before implementation.
- [ ] **Island Player Suite** (пласт, spec `docs/specs/2026-07-22-island-player-suite-design.md`,
  order approved 2026-07-22) — the ordered feature list inside the spec is still unexecuted.
- [ ] Chat-state actions: kicked → red "Delete and Exit"; per-user `bannedRights` (needs a
  `getChatMember` hydrate); bot not started → "Start"; blocked → "Unblock"; Premium-required;
  secret-chat handshake; "Join Group" for non-member megagroups.
- [ ] Full current-iOS Compose parity: group member search/tokens/avatar/TTL, OS Contacts permission
  and phone resolution, channel visibility/public username/subscriber steps.
- [ ] Typing indicator: root cause fixed, only the live UI screenshot remains; polish
  `online=false/true` on background/foreground.
- [ ] Service line with an empty or Unknown name ("Unknown вступил(а)"), one capsule with an empty
  name — log `serviceUserIds` on repro.
- [ ] Sticker track polish: lazy TGS animation by visibility, unpacked-Lottie JSON cache,
  favourites and set search. Feature track: webm → `TgInlineVideoView`, tgs → thumbnail fallback.
- [ ] Media pipeline **[P4]** and the remaining R1.5 defect list; the rest of the dogfood checklist
  (photo fullscreen, voices, video/doc on tap, stickers/GIF, sending with sanction).
- [ ] Login-code polish: show the service code in UI (native `HdsSnackBar`); witness is blocked by
  the code-request flood limit.
- [ ] Low priority, needs design assets: pdf/audio/zip type icons; `List.divider` instead of the
  inline `Divider` (#13).
- [ ] **[perf, post-v0.1.0]** `@ReusableV2` row recycling (#1): needs the smoke contract and row
  geometry stabilised first.
- [ ] Deeper `AuthSideEffect` ready/warmup integration tests once a TDLib/app-context test seam exists.
- [ ] **Repro basket for the File chat:** a poll and a sticker still need to be sent there — the two
  unsupported items found earlier were not poll types, and the sticker type fork has never been
  caught rendering live.
- [ ] Evaluate top-level vs nested `TdObject.getString` on real consumers, fixing only with a focused
  RED; do not rewrite the regex parser from one demonstration. Localize the hardcoded actions as a
  separate UI slice.
- [ ] Minor contract drift: legacy `minAPIVersion`/`targetAPIVersion` (`22`/`22`) in
  `AppScope/app.json5` against `compatibleSdkVersion 6.1.0(23)` / `targetSdkVersion 26.0.0` in
  `build-profile.json5`; the `.reuseId()` contract in `smoke-ui-phase0.ps1:400` against lesson 84;
  `HYBRID_DESIGN:89-92`.
- [ ] Full clean-checkout build; mark-read must keep failing explicitly when the committed target is
  unknown rather than reading an earlier one.

### Decisions needed from the user

- [ ] **Capacity bounds for the main path** (4 batches / 16 MiB / 30 s). Changing them is a policy
  decision, not a fix — and must not be used to hide an admitted-wait timeout.
- [ ] Logo: pick one of the four SVGs in `design/logo/` and replace the DevEco layered placeholder.
  Research artefacts are archived in `design/logo/research/`.
- [x] Canon winner: resolved by `DECISIONS.md` D25 — active sources are `STATUS`/`TODO`/agent plan/
  parity plan/`DECISIONS`, `docs/ai/*` is a frozen archive, and `MASTER_PLAN_TELEGRAM_UI.md` governs
  only the `tg_ui` visual contract.
- [ ] Auto-hide the floating tab bar on scroll (`HdsTabsController.bindScroller` + HdsTabsMiniBar) —
  behavioural decision.

### Security — user action required

- [ ] **Revoke and reissue the exposed API key** `sk-or-v1-…` (visible in the 2026-08-29 audit
  screenshots) and delete both messages in the File chat, including the prompt-injection text.

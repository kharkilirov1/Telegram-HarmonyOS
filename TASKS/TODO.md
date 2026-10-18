# TODO — Telegram-HarmonyOS

Open work only. Completed items, closed checkpoints and the full pre-compaction list (521 lines)
are in `TASKS/ARCHIVE/TODO-history-2026-10-18.md`. Every open item from that archive is represented
below, some merged where they were duplicates; two of them (the 08-29 bars slice, the commit
decision over 265 dirty paths) are closed by later work and stay in the archive only.

## Active checkpoint — 2026-10-18

- [x] Bounded first progress and admitted-backlog pacing without touching deadlines, FIFO or credits:
  15 regressions, 96 host suites, static, official builds, isolated native comparison, 75 SDK tests.
- [x] Install the exact official main over the existing session and observe getMe / profile / chat
  list / history / Back / cold and warm resume, with no messages and no new login.
- [x] Localize diagnostic-main delay across two separate processes; preserve the second initial
  history failure and the later ordinary reopen that succeeded.
- [x] Authorized 30-HAP permanent deletion after exact path/size/SHA-256 checks (1 508 061 896 bytes).
- [ ] **Separate consumer work, intentional pacing, scheduler/logging overhead and TDLib
  response-ready timing before choosing another production fix.** Main reliability stays PARTIAL;
  no speedup claim across unequal windows.

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
- [ ] Minor contract drift: `D14` (target 23 vs 26 in `build-profile.json5`); the `.reuseId()`
  contract in `smoke-ui-phase0.ps1:400` against lesson 84; `HYBRID_DESIGN:89-92`; the fate of the
  API 22-era `MASTER_PLAN`.
- [ ] Full clean-checkout build; mark-read must keep failing explicitly when the committed target is
  unknown rather than reading an earlier one.

### Decisions needed from the user

- [ ] **Capacity bounds for the main path** (4 batches / 16 MiB / 30 s). Changing them is a policy
  decision, not a fix — and must not be used to hide an admitted-wait timeout.
- [ ] Logo: pick one of the four SVGs in `design/logo/` and replace the DevEco layered placeholder.
  Research artefacts are archived in `design/logo/research/`.
- [ ] Canon winner: `AGENTS.md` rule 5 + `DECISIONS` D3 ("MASTER_PLAN wins") vs `CLAUDE.md`
  ("docs/ai is an archive"). One of them has to lose.
- [ ] Auto-hide the floating tab bar on scroll (`HdsTabsController.bindScroller` + HdsTabsMiniBar) —
  behavioural decision.

### Security — user action required

- [ ] **Revoke and reissue the exposed API key** `sk-or-v1-…` (visible in the 2026-08-29 audit
  screenshots) and delete both messages in the File chat, including the prompt-injection text.

# Official SDK and existing-emulator validation — 2026-10-13

Base: published `dev@bbfc305d47b73657147e853cf1ff008e31d6e471`. This task continues the published source checkpoint; it does not redo its 400-file review. Evidence directory: `C:\Users\Kharki\Documents\Codex\2026-10-13\task-2`.

## Scope and preservation

Official DevEco Node 24.14.1 / Hvigor and the installed SDK built the original checkout using its normal cache. The previous EPERM occurred in a separate verification copy and did not reproduce as a compiler blocker in the original checkout. Normal approved execution also made HDC 3.2.0f available at `127.0.0.1:5555`. No ACL, security policy, network policy, Windows privilege, persistent access, or credentials were changed.

The existing Pura 90 Pro Max emulator runs HarmonyOS 6.1.1 / API 24, x86_64, with 6 GB RAM and 12 GB data. Its existing data was preserved. Native test HAPs use the separate bundle `com.telegram.harmonyos.nativevalidation20261013`; the production bundle `com.telegram.harmonyos` was not reinstalled, stopped, cleared, or used to send messages. Package metadata preservation is measured separately from private data, which was not inspected.

Validation uses public dummy API credentials (0 / empty hash), not the user's private ConfigLocal contents. Production sources and original native test callbacks are projected into the main module through the existing `prepare-native-main-witness.cjs` mechanism so resource namespaces are correct. `source-input-sha256.json` records 768 public inputs; `projection-receipt.json` records 105 deliberate projection paths. Candidate receipts distinguish application changes from generated validation-only paths.

Both main and ohosTest are built sequentially with `--no-incremental --no-parallel --no-daemon --stacktrace`. A cached candidate1 main build was explicitly rejected as new compilation evidence; forced compilation followed. Every installation supplies the complete main/test HAP pair, and native logs identify fresh process IDs. HDC exit zero is not used as the test oracle: each Hypium result and declared/completed test count is parsed.

## Diagnosed defects and changes

1. Public `ConfigLocal.example.ets` omitted the already-consumed `USE_TEST_DC` export. Added `false`; private configuration remains untouched.
2. Hundreds of synchronous Hypium cases drained in one platform timer task, triggering AppFreeze. An inherited `beforeEachIt` yields for 16 ms between cases. All 85 suite factories and 1207 cases remain registered. The emoji catalog's existing per-128-item yield also needs a positive 16 ms delay; zero-delay awaits still shared one timer task on this emulator. All 9585 catalog assertions remain intact.
3. Native focus and IME snapshots can straddle show/hide transitions. One native query filtered by bundle and focus avoids redundant calls; disagreement discards the sample within the original bounded deadline and still requires coherent observations before Back. Ownership, focus, deadlines, and no-replay guards remain enforced.
4. Native text replacement exposes intermediate deletion/typing prefixes to the real debounce. Member-search checks now correlate exact requests by payload, query, port and object identity, reject duplicate final queries, and deliver stale replies to prove fencing. Production debounce behavior is unchanged.
5. Root and resend fixtures can be outside the viewport after previous interactions. Tests restore the owned root viewport and reveal the existing footer before the single send click. No production send behavior was changed.
6. Profile bio had a real renderer defect: the `@Builder` captured primitive values while its branch remained mounted. The native failure image shows “Cached bio” after successful Retry. Both information row builders now receive one object parameter; all five call sites compile to `makeBuilderParameterProxy` reactive getters. IDs, styles, lifecycle and account ownership guards remain unchanged. The original native fresh-bio assertion is retained.
7. The thumbnail pressure test asserted the last URI before the second loader batch completed under timer pressure. Controlled loader completion and URI publication now establish completion causally, preserving peak concurrency 2 and final `file://14`, with seven additional ordering/drain checks. The production coordinator is byte-identical. A delayed-turn baseline fails the original assertion; over-bound, dropped-publication and serialized-work mutants are rejected.
8. Photo preview's busy footer is below the viewport after tapping its button. A pre-cleanup capture records both session and composer busy=true, with disabled native edit controls and the footer below the screen. The original text-only wait then fails. The existing helper now reveals the stable-ID footer before the original exact-text wait, and additionally checks that specific footer's text. Busy true/false and photos:0 use this path; image-unavailable behavior and every original state/control assertion remain intact. The later post-cleanup image is not used to infer busy state.

## Preserved diagnostic results

| Run | Result | Interpretation |
|---|---|---|
| Baseline full, PID 8127 | 706 completed: 699 pass, 1 failure, 6 errors; 501 unrun | AppFreeze; one timer task drained hundreds of assertions |
| Candidate1 full, PID 17776 | 1001 completed: 997 pass, 1 failure, 3 errors; 206 unrun | Separate long emoji callback exposed zero-delay scheduling defect |
| Candidate2 focused | Deliberately stopped after 1 pass / 2 errors and a pending case | Root viewport restoration needed; not reported as a completed run |
| Candidate2 catalog | 3/3 pass | Positive-delay catalog iteration; no new fault |
| Candidate3 focused, PID 3544 | 11 completed: 9 pass, 1 failure, 1 error | Real stale bio plus ensuing navigation cascade |
| Candidate3 full, PID 4694 | **1207 completed: 1198 pass, 3 failures, 6 errors** | Normal completion, no new AppFreeze; profile, thumbnail and photo defects remained |
| Candidate3 isolated UI tail | 16 completed: 15 pass, 1 error | Chat decomposition, album and all timeline cases passed; photo busy observer independently failed |
| Candidate4 photo observation, PID 16154 | 1 completed: 1 error, 88.134 s | Unchanged failing assertion; pre-cleanup state and screenshot established clipping |
| Candidate4 focused | **16/16 pass**, 173.102 s | Retry/Back, pagination, member search, unchanged profile scenarios, catalog and all thumbnail cases |
| Candidate5 photo, PID 19848, aggregate 120 s | 1 completed: 1 error, 120.030 s | Hypium aggregate timeout; no component assertion failure was reported |
| Same Candidate5 HAP, PID 20021, aggregate 240 s | **1/1 pass**, 209.949 s | Full photo flow completed, including disabled controls, missing photo, empty selection and ten photos |

Historical failures and HDC stdout are retained. `candidate3-after-full-fault-list.txt` matches the prior four historical fault reports; this supports absence of a new report for that run, not a universal stability claim.

The 120-second limit was supplied by the workspace runner for the entire case. The same C5 HAP completed with 240 seconds: busy=true at 96.485 s, busy=false at 147.391 s, unavailable photo at 152.223 s, photos:0 at 153.735 s, and final completion at 209.949 s. This distinguishes an insufficient aggregate run budget from the original missing-footer assertion. Source component waits remain 5000 ms; no assertion, per-component wait or product behavior was weakened. The full run uses the explicit 240-second aggregate budget and 900-second command limit. Hypium timeout does not cancel its callback; the full run therefore follows an explicit isolated-bundle force-stop and a zero-process receipt.

## Evidence boundaries

The isolated EntryAbility also exercised real packaged TDLib/NAPI client creation, receive-loop startup and gateway wiring; its public dummy credential gate stopped authentication. Synthetic native fixtures do not establish authenticated Telegram delivery, real contacts, camera/provider/microphone acceptance, current shipped-iOS parity, or store-release signing. `signingConfigs` remains empty and the produced HAPs are unsigned. Existing emulator installation success does not imply distribution readiness. Direct on-device HAP hashing was denied and was not bypassed; host HAP hashes and successful install receipts do not establish installed-file byte identity.

The requested `harmonyos_docs` MCP capability was unavailable; installed SDK contracts/compiler and official OpenHarmony documentation were used, including the single-object `@Builder` parameter contract: https://github.com/openharmony/docs/blob/master/en/application-dev/ui/state-management/arkts-builder.md . Native CUA surfaces were unavailable; working screen evidence was captured through the official HDC `snapshot_display` command.

The previous published CI run (38357110508) passed 83/83 Linux host suites and static checks with Hvigor skipped. It is evidence for the published base, not this correction set; its publication CI is checked separately. Final local source, build and test receipts are recorded below.

## Final verified outcome

- Original checkout: forced official main and ohosTest builds PASS. Both validation HAP builds also PASS and the complete pair was installed successfully.
- Native focused C4: 16/16 PASS. Same final C5 HAP photo scenario: 1/1 PASS, 209.949 s with explicit aggregate budget 240 s.
- Final full native C5: **1207/1207 PASS**, no Failure/Error/Ignore, 563.208 s; no class selection.
- Final host runner: **91/91 PASS** in one serial run. PowerShell and Bash static checks PASS.
- Exact source/projection verification: 768 source inputs and 105 projection paths checked; 759 baseline inputs unchanged, with 18 reviewed source/host paths changed in total.
- This report freezes the build/native checkpoint based on bbfc305 before publication. Independent final gpt-6-astra xhigh review accepted the frozen sources, results and preservation receipts without blocking findings. Subsequent commits and publication CI are recorded in Git history and separate task receipts.

Artifacts and SHA256 are listed in [the curated evidence receipt](2026-10-13-native-validation-evidence.json). Raw logs, screenshots, patch manifests and projection receipts remain in the task evidence directory. The final production-package metadata comparison and fault-log comparison are separate workspace receipts, and must be consulted before extending preservation/stability claims.

### Reproduction

Official source build command (run sequentially for entry@default and entry@ohosTest using the installed DevEco environment):

```text
hvigorw.bat assembleHap --mode module -p product=default -p module=entry@default -p buildMode=debug --no-incremental --no-parallel --no-daemon --stacktrace
```

The workspace build-validation.ps1, install-validation.ps1 and run-native-tests.ps1 record exact commands and target only the isolated bundle. Final native command uses -s nativeUiModule entry, -s nativeColorMode light, -s timeout 240000 and -w 900, with no class filter. Host: node scripts/run-host-tests.cjs; static: scripts/smoke-ui-phase0.ps1 and scripts/smoke-ui-phase0.sh.

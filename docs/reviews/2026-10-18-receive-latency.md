# Bounded receive scheduling correction — 2026-10-18

Local source candidate on `dev@08531936bcfe5fcc290dcacdc43beea66e187d03`. One production file (`TdGateway.ets`) and one actual-source host regression suite changed. Independent Astra final review accepts this bounded correction and isolated validation. The candidate has not been published or installed over the authenticated main application.

## Reproduced cause and correction

The old drain tested its 8 ms budget before transferring an item. Intra-callback delay of at least 8 ms could produce no progress; parsing could also consume the budget before the first transfer. Actual-source controlled-clock tests reproduce both paths. Delay before callback entry alone does not establish this defect.

A separate escalating multiplier, `elapsed * (1 + drainHotStreak)`, progressively scheduled 250 ms pauses even for a finite already-admitted backlog. A due-time scheduler running the actual gateway, dispatcher and pending-request code demonstrates the unchanged 30 s deadline expiring behind 199 bounded updates. Progress-only still fails that deadline; pacing-only still fails pre-work progress. The combined candidate passes all 15 regressions. The four-variant results are baseline 6/15, progress 14/15, pacing 7/15, combined 15/15.

The correction guarantees one meaningful transfer when available, then respects the cooperative 8 ms target and a finite 50-transfer/4-new-batch-load ceiling. Inter-turn delay remains at least 2 ms, scales with twice the measured work, and retains the 250 ms ceiling. Backlog age no longer multiplies that delay. A synchronous parse/handler can exceed 8 ms; this is not a hard execution-time bound. FIFO, request deadlines, native/ArkTS byte and batch limits, generation handling, active ownership, reference clearing before ACK, and uncertain-outcome/no-replay behavior remain unchanged.

## Same-fixture native comparison

Both paired diagnostic builds use the same generated-only instrumentation and credential-free isolated bundle `com.telegram.harmonyos.nativevalidation20261014`, on the existing API24 x86_64 emulator. No AppCoreRuntime/AuthSideEffect or account initialization is created. A fresh actual gateway sends 161 `getOption(version)` requests, with **8 ms of injected, artificial synchronous consumer work per response** and the normal 30 s request timeout. That quantum models a slow consumer; it is not an observation of the real parse/dispatch cost, and the later drain notes that quote "the measured 8 ms" misread it (corrected 2026-10-23). The selected token is last in the native admission and drain order. A separate 45 s observation window allows recording late consumption and actual cleanup; it does not extend a request deadline.

| Measured result | Baseline PID20660 | Candidate PID22960 |
| --- | ---: | ---: |
| Selected admission → dispatch | 31,847 ms | 5,598 ms |
| Selected request → Promise continuation | 31,911 ms, rejected | 5,671 ms, resolved |
| Scheduled drain delays before settlement | 28,025 ms | 3,264 ms |
| Rejected requests | 37 | 0 |
| Measured work executions | 124 | 161 |
| Unique responses consumed in admission order | 161 | 161 |
| DisplaySync callbacks strictly inside work interval | 1,572 | 271 |

The baseline's selected response was admitted well before its unchanged deadline. Its native receive→publish took 53.568 ms and publish→JS took 12.488 ms, while Ark admission→dispatch took 31.847 s. This is a demonstrated admitted-wait timeout in this synthetic native flow. All late responses were consumed after timeout without retry; manufactured work was disabled at selected settlement to allow cleanup. Both runs show exactly one selected native/Ark ACK, actual Closed, producer join, TSFN finalization and zero remaining ownership. The baseline intentionally fails the final selected-success assertion after its safety assertions; that exact failure phase is bound to the frozen fixture source by the analyzer.

Candidate Hypium is 1/1 PASS. The independent fresh-process nearby gate, PID23279, is 75/75 PASS across TdGateway, GatewayErrorPropagation and NativeReceiveFlow. All 161 candidate responses received their full measured consumer work. DisplaySync proves callback opportunities during processing, not smooth rendering or input acceptance. Maximum observed unresolved-burst frame gap was 1,541 ms and includes a 1,532 ms synchronous request-send burst. No 6 s gap occurred in this fixture. Native steady-clock and Ark uptime durations are never subtracted across domains.

## Build and evidence identity

Official main and ohosTest were freshly built with DevEco Hvigor in the original checkout. Both are unsigned debug artifacts, matching the existing configuration. Host coverage is 96/96 across an initial 94 PASS and successful approved reruns of two environment-blocked Git/MSYS suites. PowerShell and approved Bash static checks PASS. Existing receive ownership host suite is 10/10; the new suite is 15/15. The final manifest verifies 939 public inputs, 784 mapped projection files and all six preserved HAPs. Private ConfigLocal is excluded.

| Artifact | SHA-256 |
| --- | --- |
| Official main | `e32101bda9c2c6be611bebefbfa4838354af87061c47c4d16d52370cb1d5cf06` |
| Official ohosTest | `81c02b41ff963fa43815dad545ce7fe473c7e0c22ee729e56f4f3a469502d6d7` |
| Isolated candidate main | `f3011ac2edc2978b546a4745e581bc4e3dfc75c4aaf716d4c04f63ce6825bb5f` |
| Isolated candidate ohosTest | `928d94424298f4342ad42e39b29e16acde3e217fc7ead23f639104297372f423` |

Evidence root: `C:\Users\Kharki\Documents\Codex\2026-10-13\task-2\receive-latency-fix-2026-10-18`. Key files: `final-evidence-verification.json`, `source-candidate.patch`, `candidate-public-inputs.json`, `host-causal-comparison.json`, `native-baseline-v3-run2-latency-analysis-v3.json`, `native-candidate-v3-run1-latency-analysis.json`, `native-candidate-v3-focus1-run.json`, `astra-final-fix-review.md`, and `artifacts/*/manifest.json`. Paired manifests under `native-draft/*-v3` prove reversible instrumentation and identical non-gateway diagnostic inputs. Parser controls reject missing/wrong/duplicate evidence and earlier baseline safety failures; all 12 controls pass.

Preserved failed attempts include the first collector's overlong hilog expression, the parser's initial misclassification of ordinary Hypium class-name lines, initial sandbox Git/MSYS failures, and the intentional native baseline failure. None is silently counted as a successful run. The installed hilog help grounded the filter correction. `harmonyos_docs` was unavailable; platform grounding used local SDK declarations, the local TDLib schema and the pinned Petrelgram receive reference, followed by official compilation and actual runtime execution.

## Remaining boundary and next main check

This result does not retrospectively establish the cause of all 87/5 historical authenticated-main timeouts or prove their repair. Main remains the previously authorized 0853193 installation: UID20020062, install/first-install1788721575252, update1792286375924 and PID7178 unchanged before/after isolated work. No main install/force-stop, messages, new login, account/key migration, data clearing, reboot, credentials, ACL/security/network changes or historical-artifact removal occurred in this stage.

The next step requires the separately specified main approval: one `hdc install -r` of the exact official main HAP above, with package identity/hash checks and preservation of existing data, followed by fresh-process authentication-state/getMe/profile/chat-list/existing-history/resume observation. Do not install ohosTest alone, clear data, create a login or send real messages. Release signing and unrelated authenticated/provider acceptance remain separate. The newly built main HAP is preserved at `artifacts/official-candidate-v1/main.hap` under the evidence root.

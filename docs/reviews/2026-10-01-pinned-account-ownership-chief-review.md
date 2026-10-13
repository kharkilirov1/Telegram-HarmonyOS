# Independent final review: pinned account/session reliability

2026-10-01. **FINAL ACCEPTED** for the exact six-path candidate and the bounded pinned-message ownership / delayed-result ordering repair described below. No remaining P1/P2 defect was found in this scope. This is code and evidence acceptance of the isolated candidate; it does not attest that the Desktop checkout has been installed or authorize unrelated changes.

Reviewer selection supplied by the parent: `gpt-6-astra`, `xhigh`. This records the explicit selected configuration, not independent attestation of an undisclosed backend. The reviewer edited only reviewer artifacts, ran safe host probes, and read the supplied build/device evidence. No product/test source, Desktop checkout, Git index/history, SDK build, device, account or Telegram action was performed by this reviewer.

## Frozen scope and correspondence

The reviewed manifest is [feature-manifest-code-final.json](/C:/Users/Kharki/Documents/Codex/2026-10-01/task-2/account-reliability/feature-manifest-code-final.json), SHA-256 `53986e53a377dc235b8c8d536f18896f6d6828ce99d9c2e4f98b2f396a3f83f8`. All six before/after SHA values match the immutable public baseline and candidate. The complete public-tree comparison, excluding candidate-local `.git` metadata, finds exactly these six changed paths: baseline 1,026 files, candidate 1,028 files, two new files and three overlaps with already-dirty paths.

| File | Reviewed role |
| --- | --- |
| `entry/src/main/ets/domain/usecases/loadPinnedMessage.ets` | Captured-gateway single-pin retrieval; existing global compatibility helper retained |
| `entry/src/main/ets/ui/pages/chat/ChatPinnedMessagesCoordinator.ets` | Route/account/request fencing and refresh/page generation invalidation |
| `entry/src/ohosTest/ets/test/PinnedMessageOwnership.test.ets` | 58 real ETS callbacks with deferred transport and explicit current-store fixture |
| `entry/src/ohosTest/ets/test/List.test.ets` | One new import and one registration call; existing registrations preserved |
| `scripts/test-pinned-message-ownership.cjs` | Same 58 callbacks plus three actual Session/Context/route-predicate integration cases and five behavioral mutations |
| `scripts/test-ios-pinned-message-panel.ps1` | Old global-helper literal replaced by captured-factory and executeSingle checks; other contracts retained |

The two product hashes remain `45f026f2ec6ad439b559d9c95c9f66367211123ac85338b5e044efcbee036f6b` (use case) and `c1a8a342110981468624d94d75a966a6edf901453c3200872bd8e92fcf8be1aa` (coordinator). No Session/Context delegate signature, reactive owner, subscription or transport lifecycle architecture changed.

## Substantive findings

**R1, ownership/API fixture gap: repaired.** Initial search, single fallback and pagination now use the captured route's gateway. The established route predicate checks the actual AppStore scope and lease; route object, chat, lifecycle, activation and request identity are checked before dispatch and after resolution/rejection. An old request cannot obtain a replacement global gateway through fallback, publish stale pins, or clear the replacement owner's state. An invalidated A scope cannot become current merely by returning the registry from B to A. Fallback entry remains synchronous after the guarded initial continuation and repeats its own ownership preflight.

R1 was reproduced at the coordinator/API boundary using a deliberately controlled registry/transport ordering. Normal authenticated account-switch reachability of that original fixture remains unproved. Existing AppCoreRuntime shutdown/initialization serialization and adapter generation fences were not removed or replaced; this review does not claim an observed authenticated cross-account disclosure.

**R2, ordinary same-account delayed ordering: repaired.** Initial refresh immediately retires the previous pagination generation, clears its cursor and releases its busy flag. Every page captures both the base request and page request IDs. Consequently, an old page cannot append to a refreshed snapshot, restore its old cursor, or release a newer page's loading flag, whether it succeeds or fails. The cleared cursor also blocks another old-cursor page while refresh is pending. This ordering needs no account replacement; the existing `onPinnedMessageChanged` adapter calls the same refresh path. Current deduplication, repeated-cursor termination, empty/404 fallback and explicit same-cursor retry controls remain green.

The activation guard allows a valid retained route: it does not require navigation-top ownership. Activation sets the flag before the initial pinned load, and teardown clears it. No broader route/UI policy or new account state owner was introduced. The narrow source changes do not require a new pixel acceptance gate.

## Independent regression and sensitivity checks

The earlier independent adversarial probe remains applicable to the unchanged product hashes: **23/23 candidate PASS**; the baseline has **18 behavioral assertion failures plus one explicit missing-new-API assertion**, with four passing controls. It exercises actual coordinator/use case, AppStore, route, lease and route-predicate source with explicit synthetic DTO/transport/registry boundaries. See [astra-source-review.md](/C:/Users/Kharki/Documents/Codex/2026-10-01/task-2/account-reliability/astra-source-review.md) and the corresponding probe logs; its former pending status is historical and superseded by this final report.

For final acceptance I read the entire new ETS suite and host runner, then independently reran the submitted runner against the candidate, immutable two-file preimages, and all five in-memory mutations. No disk source mutation occurred. Results are recorded in [astra-final-host-reruns.json](/C:/Users/Kharki/Documents/Codex/2026-10-01/task-2/account-reliability/astra-final-host-reruns.json):

| Run | Result |
| --- | --- |
| Candidate | **61/61 PASS**, consisting of 58 actual ETS callbacks and three integration cases |
| Same callbacks with baseline product preimages | **47 AssertionError failures**, 14 controls pass; ordinary failing exit code 1 |
| Account ownership guard removed | 26 behavioral assertion failures |
| Fallback completion ownership guard removed | 9 behavioral assertion failures |
| Refresh generation/cursor fencing removed | 5 behavioral assertion failures |
| Captured gateway rebound to global adapter | 1 behavioral assertion failure |
| Actual Session fallback delegate disconnected | 1 behavioral assertion failure |

Every RED result is an assertion failure, not an import, loader, syntax or TypeError failure. Mutation anchors are required to exist in actual source. Expected-RED mutation runner exit 0 means the sensitivity check succeeded, not that the mutated product passed. Case names and callback bytes are shared between baseline/candidate; the native pinned suite contains exactly the same 58 callback names.

The three extra host cases execute real Session delegates, Context accessors, pinned view model and production route predicate. They deliberately bypass the Session constructor/resource initialization and inject the current runtime-store boundary. The SDK suite executes actual coordinator/use case/parser/AppStore/RouteParams/Lease, with deferred gateway ports and an explicit current-store predicate fixture; it does not execute the production Session/predicate integration natively. These are complementary, explicitly limited witnesses.

The supplied full host log independently parses as **67 distinct suites, 67 PASS**. Decomposition evidence is **22/22**, and every recorded source hash still matches. Pinned panel/navigation static checks and PowerShell/Bash smoke logs are PASS. The static-contract change did not remove unrelated assertions.

## SDK and native evidence

Both supplied serial main and ohosTest build logs contain one `BUILD SUCCESSFUL` and no `BUILD FAILED`. The four changed entry source files match the SDK build tree byte-for-byte. Both frozen HAPs match their build outputs, size/hash records, actual ZIP `module.json`, isolated bundle identity and expected compiled ABC markers:

| HAP module | SHA-256 |
| --- | --- |
| `entry` | `9b67962410074f8479b9c46198f9063f9dee3b1d6d93a75c156971753a0285b7` |
| `entry_test` | `f3540e8ae3fb80cef8b7c373ed954f02bd6a8f074a3bbc3d2bc22803e09f8020` |

The authoritative installation log names both exact HAP paths and has two successful installations plus `AppMod finish`. The earlier directory-install-only log is not acceptance evidence. Executions target `com.telegram.harmonyos.chatrefactor20261001`; the reviewed runner force-stops/checks that isolated bundle before each run. No claim relies on process STIME.

I parsed the complete raw native logs independently, preserving all status codes. Each run has one summary, unique complete case identities, matching starts and completions, zero failure/error/ignore records, and successful overall/test-finished result codes:

| Run | Accepted result | Raw log SHA-256 |
| --- | --- | --- |
| New pinned suite | **58/58** | `e62f42ffffe8f07eab98d4ecef0450f08db8e235bbea9983ee705af0154cbc03` |
| Focused pinned + existing parser/use case suite | **64/64** | `dba21d60f8d425ed040e4e540aa2eb25fcaea353167582d555fb92a45aeb9675` |
| Full registered suite | **924/924** | `e2af2c6746a61de8f7d62d101559e3435b22f50c22d2bfa3e302b1ae16efdaa5` |

The 58-case set is contained in the 64-case set, which is contained in the full 924-case set. Raw hashes agree with all supplied native evidence and the post-run [runtime-evidence-final.json](/C:/Users/Kharki/Documents/Codex/2026-10-01/task-2/account-reliability/runtime-evidence-final.json), SHA-256 `336c8f25a6d514aed5f707fa8dfaa2215300f2e379310e129623f0c01fc17495`. Candidate files, four SDK entry sources and both HAPs remained at the frozen hashes after the runs and independent host checks. Independent machine-readable audit: [astra-final-evidence-audit.json](/C:/Users/Kharki/Documents/Codex/2026-10-01/task-2/account-reliability/astra-final-evidence-audit.json); its read-only checker is [astra-final-evidence-audit.py](/C:/Users/Kharki/Documents/Codex/2026-10-01/task-2/account-reliability/astra-final-evidence-audit.py).

The original user bundle's public metadata is byte-identical before/after: 29,386 bytes, SHA-256 `f8cf3347e682d4d5c4bb554567e97346655e7f7758c5900c03e093eb0def7f93`. This is public metadata preservation evidence, not inspection or certification of private account/session data.

## Acceptance limits and historical failures

Acceptance covers this pinned-message ownership and same-account refresh/page ordering patch. It does not prove authenticated account switching, real TDLib transport ordering, actual Telegram delivery, provider/gallery I/O, complete Session bootstrap, every reply-hydration race, or all account/session operations. No real account/login/send action or secret/sessionstore read was needed. Native runtime results demonstrate the compiled controlled fixtures on the isolated bundle, with the fixture limits above.

Baseline and mutation RED logs are intentionally retained regression evidence. Initial build-permission, Bash PATH/dirname and directory-only install diagnostics are historical setup results, superseded by the successful exact builds, repaired process-PATH smoke runs and explicit two-HAP installation. They are neither hidden nor counted as acceptance passes. `harmonyos_docs` was unavailable; no new HarmonyOS API was introduced by this fix.

No further source change, runtime loop or broader refactor is recommended for this frozen scope. Project documentation prepared after this report and any later Desktop installation require their own correspondence checks; they are not included in this six-path code acceptance.

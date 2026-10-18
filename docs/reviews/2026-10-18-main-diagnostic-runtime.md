# Main diagnostic runtime - 2026-10-18

The authorized diagnostic main was built, installed and exercised on the existing emulator. Main reliability remains PARTIAL. The trace localizes substantial delay before response delivery to Ark, with repeated native capacity waiting. It does not establish a single root cause or justify another production fix.

## Build and isolated test gates

Official main and ohosTest Hvigor builds both completed with exit 0. The preserved main HAP is 87,450,512 bytes, SHA-256 3ef90f9555944f2054b4fd62a38a1b5e766a1692a775e231ae26c9e6fe3d2e17. The official ohosTest HAP is 18,368,702 bytes, SHA-256 ae4eeb006f16d396fe5b4d0986e15ab82ab2d952d87675f2db32cf56b71612db. Both are unsigned debug artifacts, not a signed release.

The separately installed isolated pair passed a native fixture with 120/120 request responses, FIFO delivery, actual Closed/join/finalizer and zero final ledger, followed by 75/75 nearby SDK tests in a separate fresh process. The fixture did not exercise native capacity waiting; the subsequent main traces did. These isolated passes do not establish authenticated main reliability.

Build provenance remains in ../candidate-evidence.json and ../official-diagnostic-v2-build-receipt.json. The candidate-evidence document is the historical pre-install checkpoint; this report records the subsequent authorized main installation. The five-file temporary diagnostic overlay was restored exactly after building. No further production code was changed, committed or pushed in this runtime stage.

## Installation and process identity

Source manifest 8a0a8ba3759c8e4962efded250af1f6b8ed971fde15fca75bb7fa6b5ba55e17e and accepted pre-install Astra review 8731988a52bfa93c840848afb717bde0bcc7850beff48597c234ba7c5660a63f were rechecked. One ordinary main-entry install -r succeeded. UID 20020062 and install/firstInstallTime 1788721575252 were preserved; updateTime became 1792298583713. No uninstall, data clear, login, account/key/security/network change or message sending occurred.

First PID 9355 and second PID 10050 each followed an absence-before-launch check. First immediate onCreate witness passed. The second immediate query found no match, but technical-second-early.json contains the actual post-launch onCreate, authorizationStateReady and getMe resolution. Warm resume retained each process PID. Final metadata matches the installed diagnostic package and PID 10050. That check preceded the final settled-history image by about six seconds. No installed-device byte readback or retirement proof is claimed.

The first stream retained 3,226 numeric records (419 native / 2,807 Ark), 14 selected requests and four timeout tokens with coherent observed prefixes. The second retained 3,456 records (303 native / 3,153 Ark), 14 selected requests and ten timeout tokens. Both second-run domains emit window_end at their 120-second bound. Its status remains PARTIAL_TRACE and conservative request correlation remains UNKNOWN. Separate processes and unequal workloads are not a controlled performance comparison; these are bounded observed counts.

## Proved first-process boundary

| Request ordinal / method | Native send to response copy | Union of capacity waits within that interval | Ark timeout to selected batch admission |
| --- | ---: | ---: | ---: |
| 3 / loadChats | 20.298 s | 17.802 s (87.71%) | 5.383 s |
| 6 / getChat | 21.125 s | 19.406 s (91.87%) | 5.774 s |
| 7 / loadChats | 34.847 s | 32.413 s (93.02%) | 19.868 s |
| 8 / setOption | 39.085 s | 36.530 s (93.46%) | 9.019 s |

All four responses eventually dispatch as stale after the original timeout and Promise rejection. Selected batch admission itself occurs after the deadline, so its later admission-to-dispatch residence cannot alone explain that failure. Slow consumption of preceding batches can still retain credits and delay later reads.

All 53 native capacity waits begin with four outstanding batches. Ledger reconstruction matches every count and byte total and ends at zero within the observed prefix. Peak occupancy is four batches / 5,191,079 bytes, below 16 MiB. At 48 wait starts, three batches are Ark-admitted and one remains native-queued; outstanding does not mean already admitted.

Capacity intervals are clipped and unioned within each request's native-clock interval. Concurrent requests share waits; table rows cannot be added. Outside-capacity time is 1.719-2.555 seconds per request and remains unclassified. TDLib internal response-ready timing is unobserved: send-to-copy duration is not network or server latency. Native and Ark absolute clocks are never aligned or subtracted.

The first trace has 725 drain pairs. Requested delay median/p95/max is 20/148/250 ms; actual residence is 26/261/2968 ms and positive overshoot is 3/151/2934 ms. Requested delay totals 26.294 seconds, recorded residence 49.816 seconds, positive overshoot 23.542 seconds, with 20 ms undershoot. These are descriptive wall-time spans, not idle-time or CPU attribution. Synchronous slice elapsed totals 18.066 seconds. Of 91 complete store groups, measured reducer/invariant/notification components total 6.815/1.074/1.058 seconds; invariants are not the largest measured component. Timer, queue and store measurements overlap and cannot be added as independent total elapsed time.

## Second-run coverage and UI results

The second trace retains both terminal markers and all missing stages. Four early timeout requests have witnessed late receive/admission/dispatch pairs. Six additional timeout requests lack receive/dispatch before cutoff, and two later requests lack a settled outcome. Those outcomes remain UNKNOWN. The independent partial analysis excludes an unfinished capacity wait instead of inventing its end. Technical log snapshots overlap and are not added to numeric timeout counts.

Both processes displayed existing chat lists and populated profiles without reauthentication. getMe, Back and same-PID Home/resume have separate technical/UI witnesses. First existing history rendered. In the second process, initial history remained loading and later showed an empty state after same-PID warm resume; an openChat timeout is separately recorded. One later ordinary reopening displayed existing messages. PASS_AFTER_REOPEN does not erase the initial FAIL or establish smoothness. Exact visual causality is not proved. Private screenshots were inspected only by the operator; shared reports contain no account identity or message content.

## Unknown boundary and review

The unresolved boundary is why consumer progress is too slow: requested pacing, synchronous parsing/dispatch/store/listener/render work, scheduler contention and synchronous logging are not independently partitioned. TDLib response-ready timing is also unknown. Logging under native locks and the trace mutex can perturb behavior; no matched equal-work trace-off control measures observer cost. These timings cannot automatically be assigned to the earlier uninstrumented failures.

Astra independently replayed both frozen analyzers and verified the first capacity calculations. Final review accepts bounded diagnostic localization and retains PARTIAL main reliability. No additional production correction is justified. Deadlines, FIFO, consumed ACK, four-batch / 16 MiB capacity, ownership and no-uncertain-replay policies remain unchanged. Any later fixed main replacement needs its concrete reviewed candidate reported first; none is proposed here. harmonyos_docs was unavailable; local SDK, TDLib contract and source evidence were used.

## Evidence

Evidence directory: C:\Users\Kharki\Documents\Codex\2026-10-13\task-2\remaining-timeout-diagnostics-2026-10-18\main-runtime.

- Installation: preflight.json, replace-receipt.json, after-update.json, final-device.json.
- Separate processes: capture-session-first.json, capture-session-second-cold.json, first.trace.json, second-cold.trace.json.
- Analysis: first-main-analysis.md/json, second-cold-main-analysis.md/json, cost-analysis-manifest.json.
- Functional witnesses: ui-observations.json, technical-second-early.json, technical-second-final.json, technical-second-reopen.json.
- Independent review: astra-main-diagnostic-review.md, SHA-256 9bef5a8c74524b7bcdcaf32f48c536e5840456f24ff53fa0d0d21fdb2ce9cfc8.
- Host controls: 22 snapshot collector, 12 streaming collector, seven interval-union and eight partial-analysis checks passed. Earlier build and isolated gates remain in the parent evidence directory.

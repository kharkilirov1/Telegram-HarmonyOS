# Bounded timeout diagnostics - 2026-10-18

This document records the pre-installation build/isolated checkpoint. The user later approved exact diagnostic main3ef90f95; installation and two authenticated process traces are recorded in [the subsequent runtime report](2026-10-18-main-diagnostic-runtime.md). The historical not-installed/approval-pending statements below are retained with that earlier scope.

The six remaining authenticated-main request timeouts are not causally explained or fixed. This checkpoint provides a reviewed diagnostic candidate and successful SDK/native verification. The earlier bounded receive scheduling correction remains in the local source checkout; diagnostics were a temporary five-file build overlay and were restored afterward. No commit/push, diagnostic-main installation, account/data reset or outgoing message occurred here.

## Artifacts and provenance

Official main and ohosTest were built successfully with the installed SDK/Hvigor in the original checkout, against dev@08531936bcfe5fcc290dcacdc43beea66e187d03 plus the accepted local receive correction. The five diagnostic sources match the isolated projection exactly. Before/after official build941 public inputs match; all939 original public inputs match after restoration. Private configuration and credentials were excluded from inspection/fingerprints.

| Preserved artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| Official diagnostic main |87450512|3ef90f9555944f2054b4fd62a38a1b5e766a1692a775e231ae26c9e6fe3d2e17|
| Official diagnostic ohosTest |18368702|ae4eeb006f16d396fe5b4d0986e15ab82ab2d952d87675f2db32cf56b71612db|
| Isolated main |90687559|497dcc5e4e211fa66b2b9df36480b002c70f6515bb3fc038c41154165d8e125f|
| Isolated ohosTest |18374389|367ce4bf428c1fcf42bd43c5f2fbf41b90a87e7f4abcb3f140fd6420fa046b95|

These are unsigned debug HAPs. Exact manifests and native x86_64 diagnostic packaging were checked. The isolated pair was installed together into com.telegram.harmonyos.nativevalidation20261014. Main com.telegram.harmonyos remained on its prior accepted e32101bd package: UID20020062, install/first-install1788721575252, update1792293000059 and PID15597 unchanged. Technical metadata is not a new UI/session-content assertion.

## Verification

Fresh isolated PID31591 passed ReceiveTraceNative1/1:120 getOption(version) responses, zero rejected, FIFO1-120,120 artificial8ms consumer workloads totaling1034ms. Direct Closed, producer join and TSFN finalizer witnesses passed; final credits/notifications were zero. Peak credits were3 batches/10361bytes. The independent analyzer accepted1740 records (506 native/1234 Ark) without gaps or generation/epoch/batch/index disagreement. A separate fresh PID32433 passed TdGateway/GatewayErrorPropagation/NativeReceiveFlow75/75. This is the named focused set, not a new full-suite run.

Host checks passed: native parser/registry/concurrency/failure34, helper/store11, actual gateway regressions15, isolated analyzer negative controls15, main collector synthetic/fake-device22. The main collector also accepted the saved isolated native grammar offline (121 correlated requests including close); it performed no actual main capture. Failed isolated v1/v2 SDK builds remain preserved: static-this incompatibility and an explicit native-result type annotation were repaired before successful v3.

## Limits and next gate

Trace records contain only fixed stages, locally generated bounded request ordinals, method codes, epoch/batch/index/count/time. Registry128, window120s and record caps bound observations; payloads, account/chat/message identifiers, credentials and error text are excluded. Native and Ark clock durations are never subtracted across domains. Deadlines, FIFO,4-batch/16MiB credits and no-uncertain-replay policies are unchanged.

Astra accepted the diagnostic candidate with explicit UNKNOWN gates. No matched trace-off/on control establishes observer overhead: synchronous HiLog, existing native locks, the trace mutex, clocks and Promise observers can shift timing or contribute to a log-storm/AppFreeze condition. This run had no capacity-wait markers and no real AppStore workload, so those runtime branches remain unproved. Synthetic workload measurements cannot explain the historical six timeouts or establish UI smoothness.

The next action needs the separately required concrete main replacement authorization: install only the exact official main above over the existing bundle, preserve data, and observe two fresh launches with existing authorization/getMe/profile/chat list/history, Back and background/resume while collecting only validated numeric diagnostic records. Artifact/fresh-launch receipts are separate from the collector. If instrumentation can itself explain a delay, causality remains unknown until controlled evidence resolves it. No further timeout fix is proposed at this checkpoint.

Evidence root: C:\Users\Kharki\Documents\Codex\2026-10-13\task-2\remaining-timeout-diagnostics-2026-10-18. Start with candidate-evidence.json, astra-final-review.md, trace-protocol.md, draft-v2/manifest.json, isolated-v3-manifest.json, build/install receipts, isolated-v3-trace-run1-trace-analysis.json, isolated-v3-nearby-run1-command.log and main-before/after-diagnostics.json. The bounded main collector and its contract are collect-main-trace.cjs and main-trace-collector.md. Cleanup execution remains in the preceding main-acceptance evidence root and report.

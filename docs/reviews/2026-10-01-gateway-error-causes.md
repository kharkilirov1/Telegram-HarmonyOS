# Precise gateway error causes - 2026-10-01

The bounded read path now retains the existing AppError kind, TDLib code, retryable flag and technical detail. Formerly the adapter converted every typed rejection to CONNECTION_FAILED; history wrapped it again as NETWORK/0/retryable. That hid loadChats404 exhaustion and let AUTH/rate-limit failures enter ordinary initial-history retry. Friendly and technical messages remain separate.

Current terminal/auth/rate-limit history errors retire correction intent and cancel an already scheduled timer, including snapshots arriving after the error. Both UI continuations validate the existing Domain lifecycle/window/bucket sequence identity. An older callback cannot cancel a newer same-route correction even when the newer request has completed; skipped execution cannot borrow another reservation. No new state owner/counter, transport lifecycle or runtime reference import was introduced.

| Product file |
| --- |
| `entry/src/main/ets/domain/ports/TdGatewayPort.ets` |
| `entry/src/main/ets/infra/td/adapter/TdGatewayAdapter.ets` |
| `entry/src/main/ets/domain/usecases/loadChats.ets` |
| `entry/src/main/ets/domain/usecases/loadChatHistory.ets` |
| `entry/src/main/ets/ui/pages/chat/ChatInitialHistoryCoordinator.ets` |

| Gate | Result |
| --- | --- |
| Identical correct regression callbacks | Baseline44 AssertionError RED; v1 late-correction/ownership7 RED; final73/73 (60 actual ETS callbacks +13 actual host pipeline cases) |
| Behavioral mutation controls | All14 mutants detected through assertions; no loader/TypeError acceptance |
| Host and structural checks | Full host68/68; decomposition22/22; PS/Bash smoke PASS |
| Forced serial official SDK | Main28 s 489 ms [39m; ohosTest35 s 18 ms [39m; both BUILD SUCCESSFUL |
| Native isolated bundle | New60/60, focused76/76, full984/984; zero failure/error/ignore; unique matching starts/completions and subset inclusion |
| Immutable correspondence | 11 frozen code hashes, 7 SDK source matches, both frozen HAP hashes verified after all native runs |
| Independent review | [Astra xhigh final review](2026-10-01-gateway-error-causes-chief-review.md) |

Native callbacks execute real error/port/read-usecase/AppStore/reducer/route/scope/lease/coordinator code with controlled read transport and test-owned timers. Host cases separately execute actual TdGateway.send, JSON response/classifier, timeout, serializer and adapter with explicit native/readiness/bootstrap/timer fixtures. Successful history controls observe actual Domain completion. An earlier auxiliary probe omitted users.users and swallowed a TypeError as NETWORK; that fixture/witness was retained as superseded and corrected before acceptance. Official SDK execution is separate evidence from Node projection.

Existing stale-client/request/scope/route/lease guards remain first. Positive controls preserve untyped legacy wrapping, retryable network timeout and warm-up behavior, valid success/unread correction, loadChats updates/cursors and older/newer history ownership. The original user's bundle public metadata is byte-identical before/after; it was neither installed nor stopped.

Grounding: local TDLib schema defines numeric error/message and loadChats404 exhaustion; current iOS MTRpcError retains code/description. harmonyos_docs was unavailable; no new platform API was introduced. TDLib406's no-processing/display rule is acknowledged as a separate existing policy concern; no classifier, raw technical UI or logging policy change is claimed.

Main frozen HAP SHA256: `75662b1cc49dc0899f08ca78e8e5cc5a98e399da755bc7da19a5cf677986f878`. Test frozen HAP SHA256: `5a7b988f3f194ab684005191ba8415e00953c56bbcbbc2f9cc7334f8a47ca2da`. Only `com.telegram.harmonyos.chatrefactor20261001` was updated using both explicit frozen HAP paths. Build/test provenance and reviewer hashes are in [structured evidence](2026-10-01-gateway-error-causes-evidence.json); workspace receipts live under `C:/Users/Kharki/Documents/Codex/2026-10-01/task-2/gateway-errors`.

This accepts this read-path regression slice. sendMessage/forwardMessages still need a separate bounded stage preserving unknown-outcome/duplicate/restoration semantics; TDLib406 policy, authenticated behavior, Telegram delivery, native transport lifetime and current iOS visual acceptance remain unproved. Next agreed work: targeted list updates with position/smoothness checks, then later typed video/mixed media stages. No dependencies installed, real account/network actions, commit, staging, push, PR or merge.

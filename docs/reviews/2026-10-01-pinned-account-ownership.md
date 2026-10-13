# Pinned account/session ownership - 2026-10-01

The bounded fix keeps pinned initial search, single fallback and pagination on the captured route gateway. Existing route/account/lease ownership is checked before dispatch and on every success/error completion. A late callback cannot acquire a replacement global gateway or publish into a retired owner. Refresh invalidates the old page/cursor, and page completion also matches the summary snapshot from which it began.

Two product files changed: `entry/src/main/ets/domain/usecases/loadPinnedMessage.ets` and `entry/src/main/ets/ui/pages/chat/ChatPinnedMessagesCoordinator.ets`. There is no new state owner, Session interface, transport lifecycle, parser rewrite or reference runtime import. The existing four non-product changes add focused SDK/host tests, register the suite, and align one static source contract with captured fallback dispatch.

R1 is a coordinator/API fixture ownership gap: revoked A can formerly obtain B's global gateway when A's old initial callback rejects or resolves empty. Existing adapter/runtime fences and serialized teardown remain intact; normal authenticated device reachability or data leakage is not proved. R2 is ordinary same-account ordering: an old page can append to a refreshed list or reset newer loading state. Both have same-assertion baseline RED and candidate GREEN.

| Gate | Evidence |
| --- | --- |
| Identical regression callbacks | Baseline47 AssertionError RED +14 positive controls; candidate61/61 (58 actual ETS callbacks +3 actual Session/Context/route predicate checks) |
| Behavioral mutation controls | All five mutants detected through assertions; no loader/TypeError failures |
| Independent source probe | Candidate23/23; baseline18 behavioral RED +one missing-new-API assertion |
| Existing host and structural checks | Host67/67; decomposition22/22; pinned panel/navigation static contracts; PS/Bash smoke PASS |
| Forced serial SDK builds | Main46.155s, ohosTest25.056s; both BUILD SUCCESSFUL |
| Native isolated bundle | New58/58, focused64/64 (six retained LoadPinnedMessage cases), full924/924; zero failure/error/ignore; unique matching starts/completions and subset inclusion |
| Immutable correspondence | Six candidate code hashes, four entry-source SDK matches and two frozen HAP hashes rechecked after native runs; original user bundle public metadata byte-identical |
| Independent review | [Astra xhigh final review](2026-10-01-pinned-account-ownership-chief-review.md) |

Native tests execute actual coordinator/usecase/parser/AppStore/RouteParams/Lease with controlled transport/current-store predicate fixture. They do not mount actual Session/V2 models; three host integration checks separately execute the actual Session/Context/route predicate. No constructor/bootstrap or authenticated account ordering is claimed. No original bundle install/stop, login, real send, account data inspection or provider test occurred.

Grounding: local TDLib schema preserves `getChatPinnedMessage -> Message` and pinned search native cursor; current iOS source carries explicit `Account`; Petrelgram session epochs/serialized switches are behavioral comparisons under its pinned revision. `harmonyos_docs` was unavailable; installed SDK/compiler/CLI were used and no new platform API was introduced.

Main frozen HAP SHA256: `9b67962410074f8479b9c46198f9063f9dee3b1d6d93a75c156971753a0285b7`. Test frozen HAP SHA256: `f3540e8ae3fb80cef8b7c373ed954f02bd6a8f074a3bbc3d2bc22803e09f8020`. Only isolated bundle `com.telegram.harmonyos.chatrefactor20261001` was installed, using both explicit HAP paths. The first directory install emitted a single directory-level success and failed the evidence parser; the subsequent explicit multi-HAP install provides both package successes. Initial Bash missing-`dirname` and compiler-cache permission failures are retained as setup history; corrected process PATH/approved official SDK cache access passed without source changes or dependency installation.

[Structured evidence](2026-10-01-pinned-account-ownership-evidence.json) records source, HAP, test log and reviewer hashes. Source/workspace receipts are under `C:/Users/Kharki/Documents/Codex/2026-10-01/task-2/account-reliability`. This evidence accepts the bounded ownership regression, not all account/session reliability, native lifetime, Telegram delivery or current iOS visual parity. Next agreed priorities are precise gateway error causes, then targeted list updates with position/smoothness checks. No commit, staging, push, PR or merge is part of this stage.

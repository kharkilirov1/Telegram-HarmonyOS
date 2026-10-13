# Targeted chat timeline updates - 2026-10-01

An ordered middle insertion/deletion previously reloaded the List; the sampled prepend fallback also confused the absolute message anchor index with the added-row count. For `[date,A,B] -> [date,X,A,B]` it produced a duplicated B tail. The same registered correct expectations fail on source preimages and pass on this bounded candidate.

Two production files now reconcile unique stable identities while retaining stamped render keys, exact content updates and surviving rows. The new path deletes absent rows descending, inserts new rows at their target indices and emits change only for existing comparator differences. Each new-path notification observes its completed mutation. Existing same-order/append/trim/pure-prepend fast paths and comparator remain byte-identical. Ambiguous/empty/foreign-owner keys, retained reorder and no common stable identity retain safe reload; a retained date marker alone can permit targeted replacement, without a surviving-message-anchor claim.

The coordinator captures the visible stable identity and prefix, then guards native callbacks after above-anchor insert/delete/net-zero edits, even when that row is rekeyed. Formerly deletion shifted index 26 to24 after the synchronous guard ended and caused an extra loadOlder; ordinary user gestures can still unlock and paginate. Append follow captures the pre-update END-based bottom intent; its existing lifecycle-owned callback respects newer visible-range movement, including one-row upward movement, and retains large/tall/short/repeated append controls. No new Context field, global owner, timer registry or build dependency was added.

| Product path | Final SHA256 |
| --- | --- |
| `entry/src/main/ets/ui/pages/chat/ChatTimelineDataSource.ets` | `f6939377f76c5a025963f8b4e8355cb88ee66e4ec86bbfb5473e54ba9ec1b16f` |
| `entry/src/main/ets/ui/pages/chat/ChatTimelineTransactionCoordinator.ets` | `4ce76fc88738c19bd2f782bb11787b166ae14f378e629f2e84b82bb47cbac85d` |

| Gate | Result |
| --- | --- |
| Same expected-correct host callbacks | Original 22 AssertionRED / 20 controls; final 42/42 (32 registered ETS callbacks +10 actual-scheduler host cases) |
| Behavioral mutants | All 18 fail assertions; loader/TypeError failures are rejected |
| Independent source review | 115 DataSource, 9 append and 12 anchor checks PASS |
| Host/structure | Full host 69/69, decomposition 22/22, PS/Bash smoke PASS |
| Forced serial official SDK | Main 28 s 570 ms ; ohosTest 23 s 220 ms ; both BUILD SUCCESSFUL |
| Native isolated bundle | 35/35 new cases, 1019/1019 full; zero failure/error/ignore, unique aligned starts/completions, subset inclusion |
| Native UI | Real List/LazyForEach/Scroller, maintained insert/delete/rekey/repeat rectangles, delayed threshold event, real swipe update, large append follow and isolated remount |
| Final review | [Independent Astra xhigh](2026-10-01-chat-timeline-updates-chief-review.md) |

Measured msg400 stays at screenTop 262/itemY 0 across fourteen retained-anchor phases while indices alternate 40/41; msg260 stays at screenTop 262 after26->24 deletion, with a generated post-diff index 24 event and no unsolicited load intent. The real swipe deliberately moves the viewport and updates the stamped text; it is not claimed to hold unchanged screen coordinates during a user's gesture. After explicit bottom setup and twenty added rows, msg1100 is visible at the native end. The before screenshot shows msg400; the final screenshot shows the appended tail, so they are different flow states rather than a matched anchor image pair. Raw per-phase measurements prove retention.

Rows are synthetic simple V2 text cells, including one varying height. Actual production DataSource/projection/Transaction/Viewport/index handlers run; pagination ports record intents without a gateway. No Session/bootstrap/accounts or production bubbles are mounted. Remount fences belong to the isolated fixture; real Session ownership has its prior separate acceptance. This does not prove every unchanged-index/subpixel/finger interruption, visible-height edit, deleted anchor or arbitrary reset/reorder position. No native FPS benchmark or current iOS pixel parity is claimed.

The work-count probe confirms one notification for one insert/delete/change, three for a mixed edit and zero reload on 100/1000-row windows. Array.splice still moves O(n) items per structural edit; host timings are not native frame-rate measurements. SDK list.d.ts:2112-2134 documents outside-viewport LazyForEach position retention, excludes reload and describes resulting index/scroll events. Pinned iOS ListView/history transactions informed the separate insert/delete/update and stationary-anchor approach; no third-party code/assets were copied. harmonyos_docs was unavailable.

The failed first test build is retained as `sdk-test-build-v1-failed.log`: ArkTS constructor parameter properties and string-to-kind typing in the new fixture were corrected using explicit fields and the actual union, preserving/strengthening assertions. Source hashes, both frozen HAPs, screenshots and reports are in [structured evidence](2026-10-01-chat-timeline-updates-evidence.json), under `C:/Users/Kharki/Documents/Codex/2026-10-01/task-2/list-updates`. The original user bundle public metadata is unchanged; only the separate dummy bundle was installed with both HAPs. Main HAP SHA256 `45dc256d42e87b995f13c57c686c56a9388517e8fa93899e6ceb71f4f0644e84`; test `50604a941bf3c6146d51516ea729c577a784349060b68abce535a13fdd9c8655`.

Local readiness across the completed stages and remaining QA is in [consolidated readiness](2026-10-01-local-readiness.md). sendMessage/forwardMessages cause/unknown-outcome handling and TDLib406 logging/display policy remain distinct unfinished boundaries. No real sends, account/session-store reads, dependencies, commit/staging/push/PR/merge or security actions were performed. This finishes the selected list-update slice; no subsequent implementation starts automatically.

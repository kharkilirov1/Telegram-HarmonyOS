# Independent chief review — targeted timeline updates

**FINAL ACCEPTED — frozen candidate, within the bounded scope below.** No outstanding P1/P2 defect found. Project documentation and guarded installation remain separate pending steps; this report does not assert that the candidate is installed in the Desktop checkout.

Reviewer selection is explicitly `gpt-6-astra`, `xhigh`. This records the selected agent configuration, not an attestation of a hidden serving backend. The reviewer performed independent source analysis, host probes, receipt parsing, file/HAP comparisons and original screenshot inspection. No product/test/project-document/Desktop/index edits, SDK builds, device operations or account actions were performed by the reviewer.

## Accepted source and identity

The [final code manifest](/C:/Users/Kharki/Documents/Codex/2026-10-01/task-2/list-updates/feature-manifest-code-final.json), SHA-256 `8937021bbcd2cbd56f6b4fbff961c0937a29a04fb953c2545aaf4815558f9521`, contains exactly two product changes and nine test/fixture/runner paths. All 11 final hashes and lengths match, the four existing paths match their captured preimages, and the seven new paths are absent from the baseline. All ten ETS paths match the actual isolated SDK tree after the native runs.

| Product | Final SHA-256 |
| --- | --- |
| ChatTimelineDataSource.ets | `f6939377f76c5a025963f8b4e8355cb88ee66e4ec86bbfb5473e54ba9ec1b16f` |
| ChatTimelineTransactionCoordinator.ets | `4ce76fc88738c19bd2f782bb11787b166ae14f378e629f2e84b82bb47cbac85d` |

The [source review](/C:/Users/Kharki/Documents/Codex/2026-10-01/task-2/list-updates/astra-source-review.md) remains applicable. DataSource validates stable/render identity and retained order before targeted mutations, preserves existing safe fast paths, deletes absent rows in descending order, inserts/replaces in target order and publishes coherent intermediate state in the new reconciliation path. Retained anchors are not removed and reinserted. Ambiguous keys, foreign render-key ownership, retained-key reorder and zero common stable keys fall back to reload. A common date row alone intentionally permits targeted replacement; this is not a promise that every message-disjoint reset reloads or preserves an absent message anchor.

Transaction compares the retained visible anchor's stable prefix, including net-zero replacements, to arm the existing pagination guard. Append following captures the pre-diff visible-end policy and rejects subsequent start/end movement backward before considering remaining bottom intent. It handles large appends and repeated scheduled updates without introducing another state owner, counter, port or global registry. Existing lifecycle/timer-membership fences remain in force.

## Regression and build evidence

The [host evidence review](/C:/Users/Kharki/Documents/Codex/2026-10-01/task-2/list-updates/astra-test-evidence-review.md) and [independent host audit](/C:/Users/Kharki/Documents/Codex/2026-10-01/task-2/list-updates/astra-test-evidence-audit.json) verify the exact final 42 callbacks: 32 actual registered SDK callbacks plus ten additional actual transaction/lifecycle-scheduler witnesses. The independent final run is 42/42 PASS and matches the supplied ordered results and captured source map. The same callbacks against original product preimages give 22 `AssertionError` failures and 20 controls. All 18 behavioral mutants fail assertions; missing APIs, TypeErrors and parser failures are not accepted as regression evidence. Both existing integration files contain additions only.

Separate independent source probes passed 115 DataSource cases and nine append cases on the final product hashes. The reviewed author-owned anchor probe was independently rerun with 12/12 PASS; it is not presented as independently authored. These probes cover identity ambiguity, notification replay, shifted indices, retained-prefix guards, large/short/tall viewports, newer movement, repeated appends and lifecycle retirement within their recorded boundaries.

Official forced main/test builds succeeded in 28.570 s and 23.220 s respectively. Decomposition is 22/22; PowerShell and Bash smoke logs pass. The aggregate host log is 69/69, but it predates the final fixture-only ArkTS corrections. It is not an exact-final all-file run: the exact final 42-case host run, SDK test build and both native runs bind the final fixtures. The planned post-install 69-suite run remains a later installation check.

## Native runtime and visible behavior

The [independent final audit](/C:/Users/Kharki/Documents/Codex/2026-10-01/task-2/list-updates/astra-final-evidence-audit.json), produced by the [reviewer audit script](/C:/Users/Kharki/Documents/Codex/2026-10-01/task-2/list-updates/astra-final-evidence-audit.py), reparses raw logs rather than trusting aggregate PASS fields. It confirms **35/35** in the focused list run and **1019/1019** in the full run, each with zero failures/errors/ignores, unique aligned case starts/completions, contiguous case indices, one valid summary and successful finish markers. All 35 cases occur in the full run; the 32 pure native callback names match the host callbacks. All three native UI callbacks actually execute in both runs.

I independently compared both frozen HAPs with build outputs, inspected their ZIP module manifests and compiled markers, and verified the explicit two-file installation log. Both use only `com.telegram.harmonyos.chatrefactor20261001`; modules are `entry` and `entry_test`.

| Artifact | SHA-256 |
| --- | --- |
| Main HAP | `45dc256d42e87b995f13c57c686c56a9388517e8fa93899e6ceb71f4f0644e84` |
| Test HAP | `50604a941bf3c6146d51516ea729c577a784349060b68abce535a13fdd9c8655` |
| Final runtime receipt | `64401a88034ee723d81fe7e0226f825efbf275a425b366ff651fa92374655294` |

Both sets of original UI artifacts and capture hashes were verified. In each run, the first 14 anchor records retain `msg_400` at the same screen top/bottom and Scroller Y: maximum displacement **0 px / 0 vp** through insertions, deletion of a taller row above, visible edits, stamped text refresh, identical repeat and repeated cycles. Indices/counts change as expected. Measurement does not scroll to repair a failed anchor.

The pagination scenario retains `msg_260` at the same pixels as its index changes **26→24**, and records a genuine subsequent native index event with `applying=false`; older/newer load intents remain zero. The passing native assertions additionally require a later real user drag to unlock ordinary pagination. The active-drag update moves the viewport by 185 px / 183 px in the two runs, retains the updated visible message and does not invoke bottom following. The large append ends on `msg_1100`, index 102 of 103, aligned to the list bottom. Its `newerCalls=1` is an ordinary explicit bottom-edge intent; no global zero-pagination claim is made.

I viewed all four original PNGs individually: [focused before](/C:/Users/Kharki/Documents/Codex/2026-10-01/task-2/list-updates/native-ui-list/timeline-update-before.png), [focused after](/C:/Users/Kharki/Documents/Codex/2026-10-01/task-2/list-updates/native-ui-list/timeline-update-after.png), [full before](/C:/Users/Kharki/Documents/Codex/2026-10-01/task-2/list-updates/native-ui-full/timeline-update-before.png), [full after](/C:/Users/Kharki/Documents/Codex/2026-10-01/task-2/list-updates/native-ui-full/timeline-update-after.png). Text is readable and the synthetic/no-account header is visible. Before images begin at `timeline:400:v0`; after images show the appended tail through `timeline:1100:v0`. These are different flow states, not a matched anchor screenshot pair. Raw measured rectangles establish retention; the after image establishes the recorded final tail view.

## Preservation and limits

The original user bundle's before/after public metadata files are byte-identical: 29,386 bytes, SHA-256 `f8cf3347e682d4d5c4bb554567e97346655e7f7758c5900c03e093eb0def7f93`. Independent read-only rehashing also confirms all 1036 captured public Desktop files, 386 status entries, HEAD, Git index and cached diff remain unchanged before installation. Only explicitly captured public files were checked; credentials/session stores were excluded.

This accepts actual List/LazyForEach/Scroller behavior with production timeline owners and simple synthetic V2 rows. It does not certify authenticated ChatPage/Session execution, production bubble/media geometry, real delivery/provider IO, iOS pixel parity or FPS. Fixture remount proves its isolated boundary; actual production lifecycle scheduling is separately exercised by host witnesses. Same-index subpixel movement and finger-only interruption are not universally detected. Deleted anchors, arbitrary reorder/disjoint resets and visible-row height changes do not have a universal position-preservation guarantee. Send/forward error handling and TDLib 406 remain separate follow-ups; this stage does not resolve them.

All earlier source HOLDs, intermediate RED results and the initial fixture-type build failure are historical and superseded only by the exact successful evidence above. No broader release-readiness or completion of all prior QA boundaries is inferred. Within this bounded stage, the source, regression, SDK/native UI and preservation gates are satisfied; documentation and guarded installation may proceed under the parent's authorization.

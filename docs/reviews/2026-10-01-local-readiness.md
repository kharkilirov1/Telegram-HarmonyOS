# Local readiness after completed stages - 2026-10-01

**Successor accepted locally on 2026-10-02:** the bounded application send/forward and TDLib406 slice is complete; host70/70, native68/68 + full1087/1087, serial builds, smokes and independent gpt-6-astra xhigh acceptance. [Current report](2026-10-02-send-forward-errors.md) records exact scope and limits. The text below retains the preceding stages and their historical evidence.

The accepted local implementation is ready for choosing the next bounded development/QA slice. The current cumulative check is host 69/69 and native 1019/1019 in an isolated dummy-credential bundle, with serial main/test builds, smoke and independent Astra xhigh review. This is local regression readiness; authenticated delivery, provider grants, production UI/iOS parity and release readiness remain separate.

Per-stage counts below describe their accepted historical receipts, rather than reruns of every old frozen HAP. The latest full suite includes the prior regression cases; source/HAP identity for the current list slice is recorded in [list evidence](2026-10-01-chat-timeline-updates-evidence.json). All local changes remain uncommitted on dev; user's pre-existing changes are preserved with guarded before-images. No push/PR/merge occurred.

| Completed stage | Local result and evidence | Accepted checks / remaining boundary |
| --- | --- | --- |
| Petrelgram reference | Separate pinned external tree; [reference index](../../REFERENCES.md) | Reference only; no runtime/dependency integration |
| Chat decomposition | Page 5730->164, Session/read-only V2 slices/narrow owners; [report](2026-10-01-chat-screen-decomposition.md) | Host 63, decomposition 22, native 806; authenticated screen/iOS matrix unproved |
| Photo album sending | 2-10 ordered photos, one album request, captured ownership/validation/explicit repeat confirmation; [report](2026-10-01-photo-album-sending.md) | Host 65, native 856; real provider/Telegram delivery unproved |
| Photo preview | 1-10 preview/thumbs, remove/reorder by URI, caption/reply/busy/picker ownership; [report](2026-10-01-photo-selection-preview.md) | Host 66, native 866, synthetic image UI; real grants/full production Dock/iOS parity unproved |
| Pinned account/session | Captured original owner and retired refresh/page leases; [report](2026-10-01-pinned-account-ownership.md) | Host 67, native 924; R1 authenticated reachability/leak not proved, ordinary refresh ordering covered |
| Gateway read errors | Typed cause/code/retry/detail and owned terminal history correction; [report](2026-10-01-gateway-error-causes.md) | Host 68, native 984; send/forward and 406 explicitly excluded |
| Targeted list updates | Ordered row reconciliation and stable-prefix/append intent guards; [report](2026-10-01-chat-timeline-updates.md) | Host 69, 42 focused, 18 mutants, native 1019; synthetic geometry/real gesture covered, production bubble/account matrix unproved |

Two distinct boundaries were open at this 2026-10-01 snapshot and motivated the accepted 2026-10-02 slice:

1. `sendMessage`/`forwardMessages` error causes and unknown outcome: retry, restore and duplicate policy need a separate reproduced slice. Read-path typed-cause acceptance does not close this write-path boundary.
2. TDLib406: no-processing/display semantics and raw logging policy remain a separate bounded concern. No classifier/logging/UI policy change is claimed here.

Before claiming real product/release readiness, QA still needs authenticated login/reconnect/account switch/resume/history and actual Telegram send/receive/delivery; real picker/provider URI grants/storage/permissions; production ComposerDock/chat bubbles/media/IME/safe-area state matrix and current shipped-iOS witness; and full native TDLib environment/opaque-handle/slow-consumer lifetime behavior. Existing host/source contracts do not substitute for those observations.

For timeline follow-up, prioritize production bubble/media height changes, deleted-anchor policy, arbitrary reorder/reset and same-index/subpixel/finger interruption if needed. The native proof deliberately uses equivalent simple-row geometry and recorded scroll owners. Host work counts are not native FPS. Typed video receive/render/gallery and mixed photo/video albums are later feature slices.

The successor closes typed send/forward causes, owned text/forward/photo behavior and application TDLib406 message handling. Sequential document/video ownership is now accepted by the later report below; upstream packaged TDLib logging and authenticated/provider/production-UI QA remain separate. No additional feature stage is started by this report. `harmonyos_docs` was unavailable; local pinned sources and installed official SDK contracts grounded this slice.

## Later bounded result - document/video resend - 2026-10-02

Sequential document/video now retires each accepted URI before progressing. Partial failures preserve only the unsent/uncertain tail; first-item caption/reply/entities/caret are consumed once. Repeating an uncertain URI uses localized native Cancel/Send again and revalidates the existing owner/input. Late document/camera picker results and forward enter/cancel ABA cannot revive old intent. Same callbacks: baseline 28 controls PASS/113 assertion RED, candidate 141/141; host 71/71; native focused 47/47, full 1134/1134. Serial official main/test SDK builds, decomposition and PS/Bash smoke PASS; independent actual gpt-6-astra xhigh acceptance. Real provider/camera/delivery, production Dock/current shipped-iOS acceptance and packaged TDLib logs remain open. Report: `docs/reviews/2026-10-02-document-video-resend.md`.

The authoritative timed slow-mode slice was subsequently completed; see `2026-10-02-slow-mode.md`. Separate pending-outgoing presentation remains open.

## Later completed timed slow mode - 2026-10-03

Authoritative timed slow-mode countdown and fresh send/normal-attach gates are completed and independently accepted. Draft/reply/entities/caret/selections and stopped voice preview survive cooldown; expiry never sends. Account/chat/route ownership, stale FullInfo hydration and accepted-prefix cleanup remain guarded. Host76/76; same-callback baseline RED and candidate53+10 GREEN;14/14 activated feature negative controls plus2/2 scheduling controls; decomposition22/22; sequential141/141 and write-path84/84; PS/Bash smoke; official main/test SDK builds; fresh-process native final light43/43 and full1177/1177 PASS, with byte-identical UI source dark43/43 and related dark UI19/19 PASS. Actual requested gpt-6-astra xhigh chief accepted the final frozen sources and evidence. Installation and installed verification are established separately by the linked workspace receipts when present; candidate acceptance alone does not establish installation.

Native UI uses actual Dock/atom/Session/scoped store and dialogs with synthetic transport. This establishes local main-module Resource rendering and light/dark behavior, not authenticated production delivery or current shipped-iOS equivalence. Earlier watchdog/emulator failures remain retained with unproven root causes.

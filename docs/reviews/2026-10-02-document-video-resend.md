# Sequential document/video resend - 2026-10-02

Accepted locally after independent gpt-6-astra xhigh review. This stage extends existing document/video send paths; it does not add a video receive/render/codec feature. Installed-source receipts and fresh checks are retained in the evidence workspace.

## User-visible result

If A is accepted and B fails, the composer keeps B and later files. A and its original caption/reply are not repeated by ordinary retry. A definite rejection permits retry of the remaining tail. An unknown submitted outcome retains its URI history: the next overlapping attempt opens localized native Cancel/Send again before any preparation or dispatch. Cancel sends nothing and preserves the current composer; confirmation revalidates input, account/use-case, route, lifecycle and operation before sending only the remainder.

The unchanged SendMediaMessageUseCase requires a valid Message in the target chat. Here acceptance means that request returned a valid pending/accepted Message; it does not prove final Telegram delivery. Confirmed prefix retirement is synchronous and applies only to the exact owned ordered selection. First acceptance consumes original caption, reply, custom-emoji draft state and caret once. Newer input/caret/entities/selection, cancel, mode, navigation or account changes stop the old continuation without clearing newer composer or busy ownership.

Never-submitted and explicitly rejected prepared copies are discarded only through the existing file owner. Accepted or uncertain paths remain available for TDLib uploads. Late document/camera picker results and errors cannot replace a newer draft/selection. A real forward-picker enter/cancel sequence now advances the existing composer input revision, preventing an old preparation from resuming after mode ABA.

## Reproduction, scope and reference

The baseline loop retained the entire URI list after partial acceptance and only cleared composer at the end. It lacked revision/selection guards and disposal of a prepared copy whose owner had changed. Document/camera picker callbacks could overwrite newer input. Identical production callbacks on immutable preimages expose these defects; controls ensure definite first rejection, successful ordered sends and unchanged-owner paths remain allowed.

Official TDLib [sendMessage](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1send_message.html), [inputMessageDocument](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1input_message_document.html) and [inputMessageVideo](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1input_message_video.html) ground the existing request/return contract. Local pinned td_api.tl and MessagesManager.cpp were also inspected. iOS EnqueueMessage.swift and PendingMessageManager distinguish explicit resend of pending/failed messages from replay of accepted items and preserve reply/media metadata. The implementation is clean-room: no reference code/assets/dependencies were imported. harmonyos_docs was unavailable; installed official SDK contracts and actual native execution ground platform APIs.

Production changes are exactly six paths: existing Composer, new composed helper (252 lines), existing Context setter and base/ru_RU/zh_CN strings. Composer is 456 lines. Existing text/photo, gateway/error/use-case/media-normalizer owners remain unchanged. Preflight stays within existing ordered 1-10 unique nonempty URI sends and existing chat/reply/caption constraints.

## Verification

- Same callbacks: baseline 28 controls PASS/113 assertion RED, candidate 141/141; host 71/71; native focused 47/47, full 1134/1134. RED failures are behavioral assertions, with zero loader/runtime errors. Same actual SDK callback bodies run on baseline and candidate; deterministic transport/preparation are explicit ports.
- Thirteen same-suite activated negative controls and nine independent chief-review controls cover prefix/caption ownership, native consent, input/owner fences, cleanup, older uncertainty and forward-mode revision. Their receipts distinguish valid assertion failures from excluded stale-loader anchors.
- Full host suites, decomposition22/22, PowerShell/Bash smoke and serial official main/test SDK builds pass. Legacy suite loaders receive the new helper without weakening existing assertions.
- Both frozen HAPs use only com.telegram.harmonyos.documentresend20261002 with dummy credentials. Bundle metadata, ABC markers, source hashes and HAP hashes are checked before installation. Native test processes start fresh; unique callback start/completion identities and exact registered counts are verified.
- Real mounted UIContext/promptAction/Driver tests document and video A-accepted/B-unknown. They inspect native title/warning/buttons, cancel with zero extra preparation/mutation, then confirm B-only dispatch; captured commands verify caption/reply consumed only once. Two screenshots record the actual modal. Deterministic fixtures prove behavior; they do not prove real picker grants, camera recording, codec upload or Telegram delivery.
- Chief reviewer actually launched through collaboration.spawn_agent with model gpt-6-astra and reasoning_effort xhigh. It independently found and reproduced forward-mode ABA through actual public controllers/adapters/Context; the narrow fix and engaged negative control pass. See [chief review](2026-10-02-document-video-resend-chief-review.md).
- Earlier failures remain recorded. Existing host getter/setter fixture expectations were migrated to the deliberate forward-mode revision increment without dropping ownership assertions. Two initial full native runs ended with THREAD_BLOCK_6S, first after1038 completions at the unchanged decomposition UI case, then after917 completions at the unchanged1914-entry emoji catalog case. The latter performed9570 assertions; the first run took6744ms for that same case. Fault samples contain Ark runtime frames, no determining application ETS frame and ample available device memory. The identical HAP old decomposition suite passed11/11. Fresh complete verification retains all1134 tests; these observations do not establish the original freeze cause or prove the runtime interruption harmless.

## Preservation and remaining limits

Main dev started with 408 dirty records and 1055 public files, HEAD faf66b3e066afccdbbfa36442eb9122073f509b2. Immutable preimages, complete baseline hashes, unchanged HEAD/index/status checks and an exact owned path manifest guard installation. Before-images and fresh main host/smoke/hash receipts prove preservation. No reset/stash/staging/commit/push/PR/merge is used.

Only the isolated test bundle is installed/started on the existing emulator. Public bundle-manager metadata for the original app is compared before/after. No contact delivery, account login/creation, session/credential files or security settings are used.

Real provider/camera/Telegram delivery, authenticated account/navigation/IME/production Dock and current shipped-iOS visual acceptance remain open. URI history is bounded and owner-scoped, not persisted across app restart; saturation conservatively asks confirmation. Packaged upstream TDLib logging policy remains a separate gap. Proposed next user feature: the existing slow-mode countdown and attach/send gating TODO, referenced against iOS ChatTextInputSlowmodePlaceholderNode/ChatSlowmodeHintController. This proposal is not shipped by this stage.

Evidence: [structured record](2026-10-02-document-video-resend-evidence.json).

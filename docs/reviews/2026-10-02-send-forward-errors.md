# Bounded send/forward errors and application TDLib406 - 2026-10-02

Accepted locally after independent gpt-6-astra xhigh review. Installed source and recheck receipts are recorded separately in the evidence workspace; this report claims controlled transport and synthetic native UI, not real Telegram delivery or shipped-iOS pixel acceptance.

## Result

Send text/media/album and forward now preserve typed kind, code, retryability and technical detail. Per-request provenance separates explicit rejection from an unknown post-dispatch outcome. Text/media success validates the actual Message ID and target chat; malformed acceptance remains uncertain. Preflight read failures do not masquerade as dispatched writes, and a client retired after dispatch cannot establish rejection.

Text uses the existing composer owner through ChatTextSendController. Failure restores the exact raw draft, cloned custom-emoji entities, selection and reply only while that operation still owns the unchanged composer. An uncertain identical resend opens the real localized native Cancel/Send again dialog; Cancel dispatches nothing and preserves state, confirmation dispatches once after revalidating ownership. Bounded counted uncertain markers retain older ambiguity even after a later known rejection. No automatic retry was introduced.

Forwarding retains positional null/partial-result semantics. An accepted comment is never restored for replay; unknown comment/forward outcomes do not restore a fully repeatable batch. Definite rejection restores only untouched owned remaining intent. Known photo rejection removes only its current operation's consumed marker; previous uncertain markers, cancel, revision, account and lifecycle safeguards remain.

Code406 is gated before application message accessor use in the gateway, adapter, classifier and nested updateMessageSendFailed normalizer. Safe code/message identity bookkeeping remains, with no application payload processing/display/error logging. This does not prove the packaged upstream TDLib log stream/verbosity: source VLOG(td_requests) serializes result/error/update payloads and no application override is installed.

## Grounding and bounded scope

Official [TDLib error contract](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1error.html) specifies the special406 policy; [sendMessage](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1send_message.html) returns Message and [forwardMessages](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1forward_messages.html) retains ordered null entries. Local td_api.tl lines16/18,10844/10853/10881 ground the pinned shape. Requests.cpp3970/4636 and MessagesManager.cpp20956/23997 show explicit rejection preceding pending-message construction.

iOS behavior was inspected in Telegram-iOS-current: PendingMessageManager.swift90, ChatControllerLoadDisplayNode.swift5234-5272 and EnqueueMessage.swift415. Semantic errors, friendly feedback and explicit retry preserving reply/forward metadata inform the clean-room changes; no third-party code/assets/dependencies were imported. harmonyos_docs was unavailable; installed official SDK declarations and native execution grounded platform behavior.

The production delta is16 paths. The new text helper is221 lines; Composer decreased588->523 lines. No new observed/global owner, routing change, public transport retry, account/security change or mixed/video album feature is included. Sequential document/video uncertain-resend UX is intentionally the next bounded priority.

## Verification

- Identical callback assertions on immutable source preimages:18 controls PASS and66 assertion RED; final84/84GREEN (67 SDK callback bodies plus17 host pipeline/dialog controls).
- All17 activated behavioral mutants fail through assertions; loader/runtime errors do not count as negative evidence.
- Full host70/70, decomposition22/22, PowerShell/Bash UI smoke PASS. Existing assertions were retained; old fixtures now model actual Message acceptance and required revision APIs.
- Serial official main/test SDK builds PASS. HAP hashes, isolated bundle identity, ABC markers and corresponding source hashes are frozen in the evidence JSON.
- Native focused68/68 and full1087/1087 PASS, with unique one-to-one start/completion identities and zero failure/error/ignore. Real mounted UIContext/promptAction/Driver exercises Cancel and confirmation against deterministic timeout/acceptance transport, with a captured dialog screenshot.
- The first two native UI attempts were preserved as67PASS/1ERROR. The first lacked below-fold Scroll navigation; readiness plus scrollSearch repaired test navigation without weakening assertions. The second exposed the emulator lock screen: projectrunner/WindowStage logs showed content loaded then window destruction. An ordinary unlock swipe allowed the same frozen v5 HAPs to exercise real UI, with no security settings changed. Earlier ArkTS nominal fixture/type corrections and failed build logs remain recorded.
- Chief review actually launched through collaboration.spawn_agent with model gpt-6-astra and reasoning_effort xhigh. Independent typed/406/adversarial, provenance, mutation and scope checks are in [chief review](2026-10-02-send-forward-errors-chief-review.md); there is no separate model introspection endpoint.

## Preservation and remaining boundary

Main dev began at faf66b3e066afccdbbfa36442eb9122073f509b2 with397 dirty records. Immutable public preimages and hashes for1047 files, index/HEAD/status guards and an exact owned-path allowlist protect installation. Only the reviewed source/tests/docs are copied; new before-images and fresh installed host/smoke/hash receipts prove preservation. No reset/stash/staging/commit/push/PR/merge occurred.

Only com.telegram.harmonyos.senderrors20261002 is installed/started on the existing emulator; both HAPs are installed together, with dummy credentials and deterministic ports. The original bundle metadata is checked separately. No contacts, real messages, accounts, login, delivery, session files or security settings are touched.

Remaining product acceptance: real Telegram acceptance/delivery and send-failed ordering, provider grants, authenticated account/reconnect/IME/production Dock state matrix and current shipped-iOS witness. Remaining code priorities: sequential document/video uncertain-resend ownership, then packaged upstream TDLib406 logging policy. The present acceptance is local and bounded.

Evidence: [structured record](2026-10-02-send-forward-errors-evidence.json). Raw logs, before-images, native screenshot and immutable HAPs remain under the evidence workspace named there.

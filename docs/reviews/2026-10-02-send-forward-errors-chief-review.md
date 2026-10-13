# Independent chief review — ACCEPTED

2026-10-02. Frozen production v2 and tests v5 are accepted for the bounded send/forward typed-error and TDLib 406 change. No unresolved P1 or P2 findings. This decision is issued before guarded installation into the original dirty working tree.

## What was verified

- Typed AppError kind, TDLib code, retryability and user/technical separation survive all four mutating usecases through a contextual copy. Shared causes are not mutated. Explicit rejection/pre-dispatch provenance is distinct from uncertain transport outcome; post-dispatch client retirement remains uncertain.
- Numeric 406 is handled before any error-message access/classification. The gateway, contextual wrapper and nested updateMessageSendFailed normalizer discard its text; application-owned UI/log paths do not expose it. Failed-message bookkeeping remains intact. Poisoned-accessor probes and non-406 controls exercise the actual owners.
- Plain-text rejection restores only an untouched owned raw draft, deep-cloned emoji entities and original selection while preserving reply intent. Unknown outcome retains a local consumption marker. Cancel dispatches zero further writes; an explicit, still-current confirmation permits one repeat. Stale operation, input ABA, route/lifecycle, usecase, permission, reply or mode changes cannot revive an old send.
- Forward preflight and comment/forward mutations retain separate certainty. An accepted comment is not replayed. Unknown writes do not restore the whole selection as safely retryable; definitive rejection and explicit null-slot results preserve only appropriate unsent intent. Existing photo consumption/cancellation ownership remains protected.
- Reviewed all 16 production diffs and all 21 test diffs against the immutable captured dirty baseline. Legacy fixtures now return valid matching Message responses and explicit known rejection where the assertion requires it; relevant assertions are retained. The new text helper stays within the existing composer owner.

## Fresh evidence

| Evidence | Result |
|---|---|
| Final focused host execution: actual 67 Hypium callbacks + 17 gateway/dialog cases | 84/84 PASS |
| Same final callbacks over immutable baseline | 18 PASS; 66 assertion failures (meaningful RED) |
| Independent opaque-message and nested 406 probes | 7/7 PASS; baseline 4 assertion failures |
| Independent write/composer/forward adversarial probes | 18/18 PASS |
| Independently executed read/photo/forward regression | 73/73; 23/23; 65/65 PASS |
| Inspected behavioral mutation receipts | All 17 engaged; all killed by assertions |
| Parent full host suite / PowerShell and Bash smoke | 70/70; both smoke checks PASS |
| Official SDK main v2 / ohosTest v5 builds | Both exit 0, BUILD SUCCESSFUL; log hashes checked |
| Frozen-HAP native focused / full | 68/68 and 1087/1087 PASS, 0 failure/error/ignore |

The reviewer independently parsed every native start/completion pair: unique one-to-one identities, with all focused cases present in the full run. Actual HAP byte hashes and embedded ZIP module.json were checked. All 37 candidate path hashes match the frozen manifests; production and native-test files also match the SDK source snapshot and current isolated SDK copy.

The native screenshot was visually inspected: a real system dialog shows the duplicate warning and separate Cancel/Send again controls; the controlled fixture is at one mutation, busy=true, reply=55, one entity. The native callback verifies Cancel preserves intent without dispatch and confirmation submits exactly one additional matching synthetic text request with reply/entities.

Earlier v4/v5 focused runs each had 67 PASS and one UI readiness ERROR. Those logs remain failed evidence. The accepted run is `compile-v5-unlocked`, using the same frozen `compile-v5` HAPs after restoring the emulator active window.

## Launch, identity and preservation

The actual parent `collaboration.spawn_agent` receipt records `model="gpt-6-astra"`, `reasoning_effort="xhigh"`, `fork_turns="none"` and worker `/root/astra_chief_review`. This verifies the executed launch configuration; no independent model-introspection endpoint is exposed.

- Main HAP SHA-256: `530978f165c608b3b0074896c0b7958dcc40ee7fc79589f15305790a7d0f03ae`.
- Test HAP SHA-256: `4dbb19e96a6bad16e8552e9e1824616e59bab2a90f066d2743d7273722e00bcc`.
- Isolated bundle: `com.telegram.harmonyos.senderrors20261002`; embedded modules `entry` and `entry_test`.
- Rehashed all 1047 immutable baseline files. Main HEAD/index and all 37 pre-install paths still match the captured baseline. Reviewer wrote only review/probe artifacts outside candidate.
- Original bundle before/after public metadata JSON is byte-identical. This is metadata preservation evidence; session/account files were not read.

## Explicit remaining boundaries

- TDLib-internal logging of the packaged prebuilt libtdjson.so is unproved. Acceptance covers reviewed application-owned ETS/bridge paths; no claim that all native/internal logs suppress 406.
- Sequential document/video unknown-outcome resend confirmation remains future work; this narrow patch preserves their existing flow and applies typed-cause/406 handling without redesigning that UX.
- Native UI witness uses a synthetic TestAbility and deterministic gateway. No authenticated delivery, real picker/provider grants, session contents, account action, or current shipped-iOS visual parity was tested.
- Duplicate confirmation is scoped to the current composer owner/context and is not durable global idempotence across restart or arbitrary later navigation.
- Existing forward-comment restoration remains trimmed-text behavior; full original whitespace/entities/caret restoration is established for plain text sending, not newly promised for forward comments.
- No callable harmonyos_docs tool was available. Official installed SDK compilation/runtime plus official TDLib documentation and local schema ground the reviewed boundaries.

The governing external source is the [official TDLib error contract](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1error.html); the local td_api.tl schema independently matches it. Current iOS resend-choice behavior was inspected as a clean-room reference; no reference code was copied.

## Reviewed path hashes

| Scope | Path | SHA-256 |
|---|---|---|
| production | `entry/src/main/ets/core/model/AppError.ets` | `6ce31104a96fc1deaa952653ed44255959914b8168e3ed2d6b9a6a96df27c530` |
| production | `entry/src/main/ets/domain/ports/TdGatewayPort.ets` | `2ce615e8bf02cb1dc8e1ee6b9c5d764863cfbc59a87ce113122c45ead7eacce1` |
| production | `entry/src/main/ets/infra/td/gateway/TdGateway.ets` | `9cd97d9b2e4cd6043a63ab3b05ee135acfe0c8c48792d2ea9207676654f81078` |
| production | `entry/src/main/ets/infra/td/adapter/TdGatewayAdapter.ets` | `993efcf674c563fc087ca4650309ea85960ac046f78dc48c4181c8999d5fdbcb` |
| production | `entry/src/main/ets/core/events/normalizers/MessageNormalizer.ets` | `7578cbee28a3b54604cecce02ff1cff1710bf0521dfbfbd7f238de0345396a19` |
| production | `entry/src/main/ets/domain/usecases/sendMessage.ets` | `7db29a749605ac559621ff04075b02b16103ebf9e572de38908a814a3384c5f5` |
| production | `entry/src/main/ets/domain/usecases/sendMediaMessage.ets` | `cd45bd45c88485884e0fdbf17851568ae8c728e73c89af0f15ee0e47ac50e802` |
| production | `entry/src/main/ets/domain/usecases/sendMediaAlbum.ets` | `80d450e437d11feeba02e00c7c7ed04a7b4d6779963fcb1865edf30e854a661b` |
| production | `entry/src/main/ets/domain/usecases/forwardMessages.ets` | `ebbc0c611cc7acf0c9c1386a7ed037e08b175609d5f3e2d2c3852cfe2ad1bfe3` |
| production | `entry/src/main/ets/ui/pages/chat/ChatComposerController.ets` | `a8173a55caf7398552d6113a5a7ea938c5a284eb79256d117480ca727a45ac18` |
| production | `entry/src/main/ets/ui/pages/chat/ChatTextSendController.ets` | `eeb9b4c92a26462cf87c60ed1d638762fe4c1a8b94dc33c4c216d47ff08d874a` |
| production | `entry/src/main/ets/ui/pages/chat/ChatMessageActionsController.ets` | `74e532227674bf7efe21a0d4af9e6510610ba344892956c7045d99427d5ef13e` |
| production | `entry/src/main/ets/ui/pages/chat/ChatPhotoAlbumController.ets` | `cb016d3f254ff10e455a05f5263f2bca5914fe2ec0333731cc93b4e8b67e0409` |
| production | `entry/src/main/resources/base/element/string.json` | `c8410b3db5a82ab3ffd5413d45928e0c38d380fb375eca0c0f29a22ea8477b1a` |
| production | `entry/src/main/resources/ru_RU/element/string.json` | `d9310f8591519407dc4b827520608f924fd80f5b6bc0f5158b4d5b6dd911a11c` |
| production | `entry/src/main/resources/zh_CN/element/string.json` | `0cb85fb2eac5aa2e4da32e1ea314c0e7364e1c33842822aa2925799bf9af7c2f` |
| test | `scripts/test-basic-group-access.cjs` | `bdad10da64043bded7644dc123f857e2b6259a9c50a666dca08f6962cf9c940f` |
| test | `scripts/test-basic-group-media.cjs` | `64d3354f80a00b57bff91ca6b6989456f1c9ee94a6ab10a3c5edb2b62a4de7d5` |
| test | `scripts/test-command-serializer-escaping.cjs` | `573304b22796762e007e9ba4aabfc209e11ad6ed9bc4f4aa6c21cca53fc7003f` |
| test | `scripts/test-edit-only-send-guard.cjs` | `4ef0e5adbb382d97914d5403fa1d294398f455a77b78952cc4436e2f51dd8683` |
| test | `scripts/test-forward-eligibility.cjs` | `b3d3a45c96541db017a3b90fb46a5de0cd8096fa72c0b977c49ccab0e97811c0` |
| test | `scripts/test-forward-result-contract.cjs` | `ada5980120deef278dd856c31b62e0abc4541752b8f24179e8c69b6536bfde5c` |
| test | `scripts/test-forward-send-ownership.cjs` | `804288af0ab23015960d22d9d9a41278f1971e2b0460371d18a6a339841e3b90` |
| test | `scripts/test-photo-album-controller.cjs` | `fa5beebac1a1aed1e56a8fdfd273d65fda5f35c06b60a9e60018417ef6d4761d` |
| test | `scripts/test-photo-preview-controller.cjs` | `9a5e8c0bd476ad13cc92e119c16b02f62575a6f19cc7f827a27c05b09f9c9e96` |
| test | `scripts/test-send-cleanup-ownership.cjs` | `0ec191b543dd494d21b7ca0b95659953278b80144a138da9efac97044a379072` |
| test | `scripts/test-send-media-album.cjs` | `e90881b45fbb0b6a721430046435e85040426c04dd3f7bcbd5ef771d2deaabce` |
| test | `scripts/test-write-path-errors.cjs` | `499f0504ce135256fc4f6a98b52ccdf19dad343c06a00590ca6f0d8a91cf1fed` |
| test | `entry/src/ohosTest/ets/test/ForwardEligibility.test.ets` | `da6b4d70a9902428b922c9f7ddc8e7219f0845fecef2165694369ed5aa6ae24d` |
| test | `entry/src/ohosTest/ets/test/ForwardSendOwnership.test.ets` | `9cc5897f30116a91753b3428f9eacf4a9f59d5981fa45c9e4c22ac5c8f849958` |
| test | `entry/src/ohosTest/ets/test/List.test.ets` | `9a76e35c140450d8c4056de50f2b5ebfd2e1ff8e355de76807c0d319fd301a81` |
| test | `entry/src/ohosTest/ets/test/SendMediaAlbum.test.ets` | `70cc578816e5aacf2b70fae8f1741a2ee1b10a4d75c6e55f8181fe8412ffb0b6` |
| test | `entry/src/ohosTest/ets/test/UseCases.test.ets` | `0739f1531ea13a832935eba16808c4ba6c5755ec4fc086ea9de14bd0792b0914` |
| test | `entry/src/ohosTest/ets/test/WritePathErrors.test.ets` | `4a36d361d055fa36e76b08880817a610722e1761b8e6d6aa6fceb2cdd39f1fe8` |
| test | `entry/src/ohosTest/ets/test/WriteResendDialog.test.ets` | `ea0ad0bbe9d328549503f7a396b5fd53dbf1b12c9fdafdbbfe20b27c0da75f2a` |
| test | `entry/src/ohosTest/ets/testability/components/WriteResendFixture.ets` | `6e61883fdf18cc684f08e3d401b9ba5382b1721936b79e80dc700f00ac2d3a63` |
| test | `entry/src/ohosTest/ets/testability/pages/Index.ets` | `7ff472bcd13b54910aabe6dda10d57bee50e8d73c6e723120d5e976e0d483452` |

Machine-readable verdict, evidence hashes, native identities and the evidence workspace location: [installed structured evidence](2026-10-02-send-forward-errors-evidence.json). Original review artifacts `astra-review-final.json`, `astra-native-final-verification.json`, `astra-review-initial.md` and `astra-native-log-scope.md` remain in that workspace.

# Reviewed source checkpoint - 2026-10-13

This checkpoint preserves the 400 original changed files (117 tracked modifications and 283 untracked source/test/documentation files) on `dev@faf66b3e066afccdbbfa36442eb9122073f509b2`. The accepted 39-path supplement is applied once over verified preimages, producing 419 distinct selected paths. It supersedes the original candidate overlay. Three bounded review fixes follow that selection; two new test helper/regression files bring the mapped total to 421.

[The complete per-file change map](2026-10-13-source-change-map.json) records all original files, supplement membership, final working-byte hashes, reviewer groups and the 36 preserved local artifacts. All 419 selected paths received independent group review: runtime47, chat76, other UI25, tests/tooling181 and documentation90. The documentation consists of 7 active documents, 12 source references and 71 historical records. The two new completion-helper files and final remediation diff received separate review.

## Review corrections

- Initial startup retry failure no longer renders the logout retry overlay. The regression executes actual builder conditions and click expressions: baseline34/35, fixed35/35. The pre-auth logout retry remains reachable.
- A shared completion guard observes the top-level Promise in 25 previously unguarded async host entrypoints. A real adapter-suite mutation that completes only1/4 checks now exits2 instead of0. Normal4/4 completion, rejection codes and intentionally pending fixture promises remain covered.
- PowerShell contract reads normalize CRLF to LF only for raw text assertions. Application source bytes remain unchanged by the reader. LF/CRLF parity and full UI smoke pass.

## Fresh local verification

| Check | Result | Boundary |
|---|---|---|
| Full host aggregate after fixes, Node24.12.0 | 82/83 passed; exit1 | Only `test-smoke-hex-check.cjs` failed: Git Bash/MSYS cannot create its named object namespace, status0xC0000022. No incomplete-suite failures. |
| Affected completion suites | 26/26 passed | Includes actual incomplete adapter negative control; no account or device used. |
| PowerShell UI smoke | Passed; exit0 | Includes LF/CRLF contract-reader parity. |
| Official default + ohosTest SDK attempt | Both exit1 before compiler | Unchanged accepted supplement witness projection; symlink EPERM creating the Hvigor link. Final review fixes were not SDK-compiled. |
| Native/device/HDC | Not run for this checkpoint | Existing HDC10013 and GUI0x80070003 limitations remain; no bypass or new device-acceptance claim. |

Linux CI is configured for the static shell smoke and all83 host suites. Its result must be read from the Actions run for the published commit; local evidence does not establish remote CI success. The self-hosted HarmonyOS build remains opt-in through the existing repository variable.

## Commit boundaries

1. The coupled310-file baseline of runtime, decomposed chat/UI, resources, tests and CI. Keeping this integration together avoids publishing partial model/route/fixture dependencies.
2. The selected39-path stabilization supplement, applied once.
3. Login retry routing and its actual branch/action regression.
4. Async completion guard,25 entrypoint wrappers, its regression and CRLF contract reading.
5. The90 reviewed documents, current checkpoint notes/change map and exact local-artifact exclusions.

## Historical evidence and remaining limits

The33 historical evidence JSON files, two patch files and `du.exe.stackdump` are preserved on disk and individually ignored. They are classified in the change map, not removed or silently treated as application code. Historical Markdown references to them remain dated audit records; their absent raw receipts cannot be independently revalidated from a source-only checkout. No source/config consumer depends on those raw artifacts.

The account-recovery test's API configuration is a proven synthetic fixture using an injected fake gateway and test directories. It is included unchanged except for the completion-entrypoint guard if applicable; no production credential was added.

Historical SDK/native PASS reports, controlled v21 oracle checks and earlier installed HAPs apply only to their recorded snapshots. Current source review and host results do not establish a successful SDK build, current device execution, authentication/provider/microphone/delivery behavior, shipped-iOS visual parity or release readiness. Known native environment/opaque-handle lifetime, slow-consumer backpressure and conversion-error recovery remain separate work. No security, ACL, sandbox, network or credential configuration was changed to bypass these limits.

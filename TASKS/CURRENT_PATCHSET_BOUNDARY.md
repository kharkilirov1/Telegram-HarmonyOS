# CURRENT PATCHSET BOUNDARY — active snapshot

Last updated: 2026-05-18

## Baseline

- Last committed baseline: `b762cf1` (`fix: repo cleanup + TdGateway refactor + tests + selector memoization`)
- The old broad dirty-tree batch has been committed.
- Current follow-up patch covers review fixes + Phase 2 decomposition/refactor + documentation/spec hygiene.

## Current follow-up patch scope

### Code fixes / refactors
- `entry/src/main/ets/ui/pages/chat/ChatMediaDownloadController.ets`
  - Direct `downloadFile` responses flow through `TdGatewayAdapter` as `TdObject` instances.
  - The controller uses `.getObject('local')`, `.getBool('is_downloading_completed')`, and `.getString('path')` instead of treating the response as a plain `Record`.
- `entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets`
  - Composer and message-action logic removed from the page body; page remains the reactive state/navigation owner.
- `entry/src/main/ets/ui/pages/chat/ChatComposerController.ets`
  - Owns send-message branching, media send preparation, emoji panel handlers, attachment picker flow, and picked-file local copy.
- `entry/src/main/ets/ui/pages/chat/ChatMessageActionsController.ets`
  - Owns action sheet actions: reply, edit, copy, forward target flow, pin, delete, and forward submission.
- `entry/src/main/ets/ui/pages/chat/ChatScreenRouteParams.ets`
  - Shared route params extracted from the page file.
- `entry/src/main/ets/infra/td/serialization/CommandSerializer.ets`
  - Replaced large per-command `switch` with command-type dispatch handler registration.
- `entry/src/main/ets/ui/pages/chat/ChatSearchController.ets`
  - Owns debounced in-chat search requests and first-result navigation.
- `entry/src/ohosTest/ets/test/CommandSerializer.test.ets`
  - Covers serializer dispatch handlers and `buildTdlibRequestJson` raw nested JSON expansion.
- `entry/src/ohosTest/ets/test/UseCases.test.ets`
  - Covers common use-case validation and gateway command dispatch.
- `entry/src/ohosTest/ets/test/AuthSideEffect.test.ets`
  - Covers basic singleton/store seam without native TDLib startup.

### Hygiene / docs
- `STATUS.md`
- `TASKS/TODO.md`
- `TASKS/LESSONS.md`
- `TASKS/CURRENT_PATCHSET_BOUNDARY.md`
- `entry/src/main/ets/domain/selectors/chatSelectors.ets` (line-ending hygiene only)
- `entry/src/main/ets/ui/tg_ui/spec/TgChatRow.md`
- `entry/src/main/ets/ui/tg_ui/spec/TgMediaBubbleShellV2.md`
- `entry/src/main/ets/ui/tg_ui/spec/TgMessageTextBodyV2.md`
- `entry/src/main/ets/ui/tg_ui/spec/TgFilterBar.md`
- `entry/src/main/ets/ui/tg_ui/spec/TgTokens.md`
- `docs/ai/AI_MEMORY.md`
- `docs/ai/UI_MIGRATION_PLAN.md`
- `docs/ai/ATOM_ROADMAP.md`

## Out of scope for this follow-up

- Additional `TgChatScreenPage.ets` decomposition beyond composer/actions/search
- New UI atoms/demos
- Device/emulator signing/deployment
- Any destructive git history rewrite or amend

## Verification completed before handoff

- `git diff --check` — passed
- `scripts/smoke-ui-phase0.ps1` — passed
- `bash ./scripts/smoke-ui-phase0.sh` — passed
- `scripts/smoke-build.ps1` — BUILD SUCCESSFUL

Observed warnings only:
- `libtdlib_napi.so` is not verified by current SDK smoke boundary
- no signing config is configured for HAP signing

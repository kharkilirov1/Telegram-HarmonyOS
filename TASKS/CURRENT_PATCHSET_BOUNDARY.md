# CURRENT PATCHSET BOUNDARY — active snapshot

Last updated: 2026-05-18

## Baseline

- Last committed baseline: local `HEAD` before the current Phase 4 calls-pagination follow-up
- The Phase 2 review-fix/decomposition/tests patch has been committed locally.
- Current patchset is the next unblocked Phase 4 slice.

## Current follow-up patch scope

### Code fixes / refactors
- `entry/src/main/ets/core/model/AppCommand.ets`
  - `SearchCallMessagesPayload` now carries TDLib's opaque `offset:string`.
- `entry/src/main/ets/infra/td/serialization/CommandSerializer.ets`
  - `searchCallMessages` serializes `offset`, `limit`, and `only_missed`; no chat-history `_from_message_id_json`.
- `entry/src/main/ets/domain/usecases/loadCalls.ets`
  - Reads `FoundMessages.next_offset` and exposes `LoadCallsResult.nextOffset`.
- `entry/src/main/ets/ui/pages/calls/CallsPage.ets`
  - Carries next-page state as opaque TDLib offset for calls pagination.
- `entry/src/ohosTest/ets/test/CommandSerializer.test.ets`
  - Covers `searchCallMessages` serializer output.
- `entry/src/ohosTest/ets/test/LoadCalls.test.ets`
  - Covers foundMessages parsing, missed/outgoing mapping, next_offset, and direct chat/user hydration.

### Hygiene / docs
- `STATUS.md`
- `TASKS/TODO.md`
- `TASKS/LESSONS.md`
- `TASKS/CURRENT_PATCHSET_BOUNDARY.md`

## Out of scope for this follow-up

- Call-start VoIP behavior from the call row
- Call history deletion/action mode
- Group-call join/create behavior
- New UI atoms/demos or broad calls UI redesign
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

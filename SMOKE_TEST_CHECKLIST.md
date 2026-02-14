# Regression Smoke Suite — alpha-core baseline

Date: _______________  Build: _______________  Device: _______________
Tester: _______________  TDLib mode: REAL / STUB  Security mode: _______________

## Checklist

| # | Test case | Expected result | Pass/Fail | Notes |
|---|-----------|----------------|-----------|-------|
| 1 | **Cold start** — kill process, launch from scratch | Init diagnostic box in hilog, no crash, no ANR | ☐ | |
| 2 | **Init TDLib** — observe hilog during startup | `TDLib Client Init` box shows MODE, DIR, SONAME, API_ID, SEC_MODE | ☐ | |
| 3 | **Login** — enter phone number, receive code, authenticate | Auth flow completes, `updateAuthorizationState` → `authorizationStateReady` | ☐ | |
| 4 | **Chat list** — after login, main screen loads | `loadChats` returns, chat list renders with titles and last messages | ☐ | |
| 5 | **Open chat** — tap any chat | Chat history loads, messages render, `openChat` sent to TDLib | ☐ | |
| 6 | **Send text** — type and send a message in an open chat | Message appears locally, delivery confirmed (server ack), no error toast | ☐ | |
| 7 | **Relaunch** — Home → kill → relaunch | Session persists, no re-auth, chat list loads from DB, no migration logged | ☐ | |
| 8 | **Migration path** — upgrade from pre-encryption build | `DB ENCRYPTION MIGRATION v0→v1` block in hilog, old DB deleted, re-auth required, v1 marker written, subsequent launches skip migration | ☐ | |
| 9 | **Security mode** — verify in hilog after init | Physical device: `HUKS_HARDWARE`; Emulator: `SOFTWARE_FALLBACK` + degraded flag if REAL mode | ☐ | |
| 10 | **Timeout path** — simulate stuck init (dev build only) | `TDLIB_INIT_TIMEOUT` rejection after 30s with state/secMode/tdlibMode in error message; no infinite hang; `destroy()` unblocks waiters with `TDLIB_CLIENT_DESTROYED` | ☐ | |

## Result summary

- Total: 10
- Passed: ___ / 10
- Failed: ___ / 10
- Blocked: ___ / 10

## Blocking issues (if any)

| # | Test | Issue description | Severity |
|---|------|-------------------|----------|
| | | | |

## Sign-off

- [ ] All P0 tests (1-6, 8-10) pass
- [ ] No crashes or ANR observed
- [ ] hilog shows no unexpected ERROR-level entries
- [ ] Ready for alpha tag: **YES / NO**

Signed: _______________ Date: _______________

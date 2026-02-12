# QA Runbook — alpha-core

Quick reference for QA engineers verifying the alpha-core stabilization.

## Pre-requisites

- DevEco Studio with HarmonyOS SDK 6.0.2+
- Physical device (for HUKS/TEE tests) or emulator (for STUB/fallback tests)
- `hdc` shell access for hilog inspection

## Test matrix

### 1. Fresh install (clean device / emulator)
1. Uninstall app if present.
2. Install and launch.
3. Verify hilog shows: `DB encryption marker written: v1`.
4. Verify no `DB ENCRYPTION MIGRATION v0→v1` block in logs.
5. Authenticate with Telegram account.
6. **Pass** if login succeeds and chat list loads.

### 2. Upgrade from unencrypted build
1. Install a build from BEFORE the encryption changes (no SecurityService).
2. Log in and load some chats to populate the DB.
3. Install the new alpha-core build over the old one.
4. Launch — verify hilog shows the migration block:
   ```
   ┌─ DB ENCRYPTION MIGRATION v0→v1 ─────────────────
   │ Found existing TDLib database without encryption marker.
   │ Removing old unencrypted database for safe re-creation.
   │ User will need to re-authenticate after this one-time reset.
   └────────────────────────────────────────────────
   ```
5. Verify user is prompted to re-authenticate.
6. After login, verify chat list loads and `DB encryption marker written: v1` logged.
7. **Pass** if migration runs once, login succeeds, subsequent launches skip migration.

### 3. Security mode verification
**On physical device (HUKS expected):**
1. Launch app.
2. Verify hilog shows `SEC_MODE: HUKS_HARDWARE (resolved)`.
3. Verify `isDegradedSecurity` is NOT logged.
4. **Pass** if security mode is HUKS_HARDWARE.

**On emulator (no TEE):**
1. Launch app.
2. Verify hilog shows `SEC_MODE: SOFTWARE_FALLBACK (resolved)`.
3. If `tdlibMode` is `REAL`: verify `DEGRADED SECURITY` error block in logs.
4. If `tdlibMode` is `STUB`: verify `SOFTWARE_FALLBACK in STUB mode` info log.
5. **Pass** if degraded flag matches expectations for the build type.

### 4. waitForReady() timeout path
1. To simulate: add a `while(true) {}` or long delay before `_readyResolve()` in `initialize()`.
2. From another code path, call `await TDLibClient.getInstance().waitForReady()`.
3. After 30 seconds, verify the rejection:
   ```
   TDLIB_INIT_TIMEOUT: state=Initializing, elapsedMs=30000, secMode=..., tdlibMode=...
   ```
4. Verify the caller receives a `TDLibError` with message starting `TDLIB_INIT_TIMEOUT`.
5. **Pass** if timeout fires, error is diagnosable, no infinite hang.

### 5. destroy() during waitForReady()
1. Start the app normally.
2. Before init completes, call `TDLibClient.getInstance().destroy()`.
3. Any pending `waitForReady()` callers should receive `TDLIB_CLIENT_DESTROYED`.
4. **Pass** if no hanging promises, error message is clear.

### 6. Cold start → chat list
1. Kill the app process.
2. Launch from scratch.
3. Verify hilog init diagnostic box appears with all fields populated.
4. If already authenticated, verify chat list loads within 10 seconds.
5. **Pass** if no crashes, no ANR, chat list renders.

### 7. Send text message
1. Open any chat.
2. Send a text message.
3. Verify message appears in the chat and is delivered (double-check mark).
4. **Pass** if send succeeds without error toast.

### 8. Relaunch persistence
1. With an active session, press Home to background the app.
2. Bring the app back to foreground.
3. Verify chat list is intact, no re-authentication required.
4. Kill and relaunch — verify same.
5. **Pass** if session persists across lifecycle events.

## hilog cheat sheet

```bash
# Full TDLibClient logs
hdc shell hilog | grep TDLibClient

# Security-specific logs
hdc shell hilog | grep SecurityService

# Migration events
hdc shell hilog | grep "MIGRATION"

# Timeout events
hdc shell hilog | grep "TDLIB_INIT_TIMEOUT"

# Degraded security
hdc shell hilog | grep "DEGRADED SECURITY"
```

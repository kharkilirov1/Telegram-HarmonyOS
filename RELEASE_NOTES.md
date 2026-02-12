# Release Notes — alpha-core stabilization

## What changed

1. **Database encryption (one-time re-login required)**
   First launch after upgrade will delete the old unencrypted TDLib database
   and recreate it with a HUKS-backed (or fallback) encryption key.
   Users must re-authenticate with their Telegram account once.

2. **HUKS vs SOFTWARE_FALLBACK**
   The encryption key is now derived via HarmonyOS Universal Keystore (HUKS).
   On devices without TEE/Secure Element support, a deterministic software
   fallback is used. In REAL (production) TDLib mode, software fallback
   sets `isDegradedSecurity = true` and logs a prominent error block.
   STUB (development) mode tolerates the fallback silently.

3. **`waitForReady()` timeout**
   Callers using `await TDLibClient.getInstance().waitForReady()` will now
   receive a `TDLIB_INIT_TIMEOUT` rejection after 30 seconds (configurable).
   `destroy()` during initialization correctly unblocks waiters with
   `TDLIB_CLIENT_DESTROYED`. No infinite hangs are possible.

4. **Versioned encryption schema**
   DB encryption versioning (v0 → v1 → v2 …) is now explicit.
   Future key-derivation changes only require a new migration method
   and a switch-case entry — no refactoring of existing logic.

5. **Error taxonomy**
   `TDLIB_INIT_TIMEOUT` and `TDLIB_CLIENT_DESTROYED` are classified in
   `AppError` for consistent user-facing messages and retry policy.

## Upgrade behavior

| Scenario | What happens |
|----------|-------------|
| Fresh install | DB created encrypted from the start, v1 marker written |
| Upgrade from unencrypted build | Old DB deleted, user re-authenticates, v1 marker written |
| Upgrade from v1 encrypted build | No migration, marker already present |
| HUKS unavailable (emulator) | SOFTWARE_FALLBACK used, degraded flag set in REAL mode |

## Diagnosing TDLIB_INIT_TIMEOUT

If `waitForReady()` rejects with `TDLIB_INIT_TIMEOUT`, check the hilog output:

```
TDLIB_INIT_TIMEOUT: state=Initializing, elapsedMs=30000, secMode=HUKS_HARDWARE, tdlibMode=REAL
```

Common causes:
- TDLib native library failed to load (check `libtdjson.so` presence)
- Network timeout during TDLib bootstrap (first-run key exchange)
- HUKS initialization stalled (rare; check device TEE status)

Resolution:
1. Verify `hdc shell hilog | grep TDLibClient` for the full init diagnostic box
2. Check `secMode` — if `SOFTWARE_FALLBACK`, HUKS may be unavailable
3. Check `tdlibMode` — if `STUB`, you're running without real TDLib
4. Restart the app; the timeout is non-destructive (state resets on re-init)

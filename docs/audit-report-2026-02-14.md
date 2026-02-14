# Telegram-HarmonyOS — Full Codebase Audit Report

**Date:** 2026-02-14
**Scope:** All layers — services, controllers, UI pages/components, models, config, build, NAPI

---

## Summary

| Severity | Count | Description |
|----------|-------|-------------|
| **P0** | 7 | Critical — crashes, security holes, data loss, broken core features |
| **P1** | 39 | Important — functional bugs, race conditions, resource leaks |
| **P2** | 40 | Minor — dead code, edge cases, cosmetic issues |

---

## P0 — Critical

| # | Layer | File | Issue |
|---|-------|------|-------|
| 1 | Service | `SecurityService.ets` | **Fallback encryption key is static and public.** `generateFallbackKey()` produces `base64('TelegramHarmonyOS_DBKey_v1_fallback_v1')` — identical on every device. Any attacker with the APK trivially derives the DB key. |
| 2 | Service | `TDLibClient.ets:105` | **Invalid API credentials do not abort init.** `TELEGRAM_API_ID === 0` logs a warning but continues to `td_create_client_id()` and `startReceiveLoop()`. The client enters Ready state with no valid session, causing every request to fail. |
| 3 | NAPI | `tdlib_napi.cpp:268-291` | **`StopReceiveLoop` deadlocks.** Acquires `loop_mutex`, then calls `receive_thread.join()` while still holding the lock. If `StartReceiveLoop` is called concurrently, it deadlocks on the mutex. |
| 4 | UI | `CallUIPage.ets` | **Incoming call accept does nothing.** The accept-call handler never calls TDLib `acceptCall` — the call can never be answered. |
| 5 | UI | `NearbyPeoplePage.ets` | **Hardcoded null-island coordinates.** Location always sends (0.0, 0.0), so the nearby-people feature is non-functional and sends wrong data to Telegram servers. |
| 6 | UI | `PasscodeSettingsPage.ets` | **Passcode is never persisted.** The set-passcode flow validates input but never writes the hash to storage, so passcode lock provides zero security after app restart. |
| 7 | Config | `ConfigLocal.ets` | **Placeholder credentials tracked in git.** `api_id=0`, `api_hash=''` are committed. `.gitignore` was added later — file remains tracked. Real credentials could be pushed. |

---

## P1 — Important

### Service Layer

| # | File | Issue |
|---|------|-------|
| 8 | `TDLibClient.ets:530-581` | **`handleResponse` race condition.** Async method `await`s `taskpool.execute()`, yielding control. Concurrent invocations read/write `pendingRequests` map without synchronization — can cause double-resolve or missed responses. |
| 9 | `TDLibClient.ets:537,542` | **`@extra` guard always true.** `extra = response['@extra'] || 0` coerces missing `@extra` to `0`, so `extra !== undefined` is always true. Every unsolicited update triggers a spurious `pendingRequests.has(0)` lookup. |
| 10 | `TDLibClient.ets:527` | **`sendTdlibParameters` promise not awaited.** If the request fails, the rejection is unhandled — user stuck in auth limbo. |
| 11 | `TDLibClient.ets:149-155` | **`send()` mutates caller's params object.** Adds `@type` and `@extra` to the input object, surprising callers who reuse it. |
| 12 | `SecurityService.ets:127-131` | **Static IV for AES-CBC key derivation.** Not a standard KDF — same plaintext always yields same ciphertext. |
| 13 | `SecurityService.ets:67` | **Empty key returned before init.** `getDatabaseEncryptionKey()` returns `''` if called before `initialize()` completes. |
| 14 | `PreferencesService.ets:129-135` | **Passcode hash stored in plaintext Preferences.** Extractable on rooted devices; 4-6 digit PINs trivially brute-forced. |
| 15 | `PreferencesService.ets:234-266` | **`flush()` on every single write.** Multiple rapid writes cause excessive I/O. Should batch. |
| 16 | `SessionService.ets:80-86` | **Non-TDLibError exceptions swallowed as success.** `catch` logs but returns `null`, which caller interprets as success. |
| 17 | `ProxyService.ets:85-147` | **Same swallow pattern.** All four mutation methods treat runtime errors as success. |
| 18 | `ChatService.ets` | **No error handling in any method.** All ~25 methods propagate raw TDLib errors to UI. |
| 19 | `GroupService.ets` | **Same — no error handling in any method.** |
| 20 | `ConfigLocal.ets:7-8` | **No runtime fail-fast for missing credentials.** TDLib init proceeds with `api_id=0`. |

### NAPI (C++)

| # | File | Issue |
|---|------|-------|
| 21 | `tdlib_napi.cpp:28,252` | **`threadsafe_callback` read/written from two threads without sync.** Data race between main and receive thread. |
| 22 | `tdlib_napi.cpp:252` | **`napi_tsfn_blocking` blocks receive thread.** If JS main thread is busy, TDLib events queue up, potentially dropped. |
| 23 | `tdlib_napi.cpp:251-252` | **Memory leak on threadsafe call failure.** `new std::string` allocated, then if `napi_call_threadsafe_function` fails, the string is never deleted. |
| 24 | `tdlib_napi.cpp:126-136` | **Log extraction ignores spaces in JSON.** `"@type":"` pattern fails for `"@type": "..."`. |

### Controllers

| # | File | Issue |
|---|------|-------|
| 25 | `AuthController.ets:98-103` | **Encryption key send not awaited/caught.** On failure, user stuck in auth state with no error. |
| 26 | `AuthController.ets:99` | **Empty encryption key possible.** No guard that `dbKey != ''` before sending. |
| 27 | `FileController.ets:85-128` | **Download failures never notify callbacks.** Callbacks leak; callers wait forever. |
| 28 | `FileController.ets:71` | **Fire-and-forget `downloadFile`.** Send error silently lost. |
| 29 | `ContactsController.ets:69-73` | **Sequential await in loop for contacts.** Hundreds of contacts loaded one-by-one. |
| 30 | `CallsController.ets:76-100` | **No error handling for start/discard call.** TDLib errors propagate unhandled. |
| 31 | `StoriesController.ets:18` | **Unbounded stories cache.** Map grows without limit — no eviction. |
| 32 | `MessagesController.ets:98` | **`dialogsEndReached` never set to true.** Redundant `loadChats` calls to TDLib forever. |
| 33 | `MessagesController.ets:163` | **`deleteMessage` always `revoke: true`.** No option for local-only delete; revoke window expiry causes inconsistency. |
| 34 | `MessagesController.ets:108-133` | **`loadMessages` no error handling.** Promise rejects to UI with no cleanup. |
| 35 | `TdMessageParser.ets:384-401` | **Call message content parsed from wrong structure.** Reads `content['call']` but TDLib puts `duration`/`is_video`/`discard_reason` directly on content. All call messages display incorrectly. |
| 36 | `NotificationCenter.ets:84-89` | **Observer list mutation during iteration.** If handler calls `removeObserver`, iterator skips handlers or throws. |
| 37 | `MessagesUpdateSubscriber.ets:370-377` | **Typing timeout never cancelled.** Multiple `setTimeout`s accumulate; first to fire clears typing even if user is still typing. |
| 38 | `MessagesUpdateSubscriber.ets:312-314` | **`updateChatReadOutbox` does not compare message IDs.** Marks last message as read even if sent after the read pointer. |
| 39 | `UserStateReducer.ets:157-163` | **`refreshUserPresentation` iterates ALL messages on every user status update.** O(total_messages) on high-frequency events. |
| 40 | `MessageRequestService.ets:109-135` | **`sendVoiceMessage` sends empty path by default.** No validation; TDLib receives `inputFileLocal` with `path: ''`. |

### Models

| # | File | Issue |
|---|------|-------|
| 41 | `Message.ets` / `TdMessageParser.ets:64` | **Channel sender ID always 0.** `sender?.user_id \|\| 0` drops `chat_id` for channel senders. Reply attribution, sender grouping broken for channels. |
| 42 | `TdTypes.ets:47-50` | **`asRecord` unchecked cast.** Primitive values cast to `Record<string, Object>` silently produce undefined behavior. Used 14 times across 4 files. |

### UI

| # | File | Issue |
|---|------|-------|
| 43 | `PrivacySettingsPage.ets` | **Privacy settings saved locally only.** Never call TDLib `setPrivacyRules` — changes have no effect on Telegram servers. User believes they changed privacy but they didn't. |
| 44 | `TwoFactorAuthPage.ets` | **2FA flow is local-only.** Does not call TDLib 2FA APIs. Password is never set on the server. |
| 45 | `ForwardPage.ets` | **Forward-multiple only forwards one.** Loop sends the same single message regardless of selection count. |
| 46 | `BiometricSettingsPage.ets` | **Biometric auth stored only in Preferences.** Never registered with the system biometric framework. |

### Build

| # | File | Issue |
|---|------|-------|
| 47 | `entry/build-profile.json5:18-22` | **Obfuscation disabled for release builds.** Unobfuscated release makes reverse engineering trivial. |
| 48 | `build-profile.json5:3` | **Empty `signingConfigs`.** Cannot produce signed HAP for device install or AppGallery submission. |

---

## P2 — Minor (Top 20)

| # | File | Issue |
|---|------|-------|
| 49 | `TDLibClient.ets:159-163` | Timeout path bypasses `pending.reject` wrapper — inconsistent error instrumentation. |
| 50 | `TDLibClient.ets:563-572` | Exception in one update handler kills all subsequent handlers — no per-handler try/catch. |
| 51 | `SecurityService.ets:160-165` | HUKS session handle not aborted on `finishSession` error — potential secure element leak. |
| 52 | `SessionService.ets:52` | Session ID `number` type loses precision for TDLib int64 IDs > 2^53. |
| 53 | `NotificationService.ets:12` | `notificationId` counter overflow — may exceed 32-bit int limit on HarmonyOS. |
| 54 | `PreferencesService.ets:195-217` | Public generic setters allow arbitrary key injection (e.g., overwrite `passcode_hash`). |
| 55 | `AppError.ets:80-87` | Dead code — duplicate check for "timed out" / "Client destroyed" unreachable. |
| 56 | `TdFallbackRegistry.ets:22` | Unbounded `entries` map — no eviction. |
| 57 | `CallsController.ets:77` | Hardcoded protocol versions (`min_layer: 65`, `max_layer: 92`) — may become stale. |
| 58 | `ContactsController.ets:187` | `asRecord(undefined)['editable_username']` — potential TypeError. |
| 59 | `ContactsController.ets:14,220` | Duplicate user cache diverges from `MessagesController.usersById`. |
| 60 | `MessagesController.ets:193-207` | Optimistic edit not reverted on failure. |
| 61 | `MessagesUpdateSubscriber.ets:267-287` | `updateDeleteMessages` does not filter `is_permanent` flag — premature UI removal. |
| 62 | `MessageStateReducer.ets:33-43` | `replaceTemporaryMessage` mutates array in-place while other methods return copies. |
| 63 | `UserStateReducer.ets:59-60` | Empty `first_name` from TDLib discarded — stale name persists in cache. |
| 64 | `Message.ets:235-243` | `MessageDateGroup` class is dead code — never imported. |
| 65 | `Message.ets:92` | `callDiscardReason` string vs `Call.CallDiscardReason` enum — dual representations. |
| 66 | `TdTypes.ets:72-77` | `PollOptionDisplay` duplicates `PollOption` from `Message.ets` — redundant type. |
| 67 | `User.ets:36-42` | `AuthorizationState` enum is dead code — never imported. |
| 68 | `entry/build-profile.json5:2` | `apiType: "stageMode"` — may use unstable APIs in production. |

---

## Recommendations (Priority Order)

1. **Fix P0 security**: Replace fallback encryption with device-unique key (e.g., UDID-derived via HUKS). Fail-fast on missing API credentials.
2. **Fix P0 NAPI deadlock**: Release `loop_mutex` before calling `receive_thread.join()`.
3. **Fix P0 UI**: Implement actual `acceptCall` TDLib invocation; persist passcode hash; use real GPS coordinates.
4. **Fix P1 race conditions**: Guard `pendingRequests` map access; cancel typing timeouts; synchronize `threadsafe_callback`.
5. **Fix P1 missing server calls**: Wire privacy settings, 2FA, biometric auth to TDLib APIs.
6. **Fix P1 error handling**: Add try/catch to all controller/service methods that call TDLib.
7. **Fix P1 call message parser**: Read `duration`/`is_video`/`discard_reason` from content root, not `content['call']`.
8. **Enable obfuscation** for release builds and configure signing.

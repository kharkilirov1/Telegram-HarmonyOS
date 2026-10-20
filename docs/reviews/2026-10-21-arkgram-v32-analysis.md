# ArkGram v3.2 — competitor analysis — 2026-10-21

**Scope and boundary.** This note contains measurements and structural observations only. No
competitor source code, identifiers copied verbatim into this repository, assets, or resource files
are reproduced. The existing boundary in
[docs/ai/COMPETITOR_COMPARISON_ARKGRAM_NEKOGRAM.md](../ai/COMPETITOR_COMPARISON_ARKGRAM_NEKOGRAM.md)
("публичного source repo нет... код и assets копировать нельзя") is respected.

**Method.** Metadata from `module.json`, `pack.info`, `pkgContextInfo.json`; the source-file
inventory from `ets/sourceMaps.map` (which carries paths but **no `sourcesContent`**); symbol and
string mining of `libs/arm64-v8a/libentry.so` and `ets/modules.abc`. Full jadx decompilation of
`modules.abc` was attempted separately and did not complete inside the working window; everything
below comes from the methods that did.

---

## 1. What it is

| Field | Value |
|---|---|
| Bundle | `com.matheusrv.arkgram` |
| Version | 3.2 (versionCode 3000002), vendor `mrvapps` |
| Built | 2026-10-20 00:50 |
| Archive | 95 923 635 B across 171 entries |
| API | compatible 23, target 26, compileSdk 26.0.0.105, `apiReleaseType: Release` |
| **Build mode** | **`buildMode: "debug"`, `"debug": true`** |
| VM | `ark13.0.1.0`, `compileMode: esmodule` |
| TDLib | **1.8.66** |
| x86_64 native | `libc++_shared.so`, `libentry.so` — **no `libtdjson.so`** |

Competitor against this project (same measurements, this repository):

| | ArkGram 3.2 | Telegram-HarmonyOS |
|---|---|---|
| Published | yes | no |
| Build | **debug, unsigned** | debug, `signingConfigs: []` |
| ArkTS files | 291 | 374 |
| Architecture | flat `view`/`controller`/`pages`/`utils`/`model` | `ui`/`domain`/`core`/`infra`/`services` |
| Host suites / CI | not observable | 96/96, CI green |
| Concurrency primitives | **none** | none shipped (Worker path measured, null result) |
| TDLib | 1.8.66 | 1.8.61 |
| Test on | real device only (no x86_64 TDLib) | API24 x86_64 emulator |

---

## 2. The single most important finding: they do not do concurrency

`taskpool`, `ThreadWorker` and `@Concurrent` appear **zero times** in `ets/modules.abc` and zero
times in `ets/sourceMaps.map`. Not "used sparingly" — absent.

Their native bridge is the same shape this project already has:

```
pthread_create                       (producer thread)
napi_create_threadsafe_function     (marshal to ArkTS)
napi_call_threadsafe_function
napi_create_async_work              (control work: start/stop/join)
napi_create_promise
td_json_client_create / send / receive / destroy
```

That is, a native producer thread plus a threadsafe function into ArkTS — the architecture already
implemented in `entry/src/main/cpp/tdlib_napi.cpp`.

**Implication for this project: the receive-drain investigation of 2026-10-19/21 was answered by
the market, not just by the emulator.** The only shipping HarmonyOS Telegram client reachable here
does not relocate the drain, does not use Workers, and does not tune slice budgets. It ships.

This does not make the measurements worthless — the null result and the budget curve are now
recorded and reproducible (`probe/`, three dated notes). It makes them insufficient. Neither result
converges on a published product.

---

## 3. What they built that this project has not

Observed from the platform API surface in `modules.abc` and the source-file inventory.

### Notifications / push
`@ohos:notificationManager`, `wantAgent` (notification actions), and a full push payload model —
`pushMessageContent` variants for `Animation`, `Audio`, `Document`, `LiveLocation`, `Location`,
`Photo`, `Poll`, `Sticker`, `Text`, plus `pushDataArray` and `push.pushService`. The ability
registers `action.ohos.push.listener` and the custom actions `com.arkgram.action.OPEN_NOTIFICATION_MESSAGE`,
`OPEN_LATEST_PUSH` and `INLINE_REPLY`. **Inline reply from the notification is implemented.**

This is the open gate that has stood since 2026-09-27 in this project's `TASKS/TODO.md`.

### Local storage
`@ohos:data.relationalStore` (SQLite), `@ohos:data.preferences`, `@ohos:data.dataSharePredicates`,
`@ohos:data.unifiedDataChannel`. A real local database, not in-memory state.

### Features with no counterpart here
- **WebApps / mini apps** — TDLib calls `openWebApp`, `getMainWebApp`, `getWebAppUrl`,
  `getWebAppLinkUrl`, and `webAppOpenParameters` in the bytecode, plus `@ohos:web.webview`.
- **Picture-in-picture** — `@ohos:PiPWindow`.
- **Media playback sessions** — `@ohos:multimedia.avsession`, `multimedia.audio`,
  `multimedia.image`, `multimedia.media`.
- **Contacts** — `@ohos:contact`.
- **Biometric lock** — `@ohos:userIAM.userAuth`.
- **Backup** — an `EntryBackupAbility` extension (`@ohos:application.BackupExtensionAbility`).
- **Sessions management** — `terminateSession`, `logOut`, `blockListMain`, `getBlockedMessageSenders`.
- **Background work** — `@ohos:resourceschedule.backgroundTaskManager`,
  `backgroundModes: audioRecording, audioPlayback`.
- **Deep links** — `tg://`, `t.me`, `telegram.me`, `telegram.dog`; share intents accepting up to 10
  files of any media type.
- **ffmpeg** — `libavcodec`, `libavfilter`, `libavformat`, `libavutil`, `libswresample`,
  `libswscale`, for local media processing.
- **Local media access** — `@ohos:file.photoAccessHelper`, `file.picker`, `file.fs`.

### Dependency hygiene — a shared trait, not a gap
`pkgContextInfo.json` packages `@ohos/hypium` — the test framework — into the shipped bundle. This
project declares the same package (`entry/oh-package.json5`, `"@ohos/hypium": "^1.0.19"`), so it is
**not** a differentiator; it is listed here only to record that both projects do it. Their packaged
version is 1.0.24.

---

## 4. How they call TDLib from ArkTS

TDLib requests are built as JSON string constants in ArkTS: `"@type":"getAuthorizationState"`,
`"@type":"getUser"`, `"@type":"openWebApp"`, `"@type":"terminateSession"`, and others, passed
through the `libentry.so` bridge. This project uses the same pattern
(`tdlib.send(this.clientId, request.toJSON())`). No architectural advantage here either way.

---

## 5. What this project is actually ahead on

- **Test discipline.** 96/96 host suites, green CI, a host runner that fails loudly, and three dated
  notes that *retract* a wrong measurement. No competitor artifact is observable this way.
- **Documentation of measurement.** The `probe/` harness survives outside the app bundle, which is
  the fix for the earlier loss of the native validation apparatus.
- **Architecture breadth.** A layered `ui`/`domain`/`core`/`infra` split with no import cycles,
  versus a flat MVC.
- **Version discipline.** A pinned, documented TDLib revision whose `.so` reports exactly what the
  pin declares, plus a recorded provenance gap.

None of that ships.

---

## 6. Conclusion

The project is stronger in engineering and weaker in exactly the dimension the competitor is
weaker in: **delivery.** The competitor has the features this project is missing (push with inline
reply, local database, sessions management, mini-apps, PiP, backup, biometric lock, contacts) and
none of the concurrency work this project spent three days on.

The ordering that follows from the measurements, not from preference:

1. Release signing — the hard blocker; and because the competitor is also unsigned debug, the
   distribution channel is still unclaimed.
2. Push with inline reply — the feature that makes a messenger usable, absent here for three weeks.
3. One complete end-to-end path on a real device — every measurement so far needed the emulator
   because this path has never been walked.
4. TDLib 1.8.66 — seven versions behind, and the nearest competitor is at 1.8.66.

Further receive-drain work is not supported by any evidence in this repository, by the null result
of 2026-10-21, or by the competitor's shape.

---

## 7. Not completed

Full jadx decompilation of `ets/modules.abc` (302 classes, 23 128 methods, 3 335 651 instructions)
was started with the local `jadx-dev-all.jar`, which loads the bytecode successfully but had not
emitted output within ~30 minutes. Class-level detail (method bodies, exact call graphs) is
therefore **not** in this note. Everything above is metadata, symbol and string level.

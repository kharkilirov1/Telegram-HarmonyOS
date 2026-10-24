# ArkGram (com.matheusrv.arkgram) — competitor analysis — 2026-10-21

> **Corrections — 2026-10-23.** Five re-checks changed this note. The concurrency result in §2 is the
> one that survived unchanged; the package identity, the feature list, the push attribution, the
> TDLib row and §7 did not.
>
> 1. **The package analysed is v1.0.1, not 3.2.** The retained reconstruction names its source
>    artifact `ArkGram-v1.0.1.hap`, and `module.json` / `pack.info` report `versionName 1.0.1`,
>    `versionCode 1000000`. Compile SDK is `26.0.0.23` with `apiReleaseType: Beta1`, not
>    `26.0.0.105 / Release`. The previous title and the `3.2 / 3000002` row were wrong.
> 2. **The §3 feature list was not reproducible from the retained inputs.** Several platform APIs it
>    listed do not occur in any retained artifact. §3 now separates what is witnessed from what is
>    not; the `@ohos:` import surface was extracted from the retained decompiled tree and the
>    bytecode/source-map scans were re-run for this note.
> 3. **The push claim was misattributed.** The ability registers `ohos.want.action.home`; the push
>    surface is a separate extension, `ArkGramPushExtension`, declared with
>    `action.system.push.message`. `action.ohos.push.listener`, `OPEN_NOTIFICATION_MESSAGE` and
>    `OPEN_LATEST_PUSH` do not occur in the retained artifacts (`INLINE_REPLY` does, once).
> 4. **`libtdjson.so` and the TDLib version are unverified.** `pkgContextInfo.json` lists
>    `libtdjson.so` as a packaged native module, and no retained file reports a TDLib version — the
>    string `1.8.66` occurs nowhere in the bytecode, the source map or the decompiled tree. The
>    "seven versions behind" line was also wrong arithmetic: 1.8.61 → 1.8.66 is five steps; seven is
>    the distance to the 1.8.68 upstream reported on 2026-10-19.
> 5. **§7 was stale.** jadx did emit output: 160 decompiled units are retained and its log reports
>    171 classes / 11 447 methods / 1 629 763 instructions with 62 errors. The earlier
>    "302 classes / 23 128 methods / 3 335 651 instructions, no output within 30 minutes" combination
>    has no retained source.

**Scope and boundary.** This note contains metadata and structural observations only. No competitor
source code, identifiers copied verbatim into this repository, assets, or resource files are
reproduced. The boundary in
[docs/ai/COMPETITOR_COMPARISON_ARKGRAM_NEKOGRAM.md](../ai/COMPETITOR_COMPARISON_ARKGRAM_NEKOGRAM.md)
("публичного source repo нет... код и assets копировать нельзя") is respected. The retained reference
tree under `C:\Refs\Telegram\ArkGram-RE` holds a decompiled reconstruction; this note reads it for
inventory and counts, and quotes no code from it.

**Method, as re-run on 2026-10-23.** Five retained inputs were used:

| Input | What it yields |
|---|---|
| `out/ArkGram-project/entry/src/main/module.json` | manifest: bundle, versions, SDK levels, abilities, extensions, permissions |
| `out/ArkGram-project/entry/src/main/pack.info` | packer view of the same, API compatibility |
| `out/ArkGram-project/entry/src/main/pkgContextInfo.json` | packaged dependencies and native-module inventory |
| `out/ArkGram-sources/` | decompiled reconstruction, 160 `.java` units (its README counts 159 ArkTS files); the README also records the source HAP as `ArkGram-v1.0.1.hap` |
| `hap_extracted/ets/modules.abc`, `hap_extracted/ets/sourceMaps.map` | bytecode string scan and the source-path inventory (`sourcesContent` is absent — verified, 0 occurrences) |

Not retained, therefore not verified here: the `.hap` itself, its size and entry count, any `libs/`
directory, and `libentry.so`. Anything below that depends on those is marked **unverified**.

---

## 1. What it is

| Field | Value |
|---|---|
| Bundle | `com.matheusrv.arkgram` |
| Vendor | `mrvapps` |
| Version | **1.0.1** (versionCode `1000000`) |
| Built | not recorded in the retained metadata |
| API | compatible 23, target 26, compileSdk **26.0.0.23**, apiReleaseType **Beta1** |
| **Build mode** | **`buildMode: "debug"`, `"debug": true`** |
| VM | `ark13.0.1.0`, `compileMode: esmodule` |
| TDLib | **unverified** — no version string in any retained file |
| Declared native modules | `libentry.so`, `libtdjson.so`, and the ffmpeg family (`libavcodec`, `libavfilter`, `libavformat`, `libavutil`, `libswresample`, `libswscale`) per `pkgContextInfo.json` |
| Device types | phone, tablet |

Competitor against this project:

| | ArkGram 1.0.1 | Telegram-HarmonyOS |
|---|---|---|
| Published | analysed as an unsigned **debug** HAP | no |
| Build | debug | debug, `signingConfigs: []` |
| ArkTS units | 159 in the reconstruction (318 distinct `.ets` paths in `sourceMaps.map`) | 374 `.ets` files |
| Architecture | `controller` / `downloads` / `entryability` / `entrybackupability` / `extensionability` / `model` / `pages` / `proxy` / `settingsUI/*` / `utils` / `view` | `ui`/`domain`/`core`/`infra`/`services` |
| Host suites / CI | not observable | 96/96, CI workflow present |
| ArkTS-level concurrency | **0** (verified, §2) | none shipped (Worker path measured, null result) |
| TDLib | unverified | 1.8.61, witnessed in-process |
| Test target | not recorded | API24 x86_64 emulator |

The earlier "291 ArkTS files" figure is not supported: the reconstruction holds 159 ArkTS files and
the source map lists 318 distinct `.ets` paths (the map also covers non-`entry` material).

---

## 2. The single most important finding: no ArkTS-level concurrency

Occurrence counts, measured on 2026-10-23 across all three retained code inputs:

| Token | `modules.abc` | `sourceMaps.map` | decompiled tree |
|---|---:|---:|---:|
| `taskpool` | 0 | 0 | 0 |
| `ThreadWorker` | 0 | 0 | 0 |
| `@Concurrent` | 0 | 0 | 0 |
| `Worker` (any) | 0 | 0 | 0 |

Not "used sparingly" — absent. Their ArkTS side talks to native code only through NAPI imports of
`libentry.so`.

**What this does not say.** It is not "they do no concurrency". The previous version claimed a native
bridge of `pthread_create` + `napi_create_threadsafe_function` + `napi_create_async_work` +
`td_json_client_create`; none of that is witnessed in the retained artifacts (the `.so` is not
retained), so it has been removed rather than repeated. What the artifact shows is an ArkTS layer
with no worker, taskpool or `@Concurrent` usage.

**Implication for this project, stated carefully.** The only HarmonyOS Telegram client reachable
here does not relocate its receive drain and does not use ArkTS workers — and it is itself an
unsigned debug build, so this is a data point about one artifact, not a market verdict. It does
support the narrower conclusion drawn on 2026-10-21: no further receive-drain work is justified by
anything measured in this repository.

---

## 3. What they built that this project has not

### 3a. Witnessed in the retained artifacts

| Area | Evidence |
|---|---|
| Notifications | `@ohos:notificationManager`, `@ohos:app.ability.wantAgent`, `wantConstant` imports in the decompiled tree |
| Push | extension `ArkGramPushExtension`, type `push`, skill action `action.system.push.message`; `pushService` occurs twice and `INLINE_REPLY` once in the bytecode |
| Backup | `@ohos:application.BackupExtensionAbility` + `EntryBackupAbility` declared in the manifest with `$profile:backup_config` |
| Contacts | `@ohos:contact` import, `ohos.permission.READ_CONTACTS` requested |
| Local storage | `@ohos:data.preferences` only (key-value) |
| Media picking / files | `@ohos:file.photoAccessHelper`, `@ohos:file.PhotoPickerComponent`, `@ohos:file.picker`, `@ohos:file.fs`, `@ohos:file.fileuri` |
| Media rendering | `@ohos:multimedia.image`, `@ohos:multimedia.media` |
| Web view | `@ohos:web.webview` |
| Sessions | TDLib `terminateSession` (5 occurrences in the bytecode) |
| Deep links | manifest URI skills for `tg`, `t.me`, `telegram.me`, `telegram.dog` |
| ffmpeg | `libavcodec` / `libavfilter` / `libavformat` / `libavutil` / `libswresample` / `libswscale` in `pkgContextInfo.json` |
| Other platform surface | `abilityAccessCtrl`, `bundle.bundleManager`, `deviceInfo`, `geoLocationManager`, `inputMethod`, `mediaquery`, `net.http`, `pasteboard`, `promptAction`, `router`, `security.cryptoFramework`, `window` |

Their TDLib calls are built as JSON strings in ArkTS (`getOption` 6 occurrences, `optionValueString`
3), the same pattern this project uses. No architectural advantage either way.

### 3b. Claimed in the previous version, not found in any retained artifact

- `@ohos:data.relationalStore` (SQLite) — so "a real local database, not in-memory state" was
  unsupported; the witnessed local storage is preferences.
- `@ohos:data.dataSharePredicates`, `@ohos:data.unifiedDataChannel`.
- `@ohos:PiPWindow` (picture-in-picture).
- `@ohos:multimedia.avsession` and `multimedia.audio` (media playback sessions).
- `@ohos:userIAM.userAuth` (biometric lock).
- `@ohos:resourceschedule.backgroundTaskManager` and `backgroundModes` — the manifest declares no
  `backgroundModes`.
- TDLib `openWebApp` / `getMainWebApp` / `getWebAppUrl` / `getWebAppLinkUrl` — a `@ohos:web.webview`
  import exists, the web-app TDLib methods do not.
- `action.ohos.push.listener`, `OPEN_NOTIFICATION_MESSAGE`, `OPEN_LATEST_PUSH`.

These are marked absent from the retained inputs, not proven absent from the product: the inputs are
a bytecode scan, a path map and a decompilation that reports 62 errors, and the HAP itself is not
retained.

### Dependency hygiene — a shared trait, not a gap

`pkgContextInfo.json` packages `@ohos/hypium` (test framework, 1.0.24) and `@ohos/hamock` into the
shipped bundle. This project declares the same package (`entry/oh-package.json5`,
`"@ohos/hypium": "^1.0.19"`), so it is **not** a differentiator; it is listed here only to record
that both projects do it.

---

## 4. How they call TDLib from ArkTS

TDLib requests are built as JSON string constants in ArkTS (`"@type":"getAuthorizationState"`,
`"@type":"getUser"`, `"@type":"terminateSession"`, and others) and passed through the `libentry.so`
bridge. This project uses the same pattern (`tdlib.send(this.clientId, request.toJSON())`). No
architectural advantage here either way.

---

## 5. What this project is actually ahead on

- **Test discipline.** 96/96 host suites, a CI workflow, a host runner that fails loudly, and dated
  notes that *retract* a wrong measurement. No competitor artifact is observable this way.
- **Documentation of measurement.** The `probe/` harness survives outside the app bundle and now has a
  runnable entry point, which is the fix for the earlier loss of the native validation apparatus.
- **Architecture breadth.** A layered `ui`/`domain`/`core`/`infra` split with no import cycles,
  versus a flat controller/view/store tree.
- **Version discipline.** A pinned, documented TDLib revision whose `.so` reports exactly what the
  pin declares. The provenance gap — which upstream revision built that `.so` — remains open and is
  recorded as such.

None of that ships.

---

## 6. Conclusion

The project is stronger in engineering and weaker in exactly the dimension the competitor is weaker
in: **delivery**. The competitor artifact shows product surfaces this project lacks (notification and
push plumbing with an inline-reply token, contacts import, backup, preferences-backed settings,
picker/file flows, ffmpeg) and none of the concurrency work this project spent three days on.

The ordering that follows from the measurements, not from preference:

1. Release signing — the hard blocker; the competitor artifact is also unsigned debug, so the
   distribution channel is unclaimed by either side.
2. Push with inline reply — the feature that makes a messenger usable. `entry/` contains no
   notification, `wantAgent` or push code at all (checked 2026-10-23, and it was never tracked in
   `TASKS/TODO.md`), while the competitor has at least the push extension shell and an inline-reply
   token.
3. One complete end-to-end path on a real device — every measurement so far needed the emulator
   because this path has never been walked.
4. TDLib upgrade — this project is at 1.8.61; the competitor's version could not be witnessed, and
   upstream was 1.8.68 as of 2026-10-19. A target of 1.8.66 would be five steps up, not seven.

Further receive-drain work is not supported by any evidence in this repository, by the null result
of 2026-10-21, or by the competitor's shape.

---

## 7. What this analysis did not complete

The previous version reported that jadx decompilation "did not complete inside the working window"
and cited 302 classes / 23 128 methods / 3 335 651 instructions. Both parts are stale: the retained
`jadx.log` reports **171 classes / 11 447 methods / 1 629 763 instructions**, the run finished with
**62 errors**, and 160 decompiled units are retained on disk. Those 160 units are what §3 was
re-checked against.

Still not established:

- Class-level completeness: 62 decompiler errors mean the reconstruction is partial, and absence of a
  string in it is weaker evidence than absence in the bytecode scan.
- Native-side structure: the `.so` files are not retained, so the native TDLib ownership model,
  threading and the reported TDLib version remain unverified.
- Runtime behaviour: nothing here was executed. Feature presence is inferred from imports and
  manifest declarations, not from an observed run.

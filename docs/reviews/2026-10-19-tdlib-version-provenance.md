# TDLib version provenance and emulator precondition — 2026-10-19

Two gates were opened for the Worker spike. One passes, one closes with a gap.

---

## 1. Emulator precondition — PASS

`Pura 90 Pro Max` HVD, cold boot (`[WARNING] Hot boot is not enable, the bootmode "snapshot"
invalid`), Windows Hypervisor Platform accelerator operational.

| Reading | Value |
|---|---|
| Target | `127.0.0.1:5555` |
| OS | `emulator 6.1.0.125(SP9DEVC00E120R4P11)` |
| API | `24` |
| ABI | `x86_64` |
| Boot completed | `bootevent.boot.completed = true` |
| App | `com.telegram.harmonyos`, `appProvisionType: debug`, `versionName: ""`, `versionCode: 0` |

### Two operational facts the next session must not rediscover

1. **`hdc list targets` alone returns `[Empty]`.** The target appears only after
   `hdc tconn 127.0.0.1:5555`. `AGENTS.md:134` already says this; it is not optional.
2. **The target disappeared once during boot** — connected at ~45 s, gone by the next
   command, back after ~90 s more. Any script must retry the connection rather than
   treat the first success as stable. This matches the failure recorded in
   `.codex/ui-audit/2026-07-18/gallery-photo-gestures/README.md:26`.

### Limit, not a pass

The installed `libtdjson.so` could not be read:
`ls /data/app/el1/bundle/public/com.telegram.harmonyos/libs/x86_64/` → `Permission denied`
for the `shell` user. The on-device binary version is therefore **not** witnessed. Only the
source-tree prebuilt and the build intermediate were measured (below). The installed HAP on
disk is `entry-default-unsigned.hap`, 87 450 512 bytes, 2026-10-18 12:06.

---

## 2. TDLib version — the shipped binary does not come from the pinned source

Two independent routes disagree, and neither is wrong on its own terms.

| Route | Reading |
|---|---|
| Submodule `tdlib` at `cb863c160` (`v1.8.0-9195-gcb863c160`, 2026-01-08), clean tree | `project(TDLib VERSION **1.8.60**)` |
| `third_party/tdlib/lib/x86_64/libtdjson.so` | `**1.8.61**` |
| `third_party/tdlib/lib/arm64-v8a/libtdjson.so` | `**1.8.61**` |
| `entry/build/.../libs/default/x86_64/libtdjson.so` | `**1.8.61**` |
| `entry/src/main/cpp/CMakeLists.txt:118` | `set(TDLIB_RUNTIME_SONAME "libtdjson.so.**1.8.61**")` |

The bump that produces `1.8.61` is `11e254af6` — *Update version to 1.8.61*, 2026-02-07 —
which is **171 commits after the pin**. The pin is a strict ancestor of it.

### Why this is a gap and not a bug

`entry/src/main/cpp/CMakeLists.txt:95-99` documents the split deliberately:

> NOTE: The repo-root tdlib/ submodule (.gitmodules) is for building TDLib from source.
> The *prebuilt* artifacts must be placed under third_party/tdlib/{include,lib/<abi>}.
> These are separate concerns.

So the app build is internally consistent: headers from `third_party/tdlib/include` and the
binary from `third_party/tdlib/lib` are one matched pair at 1.8.61, and the SONAME agrees.

What is *not* consistent is provenance. **The shipped library cannot be reproduced from
anything pinned in this repository.** Rebuilding the submodule yields 1.8.60, not 1.8.61, and
nothing records which upstream revision produced the binary. The prior review
(`docs/reviews/2026-09-28-td-client-lifetime.md:15`) flagged this as "совпадение с
установленным `.so` не проверялось" — it is now checked, and the answer is: they do not match.

### Upstream distance

Local `origin/master` is `e0943d068` (2026-05-17) and already contains
`e59783887 *Update version to 1.8.62*`. Live upstream `CMakeLists.txt` declares **1.8.68**.
The clone's refs are therefore stale by roughly six version bumps.

---

## 3. Effect on the planned Worker spike

Neither finding blocks it.

- The spike compares **thread topology** on one fixed binary. 1.8.61 vs 1.8.60 does not
  enter the comparison.
- But one control is unavailable: "rebuild TDLib and see whether the numbers move" cannot be
  run against the pinned source, because the pinned source is not what ships.

---

## 4. What was not done

The submodule was **not** re-pinned to `11e254af6`. That change would make source and binary
agree on paper, affects no runtime behaviour (headers come from `third_party`), and is a
one-line decision for the owner rather than an agent's call.

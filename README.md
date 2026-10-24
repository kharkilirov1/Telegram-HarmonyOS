# Telegram-HarmonyOS

Telegram client for HarmonyOS NEXT in ArkTS/ArkUI with native TDLib.

- **Build target:** API 26 (`targetSdkVersion: 26.0.0`)
- **Compatible from:** API 23 (`compatibleSdkVersion: 6.1.0(23)`)
- **Verified on:** API 24 x86_64 emulator (`Pura 90 Pro Max` HVD)
- **Status:** not released, not signed; see [`STATUS.md`](STATUS.md)

## Architecture

Clean Architecture + Redux-like state management:

```
TDLib (native) → TdGateway → MainThreadDispatcher → EventNormalizer → AppStore → UI
```

- **TdGateway** — NAPI bridge to native TDLib, batched receive drain with a time budget
- **MainThreadDispatcher** — main-thread delivery bridge
- **EventNormalizer** — raw TDLib update → typed AppEvents
- **AppStore** — serial event dispatch + immutable state updates
- **UI** — V2-first ArkUI pages plus the project design system `ui/tg_ui`

## Project structure

```
entry/src/main/
├── ets/
│   ├── app/bootstrap/       # AppCoreRuntime
│   ├── core/                # events, model, reducers, store
│   ├── domain/              # selectors, usecases
│   ├── infra/               # td gateway, threading
│   ├── diagnostics/         # trace/diagnostic helpers
│   ├── models/              # TDLib DTO model barrels
│   ├── services/            # local config (ConfigLocal.ets, gitignored)
│   ├── types/               # native module typings (*.d.ts)
│   ├── ui/                  # pages, controllers, tg_ui design system
│   └── entryability/        # EntryAbility
├── cpp/                     # tdlib_napi.cpp, third_party/tdlib (gitignored)
└── resources/
probe/                       # receive-drain measurement harness + recorded runs
scripts/                     # host suites, smoke scripts, diagnostics
docs/                        # reviews (dated checkpoints), specs, ai (archive)
TASKS/                       # plan, queue, lessons; ARCHIVE/ holds history
```

## Documentation map — read in this order

| Document | Purpose |
|---|---|
| [`STATUS.md`](STATUS.md) | current state, last checkpoint, what is proven and what is not |
| [`TASKS/TODO.md`](TASKS/TODO.md) | **active queue**: open gates, backlog, decisions needed from the user |
| [`TASKS/WORKMAP.md`](TASKS/WORKMAP.md) | what is being done right now: 1–3 slices |
| [`TASKS/CAPABILITY_MATRIX.md`](TASKS/CAPABILITY_MATRIX.md) | what exists and in which state (status + evidence) |
| [`TASKS/SLICE_PROTOCOL.md`](TASKS/SLICE_PROTOCOL.md) | how one slice is done: reference, seams, test, implementation, comparison |
| [`TASKS/AGENT_EXECUTION_PLAN.md`](TASKS/AGENT_EXECUTION_PLAN.md) | canonical route; what to do in which order |
| [`TASKS/PRODUCTION_PARITY_PLAN.md`](TASKS/PRODUCTION_PARITY_PLAN.md) | per-phase exit criteria and evidence boundaries |
| [`TASKS/LESSONS.md`](TASKS/LESSONS.md) | numbered lessons and dated blocks — pitfalls that already cost time |
| [`DECISIONS.md`](DECISIONS.md) | accepted architecture/product decisions (`D1`–`D25`) |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | actual system layout and runtime boundaries |
| [`REFERENCES.md`](REFERENCES.md) | external reference registry and pins |
| [`docs/reviews/INDEX.md`](docs/reviews/INDEX.md) | all dated review reports, newest first |
| [`probe/README.md`](probe/README.md) | receive-drain harness, its status and its recorded runs |
| [`TASKS/ARCHIVE/INDEX.md`](TASKS/ARCHIVE/INDEX.md) | history — read-only, not instructions |

`docs/ai/*` is an **archive**: it is a frozen snapshot of earlier plans and comparisons. Do not execute
its roadmaps and do not keep it up to date; the active order lives in `TASKS/TODO.md`.

`AGENTS.md` and `CLAUDE.md` are local assistant rules and are intentionally **not versioned**
(`.gitignore`). A fresh clone has this README, `STATUS.md`, `DECISIONS.md` and the `TASKS/` pack as its
source of truth.

## Security (API credentials)

Telegram credentials are loaded from `entry/src/main/ets/services/ConfigLocal.ets` (**gitignored**).

1. Copy `entry/src/main/ets/services/ConfigLocal.example.ets` → `ConfigLocal.ets`
2. Fill values from [my.telegram.org/apps](https://my.telegram.org/apps)

## Requirements

- **DevEco Studio 26.0** with its bundled OpenHarmony SDK (project targets API 26, compatible API 23)
- **Node.js ≥ 24** for the host test runner (`scripts/run-host-tests.cjs`)
- **TDLib prebuilts:**
  - `entry/src/main/cpp/third_party/tdlib/include`
  - `entry/src/main/cpp/third_party/tdlib/lib/<abi>` — the current `build-profile.json5` builds **x86_64
    only** (emulator); a device build needs `arm64-v8a` added to `abiFilters`
  - or set `TDLIB_DIR` before build

## Setup

1. Clone with submodules: `git clone --recursive <repo-url>`
2. Configure credentials (see above)
3. Provide TDLib prebuilts
4. Open the project in DevEco Studio and sync

## Build

DevEco Studio: **Build > Build Hap(s)/APP**.

Command line (from a shell where `hvigorw` is available):

```bash
hvigorw clean --no-daemon
hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```

`./scripts/smoke-build.ps1` does the same (it probes `hvigorw`/`hvigor` in `PATH`, then falls back to
`C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat`) and fails loudly on a non-zero
exit. Output: `entry/build/default/outputs/default/entry-default-unsigned.hap` — **unsigned**, because
`build-profile.json5` has no `signingConfigs`.

## Verification

| Gate | Command | What it checks |
|---|---|---|
| Build | `./scripts/smoke-build.ps1` | full HAP build, exit code |
| UI contract | `./scripts/smoke-ui-phase0.ps1` or `bash ./scripts/smoke-ui-phase0.sh` | `TgChatRow` is `@ComponentV2`; chat-row metadata split; `HdsTabs` + floating bar + `barFloatingStyle`/`barOpacity`/`barHeight` in `MainTabsPage`; `.reuseId()` on the chat-list row path; `TgChatListNavigationBar` composes `Search`; `TgChatScreenPage` composes `TgChatTopBar` + `TgComposerInput` + `TgMessageRouter`; no hardcoded hex colours in the covered tg_ui files |
| Host suites | `node scripts/run-host-tests.cjs` | 96 behavioural suites in `scripts/` (Node ≥ 24; fails with `HARNESS_ERROR` on older Node) |
| On-device unit tests | DevEco `entry@ohosTest` | 87 `.test.ets` files under `entry/src/ohosTest/ets/test/` |

Runtime/emulator notes that already cost time (full list in `TASKS/LESSONS.md`):

- `hdc list targets` alone is `[Empty]`; run `hdc tconn 127.0.0.1:5555` first and retry — the target can
  disappear once during boot.
- `aa start` fails with `10106102` while the device screen is locked; wake it with
  `hdc shell power-shell wakeup` and swipe before starting.
- Installing a single ohosTest HAP over a working session recreates the bundle and wipes app data —
  install the entry HAP (or the full set) instead.
- After `hdc install -r`, verify a fresh process (`ps -ef` + `date`) before claiming a runtime witness.

Receive-drain measurements live in `probe/` and in the dated reports; they are **not** part of the app
build.

## CI

GitHub Actions: [`.github/workflows/smoke.yml`](.github/workflows/smoke.yml)

- `smoke-static` (always): required docs exist + `scripts/smoke-ui-phase0.sh`
- `smoke-host` (always): `node scripts/run-host-tests.cjs` on Node 24
- `smoke-build-harmony` (opt-in): real `hvigor` build on a self-hosted Windows HarmonyOS runner —
  enable with repository variable `HARMONYOS_SMOKE_BUILD=true`

## Known state

- Main request reliability is **PARTIAL**: request timeouts observed on the official package are not
  fully explained; see `STATUS.md`.
- No signing config, no release build, no store publication.
- Notifications/push are not implemented; they need an AGC/Push Kit track.
- `TASKS/TODO.md` is the authoritative list of open work.

## License

MIT

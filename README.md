# Telegram-HarmonyOS

Telegram client for HarmonyOS NEXT (**API 22+**), built with ArkTS/ArkUI and TDLib.

## Architecture

Clean Architecture + Redux-like state management:

```
TDLib (native) → TdGateway → MainThreadDispatcher → EventNormalizer → AppStore → UI
```

- **TdGateway** — NAPI bridge to native TDLib
- **MainThreadDispatcher** — main-thread delivery bridge
- **EventNormalizer** — raw TDLib update → typed AppEvents
- **AppStore** — serial event dispatch + immutable state updates

## Project Structure

```
entry/src/main/
├── ets/
│   ├── app/bootstrap/       # AppCoreRuntime
│   ├── core/                # events, model, reducers, store
│   ├── domain/              # selectors, usecases
│   ├── infra/               # td gateway, threading
│   ├── services/            # local config (ConfigLocal.ets)
│   ├── ui/                  # pages/components/controllers
│   └── entryability/        # EntryAbility
├── cpp/
│   ├── tdlib_napi.cpp
│   └── third_party/tdlib/   # prebuilt TDLib (gitignored)
└── resources/
```

## Security (API credentials)

Telegram credentials are loaded from:

`entry/src/main/ets/services/ConfigLocal.ets` (**gitignored**)

Setup:

1. Copy `entry/src/main/ets/services/ConfigLocal.example.ets`  
   → `entry/src/main/ets/services/ConfigLocal.ets`
2. Fill values from [my.telegram.org/apps](https://my.telegram.org/apps)

## Requirements

- DevEco Studio 5.0+
- HarmonyOS SDK **6.0.2 (API 22)** or compatible
- TDLib prebuilt binaries for HarmonyOS (`arm64-v8a`, optional `x86_64` for emulator)

## Setup

1. Clone with submodules:
   ```bash
   git clone --recursive <repo-url>
   ```
2. Configure local credentials (see section above).
3. Provide TDLib prebuilt artifacts:
   - default path: `entry/src/main/cpp/third_party/tdlib`
   - or set `TDLIB_DIR` env var before build
4. Open project in DevEco Studio and sync/build.

## Build

### DevEco Studio

- Recommended: **Build > Build Hap(s)/APP**

### Command line (hvigor)

From terminal where `hvigorw` is available:

```bash
hvigorw clean --no-daemon
hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
hvigorw assembleApp --mode project -p product=default -p buildMode=debug --no-daemon
```

### Smoke build script (PowerShell)

```powershell
./scripts/smoke-build.ps1
```

The script runs:

1. `hvigorw clean --no-daemon`
2. `hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon`

> Note: it requires DevEco/HarmonyOS command-line tooling (`hvigorw` or `hvigor`) available in `PATH`.

### Phase 0 UI smoke script (PowerShell)

```powershell
./scripts/smoke-ui-phase0.ps1
```

Checks:
- no hardcoded hex colors in shell/chatlist Phase 0 files
- `ChatListItem` uses `@Reusable`
- `ChatListPage` applies `.reuseId(...)` in `LazyForEach`

## CI

GitHub Actions workflow: `.github/workflows/smoke.yml`

- `smoke-static` (always): documentation + Phase 0 UI checks.
- `smoke-build-harmony` (optional): real `hvigor` build on a self-hosted Windows HarmonyOS runner.

To enable build job, set repository variable:

- `HARMONYOS_SMOKE_BUILD=true`

## Quick Build Checklist

- [ ] `ConfigLocal.ets` exists and contains valid `TELEGRAM_API_ID` / `TELEGRAM_API_HASH`
- [ ] `td_json_client.h` exists under `.../third_party/tdlib/include/...`
- [ ] `libtdjson.so` exists for active ABI under `.../third_party/tdlib/lib/<abi>/`
- [ ] Project opens in DevEco without dependency errors

## License

MIT

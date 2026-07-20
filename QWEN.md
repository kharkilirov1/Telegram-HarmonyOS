# QWEN.md — Context for AI Assistants

## Project Overview

**Telegram-HarmonyOS** is a native Telegram messenger client for **HarmonyOS NEXT (API 22+)**, built with **ArkTS/ArkUI** and **TDLib** (Telegram Database Library).

### Architecture

Clean Architecture with Redux-like state management:

```
TDLib (native C++) → NAPI Bridge → MainThreadDispatcher → EventNormalizer → AppStore → UI
```

**Key Components:**
- **TdGateway** — NAPI bridge to native TDLib
- **MainThreadDispatcher** — ensures all UI updates run on main thread
- **EventNormalizer** — converts raw TDLib updates to typed `AppEvent[]`
- **AppStore** — serial event dispatch with immutable state updates
- **tg_ui** — Telegram design system (atoms, molecules, tokens)

### Tech Stack

| Layer | Technology |
|-------|------------|
| **UI Framework** | ArkTS/ArkUI (HarmonyOS NEXT) |
| **Backend** | TDLib (C++) via NAPI |
| **State Management** | Custom Redux-like store |
| **Target SDK** | HarmonyOS 6.0.2 (API 22) |
| **Min SDK** | HarmonyOS 5.0.0 (API 12) |
| **Build Tool** | hvigor |
| **IDE** | DevEco Studio 5.0+ |

### Project Structure

```
Telegram-HarmonyOS/
├── entry/                          # Main application module
│   ├── src/main/
│   │   ├── cpp/
│   │   │   ├── tdlib_napi.cpp      # NAPI bridge to TDLib
│   │   │   └── third_party/tdlib/  # Prebuilt TDLib (gitignored)
│   │   ├── ets/
│   │   │   ├── app/bootstrap/      # AppCoreRuntime initialization
│   │   │   ├── core/               # events, model, reducers, store
│   │   │   ├── domain/             # selectors, usecases, ports
│   │   │   ├── infra/              # TdGateway, threading, adapters
│   │   │   ├── services/           # ConfigLocal.ets (gitignored)
│   │   │   ├── ui/
│   │   │   │   ├── pages/          # Shell pages (V1 ArkUI)
│   │   │   │   └── tg_ui/          # New design system (V2)
│   │   │   └── entryability/       # EntryAbility (UIAbility)
│   │   ├── resources/              # Strings, colors, media
│   │   └── module.json5            # Module config, permissions
│   ├── hvigorfile.ts
│   └── oh-package.json5
├── AppScope/                       # App-level config
│   └── app.json5
├── scripts/
│   ├── smoke-build.ps1             # PowerShell build script
│   └── smoke-ui-phase0.ps1         # UI parity checks
├── TASKS/
│   └── TODO.md                     # Current work items
├── docs/ai/                        # Architecture docs
├── build-profile.json5             # Build configuration
├── oh-package.json5                # Root package
└── README.md, ARCHITECTURE.md, DECISIONS.md, STATUS.md
```

## Building and Running

### Prerequisites

1. **DevEco Studio 5.0+** with HarmonyOS SDK 6.0.2 (API 22)
2. **TDLib prebuilt binaries** for HarmonyOS:
   - `arm64-v8a` (required for devices)
   - `x86_64` (optional, for emulator)
3. **Telegram API credentials** (from [my.telegram.org/apps](https://my.telegram.org/apps))

### Setup

1. **Clone with submodules:**
   ```bash
   git clone --recursive <repo-url>
   ```

2. **Configure API credentials:**
   ```bash
   # Copy example and edit
   cp entry/src/main/ets/services/ConfigLocal.example.ets \
      entry/src/main/ets/services/ConfigLocal.ets
   ```
   Fill in `TELEGRAM_API_ID` and `TELEGRAM_API_HASH`.

3. **Provide TDLib prebuilts:**
   - Default path: `entry/src/main/cpp/third_party/tdlib/`
   - Or set `TDLIB_DIR` environment variable before build

   Required structure:
   ```
   tdlib/
   ├── include/td/td_json_client.h
   └── lib/arm64-v8a/libtdjson.so
   ```

### Build Commands

#### DevEco Studio (Recommended)
- **Build → Build Hap(s)/APP**

#### Command Line (hvigor)
```bash
# Clean build
hvigorw clean --no-daemon

# Build HAP (debug)
hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon

# Build APP (debug)
hvigorw assembleApp --mode project -p product=default -p buildMode=debug --no-daemon
```

#### PowerShell Scripts
```powershell
# Full build
powershell -ExecutionPolicy Bypass -File scripts/smoke-build.ps1

# UI parity checks
powershell -ExecutionPolicy Bypass -File scripts/smoke-ui-phase0.ps1
```

### Quick Build Checklist

- [ ] `ConfigLocal.ets` exists with valid `TELEGRAM_API_ID` / `TELEGRAM_API_HASH`
- [ ] `td_json_client.h` exists under `.../third_party/tdlib/include/...`
- [ ] `libtdjson.so` exists for active ABI under `.../third_party/tdlib/lib/<abi>/`
- [ ] Project opens in DevEco without dependency errors

## Testing

```bash
# Run unit tests (Hypium framework)
hvigorw test --mode module -p product=default
```

## CI/CD

GitHub Actions workflow: `.github/workflows/smoke.yml`

- **smoke-static**: Documentation + UI shell checks (always runs)
- **smoke-build-harmony**: Real `hvigor` build on self-hosted Windows/HarmonyOS runner (optional, requires `HARMONYOS_SMOKE_BUILD=true`)

## Development Conventions

### Code Style

- **ArkTS**: Strict TypeScript with HarmonyOS SDK conventions
- **Component decorators**: `@ComponentV2` for tg_ui atoms/molecules, `@Component` for legacy V1
- **State**: Immutable updates via spread operator in reducers
- **Naming**: PascalCase for components/types, camelCase for variables/functions

### Architecture Rules

1. **Never mix V1/V2 decorators** inside the same component tree
2. **UI does not mutate domain state** — reads through AppStorage bridge or selectors
3. **TDLib callbacks** must be normalized on main thread before store dispatch
4. **Token-first design**: Colors, spacing, typography belong in `TgUiTokens.ets`, not inline
5. **Reusable lists**: `@Reusable` for V1 list rows, `@ReusableV2` for V2

### tg_ui Component Lifecycle

```
SPEC (docs/ai/*.md) → DEMO (*Demo.ets) → ATOM (*Page.ets) → INTEGRATION
```

Every reusable component should have:
- Passport spec in `ui/tg_ui/spec/`
- Demo screen in `ui/tg_ui/demos/`
- Atom implementation in `ui/tg_ui/atoms/` or `molecules/`

### Visual Reference

UI porting is anchored to **Telegram iOS**. Shipped runtime screenshots/video are the visual truth; current public source is in `C:\Refs\Telegram\Telegram-iOS-current`. The complete external registry is `REFERENCES.md`.

## Key Documentation

| File | Purpose |
|------|---------|
| `README.md` | Quick start, build instructions |
| `ARCHITECTURE.md` | Runtime topology, layer map, state model |
| `DECISIONS.md` | Accepted architectural decisions (D1-D10) |
| `STATUS.md` | Current snapshot, recent changes, device verification queue |
| `TASKS/TODO.md` | Active work items, verification checklist |
| `docs/ai/MASTER_PLAN_TELEGRAM_UI.md` | Frozen UI contract |
| `docs/ai/AI_MEMORY.md` | Operator rules, context |

## Current State (2026-03-18)

### Working Features

- ✅ EntryAbility boots AppCoreRuntime
- ✅ TDLib bridge via NAPI
- ✅ Event pipeline: gateway → dispatcher → normalizer → store → UI
- ✅ Auth/login shell
- ✅ Chat list with tg_ui components
- ✅ Chat screen with TgChatTopBar, TgMessageRouter, TgComposerInput
- ✅ Media gallery + inline video + GIF (Phase 1)
- ✅ Grouped photo albums (2-5+ photos)
- ✅ Voice/audio playback with waveform
- ✅ Document bubbles with progress
- ✅ Profile pages (user/group/channel)
- ✅ Tab bar with glass material

### tg_ui Inventory

- **31 atoms** (TgTabBar, TgTopBar, TgSearchBar, TgChatRow, TgChatTopBar, TgMessageRouter, TgComposerInput, TgPhotoBubble, TgVideoBubble, TgGroupedPhotoBubble, TgAudioBubble, TgVoiceBubble, TgDocumentRow, TgInstantVideoBubble, TgMediaGalleryPage, TgInlineVideoView, TgAnimationBubble, etc.)
- **2 molecules**
- **35 demos**
- **38 spec files**

### Pending Device Verification

Many features are **build-verified** but need **device/emulator verification**:
- Search/top-bar parity (active search, cancel flow, title ellipsis)
- Media gallery + inline video + GIF playback
- Tab bar material + selected pill
- Voice/audio playback pipeline
- Grouped photo albums
- Document bubbles
- Long-press context menu (Reply/Copy)

See `STATUS.md` and `TASKS/TODO.md` for detailed verification checklists.

## Secrets and Local Config

**Never commit credentials.** The following files are gitignored:

- `entry/src/main/ets/services/ConfigLocal.ets` — Telegram API credentials
- `local.properties` — Local SDK paths
- `entry/src/main/cpp/third_party/tdlib/` — TDLib prebuilts

## Common Issues

### Build fails with "td_json_client.h not found"
→ Ensure TDLib prebuilts are in `entry/src/main/cpp/third_party/tdlib/include/td/`

### Runtime error: "libtdjson.so not found"
→ Check `entry/src/main/cpp/third_party/tdlib/lib/<abi>/` for your target ABI

### Chat list shows empty bubbles
→ Verify TDLib credentials and network connectivity

### Media viewers don't open
→ Check `bindContentCover` removal — viewers are now direct overlays in root `Stack`

### Composer input not focusable
→ Ensure `HitTestMode.Block` is not applied to wrapper (review hotfix 2026-03-18)

## Agent Execution Plan

For new AI assistant sessions, follow the execution order in:
- `TASKS/AGENT_EXECUTION_PLAN.md`

Key principles:
1. Read before edit
2. Minimal changes, match existing style
3. Verify with build/test before claiming success
4. Device verification is mandatory for UI changes
5. Keep legacy and tg_ui paths parallel until acceptance gates pass

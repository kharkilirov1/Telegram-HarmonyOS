# Telegram-HarmonyOS

Telegram client for HarmonyOS NEXT (API 12+), built with ArkTS/ArkUI and TDLib.

## Architecture

Clean Architecture + DDD + Redux-like state management:

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  pages/ components/ (ArkUI @Component, @State, @Link)       │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                      Domain Layer                            │
│  usecases/ selectors/ (business logic, state queries)       │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                       Core Layer                             │
│  store/ reducers/ events/ model/ (Redux pattern)            │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                  Infrastructure Layer                        │
│  td/gateway/ threading/ (TDLib NAPI bridge, Emitter)        │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                     Native Layer (C++)                       │
│  tdlib_napi.cpp → TDLib (Telegram MTProto)                  │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow

```
TDLib (native) → TdGateway → MainThreadDispatcher → EventNormalizer → AppStore → UI
```

1. **TdGateway** — NAPI bridge to native TDLib
2. **MainThreadDispatcher** — Emitter-based thread switching (background → main)
3. **EventNormalizer** — Converts raw TDLib updates to typed AppEvents
4. **AppStore** — Redux-like store with serial dispatch queue
5. **Reducers** — Pure functions updating immutable state

## Project Structure

```
entry/src/main/
├── ets/
│   ├── app/bootstrap/       # AppCoreRuntime (pipeline orchestrator)
│   ├── core/
│   │   ├── events/          # EventNormalizer
│   │   ├── model/           # AppState, AppEvent, DTOs
│   │   ├── reducers/        # dialogsReducer, messagesReducer, usersReducer
│   │   ├── store/           # AppStore (Redux-like)
│   │   └── utils/           # tdAccessors, stateClone, LRU cache
│   ├── domain/
│   │   ├── selectors/       # State queries (selectOrderedChats, etc.)
│   │   └── usecases/        # Business logic (sendMessage, loadChats)
│   ├── infra/
│   │   ├── td/gateway/      # TdGateway (TDLib NAPI wrapper)
│   │   └── threading/       # MainThreadDispatcher (Emitter bridge)
│   ├── models/td/           # TDLib type definitions
│   ├── presentation/        # UI pages and components
│   └── entryability/        # UIAbility entry point
├── cpp/
│   └── tdlib_napi.cpp       # NAPI bridge to TDLib
└── resources/               # Strings, colors, media
```

## Key Features

- **ArkTS Compliant** — No indexed access, no `in` operator, explicit types
- **Thread-Safe** — All UI updates on main thread via Emitter
- **Immutable State** — Pure reducers, no mutations
- **Type-Safe** — TdObject wrapper for TDLib JSON access
- **Memory Efficient** — LRU cache for messages

## Prerequisites

- DevEco Studio 5.0+
- HarmonyOS SDK (API 12+)
- TDLib compiled for HarmonyOS (ARM64)
- Telegram API credentials from [my.telegram.org](https://my.telegram.org)

## Setup

1. Clone with submodules: `git clone --recursive`
2. Copy `ConfigLocal.example.ets` to `ConfigLocal.ets` and add your API credentials
3. Build TDLib for HarmonyOS using the NDK
4. Open in DevEco Studio and build

## License

MIT

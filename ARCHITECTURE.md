# ARCHITECTURE — Telegram-HarmonyOS

Last updated: 2026-03-07

## 1. Scope
- Telegram client for **HarmonyOS NEXT / API 22+**
- UI built in **ArkTS/ArkUI**
- Telegram backend integration via **TDLib** through a native **NAPI** bridge
- Primary target devices from `entry/src/main/module.json5`: `phone`, `tablet`, `2in1`

## 2. Runtime topology

```text
EntryAbility (UIAbility / Stage Model)
  -> AppCoreRuntime.initialize()
    -> TdGateway (NAPI bridge to TDLib)
    -> MainThreadDispatcher
    -> EventNormalizer
    -> AppStore (serial reducer pipeline)
    -> AppStoreBridge (AppStore -> AppStorage)
    -> UseCases / Selectors
    -> ArkUI pages and tg_ui components
```

### Command flow

```text
UI action
  -> UseCase
  -> AppCommand
  -> TdGatewayAdapter
  -> CommandSerializer
  -> TdGateway.send()
  -> tdlib_napi.cpp
  -> TDLib
```

### Update flow

```text
TDLib callback
  -> MainThreadDispatcher
  -> TdGateway.handleUpdateOnMainThread()
  -> EventNormalizer
  -> AppStore.dispatch()/dispatchBatch()
  -> AppStoreBridge / selectors
  -> UI rebuild
```

## 3. HarmonyOS application shell
- `entry/src/main/module.json5`
  - `mainElement = EntryAbility`
  - `routerMap = $profile:route_map`
- `entry/src/main/ets/entryability/EntryAbility.ets`
  - implements the **UIAbility** entry point in the **Stage Model**
  - initializes `AppCoreRuntime` in `onCreate()`
  - loads `ui/pages/login/LoginRouterPage` in `onWindowStageCreate()`
  - sets fullscreen/system bar policy and keyboard avoid mode

Grounding from official docs:
- **UIAbility** lifecycle is the core Stage Model UI entry pattern.
- **NavPathStack** is the navigation controller object for `Navigation`/`NavDestination`.

## 4. Layer map

```text
entry/src/main/ets/
├── app/
│   ├── bootstrap/   # runtime orchestration
│   └── bridge/      # AppStore -> AppStorage bridge
├── core/
│   ├── events/      # EventNormalizer and domain normalizers
│   ├── invariants/  # dev-mode state checks
│   ├── model/       # AppState, AppEvent, AppCommand, DTOs, errors
│   ├── reducers/    # Redux-like state transitions
│   ├── sideeffects/ # auth side effects
│   ├── store/       # serial AppStore
│   └── utils/       # td accessors, cloning, caches, resources
├── domain/
│   ├── ports/       # gateway interfaces
│   ├── selectors/   # derived state
│   └── usecases/    # loadChats, openChat, sendMessage, markChatRead, ...
├── infra/
│   ├── td/          # gateway, adapter, serializer
│   └── threading/   # MainThreadDispatcher
├── entryability/    # EntryAbility
├── models/          # TDLib types and wrappers
├── services/        # local config such as ConfigLocal.ets
└── ui/
    ├── pages/       # shell pages, still mostly V1 components
    ├── components/  # legacy / auth components
    ├── controllers/ # login and UI controllers
    ├── theme/       # older theme layer
    └── tg_ui/       # new token-first Telegram UI system
```

## 5. State model
- Single source of truth: `AppStore`
- Reducer-driven immutable updates
- Serial dispatch queue to avoid race conditions and recursive dispatch

Main state buckets:
- `auth`
- `connection`
- `chats`
- `messages`
- `users`

The UI does not mutate domain state directly. It reads through:
- AppStorage keys from `AppStoreBridge`
- selectors
- view-model builders such as `ChatItemVO` / `ChatTimelineVO`

## 6. UI architecture

### Current split
- **Shell pages** under `ui/pages/*` are still mostly **V1** ArkUI components.
- **tg_ui** is the newer Telegram design system and component library.

### Current active tg_ui runtime path
- `TgTabBar`
- `TgTopBar`
- `TgSearchBar`
- `TgChatRow`
- `TgChatTopBar`
- `TgMessageRouter`

### Component strategy
- `tg_ui/atoms` and `tg_ui/molecules` are the reusable visual system.
- `tg_ui/spec/*.md` are component passports.
- `tg_ui/demos/*Demo.ets` are state-matrix demo screens.
- `TgUiTokens.ets` is the design-token source of truth.

## 7. ArkUI boundaries that matter in this repo
- `@ComponentV2` is used for most tg_ui atoms/molecules.
- V1 and V2 decorators must not be mixed inside one component tree carelessly.
- `TgChatRow` is intentionally kept as **V1 `@Reusable`** because `ChatListPage` is still V1.
- `LazyForEach` is the list virtualization primitive currently used for chat lists.
- If a future migration moves list rows to `@ComponentV2`, reuse rules change to `@ReusableV2` semantics.

## 8. Threading and safety invariants
- TDLib callbacks are normalized onto the **main thread** before reducers/UI access.
- `AppStorage` is treated as UI-facing state; background work should move DTOs, not UI storage objects.
- `LoadChatHistoryUseCase` and `LoadChatsUseCase` keep static caches and must be reset on runtime shutdown.
- `EntryAbility.onMemoryLevel()` can clear caches and downgrade glass mode under memory pressure.

## 9. External/runtime dependencies
- Telegram credentials: `entry/src/main/ets/services/ConfigLocal.ets` (**gitignored**)
- Example config: `ConfigLocal.example.ets`
- TDLib prebuilts: `entry/src/main/cpp/third_party/tdlib`
- Build tooling: DevEco Studio / `hvigorw`

## 10. Canonical docs
- Operator rules: `AGENTS.md`
- Current state: `STATUS.md`
- Accepted choices: `DECISIONS.md`
- Current work: `TASKS/TODO.md`
- Deep migration history:
  - `docs/ai/AI_MEMORY.md`
  - `docs/ai/UI_MIGRATION_PLAN.md`
  - `docs/ai/ATOM_ROADMAP.md`
  - `docs/ai/MASTER_PLAN_TELEGRAM_UI.md`

## 11. Sources used for this file
- `README.md`
- `PROJECT_ANALYSIS.md`
- `docs/ai/AI_MEMORY.md`
- `entry/src/main/module.json5`
- `entry/src/main/ets/entryability/EntryAbility.ets`
- `entry/src/main/ets/app/bootstrap/AppCoreRuntime.ets`
- `entry/src/main/ets/core/store/AppStore.ets`
- HarmonyOS docs: `UIAbility`, `NavPathStack`, `LazyForEach`, `@ComponentV2`, `@ReusableV2`

# ARCHITECTURE — Telegram-HarmonyOS

Last updated: 2026-10-01

## 1. Scope
- Telegram client for **HarmonyOS NEXT / API 23+** in the current forward HDS shell branch
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

### Photo album dispatch

Existing 2–10 photo selection -> ChatPhotoAlbumController -> captured media use-case album getter -> SendMediaAlbumUseCase -> typed SendMediaAlbumCommand -> serializer sendMessageAlbum. Every local copy precedes the sole dispatch; route/account/permission/input revision guards own completion. Strict messages acceptance and explicit repeated-selection confirmation preserve TDLib upload/update ownership. See `docs/reviews/2026-10-01-photo-album-sending.md`.

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
    ├── pages/       # active shell/chat pages use V2
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
- **Shell pages** under `ui/pages/*` are now largely **`@ComponentV2`** ArkUI pages.
- **tg_ui** is the Telegram design system/component library layered on top of that V2 runtime.

### Active chat screen ownership
- `ui/pages/chat/TgChatScreenPage.ets` owns one stable `ChatScreenSession` and `ChatScreenViewState`; its 164 lines wire destination/lifecycle and UI composition.
- Six readonly `@ObservedV2` slices preserve all 112 former reactive fields and add canonical composer `isSending` (113 total `@Trace`): chrome, composer, panels, timeline, media, pinned/search. `ChatScreenContext` keeps operational handles/controllers and direct typed aliases to this one state; `UIContext`/navigation callbacks are lazy.
- `ChatScreenSession` initializes context and exposes typed delegates. Cohesive route/lifecycle, timeline/history, composer/interaction, media/playback, panels/catalog and pinned/search modules own algorithms through narrow ports. The combined port exists only at composition. Store subscription, account/route/generation ownership and timeline transaction remain singular.
- Seven V2 visual children own timeline viewport/row, composer, keyboard panels, popup, pinned/gallery composition. They receive observed slices and UI-only typed callbacks, without store/gateway/use-case/subscription access. `ChatScrollPositionCache` preserves the prior shared stable-key lifetime.
- `ChatTimelineDataSource.applyDiff` snapshots the old array before in-place prepend so old positions/length and anchor tail remain stable. This is a separately tested baseline bug correction, not another timeline owner.
- Source/body/composition parity and SDK gates: `docs/reviews/2026-10-01-chat-screen-decomposition.md`. No `presentation/viewmodels` layer was introduced.

### Pinned request ownership
- `ChatPinnedMessagesCoordinator` captures the existing `ChatScreenRouteParams` and its gateway. `LoadPinnedMessagesUseCase.executeSingle` keeps fallback on that captured gateway; legacy convenience helpers remain compatible.
- Initial, fallback and page operations validate route object/chat/lifecycle/current account scope/lease before dispatch and every success/error publication. No new registry, store owner, subscriptions or Session interface was added.
- Refresh invalidates page request/cursor; each page also captures its base summary request. Superseded callbacks cannot merge into a replacement snapshot or clear a newer busy flag. Evidence and acceptance limits: `docs/reviews/2026-10-01-pinned-account-ownership.md`.

### Targeted timeline updates and scroll intent
- `ChatTimelineDataSource` keeps stable identity separate from stamped render identity. Its ordered reconciliation removes absent rows descending, inserts ascending and notifies changed retained rows; invalid/ambiguous keys, retained reorder and no common stable identity fall back to reload. Protected existing fast paths and content comparator remain unchanged.
- `ChatTimelineTransactionCoordinator` captures the visible stable anchor/prefix before projection application and arms the existing viewport guard/pagination block when that prefix changes. Native List maintains surviving content position; no manual compensation, new Context field or queue owner was introduced.
- Append follow captures the old last-visible END gap and rechecks direction/range in the existing lifecycle-owned timer. Existing ordinary user-edge pagination and user unlock remain reachable.
- Native acceptance is bounded to real List/Scroller with synthetic simple V2 rows; production bubble/media geometry, deleted anchors and authenticated flows are separate QA. Evidence: `docs/reviews/2026-10-01-chat-timeline-updates.md`.

### Read-path gateway error causes
- `TdGatewayAdapter` preserves typed `AppError` after stale-client validation; untyped failures retain legacy wrapping. `INVALID_COMMAND` is UNKNOWN/non-retryable; warming/not-initialized remains retryable and retired clients remain terminal.
- `LoadChats` retains kind/code/retryability and technical detail; TDLib404 means list exhaustion. `LoadChatHistory` preserves typed causes after its request-owner check.
- `ChatInitialHistoryCoordinator` uses readonly capture/current identity methods derived from existing lifecycle/window/bucket sequence maps. Both callbacks require a newly reserved current identity; terminal/auth/rate-limit errors retire only owned fallback intent/timers. No Context counter, new registry/store owner or transport lifecycle was added.
- This accepts the bounded read path; send/forward error and TDLib406 policy remain separate. Evidence: `docs/reviews/2026-10-01-gateway-error-causes.md`.

### Ordered photo selection and preparation
- `ChatComposerState.pendingAttachmentUris` owns ordered identity for 1–10 photos. `TgPhotoSelectionPreview` owns only viewed URI and emits remove/move callbacks through existing binding/Session to guarded ComposerController setters; no store/backend access.
- Operational sending aliases canonical `@Trace isSending`. Captured input revision, current mode/permission, route/account/usecase guards fence async picker, preparation and accepted cleanup. Single and album photos share bounded consumed-URI overlap confirmation; album dispatch remains one TDLib request.
- `ChatAttachmentFilePreparer` owns unique staged paths and real native source FD finally. The default protected exact-handle observer is empty and exists for strict native verification; it does not replace native file operations. Unsubmitted files are discarded, submitted upload paths retained.
- Native synthetic IO/UI and source ownership evidence: `docs/reviews/2026-10-01-photo-selection-preview.md`; provider/delivery/Dock/iOS acceptance remains separate.

### Current active tg_ui runtime path
- **Root shell:** API23 `HdsTabs` + `HdsNavigation` in `MainTabsPage`; the old custom `TgTabBar` is no longer the active smoke contract in this forward branch. The HDS root tab bar must collapse while `navigationUIState.chatScreenVisible` is true so pushed chat detail screens keep their own bottom composer unobstructed.
- **Chats tab:** `TgChatListNavigationBar`, `TgChatRow`, `TgChatTopBar`, `TgMessageRouter`.
- **Secondary tabs:** `ContactsPage`, `CallsPage`, and `SettingsPage` are hosted under the HDS root navigation/tab shell while their Telegram-specific page content remains project-owned.
- The live Chats shell uses stock ArkUI `Search` inside `TgChatListNavigationBar`; standalone search/tab-bar wrapper atoms are not the current root-shell boundary.

### Target upper-chrome architecture
- The target upper Telegram chrome is now explicitly treated as a **layered V2 composition**, not a single bar widget.
- Desired ownership split:
  - **screen/page** owns safe-area values, derived title/search/accessory state, and placement
  - **composition atoms** (`TgChatListNavigationBar`, `TgChatTopBar`) own content layout
  - **shared visual primitive** owns blur/tint/top-edge emphasis
- Canonical detailed note: `docs/ai/UPPER_CHROME_V2_ARCHITECTURE.md`

### Component strategy
- `tg_ui/atoms` and `tg_ui/molecules` are the reusable visual system.
- `tg_ui/spec/*.md` are component passports.
- `tg_ui/demos/*Demo.ets` are state-matrix demo screens.
- `TgUiTokens.ets` is the design-token source of truth.

## 7. ArkUI boundaries that matter in this repo
- `@ComponentV2` is used across the active page/component runtime.
- V1 and V2 decorators must still not be mixed carelessly inside one component tree.
- `TgChatRow` is already a **`@ComponentV2`** row in the live chat-list path.
- `LazyForEach` is the list virtualization primitive currently used for chat lists, and `ChatListPage` still applies `.reuseId(...)` on row instances.
- A future performance modernization pass can still evaluate `Repeat` + `.reuse(...)` + `@ReusableV2`, but that is now an optimization topic rather than a migration blocker.

## 8. Threading and safety invariants
- TDLib callbacks are normalized onto the **main thread** before reducers/UI access.
- Native receive uses a four-batch/16MiB UTF8 ledger covering waiting, admitted and actively parsed payloads. Exact epoch/batch consumed ACK releases credit only after references are cleared and synchronous dispatch or explicit retirement completes. Batch hard cap is8MiB/50 responses; one bounded builder and one lookahead are separate. These limits do not bound total RSS, TDLib/VM/store memory or asynchronous downstream enrichment.
- TSFN carries nullptr wakes, with queue size1 and one unretired wake lease (physical queued+executing may reach2). Pre-JS conversion retains the front batch for at most3 paced attempts without a pending exception. Possible JS invocation is never replayed; ambiguous notification failure is terminal, while known queue-full may retry without read-ahead.
- Stop closes new submission admissions and cancels bounded ownership. An already admitted API call retains its lease; completion waits for off-owner producer join, actual TSFN finalization and retirement of control/submission work. Cleanup failures retain owner/barrier rather than reporting success; null-env delivery returns before context access.
- Gateway establishes receive ownership before allocating its TDLib client ID. Ordinary shutdown keeps private delivery/draining alive until that client reports actual Closed, even after application dispatcher detachment. Close timeout retains the owner; native stop or close Ok alone does not prove client release. Terminal bridge fault retains a live client and rejects dispatched requests with unknown outcome, with no automatic resend/replacement.
- Generation-tagged queued/active batches preserve authoritative Closed while retiring stale ordinary traffic. Reentrant Closed defers active credit release until synchronous transfer unwinds. Monotonic watchdog/status diagnostics use method/stage/code/counters and synthetic correlation.
- Real-module receive/ACK/stop and ordinary async main-Ability retirement are verified on the isolated emulator bundle. Owned-runtime/Worker cleanup probes are separate; active framework-main napi_env fallback remains runtime-unverified. See docs/reviews/2026-10-15-receive-stabilization.md.
- `AppStorage` is treated as UI-facing state; background work should move DTOs, not UI storage objects.
- `LoadChatHistoryUseCase` and `LoadChatsUseCase` keep static caches and must be reset on runtime shutdown.
- `EntryAbility.onMemoryLevel()` can clear caches and downgrade glass mode under memory pressure.

- Mutating use-cases preserve typed errors and add per-request write-outcome provenance. Explicit request rejection is distinct from timeout/retirement/malformed response; only a valid Message in the target chat establishes acceptance for sending.
- Existing composer owner delegates text to ChatTextSendController; it keeps bounded uncertain-intent counters, native explicit resend consent and revision/lifecycle guards. Forward ownership restores only known untouched intent; accepted comments are never replayed. Photo rejection removes only the current operation marker.
- Code406 is gated before application message access, rendering or error payload logging, including nested send-failed normalization. Safe code/identity bookkeeping remains; upstream TDLib native logging is a separate boundary. Evidence: `docs/reviews/2026-10-02-send-forward-errors.md`.

## 9. External/runtime dependencies
- Telegram credentials: `entry/src/main/ets/services/ConfigLocal.ets` (**gitignored**)
- Example config: `ConfigLocal.example.ets`
- TDLib prebuilts: `entry/src/main/cpp/third_party/tdlib`
- Build tooling: DevEco Studio / `hvigorw`

## 10. Canonical docs
- Operator rules: `AGENTS.md`
- External reference registry and pinned revisions: `REFERENCES.md`
- Current state: `STATUS.md`
- Accepted choices: `DECISIONS.md`
- Current work: `TASKS/TODO.md`
- Deep migration history:
  - `docs/ai/AI_MEMORY.md`
- `docs/ai/UI_MIGRATION_PLAN.md`
- `docs/ai/ATOM_ROADMAP.md`
- `docs/ai/MASTER_PLAN_TELEGRAM_UI.md`
- `docs/ai/UPPER_CHROME_V2_ARCHITECTURE.md`

## 11. Sources used for this file
- `README.md`
- `PROJECT_ANALYSIS.md`
- `docs/ai/AI_MEMORY.md`
- `entry/src/main/module.json5`
- `entry/src/main/ets/entryability/EntryAbility.ets`
- `entry/src/main/ets/app/bootstrap/AppCoreRuntime.ets`
- `entry/src/main/ets/core/store/AppStore.ets`
- `entry/src/main/ets/ui/pages/MainTabsPage.ets`
- `entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets`
- `entry/src/main/ets/ui/tg_ui/atoms/TgChatListNavigationBar.ets`
- `scripts/smoke-ui-phase0.ps1`
- `scripts/smoke-build.ps1`
- HarmonyOS docs: `UIAbility`, `NavPathStack`, ArkUI `Search` `onChange/onSubmit`, `@ComponentV2`, `Repeat`/`reuseId` patterns

## Sequential document/video write ownership - 2026-10-02

The existing ChatComposerController composes ChatSequentialMediaController (252 lines) for already available document/video commands. One existing busy operation spans preparation and sequential writes. Strict accepted Message validation remains in the unchanged media use-case; the helper retires only its owned first URI after that acceptance, advances its expected input snapshot through the existing setters and consumes the first caption/reply once. Counted bounded URI marks require real native consent before overlapping uncertain resend. The prepared-file owner discards only unsubmitted or explicitly rejected copies. Route/account/lifecycle/use-case/input changes retire continuations; late document/camera picker results are equally guarded. ChatScreenContext advances its existing composer revision only on actual forward-mode boolean changes. No new global owner, retry queue, codec/media capability or dependency is introduced. Report: `docs/reviews/2026-10-02-document-video-resend.md`.

## Timed slow-mode ownership - 2026-10-03

Strict Supergroup/FullInfo DTOs feed an immutable account-scoped slow-mode map through normalization/events/reducer. Relative expiry anchors once to receipt STARTUP uptime. ChatSlowmodeController owns the route timer and traced countdown; ChatPermissionCoordinator computes fresh dispatch eligibility. Permission capability stays independent from temporary cooldown so accepted cleanup can complete. Singleflight hydration guards captured access/snapshot identity and performs one bounded fresh fetch when superseded. Typed foreground and route hide/show/teardown pause/recompute without autosend. Dock/atom display the countdown; final controller gates cover asynchronous sends and voice preview. Test-only `prepare-native-main-witness.cjs` creates an isolated SDK projection with shared main-module callbacks/fixtures and unchanged production Resource widgets; it never edits source/main metadata.

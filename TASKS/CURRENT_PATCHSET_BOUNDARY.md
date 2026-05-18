# CURRENT PATCHSET BOUNDARY — active snapshot

Last updated: 2026-05-01

## Active Phase 2 consolidation snapshot (2026-05-01)

Phase 2 is active. The current job is no longer to mine Phase 1 for more generic runtime guards; it is to turn the mixed working tree into a coherent, reviewable, commit-ready boundary.

### Current working-tree shape
- `git status --short` currently reports:
  - `84` modified entries
  - `15` deleted entries
  - `39` untracked entries/directories
- This is a broad mixed batch, not a clean single-atom patch.
- The known `scripts/smoke-build.ps1` failure is the external user-level Hvigor cache `ENOENT`; report it as build-proof blocker, not as a reason to keep Phase 1 open.

### Provisional review grouping
1. **Runtime/navigation stabilization**
   - Modified tracked app/runtime files:
     - `entry/src/main/ets/app/bootstrap/AppCoreRuntime.ets`
     - `entry/src/main/ets/app/bootstrap/SmokeTest.ets`
     - `entry/src/main/ets/app/bridge/AppStoreBridge.ets`
   - Modified tracked core/store files:
     - `entry/src/main/ets/core/sideeffects/AuthSideEffect.ets`
     - `entry/src/main/ets/core/store/AppStore.ets`
   - Modified tracked domain/usecase files:
     - `entry/src/main/ets/domain/usecases/downloadAvatars.ets`
     - `entry/src/main/ets/domain/usecases/downloadMessageMedia.ets`
     - `entry/src/main/ets/domain/usecases/loadChatHistory.ets`
     - `entry/src/main/ets/domain/usecases/loadChats.ets`
     - `entry/src/main/ets/domain/usecases/openChat.ets`
   - Modified tracked Stage Model / infra files:
     - `entry/src/main/ets/entryability/EntryAbility.ets`
     - `entry/src/main/ets/infra/td/gateway/TdGateway.ets`
     - `entry/src/main/ets/infra/threading/MainThreadDispatcher.ets`
   - Modified tracked active UI page files:
     - `entry/src/main/ets/ui/pages/MainTabsPage.ets`
     - `entry/src/main/ets/ui/pages/calls/CallsPage.ets`
     - `entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets`
     - `entry/src/main/ets/ui/pages/chat/TgVideoPlayerPage.ets`
     - `entry/src/main/ets/ui/pages/chat/VoicePlaybackController.ets`
     - `entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets`
     - `entry/src/main/ets/ui/pages/contacts/ContactsPage.ets`
     - `entry/src/main/ets/ui/pages/login/CodeInputPage.ets`
     - `entry/src/main/ets/ui/pages/login/LoginRouter.ets`
     - `entry/src/main/ets/ui/pages/login/LoginRouterPage.ets`
     - `entry/src/main/ets/ui/pages/login/PasswordInputPage.ets`
     - `entry/src/main/ets/ui/pages/login/PhoneInputPage.ets`
     - `entry/src/main/ets/ui/pages/login/QrLoginPage.ets`
     - `entry/src/main/ets/ui/pages/login/RegistrationPage.ets`
     - `entry/src/main/ets/ui/pages/profile/TgProfilePage.ets`
     - `entry/src/main/ets/ui/pages/settings/SettingsPage.ets`
   - Untracked active UI page files/directories:
     - `entry/src/main/ets/ui/pages/chat/PendingForwardTransfer.ets`
     - `entry/src/main/ets/ui/pages/forward/TgForwardTargetPickerPage.ets`
   - Boundary note: this grouping currently has `29` modified tracked files and `2` exact untracked active UI page files. `TgChatScreenPage.ets`, `ChatListPage.ets`, `PendingForwardTransfer.ets`, and `TgForwardTargetPickerPage.ets` also participate in the forward/cross-chat slice below, so review those hunks with explicit overlap awareness rather than treating either grouping as fully independent.
2. **Forward/cross-chat navigation slice**
   - Modified tracked files:
     - `entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets`
     - `entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets`
     - `entry/src/main/resources/base/profile/route_map.json`
   - Untracked files/directories:
     - `entry/src/main/ets/ui/pages/chat/PendingForwardTransfer.ets`
     - `entry/src/main/ets/ui/pages/forward/TgForwardTargetPickerPage.ets`
   - Boundary note: `git status --short` currently reports the picker as the untracked directory `entry/src/main/ets/ui/pages/forward/`, and that directory currently contains exactly one file. `TgChatScreenPage.ets` and `ChatListPage.ets` are shared navigation files, so review their forward/cross-chat hunks together with the runtime/navigation stabilization slice if the patch is not split by hunk.
3. **tg_ui component/demo/token polish**
   - Modified tracked non-demo files:
     - `entry/src/main/ets/ui/tg_ui/spec/TgAnimationBubble.md`
     - `entry/src/main/ets/ui/tg_ui/atoms/TgComposerInput.ets`
     - `entry/src/main/ets/ui/tg_ui/spec/TgComposerInput.md`
     - `entry/src/main/ets/ui/tg_ui/spec/TgTextBubbleV3.md`
     - `entry/src/main/ets/ui/tg_ui/spec/TgVideoBubble.md`
     - `entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets`
   - Modified tracked demo files:
     - `entry/src/main/ets/ui/tg_ui/demos/TgAnimationBubbleDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgAudioBubbleDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgAvatarDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgCallRowDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgChatListNavigationBarDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgChatMetaDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgChatRowDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgChatTopBarDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgComposerInputDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgCountryRowDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgCountrySectionHeaderDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgCountrySelectionScreenDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgDateSeparatorDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgDocumentRowDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgFilterBarDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgGroupedPhotoBubbleDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgIconDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgInstantVideoBubbleDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgMediaBubbleShellV2Demo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgMessageBubbleBaseDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgMessageBubbleDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgMessageMetaDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgMessageRouterDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgMessageTextBodyV2Demo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgMessageTextRulesDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgMessageTimeContractDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgPhotoBubbleDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgReplySnippetDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgSearchBarDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgSettingsRowDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgStickerViewDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgTabBarDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgTextBubbleV2Demo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgTextBubbleV3Demo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgTopBarDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgTopChromeBackgroundDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgUnreadBadgeDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgVideoBubbleDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgVoiceBubbleDemo.ets`
   - Untracked new spec files:
     - `entry/src/main/ets/ui/tg_ui/spec/TgMediaGalleryPage.md`
     - `entry/src/main/ets/ui/tg_ui/spec/TgContactBubble.md`
     - `entry/src/main/ets/ui/tg_ui/spec/TgLocationBubble.md`
     - `entry/src/main/ets/ui/tg_ui/spec/TgPollBubble.md`
   - Untracked new demo files:
     - `entry/src/main/ets/ui/tg_ui/demos/TgMediaGalleryPageDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgContactBubbleDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgLocationBubbleDemo.ets`
     - `entry/src/main/ets/ui/tg_ui/demos/TgPollBubbleDemo.ets`
   - Boundary note: this grouping currently has `45` modified tracked files and `8` untracked tg_ui files. Direct public passport/demo gaps are now covered at artifact level; review/behavior follow-ups remain and are not permission to reopen broad UI rewrites.
4. **Test-suite modernization**
   - Deleted tracked legacy ohosTest files:
     - `entry/src/ohosTest/ets/test/CallsController.test.ets`
     - `entry/src/ohosTest/ets/test/ChatService.test.ets`
     - `entry/src/ohosTest/ets/test/ContactsController.test.ets`
     - `entry/src/ohosTest/ets/test/FileController.test.ets`
     - `entry/src/ohosTest/ets/test/MessageUtils.test.ets`
     - `entry/src/ohosTest/ets/test/MessagesController.test.ets`
     - `entry/src/ohosTest/ets/test/NotificationCenter.test.ets`
     - `entry/src/ohosTest/ets/test/PreferencesService.test.ets`
     - `entry/src/ohosTest/ets/test/ProxyService.test.ets`
     - `entry/src/ohosTest/ets/test/SecurityService.test.ets`
     - `entry/src/ohosTest/ets/test/SessionService.test.ets`
     - `entry/src/ohosTest/ets/test/StoriesController.test.ets`
     - `entry/src/ohosTest/ets/test/TdFallbackRegistry.test.ets`
     - `entry/src/ohosTest/ets/test/TdUpdateParser.test.ets`
     - `entry/src/ohosTest/ets/test/UserService.test.ets`
   - Modified tracked retained/current ohosTest files:
     - `entry/src/ohosTest/ets/test/AppError.test.ets`
     - `entry/src/ohosTest/ets/test/List.test.ets`
   - Untracked new ohosTest files:
     - `entry/src/ohosTest/ets/test/AppStateModels.test.ets`
     - `entry/src/ohosTest/ets/test/ChatTimelineVO.test.ets`
    - `entry/src/ohosTest/ets/test/ChatCommands.test.ets`
    - `entry/src/ohosTest/ets/test/FilePipeline.test.ets`
    - `entry/src/ohosTest/ets/test/LoadCalls.test.ets`
    - `entry/src/ohosTest/ets/test/MessageDtoParser.test.ets`
    - `entry/src/ohosTest/ets/test/MessagesReducer.test.ets`
    - `entry/src/ohosTest/ets/test/StateClone.test.ets`
    - `entry/src/ohosTest/ets/test/TextEngine.test.ets`
    - `entry/src/ohosTest/ets/test/UserDto.test.ets`
  - Untracked new local test directory:
    - `entry/src/test/List.test.ets`
  - Boundary note: this grouping currently has `15` deleted tracked legacy test files, `2` modified tracked retained/current test files, and `11` exact untracked replacement/local test files. `AppError.test.ets` has been reintroduced as a current core-model classifier test, `LoadCalls.test.ets` now covers part of the current Calls use-case surface, `ChatCommands.test.ets` covers the active chat command factory surface that replaced legacy chat-service method-existence checks, `UserDto.test.ets` covers the current user DTO parser/update surface for part of the legacy Contacts row, and `FilePipeline.test.ets` covers the current file update/download event pipeline for part of the legacy FileController row; the remaining deletion group still needs row-by-row replacement/de-scope rationale before acceptance.
5. **Heartbeat/runtime-sweep tooling**
   - `scripts/codex-heartbeat.ps1`
   - `scripts/install-codex-heartbeat.ps1`
   - `scripts/read-codex-heartbeat.ps1`
   - `scripts/remove-codex-heartbeat.ps1`
   - `scripts/smoke-codex-heartbeat-last-message-rotation.ps1`
   - `scripts/smoke-read-codex-heartbeat-exit-marker-boundary.ps1`
   - `scripts/smoke-read-codex-heartbeat-false-positive.ps1`
   - `scripts/smoke-read-codex-heartbeat-missing-during-newer-run.ps1`
   - `scripts/smoke-read-codex-heartbeat-network-failure.ps1`
   - `scripts/check-forward-runtime-sweep.ps1`
   - `scripts/new-forward-runtime-sweep-results.ps1`
   - `scripts/read-forward-runtime-sweep.ps1`
   - `scripts/smoke-forward-runtime-sweep-packet.ps1`
   - `scripts/validate-forward-runtime-sweep-result.ps1`
   - `TASKS/FORWARD_RUNTIME_SWEEP_CHECKLIST.md`
   - `TASKS/FORWARD_RUNTIME_SWEEP_RESULTS_TEMPLATE.md`
   - `TASKS/runtime-sweeps/README.md`
   - `TASKS/runtime-sweeps/fixtures/forward-runtime-sweep-fixture-invalid.md`
   - `TASKS/runtime-sweeps/fixtures/forward-runtime-sweep-fixture-pass.md`
   - Boundary note: all files in this grouping are currently untracked and should be reviewed/accepted as one tooling slice or intentionally deferred as one slice.
6. **Docs/index wrapper**
   - Modified tracked files:
     - `.gitignore`
     - `STATUS.md`
     - `TASKS/AGENT_EXECUTION_PLAN.md`
     - `TASKS/CURRENT_PATCHSET_BOUNDARY.md`
     - `TASKS/LESSONS.md`
     - `TASKS/TODO.md`
   - Untracked files:
     - `index.html`
   - Boundary note: this wrapper currently has `6` modified tracked files and `1` untracked file. `DECISIONS.md`, `ARCHITECTURE.md`, `README.md`, `docs/ai/AI_MEMORY.md`, and `docs/ai/UI_MIGRATION_PLAN.md` are not currently dirty in this wrapper; runtime-sweep docs and tg_ui specs are accounted for in their own slices above.

### tg_ui spec/demo coverage audit
- Component inventory from `entry/src/main/ets/ui/tg_ui/`:
  - `40` atom files
  - `2` molecule files
  - `43` demos
  - `45` specs, excluding the passport template
- Components still requiring direct public coverage or helper-parent acceptance decisions:
  - direct spec+demo added, still awaiting review/acceptance:
    - `TgContactBubble`
    - `TgLocationBubble`
    - `TgMediaGalleryPage`
    - `TgPollBubble`
  - helper candidates without standalone spec/demo:
    - `TgInlineVideoView`
    - `TgTextBodyV3`
- Previous direct audit gaps now tracked by the classification table below:
  - `TgContactBubble`
  - `TgInlineVideoView`
  - `TgLocationBubble`
  - `TgMediaGalleryPage`
  - `TgPollBubble`
  - `TgTextBodyV3`
- Contract/orphan artifacts to keep but not confuse with direct component passports:
  - specs: `TgChatScreenIntegration`, `TgGlassPolicy`, `TgMessageTextRules`, `TgTokens`
  - demos: `TgMessageBubble`, `TgMessageTextRules`, `TgMessageTimeContract`

### tg_ui direct spec/demo gap classification
- Source of this classification: local component and usage inspection only; no new ArkUI code or visual acceptance is claimed here.
- Classification rule: components routed directly as message/page surfaces need direct passport/demo coverage; implementation helpers may be accepted without standalone passport/demo only when the parent atom/page spec explicitly owns their contract.

| Component | Usage evidence | Classification | Next action |
| --- | --- | --- | --- |
| `TgContactBubble` | Exported atom used directly by `TgMessageRouter` for contact messages; inline comment references `ChatMessageContactBubbleContentNode`. | Direct public message bubble | Passport and demo added; still needs normal review/visual acceptance and explicit action-event ownership before behavior parity. |
| `TgInlineVideoView` | Exported atom used by `TgAnimationBubble`, `TgVideoBubble`, and `TgMediaGalleryPage`; not routed directly by message router. | Internal/helper candidate | Parent-contract notes added for `TgVideoBubble` and `TgAnimationBubble`; full-screen/gallery usage is owned by the `TgMediaGalleryPage` contract. |
| `TgLocationBubble` | Exported atom used directly by `TgMessageRouter` for location/venue messages; inline comment references `ChatMessageMapBubbleContentNode`. | Direct public message bubble | Passport and demo added; still needs normal review/visual acceptance and explicit map snapshot/open-location ownership before behavior parity. |
| `TgMediaGalleryPage` | Exported page-like atom used directly by `TgChatScreenPage` for media gallery presentation. | Direct page/integration surface | Page-level passport/contract and demo added; still needs normal review/visual acceptance before full coverage is accepted. |
| `TgPollBubble` | Exported atom used directly by `TgMessageRouter` for polls; `TgPollOptionVO` is imported by demos. | Direct public message bubble | Passport and demo added; still needs normal review/visual acceptance and explicit vote/view-results/quiz-solution ownership before behavior parity. |
| `TgTextBodyV3` | Exported helper used only by `TgTextBubbleV3`; `TgTextBubbleV3.md` now owns its text-body helper contract. | Internal/helper candidate | Parent-contract note and parent-demo rich-entity/collapsed-quote coverage added; still needs normal review/visual acceptance before full helper coverage is accepted. |

### Phase 2 next safe moves
1. Exact-list consolidation is now complete for the provisional broad groupings; next work should choose one follow-up rather than expand the batch.
2. For tg_ui, direct public passport/demo gaps and the named `TgTextBodyV3` parent-demo gap are now covered at artifact level; remaining tg_ui work is review/visual acceptance or a newly identified narrow gap, not another broad sweep.
3. For test-suite modernization, the current replacement-suite ownership checkpoint plus the `AppError.test.ets` classifier replacement, partial `LoadCalls.test.ets` Calls replacement, `ChatCommands.test.ets` chat-command replacement, partial `UserDto.test.ets` Contacts/user parser replacement, and partial `FilePipeline.test.ets` file-pipeline replacement are documented; next work should resolve the remaining pending/partial deleted-test rows one narrow row or feature family at a time before accepting the deletion group.
4. For runtime/navigation, use the existing hunk-aware review notes during any acceptance/split decision; do not reopen runtime work unless a concrete regression is named.

### Test-suite modernization replacement map draft
- Current retained test registry: `entry/src/ohosTest/ets/test/List.test.ets` imports `MessagesReducer`, `MessageDtoParser`, `StateClone`, `ChatTimelineVO`, `TextEngine`, `AppStateModels`, `AppError`, `LoadCalls`, `ChatCommands`, `UserDto`, and `FilePipeline`.
- Current local test wrapper: `entry/src/test/List.test.ets` re-exports the retained ohosTest registry.
- Acceptance rule: rows marked `Pending` or `Partial` are not acceptance of the deleted legacy tests; they identify the exact replacement/gap decision needed before the deletion group can be accepted.

Current replacement-suite ownership checkpoint:
- `MessagesReducer.test.ets` owns reducer-level content mapping and state mutation coverage for the current `AppState` message path.
- `MessageDtoParser.test.ets` owns current TDLib `MessageContentType` / DTO defaults and `parseMessageContent` coverage for active message content families.
- `StateClone.test.ets` owns immutable clone coverage for current state slices and guards against shared mutable state after reducer updates.
- `ChatTimelineVO.test.ets` owns current chat timeline/view-model projection coverage, including sender color and message-entry construction behavior.
- `TextEngine.test.ets` owns current text measurement/wrapping helpers, especially CJK and layout behavior; it is not a replacement for legacy URL/domain helper tests.
- `AppStateModels.test.ets` owns current model-default coverage for entities, quote metadata, message content, and other state DTO classes.
- `AppError.test.ets` owns the current `core/model/AppError` constructor defaults plus `classifyTdlibError` coverage for network/init/destroyed-client, auth, rate-limit/FLOOD_WAIT, common TDLib 400, 5xx, and unknown fallback mappings.
- `LoadCalls.test.ets` owns current Calls use-case model/command coverage for `LoadCallsParams`, `CallHistoryRecord`, `LoadCallsResult`, and `createSearchCallMessagesCommand`; it does not yet replace the private TDLib call-message parsing, missed-call direction, hydration, or sorting behavior.
- `ChatCommands.test.ets` owns the active chat command factory surface for load/open/close, mute/unmute, pin/unpin, delete history, unread toggle, forward messages, and search messages, replacing legacy chat-service singleton/API-existence checks for currently implemented chat actions.
- `UserDto.test.ets` owns current TDLib user parsing/update coverage for status mapping, direct/editable username, user flags, profile-photo extraction, safe defaults, and `applyUserUpdate`; it does not yet replace ContactsPage private contact sorting/view-model behavior.
- `FilePipeline.test.ets` owns current file update/download pipeline coverage for `updateFile` normalization, transfer-progress reducer state, completed local-path propagation to users/chats/messages, unmatched completion no-ops, and `downloadFile` command payloads; it does not recreate the obsolete private file-path LRU helper.
- Non-coverage note: service/controller singleton tests for Preferences, Proxy, Security, Session, Stories, User, and legacy notification/fallback registries remain pending architecture deletion rationale or feature-specific replacement tests. Contacts and Files are only partially covered through current DTO/pipeline rows. This checkpoint documents ownership only; it does not accept those deletions.

| Legacy test row | Legacy surface observed from HEAD | Current replacement coverage | Acceptance note |
| --- | --- | --- | --- |
| `AppError.test.ets` | TDLib error classification and flood-wait parsing | Reintroduced at `entry/src/ohosTest/ets/test/AppError.test.ets` against current `core/model/AppError` and registered in `List.test.ets` | Resolved for current classifier-unit coverage; this is not runtime/device proof. |
| `CallsController.test.ets` | Call model parsing and missed-call filtering | `LoadCalls.test.ets` now covers current `LoadCalls` params/record/result defaults and search-call command payload construction | Partial: current private TDLib call-message parsing, missed-call direction derivation, hydration, and sorting remain untested. |
| `ChatService.test.ets` | Legacy `ChatService` singleton/API surface | `ChatCommands.test.ets` covers the active command factories used by current usecase/gateway architecture for implemented chat actions | Partial/architecture-delete: singleton service is intentionally absent, but legacy group-creation/admin methods are not current implemented behavior and remain future/de-scope decisions. |
| `ContactsController.test.ets` | User parsing, contact sorting, and legacy `User` model defaults | `UserDto.test.ets` covers current TDLib user status/field/flag parsing, editable username fallback, profile-photo extraction, safe defaults, and `applyUserUpdate`; `AppStateModels.test.ets` covers current `User` model defaults | Partial: ContactsPage private contact sorting/view-model behavior remains untested and needs a deliberate seam or scoped de-scope decision. |
| `FileController.test.ets` | File-controller LRU cache behavior | `FilePipeline.test.ets` covers current `updateFile` normalization, transfer reducer state, completed local-path propagation to users/chats/messages, unmatched completion no-op behavior, and `createDownloadFileCommand` payloads | Partial/architecture-delete: the old private file-path LRU cache helper is not a current public seam and remains an explicit follow-up/de-scope decision. |
| `MessageUtils.test.ets` | URL detection/domain extraction/split helpers | `TextEngine.test.ets` covers text layout/CJK behavior only | Partial: URL/domain helper behavior is not replaced. |
| `MessagesController.test.ets` | Waveform decoding, message previews, dialog sorting, and TD message helpers | `MessageDtoParser`, `MessagesReducer`, `ChatTimelineVO`, and `TextEngine` cover parser/reducer/view-model/text portions | Partial: waveform and dialog-sort behaviors are not direct replacements. |
| `NotificationCenter.test.ets` | Legacy observer bus singleton/post/remove behavior | Old import target absent at checked legacy path; no direct new registry coverage | Pending architecture deletion rationale or event-bus replacement test. |
| `PreferencesService.test.ets` | Settings persistence/defaults via preferences store | None in current new registry | Pending settings persistence coverage decision. |
| `ProxyService.test.ets` | Proxy singleton and proxy-type parameter construction | Old import target absent at checked legacy path; no direct new registry coverage | Pending proxy feature coverage decision. |
| `SecurityService.test.ets` | Key generation and encrypt/decrypt round trips | None in current new registry | Pending security/storage coverage decision. |
| `SessionService.test.ets` | Session singleton existence | Old import target absent at checked legacy path; no direct new registry coverage | Pending auth/session architecture deletion rationale. |
| `StoriesController.test.ets` | Story model parsing, unread state, and sorting | None in current new registry | Pending/future Stories coverage decision. |
| `TdFallbackRegistry.test.ets` | Unknown TD update/content fallback registry | Old import target absent at checked legacy path; no direct new registry coverage | Pending observability/fallback coverage decision. |
| `TdUpdateParser.test.ets` | `updateChatIsMarkedAsUnread` parser | `MessageDtoParser` / `MessagesReducer` cover adjacent DTO/reducer behavior only | Partial: explicit update-parser behavior is not directly replaced. |
| `UserService.test.ets` | Legacy `UserService` singleton/API surface | Old import target absent at checked legacy path; no direct new registry coverage | Pending user/account service replacement decision. |

### Runtime/forward hunk-aware review notes
- Purpose: prevent the runtime/navigation stabilization slice and the forward/cross-chat slice from being reviewed as independent when several files carry hunks for both concerns.
- Source of this note: local `git diff` / file inspection only; no device/emulator behavior is claimed here.

| File | Runtime/navigation stabilization hunks | Forward/cross-chat hunks | Review note |
| --- | --- | --- | --- |
| `entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets` | Owns chat-screen lifecycle cleanup, active-chat mirror sync, profile push containment, back-pop readiness/rollback, duplicate-close guard, and `openChat` data refresh hooks. | Imports `TgForwardTargetPickerPage`, uses `pendingForwardTransfer`, consumes pending transfers on appear, opens the forward target picker, stages target-chat mirrors, pushes target `TgChatScreenPage`, and rolls back target push failures. | Review by hunk: back/profile/active-chat ownership belongs to runtime stabilization; picker/result/target-chat push belongs to forward slice. Shared AppStorage/nav mirrors must stay consistent across both. |
| `entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets` | Owns root visible-boundary cleanup, active-chat context clearing, nav-lock reset, duplicate/deferred open guards, route-open staging, and push-failure rollback. | Shares the same `TgChatScreenPage` route-open path used by forwarded target chats after the forward callback requests target chat data. | Review with chat-screen forward hunks because both write `ACTIVE_CHAT_*`, `CHAT_SCREEN_VISIBLE`, and `CHAT_NAV_LOCK_UNTIL`. |
| `entry/src/main/ets/ui/pages/chat/PendingForwardTransfer.ets` | None; this is not a general runtime primitive. | Untracked forward handoff store with `arm`, `consumeFor`, and `clear`, copying message ids and clearing invalid/consumed payloads. | Review wholly with the forward/cross-chat slice; runtime reviewers only need to know `TgChatScreenPage` consumes it once per target chat. |
| `entry/src/main/ets/ui/pages/forward/TgForwardTargetPickerPage.ets` | Uses navigation-stack readiness, local `isClosing`, lifecycle token, and load-chats use case cleanup patterns that mirror runtime stabilization conventions. | Untracked forward picker route/page, search/filter UI, result pop contract, cancel/back pop path, and duplicate result/cancel guard. | Review primarily with the forward slice, but keep the pop readiness/duplicate-close patterns aligned with runtime navigation guards. |
| `entry/src/main/resources/base/profile/route_map.json` | Adds route-map entries required for system route construction of `TgChatScreenPage` and `TgProfilePage`. | Adds the `TgForwardTargetPickerPage` route-map entry used by forward picker pushes. | Review as a navigation contract file shared by runtime route setup and forward picker routing. |

---

## Historical boundary snapshot (2026-03-08)

## Purpose
Freeze a reviewable boundary for the current working tree now that the log-driven runtime stabilization pass is materially successful.

## Phase status
- **Phase 1 — Runtime stabilization:** exit condition is effectively met from current local evidence.
- **Phase 2 — Consolidate current working batch:** active now.

## Included in the current stabilization batch

### A. Runtime/core stabilization
Primary scope:
- `entry/src/main/ets/app/bootstrap/AppCoreRuntime.ets`
- `entry/src/main/ets/core/store/AppStore.ets`
- `entry/src/main/ets/domain/usecases/loadChats.ets`
- `entry/src/main/ets/domain/usecases/loadChatHistory.ets`
- `entry/src/main/ets/domain/usecases/openChat.ets`
- `entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets`
- `entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets`
- related reducer / normalizer / TD wrapper fixes that were required to make those flows truthful

This slice now covers:
- runtime reset / static cache reset
- guarded chat reopen flow
- stable `LazyForEach` keys
- restore-scroll pagination guards
- edge re-entry pagination latches
- history sender hydration widening
- direct TDLib `user.id` top-level parsing fix

### B. tg_ui support artifacts already part of the current runtime path
These files belong to the same review batch because the current shell/chat path already depends on them or claims them in docs:
- `entry/src/main/ets/ui/tg_ui/atoms/TgChatTopBar.ets`
- `entry/src/main/ets/ui/tg_ui/spec/TgCallRow.md`
- `entry/src/main/ets/ui/tg_ui/spec/TgChatTopBar.md`
- `entry/src/main/ets/ui/tg_ui/spec/TgSearchBar.md`
- `entry/src/main/ets/ui/tg_ui/spec/TgSettingsRow.md`
- `entry/src/main/ets/ui/tg_ui/spec/TgTabBar.md`
- `entry/src/main/ets/ui/tg_ui/demos/TgCallRowDemo.ets`
- `entry/src/main/ets/ui/tg_ui/demos/TgChatTopBarDemo.ets`
- `entry/src/main/ets/ui/tg_ui/demos/TgMessageBubbleBaseDemo.ets`
- `entry/src/main/ets/ui/tg_ui/demos/TgMessageRouterDemo.ets`
- `entry/src/main/ets/ui/tg_ui/demos/TgSearchBarDemo.ets`
- `entry/src/main/ets/ui/tg_ui/demos/TgSettingsRowDemo.ets`
- `entry/src/main/ets/ui/tg_ui/demos/TgTabBarDemo.ets`

### C. Documentation / smoke sync
Also included in the current batch:
- root memory pack (`STATUS.md`, `DECISIONS.md`, `ARCHITECTURE.md`, `TASKS/*`)
- `README.md`
- `docs/ai/AI_MEMORY.md`
- `docs/ai/UI_MIGRATION_PLAN.md`
- `scripts/smoke-ui-phase0.ps1`
- `scripts/smoke-ui-phase0.sh`
- `.github/workflows/smoke.yml`

## Explicitly not included in this batch
These stay for later phases even if the working tree already contains related groundwork:
- **Phase 4:** real Calls data flow
- **Phase 5:** media behavior completion beyond current rendering/runtime fixes
- **Phase 6:** V1 -> V2 modernization / `LazyForEach -> Repeat` / `@ReusableV2`
- any destructive cleanup of legacy fallback paths

### Historical cleanup note (2026-03-22)
- The runtime no longer depends on `TgContactRow` / `TgSettingsSection`, and their orphaned demo/spec artifacts were deleted after verification/doc sync.

## Verification snapshot for this boundary
- `./scripts/smoke-ui-phase0.ps1` — pass
- `bash ./scripts/smoke-ui-phase0.sh` — pass
- `./scripts/smoke-build.ps1` — pass (via discovered DevEco wrapper at `C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat`)
- Latest confirming HiLog:
  - `HiLog-Mate 80 Pro-All logs of selected app-[27274]com.telegram.harmonyos-DEBUG-1772921231953.txt`
- Latest verified runtime outcomes from that log:
  - `Message references non-existent user` = `0`
  - `lastMessage is older than newest message in map` = `0`
  - `Loading older messages` = `0`
  - `Loading newer messages` = `0`
- Remaining verification blocker:
  - no longer local build-tool discovery; the next real gap for later work is device/runtime verification of newer post-boundary phases such as Calls

## Recommended commit-ready grouping
If/when the user asks to commit, keep the boundary understandable:
1. runtime stabilization core
2. tg_ui support artifacts already used by the active runtime path
3. docs + smoke sync

Do **not** mix future Calls/media/V2-modernization work into this batch.

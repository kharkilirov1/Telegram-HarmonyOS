# LESSONS — repeated mistakes and project-specific pitfalls

Last updated: 2026-05-18

## 1. Do not mix V1 and V2 ArkUI decorators casually
- `tg_ui` is `@ComponentV2`.
- Active shell pages are `@ComponentV2`.
- The live chat-list row path uses `TgChatRow` as `@ComponentV2`.
- Mixing these layers incorrectly is a reliable way to break hvigor builds.

## 2. `LazyForEach` reuse rules are not interchangeable between V1 and V2
- Current chat list path relies on `LazyForEach` + `.reuseId(...)` with a V2 row component.
- Official docs treat `@ReusableV2` as a different model for V2 components.
- Do not mechanically replace V1 reuse patterns with V2 ones.

## 3. One separator system per list
- Chat rows already carry their own separator strategy.
- Do not enable both row separators and `List.divider` at the same time.

## 4. Safe area and glass bars must be explicit
- Use avoid-area / safe-area helpers for top bar and bottom tab overlap.
- Blur/glass visuals are acceptable only if interaction zones remain safe.

## 5. Runtime reset must clear static caches
- `LoadChatHistoryUseCase` and `LoadChatsUseCase` maintain cross-call/static state.
- If runtime shutdown does not reset them, reopened sessions can behave as if data is already loaded or still in-flight.

## 6. AppStorage is UI-facing state, not background worker state
- TDLib callbacks and reducer/UI work land on the main thread.
- Background paths should move DTOs/data, not mutate AppStorage directly.

## 7. Historical names in docs can be stale
- `AppTopBar`, `AppTabBarItem`, `ChatListItem` still appear in older docs.
- Current runtime path is tg_ui-first for shell/chat screens.
- When docs conflict, trust current code + `MASTER_PLAN_TELEGRAM_UI.md` + `STATUS.md`.

## 8. Token drift creates fake "almost Telegram" UI
- Hex colors and local geometry must move into `TgUiTokens.ets` / resources.

## 9. iOS reference must be inspected before non-trivial UI work
- The project aims for Telegram iOS visual fidelity.
- Skipping iOS source inspection leads to wrong spacing, hierarchy, and state coverage.

## 10. Keep fallback paths until acceptance gates are actually passed
- Deleting legacy/fallback code too early makes regressions harder to isolate.

## 11. `LazyForEach` keys must be persistent, not order-derived
- Use stable dialog identity (`chatId`) for the item key.
- Appending the current index causes unnecessary row churn during reordering.

## 12. Programmatic chat restore can trip `List.onScrollIndex`
- Use `onDidScroll` + `ScrollState` to unlock pagination only after a real user scroll.

## 13. Edge pagination must auto-recheck after fetch, not require scroll-away
- iOS Telegram uses continuous checking (threshold = 5 items, no latch).
- After each `loadOlder`/`loadNewer`, call `recheckPaginationEdge()`.

## 14. Navigation-title weight should approximate iOS semibold
- `FontWeight.Medium` is the safer approximation for centered navigation titles.

## 15. History sender hydration caps must cover the whole default page
- `getChatHistory` batches can contain more than 8 distinct authors in a group.
- Keep sender-hydration cap high enough to cover the default history page size.

## 16. Generic regex field extraction can pick nested `id` values
- `TdObject.getNumber('id')` is unsafe for payloads like TDLib `user`.
- For identity-bearing payloads, prefer explicit top-level extraction (`getTopLevelNumber`).

## 17. Freeze a patchset boundary as soon as the HiLog loop turns green
- Write down what belongs to current stabilization batch vs. later work.

## 18. Direct TDLib responses with `@extra` do not update the store by themselves
- Use cases receiving direct responses must manually normalize and dispatch.

## 19. `getChat` needs a direct `chat` normalizer path
- Direct TDLib `getChat` responses have type `chat`; without a handler they don't populate state.

## 20. DevEco hvigor can exist locally even when `PATH` says otherwise
- Default path: `C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat`
- Build smoke scripts should probe the default DevEco install path.

## 21. TDLib `getChatHistory` short batches are ambiguous
- Official TDLib docs allow fewer messages than requested even when more history exists.
- `messageCount < limit` must NOT immediately flip `canLoadOlder=false`.

## 22. Do not render a tiny initial batch as if it were stable chat history
- Defer committing suspiciously tiny initial batches until the top-up completes.

## 23. One top-up can still be too shallow for Telegram history
- Use a bounded top-up loop while oldest-message progress continues.

## 24. In `LazyForEach`, mutable content must not be part of item identity
- Keep identity stable by dialog id (`chatId`); avoid broad reuse pools.

## 25. Prefer stock ArkUI components over thin wrapper atoms
- Custom atoms that only wrap a stock component with token styling add no real value.
- Only create an atom when it adds genuine logic: enums, computed state, composite layout.
- Use stock ArkUI components directly with token styling inline for new screens.

## 26. Avatar photos are the single biggest "demo vs real app" visual signal
- TDLib provides `file.id` in `profile_photo.small` but does NOT auto-download.
- Priority: implement `downloadFile` flow before any further UI polish work.

## 27. File download architecture: cross-cutting reducer for fileId→path mapping
- `updateFile` from TDLib only carries `file.id` + `local.path` — no entity context.
- The `filesReducer` scans `users` and `chats` maps for matching `photoSmallFileId` on `fileDownloaded`.

## 28. TDLib file objects: `getNumber('id')` fails due to nested `remote.id` string
- Use `getTopLevelNumber('id')` which does character-by-character parsing respecting JSON nesting depth.

## 29. `JSON.stringify(TdObject)` produces empty/truncated output — use native accessors
- Never `JSON.stringify` a TdObject for data extraction. Always use `.getString()` / `.getNumber()` / `.getBool()` / `.getObject()` API.

## 30. (deleted — merged into #29)

## 31. Scroll compensation for prepend must be synchronous
- Call `scrollToIndex` synchronously right after `applyDiff()`.
- Using `setTimeout(16ms)` creates a visible 1-frame shift/flicker.

## 32. Pagination latch pattern is unnecessary overhead
- Neither Android nor iOS Telegram use a latch for pagination.
- `recheckPaginationEdge()` provides continuous loading without latches.

## 33. Prepend scroll compensation: pre-capture + viewport freeze + cascade block
- Save indices AND yOffset BEFORE `applyDiff`.
- Freeze viewport with immediate `scrollTo({ yOffset, animation: false })`.
- Block cascade: set `blockAutoPaginationUntilUserScroll = true` during prepend.

## 34. Prefer ArkUI native `maintainVisibleContentPosition(true)` over custom prepend scroll hacks
- Keep the native flag on for chat history lists.

## 35. Do not mix `onDatasetChange` with `onDataAdd/onDataDelete/onDataChange` in one LazyForEach datasource
- Keep one notification family per datasource.

## 36. Never recheck pagination synchronously in the same promise `finally` that dispatches history
- Schedule edge recheck to the next tick; retry after diff has settled.

## 37. Media status controls need explicit state machines
- Telegram iOS models media controls as explicit states (download, progress, play, pause).
- Map each bubble's control to a finite state machine, not ad-hoc branches.

## 38. Determinate media progress should imply an active transfer
- `downloadProgress in [0, 1)` counts as active even if `isDownloading` is false.

## 39. Composer accessory panels belong inside the text capsule
- iOS places panels inside `textInputContainerBackgroundView`, not as separate floating capsules.

## 40. Platform root tab bars must collapse on detail routes
- When chat detail is visible: HDS bar height, margin, mask, and opacity collapse to 0.

---

## Review-driven additions (2026-05-18)

## 41. Map-based dispatch beats chained if/else for method routing
- `TdGateway.getMethodTimeout()` used 8 if/else branches mapping methods to timeouts.
- Replaced with `Record<string, number>` + `??` default — O(1) lookup, adds a new method without growing the function body.

## 42. Docs files grow without bound if every task appends status entries
- `STATUS.md` reached 1220+ lines, `LESSONS.md` reached 527+ entries, `TODO.md` 428KB.
- These files should be working snapshots, not changelogs. The git history is the changelog.
- Trim aggressively. If a doc exceeds ~200 lines, consolidate or archive.

## 43. Large page files are the first architectural smell to address
- `TgChatScreenPage.ets` at 3094 lines mixes subscriptions, 6 use cases, composer, emoji panel, gallery, navigation, voice playback, and context menu.
- A page this size is impossible to review, hard to test, and prone to merge conflicts.
- Decompose before adding more features: ViewModel + Controller + Panel sub-components.

## 44. Direct TDLib adapter responses are `TdObject`, not plain records
- `TdGatewayAdapter.send()` returns the `TdObject` from the gateway as `Object`.
- Do not cast direct TDLib responses to `Record<string, Object>` and index into them.
- Use `TdObject` accessors (`getObject`, `getString`, `getBool`, `getNumber`) for direct responses too.

## 45. ArkTS object literal restrictions affect controller extraction
- Do not return ad-hoc object-literal host adapters from component methods; ArkTS rejects untyped object literals.
- Prefer explicit host methods on the component and pass `this` to extracted controllers.
- Avoid host method names that collide with `@Local` field names.

## 46. Command serializers should be handler-dispatched, not switch-owned
- Keep each TDLib command serializer in a small handler function.
- Register handlers by command type so adding a command does not grow one high-conflict switch body.

## 47. Side-effect tests need explicit seams
- Pure use cases can be tested with a fake `TdGatewayPort`.
- `AuthSideEffect` currently couples to singleton TD gateway and app context; keep basic seam tests local until a richer injectable runtime seam exists.

## 48. Debounced search belongs outside the page body
- Keep timer ownership and stale-result guards in a controller.
- Let the page expose only active chat id, query state, and message-id scrolling.

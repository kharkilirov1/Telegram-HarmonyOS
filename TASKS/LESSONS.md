# LESSONS — repeated mistakes and project-specific pitfalls

Last updated: 2026-04-08

## 1. Do not mix V1 and V2 ArkUI decorators casually
- `tg_ui` is largely `@ComponentV2`.
- Active shell pages are now largely `@ComponentV2`.
- The live chat-list row path already uses `TgChatRow` as `@ComponentV2`, not as a V1 `@Reusable` exception.
- Mixing these layers incorrectly is a reliable way to break hvigor builds.

## 2. `LazyForEach` reuse rules are not interchangeable between V1 and V2
- Current chat list path relies on `LazyForEach` + `.reuseId(...)` with a V2 row component.
- Official docs treat `@ReusableV2` as a different model for V2 components.
- Do not mechanically replace V1 reuse patterns with V2 ones.

## 3. One separator system per list
- Chat rows already carry their own separator strategy.
- Do not enable both row separators and `List.divider` at the same time.
- This already caused double-divider style regressions before.

## 4. Safe area and glass bars must be explicit
- Earlier shell passes had top content sliding under the status bar.
- Use avoid-area / safe-area helpers for top bar and bottom tab overlap.
- Blur/glass visuals are acceptable only if interaction zones remain safe.

## 5. Runtime reset must clear static caches
- `LoadChatHistoryUseCase` and `LoadChatsUseCase` maintain cross-call/static state.
- If runtime shutdown does not reset them, reopened sessions can behave as if data is already loaded or still in-flight.

## 6. AppStorage is UI-facing state, not background worker state
- The project architecture expects TDLib callbacks and reducer/UI work to land on the main thread.
- Background paths should move DTOs/data, not mutate AppStorage directly.

## 7. Historical names in docs can be stale
- `AppTopBar`, `AppTabBarItem`, `ChatListItem`, and old feature-flag notes still appear in older docs.
- Current runtime path is tg_ui-first for shell/chat screens.
- When docs conflict, trust current code + `MASTER_PLAN_TELEGRAM_UI.md` + `STATUS.md`.

## 8. Token drift creates fake “almost Telegram” UI
- Earlier phases had hex colors and local geometry leaking into components.
- The project only stays coherent when values move into `TgUiTokens.ets` / resources.

## 9. iOS reference must be inspected before non-trivial UI work
- The project is not aiming for generic HarmonyOS styling.
- Skipping iOS source inspection leads to wrong spacing, wrong hierarchy, and wrong state coverage.

## 10. Keep fallback paths until acceptance gates are actually passed
- This branch regularly carries many in-flight changes.
- Deleting legacy/fallback code too early makes visual regressions and navigation bugs harder to isolate.

## 11. `LazyForEach` keys must be persistent, not order-derived
- HarmonyOS key generation rules expect a unique **persistent** key per item, not a key that changes when the list reorders.
- In chat lists, use stable dialog identity (`chatId`) for the item key; appending the current index causes unnecessary row churn during incoming-message reordering and hurts reuse stability.

## 12. Programmatic chat restore can trip `List.onScrollIndex`
- In `TgChatScreenPage`, a programmatic `scrollToIndex()` used for unread-boundary or saved-position restore can still lead to later `onScrollIndex` callbacks near the top edge.
- Use `onDidScroll` + `ScrollState` to unlock pagination only after a real user scroll; otherwise the restored `start < 10` state can trigger an unwanted `loadOlder` storm on chat open/reopen.

## 13. Edge pagination must auto-recheck after fetch, not require scroll-away
- The original latch pattern required the user to scroll away from the edge and back to trigger the next page load. iOS Telegram uses **continuous checking** (threshold = 5 items, no latch).

## 14. Navigation-title weight should approximate iOS semibold, not generic bold
- Telegram iOS chat-list and chat top bars often sit closer to `17pt semibold` than to a heavier full bold title.
- In ArkUI, `FontWeight.Medium` is the safer approximation for these centered navigation titles unless the local reference clearly shows a heavier treatment.
- After each completed `loadOlder`/`loadNewer`, call `recheckPaginationEdge()` to see if the viewport is still near the edge; if so, re-arm and fire the next batch automatically.
- This gives iOS-like continuous loading without removing the anti-spam latch for normal scroll events.

## 14. History sender hydration caps must cover the whole default page
- `getChatHistory` batches can easily contain more than 8 distinct `messageSenderUser` authors in a group/channel page.
- If pre-dispatch hydration stops too early, `assertInvariants()` reports residual `Message references non-existent user` warnings even though the fix is in the right pipeline.
- Keep the sender-hydration cap high enough to cover the default history page size, or HiLog noise will persist after the scroll/pagination bugs are already fixed.

## 15. Generic regex field extraction can pick nested `id` values
- `TdObject.getNumber('id')` is unsafe for payloads like TDLib `user`, because nested keys such as `profile_photo.id` can appear before the real top-level `id`.
- This showed up as impossible `getMe resolved` values and as `getUser` hydrations that succeeded transport-wise but still stored users under the wrong key, leaving `Message references non-existent user` soft invariants unresolved.
- For identity-bearing payloads, prefer explicit top-level extraction over generic nested-key matching.

## 16. Freeze a patchset boundary as soon as the HiLog loop turns green
- Once the active runtime regressions reach a clear verified state (`missing-user = 0`, `stale-lastMessage = 0`, `older/newer storm = 0`), stop poking Phase 1 opportunistically.
- Write down what belongs to the current stabilization batch vs. later Calls/media/V2 work, otherwise the branch turns back into an unreviewable moving pile.

## 17. Attempt the build gate immediately, even if the likely blocker is environmental
- After runtime/log validation turns green, do not just assume the build blocker is unchanged — run the build smoke entry point and capture the exact current failure text.
- In this repo the correct blocker wording is currently that `hvigorw` / `hvigor` is missing from `PATH`; recording that precisely keeps later sessions from re-investigating already-known uncertainty.

## 18. Direct TDLib responses with `@extra` do not update the store by themselves
- `TdGateway` resolves pending requests with `@extra` directly to the caller and does **not** forward those payloads through the normal AppCoreRuntime update pipeline.
- If a use case depends on direct responses such as `getUser`, `getChat`, or future `search*` helpers, it must manually run `getEventNormalizer().normalize(response)` and `store.dispatchBatch(events)` when store state needs to change.

## 19. `getChat` needs a direct `chat` normalizer path, not only update handlers
- Before Phase 4 calls work, `ChatNormalizer` only handled `updateNewChat` / partial chat updates.
- Direct TDLib `getChat` responses have type `chat`; without a `chat` handler they do not populate `state.chats.chats`, which breaks later peer/title resolution for features that hydrate chats on demand.

## 20. DevEco hvigor can exist locally even when `PATH` says otherwise
- On this machine the working wrapper is `C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat`.
- `where hvigor` / `where hvigorw` can still return nothing because DevEco does not add that wrapper directory to `PATH` by default.
- Build smoke scripts should probe the default DevEco install path instead of assuming global PATH setup is complete.

## 21. TDLib `getChatHistory` short batches are ambiguous, not end-of-history proof
- Official TDLib docs explicitly allow `getChatHistory` to return **fewer messages than requested**, even when more history still exists.
- In this repo that means `messageCount < limit` must **not** immediately flip `canLoadOlder=false` / `canLoadNewer=false`; otherwise a chat can open with a tiny first batch and then look “fully loaded” when it is not.
- Safer rule here: treat empty or no-progress pagination responses as end-of-history, and use at most one controlled older top-up when the very first default batch is suspiciously tiny.

## 22. Do not render a tiny initial batch as if it were stable chat history
- After the short-batch data fix, the user could still briefly see a false intermediate UI state (for example one message or `No messages yet`) before the controlled top-up arrived.
- For first-open history loads, defer visibly committing suspiciously tiny initial batches until the top-up completes, and keep a loading placeholder on the chat screen while the initial timeline is still settling.

## 23. One top-up can still be too shallow for Telegram history
- Real device HiLogs showed chats where the first default batch was `1` message and the first older top-up only added **one more** message, while `canLoadOlder` still remained true.
- Therefore the initial stabilization path should use a **bounded top-up loop** while oldest-message progress continues, instead of assuming a single extra request is enough.

## 24. In `LazyForEach`, mutable content must not be part of item identity

- Chat list regressions reappeared when `getChatListKey()` started including mutable row fields (`title`, `preview`, `unreadCount`, avatar path) and `reuseId` was collapsed into coarse buckets.
- For reusable Telegram rows, keep identity stable by dialog id (`chatId`) and avoid broad reuse pools that let unrelated rows share one cached component shape.
- If title updates are partial/empty (`updateChatTitle`), block empty overwrite in normalizer/reducer; otherwise list identity churn and placeholder rows amplify each other.

## 25. Prefer stock ArkUI components over thin wrapper atoms
- Custom atoms that only wrap a stock component with token styling (e.g. `Search`, `ListItemGroup`) add a file and abstraction layer without real value.
- Only create an atom when it adds genuine logic beyond styling: enums, computed state, composite layout, custom drawing.
- For new screens, use stock ArkUI components directly with token styling inline. Save atoms for truly custom Telegram-specific UI.
- Runtime simplification result: `TgSettingsSection` and `TgContactRow` were removed from the live page path and later their orphaned demo/spec artifacts were deleted. `TgSearchBar` was not removed from the library; only the live Chats shell switched to stock ArkUI `Search` inside `TgChatListNavigationBar`.

## 26. Avatar photos are the single biggest "demo vs real app" visual signal
- Without real avatar photos (only colored initials circles), the entire app looks like a prototype regardless of UI polish.
- TDLib provides `file.id` in `profile_photo.small` but does NOT auto-download — explicit `downloadFile` call is required.
- Current codebase stores `TdLocalFile.path` but never triggers download, so path is always empty.
- Priority: implement `downloadFile` flow before any further UI polish work.

## 27. File download architecture: cross-cutting reducer for fileId→path mapping
- `updateFile` from TDLib only carries `file.id` + `local.path` — no entity context (which user/chat owns it).
- The `filesReducer` scans both `users` and `chats` maps for matching `photoSmallFileId` on each `fileDownloaded` event. This is O(n) but only fires on download completion (rare event).
- Alternative approaches (fileId→entity registry in usecase, or normalizer with store access) were rejected for architecture cleanliness.
- The `downloadAvatars` usecase watches store for new users/chats with `fileId > 0` and empty `photoSmall`, then triggers `downloadFile` command. It maintains a `pendingFileIds` set to avoid duplicate requests.

## 28. TDLib file objects: `getNumber('id')` fails due to nested `remote.id` string
- TDLib `file` objects contain `"id": 123` (number) at top level AND `"remote": {"id": "AQA..."}` (string) nested inside.
- The regex-based `extractValue('id')` tries `extractStringValue` FIRST, which finds the nested `remote.id` string before the top-level numeric `id`.
- Result: `getNumber('id')` returns 0 because `parseFloat("AQA...")` is NaN.
- Fix: use `getTopLevelNumber('id')` which does character-by-character parsing respecting JSON nesting depth.
- This affects ALL file ID extraction: UserDto, ChatDto, FileNormalizer — anywhere `tdGetNumber(fileObj, 'id')` is used on a TDLib file object.

## 29. `JSON.stringify(TdObject)` produces empty/truncated output — use native accessors
- `TdObject` stores its data in a `private rawJson: string` field. `JSON.stringify()` cannot access private fields in ArkTS, so the result is a near-empty object (only pre-cached `@type` and `@extra` appear).
- This broke the `downloadAvatars` direct-response handler: `JSON.stringify(response)` → `JSON.parse()` → empty `local` object → download completions from direct `downloadFile` responses were silently lost.
- Fix: cast `response as TdObject` and use native accessor methods (`.getObject('local')`, `.getBool('is_downloading_completed')`, `.getString('path')`).
- Rule: **never** `JSON.stringify` a TdObject for data extraction. Always use the `.getString()` / `.getNumber()` / `.getBool()` / `.getObject()` API.

## 31. Scroll compensation for prepend must be synchronous
- When older messages are prepended to a List via `notifyDataAdd(0..N)`, ArkUI shifts visible items down.
- Using `setTimeout(16ms)` to call `scrollToIndex` creates a visible 1-frame shift/flicker.
- Fix: call `scrollToIndex` synchronously right after `applyDiff()` — ArkUI processes data change and scroll in the same frame.
- Also update `lastVisibleStartIndex/EndIndex` immediately by `+prependCount` to prevent stale indices triggering unwanted loads.
- Android RecyclerView handles this natively via `LinearLayoutManager.onItemsAdded()`.

## 32. Pagination latch pattern is unnecessary overhead
- Neither Android nor iOS Telegram use a latch (scroll-away-to-rearm) for pagination.
- Android uses simple `!loading` / `!loadingForward` boolean flags.
- iOS uses reactive Signal pipeline (single active request by design).
- The `recheckPaginationEdge()` pattern (fire again if still at edge after load) provides continuous loading without needing latches.
- Simpler code, fewer state variables, same behavior.

## 33. Android Telegram tab bar uses full-tab pill, not ring highlight
- Android `GlassTabView` draws a capsule (borderRadius=height/2) over the ENTIRE tab area with 9% alpha of `glass_tabSelected`.
- Scale animation: 0.6→1.0 over 320ms DECELERATE.
- Icon: 24dp, text: 12sp Bold→ExtraBold, Lottie outline↔filled animation.
- Our original ring (29x29 circle behind icon) looked nothing like this.
- ArkUI equivalent: `.animation({ duration: 320, curve: Curve.EaseOut })` on pill opacity+scale.

## 34. Prepend scroll compensation requires pre-capture + viewport freeze + cascade block
- `scrollToIndex` alone after `notifyBatchChange` causes a visible flash frame: ArkUI renders prepended items before processing the scroll.
- **Save indices AND yOffset BEFORE `applyDiff`**: `onScrollIndex` may fire during `notifyBatchChange`, updating `lastVisibleStartIndex` to stale/double-counted values.
- **Freeze viewport**: call `scrollTo({ yOffset: savedYOffset, animation: false })` immediately after `applyDiff`, BEFORE `scrollToIndex`. This anchors the viewport at the pre-prepend pixel position.
- **`contentStartOffset` gap**: when user was near the top (yOffset < topBarTotalHeight), `scrollToIndex(target, START)` loses the top bar gap. Fix: use `extraOffset: LengthMetrics.vp(topBarTotalHeight - savedYOffset)`.
- **Block cascade**: set `blockAutoPaginationUntilUserScroll = true` during prepend. Without this, `recheckPaginationEdge` fires after each load (320ms guard insufficient), causing repeated prepend→flash chains.
- Android ref: `ChatActivity.getScrollingOffsetForView()` + `scrollToPositionWithOffset(newIndex, savedTop)`.
- iOS ref: `stationaryItemRange` → capture anchor frame → compute delta → shift all items atomically.

## 35. Do not defer prepend compensation to the next frame
- HarmonyOS docs for `List` off-screen data changes recommend capturing the visible index with `onScrollIndex` and immediately calling `Scroller.scrollToIndex()` when data is inserted before the viewport.
- In this repo, a delayed second-pass `setTimeout(16ms)` prepend re-scroll still produced the user-visible “messages jumped down” effect even though the anchor logic itself was correct.
- Keep prepend compensation synchronous in the same turn as `applyDiff()`; if a viewport freeze is needed, do it with immediate `scrollTo({ yOffset: savedYOffset, animation: false })`, not with a later timer.

## 36. Do not block first chat paint on missing sender hydration
- In this repo, names/avatars for group bubbles are a valid dependency, but the **first visible history batch** must not wait for a serial `getUser` loop.
- Better path: dispatch `getChatHistory` results first, then hydrate missing sender users in the background with small parallel chunks and one batched store dispatch.
- Also memoize sorted chat-message arrays by the per-chat message-map reference; otherwise user-only updates re-sort the whole active chat even when message order did not change.

## 37. Prefer ArkUI native visible-position preservation over custom prepend scroll hacks
- Official HarmonyOS `List` has `maintainVisibleContentPosition(true)` specifically for keeping viewport position stable when `LazyForEach` inserts/deletes data above the visible area.
- In this repo, the manual prepend `scrollToIndex` compensation was still brittle because it fought ArkUI's own layout timing and item heights.
- Keep the native flag on for chat history lists and use custom scroll compensation only as a last-resort fallback when the platform path is proven insufficient.

## 38. Do not mix `onDatasetChange` with `onDataAdd/onDataDelete/onDataChange` in one LazyForEach datasource
- Device HiLog showed `Timeline rebuild failed: Error: onDatasetChange cannot be used with other interface` while chat history was paging older messages.
- In this repo, `ChatTimelineDataSource` was using per-item notifications for some paths and `onDatasetChange(...)` for append/prepend paths. That combination is runtime-invalid for the registered `DataChangeListener`.
- Keep one notification family per datasource. For chat timeline we reverted to the classic `onDataAdd/onDataDelete/onDataChange/onDataReloaded` path.

## 39. Never recheck pagination synchronously in the same promise `finally` that dispatches history
- `loadOlderMessages()` / `loadNewerMessages()` can dispatch store updates that schedule `rebuildTimeline()` on `setTimeout(0)`.
- If `recheckPaginationEdge()` runs immediately in the promise `finally`, it still sees the **old** `lastVisibleStartIndex/lastVisibleEndIndex` and old datasource count, so it can fire another `loadOlderMessages()` before the prepend diff is applied.
- In this repo that created a `Loading older messages...` storm on device. Fix: schedule the edge recheck to the next tick and, if a rebuild is still pending, retry after the diff has settled.

## 40. Center top bars with fixed side slots, not a left-packed Row
- In `TgChatTopBar`, a plain `Row()` with back capsule, title capsule, and avatar capsule packed all content from the left, leaving unused space on the right and making the whole cluster look shifted.
- The stable pattern is: fixed left slot + weighted center lane + fixed right slot.
- For this repo, the center lane hosts the title capsule and uses `layoutWeight(1)` + `justifyContent(FlexAlign.Center)`, while the title/subtitle texts are centered inside the capsule itself.

## 41. Glass chrome and content must be separate layers
- In this repo, applying `backgroundBlurStyle(...)` and then `overlay(buildGlassSpecular())` directly on the same node that also contained `Text`, `TgIcon`, or `TgAvatar` made the content look visually embedded into the blur/highlight.
- The stable composition is a `Stack`:
  1. background glass layer (blur/tint/border),
  2. optional specular highlight layer,
  3. content layer on top.
- Use this especially for top bars and floating capsules on dark chat backgrounds, where incorrect stacking becomes obvious.

## 42. LazyForEach prepend must use per-item splice+notify, not bulk array replacement
- `maintainVisibleContentPosition(true)` only works when each insert is a single `splice(0,0,item)` + `notifyDataAdd(0)` call — matching the official HarmonyOS example.
- Replacing the entire `this.items` array first and then batch-firing `notifyDataAdd(0..N)` breaks the position tracking because ArkUI sees stale data at notification time.
- For reverse-order prepend at index 0: iterate from `offset-1` down to `0`, insert each item with `splice(0,0,item)` + `notifyDataAdd(0)`.
- This is the root cause of the "messages jump up" issue during older-history pagination.

## 43. backgroundBlurStyle does not clip to borderRadius — add .clip(true)
- In ArkUI, `backgroundBlurStyle` renders the blur region as a rectangle matching the element's frame, ignoring `borderRadius`.

## 44. Special video previews must populate shared `videoThumb*` fields
- In this repo, `animation` and `videoNote` are rendered through the shared video bubble path.
- If `MessageDto` only fills `animationPath` / `videoNotePath` and leaves `videoThumbPath` empty, previews silently depend on the full media file already being local, which makes some GIF/videoNote bubbles look blank until download completes.
- Keep thumbnail extraction aligned with regular videos by populating `videoThumbPath` and `videoThumbFileId` for these special media types too.

## 45. Grouped albums should preserve empty-path cells instead of collapsing
- `TgGroupedPhotoBubble` already knows how to render placeholder cells when an album item path is currently empty.
- If `ChatTimelineVO.buildPhotoAlbumEntry()` skips empty-path items, partially downloaded albums shrink to length `1` and incorrectly fall back to a single-photo bubble.
- Preserve every album slot and let the bubble render placeholders; do not treat “local file missing right now” as “album item does not exist”.
- Continue to pair glass blur with `.clip(true)` when the shape must stay rounded, otherwise the blur bleeds past the intended Telegram capsule edges.

## 44. Unsupported secondary message types must never fall through to an empty media shell
- In this repo, `MessageDto` already provides safe fallback text for `location`, `contact`, `poll`, and unknown TDLib message types.
- If `TgMessageRouter` only treats `'text'` / `'unsupported'` as text-like, those secondary types bypass the text path, skip every specialized renderer, and produce visually blank bubbles.
- Safer rule here: if a message type has no dedicated atom yet but already has fallback text, keep it on the text-bubble path until a real renderer exists.

## 45. File rows read better with an extension badge + two-line title than with a generic one-line icon row
- The iOS `ChatMessageInteractiveFileNode` uses a strong leading file affordance plus a title/meta stack that can breathe vertically.
- In this repo, a single-line file title plus a generic icon made document bubbles look under-specified and cramped.
- A better baseline is: extension badge tile when not downloading, explicit progress state when downloading, and up to two title lines with ellipsis in the weighted text column.

## 46. Voice bubble meta cannot rely on a generic `width('100%')` row inside a shrink-wrapped media bubble
- In this repo, the voice bubble body width is duration-based, while the outer non-visual media bubble shell can still be shrink-wrapped by ArkUI.
- A separate meta row with `width('100%')` is therefore ambiguous and can drift outside the intended voice bubble width on real runtime layouts.
- Safer pattern: compute one shared voice bubble width contract and use it in both the atom and the router, then give the voice meta row an explicit width derived from that same helper.

## 47. Channel posts must not inherit the hidden group avatar lane by sender-name heuristics
- In this repo, using `senderName.length > 0` as the router-side proxy for avatar-lane reservation made broadcast/channel bubbles narrower even when no avatar was shown.
- iOS broadcast/channel layout does not blindly reserve the group avatar lane for every incoming post; that width is a big part of why Telegram channel bubbles feel more open.

## 48. `fileDownloaded` alone is not enough for media UX
- In this repo, relying only on `FileDownloadedEvent` meant the UI knew about media only in two states: “not local yet” and “already finished”.
- Photo/video/document/audio/voice transfer indicators need a store-level `fileId -> transfer state` map fed by every TDLib `updateFile`, not just the completion event.
- Keep `fileDownloaded` for path application, but drive visible pending/progress UI from a separate transfer-update event.

## 49. Text-engine whitespace normalization must preserve hard breaks
- In this repo, the first V3 engine pass reused a generic whitespace normalizer that collapsed `\n` into spaces before tokenization.
- That silently violated the Telegram text contract and made the custom engine less correct than the old plain `Text(...)` rendering for multiline messages.
- Normalize horizontal whitespace per line, but preserve newline boundaries all the way into segmentation/layout.

## 50. Engine-driven meta width must follow rendered status semantics, not optimistic transport semantics
- The live V3 text path renders a failed outgoing icon in `TgMessageMeta`, so the layout pass must reserve width for `Failed` too.
- A narrower `hasStatus` check in the calculator created a subtle but real mismatch: the bubble math assumed “no icon”, while the UI still rendered one.
- For shrink-wrap bubbles, layout predicates must match the final rendered states exactly, or the engine loses its point.

## 51. Quote-aware bubbles need explicit segment geometry in layout, not only raw-text measurement
- Measuring the whole raw text once is not enough when the renderer inserts distinct quote surfaces with their own paddings, accent bars, and segment gaps.
- In this repo, `computeTextBubbleLayout()` looked engine-driven but still undercounted quote-heavy bubbles because it ignored the quote shell geometry.
- If the renderer splits text into semantic blocks (quote/plain/reply/etc.), the layout pass must model those same blocks explicitly.

## 52. Photo preview availability and full-photo availability are different states
- In this repo, `photoPath` in the chat VO can legally point to a thumb/preview while the full `photoFileId` is still downloading.
- Therefore the photo bubble cannot infer “full asset is local” from “some preview image exists”; it needs an explicit `hasLocalPhoto` flag separate from the preview URI.
- Safer pattern: compute an explicit `reserveAvatarLane` flag in timeline/build logic and pass it into the router instead of inferring lane reservation from sender-name presence.

## 53. Atoms must not mutate shell navigation state directly
- In this repo, `TgTabBar` briefly wrote `MAIN_TAB_INDEX` into `AppStorage` itself even though `MainTabsPage` already owned `selectedIndex`, `TabsController`, and shell persistence.
- That duplicates the source of truth and makes tab selection bugs harder to reason about.
- Keep atoms presentational: emit callbacks upward, and let the page/shell own `AppStorage` and controller writes.

## 54. Demo/state coverage is not proof that a badge path is actually live
- `TgTabBar` already had `chatBadgeCount` and `buildBadge()`, but the real Chats tab still passed `showBadge = false`, so unread badges never rendered at runtime.
- For shell chrome, always verify the integrated call site after atom work; do not assume a prop/state path is live just because the atom supports it.

## 52. Tab bar glass tuning should not silently retint the whole chrome system
- In this repo, `glass_tab_bg` and `glass_edge_highlight` are reused by multiple surfaces (tab bar, filter bar, top/composer chrome).
- When only the tab bar needs more visual mass, prefer dedicated tab-bar resources/tokens instead of globally changing every glass surface at once.


## 48. ArkUI text can look “correct but not Telegram-like” if wrapping stays on the default greedy path
- Even after font-size/token tuning, HarmonyOS text metrics differ from iOS CoreText/AsyncDisplayKit, so chat bubbles can still wrap too early or feel optically narrower.
- ArkUI docs state that `lineBreakStrategy` affects wrapping quality when `wordBreak` is not `BREAK_ALL`; using a higher-quality strategy for normal text/captions is a safer parity lever than forcing more aggressive word-break rules.
- Keep `BREAK_ALL` only for genuinely pathological long tokens; use a higher-quality line-break strategy for everyday message text and captions.

## 44. `@Builder` bodies cannot start with normal local statements
- In ArkTS/ArkUI, a `@Builder` function body must contain UI-component syntax only.
- A plain `const ... = ...` at the top of a builder caused `Only UI component syntax can be written here` in `TgPhotoBubble`.
- If precomputed values are needed, move them into helper methods (`computedMediaWidth()` / `computedMediaHeight()`) or calculate them outside the builder.

## 45. HarmonyOS text can read optically larger even at Telegram's nominal 17-size tokens
- ArkUI `fontSize(number)` uses **fp** units, and HarmonyOS font metrics/x-height can make `17` look heavier than Telegram iOS `messageFont` even when the nominal value matches.
- In this repo, chat bubbles felt too screen-hungry until body/caption typography was tightened from `17/22` to `16/21`.
- For bubble parity issues, compare optical density on device — not just the raw numeric font token.
- To make blur respect rounded corners, add `.clip(true)` on the same element.
- Additionally, when blur is on a separate layer in a Stack (e.g., glass capsules), add `.renderGroup(true)` to isolate the blur from sibling content layers.
- Affected: `TgChatTopBar` capsules (back, title, avatar).

## 30. ArkUI `Image()` requires `file://` URI, not raw sandbox paths
- TDLib stores downloaded files at raw sandbox paths like `/data/storage/el2/database/entry/profile_photos/xxx.jpg`.
- ArkUI `Image()` component does NOT load raw sandbox paths — it requires `file://<bundleName>/<sandboxPath>` format.
- Fix: use `fileUri.getUriFromPath(path)` from `@kit.CoreFileKit` to convert before passing to any UI component.
- This must be done at the UI mapping boundary (VO builders, page state setters), not in the store/reducer layer.

## 44. ChatList search must belong to the header surface, not the scrolling list
- Telegram iOS `ChatListNavigationBar` integrates the search lane into the navigation header (`searchScrollHeight = 54.0`); it is not a separate strip rendered as the first list cell.
- In this repo, using `TgTopBar` plus a scrolling `Search` list item created a visible double-strip header and clipped localized left action text.
- The stable pattern is a dedicated chat-list header atom that owns title row + integrated search row, while `List.contentStartOffset(...)` reserves the full combined header height.

## 45. Overlay headers in `Stack` must declare explicit height
- In this repo, `ChatListPage` uses `Stack` to let the list scroll under the integrated `TgChatListNavigationBar`.
- When the overlay header atom had `width('100%')` but no explicit root height, the overlay could expand to the full stack height and swallow all scroll/tap interaction intended for the list below.
- The stable pattern is: if a header is overlaid above a scrollable surface in `Stack`, give the header root an explicit total height (`topInset + contentHeight`) and keep the list responsible for `contentStartOffset(...)`.

## 46. Current Telegram iOS tab bar is still a centered glass capsule
- A quick read of old `TabBarNode.swift` alone is not enough; the current active shell path also uses `TabBarContollerNode.swift` + `TabBarComponent.swift`.
- In the current iOS refs, the tab bar is hosted inside a centered `GlassBackgroundContainerView` capsule with bottom outer insets, not as a full-width shelf glued to the screen edge.
- In this repo, changing the custom bar to a full-width shelf was a misread of the reference. The safer pattern is a centered capsule plus page-owned bottom safe-area offset and content-end inset.
## 47. Send-style ArkUI `TextArea` composers should keep editable state
- HarmonyOS docs show that when `TextArea.enterKeyType(EnterKeyType.Send)` is used, the safe pattern is `onSubmit((enterKey, event) => event.keepEditableState())` if the composer should keep the keyboard visible after submit.
- In this repo, the chat composer also works better as a **screen-owned controlled input** (`text` + `onTextChange`) than as an atom with hidden local draft state, because chat page rebuilds and integration logic should not silently reset or diverge the visible draft.

## 48. Keep tab-bar safe-area ownership at the page level
- In this repo, the centered capsule `TgTabBar` should adapt its width from window size, but it should not maintain a private bottom-safe-area state when the page already owns outer bottom offset and `contentEndOffset` math.
- If both the page and the atom try to own bottom inset logic, the capsule contract becomes harder to reason about and spec/code drift returns.

## 49. If the passport says glass, the atom must expose a real glass path
- In this repo, `TgChatTopBar` had drifted into opaque fallback-only capsules even though the passport/demo/docs all described blur/fallback behavior.
- The stable pattern is explicit: `glassMode` param + realtime blur/fallback background selection + separate glass shell and content layers. Otherwise shell chrome drifts silently even when docs still look correct.

## 50. Chat-list preview accents should stay separate from preview body
- In this repo, collapsing `Draft:` or group sender prefixes directly into one plain `lastMessage` string made `TgChatRow` render everything in a single color, which flattened important Telegram visual states.
- Telegram iOS keeps those states visually split: draft prefix in the draft/error accent, author prefix in the chat-list accent color, body text in the normal preview tone.
- The stable pattern is to carry `previewPrefix` + `previewPrefixStyle` alongside the preview body and let `TgChatRow` render them as separate fragments while the body owns ellipsis independently.

## 51. Right chat-list meta tuning should follow iOS numeric/icon metrics, not generic app meta tokens
- `ChatListItem.swift` uses a 14pt-style date font and a 14pt monospaced badge font inside a 20pt badge diameter. The pin glyph is visibly smaller than the unread badge lane, not the same size as a generic 16pt app icon.
- In this repo, reusing the generic 13pt meta font and a 16pt pin icon made the right cluster feel undersized/imbalanced even though the overall anti-jump geometry was correct.
- The safer pattern is dedicated chat-meta tokens: separate time font size, badge font size, status icon size, and pin icon size. Keep the anti-jump min-width contract, but tune the visible metrics independently.

## 52. Chat-list typing preview should not reuse draft/author accent styling
- Current Telegram iOS chat-list typing is rendered by `ChatListInputActivitiesNode` (`ChatListTypingNode.swift`) with the regular chat-list message text color passed from `ChatListItem.swift`.
- In this repo, reusing the draft/author split-prefix accent path for typing made group typing rows look too loud and less Telegram-like.
- If typing is represented as plain text in HarmonyOS instead of a dedicated activity node, keep it in the normal preview tone and avoid borrowing the draft/error or author-prefix accent treatment.

## 53. Chat-list separator lane should follow the iOS avatar path, not the full text-start inset
- `ChatListItem.swift` anchors the normal separator lane at `leftInset + rawContentRect.origin.x`, which lands around `80pt` on the standard 60pt avatar layout.
- In this repo, deriving the separator from `sideInset + avatar + full text gap` pushed the divider too far right and made the list feel less Telegram-like.
- Also, iOS row text rhythm is tighter than a generic `Column(space: 4)` layout. If the HarmonyOS row feels visually airy, tighten title/preview spacing before changing bigger geometry like row height.

## 54. Chat rows need their own typography tokens, not the global title token
- `ChatListItem.swift` uses row-local typography derived from the list base font (`16/17` title, `15/17` preview), which is different from a screen header/title scale.
- In this repo, driving `TgChatRow` from the global `FONT_TITLE_SIZE` made chat titles too coupled to unrelated shell typography work.
- The safer pattern is dedicated row tokens (`CHAT_ROW_TITLE_FONT_SIZE`, `CHAT_ROW_PREVIEW_FONT_SIZE`) so list tuning does not accidentally change headers, demos, or other atoms.

## 54. iOS unread badge is accent blue, not red
- iOS Telegram `ChatListItem.swift` uses `theme.chatList.unreadBadgeActiveBackgroundColor` which resolves to the accent color (blue `#0088FF`), not red.
- Red is only used for muted badge in some themes. The default unread badge is always the accent/blue.
- In this repo, using red `#FF3B30` for the unread badge was a significant visual mismatch — it made the chat list look like an error-heavy interface instead of a communication app.

## 55. iOS chat-list author prefix is black, not accent blue
- iOS `ChatListItem.swift` renders the author name in the title/primary text color (black in light, white in dark), not in the accent color.
- Using accent blue for the author prefix in the chat list preview made group chats visually louder than in Telegram iOS.
- The accent blue should be reserved for interactive elements (links, buttons), not for passive label text in the list.

## 56. Message spacing must differentiate same-sender vs different-sender
- iOS `ChatMessageBubbleItemNode` uses `defaultSpacing = 2.33pt` for consecutive messages from the same sender, and a larger gap (~8pt) when the sender changes.
- Without this differentiation, the message timeline looks like a flat list of equal items instead of conversational groups.
- In this repo: track `prevSenderId` (with `-2` for outgoing = virtual same sender), set `topSpacing` per message in the VO, and apply it as top padding in the ListItem.

## 57. Profile online status should be green, not blue
- iOS PeerInfoScreen uses green for "online" status text, matching the online dot color.
- Blue is the accent/action color. Using it for online status text conflates "status" with "action" and breaks the iOS visual language.
- Profile title font is 28pt Medium in iOS (not 22pt Bold), and the subtitle is 17pt Regular.

## 58. Incoming group avatar lane must depend on grouping context, not downloaded image state
- In this repo, reserving the left avatar lane based on `avatarImageSrc` / `avatarInitials` caused message bubbles to change width after sender hydration finished.
- The stable rule is: if the row is an incoming grouped message (we already know that from VO/router context), reserve `avatarInset` immediately and let the visible avatar chip be a later concern.
- Also mark `showAvatar` for the last message in the sender group even when photo data is missing; the router can fall back to sender initials.

## 59. Inline bubble meta must disable generic `TgMessageMeta` minimum width
- `TgMessageMeta` has a default `minWidth` / hidden placeholder contract that is useful for standalone rows, but it is too wide for text/caption overlay usage.
- In this repo, using the default inline caused the rendered time/check cluster to be wider than the transparent reserve span, which produced trailing overlap/drift.
- For inline or media-overlay usage, pass `minWidth: 0`, `reserveTimeSlot: false`, and `reserveStatusSlot: false` so the visible cluster width matches the reserved text width more closely.

## 60. End-aligned `Stack` + `width('100%')` child needs an explicit stack width
- In this repo, the media-caption path used `Stack({ alignContent: Alignment.BottomEnd })` with a caption `Text().width('100%')`, but the stack itself had no explicit width.
- ArkUI then aligned the percentage-width child against the stack's end edge and the left part of the caption could extend outside the bubble, clipping the first characters of every line.
- For shrink-wrapped media bubbles, give the `Stack` an explicit width equal to the actual media bubble width before using percentage-width caption children.

## 58. Chat list preview should use emoji prefixes, not brackets
- iOS Telegram uses emoji prefixes in chat list previews: `📷 Photo`, `📹 Video`, `📎 File`, `🎤 Voice message`, `📍 Location`, `📊 Poll`, `👤 Contact`.
- Our code had `[Photo]`, `[Video]` etc. — plain brackets look non-native.
- Sticker and GIF use plain text labels without emoji (matches iOS).

## 59. ArkUI does not allow two `.gesture()` calls on the same component
- The second `.gesture()` silently overwrites the first.
- Use `.parallelGesture()` for the second gesture so both coexist.
- PanGesture(Horizontal) + LongPressGesture on message bubbles: pan for swipe-to-reply, parallel long press for copy.

## 60. Group/channel top bar subtitle should show member count
- `updateChatTopBarData()` only handled private chats (user status). Groups/channels got empty subtitle.
- `chat.memberCount` was available in the model but unused in the top bar.
- Fix: show "X members" for groups, "X subscribers" for channels, with fallback labels when count is 0.

## 61. Reply bar must be inside the area-tracked wrapper, not adjacent
- The composer overlay uses `onAreaChange` to track total height for `contentEndOffset`.
- If the reply bar is placed outside the tracked wrapper, the List doesn't reserve space for it and content gets hidden behind.
- Fix: wrap reply bar + TgComposerInput in a single Column with onAreaChange on the wrapper.

## 62. Sender name tokens must be consistent across all bubble paths
- TgMessageRouter has 3 code paths for sender name: sticker, text, media.
- After the iOS alignment pass, only the text path was updated to use `MSG_SENDER_NAME_SIZE` / `MSG_SENDER_NAME_WEIGHT`.
- Sticker and media paths still had hardcoded `fontSize(13)` / `fontWeight(FontWeight.Medium)` — fixed with `replace_all`.

## 63. Don't use shared @State for per-item gesture state in LazyForEach
- Using a shared `@State swipeOffsetX` for per-message swipe-to-reply causes ALL visible LazyForEach items to re-evaluate on every gesture frame (because @State triggers full re-render).
- This is a performance anti-pattern — each `.offset()` expression references `this.swipeOffsetX`, so ArkUI marks every item dirty.
- Fix: use `promptAction.showActionMenu()` (system-level action menu) instead of custom swipe gesture for reply/copy actions. No per-item state needed.

## 64. ArkUI `.gesture()` called twice on same component — second overwrites first
- Cannot chain `.gesture(PanGesture)` and `.gesture(LongPressGesture)` — second silently replaces first.
- Use `.parallelGesture()` for additional gestures, or consolidate into a single gesture.
- Better approach: use system APIs (`promptAction.showActionMenu`) instead of custom gesture combinations.

## 65. Use `promptAction.showActionMenu()` for message context actions
- HarmonyOS provides `promptAction.showActionMenu()` — a native action sheet with buttons.
- Much simpler and more reliable than custom gesture + overlay implementations.
- Returns a Promise with `ActionMenuSuccessResponse.index` to identify which button was tapped.
- Catches dismiss (user cancelled) via `.catch()`.

## 66. Always use localized string resources for user-visible text
- Hardcoded strings like `'X members'` or `'X subscribers'` won't work for i18n.
- Use `localized($r('app.string.key').id, 'fallback')` pattern consistently.
- Add string resources to `string.json` for all locales (base/en, ru_RU, zh_CN).

## 67. TextContentStyle.INLINE shows blue focus border — use DEFAULT for custom shells
- ArkUI `TextArea.style(TextContentStyle.INLINE)` has a built-in focus indicator (blue outline around the text area on focus).
- For custom composer shells where the capsule itself is the visual boundary, this blue outline is unwanted and squishes adjacent icons.
- `TextContentStyle.DEFAULT` has no visual focus change, but also has no internal padding — add explicit `.padding()` when switching.
- Add `.caretColor()` explicitly since DEFAULT may use a different default caret color.

## 68. Use COMPONENT_* BlurStyle variants for UI element blur
- HarmonyOS `BlurStyle` has two families: `BACKGROUND_*` (for material/background effects) and `COMPONENT_*` (purpose-built for UI components like nav bars, tab bars, cards).
- `Thin`/`Regular`/`Thick` are legacy shorthand that map to background styles.
- `COMPONENT_REGULAR` and `COMPONENT_THIN` produce better visual results for floating UI elements — they're designed for the use case of blurring content behind a foreground component.
- In this repo: all glass elements use `COMPONENT_REGULAR`, tab bar pill uses `COMPONENT_THIN` (lighter effect for a small highlight area).

## 69. Glass depth comes from three combined techniques, not shadows
- iOS Telegram glass elements look "volumetric" (not flat) through:
  1. **Sufficient overlay alpha** (15-20%, not 2%) — gives visible frosted tint
  2. **COMPONENT_* blur** — proper component-level blur rendering
  3. **Edge highlight** — thin semi-transparent white border (~0.75vp, 20-33% white) mimicking light catching on glass edges
- Drop shadows (`shadow()`) are NOT the technique — they make elements look "floating above" rather than "made of glass".
- The user's words: "это не тени, это словно блики краев стекла" — it's edge light catch, not shadow.

## 76. ChatTimelineVO must convert sandbox paths to file:// URIs
- ArkUI `Image()` requires `file://<bundleName>/<path>` format, not raw sandbox paths.
- The download pipeline (DownloadMessageMediaUseCase → FileNormalizer → filesReducer) stores raw sandbox paths in message content.
- The VO builder is the correct place for conversion: `fileUri.getUriFromPath(path)` from `@kit.CoreFileKit`.
- Without this conversion, media silently fails to display — Image shows nothing, no error.
- Apply to ALL media paths: photo, video thumb, sticker, voice, document, animation, video note.

## 77. Do not call viewMessages before openChat reaches TDLib
- `viewMessages` requires an active `openChat` session in TDLib.
- If called before `openChat` is processed, TDLib may silently ignore it.
- Combined with a dedup key that prevents retry, this means `viewMessages` never succeeds → badges never reset.
- Fix: only call `maybeMarkChatRead` from store subscription (fires after history loads, by which time `openChat` is done).

## 71. Use List `initialIndex` for chat history instant positioning
- HarmonyOS `List` constructor accepts `initialIndex` — tells List to start rendering at a specific index instead of 0.
- Combined with `maintainVisibleContentPosition(true)`, this is the official pattern for chat-style lists (documented in HarmonyOS examples).
- Eliminates scroll-from-top animation on chat open. Priority order: unread boundary → saved scroll position → bottom (newest).
- Do NOT use `scrollToIndex` for initial positioning — it causes a visible scroll animation from index 0.

## 72. Placeholder release threshold must not block small chats
- `TgChatScreenPage` had `INITIAL_HISTORY_PLACEHOLDER_RELEASE_COUNT = 12` — List stayed hidden until 12+ items loaded.
- For chats with <12 messages where `canLoadOlderMessages` was true, List never rendered → `onScrollIndex` never fired → pagination never triggered → eternal spinner.
- Fix: threshold = 1. Show content as soon as ANY messages arrive. Pagination will fire from `onScrollIndex` or `recheckPaginationEdge`.

## 73. Race condition: screen history load vs OpenChatUseCase
- `ChatListPage.openChat()` sets `ACTIVE_CHAT_ID` (triggers TgChatScreenPage) THEN calls `requestOpenChatData()` (OpenChatUseCase).
- TgChatScreenPage's `aboutToAppear` fires `getChatHistory` with `HISTORY_INITIAL_DELAY_MS=0`, grabbing the bucket lock before OpenChatUseCase sends `openChat` to TDLib.
- Without `openChat` first, TDLib returns only locally cached messages (1-2 instead of full page).
- Fix: `HISTORY_INITIAL_DELAY_MS = 600` to let OpenChatUseCase run first. Not ideal (timing-based), but effective until proper sequencing is implemented.

## 74. Sticky unread marker pattern
- `markChatRead()` fires immediately on chat open → `unreadCount` becomes 0 → `firstUnreadIncomingIndex()` returns -1 → unread separator disappears on next rebuild.
- Fix: capture `lastReadInboxMessageId` at chat entry as `stickyLastReadMessageId`. Use it instead of live `unreadCount` for unread boundary calculation during the entire chat session.
- Reset `stickyLastReadMessageId = ''` in `aboutToDisappear`.
- Pass sticky ID through `buildChatTimeline()` → `firstUnreadIncomingIndex()`.

## 75. Schedule pagination recheck for static lists after guard expiry
- After initial load with few messages, `guardProgrammaticScroll` blocks pagination for N ms.
- When guard expires, `onScrollIndex` does NOT re-fire for static lists (no scroll happened).
- Fix: `schedulePaginationRecheck(PROGRAMMATIC_SCROLL_GUARD_MS + 50)` after every restore path — ensures pagination fires even if user hasn't scrolled yet.

## 70. Status bar icons need explicit color via setWindowSystemBarProperties
- On HarmonyOS, status bar icon colors (battery, network, time) are not always automatically themed.
- Use `mainWindow.setWindowSystemBarProperties({ statusBarContentColor: '#FFFFFF' })` for dark mode (white icons) and `'#000000'` for light mode.
- Must listen to `onConfigurationUpdate(newConfig)` in EntryAbility to react to runtime theme changes.
- Store `colorMode` in AppStorage for components that need to read current theme.

## 78. Grouped media has to be collapsed in timeline before it reaches the router
- Telegram photo albums are not a visual variant of a single `photo` bubble; they are a separate grouped-message path.
- In this repo, the stable place to merge them is `ChatTimelineVO` using consecutive `media_album_id` items from the same sender/outgoing cluster.
- If grouping is postponed until the atom/router layer, captions, unread marker placement, sender grouping, and diff identity all drift.

## 79. HarmonyOS media components and AVPlayer do not want the same path format
- ArkUI `Image` / thumbnail rendering in this repo requires `fileUri.getUriFromPath(...)`, but local `AVPlayer` voice playback works through `fdSrc` with the raw sandbox path opened via `@ohos.file.fs`.
- Therefore `ChatTimelineVO` must keep a split contract: visual media paths become `file://...`, while `voicePath` remains raw for `VoicePlaybackController`.
- Converting voice playback paths to `file://` broke the player contract; converting image paths to raw sandbox paths broke ArkUI rendering.

## 80. Async controller teardown can reset newer playback state if identity is not guarded
- `VoicePlaybackController.release()` is async. If `TgChatScreenPage` tears down an old controller and immediately creates a new one, a late callback/finally from the old controller can zero out the new active voice state.
- The safe pattern in this repo is: detach the old controller first, reset page state synchronously, and ignore snapshots from stale controller instances.
- Also, any overlay drawn on the last grouped-media cell (`+N`) must have its own click handler, otherwise it blocks the underlying photo tap target.

## 81. For chat media viewers, direct root-Stack overlays are safer than `bindContentCover`
- In this repo, the photo/video viewer path was wired correctly but still did not open reliably on the emulator through `bindContentCover(...)`.
- Replacing that path with explicit conditional fullscreen overlays inside the chat page root `Stack` is simpler and more predictable for this screen architecture.
- Also make the whole video preview surface clickable, not only the center play button; otherwise GIFs/animations with hidden play affordance lose their open-viewer path completely.

## 82. `videoNote` needs its own router branch, not just a different inner atom
- In this repo, swapping only the inner media atom for `videoNote` was not enough because the generic visual-media branch in `TgMessageRouter` still wrapped the content in the rectangular bubble background.
- For Telegram-style instant video, the router itself must branch out of the generic visual-media shell and render sender/reply/caption/meta around a circular media surface with no outer rounded rectangle.
- Also keep the size contract explicit (`212 / 240` compact/regular targets) and pair circular `borderRadius` with `.clip(true)`; otherwise the instant-video path still reads like a normal video card.

## 83. Album viewers should open from page-owned path arrays, not a single photo path
- In this repo, grouped-photo bubbles already knew all album cell paths, but the fullscreen viewer state only stored one `viewerPhotoPath`, so tapping an album opened a dead-end single-photo overlay.
- The stable pattern is: normalize/filter album paths in `TgChatScreenPage`, store the selected index there, and pass `photoPaths + initialIndex` into the viewer. That keeps placeholder cells out of the fullscreen gallery and lets the page stay the single owner of viewer state.
- Preserve the old zoom/dismiss interaction for true single-photo viewers; only the multi-photo path should switch to `Swiper`-style horizontal paging.

## 84. Audio/music bubbles need a dedicated media atom, not the document tile
- In this repo, reusing `TgDocumentRow` for `audio` preserved download behavior but kept the whole message visually in the generic file/document family.
- Telegram music messages are closer to a playback affordance + title/performer stack than to an extension-badge document tile, so the safer pattern is a separate `TgAudioBubble` atom and dedicated router branch.
- Keep the tap contract page-owned: if the file is missing, request download; if it is local, open/play it from the page layer. Do not bury file-opening logic inside the atom itself.

## 85. On-demand media taps need their own pending-file dedupe, not just watcher-level dedupe
- `DownloadAvatarsUseCase` and `DownloadMessageMediaUseCase` already guard duplicate background requests with `pendingFileIds`, but `TgChatScreenPage.requestMediaDownload(...)` used to fire a fresh `downloadFile` on every tap.
- The 2026-03-16 `[31799]` HiLog proved this with repeated `On-demand media download requested: fileId=2274` lines for the same item before the local path appeared.
- Fix pattern for this repo: keep a page-owned pending-file set for on-demand taps, clear it when the local path lands in timeline state or the request fails, and drive bubble spinners from that same pending set.

## 86. Media bubbles must expose explicit download/pending states once auto-download is tightened
- After reducing background auto-downloads, relying on a hidden tap contract makes media look broken: GIF/videoNote bubbles can show only a preview thumbnail, and voice/audio/document bubbles can look idle even though the file is missing.
- The safer Telegram-like fallback in this repo is: show a download affordance before the file is local, switch to an indeterminate spinner while the file is pending, then reveal the normal play/open affordance after the local path appears.
- This keeps the UI honest when heavier payloads like voice, GIF, and videoNote are intentionally on-demand while previews and full photos can still remain eager for a smoother viewer path.

## 87. Audio and file bubbles need a composed leading cluster, not a single flat tile/control
- In this repo, even after transfer state was wired correctly, `audio` still looked too much like a slightly modified document row and `document` still read as a flat badge block.
- The closer Telegram-style fallback is a **composed leading cluster**: a primary square tile that carries identity (album-art-like surface or extension badge) plus a smaller secondary action chip that carries open/download/play affordance.
- This separation makes idle state easier to parse and lets download/pending state temporarily take over the primary tile center without losing the component's family resemblance.

## 88. Real chats may hide audio-looking messages behind the `document` route
- In this repo, not every user-visible “audio file” arrives as `messageAudio`; some real payloads still stay on the `document` path with `mimeType = audio/*`.
- If only the dedicated `audio` branch is restyled, the user can correctly report “nothing changed” because the messages they are looking at never hit that branch.
- Safe fallback: in `TgMessageRouter`, treat `contentType = 'document'` + `mimeType.startsWith('audio/')` as an audio-like visual path while keeping the existing document open/download behavior.

## 89. Audio/file bubble parity lives or dies on control hierarchy, not on token micro-polish
- In this repo, a softer “square tile + tiny chip” pass was technically different but visually still read almost the same to the user.
- Telegram iOS and Android refs both show file/audio cells organized around a **dominant primary control area** (`~44pt/48dp`) with text stacked to the side.
- If refs show control-first composition, do not expect color/gap tweaks on the old flat structure to create a meaningful visible delta.

## 90. When the visual hierarchy changes, sync the atom passports immediately
- In this repo, the tg_ui specs are used as the frozen contract for later passes and demos.
- If an atom moves from a composed-tile layout to a control-first layout but the spec still describes the old hierarchy, later verification becomes misleading and future agents can “fix” the component back toward the wrong shape.
- After any non-trivial UI rewrite, update the matching `spec/*.md` passport in the same patch.

## 91. Audio bubble must use art tile, not plain circle button — iOS/Android refs both use a square tile
- iOS `ChatMessageInteractiveFileNode` uses a 44pt rounded-rect tile (album art or gradient + note) as the leading anchor, not a plain circular play button.
- Android `AudioPlayerCell` uses `RadialProgress2` embedded in a similar tile.
- The old plain circle button made audio messages look identical to voice messages. The gradient square tile with `borderRadius(12)` creates the correct music-vs-voice visual separation.

## 92. Video note overlays must be semi-transparent, not opaque circles
- iOS `InstantVideoRadialStatusNode` draws play/download icons as semi-transparent white (#99FFFFFF) directly over the video preview — there is no opaque background circle behind the icon.
- Download progress is a radial `Progress(Ring)` around the entire circle perimeter, not a centered spinner.
- The old opaque `VIDEO_BUBBLE_PLAY_BG` circle made video notes look like regular video bubbles instead of the lightweight iOS pattern.

## 93. Declare token constants even before they are wired to runtime — but note unused ones
- `AUDIO_BUBBLE_ART_SIZE`, `AUDIO_BUBBLE_ART_RADIUS`, `AUDIO_BUBBLE_ACTION_*` existed in `TgUiTokens` but were never used in the component code, leading to a false impression that the feature was implemented.
- When adding forward-looking tokens, either wire them immediately or add a `// TODO: not yet wired` comment so future agents don't assume implementation exists.

## 94. `shouldReactToStoreChange` must include `files.transfers` — otherwise download progress is invisible
- `TgChatScreenPage.shouldReactToStoreChange()` checked `messages`, `chats`, `typingActions`, and `users` — but NOT `files.transfers`.
- When `filesReducer` updated `state.files.transfers` on `fileTransferUpdated`, the store subscription returned `false` → timeline never rebuilt → download progress indicators were never shown in any media bubble.
- This made all download animations (documents, audio, video, voice) completely invisible despite the full pipeline being correctly wired from TDLib through FileNormalizer → filesReducer → ChatTimelineVO → router → bubble atoms.
- **Rule:** when adding a new state slice that affects UI rendering, always add it to the store subscription filter in every page that reads from that slice.

## 95. Voice/GIF/VideoNote must be auto-download — Telegram always auto-downloads these
- `downloadMessageMedia.ets` had voice, animation, and videoNote in the "on-demand" category.
- Telegram iOS and Android auto-download voice messages, GIFs, and video notes by default.
- Without auto-download, voice messages required two taps (tap to download → tap to play), which felt broken.
- Audio and full video stay on-demand (user-initiated download) as they can be large.

## 96. Use a unified playback controller for voice AND audio — not separate paths
- The old `VoicePlaybackController` only handled voice; audio tapped `viewData` to open an external app.
- Telegram iOS uses a unified `MediaPlayer` + `SharedMediaPlayer` for all audio types.
- Telegram Android uses `MediaController` + `ExoPlayer` for everything.
- Unified `MediaPlaybackController` enables: inline playback for both types, auto-advance to next voice/audio in sequence, shared play/pause state so only one thing plays at a time.

## 97. iOS audio bubble uses a 44pt ROUND circle, not a square tile
- Initial rewrite changed the art tile from round (RADIUS_ROUND_MAX) to rounded square (radius 12), thinking it would differentiate from voice.
- iOS `ChatMessageInteractiveFileNode` confirms: audio/music also uses a 44pt diameter circle for the play/progress control.
- Visual "improvements" that diverge from the reference create drift, not parity. Always check the reference before inventing new geometry.

## 98. DevEco may cache old artifacts — always Clean Build after .ets rewrites
- After rewriting TgAudioBubble.ets with new layout (art tile, seek bar, gradient), a normal rebuild showed no visual change on device.
- HarmonyOS hvigor/DevEco can cache compiled artifacts. Use Build → Clean Project → Build to force fresh compilation.
- If visual changes don't appear after rebuild, suspect build cache before debugging code.

## 99. Router must pass fileId props for each media type — not reuse documentFileId for photos
- Photo download was wired to `this.documentFileId` in router, which is always 0 for photo messages.
- Each media type needs its own fileId prop: `photoFileId`, `videoFileId`, `audioFileId`, `documentFileId`, `voiceFileId`.
- The page already has these IDs from ChatTimelineVO — they just need explicit prop forwarding.

## 100. videoNote download used `voiceFileId` instead of `videoFileId` — wrong file entirely
- Copy-paste error in router: instant video download callback used `this.voiceFileId`.
- videoNote shares the `videoFileId`/`videoPath` path in ChatTimelineVO, not voice.

## 101. `onPlayToggle` / `onSeek` passed as no-ops kill audio/voice bubble interactivity
- Router was passing `() => {}` for `onPlayToggle` and `onSeek` in audio/voice branches.
- The atoms' art tile and seek gestures visually exist but do nothing without real callbacks.
- Wire `onPlayToggle` → same handler as `onTap`, wire `onSeek` → `seekToProgress()` on controller.

## 102. Document preview URI may already be a file:// URI from ChatTimelineVO
- `TgDocumentRow` prepended `'file://' +` to `documentPath`, but the VO already normalizes paths to file:// URIs.
- Result: `Image('file://file://...')` which silently fails. Just pass `this.documentPath` directly.

## 103. Animation/GIF should have a dedicated bubble, not ride on TgVideoBubble with hidePlayButton
- `TgVideoBubble + hidePlayButton` hack loses GIF-specific semantics: "GIF" badge, no play button, auto-play surface.
- Dedicated `TgAnimationBubble` makes the route explicit and allows GIF-specific behavior later.

## 104. AVPlayer `prepare()` requires `initialized` state — fdSrc assignment is async
- Calling `prepare()` immediately after `player.fdSrc = ...` causes "current state is not stopped or initialized" errors.
- `fdSrc` triggers an async state transition to `initialized`. Must wait for that state before calling `prepare()`.
- Also: `release()` on an active player (`playing`/`paused`) should `stop()` first to avoid "unsupport release" errors.
- Fix: `waitForState('initialized', 2000)` helper + explicit `stop()` in `release()`.

## 105. Store subscription handlers that scan full state need throttle/debounce
- `DownloadAvatars` subscribed to `users`/`chats` changes and ran a full scan on every update.
- During initial load with 100+ chats, each chat addition triggers a store update → scan → log line.
- Result: 269 scan iterations in 5 minutes, mostly redundant.
- Fix: throttle scan to max once per 500ms, use latest state at execution time instead of captured state.

## 106. V1 @Component using V2 child needs @State declarations for bound state
- `TgChatScreenPage` (V1 `@Component`) uses `TgMediaGalleryPage` (V2 `@ComponentV2`) as overlay child.
- Properties like `showMediaGallery`, `galleryItems`, `galleryInitialIndex` passed to V2 child must be declared as `@State` in the V1 parent — otherwise the variables exist at runtime but the compiler cannot track reactivity and build may succeed while UI silently fails to update.
- Always declare state variables before using them in builder expressions.

## 107. Do not use `$r('sys.media.*')` for icons that may not exist on all API levels
- `$r('sys.media.ohos_ic_public_download')` caused a build error because the resource is not guaranteed to exist.
- Use project-local icon resources via `TgUiTokens.ICON_RES_*` tokens instead.
- Rule: all icons go through TgUiTokens, never reference `sys.media` directly in atoms.

## 108. Token names must exist before referencing — use grep to verify
- `FONT_BODY_SIZE` was referenced in TgMediaGalleryPage but did not exist in TgUiTokens.
- Always verify token existence with grep before using in new components.
- Closest match: `FONT_PREVIEW_SIZE` (15) for body text, `FONT_META_SIZE` (13) for secondary text.

## 109. Clean up crashed agent worktrees and branches immediately
- API 500 errors during parallel agent execution left orphaned worktree branches (`worktree-agent-*`, `feat/media-gallery-page`) with no useful commits.
- These consume branch namespace and can cause confusion on next session.
- After any agent crash: check `git worktree list` + `git branch`, remove orphans.


## 48. Documentation inventory and active shell path must be derived from the tree
- In this repo, copying an older snapshot into docs is enough to create false claims such as “`TgSearchBar` was removed” or “the latest commit is still `511e6cb`”.
- Before updating human-facing docs, derive facts from the real tree: current HEAD, actual file counts, live imports, and smoke scripts.
- Current example: `TgSearchBar` still exists in `tg_ui`, while the live Chats shell uses `TgChatListNavigationBar` with stock ArkUI `Search`; both facts matter and must be documented separately.


## 49. Unrecorded verification turns into fake blockers in docs
- In this repo, large parts of the product were already runtime-verified, but the result was not written back into `STATUS.md` / `TASKS/TODO.md`.
- That creates false blockers for future sessions, who then waste time re-opening already finished verification work.
- When a verification pass is accepted (including explicit user confirmation), sync the docs immediately and clearly label any retained checklists as historical regression references.


## 50. Smoke checks must evolve with the runtime, not with old migration assumptions
- In this repo, `scripts/smoke-ui-phase0.ps1` was still asserting `@Reusable` on `TgChatRow` even after the live row path had already moved to `@ComponentV2`.
- A stale smoke script is worse than no script: it turns real cleanup work into false failures and hides the actual regressions.
- When the runtime contract changes (for example V1 -> V2 component migration), update the smoke checks in the same pass.

## 110. Chat-list diff equality must include prefix and pinned-boundary flags
- In this repo, `ChatListDataSource.isSameChatRow(...)` did not compare `previewPrefix`, `previewPrefixStyle`, `isDraft`, or `isLastPinned`.
- Result: same-order chat rows could silently skip UI refreshes when only draft/author prefix styling changed, or when the pinned-boundary spacer should appear/disappear.
- If a list uses incremental `onDataChange(...)` updates, every user-visible row state that affects layout/text/separators must be included in the equality check.

## 111. Custom composer shells should use ArkUI inline text style, not default text-box chrome
- In this repo, `TgComposerInput` is a custom glass-shell composer, not a stock boxed form field.
- `TextArea.style(TextContentStyle.DEFAULT)` reintroduces stock input-box behavior that can visually fight the custom capsule.
- For this kind of Telegram-like composer shell, prefer `TextContentStyle.INLINE` so the custom glass container stays visually in control.

## 112. When a comparison doc already identifies high-confidence visual deltas, prefer the narrow fixes first
- In this repo, local comparison docs already called out concrete top-bar and chat-row mismatches such as `Bold` vs iOS `semibold`, `37vp` vs `38pt` avatar inner size, and an overly wide avatar-to-text lane in the chat list.
- The safe next step is to fix those explicit deltas first and verify, not to jump straight into broader redesigns or speculative feature additions.
- This keeps parity work reviewable and prevents “fixing” unrelated parts of the shell while chasing one visual complaint.

## 113. When porting a complex Telegram surface, decompose the iOS composition before hunting HarmonyOS controls
- In this repo, the correct unit of analysis is often a **UI zone** (for example the whole upper header area), not a single atom and not the whole screen.
- The reliable method is: `Reference Decomposition -> Platform Mapping -> Assembly`.
- First extract iOS layers, content/state model, layout invariants, visual decisions, and behavior. Then look for HarmonyOS analogs. Only after that decide how to assemble the result in our architecture.

## 114. Upper chrome must be split into shared background, content composition, and derived state
- In this repo, top bars started drifting when they tried to own too much at once: blur/tint surface, geometry, state derivation, and accessory behavior.
- Telegram iOS upper chrome is layered. Preserve that by splitting responsibilities:
  - screen/page derives state and owns placement,
  - V2 composition components render content,
  - shared background primitive owns blur/tint/top-edge emphasis.
- If a top bar feels like one “magic widget”, the ownership is probably wrong.

## 115. Extract the shared upper-background primitive before rewriting every top bar
- In this repo, `TgChatListNavigationBar` originally owned both content layout and the full blur/specular background internally.
- The safer first step was to extract `TgTopChromeBackground` and make the chat-list header render above it.
- This keeps the migration incremental: first centralize the shared background responsibilities, then move other top bars onto the same model.

## 116. After extracting the shared top background, move each top bar onto it before optical tuning
- In this repo, the next safe step after introducing `TgTopChromeBackground` was to rehost `TgChatTopBar` on top of it without redesigning every capsule.
- This prevents doing visual tuning on the wrong ownership model.
- Rule: first align ownership, then tune optics.

## 117. After ownership is correct, reduce capsule mass with the smallest token pass before adding features
- In this repo, once `TgChatTopBar` was moved onto the shared background, the next justified fix was **not** to add search/call/typing features immediately.
- The user-visible problem was optical: the center capsule felt too wide and too heavy. The correct response was a narrow token pass (gap, padding, min width, border stroke), verified by build/smoke.
- Rule: if the structure is correct and the complaint is visual weight, first try the smallest token/composition correction before opening a larger feature branch.

## 118. Do not over-customize shell chrome when the platform is already converging toward the target language
- In this repo, a lot of effort went into manually reproducing glass/island shell surfaces that were not actually the strongest Telegram-specific invariants.
- Repeated API 23 beta visuals indicate that HarmonyOS shell chrome is moving much closer to the desired direction. When that happens, the better strategy is to preserve Telegram semantics and move shell containers toward native/hybrid paths instead of continuing endless custom chrome polishing.
- Rule: spend custom effort where Telegram identity truly lives; treat shell chrome as a platform-quality problem first, not a default custom-atom problem.

## 119. For chat top bars, enrich subtitle semantics before adding more chrome features
- In this repo, once the upper-chrome ownership and optical mass were acceptable, the next high-value gap was not another glass tweak but the missing Telegram chat-title state model.
- The safer first expansion is an explicit subtitle contract (`secondary` / `online` / `activity`) derived at the screen level, with typing/action states mapped from the normalized store and passed into the atom as plain V2 params.
- Rule: for `TgChatTopBar`, prefer screen-derived subtitle/title semantics before reopening search buttons, badge chrome, or more capsule styling.

## 120. In `TgChatRow`, prefer title-side Telegram badges before more shell-like row cosmetics
- During the row completeness audit, the better next improvement was not another spacing/material tweak but a missing Telegram-specific title state that already had data in the store (`user.isVerified`).
- The safe pattern is: extend `ChatItemVO`, pass a flat V2 prop into `TgChatRow`, and update `ChatListDataSource` equality so same-order rows repaint when the new semantic flag changes.
- Rule: when a Telegram-specific row state already exists in the local model, surface it through the row contract first before inventing more general-purpose visual polish.

## 121. Do not split composer reply semantics between the screen and the atom
- In this repo, `TgComposerInput` already had a reply-strip contract in its passport, but the live chat screen had drifted to a separate hand-built `buildReplyBar()` above the composer.
- That duplication weakens the V2 ownership model and guarantees spec/runtime drift. The screen should own reply state; the composer atom should own rendering of the reply strip and its cancel affordance.
- Rule: for composer semantics, keep state derivation in `TgChatScreenPage` and keep reply-strip UI composition inside `TgComposerInput`.

## 122. Reply previews should resolve Telegram media semantics in the timeline, not leak raw content types into UI
- In this repo, the generic reply pipeline was still returning `[Unsupported message]` or raw internal `contentType` strings like `videoNote` in real user-facing reply snippets and action-menu reply previews.
- The better contract is to normalize reply preview semantics where the replied message is already known: `ChatTimelineVO` should produce user-facing labels (`Photo`, `Video`, `GIF`, `Voice message`, `Video message`, `Sticker`, file name / `File`) and attach reply thumbnails when a local preview path exists.
- Rule: keep `TgReplySnippet` presentation-only; derive media-aware reply labels and thumbnail sources upstream in timeline/screen logic, and include those fields in datasource equality so late thumbnail hydration still repaints the row.

## 123. Start a message-surface reset with a parallel text-family atom, not a router rewrite
- In this repo, the safest first step of the bubble rebuild is not to tear open `TgMessageRouter` immediately.
- A better pattern is to land a parallel presentation-only atom (`TgTextBubbleV2`) with its own passport and demo, composed from existing primitives (`TgMessageBubbleBase`, `TgReplySnippet`, `TgMessageMeta`), and only then do a narrow live swap for the text branch.
- Rule: for partial UI resets, replace the most common visual family first in parallel, prove it in demo/build, then integrate narrowly instead of attempting a monolithic router-first rewrite.

## 124. After a parallel bubble atom lands cleanly, the next safe step is a single-branch live swap
- In this repo, once `TgTextBubbleV2` had atom/spec/demo coverage and build verification, the correct integration move was not a broad `TgMessageRouter` rewrite.
- The safe path is to swap only the live `text` branch onto the new atom, keep avatar-lane ownership where it already works, and leave media/document/voice/sticker paths untouched until their own shells are ready.
- Rule: promote a parallel message-surface atom into runtime one branch at a time; do not force all content families through the new architecture in one patch.

## 125. After the text-family swap, extract one visual-media shell before touching non-visual branches
- In this repo, the next high-value router cleanup step after `TgTextBubbleV2` was not voice/document/audio refactoring and not a full molecule rewrite.
- The safer move is to extract a shared **visual-media shell** (`photo`, `photoAlbum`, `video`, `animation`) because those branches already share the same sender/reply/media/caption/meta structure in Telegram, while `videoNote` and non-visual media have different geometry contracts.
- Rule: after a text-family reset, pull one coherent media family into its own presentation atom and do a narrow live swap for that family only; keep instant video and non-visual rows on their dedicated paths until their own contracts are ready.

## 126. Quote mode must come from explicit reply data, not from preview length heuristics
- In this repo, `ChatTimelineVO` had started using `replyPreview.length > 80` as a fake proxy for quote mode.
- That makes quote UI nondeterministic and ties product semantics to incidental string length. The correct contract is explicit: `replyIsQuote`, `replyQuoteText`, and optionally `replyQuoteOffset` should come from the message/reply data path, while the UI stays presentation-only.
- Rule: if quote support is not truly available yet, keep the contract explicit and future-ready rather than inventing heuristics from text length.


127. For visible quotes in chat bubbles, do not fake it from reply previews or string heuristics. Carry explicit quote ranges from TDLib text entities, then render them in a dedicated text-body atom so the live text branch can gain quote parity without reopening non-text branches.


128. After adding visible blockquotes to text messages, reuse the same explicit quote-range contract for media captions instead of inventing a second caption-only renderer. Keep the quote-body atom shared and extend shell family by family.


129. Telegram iOS blockquote tint is not a universal blue. In the text-bubble path it is derived from `baseQuoteTintColor = mainColor`, and in incoming group-message cases that `mainColor` can follow the sender-name color. When quote rendering looks too tall, first remove layout inflation from the accent-bar container and tighten quote paddings before reopening the whole bubble/meta layout.


130. For quoted bubbles, a dedicated meta row is an easy but visually expensive shortcut. A closer Telegram-style path is to keep the invisible trailing reserve on the final visible segment (plain or quote) and let the bubble reuse the standard bottom-right overlay meta behavior; only special trailing-width heuristics should remain after that.


131. When a user says quote color/height “did not change,” check whether they are actually looking at the reply snippet path. In this repo, `TgReplySnippet` is a separate visual contract from body blockquotes and must be tightened/tinted independently.


132. In quote/reply snippets, a full-height accent bar (`height('100%')`) can become the reason the whole snippet feels too tall. If the stripe should follow content, give it an explicit content-sized height and let the outer snippet collapse to text instead of enforcing a container-wide min-height.


133. When a Telegram quote/reply stripe looks “detached,” the issue may be its horizontal inset, not only its height. The stripe should usually be anchored to the left edge of the quote surface, while only the text content gets inner padding. For sender-name fallback colors, prefer the iOS `PeerNameColors.defaultSingleColors` palette over ad-hoc local hues.


134. If sender/reply/quote colors “still feel wrong,” changing fallback hexes is often the wrong layer. Telegram peers carry accent identity in data (`nameColor` / `accent_color_id` style fields), and UI should prefer that protocol-backed source first. Only use a local palette as a fallback resolver when the peer accent id or the full accent-color table is unavailable.


135. A peer `accent_color_id` alone is not the whole resolver for Telegram colors. Non-built-in ids need the global TDLib `updateAccentColors` table; for one-color UI surfaces (sender names, reply stripes, quote accents), prefer `built_in_accent_color_id` from the accent definition first, and only then fall back to exact theme color arrays or local defaults.


136. In reply snippets, do not reuse the current message sender color for the stripe/title/tint. Telegram reply info colors are tied to the **quoted author**; carry a separate `replyAuthorColorHex` from the replied message and keep it distinct from the current bubble's `senderColorHex`.


137. If a body blockquote stripe looks too short inside a rounded quote area, the problem is usually outer-container padding, not only stripe height. Keep the stripe as a full-height left-edge layer inside the clipped rounded surface, and move padding to the text-content row so the line visually reaches the quote block edges.


138. If a quoted caption inside a media bubble looks more centered than the normal caption and seems to have larger edge insets, first compare the width contracts. In this repo the real bug was the quote-caption branch using `width('100%')` while the normal caption branch used `visualMediaBubbleWidth()`. Match structural width first; do not start with padding tweaks.

139. If users want all quote/reply variants to feel the same, do not keep body blockquotes on a full clipped surface stripe while reply snippets use a shorter content-sized bar. In this repo, `TgReplySnippet` should follow the same left-edge full-surface stripe contract as `TgMessageTextBodyV2`; otherwise the two quote paths will keep reading as different UI systems.

140. If quote/reply variants are supposed to feel like one system, do not leave `TgReplySnippet` on a separate shell-token family after body blockquotes already use `MSG_QUOTE_*`. In this repo the right split is: one shared quote-surface geometry/tint contract, different content models on top of it.

141. In ArkUI `Stack`, a full-height decorative child can still distort perceived sizing if it participates like a normal layout child. For reply snippets in this repo, keep the stripe full-height but make it a positioned overlay layer so the content, not the stripe, determines snippet height.

142. When a user reports that group-chat reply height is still wrong, first confirm the exact runtime path. In this repo, normal participant-to-participant text replies are `TgMessageRouter -> TgTextBubbleV2 -> TgReplySnippet`; once stripe geometry is already isolated, the next likely cause is reply-snippet text density (`padding_v`, line gap) or the parent gap around the snippet, not the quote stripe itself.

143. When repeated stripe/layout tweaks still do not fix reply-snippet height, stop patching the same overlay model. In this repo, the correct next move was to replace the `TgReplySnippet` `Stack` composition with a content-driven `Row`, keeping the stripe as a left child and the text block as the weighted content region.

144. Once `TgReplySnippet` internals are already tightened, the remaining excess height in ordinary group-text replies may live in the caller path, not in the snippet. In this repo, `TgTextBubbleV2` can add extra frame through its own margin/padding around the snippet, so inspect caller spacing before reopening the snippet internals again.

145. The user was right that the height regression started when the stripe was pushed edge-to-edge. In this repo the fix is to separate measurement from decoration again: keep a content-measuring base row for the quote surface, and render the stripe as a positioned overlay so it can reach the edges without becoming the thing that defines height.

146. If the quote surface is already content-sized but the stripe still looks wrong, stop changing the whole container. In this repo the remaining issue was the stripe contract alone: it needed explicit content-following height and a top offset equal to the snippet's vertical padding, not another full-surface height model.

## 147. Reply stripe contract should follow the reply surface, not float beside it
- **Context:** The reply-snippet line kept oscillating between “outside overlay” and “full-height lane” fixes, which made it hard to tell whether the geometry problem was height or ownership.
- **Discovery:** Android makes the ownership explicit: `ChatMessageCell` draws the reply background and then `ReplyMessageLine.drawLine(...)` against the same reply rect. The line is structurally part of the quote/reply surface.
- **Lesson:** For reply/quote blocks, first decide **which surface owns the stripe**, then tune padding/density. If the stripe is conceptually outside the clipped surface, later height/padding fixes will drift again.
- **Tradeoff:** In ArkUI, putting the whole reply surface on the root `Stack` plus a `height('100%')` stripe looked structurally closer to Android, but reintroduced the height regression. For this repo, visual ownership and measurement ownership may need to stay split: stripe behaves like part of the quote area, but content row should still own height.

## 148. cloneMessagesState must share inner Maps by reference
- **Context:** Selector memoization (`selectChatMessages`, `selectChatMessagesForChatView`) compared inner `Map<string, Message>` by reference (`===`) to skip expensive O(n log n) re-sorts.
- **Discovery:** `cloneMessagesState()` was creating `new Map(messageMap)` for EVERY chat on EVERY message dispatch. This broke reference identity for ALL chats, causing cache miss and full re-sort on every single event — even events for unrelated chats.
- **Lesson:** When cloning a nested map structure for immutable state, only the outer container needs a new instance. Inner maps should be shared by reference; the reducer already creates a new inner Map for the specific chat it modifies.
- **Fix:** `new Map<number, Map<string, Message>>(messages.messages)` — single constructor call, shares all inner maps.

## 149. pendingFileIds must be cleaned up by resolved state, not only by gateway response
- **Context:** `DownloadMessageMediaUseCase.pendingFileIds` tracked in-flight downloads to prevent duplicate enqueue.
- **Discovery:** When TDLib completes a download via `updateFile` → FileNormalizer (the normal path for larger files), the file path gets updated in the store, but `pendingFileIds` was never cleaned up — it only cleared on direct gateway response or error. The Set grew monotonically for the lifetime of the session.
- **Lesson:** Any dedup tracking Set that guards async operations must have a secondary cleanup path that syncs with the actual resolved state, not only with the initiating promise.
- **Fix:** Added `scanFileSlot()` that deletes fileId from pendingFileIds when the path is already resolved (non-empty).

## 151. Action menu: parallel arrays (buttons + actions) eliminate index tracking bugs
- **Context:** Expanding the long-press action menu with conditional buttons (Edit only for own non-sticker messages, Copy only if text present).
- **Discovery:** Using incremental index counter (`idx++`) to match dynamic buttons is fragile and error-prone. Parallel arrays (`buttons[]` + `actions[]`) with `actions[result.index]()` dispatch are cleaner and immune to ordering bugs.
- **Lesson:** For dynamic action menus, build buttons and their handlers in parallel arrays. Dispatch by index into the actions array. Never hardcode button positions.

## 154. showActionMenu buttons must be tuple, not array
- **Context:** ArkTS `showActionMenu` expects `buttons: [Button, Button?, Button?, Button?, Button?, Button?]` — a fixed-length tuple.
- **Discovery:** Building buttons dynamically with `Button[]` fails compilation: "Type 'Button[]' is not assignable to type '[Button, ...]'".
- **Fix:** Cast via `as [promptAction.Button, promptAction.Button?, ...]`. The tuple still accepts 1-6 elements.

## 156. Chat row needs press feedback for iOS parity
- **Context:** iOS highlights chat rows on tap. Our rows had no visual feedback.
- **Fix:** `.stateStyles({ pressed: { .backgroundColor(BG_SECONDARY) }, normal: { .backgroundColor(Transparent) } })` on ListItem.
- **Lesson:** Always add press state feedback on tappable list items. Silent taps feel broken.

## 157. Refresh component needs $$ two-way binding for refreshing state
- **Context:** `Refresh({ refreshing: this.isRefreshing })` doesn't auto-reset the spinner.
- **Discovery:** HarmonyOS docs explicitly state: "This parameter supports two-way binding through $$". Without `$$`, the component can't set `isRefreshing = false` after the refresh animation completes.
- **Fix:** `Refresh({ refreshing: $$this.isRefreshing })`. Works with `@Local` in `@ComponentV2`.

## 158. In shrink-wrapped ArkUI bubble shells, footer meta should follow content width, not `width('100%')`
- **Context:** Several non-text bubble branches in `TgMessageRouter` still rendered time/status through a generic footer row with `width('100%')`.
- **Discovery:** In shrink-wrapped ArkUI columns this is ambiguous: the footer can stretch against a looser container contract than the actual measured content width, so the time/status cluster visually drifts away from the bubble edge.
- **Lesson:** For sticker/contact/location/poll/document-style bubbles, anchor the footer meta with `alignSelf(ItemAlign.End)` (or another explicit trailing contract) so it follows the real content width instead of a guessed full-width footer.
- **Reference grounding:** Local Telegram iOS refs (`ChatMessageAttachedContentNode`, `ChatMessageMapBubbleContentNode`, `ChatMessagePollBubbleContentNode`, `ChatMessageAnimatedStickerItemNode`) place the date/status node against the trailing rendered content, not a generic stretch footer row.

## 159. Sticker and plain-map messages are image-like surfaces; their time/status belongs on the surface, not under it
- **Context:** Even after the generic footer-row fix, sticker messages and map-only location messages were still special cases.
- **Discovery:** Local Telegram iOS refs show animated-sticker and plain-map paths anchoring `dateAndStatusNode` against the rendered media/image frame itself. Treating them like ordinary text-card footers keeps the time visually detached from the real surface.
- **Lesson:** When a message body is effectively a standalone media surface (sticker, map snapshot without venue text, instant-video, photo/video without caption), use bottom-right overlay meta tied to that surface. Reserve footer rows for card-like content with real text/body below the media.

## 155. Migrate deprecated promptAction to UIContext.getPromptAction()
- **Context:** `promptAction.showToast()` and `promptAction.showActionMenu()` from `@kit.ArkUI` are deprecated since API 18.
- **Discovery:** Build warnings flagged these. Official docs say: use `this.getUIContext().getPromptAction().showActionMenu()` instead.
- **Lesson:** In `@ComponentV2` structs, always use UIContext-based API for prompt/dialog/toast. The global `promptAction.*` functions may have ambiguous UI context and will be removed.

## 153. Search mode in top bar should replace content, not add a layer
- **Context:** Adding in-chat message search to TgChatTopBar.
- **Discovery:** iOS ref (`ChatSearchNavigationContentNode.swift`) replaces the title area with an inline search field in the same glass capsule, rather than adding a separate overlay or sheet.
- **Lesson:** For mode-switching UI (normal → search), prefer content replacement within the existing container shape over adding new layers. This preserves the capsule glass design and avoids z-order/layout complexity.

## 152. iOS reference determines action menu order and edit eligibility
- **Context:** First implementation guessed the action order (Reply → Copy → Edit → Forward → Delete).
- **Discovery:** iOS reference (`ChatInterfaceStateContextMenus.swift`) shows: Reply → Edit → Copy → [media] → Forward → separator → Delete. Edit excludes stickers, videoNotes, contacts, polls, games, invoices — not just "has text".
- **Lesson:** Always inspect iOS reference before implementing Telegram UI semantics. The order and conditions are product decisions, not engineering guesses.

## 150. Debounce 0ms in store subscription is a no-op
- **Context:** ContactsPage and CallsPage used `setTimeout(..., 0)` for rebuild debounce.
- **Discovery:** `setTimeout(fn, 0)` on HarmonyOS schedules on next microtask but provides zero actual debounce — rapid state changes still trigger rapid rebuilds.
- **Lesson:** Match the debounce value across all pages. ChatListPage uses 300ms — other tabs should use the same unless there's a specific reason for a different value.

## 153. Params wired through VO but not rendered are invisible bugs
- **Context:** TgChatRow had `isTyping` as `@Param` since initial implementation. ChatItemVO built `typingText` correctly. ChatListPage swapped preview text when typing. But TgChatRow never used `isTyping` to change visual appearance.
- **Discovery:** The typing preview text was already showing, but in the same gray color as normal preview — no visual distinction for the user.
- **Lesson:** When adding a state param to a component, always check that the `build()` method actually uses it for visual differentiation. An unused `@Param` is a silent gap.

## 154. Edit mode needs the same visual pattern as reply mode
- **Context:** TgComposerInput had a full reply snippet bar (author + preview + cancel). Edit mode existed at screen level (startEditMessage/cancelEditMessage) but had zero visual signal in the composer.
- **Discovery:** Users could enter edit mode via action menu, and the composer text would change, but nothing indicated they were editing vs. writing a new message. Cancel was only possible via sending empty text.
- **Lesson:** Any modal composer state (reply, edit, forward) needs its own snippet bar following the same pattern: label + preview + cancel button.

## 155. Data extracted by normalizer but not applied by reducer is invisible
- **Context:** ChatNormalizer had `handleChatUnreadMentionCount` handler for over a month. ChatDto had `unreadMentionCount` field. But Chat model in AppState never received it, chatsReducer never applied it, cloneChat never copied it.
- **Discovery:** The full TDLib → normalizer → DTO pipeline was present but the reducer → model link was missing. No amount of UI work could surface mention badges.
- **Lesson:** When adding a TDLib update handler, trace the full pipeline: normalizer → DTO → reducer → model → cloneChat → VO → UI. If any link is broken, the data is extracted but never reaches the screen.

## 156. Splitting a merged TDLib type requires fixing all downstream guards
- **Context:** `chatTypeSecret` was previously merged with `chatTypePrivate` into one `'private'` type. Adding a separate `'secret'` type broke guards that only checked `type === 'private'`.
- **Discovery:** Three places (TgProfilePage, ChatTimelineVO, ChatItemVO) relied on `type === 'private'` for peer-user logic. ChatItemVO was safe (uses `peerUserId > 0` instead of type check), but the other two needed `|| chat.type === 'secret'`.
- **Lesson:** When splitting a merged enum value, grep for ALL downstream consumers of the original value. `peerUserId > 0` is more resilient than `type === 'private'` for "is this a 1:1 chat" checks.

## 157. toFileUri() breaks MediaPlaybackController — paths for playback must stay raw
- **Context:** `ChatTimelineVO.ets` converted `audioPath` via `toFileUri()` to `file://` URI for consistency with photo/video Image components. But `MediaPlaybackController` uses `fs.openSync(filePath)` which needs raw sandbox paths.
- **Discovery:** `voicePath` was NOT converted (worked fine), but `audioPath` was converted (broke playback). `documentPath` also converted — breaks document-as-audio playback since the same path flows to `handleAudioTap` → `controller.toggle()`.
- **Lesson:** `toFileUri()` is ONLY for ArkUI Image/Video components. Paths used by `fs.openSync()`, `AVPlayer.fdSrc`, or other file-system APIs must remain raw sandbox paths. When a path serves dual purposes (UI display + playback), either store both forms or convert file:// back to raw at the playback boundary.

## 158. Event handlers declared in component but not wired at instantiation are silent failures
- **Context:** `TgMessageRouter` declared `@Event onAudioSeek` and `@Event onVoiceSeek`. `TgChatScreenPage` had `handleAudioSeek` and `handleVoiceSeek` methods. But neither was passed in the TgMessageRouter constructor call.
- **Discovery:** Seek gestures in TgAudioBubble and TgVoiceBubble fired the events, which called the default no-op `() => {}`. No error, no warning, just silent non-functionality.
- **Lesson:** After adding `@Event` to a component, immediately grep for all instantiation sites and wire the handler. ArkTS does not warn about unwired events — they silently use defaults.

## 159. Canvas waveform must use @Monitor for reactive playback progress
- **Context:** TgVoiceBubble drew waveform bars in Canvas `onReady()` which fires once. Playback progress changed `playbackProgress` but Canvas never redrew — waveform coloring stayed static.
- **Discovery:** iOS uses AudioWaveformComponent with progress-driven coloring. Our Canvas had no reactive update mechanism.
- **Lesson:** Canvas `onReady()` fires once. For reactive updates, extract drawing to a method, flag `canvasReady`, and use `@Monitor('playbackProgress', ...)` to call the redraw method. Also use `lineCap='round'` + `stroke()` for iOS-matching rounded bar caps instead of `rect()`+`fill()`.

## 160. Hardcoded colors in bubble components must use shared tokens
- **Context:** All 4 media bubbles had `#40000000` (overlay), `#FFFFFF` (progress), `#40888888` (seek bg), `#99FFFFFF` (ring) hardcoded inline.
- **Discovery:** Changing one overlay color would require editing 4+ files. iOS uses theme-centralized colors.
- **Lesson:** Add shared tokens (`MEDIA_OVERLAY_DARK`, `MEDIA_PROGRESS_COLOR`, `MEDIA_SEEK_BG`, etc.) in TgUiTokens for cross-component media styles. Replace all inline hex values with tokens.

## 161. Rich text entities require changes at 9 layers
- **Context:** Adding bold/italic/code/link rendering required changes to: MessageDto (parsing), AppState (model), messagesReducer (DTO→State + clone), ChatTimelineVO (VO model + mapping), TgChatScreenPage (wiring), TgMessageRouter (params), TgTextBubbleV3 (proxy), TgTextBodyV3 (rendering), TgMessageTextBodyV2 (rendering).
- **Discovery:** The quote pipeline was the perfect template — same parallel-array pattern extended to generic entities. The `buildStyledSpans()` boundary-splitting algorithm handles overlapping entities (bold+italic) correctly.
- **Lesson:** When adding a new data field through the Telegram pipeline, follow the existing pattern end-to-end: TDLib → DTO → Reducer → State → VO → Router → Bubble → Body. Use ArkUI `Text() { Span() }` for styled segments — Span supports fontWeight, fontStyle, decoration, fontFamily, textBackgroundStyle.

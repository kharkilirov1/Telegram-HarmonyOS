# LESSONS — repeated mistakes and project-specific pitfalls

Last updated: 2026-03-09

## 1. Do not mix V1 and V2 ArkUI decorators casually
- `tg_ui` is largely `@ComponentV2`.
- Shell pages are still mostly V1 `@Component`.
- `TgChatRow` is intentionally V1 `@Reusable` because its parent list page is V1.
- Mixing these layers incorrectly is a reliable way to break hvigor builds.

## 2. `LazyForEach` reuse rules are not interchangeable between V1 and V2
- Current chat list path relies on `LazyForEach` + V1 `@Reusable` row reuse.
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

## 13. Edge pagination needs re-entry latches
- Even after restore is guarded, staying near the same top/bottom edge after a page fetch can retrigger `loadOlder` / `loadNewer` repeatedly on subsequent `onScrollIndex` callbacks.
- Keep explicit top/bottom edge latches and only re-arm them after the list leaves that edge zone; this matches the intent of Telegram-style paged history loading better than firing on every callback while `start < threshold` or `end >= total - threshold`.

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

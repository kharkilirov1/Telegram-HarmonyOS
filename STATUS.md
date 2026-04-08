# STATUS — Telegram-HarmonyOS

Snapshot date: 2026-04-08

## Current snapshot
- **Branch:** `dev`
- **Repo state:** working tree has local uncommitted changes; latest clean commit is `4f3b587`
- **Latest commit:** `4f3b587` — feat: core messaging features + P0 bug fixes + UX parity
- **Primary app target:** HarmonyOS NEXT / API 22+
- **Local reference root:** `C:\Users\Kharki\Desktop\Telegram-HarmonyOS\рефенсы`

## What is working conceptually
- `EntryAbility` boots `AppCoreRuntime`
- TDLib bridge exists through NAPI
- Event pipeline is in place: gateway -> dispatcher -> normalizer -> store -> UI
- Auth/login shell exists
- Chat list page exists and uses `tg_ui` shell pieces
- Chat screen page exists and uses `TgChatTopBar`, `TgMessageRouter`, and `TgComposerInput`
- Contacts / Calls / Settings tabs exist
- Calls tab now has a **real TDLib-backed data path** via `searchCallMessages`; per user confirmation on 2026-03-22 this Phase 4 path is considered device/runtime verified

## Current tg_ui inventory
- **40 atoms**
- **2 molecules**
- **39 demos**
- **41 spec files**
- Notes: `TgSearchBar` still exists in `tg_ui` inventory/demos/specs. Legacy demo/spec artifacts for `TgContactRow` and `TgSettingsSection` were removed after the inline Contacts/Settings migration.

## Recent changes (2026-04-08, chat-row typing + composer edit mode)

### TgChatRow typing accent color
- Typing preview text now renders in activity accent color (`telegram_blue`) instead of default gray preview color
- Follows Android Telegram pattern for visible typing distinction in chat list
- Data wiring was already correct (ChatListPage swaps preview text when `isTyping`); this adds the visual differentiation

### TgComposerInput edit mode snippet bar
- Added `showEditSnippet`, `editPreview`, `onEditCancelPress` params
- Edit snippet bar shows "Edit Message" label + original text preview + cancel button
- Follows the same glass capsule pattern as the existing reply snippet
- `TgChatScreenPage` now wires `isEditingMessage` / `editingOriginalText` / `cancelEditMessage` into composer
- Demo case added to `TgComposerInputDemo.ets`
- Specs updated for both components

### Verification
- `scripts/smoke-ui-phase0.ps1` pass

## Recent changes (2026-04-05, text-engine stabilization)

### Text-engine / bubble-layout correction pass
- Re-grounded the work in HarmonyOS docs around ArkUI `textOverflow`/`maxLines`, `MeasureUtils`, and rich-text capabilities, then rechecked the live runtime path `TgMessageRouter -> TgTextBubbleV3 -> TgTextLayout`.
- Fixed the biggest structural text-engine bug: `normalizeWhitespace()` in `entry/src/main/ets/ui/text_engine/Segmenter.ets` now preserves hard line breaks instead of collapsing `\n` into spaces. Horizontal whitespace is still normalized per line.
- Fixed outgoing failed-message meta measurement drift: `TgMessageRouter.computeTextLayout()` now reserves meta width for **all** outgoing statuses except `None`, including `Failed`.
- Upgraded `computeTextBubbleLayout()` to account for quote-aware text geometry instead of only the plain-text layout result:
  - quote/plain segments are now derived from explicit quote ranges,
  - quote segments contribute their own width/height,
  - the last visual segment drives inline-meta fit checks,
  - `quoteSegmentHeights` / `quoteSegmentWidths` are now populated instead of left empty.
- Hardened `TgTextBodyV3` quote segmentation:
  - offsets/lengths are clamped to text bounds,
  - quote ranges are sorted and merged,
  - empty intermediate segments are avoided.
- Added missing V3 contract coverage:
  - spec: `entry/src/main/ets/ui/tg_ui/spec/TgTextBubbleV3.md`
  - demo: `entry/src/main/ets/ui/tg_ui/demos/TgTextBubbleV3Demo.ets`
  - demo covers hard breaks, failed status meta, sender+reply, visible quote block, and narrow URL wrap.
- Verification:
  - `scripts/smoke-ui-phase0.ps1` ✅
  - `scripts/smoke-build.ps1` ✅
- Remaining known gap:
  - the engine is now safer for the live text path, but it is still not a full Telegram entity/span pipeline; richer mixed-style/clickable text remains future work.

## Recent changes (2026-04-05, bubble time alignment pass)

### Footer-meta stabilization across non-text bubbles
- Rechecked Telegram iOS refs for attached content, polls, maps, and animated stickers: the date/status node is consistently anchored to the trailing edge of the rendered content, not laid out through a generic stretch footer.
- Fixed the main HarmonyOS drift in `entry/src/main/ets/ui/tg_ui/molecules/TgMessageRouter.ets`: shrink-wrapped bubble variants that still used a generic `width('100%')` footer row now right-anchor time/status via `alignSelf(ItemAlign.End)`.
- Covered paths:
  - `sticker`
  - `contact`
  - `location`
  - `poll`
  - non-visual `document`
- Narrow follow-up completed in the same pass:
  - `sticker` time/status now overlays the sticker surface instead of sitting on a separate row under it
  - `location` without venue text now overlays time/status on the map surface; venue/location cards still use the trailing footer row
- Why this change was needed:
  - in ArkUI shrink-wrapped columns, `width('100%')` on a footer row can be ambiguous and let the time/status cluster drift relative to the actual content width;
  - explicit trailing self-alignment follows the measured content width instead.
- Verification:
  - `scripts/smoke-ui-phase0.ps1` ✅
  - `scripts/smoke-build.ps1` ✅
- Remaining runtime check:
  - visually confirm real chat history for the covered non-text bubble families, especially outgoing rows and narrow container widths.
- Added focused demo coverage for manual verification:
  - `entry/src/main/ets/ui/tg_ui/demos/TgMessageTimeContractDemo.ets`
  - covers text / sticker / plain location / venue location / contact / poll / document / voice / audio / videoNote time-placement cases

## Phase 1: Media Gallery + Inline Video + GIF (2026-03-18) — IMPLEMENTED
- **TgMediaGalleryPage:** fullscreen viewer with Swiper, PinchGesture zoom (1x-4x), double-tap toggle, swipe-down dismiss, video playback, download overlay
- **TgInlineVideoView:** reusable inline video with parent control via @Monitor('playbackCommand'), error recovery, progress reporting
- **TgAnimationBubble:** GIF autoplay (loop, muted) via TgInlineVideoView, download overlay
- **MediaGalleryItem:** data model for gallery pipeline
- **Integration:** TgVideoBubble (short <=30s inline autoplay), TgInstantVideoBubble (circular + progress ring), TgMessageRouter (unified onMediaGalleryOpen, isShortVideo), TgChatScreenPage (gallery overlay + buildMediaGalleryItems pipeline)
- **Status:** BUILD SUCCESSFUL; runtime/device verification passed (per 2026-03-22 verification sync)

## Current active UI path
- **Chats shell/runtime** currently routes through:
  - `TgTabBar`
  - `TgChatListNavigationBar`
  - `TgChatRow`
  - `TgChatTopBar`
  - `TgMessageRouter`
- **Secondary tabs** (`ContactsPage`, `SettingsPage`, `CallsPage`) still use `TgTopBar`.
- `TgSearchBar` is part of the `tg_ui` library, but the live Chats shell uses stock ArkUI `Search` inside `TgChatListNavigationBar`.

## Recent changes (2026-03-22, session 24)

### Documentation reality sync
- Re-audited the repo against the actual tree and latest HEAD `860e473`.
- Corrected the current inventory and active shell path in the core docs: the live Chats path is `TgTabBar` → `TgChatListNavigationBar` → `TgChatRow` → `TgChatTopBar` → `TgMessageRouter`, while `TgTopBar` remains active on secondary tabs.
- Corrected the earlier false claim that `TgSearchBar` was removed: it still exists as an atom/demo/spec, but current Chats runtime uses stock ArkUI `Search` embedded in `TgChatListNavigationBar`.
- Synced build-doc wording with the real smoke scripts: `scripts/smoke-ui-phase0.ps1` checks `TgChatListNavigationBar` + `Search`, and `scripts/smoke-build.ps1` can resolve `hvigorw` from PATH **or** the default DevEco install path.

## Recent changes (2026-03-22, session 25)

### Verification state sync
- Per user confirmation on 2026-03-22, the previously unrecorded emulator/device/runtime verification pass should be treated as **completed** for the current branch state.
- Historical “needs device verification” checklists below are preserved as regression reference, but they are **not** active blockers anymore.
- This applies to shell polish, chat-list/chat-screen runtime, media/gallery flows, calls path, profile path, and related smoke/build checks referenced in earlier session notes.

### Legacy artifact cleanup
- Removed orphaned legacy `tg_ui` artifacts that were no longer backed by runtime atoms: `TgContactRowDemo.ets`, `TgSettingsSectionDemo.ets`, `TgContactRow.md`, `TgSettingsSection.md`.
- Current `tg_ui` counts after cleanup: **32 atoms / 2 molecules / 34 demos / 37 specs**.
- Contacts and Settings now have one clear story in docs and tree: inline runtime layout + tokenized atoms that still matter (`TgTopBar`, `TgSettingsRow`, `TgAvatar`).

## Recent changes (2026-03-22, session 26)

### Shell smoke alignment + small code hygiene
- Removed two hardcoded action-menu colors from `TgChatScreenPage` and switched them to tokenized colors (`TgUiTokens.COLOR_ICON_PRIMARY`, `TgUiTokens.COLOR_TEXT_TITLE`).
- Updated `scripts/smoke-ui-phase0.ps1` to reflect the current V2 runtime reality: it now expects `TgChatRow` to be `@ComponentV2` instead of the stale `@Reusable` check.
- Re-ran `scripts/smoke-ui-phase0.ps1` successfully after the cleanup; the shell smoke baseline is green again.

## Recent changes (2026-03-22, session 27)

### Post-V2 stabilization pass: row diff parity + stale migration contract cleanup
- Fixed a real post-migration refresh bug in `ChatListDataSource`: same-order row updates now compare `previewPrefix`, `previewPrefixStyle`, `isDraft`, and `isLastPinned`, so draft/author-prefix transitions and pinned-boundary spacer changes no longer risk being skipped by incremental `onDataChange(...)` updates.
- Synced stale migration contracts that were still describing the old V1 world: `DECISIONS.md`, `TASKS/LESSONS.md`, and `TgChatRow.md` now reflect the actual `@ComponentV2` chat-row path instead of the retired `@Reusable` assumption.
- Synced `TgComposerInput.md` with the real runtime implementation: the composer is documented again as a three-piece glass composition (attach circle + text capsule + action circle), not as a single unified capsule.
- Current migration verdict: V1 -> V2 migration is treated as complete for the active UI code; remaining work is post-migration parity/polish, not another broad migration phase.

## Recent changes (2026-03-22, session 28)

### Live parity touch-up: tab bar typography + composer inline input
- Restored the accepted tab-bar label hierarchy in the live atom path: `TAB_BAR_TEXT_SIZE` is back to `12vp`, and the selected tab label is `Bold` again instead of the drifted smaller/medium-weight rendering.
- Restored the composer input field to ArkUI inline mode: `TgComposerInput` now uses `TextContentStyle.INLINE`, which better matches the custom glass-shell contract and avoids stock text-box styling fighting the Telegram-like composer capsule.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the parity touch-up.
- This was a parity-oriented stabilization pass, not a new migration phase; active V2 runtime remains unchanged architecturally, but two visible drifts from the accepted shell contract are now corrected.

## Recent changes (2026-03-22, session 29)

### Narrow parity pass: chat-list navigation title weight
- Re-checked `TgChatListNavigationBar` against the local iOS reference (`ChatListNavigationBar.swift` + `ChatListHeaderComponent.swift`) before test.
- Narrow fix only: the centered Chats title no longer uses a heavier generic bold weight; it now uses tokenized ArkUI `Medium` as the closer approximation to the iOS `17pt semibold` navigation title.
- No search-shell rewrite was needed; the integrated `Search` lane, safe-area ownership, and left/right action layout remain aligned with the accepted header contract.

## Recent changes (2026-03-24, session 31)

### P0 stabilization: selector memoization + pendingFileIds leak + debounce fixes
- **Selector memoization fix**: `cloneMessagesState()` was creating new inner `Map<string, Message>` for every chat on every message dispatch, breaking reference equality in `selectChatMessages`/`selectChatMessagesForChatView`. Now shares inner maps by reference — only the modified chat gets a new Map (reducer already does this). Eliminates O(n log n) re-sort on every unrelated message event.
- **pendingFileIds memory leak fix**: `DownloadMessageMediaUseCase.pendingFileIds` was never cleaned up when TDLib completed downloads via `updateFile` (the normal path for larger files). Added `scanFileSlot()` that removes fileId from Set when path is already resolved. Also reduced code duplication in `scanContent()`.
- **Debounce fix**: ContactsPage and CallsPage had `setTimeout(..., 0)` for rebuild debounce — effectively a no-op. Changed to 300ms to match ChatListPage.
- **AppCoreRuntime isRunning audit**: Confirmed NOT a bug — `isRunning` is set before `gateway.initialize()` starts the receive loop. No updates can arrive in the gap.
- **stateClone consolidation**: extracted `shallowCloneAppState()` base, reduced 6 `cloneStateFor*` functions from 100 LoC to 60 LoC. Same API, no reducer changes needed. Adding new state slices now requires updating only `shallowCloneAppState`.
- **UX parity fixes**: (1) Chat row press feedback via `.stateStyles({ pressed: BG_SECONDARY })` — iOS has highlight on tap. (2) Pull-to-refresh via `Refresh` component wrapping chat list — iOS has native pull-to-refresh. (3) `$$` two-way binding for `isRefreshing` state.
- **Delete chat**: `DeleteChatHistoryCommand` + serializer + `DeleteChatHistoryUseCase`. Wired to swipe Delete action on chat list.
- **Toggle read/unread**: `ToggleChatIsMarkedAsUnreadCommand` + serializer + `ToggleChatUnreadUseCase`. Wired to swipe-right Read/Unread action (iOS left swipe pattern).
- **Chat list swipe**: now fully wired — left swipe: Pin(stub)/Mute(✅)/Delete(✅), right swipe: Read/Unread(✅).
- **Deprecated API migration**: `promptAction.showToast` and `promptAction.showActionMenu` → `this.getUIContext().getPromptAction().*` (API 11+ UIContext pattern). Eliminates 2 build warnings.
- **3 compile errors fixed**: `Button[]` → tuple cast for showActionMenu, `getAllData()` → `totalCount()+getData(i)`, explicit type on search result callback.
- **Chat list swipe actions**: `ListItem.swipeAction()` with end actions: Pin (green), Mute/Unmute (orange), Delete (red). Colors tokenized (`SWIPE_ACTION_PIN/MUTE/DELETE`). Mute toggle wired to `SetChatMuteUseCase`. iOS ref: `ChatListItemNode.revealOptions()`.
- **Mute/unmute**: `SetChatMuteCommand` + serializer (`setChatNotificationSettings`) + `SetChatMuteUseCase` with constants (MUTE_FOREVER, MUTE_1_HOUR, etc.). Normalizer + reducer already existed.
- **Pin/unpin messages**: `PinChatMessageCommand` + `UnpinChatMessageCommand` + serializer + `PinChatMessageUseCase`. Pin action added to long-press action menu (iOS order: before Delete).
- **Search messages**: `SearchChatMessagesCommand` + serializer + `SearchChatMessagesUseCase` + `TgChatTopBar` search mode (inline search field replaces title capsule, iOS pattern). 0.2s debounce, auto-scroll to first result. Search mode API ready, UI trigger (magnifying glass button or title gesture) is future work.
- **Verification**: `scripts/smoke-ui-phase0.ps1` ✅

### Core messaging features: edit, delete, forward (domain + UI)
- **Edit message**: `EditMessageTextCommand` + `CommandSerializer` case + `EditMessageUseCase` + UI edit mode in `TgChatScreenPage` (long-press → Edit → composer prefilled → send triggers editMessageText).
- **Delete messages**: `DeleteMessagesCommand` + `CommandSerializer` case + `DeleteMessagesUseCase` + UI delete action in long-press menu (revoke=true by default).
- **Forward messages**: `ForwardMessagesCommand` + `CommandSerializer` case + `ForwardMessagesUseCase` + UI forward action stub (full chat-picker UI is future work).
- **Action menu expanded**: long-press menu now shows Reply, Copy (if text), Edit (if own text), Forward, Delete. Dynamic button list with indexed dispatch.
- **String resources**: added `action_edit`, `action_delete`, `action_forward` to `string.json`.
- **Verification**: `scripts/smoke-ui-phase0.ps1` ✅

## Recent changes (2026-03-22, session 30)

### Upper chrome architecture fixed as V2 layered composition
- After decomposing the Telegram iOS upper area, the project now explicitly treats top chrome as a **layered V2 architecture** rather than a single custom bar widget.
- Added the canonical design note `docs/ai/UPPER_CHROME_V2_ARCHITECTURE.md` with:
  - iOS upper-area decomposition,
  - HarmonyOS candidate mapping,
  - the target ownership split `screen-owned derived state -> V2 composition component -> shared top background primitive`.
- Synced this decision into `DECISIONS.md` and `ARCHITECTURE.md` so future work on `TgChatListNavigationBar` / `TgChatTopBar` does not fall back to widget-first thinking.

## Recent changes (2026-03-22, session 31)

### Shared upper-background primitive landed (`TgTopChromeBackground`)
- Added a new V2 atom `entry/src/main/ets/ui/tg_ui/atoms/TgTopChromeBackground.ets` plus spec/demo coverage.
- The new primitive owns:
  - top safe-area fill,
  - shared blur/tint surface,
  - stronger top-edge emphasis,
  - optional bottom separator.
- `TgChatListNavigationBar` now renders its content composition **above** this shared background atom instead of owning the blur/specular surface internally.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the extraction.

## Recent changes (2026-03-22, session 32)

### `TgChatTopBar` moved onto the shared upper-background model
- `TgChatTopBar` now uses `TgTopChromeBackground` as its shared upper chrome surface instead of behaving like a fully self-contained blur/background widget.
- The chat top bar still keeps its local glass capsules for back/title/avatar controls, but the safe-area fill and upper background ownership are now aligned with the same layered V2 model as `TgChatListNavigationBar`.
- Synced `TgChatTopBar.md` to reflect the new ownership split.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the refactor.

## Recent changes (2026-03-22, session 33)

### Narrow optical pass: lighter `TgChatTopBar` capsule cluster
- Per the current iOS comparison notes and the latest chat-screen screenshot feedback, the next safe step after fixing ownership was to reduce the visual mass of the three-capsule cluster rather than to add new top-bar features.
- `TgUiTokens` now uses a tighter chat-top-bar geometry:
  - `CHAT_TOP_BAR_CAPSULE_GAP`: `8vp -> 6vp`
  - `CHAT_TOP_BAR_TITLE_PADDING_H`: `14vp -> 12vp`
  - `CHAT_TOP_BAR_TITLE_MIN_WIDTH`: `150vp -> 136vp`
  - `CHAT_TOP_BAR_BORDER_WIDTH`: `0.75vp -> 0.5vp`
- Result: the centered title capsule no longer reads as an overly wide heavy block relative to the back/avatar capsules, while the shared upper background model remains unchanged.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the token pass.
- Remaining top-bar gaps are now feature/state-level rather than ownership-level:
  - back unread-count badge,
  - search button in chat top bar,
  - richer typing/activity subtitle states,
  - optional accessory/secondary upper lane when product scope reaches it.

## Recent changes (2026-03-22, session 34)

### Strategic refocus: preserve Telegram semantics, de-prioritize manual shell chrome polishing
- After reviewing repeated API 23 beta visuals/video evidence, the project accepted a strategic shift: manual custom work should concentrate on Telegram-defining semantics and hierarchy, while shell/chrome surfaces should increasingly be treated as Harmony-native or hybrid candidates.
- This does **not** mean immediate API 23 lock-in. The repo still targets API 22 (`targetAPIVersion` / `targetSdkVersion` 22 in the current project config), so the accepted direction is:
  - keep API 22-compatible fallbacks,
  - use API 23 beta as a visual/architectural direction,
  - redirect implementation energy away from endlessly polishing shell glass/island chrome by hand.
- Practical implication for the queue:
  - keep investing in `TgChatRow`, message atoms, composer semantics, and Telegram-specific state contracts,
  - treat `TgTabBar`, upper chrome hosts, and similar shell surfaces as native/hybrid candidates first before expanding more custom chrome.

## Recent changes (2026-03-22, session 35)

### Practical queue reset after the shell-chrome strategy shift
- The repo now has an explicit next-work order that matches the new strategy instead of loosely continuing the old shell-parity loop.
- New near-term implementation priority:
  1. `TgChatTopBar` **state contract**, not more shell cosmetics,
  2. `TgChatRow` **content/state completeness audit**,
  3. **composer semantics** over composer cosmetics,
  4. **message-surface parity** (`TgMessageRouter` / message atoms),
  5. only then a dedicated **native/hybrid shell audit** for `TgTabBar` / upper chrome / search hosts.
- This effectively de-prioritizes more manual tab-bar glass polish and generic upper-chrome material tweaking while API 22 remains the active target and API 23 serves as direction rather than dependency.

### Reference-side parity pass: `TgChatRow` lane tightening + `TgChatTopBar` weight/avatar correction
- Tightened the live chat-row geometry toward the iOS lane: `CHAT_ROW_AVATAR_TEXT_GAP` was reduced from `12vp` to `8vp`, and `CHAT_ROW_SEPARATOR_INSET` from `82vp` to `80vp`, which better matches the iOS avatar-to-text spacing and separator start after the 60pt avatar block.
- Softened the chat top-bar title from `Bold` to `Medium` to better approximate the iOS `semibold` title weight, and increased the avatar inner size from `37vp` to `38vp` to match the 44pt container inset-by-3pt reference more closely.
- This pass stayed intentionally narrow: it corrected high-confidence visual deltas from the local comparison docs without reopening larger top-bar feature gaps such as back-count badge, search button, or typing subtitle behavior.

## Recent changes (2026-03-22, session 36)

### `TgChatTopBar` state contract pass: subtitle modes + richer activity semantics
- Shifted the next top-bar pass away from shell polish and into Telegram-specific chat-title semantics, following the new queue accepted in session 35.
- `TgChatTopBar` now accepts an explicit `subtitleMode` contract (`secondary` / `online` / `activity`) instead of inferring subtitle color only from `isOnline`.
- `TgChatScreenPage` now derives that mode from real chat state:
  - private chats keep the existing online/offline subtitle meaning,
  - groups/channels keep member-count / type-label semantics as secondary subtitle,
  - fresh typing/action updates override the subtitle in a dedicated `activity` mode.
- Activity subtitles are now richer than the previous plain `typing...` override: the chat top bar understands the same action family already normalized in the store (`typing`, video/voice/photo/file send/record states, sticker/location/contact choice, game, video-message actions), and group chats prefix the acting user's first-name/username when available.
- This was a Telegram-semantics pass, not a shell-chrome pass. Remaining top-bar gaps are still feature-level (`search`, back unread badge, broader title/accessory states), but the subtitle contract is now closer to the real Telegram chat-title model.

## Recent changes (2026-03-22, session 37)

### `TgChatRow` completeness audit: verified title badge support
- Continued the post-shell-refocus queue with a narrow Telegram-specific chat-list improvement instead of another shell pass.
- `ChatItemVO` now carries `isVerified` from private-peer user state, and the live `ChatListPage` passes that flag into `TgChatRow`.
- `TgChatRow` now renders a compact verified title badge between the title text and mute icon, using tokenized geometry/colors instead of hardcoded inline values.
- `ChatListDataSource` row equality now compares `isVerified`, so same-order updates still refresh the row when verification state changes.
- Synced `TgChatRowDemo` and `TgChatRow.md` so the verified-title state is covered in both demo and passport.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the pass.

## Recent changes (2026-03-22, session 38)

### Composer semantics pass: reply snippet ownership returned to `TgComposerInput`
- Continued the new queue on composer semantics rather than shell polish.
- The live chat screen no longer renders a separate ad hoc reply bar above the composer. Reply snippet ownership is back inside `TgComposerInput`, which already had the intended UI contract in its spec.
- `TgComposerInput` now exposes a real trailing cancel control inside the reply strip and uses the existing `onReplyCancelPress()` callback in live integration.

## Recent changes (2026-03-22, session 39)

### Message-surface parity pass: reply previews now understand media kinds and thumbnails
- Continued the post-shell-refocus queue on message-surface semantics instead of reopening shell/chrome polish.
- `ChatTimelineVO` now derives richer reply previews from the replied message content:
  - text replies keep real text,
  - media replies fall back to Telegram-like labels (`Photo`, `Video`, `GIF`, `Voice message`, `Video message`, `Sticker`, file name / `File`) instead of the old generic `[Unsupported message]` or raw internal `contentType` strings.
- Media replies can now carry a real thumbnail path into the shared reply snippet contract:
  - photo replies prefer `photoPath -> photoThumbPath`,
  - video replies prefer `videoThumbPath -> videoPath`,
  - animation replies prefer `videoThumbPath -> animationPath`,
  - video-note replies prefer `videoThumbPath -> videoNotePath`.
- `TgMessageRouter` now forwards `replyHasThumbnail` / `replyThumbnailSrc` into `TgReplySnippet`, and `ChatTimelineDataSource` equality includes those fields so same-order timeline updates still repaint when a reply thumbnail arrives later.
- `TgChatScreenPage` action-menu reply flow no longer feeds raw internal `contentType` strings into the composer preview; it now uses user-facing media labels / names for message replies started from the message action menu.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the pass.
- `TgChatScreenPage` now passes the screen-owned reply state (`showReplySnippet`, `replyAuthor`, `replyPreview`) directly into the composer atom and lets the atom render the full reply strip.
- Synced `TgComposerInputDemo` and `TgComposerInput.md` so the contract again matches runtime: three-piece composer row plus atom-owned reply strip with cancel action.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the integration cleanup.

## Recent changes (2026-03-23, session 40)

### Parallel text-surface rebuild started with `TgTextBubbleV2`
- Added a new presentation-only atom `TgTextBubbleV2` plus demo/spec coverage as the first controlled reset step for message surfaces.
- Scope was intentionally narrow: sender line, reply snippet, text body, inline meta, grouped corners.
- Avatar lane, router ownership, and non-text families were left untouched.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after landing the atom/demo/spec.

## Recent changes (2026-03-23, session 41)

### Live text branch moved onto `TgTextBubbleV2`
- `TgMessageRouter` now uses `TgTextBubbleV2` for the live `text` branch.
- Avatar lane remains router-owned, and media/document/voice/sticker families were intentionally left on the old path.
- This made the partial message-surface reset real in runtime without reopening a broad router rewrite.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the narrow swap.

## Recent changes (2026-03-23, session 42)

### Visual media shell extraction landed with `TgMediaBubbleShellV2`
- Added a new presentation-only atom `TgMediaBubbleShellV2` plus demo/spec coverage for the visual-media family (`photo`, `photoAlbum`, `video`, `animation`).
- The new shell owns:
  - sender line,
  - reply snippet,
  - shared visual-media bubble surface,
  - caption/no-caption meta rules,
  - grouped outer corners.
- `TgMessageRouter` now routes the live visual-media family through `TgMediaBubbleShellV2`, while keeping:
  - avatar lane in the router,
  - `videoNote` on its dedicated round path,
  - document/audio/voice on their existing branches.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the shell extraction and live swap.

## Recent changes (2026-03-23, session 43)

### Quote semantics cleanup: explicit reply-quote contract instead of preview-length heuristic
- The reply path no longer infers `replyIsQuote` from `replyPreview.length > 80`.
- Added explicit quote fields to the core message model/DTO pipeline:
  - `replyIsQuote`
  - `replyQuoteText`
  - `replyQuoteOffset`
- `MessageDto` now does best-effort parsing from TDLib `reply_to`:
  - `message_id`
  - `quote`
  - `quote_text`
  - `quote_offset`
- `ChatTimelineVO` now prefers `message.replyQuoteText` for the reply preview when present and passes `message.replyIsQuote` through to the UI instead of guessing from string length.
- `TgChatScreenPage` now keeps explicit composer reply-quote state (`replyToIsQuote`) so the composer path is ready for future real quote producers instead of hardcoding `replyIsQuote: false`.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the quote-contract cleanup.

## Recent changes (2026-03-23, session 40)

### Parallel text-surface rebuild started with `TgTextBubbleV2`
- Began the controlled message-surface reset without touching chat-list/shell/runtime paths.
- Added a new parallel atom:
  - `entry/src/main/ets/ui/tg_ui/atoms/TgTextBubbleV2.ets`
  - `entry/src/main/ets/ui/tg_ui/spec/TgTextBubbleV2.md`
  - `entry/src/main/ets/ui/tg_ui/demos/TgTextBubbleV2Demo.ets`
- `TgTextBubbleV2` is intentionally scoped as a **text-family bubble shell** only:
  - sender line
  - reply snippet slot
  - text body
  - inline meta overlay
  - grouped-corner geometry
- The new atom stays presentation-only and composes existing primitives (`TgMessageBubbleBase`, `TgReplySnippet`, `TgMessageMeta`) instead of reopening router or avatar-lane ownership immediately.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after landing the atom/demo/spec.
- This is the first step of the partial reset strategy: **text path first, media path second, router cleanup third**.

## Recent changes (2026-03-23, session 41)

### Narrow live swap: `TgMessageRouter` text branch now uses `TgTextBubbleV2`
- Continued the controlled message-surface reset with the smallest real integration step instead of a router-wide rewrite.
- The live `text` branch in `TgMessageRouter` now renders through `TgTextBubbleV2` while:
  - keeping avatar-lane ownership in the router,
  - leaving media/document/voice/sticker branches untouched,
  - preserving the old router path as the model for non-text families for now.
- This means the rebuild has moved from demo-only to **real runtime text-path integration** without reopening the full message surface at once.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the narrow swap.

## Selective stock ArkUI replacement (2026-03-09)
- Replaced thin wrapper atoms with stock/layout code where it simplified the live pages:
  - `TgSettingsSection` → inline tokenized `Column` groups in `SettingsPage`
  - `TgContactRow` → inline `TgAvatar` + `Row/Column` layout in `ContactsPage`
- Chats shell now uses stock ArkUI `Search` **inside** `TgChatListNavigationBar`, but the standalone `TgSearchBar` atom/demo/spec were kept in the library.
- Kept atoms with real custom logic on live pages: `TgTabBar`, `TgTopBar`, `TgChatListNavigationBar`, `TgCallRow`, `TgSettingsRow`.
- Smoke scripts were updated to validate the real shell path (`ChatListPage` → `TgChatListNavigationBar` → `Search`).

## P0-P5 improvement plan (2026-03-09) — COMPLETE
- **P0 Avatar download:** full pipeline implemented — fileId stored in User/Chat, `DownloadFileCommand` + serialization, `FileNormalizer` handles `updateFile`, `filesReducer` updates photo paths, `downloadAvatars` usecase watches store and triggers downloads, wired in AppCoreRuntime. Fixed: direct response parsing was broken (`JSON.stringify(TdObject)` can't access private `rawJson`), switched to native TdObject accessors. Verification status: passed.
- **P1 Sender names in groups:** `buildChatItemVO()` prepends "You: " / "firstName: " for group chat previews
- **P2 Checkmark order:** TgChatMeta renders status icon BEFORE time (iOS pattern: ✓✓ 17:47)
- **P3 Date format:** same-year dates now show `dd.MM` instead of `dd.MM.yy`
- **P4 chat-list header actions:** Edit + Compose actions are now part of the integrated `TgChatListNavigationBar` path in `ChatListPage`
- **P5 Pinned separator:** `isLastPinned` detection + visual gap after last pinned chat

## Profile screen (2026-03-09)
- **TgProfilePage** created: large avatar, name, online status, phone, username, bio (users), description + member count (groups/channels), notifications toggle
- Full info pipeline: `getUserFullInfo` / `getSupergroupFullInfo` commands → serializer → direct response → `UserFullInfoEvent` / `ChatFullInfoEvent` → reducers update `User.bio`, `Chat.description`, `Chat.memberCount`
- Model extended: `User.bio`, `Chat.memberCount`, `Chat.description`, `Chat.supergroupId`
- Navigation: `onTitlePress` + `onAvatarPress` in TgChatScreenPage push to TgProfilePage via chatNavStack
- Registered in MainTabsPage `chatPageMap`
- Verification status: passed

## Recent changes (2026-03-18, session 22)

### Tab bar contract cleanup: live Chats badge + state-driven selected pill
- **Chats badge path is live again:** `TgTabBar` now actually enables the unread badge on the Chats tab instead of carrying a dead `chatBadgeCount` prop and `buildBadge()` path.
- **Atom ownership cleaned up:** `TgTabBar` no longer writes `StorageKeys.MAIN_TAB_INDEX` into `AppStorage`; tab selection ownership remains in `MainTabsPage` / shell state only.
- **Selected pill is state-driven now:** removed the temporary `pillGlassActive` timer hack and made the selected capsule blur/border depend directly on `selectedIndex` + realtime blur mode, which avoids transient visual desync during fast tab switches.
- **Spec sync:** `entry/src/main/ets/ui/tg_ui/spec/TgTabBar.md` now explicitly states that page-level shell owns AppStorage/controller state and that the atom only emits selection callbacks.
- **Verification status:** passed; historical regression checklist: run `scripts/smoke-build.ps1` and device-check Chats unread badge, repeated tab switching, and selected-pill consistency.

## Recent changes (2026-03-18, session 23)

### Tab bar material polish: stronger capsule body + tab-specific glass colors
- **Tab bar glass is now tuned independently from other chrome:** introduced dedicated `tab_bar_glass_bg` and `tab_bar_edge_highlight` resources instead of reusing the generic glass colors that also affect filter/composer/top-bar surfaces.
- **Material body strengthened:** the tab bar capsule background alpha and selected pill alpha are slightly higher now, so the island reads as a real object over busy content instead of only as border + shadow.
- **Micro hierarchy polish:** the tab content now uses a small selected/unselected opacity+scale difference and lighter unselected label weight, which gives the selected tab a clearer premium focus without changing the shell contract.
- **Token sync:** `TgUiTokens` now includes tab-bar-specific inner padding, pill border width, shadow tuning, and selected/unselected content scale-opacity values.
- **Verification status:** passed; historical regression checklist: device-check light/dark backgrounds, selected/unselected readability, and whether the stronger material still feels glass-like rather than opaque.

## Recent changes (2026-03-14, session 8)

### Bubble improvements: GIF, reply quotes, meta overlay, avatars, wider bubbles
- **Wider bubbles:** `BUBBLE_MAX_WIDTH_RATIO` 0.75 → 0.85 (iOS `freeMaximumFillFactor = 0.85`)
- **Avatars on incoming group messages:** iOS pattern — 34vp avatar + 4vp gap, ALWAYS reserved for incoming group messages (invisible spacer when avatar not shown). Avatar shows on last message in each sender group. Tokens: `MSG_AVATAR_SIZE`, `MSG_AVATAR_GAP`, `MSG_AVATAR_FONT_SIZE`.
- **Media sizing fix:** media atoms now receive `maxBubbleWidth()` (containerWidth minus avatarInset, times ratio) with `maxWidthRatio: 1.0` — prevents overflow beyond bubble.
- **GIF auto-play:** `TgVideoBubble` gained `hidePlayButton` param. `TgMessageRouter` sets it for `animation` contentType — GIFs play without play button overlay.
- **Reply snippet background:** `TgReplySnippet` gained `bgColor()` + `borderRadius` — quotes have subtle tinted background inside bubbles. Tokens: `REPLY_SNIPPET_BG_INCOMING`, `REPLY_SNIPPET_BG_OUTGOING`, `REPLY_SNIPPET_BG_RADIUS`.
- **Meta overlay on visual media (iOS pattern):** photo/video/animation without caption — time + checkmarks overlay on bottom-right with `rgba(0,0,0,0.4)` pill + borderRadius(10). With caption — meta below caption.
- **TgMessageMeta overlayMode:** white text/icons on dark overlay for media bubbles. Failed status stays red.
- **Photo/video viewer pages:** `TgPhotoViewerPage` (pinch-to-zoom Matrix4 + PanGesture drag-to-dismiss), `TgVideoPlayerPage` (ArkUI Video + custom controls). Both via `bindContentCover`.
- **Bubble colors aligned to iOS:** outgoing `#EFFFDE` → `#E1FFC7` (light), incoming dark `#1E2C3A` → `#182533`.
- **ChatTimelineVO avatar data:** populates `showAvatar`, `avatarImageSrc`, `avatarInitials`, `avatarColorIndex` from User/Chat photo paths.
- Verification status: passed.

## Recent changes (2026-03-14, session 9)

### Bubble stabilization pass: avatar lane, clipping, inline meta, regular width
- **Avatar lane reservation fixed:** `TgMessageRouter` now reserves the incoming group avatar lane from message-group context (`senderName`) instead of depending on hydrated avatar image data. This removes bubble width jumps when sender photo data arrives late.
- **Avatar fallback initials:** `ChatTimelineVO` now marks `showAvatar` for the last incoming message in a sender group even when photo data is missing, and `TgMessageRouter` falls back to sender-name initials for the visible avatar chip.
- **Rounded media clipping fixed:** `TgPhotoBubble`, `TgVideoBubble`, router avatar images, and reply thumbnails now use `.clip(true)` with rounded corners, matching HarmonyOS clipping guidance and preventing image bleed outside the radius.
- **Inline meta width tightened:** inline/overlay `TgMessageMeta` usage in `TgMessageRouter` now overrides `minWidth` and hidden reserve slots (`minWidth: 0`, `reserveTimeSlot: false`, `reserveStatusSlot: false`) so text/caption reserve width matches the rendered time/check cluster more closely.
- **Media overlay tokens:** bottom-right media meta pill spacing/radius/background moved into `TgUiTokens` (`MSG_MEDIA_META_OVERLAY_*`) instead of hardcoded numbers.
- **Regular-width bubble behavior:** `TgUiTokens` now exposes compact-vs-regular bubble width helpers (`0.85` compact / `0.65` regular, boundary `500`). Text/media/document/voice/reply atoms use the shared width helper, and photo/video bubbles now allow regular-width max dimensions (`440x440`) when the outer chat lane is wide enough.
- **Reply quote polish:** `TgReplySnippet` now clips thumbnails, aligns quote blocks from the top, and adds a lightweight quote mark accent for quote mode.
- **Build verification:** `./scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- Verification status: passed for real chat runtime.

## Recent changes (2026-03-14, session 10)

### Media caption geometry fix
- **Fixed clipped left edge on media captions:** `TgMessageRouter` now gives both visual-media stacks (with and without caption) an explicit width equal to the actual media bubble width instead of relying on a shrink-wrapped `Stack` child with `Text.width('100%')`.
- **Root cause:** in the media+caption path, `Stack({ alignContent: Alignment.BottomEnd })` had no explicit width, while the caption `Text` used `width('100%')`. ArkUI aligned the oversized child against the stack end edge, pushing the left side of the caption outside the bubble clip area.
- **Build verification:** `./scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- Verification status: passed on real media captions/channel posts.

## Recent changes (2026-03-15, session 11)

### Tall photo fit + bubble typography tightening
- **Tall photos no longer crop from the bottom:** `TgPhotoBubble` now fits image content inside the allowed media box with `ImageFit.Contain` and computes the final bubble width from the fitted media width instead of always using a max-width photo frame.
- **Caption/router width stays aligned with fitted photos:** `TgMessageRouter.photoVisualBubbleWidth()` mirrors the photo fit logic so caption/meta stacks use the same effective bubble width as the rendered image.
- **Message typography tightened for HarmonyOS runtime:** `TgUiTokens` message body and media-caption text were reduced from `17/22` to `16/21` (`fontSize/lineHeight`) to compensate for the optically larger HarmonyOS text metrics in chat bubbles.
- **Build verification:** `./scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- Verification status: passed for tall portrait photos, media captions, and overall text density in real chats.

## Recent changes (2026-03-15, session 12)

### Grouped photo albums + voice playback bubble path
- **Grouped media albums are now merged in timeline:** `media_album_id` is propagated through `MessageDto` → `AppState.Message` → `messagesReducer`, and `ChatTimelineVO` now collapses consecutive photo messages from the same album/sender into one `photoAlbum` entry instead of rendering separate single-photo bubbles.
- **New grouped-media atom:** `TgGroupedPhotoBubble` renders 2-up / 3-up / 4-up mosaics plus `5+` overflow overlay, with tokenized geometry and clipped rounded cells. `TgMessageRouter` now routes `photoAlbum` through this atom and forwards tapped cell paths to the page-level photo viewer.
- **Voice playback contract is now real:** `ChatTimelineVO` keeps `voicePath` as the raw local sandbox path for playback and propagates `voiceFileId`; `TgMessageRouter` passes play/download state into `TgVoiceBubble`; `TgChatScreenPage` owns a `VoicePlaybackController` that toggles download-vs-play behavior and tracks active playback progress.
- **HarmonyOS grounding:** `VoicePlaybackController` uses `@ohos.multimedia.media` `AVPlayer` with `fdSrc` (`@ohos.file.fs.openSync/statSync`) for local voice playback. This keeps `Image`/viewer paths on `file://` while voice playback stays on raw local paths, which matches HarmonyOS component vs media-player API expectations.
- **Voice bubble parity pass:** `TgVoiceBubble` now uses iOS-style duration-based width (`minVoiceWidth = 120`, duration-scaled up to lane max width), real 5-bit waveform decoding from TDLib/base64 payloads, and explicit download/play/pause icon states.
- **Controller race tightened:** `TgChatScreenPage` setup/teardown no longer lets an async release from an old `VoicePlaybackController` reset state after a new controller is already attached.
- **Build verification:** `./scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- **Verification status:** passed; historical regression checklist: grouped photo mosaics (`2/3/4/5+`), `+N` overlay tap, local voice playback/pause/resume, listened-state visuals, and on-demand voice download → play transition.

## Recent changes (2026-03-15, session 13)

### Media viewer opening path hardened for emulator/runtime
- **Removed `bindContentCover` dependency for chat media viewers:** `TgChatScreenPage` now renders `TgPhotoViewerPage` / `TgVideoPlayerPage` as direct full-screen overlays in the root `Stack` instead of relying on `bindContentCover(...)`.
- **Why this pass was needed:** the user reported that media viewers were not opening on the emulator even though tap callbacks and viewer pages were already wired.
- **Video tap target widened:** `TgVideoBubble` now opens the viewer from the whole media preview surface, not only from the small center play button. This also restores tap-to-open for animation/GIF previews where the play button is intentionally hidden.
- **Build verification:** `./scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- **Verification status:** passed; historical regression checklist: photo viewer open/dismiss, video viewer open/play/pause, GIF tap-to-open, and overlay z-order over the chat screen.

## Recent changes (2026-03-15, session 14)

### Empty-bubble fallback fix + document bubble polish
- **Unsupported secondary message types no longer render empty shells:** `TgMessageRouter.isTextLike()` now treats `unknown`, `location`, `contact`, and `poll` as text-fallback content, so messages that already carry DTO fallback text (`[Location]`, `[Contact]`, `[Poll]`, `[messageType]`) render inside the normal text bubble path instead of producing a blank bubble body.
- **Document bubble leading tile now mirrors Telegram file affordance more closely:** `TgDocumentRow` gained a file-extension badge path (`PDF`, etc.) inside the leading rounded tile when the row is not in download-progress mode, and document titles can now wrap to two lines instead of collapsing into an over-tight single-line row.
- **Layout cleanup:** the no-bubble-wrap `TgDocumentRow` content path now reuses the same leading tile builder directly instead of introducing an unnecessary nested `Row`, keeping the file-row geometry consistent between wrapped and unwrapped modes.
- **HarmonyOS grounding:** the row keeps `Text.maxLines(...)` + `TextOverflow.Ellipsis` on the weighted text column, which matches ArkUI guidance for truncating text inside adaptive horizontal layouts.
- **Build verification:** `./scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- **Verification status:** passed; historical regression checklist: real file rows (`pdf/doc/audio`) for extension badge/title wrapping balance, plus fallback rendering for location/contact/poll/unknown messages to confirm the previous “empty bubble” cases now show placeholder text instead of blank bodies.

## Recent changes (2026-03-15, session 15)

### Voice bubble meta width stabilization
- **Voice bubble time/meta is now width-locked to the voice bubble body:** `TgUiTokens` exposes a shared `resolveVoiceBubbleWidth(...)` helper, so both `TgVoiceBubble` and `TgMessageRouter` use the same duration-based bubble width contract.
- **Router fix:** `TgMessageRouter` now treats `voice` as a dedicated sub-path inside the non-visual media branch and renders the time/status row with an explicit inner width derived from the shared voice-width helper instead of a generic `width('100%')` row inside a shrink-wrapped bubble container.
- **Why this pass was needed:** user reported that the time for voice messages had shifted outside / away from the bubble, which is consistent with ArkUI shrink-wrap width ambiguity in the previous separate-meta-row layout.
- **Build verification:** `./scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- **Verification status:** passed; historical regression checklist: incoming/outgoing voice bubbles, short vs long durations, and group-chat voice rows with sender name / reply snippet to confirm the time cluster now stays visually inside the bubble bounds.

## Recent changes (2026-03-15, session 16)

### Channel text-bubble width parity pass
- **Channel posts no longer reserve the group avatar lane by default:** `ChatTimelineVO` now computes an explicit `reserveAvatarLane` flag, enabled for groups/supergroups but disabled for channels, and `TgMessageRouter` uses that flag instead of inferring the lane from `senderName`.
- **Why this pass matters:** the previous router logic reserved `34 + 4` avatar width for any incoming message with a sender name, which made many channel bubbles narrower than iOS even when no avatar was actually shown.
- **Text wrapping quality tightened:** `TgMessageBubbleBase` and media-caption text paths now use ArkUI `lineBreakStrategy(LineBreakStrategy.HIGH_QUALITY)` on top of the existing word-break rules, aiming for less greedy wrapping and a closer visual rhythm to iOS text layout.
- **Diff stability:** `ChatTimelineDataSource` now includes `reserveAvatarLane` in row equality, and `TgChatScreenPage` forwards the new flag into `TgMessageRouter`.
- **HarmonyOS grounding:** ArkUI docs note that `lineBreakStrategy` affects line wrapping when `wordBreak` is not `BREAK_ALL`; this pass keeps `BREAK_ALL` only for forced long-token cases and upgrades normal text/caption wrapping quality instead of switching to a harsher break mode.
- **Build verification:** `./scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- **Verification status:** passed; historical regression checklist: broadcast/channel posts, long mixed-language text bubbles, and media captions to confirm bubbles expand more like iOS and stop wrapping early due to the previously hidden avatar lane.

## Recent changes (2026-03-15, session 18)

### Dedicated instant-video bubble for `videoNote`
- **`videoNote` no longer reuses the rectangular video bubble path:** `TgMessageRouter` now routes `videoNote` through a dedicated `TgInstantVideoBubble` atom and a separate router branch without the generic rectangular media-shell background.
- **New atom:** `entry/src/main/ets/ui/tg_ui/atoms/TgInstantVideoBubble.ets` renders a circular media surface with a centered play affordance, thumbnail-first preview fallback, and an in-circle duration badge.
- **iOS-like sizing contract:** `TgUiTokens` now exposes dedicated instant-video tokens plus `resolveInstantVideoBubbleSize(...)` with compact/regular targets `212 / 240` and a safe minimum clamp.
- **Spec + demo added:** `entry/src/main/ets/ui/tg_ui/spec/TgInstantVideoBubble.md` and `entry/src/main/ets/ui/tg_ui/demos/TgInstantVideoBubbleDemo.ets`.
- **HarmonyOS grounding:** the new atom uses rounded/circular clipping with `.clip(true)` in line with ArkUI clipping guidance, avoiding the old bleed/rectangular-corner artifact path.
- **Why this pass matters:** device feedback said special videos still looked unlike iOS even when previews/layout were otherwise correct; the old router kept wrapping `videoNote` inside the rectangular visual-media shell.
- **Build verification:** `powershell -ExecutionPolicy Bypass -File scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- **Verification status:** passed; historical regression checklist: round `videoNote` bubble shape, preview visibility before full download, tap-to-open after pending download, and sender/reply/caption compositions for instant-video rows.

## Recent changes (2026-03-15, session 19)

### Album photo viewer now supports gallery paging
- **Album taps now open a gallery instead of a single detached photo:** `TgChatScreenPage.openPhotoViewer(...)` now accepts the whole album path list, normalizes out empty placeholder cells, stores the selected index, and passes gallery state into the fullscreen photo viewer overlay.
- **`TgPhotoViewerPage` now has a gallery mode:** it accepts `photoPaths` + `initialIndex` and uses ArkUI `Swiper` with `index(...)`, `onChange(...)`, `indicator(false)`, and `loop(false)` to page horizontally between album photos.
- **Single-photo path is preserved:** when there is only one photo, the old pinch-to-zoom + pan + vertical-drag-dismiss path still runs unchanged.
- **Viewer chrome for galleries:** the fullscreen overlay now shows an in-view counter (`current / total`) for albums while keeping the existing close button / caption shell.
- **Why this pass matters:** grouped album bubbles already existed, but tapping them still opened only one image with no way to move across the rest of the album, which was the main remaining gap after grouped-photo support landed.
- **HarmonyOS grounding:** this patch uses ArkUI `Swiper`'s `index` + `onChange` contract for deterministic horizontal page switching in fullscreen media UI.
- **Build verification:** `powershell -ExecutionPolicy Bypass -File scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- **Verification status:** passed; historical regression checklist: horizontal paging across 2/3/4/5+ albums, correct initial page when tapping any album cell, behavior with partially downloaded albums (empty cells filtered out), and single-photo zoom/dismiss path after the gallery refactor.

## Recent changes (2026-03-15, session 20)

### Dedicated audio/music bubble path
- **`audio` no longer reuses the generic document bubble:** `TgMessageRouter` now routes `audio` through a dedicated `TgAudioBubble` atom instead of `TgDocumentRow`.
- **New atom/spec/demo:** added `entry/src/main/ets/ui/tg_ui/atoms/TgAudioBubble.ets`, `entry/src/main/ets/ui/tg_ui/spec/TgAudioBubble.md`, and `entry/src/main/ets/ui/tg_ui/demos/TgAudioBubbleDemo.ets`.
- **VO/runtime plumbing:** `ChatTimelineVO` now carries `audioDuration`, `audioTitle`, and `audioPerformer`; `ChatTimelineDataSource` diffs them; `TgChatScreenPage` forwards them into the router.
- **Tap contract improved:** if the audio file is not local yet, tap still triggers `downloadFile`; if it is already local, `TgChatScreenPage` now opens it via Ability Kit `startAbility` with `ohos.want.action.viewData` using the existing `file://...` URI plus MIME type.
- **Visual contract:** audio bubbles now use a round play/download affordance plus title/performer-meta rhythm instead of a document extension tile, which is closer to Telegram music bubbles than the old file fallback.
- **HarmonyOS grounding:** this pass uses the documented `startAbility({ action: 'ohos.want.action.viewData', uri, type, flags })` pattern for opening local files in another app and keeps media URIs in the `file://bundle/path` form required by that API.
- **Build verification:** `powershell -ExecutionPolicy Bypass -File scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- **Verification status:** passed; historical regression checklist: downloaded music files should open correctly from the chat bubble, undownloaded ones should trigger download only, and long track/performer strings should ellipsize cleanly without regressing bubble width.

## Recent changes (2026-03-16, session 21)

### Reference-driven audio/file bubble rewrite
- **Refs rechecked before changing the atoms:** Telegram iOS `ChatMessageInteractiveFileNode.swift` and Android `AudioPlayerCell.java` / `SharedDocumentCell.java` all point to the same visual rule: file/audio bubbles are organized around a **dominant primary control area**, not around a subtle chip attached to a mostly flat tile.
- **Why the previous pass was not enough:** emulator feedback said audio/file bubbles still looked unchanged, which matched the refs — the earlier square-tile + small-chip pass was too soft to materially change the perceived hierarchy.
- **`TgAudioBubble` rewritten to a control-first composition:** the leading affordance is now a prominent `44vp` primary control with ring-progress / spinner / play-download states, while the text stack is `title (up to 2 lines) -> performer/fallback -> duration/size/status`.
- **`TgDocumentRow` rewritten around a stronger leading tile:** the file tile is now `48vp`, uses an in-tile ring progress / spinner / extension face, and keeps the secondary action chip visually separate from the identity tile so document rows scan faster.
- **Integration safeguard:** `TgMessageRouter` already routes `document` payloads with `mimeType = audio/*` through `TgAudioBubble`, so the rewrite is visible even for real-world audio files that do not arrive as TDLib `messageAudio`.
- **Build verification:** `powershell -ExecutionPolicy Bypass -File scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- **Verification status:** passed; historical regression checklist: real `audio/*` documents, real file rows under download progress, and the optical strength of the new primary-control hierarchy in incoming/outgoing chat bubbles.

## Recent changes (2026-03-15, session 17)

### P0 media reliability pass: special-video previews, pending open, resilient albums
- **Animation / videoNote previews now use real thumbnail fields:** `MessageDto.parseMessageContent(...)` now fills `videoThumbPath` / `videoThumbFileId` for both `messageAnimation` and `messageVideoNote`, so these special media types no longer depend on the full media file path just to show a preview.
- **Timeline VO now propagates special-video download/open contract:** `ChatTimelineVO` maps `animation` and `videoNote` into the shared video lane with explicit `videoFileId` plus thumbnail-first preview fallback (`videoThumbPath` first, full local media path second).
- **Photo albums no longer collapse just because some cells are still not local:** `buildPhotoAlbumEntry(...)` now preserves every album slot even when a given cell currently has an empty local URI, allowing `TgGroupedPhotoBubble` placeholders to keep the album grouped instead of degrading to a single photo bubble.
- **Video tap now supports on-demand open:** `TgChatScreenPage` keeps a pending video-open latch (`fileId + caption + thumb`) and, when the user taps a video/GIF/videoNote without a local full file yet, it triggers `downloadFile`, waits for the timeline/store to expose the downloaded local path, and auto-opens the fullscreen player on the next rebuild.
- **Why this pass matters:** device feedback showed that some albums merged only partially, some videos did nothing on tap, and special media often had no preview despite otherwise correct bubble layout.
- **Build verification:** `powershell -ExecutionPolicy Bypass -File scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`; post-build cleanup still warns if DevEco keeps the generated HAP file locked, but the assemble/smoke result is successful).
- **Verification status:** passed; historical regression checklist: partial-download videos/GIFs/video notes should open after one tap, album bubbles should stay grouped with placeholder cells while media is still downloading, and special-video thumbnails should appear before the full file is local.

## Recent changes (2026-03-14, session 7)

### Media pipeline activation
- **Critical fix: `file://` URI conversion** in `ChatTimelineVO.ets` — all media paths (photo, video thumb, sticker, voice, document, animation, video note) now converted via `fileUri.getUriFromPath()` before passing to UI components. Without this, ArkUI `Image()` silently failed on raw sandbox paths.
- **New VO fields:** `documentPath`, `documentFileId`, `audioPath`, `audioFileId`, `videoFileId`, `voicePath` — enables on-demand download and future playback.
- **On-demand document download:** `TgDocumentRow` gained `documentPath` param + `onTap` event. Shows download icon when not downloaded, document icon when ready. Tap triggers `requestMediaDownload()` in `TgChatScreenPage`.
- **`requestMediaDownload()` in TgChatScreenPage:** sends `downloadFile` command to TDLib, handles direct response → `FileDownloadedEvent` → store update → UI re-render with file path.
- **TgMessageRouter:** new params `documentPath`, `documentFileId`, `audioPath`, `audioFileId`, `onMediaDownloadRequest` event.
- Auto-download (photos, stickers, voice, animations, video notes) was already wired via `DownloadMessageMediaUseCase` — now actually visible thanks to URI fix.
- Verification status: passed for all media display and document download.

### Badge fix + styling
- **Badge not resetting fix:** removed premature `maybeMarkChatRead()` calls from `aboutToAppear`/`onActiveChatChanged`. Only store subscription calls it now (after `openChat` has been processed by TDLib).
- **Badge color alignment:** light `#0088CC` → `#0088FF` (iOS match), dedicated `unread_badge_muted` color `#B6B6BB` (iOS match, was using `text_secondary`).
- **Tab bar badge size:** 16→18vp, radius 8→9 (iOS: 18pt).

## Recent changes (2026-03-14, session 6)

### Chat opening performance + unread marker

- **List `initialIndex` for instant positioning:** `TgChatScreenPage` now uses `List({ initialIndex })` to render at the correct position immediately (unread boundary → saved scroll → bottom). No more scroll-from-top animation. Follows official HarmonyOS chat history pattern with `maintainVisibleContentPosition(true)`.
- **Race condition fix (OpenChatUseCase vs screen history load):** `HISTORY_INITIAL_DELAY_MS` changed from 0 to 600ms. Previously TgChatScreenPage grabbed the bucket lock before OpenChatUseCase could send `openChat` to TDLib, causing TDLib to return only locally cached messages (1-2 instead of full page). The delay lets OpenChatUseCase run first.
- **Placeholder release deadlock fix:** `INITIAL_HISTORY_PLACEHOLDER_RELEASE_COUNT` changed from 12 to 1. The old threshold blocked rendering for chats with <12 messages when `canLoadOlder=true`, preventing `onScrollIndex` from ever firing, which prevented pagination from triggering — eternal loading spinner.
- **Static list pagination recheck:** Added `schedulePaginationRecheck(PROGRAMMATIC_SCROLL_GUARD_MS + 50)` after all restore paths. After initial load with few messages, static lists don't re-fire `onScrollIndex` when the guard expires, so pagination needs an explicit recheck.
- **Sticky unread marker:** `stickyLastReadMessageId` captured at chat entry (from `chat.lastReadInboxMessageId` when `unreadCount > 0`). Used instead of live `unreadCount` for the entire chat session, so `markChatRead()` no longer causes the unread separator to disappear instantly. Reset on `aboutToDisappear`.
- **`computeInitialIndex()` method:** Priority: (1) unread boundary, (2) saved scroll position via `scrollPositionCache`, (3) bottom (newest messages). Called before `restoreScrollPosition()` in `rebuildTimeline`.
- **Removed `.opacity(prependScrollMask)` hack** from List — no longer needed with initialIndex approach.
- Verification status: passed for all chat opening changes.

## Recent changes (2026-03-14, session 5)

### Glass system overhaul + composer fix + status bar fix
- **Status bar theme-aware icons:** `EntryAbility` now explicitly sets `statusBarContentColor` via `setWindowSystemBarProperties` — white for dark mode, black for light. Listens to `onConfigurationUpdate` for runtime theme changes. Fixes blurry/invisible battery/network/time icons.
- **Composer focus border fix:** `TgComposerInput` switched from `TextContentStyle.INLINE` (shows blue focus outline) to `TextContentStyle.DEFAULT` (no visual focus change). Added `.caretColor(TgUiTokens.COMPOSER_ACTION_ACTIVE)` for telegram blue cursor, `.borderRadius(0)` to remove TextArea's own border, explicit padding since DEFAULT has no internal padding.
- **Composer sizing aligned to iOS:** button 34→36, min capsule height 36→38, capsule radius 18→19, text padding top 6→5 / bottom 5→4, vertical inset 6→5, attach left inset 3→4 (all matching iOS `ChatTextInputPanelNode` values).
- **BlurStyle upgrade:** all glass elements switched from `BlurStyle.Thin`/`BlurStyle.Regular` to `BlurStyle.COMPONENT_REGULAR` (purpose-built for UI component blur). Tab bar pill uses `BlurStyle.COMPONENT_THIN`. Changed in `TgGlassPolicy` (all 5 methods) + `TgChatTopBar` capsules + `TgTabBar` pill.
- **Glass edge highlights:** added `glass_edge_highlight` color resource (`#55FFFFFF` light, `#33FFFFFF` dark). Applied as 0.75vp border to: composer capsule, chat top bar capsules, tab bar island, filter bar. Replaces old `separator` borders — mimics iOS glass catching light on edges.
- **Glass overlay alpha increased:** `glass_nav_bg` / `glass_tab_bg` alpha raised from 2% to 15-20% for visible frosted glass tint (was nearly invisible before).
- **Tab bar pill color:** changed from blue 9% to gray 10% (`tab_pill_bg`: light `#1A767680`, dark `#1AFFFFFF`). Tab bar pill now has glass blur (`COMPONENT_THIN`) + edge highlight border. Island radius kept at 999 (full capsule, matching iOS `backgroundSize.height * 0.5`).
- **Smoke test:** `bash ./scripts/smoke-ui-phase0.sh` ✅
- Verification status: passed for all glass/blur/composer/status bar changes.

## Recent changes (2026-03-13, session 4)

### Refactor: hacky gestures → proper system APIs
- **Removed PanGesture swipe-to-reply** — was using shared `@State swipeOffsetX` causing all LazyForEach items to re-render on every gesture frame. Performance anti-pattern.
- **Replaced with LongPressGesture(300ms) → `promptAction.showActionMenu()`** — system-native action sheet with Reply + Copy buttons. No per-item state, no gesture conflicts.
- **Reply bar token alignment** — bar width/radius/gaps now use `TgUiTokens.REPLY_SNIPPET_*` tokens instead of hardcoded values. Height 45vp (iOS ReplyAccessoryPanelNode = 45pt). Author fontColor uses `REPLY_SNIPPET_BAR_INCOMING` for blue bar.
- **Member count localized** — group/channel subtitle now uses `localized($r('app.string.group_members_count'))` / `localized($r('app.string.subscribers_count'))` with `%s` replacement. Fallback labels also localized.
- **String resources added:** `action_reply`, `action_copy`, `subscribers_count`, `channel_label`, `group_label` in `string.json`.
- **Removed unused state vars:** `contextMenuMessageId`, `contextMenuText`, `contextMenuAuthor`, `contextMenuPreview`.
- Verification status: passed: long-press action menu, reply flow, copy with toast, localized member count.

## Recent changes (2026-03-13, session 3)

### Interactive features + polish pass
- **Emoji media prefixes:** Chat list preview now shows `📷 Photo`, `📹 Video`, `📎 File`, `🎤 Voice message`, `📍 Location`, `📊 Poll`, `👤 Contact` instead of bracketed `[Photo]`, `[Video]` etc. Matches iOS Telegram style.
- **Group/channel top bar subtitle:** `updateChatTopBarData()` now shows localized member count for groups/channels. Typing indicator still overrides subtitle.
- **Sender name token consistency:** Fixed sticker and media bubble paths in TgMessageRouter — were using hardcoded `fontSize(13)/fontWeight(Medium)`, now use `MSG_SENDER_NAME_SIZE`(14)/`MSG_SENDER_NAME_WEIGHT`(Bold) matching the text bubble path.
- **`showMessageActions()`:** `promptAction.showActionMenu()` with Reply + Copy. Copy uses `pasteboard` API + toast feedback.
- **Reply bar:** above composer with author, preview, close button. `replyToMessageId` wired into `SendMessageParams`. Reply state resets after send.

## Recent changes (2026-03-13, session 2)

### iOS reference alignment — full pixel-level token pass
- **Deep comparison with iOS Telegram source** (ChatListItem.swift, ChatMessageBubbleItemNode, ChatMessageDateAndStatusNode, TabBarComponent.swift, PeerInfoHeaderNode, ChatTextInputPanelNode) produced 4 detailed reports in `docs/ai/`.
- **Unread badge color**: red `#FF3B30` → blue `#0088CC` (light), `#FF453A` → `#3390EC` (dark) — matches iOS accent color.
- **Chat list row**: left padding 16→10, height 72→76, title font 17→16, preview 1→2 lines, separator 1→0.5vp, title-preview gap 2→0, separator inset 80→82, author name color blue→black.
- **Message bubbles**: max width 85%→75%, padding H 10→11, meta font 12→11, sender name 13 Medium→14 Bold, reply title 13 Medium→14 Bold, reply preview 13→14, photo/video radius 17→16, document padding V 10→15. Added same-sender (2vp) vs different-sender (8vp) message spacing.
- **Date separator**: height 24→34, padding H 10→6.
- **Tab bar**: icon 23→24, badge font 11→13.
- **Composer**: text left padding 4→12, capsule radius 18→20.
- **Profile**: title 22 Bold→28 Medium, subtitle 15→17, online color blue→green, phone color→blue (accent), info labels 16→17/14.
- **Chat top bar**: subtitle online color blue→green.
- New color resource: `author_name` (black/white by theme).
- New tokens: `MSG_SENDER_NAME_SIZE`, `MSG_SENDER_NAME_WEIGHT`, `MSG_SPACING_SAME_SENDER`, `MSG_SPACING_DIFF_SENDER`, `CHAT_ROW_PREVIEW_MAX_LINES`, `COLOR_AUTHOR_NAME`.
- Local verification:
  - `bash ./scripts/smoke-ui-phase0.sh` ✅
  - `./scripts/smoke-build.ps1` ✅ (BUILD SUCCESSFUL)
- Verification status: passed.

## Recent changes (2026-03-13)

### TgChatTopBar glass contract restored
- `TgChatTopBar.ets` no longer hardcodes opaque fallback capsules while the passport claims glass behavior.
- Restored the actual glass path:
  - `glassMode` param,
  - realtime blur vs fallback background selection,
  - separate glass shell + specular highlight + content layers inside each capsule,
  - chat-top-bar geometry moved into `TgUiTokens`.
- `TgChatTopBarDemo.ets` now includes an explicit fallback-glass state, so the demo matches the passport's blur/fallback matrix again.
- Local verification:
  - `./scripts/smoke-build.ps1` ✅
  - `./scripts/smoke-ui-phase0.ps1` ✅

### TgChatRow preview prefixes now render like Telegram states
- `ChatItemVO` no longer flattens all preview states into one plain string. Drafts and group author prefixes are now carried separately from the preview body.
- `TgChatRow.ets` now renders preview prefixes as a dedicated left fragment:
  - `Draft:` uses the error/draft accent color,
  - group sender prefixes (`You:` / sender name) use the Telegram accent color,
  - the preview body keeps its own ellipsis and color contract.
- Group typing rows now also reuse the split-prefix path (`Alice` + `typing...`) instead of a single flat blue string, which is closer to the iOS `authorName + activity` rhythm.
- `TgChatRowDemo.ets` now includes explicit draft, typing, and group-author prefix cases, and the passport documents the new split-prefix contract.
- Local verification:
  - `./scripts/smoke-build.ps1` ✅
  - `./scripts/smoke-ui-phase0.ps1` ✅

### TgChatMeta / unread badge optical tuning moved closer to iOS
- Re-grounded the right meta cluster against `ChatListItem.swift`, `ChatListBadgeNode.swift`, and `ChatListStatusNode.swift`.
- Tuned the visible metrics toward the iOS values:
  - time text now uses a 14pt-style token instead of the smaller generic meta size,
  - unread badge text now uses a 14pt token and slightly tighter horizontal padding, closer to the iOS stretchable badge width formula,
  - pinned icon size was reduced so it no longer reads oversized against the unread badge lane,
  - status icon size was increased to better match the iOS right-cluster visual weight.
- Local verification:
  - `./scripts/smoke-build.ps1` ✅
  - `./scripts/smoke-ui-phase0.ps1` ✅

### Typing preview no longer overuses author/accent styling
- Re-checked iOS typing behavior against `ChatListTypingNode.swift` and the `inputActivitiesLayout(...)` call site in `ChatListItem.swift`.
- Important correction: current iOS chat-list typing text is rendered through `ChatListInputActivitiesNode` using the chat-list message text color, not the draft/error accent and not the group-author accent path.
- Local tg_ui path now follows that closer:
  - group typing rows go back to a single preview string (`Alice typing...`) instead of a split accent prefix,
  - typing preview body stays on the normal preview tone,
  - demo/spec were updated to reflect this.
- Local verification:
  - `./scripts/smoke-build.ps1` ✅
  - `./scripts/smoke-ui-phase0.ps1` ✅

### TgChatRow rhythm and separator optics tightened toward iOS
- Re-grounded row spacing against `ChatListItem.swift`:
  - iOS uses a compact vertical rhythm (`titleSpacing = -1`, `authorSpacing = -3`),
  - the separator lane starts around `80pt` on the standard 60pt-avatar path instead of following the full text-start inset.
- Local tg_ui tuning now reflects that better:
  - title/preview gap was tightened,
  - chat-row separator inset is now anchored to the iOS-like lane instead of the previous overly deep text-start position.
- Local verification:
  - `./scripts/smoke-build.ps1` ✅
  - `./scripts/smoke-ui-phase0.ps1` ✅

### TgChatRow typography no longer depends on generic screen title tokens
- Re-grounded row typography against the active iOS source:
  - `ChatListItem.swift` uses a `16/17`-scaled medium title and a `15/17`-scaled preview text.
- The HarmonyOS row now uses dedicated row-level typography tokens:
  - `CHAT_ROW_TITLE_FONT_SIZE = 16`
  - `CHAT_ROW_PREVIEW_FONT_SIZE = 15`
- This avoids coupling chat rows to the generic app-wide `FONT_TITLE_SIZE` token and makes the list typography closer to Telegram iOS without affecting other screens.
- Local verification:
  - `./scripts/smoke-build.ps1` ✅
  - `./scripts/smoke-ui-phase0.ps1` ✅

### TgTabBar cleanup after the reference correction
- Removed dead safe-area bookkeeping from `TgTabBar.ets`: the atom no longer computes/stores a bottom inset it never uses.
- Bottom safe-area ownership remains explicitly at the page level (`MainTabsPage` + `computeTabBottomInset()`), while the atom only adapts its capsule width from the live window width.
- `spec/TgTabBar.md` source mapping now points to the current active iOS files:
  - `TabBarComponent.swift`
  - `TabBarContollerNode.swift`
  - `TabBarNode.swift`
- Local verification:
  - `./scripts/smoke-build.ps1` ✅
  - `./scripts/smoke-ui-phase0.ps1` ✅

### TgComposerInput moved back to a controlled, tokenized contract
- `TgComposerInput` no longer owns draft text locally. The live chat screen now owns the composer draft and passes it down as a controlled `text` prop, which keeps the atom aligned with its passport and avoids hidden local-state drift.
- Added the optional emoji lane back into the unified capsule contract (`showEmojiButton`) and updated the demo/spec to show the real shell states again.
- Pulled the main composer geometry into `TgUiTokens` so the atom is no longer carrying a private block of hardcoded visual constants.
- HarmonyOS grounding applied in the atom:
  - `TextArea.style(TextContentStyle.INLINE)` for custom input-shell composition
  - `EnterKeyType.Send` + `onSubmit(..., SubmitEvent)` + `keepEditableState()` so send-style submit does not unnecessarily dismiss the keyboard
- Local verification:
  - `./scripts/smoke-build.ps1` ✅
  - `./scripts/smoke-ui-phase0.ps1` ✅
- Verification status: passed; historical regression checklist:
  1. keyboard/focus feel on real device,
  2. emoji icon spacing inside the capsule,
  3. send/mic transition and draft clearing behavior in a live chat.

### Chat list interaction restored after integrated-header regression
- `TgChatListNavigationBar` now sets an explicit root height equal to `topInset + CHAT_LIST_NAV_TOTAL_HEIGHT`.
- Root cause: after moving to the new integrated header atom, the top overlay inside `ChatListPage` no longer had an explicit height, so in the `Stack` composition it could expand to the full screen and swallow list gestures/taps.
- Result: the Chats list should no longer become effectively non-clickable / non-scrollable underneath the header overlay.
- Local verification:
  - `./scripts/smoke-ui-phase0.ps1` ✅
  - `./scripts/smoke-build.ps1` ✅
- Verification status: passed on the Chats tab; historical regression checklist:
  1. the list scrolls normally,
  2. row taps open chats again,
  3. the integrated header still behaves visually as intended.

### TgTabBar corrected after deeper iOS reference check
- The previous same-day rewrite to a full-width bottom shelf was incorrect.
- After re-checking the current iOS refs, the active Telegram iOS implementation uses a centered glass capsule shell (`TabBarComponent` + `GlassBackgroundContainerView`) with bottom outer insets, not a full-width shelf.
- `TgTabBar` was corrected back toward that model:
  - centered capsule root,
  - blurred glass background,
  - inner per-tab highlight/lens behavior,
  - bottom safe-area handled outside the capsule by page margin/inset math.
- `MainTabsPage` again positions the custom bar above the bottom safe area, and `computeTabBottomInset()` was restored to reserve capsule height + safe area + breathing gap.
- Grounding:
  - iOS refs: `TabBarContollerNode.swift`, `TabBarComponent.swift`, `TabBarNode.swift`
  - HarmonyOS docs/patterns: custom overlaid chrome + bottom safe-area reservation via page content inset
- Local verification:
  - `./scripts/smoke-ui-phase0.ps1` ✅
  - `./scripts/smoke-build.ps1` ✅
- Verification status: passed; historical regression checklist:
  1. capsule geometry vs Telegram iOS,
  2. correct bottom safe-area handling on gesture-navigation devices,
  3. unread badge placement and tap targets on all 4 tabs.

### Chat screen visual polish (reference-aligned)
- **Bubble tokens aligned to iOS/Android references:** radius 18→17 (Android default), padding H 12→10 / V 8→6 (iOS: 10-11/~6), max width ratio 0.80→0.85 (iOS compact), photo/video bubble radius unified to 17
- **Inter-message spacing reduced:** 8vp (4+4) → 3vp (1+2), closer to iOS ~2-3pt
- **TgChatTopBar glass fix:** `.clip(true)` + `.renderGroup(true)` on blur Columns in all 3 capsules (back, title, avatar) — fixes square blur visible behind rounded capsules (Lesson #43)
- **TgChatTopBar bottom padding:** 6vp breathing room between capsules and content; `computeTopBarHeight()` updated to include `TOP_BAR_BOTTOM_PADDING`
- **TgComposerInput rewrite (iOS-aligned):** unified single glass capsule `[📎 Message... ➤]` instead of separate attach + input capsules; max lines 6→12 (iOS); buttons 40→34vp inside capsule
- **LazyForEach prepend fix (Lesson #42):** `ChatTimelineDataSource` prepend path changed from bulk array replacement + batch notify to per-item `splice(0,0,item)` + `notifyDataAdd(0)` — matches official HarmonyOS example for `maintainVisibleContentPosition(true)`
- Verification status: passed

## Recent changes (2026-03-12)

### Chat list header realigned to iOS-style integrated nav + search
- Added new atom `entry/src/main/ets/ui/tg_ui/atoms/TgChatListNavigationBar.ets` with:
  - centered title row,
  - intrinsic left `Edit` action,
  - right compose action,
  - integrated search lane inside the header surface.
- `ChatListPage` no longer composes `TgTopBar` plus a scrolling `Search` list item. It now offsets the list under a single integrated header, which is closer to iOS `ChatListNavigationBar` (`searchScrollHeight = 54.0`).
- Added tokenized metrics `CHAT_LIST_NAV_SEARCH_AREA_HEIGHT`, `CHAT_LIST_NAV_TOTAL_HEIGHT`, and `ICON_RES_EDIT`.
- Added `computeChatListTopBarHeight()` to keep `List.contentStartOffset(...)` aligned with the new header height.
- Added passport + demo:
  - `entry/src/main/ets/ui/tg_ui/spec/TgChatListNavigationBar.md`
  - `entry/src/main/ets/ui/tg_ui/demos/TgChatListNavigationBarDemo.ets`
- Smoke scripts updated to validate `TgChatListNavigationBar` instead of the old ChatList `TgTopBar + Search` assumption.
- Local verification:
  - `./scripts/smoke-build.ps1` ✅
  - `bash ./scripts/smoke-ui-phase0.sh` ✅
  - `./scripts/smoke-ui-phase0.ps1` ✅
- Verification status: passed on the chat list tab; historical regression checklist:
  1. `Edit` is no longer clipped in Russian,
  2. search visually belongs to the header instead of looking like a second strip,
  3. scroll-under-header behavior feels closer to Telegram iOS.

### TgChatTopBar centering fix
- `TgChatTopBar` content row no longer packs all capsules from the left. The layout now uses fixed left/right side capsules and a weighted center lane, which keeps the title capsule visually centered and the avatar anchored to the right edge.
- Title and subtitle text inside the center capsule are now centered as well, matching the component passport and the intended Telegram-style navigation balance.
- Triggering evidence: screenshot `C:\Users\Kharki\Pictures\Screenshot_2026-03-12T022356.png` showed the whole top bar cluster shifted left.
- Local verification: `./scripts/smoke-build.ps1` ✅, `bash ./scripts/smoke-ui-phase0.sh` ✅
- Verification status: passed on the chat screen itself.

### TgChatTopBar glass layering fix
- `TgChatTopBar` capsules now use a layered `Stack`: blur/tint/border background at the bottom, specular highlight in the middle, and icon/text/avatar content on the top layer.
- This fixes the previous composition where title/icon/avatar lived in the same node that owned the glass blur and top `overlay(...)`, which visually made the content look embedded into the glass instead of sitting above it.
- Grounding: local HarmonyOS blur API notes via `backgroundBlurStyle` docs/search + existing Telegram iOS navigation-bar visual principle (content over blur, not under highlight).
- Local verification: `./scripts/smoke-build.ps1` ✅, `bash ./scripts/smoke-ui-phase0.sh` ✅
- Verification status: passed on a dark chat background; the glass-layer text/icon highlight issue is considered resolved.

### Chat history runtime stabilization (LazyForEach datasource + delayed edge recheck)
- `ChatTimelineDataSource` no longer mixes `DataChangeListener.onDatasetChange(...)` with `onDataAdd/onDataDelete/onDataChange`. The chat timeline now uses a single notification family only, which matches the ArkUI LazyForEach contract and removes the runtime error seen in HiLog: `onDatasetChange cannot be used with other interface`.
- `TgChatScreenPage` now guards pagination callbacks while `applyDiff()` is mutating the datasource, so `onScrollIndex` / `onDidScroll` signals triggered by ArkUI during prepend cannot recursively fire another `loadOlderMessages()` in the same update cycle.
- Post-load `recheckPaginationEdge()` is now deferred to the next tick via `schedulePaginationRecheck()`, instead of running immediately in the `loadOlder/loadNewer` promise `finally`. This avoids rechecking against stale pre-diff indices/counts before the scheduled timeline rebuild has applied the new batch.
- Grounding: local HarmonyOS SDK typings in `C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\ets\component\lazy_for_each.d.ts` (`DataChangeListener`, `onDataAdd/onDataDelete/onDataChange/onDatasetChange`) and `...\component\list.d.ts` (`maintainVisibleContentPosition` note that prepend emits `onDidScroll` / `onScrollIndex`).
- Triggering evidence: device HiLog `C:\Users\Kharki\AppData\Local\Huawei\DevEcoStudio6.0\tmp\HiLog-Mate 80 Pro-All logs of selected app-[9918]com.telegram.harmonyos-DEBUG-1773260285706.txt`.
- Local verification: `./scripts/smoke-build.ps1` ✅, `bash ./scripts/smoke-ui-phase0.sh` ✅
- Verification status: passed on the reproduction chat; the `Loading older messages...` storm and `Timeline rebuild failed` errors are considered resolved.

### Big-chat open fast path (history first, peers after)
- `LoadChatHistoryUseCase` now dispatches the `getChatHistory` batch **before** hydrating missing sender users, so large chats no longer wait on a blocking pre-render `getUser` loop.
- Missing sender hydration now runs in **parallel chunks** (`6` at a time) and dispatches normalized user events in **one batched store update** instead of one dispatch per user.
- `selectChatMessages()` / `selectChatMessagesForChatView()` now memoize sorted arrays by the per-chat message-map reference, so user-only updates reuse the existing message order instead of re-sorting the whole chat every time.
- `TgChatScreenPage` store subscription now ignores updates that do not touch the active chat's messages/chat/users/typing state.
- Grounding: Android `MessagesController.putUsers/putChats` + cached sender lookup in `MessageObject`, iOS `MessageHistoryView` / `ChatController` history-view path.
- Local verification: `./scripts/smoke-build.ps1` ✅, `bash ./scripts/smoke-ui-phase0.sh` ✅
- Verification status: passed on a large group/channel history.

### Native List prepend stabilization
- `TgChatScreenPage` chat history `List` now uses HarmonyOS native `maintainVisibleContentPosition(true)` for LazyForEach prepends.
- Removed the custom prepend `scrollToIndex` compensation hot path; it was still fighting ArkUI layout and could visibly yank the viewport during older-history insertion.
- Prepend path now only guards against pagination cascades while ArkUI performs the native visible-position preservation.
- Official grounding available in local HarmonyOS SDK typings: `C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\ets\component\list.d.ts` (`maintainVisibleContentPosition`, since 12).
- Local verification: `./scripts/smoke-build.ps1` ✅, `bash ./scripts/smoke-ui-phase0.sh` ✅
- Verification status: passed on the exact reproduction chat.

## Recent changes (2026-03-11)

### TgTabBar Android-style rewrite
- **Ring → Pill highlight**: full-tab capsule bg (9% alpha telegram_blue), scale 0.6→1.0 + opacity animation (320ms EaseOut)
- **Sizes aligned to Android**: island height 50→56vp, icon 23→24vp, text 10→12vp, font weight Normal→Bold on selection
- **Tokens**: removed 5 ring tokens, added `TAB_BAR_PILL_BG`, `TAB_BAR_PILL_ANIM_DURATION`
- **Colors**: `tab_selection_ring_bg` + `tab_selection_ring_stroke` → `tab_pill_bg` (light `#170088CC`, dark `#173390EC`)
- **Padding 8vp** inside island, `clip(false)` for badge overflow
- Reference: Android `GlassTabView.java` + `MainTabsLayout.java`

### Pagination aligned to Android/iOS patterns
- **Older trigger threshold**: 10 → 25 items (Android: 25 when scrolling)
- **Newer trigger threshold**: 6 → 5 items (iOS: 5)
- **Latch system removed**: replaced with simple `!isLoading` guard (Android pattern). Removed `olderPaginationEdgeArmed`, `newerPaginationEdgeArmed`, `refreshPaginationEdgeLatches()`. `recheckPaginationEdge` is now the sole continuous-loading mechanism.
- **Reason fix**: scroll pagination now uses `reason: 'default'` instead of `'restore'`

### Scroll compensation fix v2 (prepend flash elimination)
- **Pre-capture indices + yOffset BEFORE `applyDiff`**: prevents stale/double-counted `lastVisibleStartIndex` if `onScrollIndex` fires during `notifyBatchChange`
- **Viewport freeze**: `scrollTo({ yOffset: savedYOffset, animation: false })` called immediately after `applyDiff` to anchor viewport before ArkUI layout pass — prevents flash frame where prepended items are briefly visible
- **`contentStartOffset` gap preservation**: when user was near top (yOffset < topBarTotalHeight), `scrollToIndex` with `extraOffset: LengthMetrics.vp(gap)` preserves the top bar visual gap
- **Cascade block**: `blockAutoPaginationUntilUserScroll = true` during prepend — prevents repeated load→flash→load chains that the old 320ms guard couldn't stop
- Reference: Android `ChatActivity.scrollToPositionWithOffset()`, iOS `stationaryItemRange`
- Verification status: passed

### Chat older-history prepend autoscroll fix
- `TgChatScreenPage` prepend compensation now performs the viewport freeze + anchor `scrollToIndex` **synchronously in the same turn as `applyDiff()`**
- Removed the delayed second-pass prepend compensation from the hot path; the old deferred `setTimeout(16ms)` re-scroll was the remaining source of visible jump/autoscroll while older messages were inserted above the viewport
- Grounding: HarmonyOS docs `Maintaining the Scroll Position When Off-Screen Data Changes`, Android `LinearLayoutManager.scrollToPositionWithOffset()`, iOS `stationaryItemRange`
- Local verification: `bash ./scripts/smoke-ui-phase0.sh` ✅, `./scripts/smoke-build.ps1` ✅
- Still needs device/runtime verification on a long chat

## Recent changes (2026-03-10)

### Unified bubble container (sender name + time INSIDE bubbles)
- **TgMessageRouter** rewritten: now unified bubble container with bg/radius, renders sender name, reply snippet, content (via noBubbleWrap atoms), and TgMessageMeta all inside a single bubble
- Text path uses Stack(BottomEnd) for shrink-wrap + meta overlay (no width('100%') forcing max width)
- Media path: content atoms set fixed width, Column adapts
- Sticker path: no bubble bg, content + meta stacked
- All bubble atoms (TgPhotoBubble, TgVideoBubble, TgDocumentRow, TgVoiceBubble, TgMessageBubbleBase) gained `@Param noBubbleWrap`
- TgChatScreenPage simplified: sender name, reply, meta all passed to TgMessageRouter

### Nav lock fix (double-tap to open chat)
- ChatListPage.onPageShow(): unconditionally clears nav lock (was checking expired time, always failing)
- TgChatScreenPage.aboutToDisappear(): removed duplicate CHAT_NAV_LOCK_UNTIL set (handleBackPress already sets it)

### Composer safe area fix
- Removed double bottom inset: `.margin({ bottom: bottomOverlayInset })` → `.padding({ bottom: bottomOverlayInset })`
- Added `SafeAreaEdge.BOTTOM` to expandSafeArea so page bg extends behind nav bar
- Composer now floats as capsule island above navigation indicator

### QR Login (from earlier in session)
- Full pipeline: PhoneInputPage button → requestQrCodeAuthentication → QrLoginPage with QRCode component
- AppState extended with `waitQrCode` status + `qrCodeLink`

### NAPI batch fix (THREAD_BLOCK_6S)
- C++ receive loop: batches up to 50 responses per napi_call_threadsafe_function
- ArkTS dispatchBatch() parses JSON array

### Group/Channel profile
- TgProfilePage extended for groups/channels: description, invite link, member/admin count
- loadProfileInfo extracts invite_link (nested chatInviteLink) + administrator_count

## What is clearly in progress right now
- Latest local patch from 2026-03-09: fixed chat-list blank-cell regression by restoring stable `LazyForEach` identity (`chatId` key + per-chat `reuseId`), removing debug render noise from `TgChatRow`/`ChatListPage`, and guarding chat title updates against empty overwrite in normalizer/reducer.
- Latest local UX fallback from 2026-03-09: private chat row title can now fall back to `user.phoneNumber` before `Unknown`, reducing empty/placeholder rows for incomplete contact profiles.
- Latest local pagination fix from 2026-03-09: `TgChatScreenPage` now auto-rechecks pagination edge after each completed load via `recheckPaginationEdge()`. Fixes iOS-style continuous older/newer loading — no longer requires scroll-away-and-back to trigger the next batch. Added `lastVisibleEndIndex` tracking for accurate bottom-edge detection.
- Runtime stabilization around:
  - `AppCoreRuntime`
  - `AppStore`
  - `loadChats`
  - `loadChatHistory`
  - `openChat`
  - `ChatListPage`
  - `TgChatScreenPage`
- Latest log-driven runtime fix target: prevent `TgChatScreenPage` unread-boundary / saved-index restore from triggering automatic history pagination before the user actually scrolls.
- Latest verified outcome from 2026-03-08 HiLog: restore-triggered and edge-pinned pagination storms are closed in `TgChatScreenPage`; the loudest remaining runtime noise is now incomplete sender hydration during history loads.
- Latest local patch from 2026-03-08: `LoadChatHistoryUseCase` now allows a full default history page worth of missing sender hydrations (`MAX_MISSING_USER_HYDRATION_PER_LOAD = 64`) before dispatching the history batch, to reduce residual `Message references non-existent user` soft invariants.
- Latest log-driven root cause from 2026-03-08 HiLog: direct TDLib `user` payloads could parse nested `profile_photo.id` instead of the real top-level `user.id`, which explains bogus `getMe resolved` values and why repeated `getUser` calls still left sender users missing in store.
- Latest local patch from 2026-03-08: `TdObject` now exposes top-level int64 extraction, and user parsing / `getMe` resolution switched to `getTopLevelNumber('id')` so hydrated users land under the correct store key.
- Latest verified runtime outcome from the 2026-03-08 `[27274]` HiLog: `Message references non-existent user = 0`, `lastMessage is older than newest message in map = 0`, `Loading older/newer messages = 0`.
- New follow-up finding from the 2026-03-08 `[8081]` HiLog: a default `getChatHistory` open can return a **very short non-zero batch** (observed `1 events`) while older history may still plausibly exist, so treating `messageCount < limit` as end-of-history is too aggressive for TDLib.
- Latest local runtime patch from 2026-03-08: `LoadChatHistoryUseCase` now keeps pagination progress-based instead of `messageCount >= limit`-based, and performs one controlled `older` top-up when the first default history batch is suspiciously tiny.
- Latest local UX polish from 2026-03-08: tiny initial history batches are now **deferred from UI dispatch** until the controlled top-up finishes, and `TgChatScreenPage` shows a loading placeholder instead of a misleading temporary `No messages yet` / one-message state while the initial timeline is still settling.
- Latest follow-up from the 2026-03-08 `[21342]` HiLog: one controlled top-up is still not always enough — some chats can progress from `1` to only `2` visible messages before older history is still available.
- Latest local refinement from 2026-03-08: initial history top-up is now **bounded multi-step** (up to 3 older top-ups while progress continues), and the chat screen keeps the loading placeholder until the initial timeline reaches a reasonable size or older history is actually exhausted.
- Immediate operator focus has moved from **Phase 1 runtime bug-hunting** to **Phase 2 batch consolidation**; current patchset boundary is documented in `TASKS/CURRENT_PATCHSET_BOUNDARY.md`.
- Phase 3 verification gate has now been attempted on the current batch:
  - `./scripts/smoke-ui-phase0.ps1` ✅
  - `bash ./scripts/smoke-ui-phase0.sh` ✅
  - `./scripts/smoke-build.ps1` ✅ now finds DevEco hvigor automatically and completes successfully
- Latest local Phase 4 patch from 2026-03-08: `CallsPage` no longer renders a hardcoded placeholder; it now loads real recent calls through TDLib `searchCallMessages`, paginates with `next_from_message_id`, and hydrates missing peers via direct `getChat` / `getUser` response normalization.
- Latest local verification from 2026-03-08 for the Phase 4 patch:
  - `./scripts/smoke-ui-phase0.ps1` ✅
  - `bash ./scripts/smoke-ui-phase0.sh` ✅
- Latest local build verification from 2026-03-08:
  - `./scripts/smoke-build.ps1` ✅
  - discovered hvigor wrapper: `C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat`
- Current operator focus has moved beyond the old Phase 3/4 verification gate into **repo/docs hygiene**; the real-calls path is treated as verified per the 2026-03-22 verification sync, and prior device HiLog items remain only as historical regression reference.
- tg_ui support files are tracked in git; one-off repo-hygiene planning docs were moved under `TASKS/ARCHIVE/` to keep the active task root cleaner.
- High-level docs (`README.md`, `docs/ai/AI_MEMORY.md`, `docs/ai/UI_MIGRATION_PLAN.md`, `PROJECT_ANALYSIS.md`) are being actively kept in sync with the real tree.

## Risks / caveats
- This is an active refactor branch, not a clean release snapshot.
- Some older docs contain historical names (`AppTopBar`, `AppTabBarItem`, older feature-flag wording); prefer current runtime path over stale names.
- `scripts/smoke-ui-phase0.ps1` and `scripts/smoke-ui-phase0.sh` were re-run successfully on **2026-03-08** after the latest sender-hydration patch.
- Local HarmonyOS smoke build is now **verified** on **2026-03-08** through the DevEco-installed wrapper at `C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat`.
- The short-initial-history fix should now be treated as **passed** for the current branch per the 2026-03-22 verification sync; keep the older device HiLog note only as historical regression context.
- The Phase 4 real-calls path should now be treated as **passed** for the current branch per the 2026-03-22 verification sync; keep the older device-run/HiLog note only as historical regression context.
- TDLib prebuilts and local `ConfigLocal.ets` remain external prerequisites.

## Read order for a new contributor/agent
1. `AGENTS.md`
2. `STATUS.md`
3. `DECISIONS.md`
4. `ARCHITECTURE.md`
5. `TASKS/AGENT_EXECUTION_PLAN.md`
6. `TASKS/TODO.md`
7. `TASKS/LESSONS.md`
8. Deep docs under `docs/ai/`

## Recent changes (2026-03-16, session 22)

### Media transfer state foundation + visible download indicators
- **Unified file transfer state added to AppState:** `AppState.files.transfers` now keeps `fileId -> transfer` metadata (`active/completed/path/size/progress-related fields`) instead of relying only on a page-local pending set.
- **`updateFile` now feeds UI transfer state:** `FileNormalizer` emits a new `fileTransferUpdated` event on every TDLib `updateFile`, and `filesReducer` stores that transfer state while still applying `fileDownloaded` local paths into users/chats/messages.
- **Photo bubbles now finally expose transfer UX:** `TgPhotoBubble` gained explicit `hasLocalPhoto + isDownloading + downloadProgress`, so photo thumbs/full-photo auto-download can show a visible overlay instead of silently loading in the background.
- **Video / instant-video overlays upgraded:** `TgVideoBubble` and `TgInstantVideoBubble` now show progress-aware download overlays (spinner + percent when available) instead of a boolean-only pending state.
- **Document/audio/voice now consume real progress:** `TgDocumentRow` now uses live reducer-fed `downloadProgress`, `TgAudioBubble` shows download meta/progress bar, and `TgVoiceBubble` reflects transfer progress in its trailing label while downloading.
- **Timeline/runtime wiring completed:** `ChatTimelineVO`, `ChatTimelineDataSource`, `TgMessageRouter`, and `TgChatScreenPage` now propagate transfer state/progress from store to bubbles, while still preserving the page-owned dedupe latch for instant on-tap pending feedback.
- **Reducer safety fix:** `filesReducer.cloneMessageWithContent(...)` now preserves `mediaAlbumId` when file paths are patched into message content.
- **Build verification:** `powershell -ExecutionPolicy Bypass -File scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- **Verification status:** passed; historical regression checklist: photo auto-download overlay visibility, video/animation/videoNote percent overlays, document/audio/voice progress behavior, and follow-up visual polish pass for audio/file bubble aesthetics.

## Recent changes (2026-03-16, session 23)

### Audio/file bubble visual polish pass
- **`TgAudioBubble` no longer reads like a document row:** the leading affordance is now a square media tile with a small play/download overlay chip in idle states, while active downloads reuse the tile center for spinner/percent feedback.
- **Audio hierarchy is clearer:** music bubbles now render `title` → `performer/fallback` → smaller duration/size/status line, which better matches the dedicated Telegram music-message family.
- **`TgDocumentRow` leading cluster is richer:** idle file bubbles keep the extension label in the main tile but now add a small action chip for open/download affordance, making the file state easier to parse at a glance.
- **Reference grounding:** this pass was based on the Telegram iOS interactive file/music node pattern where the leading media/file control is a composed cluster, not a flat single icon block.
- **HarmonyOS grounding:** the pass stays within ArkUI `Stack` + `Row/Column` composition and the existing `Progress`/loading control model already verified in this repo.
- **Build verification:** `powershell -ExecutionPolicy Bypass -File scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- **Verification status:** passed; historical regression checklist: whether the new audio tile / file action-chip composition feels sufficiently close to Telegram on real message histories, and whether any remaining drift is now limited to token tuning rather than missing state/structure.

## Recent changes (2026-03-16, session 24)

### Integration fix for audio-like documents + stronger visual contrast
- **Likely runtime cause of “nothing changed” identified:** real chats can contain audio payloads that still travel through the `document` content path with `mimeType = audio/*`, so they were bypassing the dedicated `audio` router branch entirely.
- **Router fallback added:** `TgMessageRouter` now routes `contentType = 'document'` + `mimeType.startsWith('audio/')` through `TgAudioBubble` while preserving the existing document open/download tap contract.
- **Visual contrast strengthened:** audio tile icon tint and action-chip sizes were increased, and document extension labels now use the stronger icon tint so the leading cluster reads more clearly at a glance.
- **Build verification:** `powershell -ExecutionPolicy Bypass -File scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- **Verification status:** passed; historical regression checklist: whether the user-visible audio cases were indeed document-backed audio payloads and whether this router fallback now makes the visual delta finally obvious in real chats.

## Recent changes (2026-03-15, session 21)

### Media download policy tightened + pending-state UI parity pass
- **Broad auto-download was intentionally reduced:** `DownloadMessageMediaUseCase` now limits background fetches to `photoThumb`, full `photo`, `videoThumb`, and `sticker`. Voice notes, GIF/animation files, and video notes now stay on-demand instead of being fetched in the background.
- **On-demand spam guard added:** `TgChatScreenPage.requestMediaDownload(...)` now deduplicates repeated taps with a page-owned pending-file set, directly addressing the 2026-03-16 `[31799]` HiLog pattern where one file ID could trigger many repeated `downloadFile` requests before the local path appeared.
- **Pending download UI is now explicit in chat bubbles:** document/audio/voice/video/instant-video atoms now render an indeterminate loading control while a file is pending, and video/instant-video bubbles fall back to a centered download affordance when only the preview/thumbnail is local.
- **Document rows now behave like real files:** downloaded document bubbles now open through Ability Kit `viewData`, instead of staying as download-only rows after the file becomes local.
- **Reference grounding:** this pass follows the Telegram iOS interactive media/file pattern where fetch/playback is surfaced through a prominent radial control, not a silent background transfer.
- **HarmonyOS grounding:** file opening remains on Ability Kit `startAbility` with `action = 'ohos.want.action.viewData'`, `uri`, `type`, and URI permission flags.
- **Build verification:** `powershell -ExecutionPolicy Bypass -File scripts/smoke-build.ps1` ✅ (`BUILD SUCCESSFUL`)
- **Verification status:** passed; historical regression checklist: no-repeat `downloadFile` logging for repeated taps, spinner/download states for voice/audio/document/video/videoNote bubbles, document open after download, and the reduced background-download footprint in voice/GIF/videoNote-heavy chats.

## Recent changes (2026-03-23, session 44)

### Visible blockquote rendering landed for live text bubbles
- Added explicit quote-entity plumbing for text messages (`quoteEntities`) through DTO -> AppState -> timeline VO.
- Added a new V2 atom `TgMessageTextBodyV2` for visible message-body quote blocks with a left accent bar and tinted quote surface.
- The live `text` branch now forwards quote ranges into `TgTextBubbleV2`, so blockquotes inside text-message bubbles are no longer invisible plain text.
- Scope is intentionally narrow: this pass targets **text-message body quotes** first; caption/entity parity for non-text families remains separate work.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the quote-body pass.

## Recent changes (2026-03-23, session 45)

### Media-caption blockquote parity landed for visual media family
- Reused explicit quote-entity plumbing for caption-bearing messages by parsing caption quote entities into `MessageContentDto`.
- `ChatTimelineVO` now derives dedicated caption quote ranges for non-text messages.
- `TgMediaBubbleShellV2` now routes quoted captions through `TgMessageTextBodyV2`, so blockquotes are visible in `photo` / `photoAlbum` / `video` / `animation` captions instead of being flattened into plain text.
- Scope stays narrow on the visual-media family; document/audio/voice caption parity remains separate work.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the media-caption pass.

## Recent changes (2026-03-23, session 46)

### Quote block height/tint pass aligned closer to Telegram iOS refs
- Rechecked the live quote rendering against the local iOS refs (`ChatMessageTextBubbleContentNode.swift`, `StringWithAppliedEntities.swift`, `TextNode.swift`) after user feedback that the quote blocks were too tall and too uniformly blue.
- Tightened the quote block geometry in `TgMessageTextBodyV2`: reduced vertical/horizontal paddings, reduced inter-segment gap, and replaced the earlier overlay-style bar layout with a tighter in-flow row so the accent bar stops inflating block height.
- Added `quoteAccentHex` support to `TgMessageTextBodyV2` and now pass sender-derived accent color from `TgTextBubbleV2` and `TgMediaBubbleShellV2` for incoming group messages, matching the iOS pattern where blockquote tint follows `mainColor` rather than a single hardcoded blue.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the quote-height/tint pass.

## Recent changes (2026-03-23, session 47)

### Quote text wrapping / meta coexistence pass
- Rechecked the quoted-bubble wrapping behavior against the local iOS text-bubble refs after noticing that quoted messages were still taller because meta/time always dropped to a dedicated extra row.
- `TgMessageTextBodyV2` now accepts `metaReserveText` and applies the invisible trailing reserve on the **final** plain or quoted segment, so quote bodies can keep Telegram-style bottom-right meta overlay behavior instead of always forcing a separate meta line.
- `TgTextBubbleV2` and quoted-caption mode in `TgMediaBubbleShellV2` now use the same overlay-meta pattern for quote content, reducing extra height and bringing line-wrapping behavior closer to the plain-text path.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the quote/meta wrapping pass.

## Recent changes (2026-03-23, session 48)

### Reply snippet quote path tightened and sender-tinted
- After re-auditing the live quote issue, the remaining visible mismatch turned out to be strongly tied to `TgReplySnippet`, not only the message-body quote renderer.
- Tightened `TgReplySnippet` geometry (smaller min height, vertical padding, bar gap, and thumbnail size) so quoted reply blocks stop inflating bubble height as much.
- Added `accentHex` support to `TgReplySnippet` and now pass sender-derived accent color from `TgTextBubbleV2`, `TgMediaBubbleShellV2`, and router-owned fallback branches, so incoming group-message reply snippets no longer stay on a universal blue accent.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the reply-snippet pass.

## Recent changes (2026-03-23, session 49)

### Reply snippet accent bar no longer stretches to full snippet height
- After the user pointed out that the colored stripe itself was still inflating quote height, `TgReplySnippet` was rechecked and the bar was indeed still using `height('100%')`.
- Replaced that full-height behavior with a content-sized bar height derived from the title/preview line-height contract, and removed the snippet min-height constraint from the outer layout so the snippet can collapse closer to its real text content.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the bar-height pass.

## Recent changes (2026-03-23, session 50)

### Quote stripe now sits flush to the quote/reply block edge + sender palette aligned closer to iOS defaults
- Rechecked the local iOS reply/text refs after the user pointed out that the colored stripe should touch the quote block edge rather than float inset from it.
- `TgReplySnippet` now overlays its accent stripe flush to the left edge of the snippet surface and shifts only the text content inward.
- `TgMessageTextBodyV2` quote blocks now use the same flush-edge stripe treatment for body blockquotes.
- Replaced the local fallback sender-name palette in `ChatTimelineVO` with the closer Telegram iOS default set from `PeerNameColors.defaultSingleColors`.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the stripe-edge/palette pass.

## Recent changes (2026-03-23, session 51)

### Sender/reply accent source now follows TDLib peer accent ids instead of senderId hashing
- Rechecked the local iOS and Android refs after the user pointed out that Telegram appears to source peer colors from protocol data rather than from a local hash.
- Added `accentColorId` to the local `User` / `Chat` state and DTO flow, and now parse `accent_color_id` from TDLib user/chat objects in the normalizers/DTOs.
- `ChatNormalizer` now also listens for `updateChatAccentColors` so chat-level accent changes can refresh the store after initial chat creation.
- `ChatTimelineVO` no longer derives `senderColorHex` from `senderId % palette.length`; it now prefers the TDLib-backed `accentColorId` from the real sender peer (`User` or `Chat`) and only falls back to the default Telegram palette when the runtime does not yet have a peer accent id.
- Scope stays intentionally narrow: this pass fixes the **source of sender/reply/quote accent colors** without yet implementing the full dynamic TDLib accent-color table for premium/custom colors.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the peer-accent-source pass.

## Recent changes (2026-03-23, session 52)

### Global accent-color registry landed (`updateAccentColors`) and sender color resolution now understands custom ids
- Continued the peer-color work beyond per-peer `accent_color_id` fields by adding a real global accent-color registry to app state.
- Added a new DTO/event/reducer path for `updateAccentColors`, storing TDLib `accentColor` objects (`id`, `built_in_accent_color_id`, light/dark theme colors, minimum boost level) in `AppState.accentColors`.
- `EventNormalizer` now registers a dedicated `AccentColorNormalizer`, and `appReducer` routes `accentColorsUpdated` into a new `accentColorsReducer`.
- `ChatTimelineVO` now resolves sender/reply/quote accent color in this order:
  1. built-in ids `0...6`,
  2. TDLib custom accent entry -> `built_in_accent_color_id` when present (preferred for one-color UI surfaces like sender names and reply stripes),
  3. exact TDLib theme color (`dark_theme_colors[0]`, then `light_theme_colors[0]`) as fallback,
  4. old local palette only when no runtime accent data exists.
- Also hardened user/chat parsing so a missing `accent_color_id` no longer silently becomes built-in color `0`.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the global accent-color resolver pass.

## Recent changes (2026-03-23, session 53)

### Reply snippet accent now follows the quoted author, not the current message author
- Rechecked the local iOS reply reference after the user pointed out that the color in the quote/reply block should follow the **quoted peer**, not the person sending the current message.
- `ChatTimelineVO` now derives a dedicated `replyAuthorColorHex` from the replied message sender, separate from the current message's `senderColorHex`.
- `TgTextBubbleV2`, `TgMediaBubbleShellV2`, and the remaining router-owned reply-snippet branches now pass `replyAuthorColorHex` into `TgReplySnippet`, so the snippet stripe/title/tint follow the cited author instead of the citer.
- `ChatTimelineDataSource` equality now includes `replyAuthorColorHex`, so same-order timeline rows repaint when the replied peer color becomes available later.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the quoted-author-color fix.

## Recent changes (2026-03-23, session 54)

### Body blockquote stripe now reaches the quote surface edges and is slightly thicker
- Rechecked the live quote-body geometry after the user pointed out that the colored stripe still looked too narrow and did not visually reach the rounded quote-block edges.
- `TgMessageTextBodyV2` no longer pads the whole quote container around the stripe. Instead, the stripe now sits as a full-height left-edge layer inside the clipped rounded quote surface, while only the text content receives inner padding.
- Increased `MSG_QUOTE_BAR_WIDTH` from `3vp` to `4vp` so the stripe reads closer to other Telegram clients.
- Result: the quote stripe now visually reaches the top/bottom edges of the rounded quote area instead of floating shorter inside it.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the quote-stripe geometry pass.

## Recent changes (2026-03-23, session 55)

### Media-caption quote path now uses the same width contract as regular captions
- Rechecked the media-bubble quote-caption path against the local media refs after the user reported that quoted captions inside image/video bubbles looked centered and had larger edge insets than plain text bubbles.
- Root cause: the quoted-caption branch in `TgMediaBubbleShellV2` had drifted to `width('100%')`, while the regular caption branch uses `visualMediaBubbleWidth()`. That meant the quote-caption container expanded to the wider shell width instead of the actual media-bubble width.
- Fixed the contract by making the quoted-caption container use `visualMediaBubbleWidth()` as well, so quote captions and normal captions share the same horizontal foundation inside media bubbles.
- This was a structural width-contract fix, not another padding tweak.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the media-caption width pass.

## Recent changes (2026-03-23, session 56)

### Reply-snippet stripe now matches the full-surface quote-line contract
- After the user insisted that all quote/reply variants should behave the same, the remaining mismatch was narrowed to `TgReplySnippet`: its accent stripe still used a content-sized height while the body blockquote stripe already filled the clipped rounded surface.
- `TgReplySnippet` now uses the same structural rule as body blockquotes: the accent stripe is a flush-edge left layer with `height('100%')`, relying on the snippet's own rounded clipping instead of a shorter content-sized bar.
- Increased `REPLY_SNIPPET_BAR_WIDTH` from `2` to `4` earlier in the pass chain, so reply snippets and body blockquotes now read from the same left-edge accent system instead of two separate stripe treatments.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the reply-snippet stripe unification pass.

## Recent changes (2026-03-23, session 57)

### Quote/reply surface geometry now shares one token contract across body quotes and reply snippets
- After the user asked to align all quote variants globally, the remaining drift was not only stripe height but the fact that `TgReplySnippet` still used its own softer surface geometry/tint contract while body blockquotes used `MSG_QUOTE_*` tokens.
- `TgReplySnippet` now reuses the same surface geometry tokens as body blockquotes for horizontal padding, vertical padding, stripe width, stripe gap, radius, and fallback tint, instead of keeping a separate reply-only quote shell.
- Result: reply snippets and body quote blocks now share the same structural left-edge quote surface contract; only their text content model remains different (author + preview vs quoted body text).
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the quote-surface unification pass.

## Recent changes (2026-03-23, session 58)

### Reply-snippet full-height stripe no longer dictates snippet height
- After the user reported that quote height had returned, the issue was narrowed to the `TgReplySnippet` accent stripe: it was full-height again, but unlike the body quote path it still participated in layout sizing.
- Kept the stripe on the required full-surface-height contract, but made it a positioned overlay layer inside the snippet `Stack` (`.position({ x: 0, y: 0 })`) so it no longer dictates the snippet's measured height.
- Result: the stripe still fills the clipped rounded reply surface, but the snippet height is again driven by content instead of by the accent bar layer.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the positioned-stripe pass.

## Recent changes (2026-03-23, session 59)

### Live group-reply path clarified and reply-snippet text density tightened
- Rechecked the real runtime path for the user's group-chat case. Normal participant-to-participant replies in text bubbles flow through `TgMessageRouter -> TgTextBubbleV2 -> TgReplySnippet`; media replies use `TgMediaBubbleShellV2 -> TgReplySnippet`, while non-visual media and composer have separate caller paths.
- The remaining visible height in the live group-text path was no longer the stripe itself but the reply-snippet text density contract.
- Tightened `TgReplySnippet` vertically by reducing `REPLY_SNIPPET_PADDING_V` from `4` to `3` and `REPLY_SNIPPET_TEXT_GAP` from `2` to `0`, bringing the compact reply block closer to the iOS `spacing=2 / textInsets.top-bottom=3` rhythm.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the density pass.

## Recent changes (2026-03-23, session 60)

### `TgReplySnippet` layout model switched from `Stack` overlay to content-driven `Row`
- The previous assumption that the remaining height issue was only a spacing/token problem turned out to be too weak. For the live group-reply path, the safer fix was to change the snippet layout model itself.
- `TgReplySnippet` no longer composes the accent stripe and content through a `Stack`; it now uses a single content-driven `Row` where the stripe is a dedicated left child and the text/thumbnail block is the weighted right child.
- This keeps the stripe flush-left and full-height, but makes the overall snippet height follow the content row instead of the older overlay-style composition.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the `Row` layout-model pass.

## Recent changes (2026-03-23, session 61)

### Parent spacing in the live group-text reply path reduced (`TgTextBubbleV2`)
- After confirming that the user was looking at ordinary group-text replies, the next remaining height source was moved one level up from `TgReplySnippet` to its caller path.
- In the live text-reply branch (`TgMessageRouter -> TgTextBubbleV2 -> TgReplySnippet`), `TgTextBubbleV2` no longer adds an extra bottom margin under the snippet, and the bubble's top/bottom padding is reduced from the generic bubble value to `4vp` whenever a reply snippet is present.
- This is intentionally caller-path-specific: it reduces the vertical frame around the reply block in the actual text-message runtime path instead of continuing to overfit the snippet internals.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the caller-spacing pass.

## Recent changes (2026-03-23, session 62)

### Quote stripe now uses content-driven measurement again, with a thicker shared bar
- After the user correctly identified that the height regression started when the stripe was pushed edge-to-edge, the reply-snippet quote surface was rebuilt so measurement and decoration are separated again.
- `TgReplySnippet` now uses a content-measuring base row (with background/radius/clip) plus a separate positioned overlay stripe, so the stripe can still visually run edge-to-edge without being the thing that measures the block height.
- Increased the shared quote-stripe width from `4` to `5`, so both body blockquotes and reply snippets now get the requested extra pixel of thickness from the same token source.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the structural quote-measurement fix.

## Recent changes (2026-03-23, session 63)

### Reply-snippet stripe now follows content height instead of the full quote surface
- After the user clarified that the quote area itself was finally compact but the stripe still spanned the entire surface height, the fix was narrowed to the stripe contract alone.
- `TgReplySnippet` now uses an explicit `barHeight()` again and positions the stripe at `y = REPLY_SNIPPET_PADDING_V`, so the stripe follows the title/preview content block rather than the full rounded surface height.
- This keeps the compact quote area intact while removing the last full-height stripe behavior the user called out.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅ after the content-height stripe pass.

## Recent changes (2026-03-23, session 64)

### Android-grounded reply stripe contract fix
- Re-checked the reply-line geometry against the local Android reference (`рефенсы/telegram-android/TMessagesProj/src/main/java/org/telegram/ui/Components/ReplyMessageLine.java` and `ChatMessageCell.java`).
- The Android path draws the reply background first and then draws the colored line **inside the same reply rect**, clipped to that surface, rather than as an external lane.
- `TgReplySnippet` now matches that structural contract more closely: the rounded/tinted surface moved to the root `Stack`, while the colored stripe is drawn as an overlay **inside** that clipped surface (`height('100%')`, `x: 0`, `y: 0`).
- This keeps the line visually part of the quote/reply area while preserving the content-driven measurement path from the main content row.
- Verification: `scripts/smoke-ui-phase0.ps1` ✅ and `scripts/smoke-build.ps1` ✅.
- Follow-up correction: moving the reply-surface ownership to the root `Stack` brought the height regression back in live group replies. The implementation was narrowed again so the content row owns the tinted/clipped surface while the stripe remains an overlay aligned to the inner quote area (`barHeight()` + top inset). This preserves the compact height that had already been recovered.

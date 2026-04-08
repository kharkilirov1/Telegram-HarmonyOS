# TODO — observed current work

Last updated: 2026-04-08

This is a **working snapshot**, not a product roadmap. It is derived from:
- current git status on branch `dev`
- current repo docs
- current file layout
- user-confirmed verification state for the current branch

Canonical execution order for agents now lives in:
- `TASKS/AGENT_EXECUTION_PLAN.md`

## Fresh snapshot (2026-04-08)

### TgChatRow typing accent + Composer edit mode — completed
- **Goal:** wire remaining Telegram-semantic gaps in chat row and composer.
- **Status:** completed this session:
  - `TgChatRow`: typing preview now renders in activity accent color (`telegram_blue`) instead of default gray — follows Android Telegram pattern for visible typing distinction
  - `TgComposerInput`: added edit mode snippet bar (`showEditSnippet`, `editPreview`, `onEditCancelPress`) — shows "Edit Message" header with original text preview and cancel button, matching reply snippet pattern
  - `TgChatScreenPage`: wired `isEditingMessage` / `editingOriginalText` / `cancelEditMessage` into composer's new edit params
  - Updated demo: `TgComposerInputDemo.ets` now includes case 05 (edit mode snippet)
  - Updated specs: `TgChatRow.md` (typing accent documented), `TgComposerInput.md` (edit params + state)
- **Verification:** `scripts/smoke-ui-phase0.ps1` pass
- **Next action:** continue queue — composer forward mode or further row states (scam/fake/secret badges)

### TgChatRow mention badge — full pipeline — completed
- **Goal:** surface unread mention count as a dedicated "@" badge in chat list rows.
- **Status:** completed this session:
  - `Chat` model: added `unreadMentionCount` field
  - `chatsReducer`: wires `unreadMentionCount` from DTO on newChat and chatUpdated
  - `cloneChat`: copies `unreadMentionCount`
  - `ChatItemVO`: added `hasMention` field, derived from `chat.unreadMentionCount > 0`
  - `ChatListDataSource.isSameChatRow`: includes `hasMention` in equality check
  - `TgChatMeta`: added `hasMention` param + `buildMentionBadge()` — "@" circle badge (20vp), same colors as unread badge, appears left of unread count or standalone
  - `TgChatRow`: added `hasMention` param, passes through to TgChatMeta
  - `ChatListPage`: wires `hasMention` from ChatItemVO to TgChatRow
  - Tokens: `CHAT_META_MENTION_BADGE_SIZE`, `CHAT_META_MENTION_FONT_SIZE`, `CHAT_META_BADGE_GAP`
- **Data pipeline:** TDLib `updateChatUnreadMentionCount` → ChatNormalizer (already existed) → ChatUpdateDto → chatsReducer → Chat model → ChatItemVO → TgChatRow → TgChatMeta
- **Verification:** `scripts/smoke-ui-phase0.ps1` pass
- **Next action:** composer forward mode

### Secret chat indicator — full pipeline — completed
- **Goal:** visually distinguish secret chats with green lock icon + green title in chat list.
- **Status:** completed this session:
  - `ChatType` union: added `'secret'` to AppState + `SECRET` to DTO enum
  - `ChatDto`: `chatTypeSecret` now maps to `SECRET` instead of being merged with `PRIVATE`
  - `chatsReducer.mapChatType`: added `SECRET → 'secret'`
  - `ChatItemVO`: added `isSecret`, derived from `chat.type === 'secret'`
  - `TgChatRow`: lock icon (green, `secret_green`) before title text + green title color for secret chats
  - Fixed `type === 'private'` guards in `TgProfilePage` and `ChatTimelineVO` to also match `'secret'`
  - Tokens: `CHAT_ROW_SECRET_ICON_SIZE`, `ICON_RES_LOCK`, `COLOR_SECRET_CHAT`
- **Verification:** `scripts/smoke-ui-phase0.ps1` pass

### TgChatRow scam/fake badges — full pipeline — completed
- **Goal:** surface TDLib `is_scam`/`is_fake` user flags as red warning labels in chat list rows.
- **Status:** completed this session:
  - `UserDto`: added `isScam`/`isFake` fields + extraction via `tdGetBoolean` + update/clone support
  - `User` model (AppState): added `isScam`/`isFake`
  - `usersReducer`: applies on newUser + partialUpdate
  - `cloneUser`: copies both flags
  - `ChatItemVO`: derives from user for private chats
  - `TgChatRow`: `buildScamFakeBadge()` — red outlined "SCAM"/"FAKE" label, replaces verified badge
  - Tokens: `CHAT_ROW_SCAM_FONT_SIZE`, `CHAT_ROW_SCAM_RADIUS`, `CHAT_ROW_SCAM_PADDING_H`
- **Verification:** `scripts/smoke-ui-phase0.ps1` pass

## Previous snapshot (2026-04-05)

### Text engine stabilization pass — completed
- **Goal:** remove the most dangerous gaps in the live V3 text path before calling the engine “good enough” for broader message-surface work.
- **Status:** completed this session:
  - hard line breaks are preserved in `Segmenter.normalizeWhitespace()`
  - outgoing `Failed` state now reserves meta width in the engine-driven layout path
  - `computeTextBubbleLayout()` now includes quote-segment geometry instead of treating quotes like plain text-only layout
  - `TgTextBodyV3` quote ranges are now clamped/sorted/merged
  - added `TgTextBubbleV3` spec + demo coverage
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Immediate next action:** visually re-check the live chat text path on device/emulator, especially:
  1. multiline `\n` messages,
  2. outgoing failed bubbles,
  3. quoted bubbles with inline vs row meta,
  4. sender + reply + quote combinations in narrow widths.

### Remaining text-engine follow-up
- **Still missing:** a true Telegram entity/span pipeline for mixed styles and interactive text.
- **Safer next slice:** keep the next text pass narrow:
  - evaluate whether `TgTextBubbleV3` should become the only text spec source of truth,
  - then decide whether to migrate quote/reply body rendering onto `StyledString`/span-based text or keep the current segmented composition.

### Bubble time alignment pass — completed
- **Goal:** stop letting time/status drift in shrink-wrapped non-text bubble variants.
- **Status:** completed this session:
  - `TgMessageRouter` no longer uses generic `width('100%')` footer rows for `sticker`, `contact`, `location`, `poll`, and non-visual `document` message branches
  - those branches now right-anchor the footer meta with `alignSelf(ItemAlign.End)`
  - `sticker` now uses bottom-right overlay meta instead of a detached row below the sticker
  - `location` without venue info now uses bottom-right overlay meta on the map surface; venue cards keep the trailing footer row
  - `TgMessageRouter` spec was synced to the live V3 text path and the new footer-meta rule
  - added `TgMessageTimeContractDemo.ets` for focused manual verification across the remaining message families
- **Reference grounding:** local Telegram iOS refs (`ChatMessageAttachedContentNode`, `ChatMessageMapBubbleContentNode`, `ChatMessagePollBubbleContentNode`, `ChatMessageAnimatedStickerItemNode`) keep date/status trailing the real rendered content instead of relying on a generic stretch footer.
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Immediate next action:** visually re-check real rows for sticker / contact / location / poll / document bubbles on device/emulator to confirm:
  1. sticker overlay stays anchored to the rendered sticker bounds,
  2. plain map/location messages overlay in the lower-right corner,
  3. venue/location cards still keep the footer cluster inside the bubble width,
  4. contact/poll/document footer meta no longer drifts in outgoing narrow-width cases.

## Current housekeeping focus

> Verification sync note (2026-03-22): per user confirmation, the emulator/device/runtime verification passes referenced below should be treated as **passed** for the current branch state. Historical verification blocks are kept as regression checklists, not as active blockers.

### 0am. Strategic refocus: less manual shell chrome, more Telegram semantics (2026-03-22)
- **Goal:** stop spending disproportionate effort on hand-built shell/chrome surfaces that the platform is now increasingly capable of carrying natively or in hybrid form.
- **Status:** accepted this session as the new strategic direction.
- **Current rule:**
  - keep custom focus on Telegram-defining UI (`TgChatRow`, message atoms, composer semantics, meta/badge/status logic),
  - treat shell containers (`TgTabBar`, upper chrome hosts, search hosts) as native/hybrid candidates first,
  - keep API 22 fallbacks while the repo still targets API 22.
- **Immediate next action:** future parity work should prioritize Telegram-specific surfaces and state contracts over further manual polishing of shell glass/island chrome.

### 0an. New practical queue after the shell-chrome refocus (2026-03-22)
- **Goal:** give the repo a concrete next-work order that matches the new strategy instead of drifting back into shell-only polish.
- **Working order from here:**
  1. **`TgChatTopBar` state contract**
     - enrich title/subtitle semantics before adding more shell visuals,
     - focus on Telegram-specific states: member count, typing/activity, custom subtitle/title modes, and other chat-title semantics that are not platform-owned.
  2. **`TgChatRow` completeness audit**
     - verify remaining Telegram-specific row states against the local refs/spec,
     - prioritize hierarchy/content correctness over micro glass polish.
  3. **Composer semantics**
     - keep `TgComposerInput` visually stable and invest in Telegram behavior/state instead of shell cosmetics,
     - future focus: reply/edit/forward/accessory behavior and other Telegram input semantics.
  4. **Message-surface parity**
     - continue on message atoms / `TgMessageRouter` where Telegram identity is strongest,
     - treat this as higher-value than more tab-bar or generic top-bar hand-polish.
  5. **Only after that:** native/hybrid shell audit
     - revisit `TgTabBar`, upper chrome hosts, and search hosts with API 23 direction in mind,
     - do not reopen large shell rewrites while API 22 remains the active target.
- **De-prioritized by this queue:**
  - more manual tab-bar island polishing,
  - more blind glass/material tuning for upper chrome,
  - shell-only parity passes that do not improve Telegram semantics.

### 0ao. `TgChatTopBar` state contract pass (2026-03-22)
- **Goal:** move the next top-bar iteration from shell visuals to Telegram chat-title semantics.
- **Status:** completed this session for the first contract expansion:
  - `TgChatTopBar` now renders explicit subtitle modes (`secondary` / `online` / `activity`)
  - `TgChatScreenPage` derives those modes from real chat state instead of only toggling `isOnline`
  - typing/actions now override the subtitle with richer Telegram-style activity text, and group chats prefix the acting user's first name/username when known
- **Next action:** do not reopen capsule glass tuning first; the next meaningful chat-top-bar step should be broader state coverage (custom title/subtitle modes, accessory/title-panel semantics, search/back-badge only when product scope requires them).

### 0ap. `TgChatRow` completeness audit — verified title badge (2026-03-22)
- **Goal:** continue the queue on Telegram-defining chat-list semantics instead of drifting back into shell polish.
- **Status:** completed this session for one narrow, high-signal row state:
  - private verified peers now surface a compact title badge in `TgChatRow`
  - the live chat-list mapping (`ChatItemVO` -> `ChatListPage` -> `TgChatRow`) carries `isVerified`
  - `ChatListDataSource` equality now refreshes same-order rows when the verified flag changes
- **Next action:** keep the audit narrow; the next likely row-semantic candidates are mention/unread-special states or other title-side Telegram badges only if their data path is already available and they materially improve chat-list fidelity.

### 0aq. Composer semantics — reply strip integration cleanup (2026-03-22)
- **Goal:** stop keeping reply semantics split between the chat screen and the composer atom.
- **Status:** completed this session:
  - the live reply strip is now rendered by `TgComposerInput` instead of a duplicate `TgChatScreenPage.buildReplyBar()`
  - `TgChatScreenPage` passes screen-owned reply state directly into the atom
  - `TgComposerInput` now owns the trailing cancel affordance and emits `onReplyCancelPress()`
- **Next action:** keep composer work focused on Telegram semantics (edit/forward/accessory behavior) rather than more glass polish.

### 0ar. Message-surface parity — richer reply preview semantics (2026-03-22)
- **Goal:** improve the shared reply snippet contract in real chats before doing more shell/chrome work.
- **Status:** completed this session:
  - timeline rows now derive user-facing media reply labels instead of generic unsupported/internal type strings,
  - photo/video/animation/videoNote replies can now carry a thumbnail into `TgReplySnippet`,
  - `TgMessageRouter` forwards `replyHasThumbnail` / `replyThumbnailSrc`,
  - `TgChatScreenPage` action-menu reply flow now uses the same richer media labels/names.
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** if the build passes, continue the queue on the next message-surface gap instead of reopening shell polish.

### 0as. Parallel text-surface rebuild — `TgTextBubbleV2` atom/demo/spec (2026-03-23)
- **Goal:** start the controlled message-surface reset with a parallel text-family atom before touching the live router path.
- **Status:** completed this session:
  - added `TgTextBubbleV2.ets`
  - added `TgTextBubbleV2.md`
  - added `TgTextBubbleV2Demo.ets`
  - scoped the atom to sender + reply + text + inline meta + grouped corners only
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** do a narrow runtime swap for the text branch only (old path remains fallback), then continue with media-shell extraction after the text path is visually accepted.

### 0at. Narrow live text-path swap onto `TgTextBubbleV2` (2026-03-23)
- **Goal:** move the partial reset from demo-only into the real runtime with the smallest safe integration step.
- **Status:** completed this session:
  - `TgMessageRouter` now uses `TgTextBubbleV2` for the live `text` branch
  - avatar lane remains router-owned
  - media/document/voice/sticker paths remain unchanged
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** visually evaluate the live text path; if it holds, continue with media-shell extraction rather than broad router surgery.

### 0au. Parallel visual-media shell rebuild + narrow live swap (2026-03-23)
- **Goal:** extract shared visual-media layout rules out of `TgMessageRouter` without reopening document/audio/voice branches.
- **Status:** completed this session:
  - added `TgMediaBubbleShellV2.ets`
  - added `TgMediaBubbleShellV2.md`
  - added `TgMediaBubbleShellV2Demo.ets`
  - moved the live `photo` / `photoAlbum` / `video` / `animation` branches onto the new shell
- **Kept intentionally unchanged:**
  - avatar lane ownership in the router,
  - `videoNote` dedicated round path,
  - document/audio/voice/sticker paths
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** continue the message-surface reset with non-visual media/router cleanup or grouping polish instead of touching shell chrome.

### 0av. Quote semantics cleanup — explicit reply quote contract (2026-03-23)
- **Goal:** stop faking quote mode from preview length and move reply quotes onto an explicit data contract.
- **Status:** completed this session:
  - added `replyIsQuote`, `replyQuoteText`, and `replyQuoteOffset` to message/DTO flow

### 0ay. Quote block height/tint parity pass (2026-03-23)
- **Goal:** bring the new visible quote blocks closer to Telegram iOS after real-user inspection flagged excess height and an over-generic blue tint.
- **Status:** completed this session:
  - tightened `TgMessageTextBodyV2` quote geometry (smaller paddings + smaller segment gap),
  - removed the older overlay-style accent-bar layout that was adding vertical bulk,
  - added `quoteAccentHex` so incoming group-message quotes can inherit sender-name color instead of always using one blue fallback.
- **Reference grounding:** local iOS refs show blockquote tint is driven from `baseQuoteTintColor = mainColor`, and in incoming group-message paths `mainColor` can be `authorNameColor`.
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** visually re-check on real chat history; if quote height still feels off, the next narrow fix should target quote/meta coexistence rather than reopening the whole bubble family.

### 0az. Quote/meta line-wrapping parity pass (2026-03-23)
- **Goal:** stop forcing quoted bubbles onto an extra dedicated meta row and bring their line wrapping closer to the normal Telegram text-bubble path.
- **Status:** completed this session:
  - `TgMessageTextBodyV2` now accepts `metaReserveText` and applies the transparent trailing reserve to the final visible segment,
  - quoted text bubbles now use bottom-right overlay meta again instead of always rendering a separate meta row,
  - quoted visual-media captions now use the same reserve + overlay pattern.
- **Reference grounding:** in Telegram iOS, trailing date/status measurement for text bubbles is special-cased for the last segment and differs from a naive “always put meta on the next row” layout.
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** re-check on device/emulator whether quoted last-line behavior now looks close enough; if not, the next narrow target is trailing-width heuristics for quoted last segments rather than more global bubble surgery.

### 0ba. Reply snippet quote path parity pass (2026-03-23)
- **Goal:** fix the remaining quote-looking drift that still came from the reply snippet path rather than the message-body quote renderer.
- **Status:** completed this session:
  - tightened `TgReplySnippet` geometry,
  - added `accentHex` so reply snippet title/bar/background can follow sender accent instead of always staying blue,
  - wired that accent through the text bubble, media shell, and router-owned fallback branches.
- **Reference grounding:** local `ChatMessageReplyInfoNode.swift` computes reply title/main colors from bubble context and author name color where available, so a hardcoded blue reply snippet is not faithful to Telegram iOS.
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** visually re-check live quoted replies; if the user still sees no change, inspect actual runtime messages for whether they are reply snippets, body blockquotes, or both.

### 0bb. Reply snippet accent bar height correction (2026-03-23)
- **Goal:** stop the colored reply-snippet stripe from stretching to the full snippet container height.
- **Status:** completed this session:
  - removed `height('100%')` from the snippet accent bar,
  - replaced it with a content-sized height derived from title/preview line heights,
  - removed the outer min-height constraint so the snippet can follow text content more closely.
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** visually re-check on a real quoted message; if the snippet is still too tall, the next narrow target is title/preview line-count policy rather than another generic spacing pass.

### 0bc. Quote stripe edge alignment + sender palette sync (2026-03-23)
- **Goal:** align the colored stripe behavior and sender name palette more closely with Telegram iOS.
- **Status:** completed this session:
  - moved the reply-snippet stripe to the left edge of the quote surface instead of leaving it inset,
  - applied the same flush-edge idea to body quote blocks,
  - replaced the local sender-name fallback palette with the closer `PeerNameColors.defaultSingleColors` values from the iOS reference set.
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** visually re-check whether the overall sender accent family now feels closer to iPhone; if not, the next pass should target mapping/order, not arbitrary hue guessing.
  - added best-effort TDLib `reply_to` parsing for quote fields
  - `ChatTimelineVO` now prefers explicit quote text and passes explicit quote mode to UI
  - `TgChatScreenPage` now keeps explicit composer `replyToIsQuote` state
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** real quote production is still missing; the next meaningful step is to add a true quote producer (for example selected-text reply) instead of adding more heuristics.

### 0af. Live shell parity touch-up after V2 stabilization (2026-03-22)
- **Goal:** close small but visible drift in the highest-frequency shell controls after the migration was declared complete.
- **Status:** completed this session for two concrete regressions:
  - `TgTabBar` live typography was restored to the accepted contract (`12vp` label text, `Bold` selected label)
  - `TgComposerInput` now uses ArkUI inline text style again, matching the custom glass-capsule contract instead of fighting it with default text-box behavior
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** if device screenshots still show drift, continue with a reference-side-by-side pass on `TgChatRow` / `TgChatTopBar` rather than broad shell rewrites.

### 0ag. Reference-side parity pass — `TgChatRow` / `TgChatTopBar` (2026-03-22)
- **Goal:** close the highest-confidence visual deltas that are already documented in the local iOS comparison notes.
- **Status:** completed this session for the safest narrow corrections:
  - `TgChatRow` avatar-to-text lane tightened (`12vp -> 8vp`) and separator inset nudged closer to the iOS start position
  - `TgChatTopBar` title weight moved closer to iOS semibold (`Bold -> Medium` approximation) and avatar inner size aligned to the 38pt reference
- **Verification:** run `scripts/smoke-ui-phase0.ps1` and `scripts/smoke-build.ps1` after the token pass; if screenshots still show drift, the next step is screenshot-based optical tuning rather than further blind token edits.

### 0ah. Pre-test parity check — `TgChatListNavigationBar` title weight (2026-03-22)
- **Goal:** inspect the live Chats list top bar before the next test and only correct high-confidence typography drift.
- **Status:** completed this session: local iOS header sources show a `17pt semibold` centered title, so the Harmony atom now uses tokenized `Medium` instead of a heavier bold title.
- **Scope intentionally kept narrow:** no structural changes to the integrated search lane, safe-area handling, or action slots.

### 0ai. Upper chrome V2 architecture pass (2026-03-22)
- **Goal:** stop treating top bars as standalone widgets and fix the target architecture before deeper parity work.
- **Status:** completed as a design/assembly decision:
  - the canonical note is now `docs/ai/UPPER_CHROME_V2_ARCHITECTURE.md`
  - upper chrome is defined as `screen-owned derived state -> V2 composition component -> shared top background primitive`
  - `TgChatListNavigationBar` and `TgChatTopBar` are now explicitly treated as content compositions, not as complete effect engines
- **Next action:** when implementation work resumes, first introduce/extract the shared upper-background primitive, then adapt `TgChatListNavigationBar`, then rework `TgChatTopBar` around the same layered model.

### 0aj. Shared top chrome primitive extraction (2026-03-22)
- **Goal:** land the first runtime piece of the new upper-chrome architecture without reopening the whole top-bar system.
- **Status:** completed this session:
  - added `TgTopChromeBackground` as a new V2 atom
  - added `TgTopChromeBackgroundDemo.ets`
  - added `TgTopChromeBackground.md`
  - rewired `TgChatListNavigationBar` to render its content above the shared background primitive
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** adapt `TgChatTopBar` to the same shared-background model instead of keeping all blur/glass responsibility internal.

### 0ak. `TgChatTopBar` shared-background migration (2026-03-22)
- **Goal:** move the chat-screen top bar onto the same layered V2 upper-chrome model already introduced for the chat-list header.
- **Status:** completed this session:
  - `TgChatTopBar` now renders above `TgTopChromeBackground`
  - internal capsules remain as local control atoms, but the shared upper surface is no longer owned ad hoc by the top bar itself
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** start visual tuning on top of the new structure instead of refactoring background ownership again.

### 0al. `TgChatTopBar` optical mass reduction (2026-03-22)
- **Goal:** fix the remaining high-confidence “too heavy / too wide” feel of the chat-screen capsule cluster without expanding feature scope.
- **Status:** completed this session:
  - reduced title capsule minimum width and horizontal padding,
  - tightened the inter-capsule gap,
  - lightened the capsule border stroke.
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** if chat-screen screenshots still drift from iOS, continue with screenshot/device-guided optical tuning only; do **not** reopen structural ownership work.
- **What is still missing after this pass:** back unread-count badge, search button, and richer typing/activity subtitle states.

### 0ae. Post-V2 stabilization pass (2026-03-22)
- **Goal:** close the remaining low-grade drift after the completed `@ComponentV2` migration without reopening a broad architecture refactor.
- **Status:** completed this session for the highest-leverage obvious drift points: stale V1 migration assumptions were removed from current docs/specs, and the chat-list incremental diff path now refreshes draft/author-prefix and pinned-boundary changes correctly.
- **Next action:** if visual drift is still visible on device, do a targeted parity pass on specific live atoms (`TgChatRow`, `TgChatTopBar`, `TgTabBar`, `TgComposerInput`) instead of reopening migration work.

### 0ad. Repo/order cleanup after verification sync (2026-03-22)
- **Archive sync:** one-off repo-hygiene planning docs now live under `TASKS/ARCHIVE/` instead of cluttering the active task root.
- **Goal:** convert the repo from “implemented but under-documented” into a coherent post-verification baseline.
- **Current action:** docs/execution sync, archive move, and `PROJECT_ANALYSIS.md` promotion are done; remaining cleanup is opportunistic pruning of stale historical phrasing only.

### 0ac. Documentation reality-sync (2026-03-22)
- **Evidence:** core docs drifted from the actual tree: latest HEAD is `860e473` (not `511e6cb`), current `tg_ui` inventory is `32/2/34/37`, and the live Chats shell path is `TgTabBar -> TgChatListNavigationBar -> TgChatRow -> TgChatTopBar -> TgMessageRouter`, not `TgTopBar + TgSearchBar`.
- **Status:** completed this session for the main tracked docs. Root docs, execution docs, and deep sync headers were aligned with the real imports/scripts and current verification state.

### 0ab. Verified regression checklist — Phase 1 media gallery + inline video + GIF (2026-03-18)
- **Evidence:** commit `511e6cb` — TgMediaGalleryPage, TgInlineVideoView, TgAnimationBubble, MediaGalleryItem, integration into all bubble atoms + router + chat screen. BUILD SUCCESSFUL.
- **Historical regression checklist:** verify on device (CLEAN BUILD):
  1. Photo tap → gallery opens, pinch zoom works (1x-4x), double-tap toggle
  2. Swipe between photos in gallery
  3. Gallery swipe-down dismiss
  4. Short video (<=30s) auto-plays muted inline in bubble
  5. Short video tap → gallery with sound
  6. Long video shows thumbnail + play button, tap → gallery
  7. GIF auto-plays looping muted in bubble
  8. Video note tap → plays inline in circle with progress ring
  9. Video note second tap → gallery fullscreen
  10. Album cell tap → gallery at correct index
  11. Gallery shows download button for not-yet-downloaded media
  12. Max 3 inline videos — no crash on media-heavy chats
  13. No regression in download/progress indicator states
  14. Swipe between mixed media types in gallery (photo→video→GIF)
  15. All existing chat functionality unchanged (text, voice, audio, document)

### 0aa. Verified regression checklist — tab bar badge + selected-pill cleanup (2026-03-18)
- **Evidence:** `TgTabBar` no longer mutates `AppStorage` directly, the Chats tab now actually passes `showBadge = true`, the selected pill blur/border is driven by `selectedIndex` instead of a temporary timer-gated `pillGlassActive` flash, and the island now uses tab-specific glass colors/material tokens plus a subtler selected-vs-unselected content scale/opacity split.
- **Historical regression checklist:** verify on emulator/device:
  1. unread badge appears on the Chats tab when `totalUnread > 0`,
  2. badge clamps cleanly at `99+`,
  3. repeated fast tab switching does not produce stale glass flashes or selected-pill desync,
  4. tapping the already-selected tab still behaves normally and does not break `TabsController` state,
  5. tab selection continues to persist through the page-owned shell state only,
  6. light/dark tab bar material reads as a real glass capsule instead of an almost-invisible outline,
  7. selected tab content feels slightly stronger than unselected without looking over-animated.

### 0z. Verified regression checklist — full media playback + download pipeline (2026-03-16, session 8)
- **Evidence (visual):** `TgAudioBubble` — 44vp round circle (radius 22, iOS parity) with gradient `#51b4ff→#2b88d4`, download arrow on idle, play/pause/ring-progress on states, 4vp seek bar below performer. `TgInstantVideoBubble` — radial `Progress(Ring)` around circle, semi-transparent overlays. Voice button 40vp, waveform range 3-20vp.
- **Evidence (behavioral):** Critical `shouldReactToStoreChange` fix — `files.transfers` now triggers timeline rebuild → all download progress indicators visible. Unified `MediaPlaybackController` (voice+audio inline playback, auto-advance). Voice/GIF/VideoNote auto-download. `pendingFileIds` cleanup fix in downloadMessageMedia. FileNormalizer guard fix.
- **IMPORTANT:** Use **Clean Build** (Build → Clean Project → Build) to avoid DevEco cache.
- **Historical regression checklist:** verify on emulator/device (CLEAN BUILD):
  1. audio bubbles show gradient circle with download arrow (idle) → play (downloaded) → pause (playing),
  2. tapping audio plays inline (NOT opens external app),
  3. audio seek bar fills during playback,
  4. after one audio finishes, next audio auto-plays,
  5. download progress ring visible on art tile during audio/document download,
  6. voice messages auto-download on chat open (no manual tap needed),
  7. voice tap toggles play/pause with waveform color fill,
  8. after voice finishes, next voice auto-plays,
  9. video note circles show radial ring progress during download,
  10. video note / GIF / animation auto-download,
  11. document download shows progress bar,
  12. photo download shows progress overlay on bubble,
  9. all demo states render correctly in TgAudioBubbleDemo and TgInstantVideoBubbleDemo.

### 0y. Verified regression checklist — media transfer indicators + audio/file visual pass (2026-03-16)
- **Evidence:** store-level transfer state now exists (`AppState.files.transfers` + `fileTransferUpdated`), and transfer/progress props are wired through `ChatTimelineVO` → `TgMessageRouter` into `TgPhotoBubble`, `TgVideoBubble`, `TgInstantVideoBubble`, `TgDocumentRow`, `TgAudioBubble`, and `TgVoiceBubble`.
- **Historical regression checklist:** verify on emulator/device:
  1. single photo bubbles show a visible transfer overlay while the full photo is still downloading,
  2. video / GIF / instant-video bubbles show download spinner/percent instead of silently changing state,
  3. document rows now display real progress bar/percent instead of a static download affordance only,
  4. audio bubbles show download meta/progress and no longer look inert while waiting,
  5. voice bubbles expose download progress in the trailing label before playback is possible,
  6. re-evaluate after the new visual pass whether any remaining media drift is now concentrated in token tuning only.

### 0r. Verified regression checklist — bubble improvements: GIF, reply quotes, meta overlay, avatars (2026-03-14)
- **Evidence:** TgMessageRouter rewritten with avatar support, media sizing fix, tighter inline meta, media overlay tokens, regular-width bubble helper, and avatar-lane fallback logic. Rounded media/avatar/reply images now use `.clip(true)`. TgPhotoViewerPage + TgVideoPlayerPage added. Bubble colors aligned to iOS. overlayMode wired in TgMessageMeta.
- **Historical regression checklist:** device-check:
  1. Wider bubbles (0.85 ratio) — text and media fill more of screen width,
  2. Avatars appear left of incoming group messages (last in sender group),
  3. Avatar space stays reserved for all incoming group messages even before avatar photo hydration,
  4. GIFs auto-play without play button overlay,
  5. Reply quotes have subtle background tint plus top-right quote accent inside bubbles,
  6. Photo/video/avatar/reply thumbnail corners stay cleanly clipped (no square bleed),
  7. Photo/video without caption: time overlays on bottom-right dark pill with white text and no oversized empty width,
  8. Photo/video with caption: time below caption (normal style) and no overlap with trailing text,
  9. Photo tap opens fullscreen viewer with pinch-to-zoom,
  10. Video tap opens fullscreen player with controls,
  11. Bubble colors match iOS (outgoing green #E1FFC7, dark incoming #182533),
  12. On tablet/regular width chats, bubbles shrink to the iOS-style narrower lane instead of staying phone-wide.
  13. Media captions no longer lose the first characters on the left edge (especially channel/photo posts).
  14. Tall portrait photos fit fully inside the bubble instead of cropping the lower part.
  15. Bubble body/caption text now reads less oversized in HarmonyOS runtime after the 16/21 typography tightening.

### 0s. Verified regression checklist — grouped photo albums + voice playback path (2026-03-15)
- **Evidence:** `media_album_id` now flows through DTO/state/reducer, `ChatTimelineVO` collapses album clusters into `photoAlbum`, `TgGroupedPhotoBubble` renders the mosaic, and `TgMessageRouter` / `TgChatScreenPage` now drive real voice download+playback via `VoicePlaybackController`.
- **Historical regression checklist:** device-check:
  1. paired photos now render as one grouped bubble instead of two separate photo bubbles,
  2. 3-up / 4-up / `5+` album layouts look stable and clipped,
  3. tapping the `+N` overlay cell still opens the tapped photo,
  4. album caption/time layout still reads correctly under the grouped bubble,
  5. voice bubble shows download icon before file exists, then play/pause after download,
  6. voice playback starts from local file, pauses/resumes, and progress colors move across the waveform,
  7. listened-state styling stays correct after local playback,
  8. switching chats or reopening the same chat does not leave stale active voice state behind.

### 0t. Verified regression checklist — hardened media viewers (2026-03-15)
- **Evidence:** `TgChatScreenPage` no longer uses `bindContentCover` for photo/video viewing; fullscreen viewers are rendered as direct overlay layers in the root `Stack`. `TgVideoBubble` now opens on tap anywhere on the preview, not only on the center play button.
- **Historical regression checklist:** verify on emulator/device:
  1. tapping a photo bubble opens `TgPhotoViewerPage`,
  2. tapping an album cell opens the selected photo in the viewer,
  3. tapping a video bubble preview opens `TgVideoPlayerPage`,
  4. tapping a GIF/animation preview opens the viewer path again,
  5. dismiss/close returns cleanly to the chat without leaving a stale black overlay.

### 0u. Verified regression checklist — document bubbles + empty-bubble fallback fix (2026-03-15)
- **Evidence:** `TgDocumentRow` now renders a Telegram-style extension badge in the leading tile and allows a 2-line file title; `TgMessageRouter` now routes `unknown` / `location` / `contact` / `poll` through the text-fallback path instead of letting them fall into an empty visual shell.
- **Historical regression checklist:** verify on emulator/device:
  1. document/file bubbles show an extension badge (`PDF`, etc.) when not downloading,
  2. long file names wrap to two lines without breaking the meta row,
  3. download-progress document rows still show the progress state instead of the extension badge,
  4. previously blank bubbles now render fallback text for location/contact/poll/unknown content,
  5. no new width/alignment regression appeared in file bubbles after the leading-tile change.

### 0v. Verified regression checklist — voice bubble meta alignment fix (2026-03-15)
- **Evidence:** `TgUiTokens.resolveVoiceBubbleWidth(...)` now drives both `TgVoiceBubble` and `TgMessageRouter`, and the router no longer uses a generic `width('100%')` meta row for voice messages.
- **Historical regression checklist:** verify on emulator/device:
  1. time/status stays inside outgoing voice bubbles,
  2. time/status stays inside incoming voice bubbles,
  3. short voice messages do not push time off the right edge,
  4. long voice messages still keep the time cluster aligned to the bubble body,
  5. group-chat voice messages with sender name / reply snippet do not reintroduce width drift.

### 0w. Verified regression checklist — channel bubble width / wrap parity pass (2026-03-15)
- **Evidence:** channel posts no longer reserve the hidden group avatar lane, and text/caption paths now use `lineBreakStrategy(LineBreakStrategy.HIGH_QUALITY)` in addition to the existing word-break rules.
- **Historical regression checklist:** verify on emulator/device:
  1. incoming channel posts are visibly wider than before,
  2. channel text bubbles stop wrapping too early because of a hidden avatar lane,
  3. long Russian/Cyrillic text reads closer to iOS rhythm,
  4. media captions in channels also wrap more naturally,
  5. normal group chats still keep the reserved avatar lane behavior.

### 0x. Verified regression checklist — P0 media reliability pass (2026-03-15)
- **Evidence:** `MessageDto` now extracts thumbnails for `messageAnimation` / `messageVideoNote`; `ChatTimelineVO` propagates their `videoFileId` and thumb-first preview path; `TgChatScreenPage` now queues pending video opens and auto-opens after `downloadFile` makes the local path available; grouped photo albums no longer drop empty-path cells.
- **Historical regression checklist:** verify on emulator/device:
  1. tapping a not-yet-local video opens it automatically after download instead of requiring a second tap,
  2. GIF/animation bubbles show preview thumbnails before the full animation file is downloaded,
  3. videoNote bubbles show preview thumbnails before the full file is local,
  4. partially downloaded photo albums stay grouped and show placeholder cells instead of collapsing into one photo,
  5. special-media fullscreen open still works when the file is already local,
  6. switching chats clears any stale pending-video-open state.

### 0q. Verified regression checklist — media pipeline + badge reset (2026-03-14)
- **Evidence:** Full media pipeline activated: file:// URI conversion, on-demand document download, badge reset fix, badge styling alignment.
- **Historical regression checklist:** device-check:
  1. Photos display in chat bubbles (not placeholder icons),
  2. Stickers display correctly,
  3. Video thumbnails show in video bubbles,
  4. Document tap triggers download, icon changes after completion,
  5. Unread badges reset when exiting a previously unread chat,
  6. Tab bar badge decrements correctly,
  7. Muted chat badges show gray (#B6B6BB) not text_secondary gray,
  8. Voice messages auto-download (bubble should show waveform ready for playback).

### 0p. Verified regression checklist — chat opening performance + unread marker (2026-03-14)
- **Evidence:** TgChatScreenPage rewritten for instant chat positioning via `List({ initialIndex })`, race condition fix (`HISTORY_INITIAL_DELAY_MS=600`), placeholder release deadlock fix (`INITIAL_HISTORY_PLACEHOLDER_RELEASE_COUNT=1`), sticky unread marker (`stickyLastReadMessageId`).
- **Historical regression checklist:** device-check:
  1. Chat opens at correct position (bottom for read chats, unread boundary for unread),
  2. No eternal loading spinner on any chat,
  3. Old messages load normally via pagination (not broken by delay change),
  4. Unread marker ("Unread Messages") persists while in chat, disappears on re-entry after reading,
  5. Chats with <12 messages render content immediately (no spinner),
  6. Saved scroll position restored correctly on back-navigate to previously opened chat.

### 0n. Verified regression checklist — glass system overhaul + composer + status bar (2026-03-14)
- **Evidence:** Full glass/blur/composer/status bar rework in session 5.
- **Historical regression checklist:** device-check:
  1. Status bar icons visible and correct color in both light/dark themes,
  2. Composer no longer shows blue focus outline on tap,
  3. Composer sizing/padding feels closer to iOS (slightly thicker capsule),
  4. Glass elements (top bar, tab bar, composer, filter bar) show frosted tint (not nearly-invisible),
  5. Glass edge highlights visible as thin light border on all glass capsules,
  6. Tab bar pill is gray (not blue) with glass blur effect,
  7. Tab bar island still full capsule shape (radius 999),
  8. BlurStyle.COMPONENT_REGULAR renders properly on device (not all devices support it equally).

### 0j. Device-verify long-press context menu + reply bar
- **Evidence:** TgChatScreenPage now uses LongPressGesture(300ms) → `promptAction.showActionMenu()` with Reply/Copy actions. Old PanGesture swipe-to-reply removed (was hacky, caused perf issues with shared @State). Reply bar uses proper tokens (REPLY_SNIPPET_*), height 45vp (iOS reference). Member count uses localized string resources.
- **Historical regression checklist:** device-check:
  1. long-press on message shows action menu (Reply + Copy),
  2. Reply action opens reply bar above composer,
  3. Copy action copies text to clipboard with toast feedback,
  4. reply bar appears/disappears properly,
  5. sent message includes reply-to reference,
  6. reply state clears after send,
  7. group/channel subtitle shows localized member count.

### 0k. Verified regression checklist — emoji media prefixes in chat list
- **Evidence:** `fallbackMessageTextForType()` now returns emoji prefixes (`📷 Photo`, `📹 Video`, etc.) instead of brackets.
- **Historical regression checklist:** device-check chat list to confirm media type previews show emoji.

### 0l. Verified regression checklist — group/channel member count in top bar
- **Evidence:** `updateChatTopBarData()` now shows "X members"/"X subscribers" for groups/channels.
- **Historical regression checklist:** device-check group and channel chat screens to confirm subtitle shows member count.

### 0m. Verified regression checklist — long-press copy
- **Evidence:** parallelGesture(LongPressGesture) on message bubbles copies text to clipboard.
- **Historical regression checklist:** device-check long-press on text message, paste elsewhere to verify.

### 0d. Verified regression checklist — controlled TgComposerInput + emoji lane
- **Evidence:** `TgComposerInput` was brought back to a controlled contract: `TgChatScreenPage` now owns the live draft text, the atom exposes `text` + `onTextChange`, the optional emoji lane is present again, and the main geometry moved into `TgUiTokens`.
- **HarmonyOS grounding:** the atom now uses `TextArea.style(TextContentStyle.INLINE)` plus `onSubmit(..., SubmitEvent).keepEditableState()` for send-style keyboard behavior.
- **Historical regression checklist:** device-check the live chat composer and confirm:
  1. typing updates stay stable across page rebuilds,
  2. send-style Enter does not unnecessarily dismiss the keyboard,
  3. emoji/send/mic spacing reads correctly inside the unified capsule,
  4. draft clearing after send still feels natural.

### 0e. Verified regression checklist — TgChatRow prefix states
- **Evidence:** `ChatItemVO` + `TgChatRow` now split preview prefixes from the preview body instead of flattening everything into one plain string.
- **What changed locally:**
  - drafts now render as a red `Draft:` prefix + normal body text,
  - group sender prefixes (`You:` / sender name) now render as a separate accent fragment,
  - group typing rows now use the same split-prefix rhythm (`Alice` + `typing...`) instead of one flat string.
- **Historical regression checklist:** device-check the Chats tab and confirm:
  1. draft rows read like Telegram instead of one monochrome sentence,
  2. group sender prefixes visually separate from the body,
  3. typing rows still ellipsize correctly on narrow widths,
  4. right meta cluster does not jump when prefix states change.

### 0f. Verified regression checklist — TgChatMeta optical tuning
- **Evidence:** `TgChatMeta` / `TgUnreadBadge` were re-tuned against current iOS refs:
  - time text now uses a dedicated 14pt-style token,
  - unread badge text uses a dedicated 14pt token plus tighter horizontal padding,
  - pin icon size was reduced,
  - status icon size was increased.
- **Historical regression checklist:** device-check several row states and confirm:
  1. time/status cluster no longer looks undersized,
  2. unread badge width/weight feels closer to Telegram iOS,
  3. pin icon no longer looks oversized beside the badge lane,
  4. no jump/regression appeared in the right meta cluster.

### 0g. Verified regression checklist — typing preview correction
- **Evidence:** iOS `ChatListTypingNode.swift` renders typing activity through `ChatListInputActivitiesNode` using the regular chat-list message text color, not the draft/error accent and not the split author-prefix accent path.
- **What changed locally:** group typing rows went back to a single preview string (`Alice typing...`), and `TgChatRow` no longer paints typing body text in the primary accent color.
- **Historical regression checklist:** device-check typing states and confirm:
  1. typing rows no longer look over-accented,
  2. group typing text still reads clearly,
  3. ellipsis still behaves correctly on narrow rows,
  4. the state feels closer to Telegram iOS than the previous blue/accent version.

### 0h. Verified regression checklist — row rhythm / separator lane tuning
- **Evidence:** `ChatListItem.swift` shows a tighter vertical title/preview rhythm than the old tg_ui row, and the iOS separator lane for the standard avatar path lands around `80pt`, not at the full text-start inset.
- **What changed locally:** `TgUiTokens` now use a tighter title/preview gap and an explicit iOS-like separator inset lane.
- **Historical regression checklist:** device-check the Chats tab and confirm:
  1. rows no longer feel too airy vertically,
  2. separator starts closer to Telegram iOS,
  3. pinned/background transitions still look clean,
  4. no clipping/regression appeared in narrow rows.

### 0i. Device-verify row typography tuning
- **Evidence:** `ChatListItem.swift` uses row-specific title/preview typography (`16/17`-scaled title, `15/17`-scaled preview) rather than generic screen-title sizing.
- **What changed locally:** `TgChatRow` now uses dedicated row typography tokens (`CHAT_ROW_TITLE_FONT_SIZE`, `CHAT_ROW_PREVIEW_FONT_SIZE`) instead of the shared global title token.
- **Historical regression checklist:** device-check the Chats tab and confirm:
  1. row titles no longer feel oversized,
  2. preview/body balance looks closer to Telegram iOS,
  3. nothing else in the app regressed because the old global token is no longer driving chat rows.

### 0j. Device-verify `videoNote` / instant-video parity
- **Evidence:** special videos still looked unlike Telegram iOS because `videoNote` was routed through the generic rectangular `TgVideoBubble` shell even after preview/open-flow fixes.
- **What changed locally:** added `entry/src/main/ets/ui/tg_ui/atoms/TgInstantVideoBubble.ets`, `entry/src/main/ets/ui/tg_ui/spec/TgInstantVideoBubble.md`, `entry/src/main/ets/ui/tg_ui/demos/TgInstantVideoBubbleDemo.ets`, plus a dedicated `videoNote` branch in `TgMessageRouter` with iOS-like compact/regular size targets (`212 / 240`) and circular `.clip(true)` media rendering.
- **Historical regression checklist:** device-check special-video rows and confirm:
  1. `videoNote` bubbles are circular instead of rectangular,
  2. preview thumbnails appear before the full file is local,
  3. one tap still opens the viewer after the pending-download path completes,
  4. sender name / reply snippet / caption cases do not reintroduce a hidden rectangular shell.

### 0k. Device-verify album gallery viewer paging
- **Evidence:** grouped-photo bubbles already merged correctly, but fullscreen open still showed only one photo and had no way to move through the rest of the album.
- **What changed locally:** `TgChatScreenPage` now passes normalized album path arrays + selected index into `TgPhotoViewerPage`, and `TgPhotoViewerPage` now uses ArkUI `Swiper` for multi-photo fullscreen paging while preserving the old zoom/dismiss path for single-photo viewers.
- **Historical regression checklist:** device-check album viewer behavior and confirm:
  1. tapping any album cell opens the correct initial photo,
  2. horizontal swipe moves through the whole album,
  3. empty placeholder cells from partial downloads are skipped instead of creating blank viewer pages,
  4. single-photo viewer still pinch-zooms and drag-dismisses as before.

### 0l. Device-verify dedicated audio/music bubble path
- **Evidence:** music/audio messages were still routed through `TgDocumentRow`, so even downloaded tracks looked like generic files instead of Telegram music bubbles.
- **What changed locally:** added `TgAudioBubble` + spec/demo, extended chat VO/router with `audioDuration/audioTitle/audioPerformer`, and wired page-owned tap handling so local audio opens through Ability Kit `viewData` while missing audio still triggers download.
- **Historical regression checklist:** device-check music/audio bubbles and confirm:
  1. `audio` messages no longer look like document rows,
  2. long title/performer pairs ellipsize cleanly,
  3. tap on undownloaded audio starts download,
  4. tap on downloaded audio opens the local file correctly.

### 0c. Device-verify corrected iOS-style tab bar capsule
- **Evidence:** same-day re-check of current Telegram iOS refs showed that the active tab shell is still a centered glass capsule (`TabBarComponent` / `GlassBackgroundContainerView`), so the brief full-width shelf rewrite was wrong.
- **What changed locally:** `entry/src/main/ets/ui/tg_ui/atoms/TgTabBar.ets` was corrected back toward a centered capsule model; dead atom-local bottom-inset bookkeeping was removed so the page remains the only owner of bottom safe-area math; `entry/src/main/ets/ui/pages/MainTabsPage.ets` again positions it above the bottom safe area; `entry/src/main/ets/ui/utils/SafeAreaUtils.ets` again reserves capsule height + safe area + breathing gap.
- **Historical regression checklist:** device-check root tabs and confirm:
  1. the capsule sits at the correct bottom offset safely,
  2. all 4 tabs remain easy to tap,
  3. unread badge placement still looks right,
  4. the overall bottom chrome reads like the current Telegram iOS capsule.

### 0a. Device-verify TgChatTopBar centering on chat screen
- **Evidence:** screenshot `C:\Users\Kharki\Pictures\Screenshot_2026-03-12T022356.png` showed the chat top bar cluster packed to the left instead of using the full width.
- **What changed locally:** `entry/src/main/ets/ui/tg_ui/atoms/TgChatTopBar.ets` now uses fixed left/right capsules plus a weighted center lane for the title capsule; title/subtitle text are centered inside the capsule; each capsule is now a layered `Stack` so glass blur/specular stay behind the content instead of compositing over it; the atom again exposes `glassMode` and no longer hardcodes opaque fallback surfaces as the only path.
- **Historical regression checklist:** run device check on the same chat screen and confirm (1) avatar is pinned right, (2) title capsule is centered, and (3) text/icons look crisp above the glass on a dark chat background.

### 0b. Device-verify new integrated ChatList header
- **Evidence:** the previous ChatList shell used `TgTopBar` plus a separate scrolling `Search` list item, which visually produced a double-strip header and clipped left `Edit` text in Russian (`C:\Users\Kharki\Pictures\Screenshot_2026-03-12T101849.png`).
- **What changed locally:** `ChatListPage` now uses the new atom `entry/src/main/ets/ui/tg_ui/atoms/TgChatListNavigationBar.ets`; the search field moved into the header surface; the page now offsets list content by a tokenized integrated header height instead of rendering search as the first list row. A follow-up fix on 2026-03-13 gave the header atom an explicit root height, because without it the `Stack` overlay could expand and swallow all chat-list gestures/taps.
- **Historical regression checklist:** device-check the Chats tab and confirm:
  1. the left action text is no longer clipped,
  2. the search field reads as part of the header chrome,
  3. list content scrolls under the header cleanly with no extra strip/gap,
  4. the list is scrollable and rows are tappable again.

### 0. Device-verify chat-list blank-cell regression fix
- **Evidence:** local code updates in:
  - `entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets`
  - `entry/src/main/ets/ui/tg_ui/atoms/TgChatRow.ets`
  - `entry/src/main/ets/core/events/normalizers/ChatNormalizer.ets`
  - `entry/src/main/ets/core/reducers/chatsReducer.ets`
  - `entry/src/main/ets/ui/pages/chatlist/ChatItemVO.ets`
- **What changed locally:** restored stable `LazyForEach` identity (`chatId` key + per-chat `reuseId`), removed debug row instrumentation, blocked empty `updateChatTitle` overwrite path, and added phone-number private-title fallback.
- **Historical regression checklist:** run device HiLog/UI pass to confirm blank/empty chat cells no longer reproduce under fast scroll + initial hydration.

### 1. Stabilize runtime reset and chat loading flows
- **Evidence:** modified files in:
  - `entry/src/main/ets/app/bootstrap/AppCoreRuntime.ets`
  - `entry/src/main/ets/core/store/AppStore.ets`
  - `entry/src/main/ets/domain/usecases/loadChats.ets`
  - `entry/src/main/ets/domain/usecases/loadChatHistory.ets`
  - `entry/src/main/ets/domain/usecases/openChat.ets`
  - `entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets`
  - `entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets`
- **Likely focus:** avoid stale caches, duplicate in-flight loads, bad reopen behavior, unread/history restore glitches, and list churn from non-persistent `LazyForEach` keys.
- **Latest evidence from 2026-03-08 HiLog:** reopening into `savedIndex = 0` / unread-boundary restore can immediately trigger repeated `loadOlder`/`loadNewer` bursts in `TgChatScreenPage` before any real user scroll.
- **Latest pagination fix from 2026-03-09:** edge latch replaced with `recheckPaginationEdge()` pattern — after each completed load, if viewport is still near edge, auto-triggers next batch (iOS-like continuous loading). Added `lastVisibleEndIndex` for accurate newer-edge detection.
- **Follow-up after the latest 2026-03-08 HiLog pass:** restore-triggered burst and edge-pinned pagination storm are fixed in `TgChatScreenPage`; next runtime verification should confirm the reduced `loadOlder` / `loadNewer` counts stay at zero.
- **Current runtime cleanup focus:** `loadChatHistory` sender hydration cap was widened to cover a full default history page before dispatch; remaining work is to re-check HiLog and see whether any missing-user warnings are true misses vs transient hydration lag.
- **Newest runtime finding from 2026-03-08 HiLog:** the remaining startup/live missing-user warnings correlate with direct `getUser`/`getMe` responses being parsed with the wrong `id` source, not with chat history pagination anymore.
- **Newest patch target completed locally:** user parsing now uses top-level `user.id` extraction instead of generic nested-key regex matching; next device run should confirm that `getMe resolved` becomes sane and repeated `Message references non-existent user` warnings collapse.
- **Latest verification from 2026-03-08 `[27274]` HiLog:** runtime stabilization target is effectively satisfied — missing-user warnings dropped to `0`, stale-lastMessage warnings dropped to `0`, and `loadOlder` / `loadNewer` stayed at `0`.
- **Newest finding from 2026-03-08 `[8081]` HiLog:** a chat open can still get a **tiny but non-zero** default `getChatHistory` batch (`1 events` observed for `ClawdBot`), after which the old `messageCount >= limit` rule incorrectly froze `canLoadOlder=false`.
- **Newest patch completed locally:** `LoadChatHistoryUseCase` now treats TDLib short batches as ambiguous, keeps pagination progress-based, and performs one controlled older top-up for suspiciously tiny first-open default batches.
- **Newest polish completed locally:** short initial batches are now held back from visible timeline dispatch until the controlled top-up returns, and `TgChatScreenPage` shows a loading placeholder while the initial timeline is still pending.
- **Newest finding from 2026-03-08 `[21342]` HiLog:** the defer-placeholder path worked, but one top-up was not always enough — at least one chat still progressed only `1 -> 2` messages while `canLoadOlder` stayed true.
- **Newest local refinement completed:** initial top-up now retries in a bounded loop while oldest-message progress continues, and the chat screen keeps the loading placeholder until the initial timeline is large enough or older history is genuinely exhausted.
- **Historical regression checklist:** device-verify that problematic chats now land on a fuller first-open timeline without showing a misleading tiny partial history in between.
- **Newest local fix (2026-03-11):** prepend compensation for older-history loading in `TgChatScreenPage` now freezes the viewport and re-anchors the saved visible item synchronously in the same turn as `applyDiff()`. The delayed second-pass `setTimeout(16ms)` compensation was removed from the prepend path because it still allowed a visible jump/autoscroll when older rows were inserted above the viewport.
- **Newest local perf fix (2026-03-12):** initial `getChatHistory` dispatch now lands in store/UI before missing sender hydration. Sender users are hydrated in background, in parallel chunks, and their normalized events are dispatched as one batch instead of one store update per user. Message selectors now memoize per-chat sorted arrays by message-map reference, so those follow-up user updates no longer force a full re-sort of the active chat.
- **Newest local scroll fix attempt (2026-03-12):** chat history `List` now enables native `maintainVisibleContentPosition(true)` and the old custom prepend `scrollToIndex` compensation hot path was removed. Prepend now relies on ArkUI's built-in off-screen insert preservation and only keeps the anti-cascade guard.
- **Newest local runtime fix (2026-03-12):** `ChatTimelineDataSource` stopped mixing `onDatasetChange(...)` with `onDataAdd/onDataDelete/onDataChange`, which was matching the device HiLog error `onDatasetChange cannot be used with other interface`. `TgChatScreenPage` now also blocks pagination callbacks while `applyDiff()` is running and defers `recheckPaginationEdge()` to the next tick so it does not fire against stale pre-prepend indices/counts.
- **Verification status:** `bash ./scripts/smoke-ui-phase0.sh` ✅, `./scripts/smoke-build.ps1` ✅, `./scripts/smoke-ui-phase0.ps1` ✅.
- **Historical regression checklist:** device-verify three runtime cases on a long/big chat: (1) hitting the top edge loads older messages without shifting the visible viewport under native `maintainVisibleContentPosition`, (2) the `Loading older messages...` loop no longer cascades without user scroll after each batch, and (3) `Timeline rebuild failed: onDatasetChange cannot be used with other interface` no longer appears in HiLog.

### 2. Finish and commit the new tg_ui docs/demo batch
- **Evidence:** untracked files include:
  - `entry/src/main/ets/ui/tg_ui/atoms/TgChatTopBar.ets`
  - specs for `TgCallRow`, `TgChatTopBar`, `TgSearchBar`, `TgSettingsRow`, `TgTabBar`
  - demos for `TgCallRow`, `TgChatTopBar`, `TgMessageBubbleBase`, `TgMessageRouter`, `TgSearchBar`, `TgSettingsRow`, `TgTabBar`
- **Goal:** get the repo history aligned with the current tg_ui runtime path and documentation claims.
- **Boundary note:** these untracked tg_ui support files are explicitly classified as part of the current batch in `TASKS/CURRENT_PATCHSET_BOUNDARY.md`.

### 3. Resync human-facing docs with current runtime reality
- **Evidence:** local modifications in:
  - `README.md`
  - `docs/ai/AI_MEMORY.md`
  - `docs/ai/UI_MIGRATION_PLAN.md`
- **Goal:** remove drift between historical notes and the current shell/chat path.

### 4. Replace the Calls placeholder with real TDLib-backed call history
- **Evidence:** modified / added files in:
  - `entry/src/main/ets/core/model/AppCommand.ets`
  - `entry/src/main/ets/infra/td/serialization/CommandSerializer.ets`
  - `entry/src/main/ets/core/events/normalizers/ChatNormalizer.ets`
  - `entry/src/main/ets/domain/usecases/loadCalls.ets`
  - `entry/src/main/ets/ui/pages/calls/CallsPage.ets`
  - `entry/src/main/ets/ui/tg_ui/atoms/TgCallRow.ets`
- **What changed locally:** `CallsPage` now uses TDLib `searchCallMessages` instead of the hardcoded empty state, paginates with `next_from_message_id`, and hydrates missing chat/user metadata via direct `getChat` / `getUser` response normalization.
- **Current limitation:** this pass maps TDLib `messageCall` / `messageGroupCall` into the existing single-peer `TgCallRow`; there is still no dedicated missed-only segmented header or richer group-call row treatment.
- **Historical regression checklist:** fresh device run + HiLog to confirm the real payload shape on this repo/runtime and verify that row titles/avatars hydrate correctly on non-trivial histories.

### 5. Stock ArkUI atom replacement (2026-03-09) ✅
- Replaced the genuinely thin wrappers with inline page layout where it simplified the runtime:
  - `TgSettingsSection` → inline `Column` with tokens in `SettingsPage`
  - `TgContactRow` → inline `TgAvatar` + `Row/Column` in `ContactsPage`
- The live Chats shell also uses stock ArkUI `Search`, but **inside** `TgChatListNavigationBar`; the standalone `TgSearchBar` atom/demo/spec still remain in the library.
- Kept as active custom atoms: `TgTabBar`, `TgTopBar`, `TgChatListNavigationBar`, `TgCallRow`, `TgSettingsRow`.
- Smoke scripts updated. `bash ./scripts/smoke-ui-phase0.sh` ✅
- Cleanup candidates for removed runtime atoms were completed this session: `TgContactRow` / `TgSettingsSection` demo+spec artifacts were deleted.

---

## Improvement plan — "demo → real app" (derived from iOS comparison 2026-03-09)

Priority order is by **visual/functional impact**, not by architectural purity.

### P0-P5 Improvement plan — ALL COMPLETE (2026-03-09)
- **P0 Avatar download:** ✅ Full pipeline: `photoSmallFileId` in AppState/DTOs/reducers/stateClone, `DownloadFileCommand` + `CommandSerializer`, `FileNormalizer` (updateFile → FileDownloadedEvent), `filesReducer`, `downloadAvatars` usecase in AppCoreRuntime. Fixed two bugs: (1) `getTopLevelNumber('id')` for file IDs (Lesson #28), (2) direct response parsing via TdObject native accessors instead of broken `JSON.stringify(TdObject)` (Lesson #29). Verification status: passed; keep older device-check wording only as historical regression context.
- **P1 Sender names in groups:** ✅ `buildChatItemVO()` prepends "You: " / "firstName: " for group previews
- **P2 Checkmark order:** ✅ TgChatMeta status icon before time (iOS: ✓✓ 17:47)
- **P3 Date format:** ✅ Same-year dates → `dd.MM` (no year)
- **P4 chat-list header actions:** ✅ Edit + Compose buttons in the integrated `TgChatListNavigationBar` path
- **P5 Pinned separator:** ✅ `isLastPinned` + 8vp gap after last pinned chat

### P6 Profile screen — COMPLETE (2026-03-09)
- **TgProfilePage**: full pipeline from model through usecase to UI
- Navigation wired from TgChatScreenPage (avatar + title taps)
- getUserFullInfo (bio), getSupergroupFullInfo (description, memberCount)
- Verification status: passed; keep older device-check wording only as historical regression context.

### P8 TgTabBar Android-style rewrite — COMPLETE (2026-03-11)
- Pill highlight replaces ring (full-tab capsule, 9% alpha, scale+opacity animation 320ms)
- Sizes: 56vp height, 24vp icon, 12vp text, Bold font on selection
- Reference: Android `GlassTabView.java`

### P9 Pagination Android/iOS alignment — COMPLETE (2026-03-11)
- Older threshold 10→25, newer 6→5 (Android/iOS values)
- Latch system removed → simple `!isLoading` guard (Android pattern)
- Scroll compensation: synchronous (removed setTimeout 16ms flicker)
- Reason: `'restore'` → `'default'` for scroll pagination

### P7 Unified bubble container — COMPLETE (2026-03-10)
- TgMessageRouter: sender name, reply, content, meta all INSIDE bubble
- Stack(BottomEnd) for text bubble shrink-wrap + meta overlay
- All bubble atoms gained noBubbleWrap support
- Nav lock double-tap fix (ChatListPage.onPageShow + aboutToDisappear)
- Composer safe area fix (margin→padding, expandSafeArea BOTTOM)

### Future (beyond current sprint)
- Media download/open (photos, videos, documents)
- Voice message playback
- Push notifications
- Create new chat/group
- Search within messages
- Message context menu (reply, copy, forward, delete)
- Unread counter badge on chat list tab
- Typing indicator in chat screen
- Online status in chat list

## Next after the current patchset

### Verification ledger (passed)
- `scripts/smoke-ui-phase0.ps1` — passed on 2026-03-09
- `scripts/smoke-ui-phase0.sh` — passed on 2026-03-09
- latest runtime HiLog verification — passed on 2026-03-08 via `[27274]` trace
- `scripts/smoke-build.ps1` — passed on 2026-03-08
- next verification actions are:
  1. phase-4 calls path runtime verification — passed (per 2026-03-22 verification sync)
  2. P0 avatar download flow runtime verification — passed (per 2026-03-22 verification sync)

### Clean up stale historical references
- Only after demos/specs/integration are safely committed.
- Orphaned demos/specs for removed runtime atoms (`TgSettingsSection`, `TgContactRow`) were deleted on 2026-03-22; `TgSearchBar` is not removed, only inactive in the live Chats shell.
- Do not remove old docs or fallback paths blindly while the branch is still unstable.

## External blockers / prerequisites
- TDLib prebuilts under `entry/src/main/cpp/third_party/tdlib`
- local credentials in `entry/src/main/ets/services/ConfigLocal.ets`

### 0m. Verified regression checklist — tightened media download policy + pending bubble states
- Verify the 2026-03-15 session 21 patch on a real device/emulator:
  - repeated taps on the same video/file no longer spam repeated `downloadFile` HiLog entries
  - voice/audio/document bubbles show download → spinner → open/play transitions
  - video / GIF / instant-video previews show a download affordance before the file is local and a spinner while pending
  - downloaded documents open via Ability Kit `viewData`
  - background auto-download noise is reduced by keeping voice/GIF/videoNote on-demand while preserving photo/thumb preview behavior


### 0aw. Visible blockquote rendering for live text bubbles (2026-03-23)
- **Goal:** make message-body quotes visible inside text-message bubbles instead of only supporting reply-quote headers.
- **Status:** completed this session for the narrow text path:
  - added explicit `quoteEntities` to message-content DTO/state flow
  - added `TgMessageTextBodyV2` for visible quote blocks
  - live `text` branch now forwards quote ranges through `TgMessageRouter` -> `TgTextBubbleV2`
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** if captions/media also need quote parity, do that as a separate pass; do not reopen the whole router for this.


### 0ax. Media-caption blockquote parity for visual media family (2026-03-23)
- **Goal:** extend visible quote rendering from text messages into media captions without reopening non-visual branches.
- **Status:** completed this session for `photo` / `photoAlbum` / `video` / `animation`:
  - caption quote entities are now parsed from TDLib caption formatted text
  - timeline rows carry explicit caption quote ranges
  - `TgMediaBubbleShellV2` renders quoted captions via `TgMessageTextBodyV2`
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** if quote parity is needed for document/audio/voice captions, do it as a separate narrow pass.

### 0ay. Replace senderId-hash name colors with TDLib-backed peer accent ids (2026-03-23)
- **Goal:** stop sourcing sender/reply/quote accent colors from a local senderId modulo fallback when Telegram/TDLib already carries peer accent identity.
- **Status:** completed this session for the current narrow runtime path:
  - added `accentColorId` to `User` / `Chat` state and DTO flow,
  - parse `accent_color_id` from TDLib user/chat objects,
  - handle `updateChatAccentColors` in `ChatNormalizer`,
  - `ChatTimelineVO` now prefers the real sender peer's `accentColorId` for `senderColorHex` and only falls back to the default Telegram palette when the peer accent is not available.
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** if exact premium/custom peer colors are still visually off, the next step is not another local hex shuffle but a proper TDLib accent-color-table resolver path.

### 0az. Global TDLib accent-color resolver path (`updateAccentColors`) (2026-03-23)
- **Goal:** stop treating non-built-in peer accent ids as opaque numbers and resolve them through the real TDLib accent-color table.
- **Status:** completed this session:
  - added a global `accentColors` state slice,
  - added DTO/event/normalizer/reducer handling for `updateAccentColors`,
  - `ChatTimelineVO` now resolves custom peer accent ids via the TDLib accent-color registry before falling back to local defaults.
- **Current resolution order:**
  1. built-in `0...6`,
  2. TDLib `built_in_accent_color_id` for one-color UI surfaces,
  3. exact dark/light theme color from TDLib accent data,
  4. local fallback palette only when runtime data is missing.
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** if avatar/profile surfaces later need exact premium/profile gradients, do that through a separate `updateProfileAccentColors` path rather than overloading sender-name/reply-line logic.

### 0ba. Reply-snippet color source fixed to cited author (2026-03-23)
- **Goal:** stop tinting quote/reply snippets with the current sender color when the cited message belongs to a different peer.
- **Status:** completed this session:
  - timeline rows now carry `replyAuthorColorHex`,
  - live text/media/router reply-snippet paths use that dedicated color instead of `senderColorHex`,
  - datasource equality includes the new field so late peer-color hydration still repaints the row.
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** if any remaining color mismatch is reported, inspect whether it is a reply snippet or a body blockquote before changing quote-body tint logic again.

### 0bb. Body blockquote stripe reaches rounded quote-surface edges (2026-03-23)
- **Goal:** stop rendering the body-quote accent stripe as a shorter inset line inside the quote block.
- **Status:** completed this session:
  - moved quote padding from the outer quote container to the text-content row in `TgMessageTextBodyV2`,
  - kept the stripe as a full-height left-edge layer inside a clipped rounded quote surface,
  - increased `MSG_QUOTE_BAR_WIDTH` from `3` to `4`.
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** if users still report visual drift, the next step should be optical tuning of quote radius/padding, not reverting the flush-edge stripe geometry.

### 0bc. Media quote captions use the same width contract as regular captions (2026-03-23)
- **Goal:** stop quote captions inside image/video bubbles from expanding to the wider shell width and looking visually centered with larger edge insets.
- **Status:** completed this session:
  - the quoted-caption branch in `TgMediaBubbleShellV2` now uses `visualMediaBubbleWidth()` instead of `width('100%')`.
- **Why this mattered:** the issue was structural drift in the width contract, not just padding values.
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** if more drift remains, inspect whether the mismatch is width-contract or quote-body layout before changing media caption paddings again.

### 0bd. Reply-snippet stripe uses the same full-surface left-edge contract as body blockquotes (2026-03-23)
- **Goal:** stop keeping reply snippets on a shorter content-sized accent bar when body blockquotes already use a full clipped surface stripe.
- **Status:** completed this session:
  - `TgReplySnippet` accent stripe now uses `height('100%')`,
  - the stripe remains flush to the left edge of the clipped rounded snippet surface,
  - reply snippets and body quotes now share the same structural stripe behavior instead of two different height models.
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** if any remaining quote mismatch is reported, inspect width/radius/content layout first rather than reintroducing a shorter reply-only stripe model.

### 0be. Reply snippets and body quotes now share one surface geometry/tint contract (2026-03-23)
- **Goal:** remove the last structural drift where `TgReplySnippet` still used reply-only shell tokens while body blockquotes used `MSG_QUOTE_*` tokens.
- **Status:** completed this session:
  - `TgReplySnippet` now reuses `MSG_QUOTE_*` geometry/tint tokens for padding, stripe width, stripe gap, radius, and fallback quote tint,
  - reply snippets and body blockquotes now differ by content model, not by separate quote-surface geometry.
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** if visual drift remains, inspect width contracts and text-layout density per variant rather than reopening stripe/radius tokens again.

### 0bf. Reply-snippet stripe is now overlay-positioned so full height no longer inflates the snippet (2026-03-23)
- **Goal:** preserve the full-surface stripe while preventing it from becoming the reason reply snippets get taller again.
- **Status:** completed this session:
  - the stripe in `TgReplySnippet` remains `height('100%')`,
  - but is now `position({ x: 0, y: 0 })` inside the `Stack`, so content drives snippet height instead of the stripe layer.
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** if drift remains, inspect text line-density/thumbnail branch before touching the stripe model again.

### 0bg. Live group-reply text path density tightened in `TgReplySnippet` (2026-03-23)
- **Goal:** reduce the remaining vertical bulk in the actual group-text reply path after stripe geometry had already been isolated.
- **Status:** completed this session:
  - confirmed the live path for group text replies is `TgMessageRouter -> TgTextBubbleV2 -> TgReplySnippet`,
  - reduced `REPLY_SNIPPET_PADDING_V` from `4` to `3`,
  - reduced `REPLY_SNIPPET_TEXT_GAP` from `2` to `0`.
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** if the reply block still feels too tall, inspect the parent gap in `TgTextBubbleV2` / `TgMediaBubbleShellV2` before touching stripe geometry again.

### 0bh. `TgReplySnippet` now uses a content-driven `Row` layout model (2026-03-23)
- **Goal:** stop the reply snippet from behaving like an overlay-composed block when the live group-reply path needs a simpler content-driven height contract.
- **Status:** completed this session:
  - replaced the `Stack` composition in `TgReplySnippet` with a single `Row`,
  - kept the accent stripe as a dedicated left child,
  - moved the content block to the weighted right side so snippet height follows content directly.
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** if the user still sees excessive height, the next inspection target is parent spacing in `TgTextBubbleV2` / `TgMediaBubbleShellV2`, not the internal snippet layout model.

### 0bi. Live text-reply caller spacing reduced in `TgTextBubbleV2` (2026-03-23)
- **Goal:** cut the remaining extra frame around the reply block in the actual group-text runtime path after the snippet internals had already been tightened.
- **Status:** completed this session:
  - removed the extra bottom margin under `TgReplySnippet` in `TgTextBubbleV2`,
  - reduced top/bottom bubble padding to `4vp` whenever `showReplySnippet` is true.
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** if this still looks too tall, inspect sender-name spacing above the snippet in group chats before changing the snippet itself again.

### 0bj. Quote measurement and decoration split again in `TgReplySnippet`; shared stripe width increased to 5 (2026-03-23)
- **Goal:** restore content-driven height while keeping the stripe edge-to-edge, and make the stripe one pixel thicker across quote paths.
- **Status:** completed this session:
  - `TgReplySnippet` now uses a content-measuring base row plus a separate positioned overlay stripe,
  - `MSG_QUOTE_BAR_WIDTH` increased from `4` to `5`, which also propagates to reply snippets through shared tokens.
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** if quoted blocks are still visually tall after this, compare sender-name spacing and thumbnail branch density before changing the stripe system again.

### 0bk. Reply-snippet stripe now follows content height only (2026-03-23)
- **Goal:** keep the quote area compact while making the accent stripe stop spanning the full surface height.
- **Status:** completed this session:
  - restored explicit `barHeight()` in `TgReplySnippet`,
  - stripe is positioned from `REPLY_SNIPPET_PADDING_V` instead of filling the entire surface.
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** if further drift remains, inspect the exact author/preview line-count heuristic in `barHeight()` rather than changing the whole layout again.

### 0bl. Reply stripe should live inside the quote surface, not outside it (2026-03-23)
- **Goal:** finish the reply-snippet stripe contract using the Android reference instead of continuing blind padding tweaks.
- **Status:** completed this session:
  - inspected `ReplyMessageLine.java` + `ChatMessageCell.java`
  - Android draws `drawBackground(rect)` and `drawLine(rect)` against the same reply rect
  - `TgReplySnippet` was updated so the root clipped/tinted surface owns the geometry, while the stripe is drawn inside that same surface as an overlay
- **Verification:** `scripts/smoke-ui-phase0.ps1` ✅, `scripts/smoke-build.ps1` ✅
- **Next action:** visually re-check group-chat reply snippets; if drift remains, the next candidate is text density/line-height, not whether the stripe belongs inside the surface.
- **Follow-up:** the first Android-grounded rewrite regressed height in runtime. The current compromise keeps the snippet compact again: surface measurement stays content-owned, while the stripe is still treated as part of the quote area visually.

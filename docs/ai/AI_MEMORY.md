# AI Memory — Telegram-HarmonyOS

## 0) Maintenance sync (2026-05-18)
- Current `tg_ui` inventory is post-cleanup/API23-HDS-shell; use `STATUS.md` for exact current counts.
- Live Chats shell path is API23 `HdsTabs`/`HdsNavigation` + `TgChatListNavigationBar` + `TgChatRow` + `TgChatTopBar` + `TgMessageRouter`; older mentions of custom `TgTabBar`, `AppTopBar`, `AppTabBarItem`, `AppListRow`, `ChatListItem`, and `USE_TG_CHATLIST_V2` below are historical.
- `TgSearchBar`, `TgUnreadBadge`, `TgTextBubbleV2`, and custom `TgTabBar` standalone files are historical in this branch; active equivalents are stock `Search`, inline `TgChatMeta` badge, `TgTextBubbleV3`/`TgTextBodyV3`, and API23 `HdsTabs`.
- `scripts/smoke-ui-phase0.ps1` / `.sh` were resynced to the current shell path, and `scripts/smoke-build.ps1` now resolves `hvigorw` from PATH or the default DevEco install path.
- Per user confirmation on 2026-03-22, the previously pending emulator/device/runtime verification items for the current branch are considered passed and should no longer be treated as active blockers.
- Dark-theme parity was repaired for `sender_color_8` plus attach/call/reaction/story colors.
- Current `entry/src/main/ets` TODO/FIXME scan returns 0 hits.

Last updated: 2026-02-26  
Project root: `C:\Users\Kharki\Desktop\Telegram-HarmonyOS`  
Branch: `dev`

## 1) Mission
- Build HarmonyOS client UI with **Telegram iOS visual reference**.
- Migrate **iteratively by blocks**, not by full app rewrite.
- Keep architecture/domain/core stable while UI shell is rebuilt.

Master UI contract (frozen):
- `docs/ai/MASTER_PLAN_TELEGRAM_UI.md`

## 2) Fixed decisions (agreed)
1. iOS source of truth path:
   - `C:\Users\Kharki\Desktop\Telegram-HarmonyOS\рефенсы\Telegram-iOS-master`
2. Work strategy:
   - Atom-first pipeline (`SPEC -> TOKENS -> DEMO -> ATOM -> integration`).
   - Order is governed by `docs/ai/ATOM_ROADMAP.md` and frozen contract `MASTER_PLAN_TELEGRAM_UI.md`.
3. Auth UI:
   - Keep current logic.
   - Later align visuals to global design system for consistency.

## 3) Recent important changes (already done)
- Credentials moved from hardcoded constants to local config:
  - `entry/src/main/ets/services/ConfigLocal.ets` (gitignored)
  - `entry/src/main/ets/services/ConfigLocal.example.ets`
- `README.md` updated (API level, setup, hvigor commands, security note).
- Removed root garbage file `nul`.
- Threading comments cleaned up (removed outdated emitter narrative in dispatcher/gateway docs/comments).
- Collaboration docs added:
  - `docs/ai/UI_MIGRATION_PLAN.md`
  - `docs/ai/AI_HANDOFF_TEMPLATE.md`
- Phase 0 foundation started:
  - `entry/src/main/ets/ui/theme/AppShellTokens.ets`
  - `entry/src/main/ets/ui/components/common/{AppTopBar,AppTabBarItem,AppListRow}.ets`
  - `entry/src/main/ets/ui/pages/MainTabsPage.ets` now uses `AppTabBarItem`
  - `entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets` now uses `AppTopBar`
  - `docs/ai/VISUAL_QA_CHECKLIST.md`
- Phase 0 hardening pass completed for shell/chatlist:
  - removed hex color hardcode from Phase 0 shell/chatlist files
  - expanded `AppShellTokens` and switched placeholders (`ContactsPage`, `SettingsPage`) to shared `AppTopBar`
  - the live `TgChatRow` path is now `@ComponentV2`, and `ChatListPage` still applies `reuseId(...)` in `LazyForEach`
- Tab bar visual pass (iOS-like island refinement):
  - `MainTabsPage` now uses fixed bottom tab layout + floating glass island backdrop.
  - Chats tab icon switched from generic `ic_email` to dedicated `ic_chat`.
  - `AppTabBarItem` icon slot/badge overlay updated to keep icon centering stable.
- Top safe-area fix for shell pages:
  - `AppTopBar` now reads system avoid area (`TYPE_SYSTEM`) and adds dynamic top inset.
  - This prevents tab content/header from sliding under status bar while preserving immersive top background behavior.
- Shell parity pass (iOS closer):
  - Main tabs extended from 3 to 4 placeholders (`Contacts`, `Calls`, `Chats`, `Settings`) with default selected tab = `Chats`.
  - Tab bar rendering switched to floating island-only blur (system TabBar strip stays transparent), with lighter translucency.
  - `AppTopBar` switched to lighter translucent glass background + thinner blur.
  - `ChatListPage` now overlays top bar above content so list/background are visible under translucent header.
  - Added chat list bottom safe padding token to keep actionable content out of floating tab bar overlap area.
- Process hardening for atom-by-atom porting:
  - Added root `AGENTS.md` with strict Telegram iOS → HarmonyOS migration workflow and acceptance gates.
  - Added `entry/src/main/ets/ui/tg_ui/` scaffold (`tokens/`, `atoms/`, `molecules/`, `demos/`, `spec/`).
  - Added passport templates:
    - `entry/src/main/ets/ui/tg_ui/spec/COMPONENT_PASSPORT_TEMPLATE.md`
    - `entry/src/main/ets/ui/tg_ui/spec/TgChatRow.md` (first atom kickoff template).
- ChatRow pipeline kickoff (SPEC → DEMO → ATOM):
  - Step 0 tokens added: `entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets`
  - Step 1 `TgIcon` completed:
    - spec: `entry/src/main/ets/ui/tg_ui/spec/TgIcon.md`
    - atom: `entry/src/main/ets/ui/tg_ui/atoms/TgIcon.ets`
    - demo: `entry/src/main/ets/ui/tg_ui/demos/TgIconDemo.ets`
  - Step 2 `TgAvatar` completed:
    - spec: `entry/src/main/ets/ui/tg_ui/spec/TgAvatar.md`
    - atom: `entry/src/main/ets/ui/tg_ui/atoms/TgAvatar.ets`
    - demo: `entry/src/main/ets/ui/tg_ui/demos/TgAvatarDemo.ets`
    - includes online-dot overlay geometry and size variants (`40/54/60`) from token source
  - Step 3 `TgUnreadBadge` was a historical standalone atom; its spec/atom/demo were later removed. Active unread rendering lives inline in `TgChatMeta` and follows Telegram iOS compact `K/M` formatting (`1...999`, then `1K`, `2.5K`, `1.2M`).
  - Step 4 `TgChatMeta` completed:
    - spec: `entry/src/main/ets/ui/tg_ui/spec/TgChatMeta.md`
    - atom: `entry/src/main/ets/ui/tg_ui/atoms/TgChatMeta.ets`
    - demo: `entry/src/main/ets/ui/tg_ui/demos/TgChatMetaDemo.ets`
    - anti-jump rules applied:
      - right cluster width reserve via `constraintSize(minWidth)` + right alignment
      - fixed bottom-row geometry with placeholder when empty
  - Step 5 `TgChatRow` completed:
    - spec: `entry/src/main/ets/ui/tg_ui/spec/TgChatRow.md`
    - atom: `entry/src/main/ets/ui/tg_ui/atoms/TgChatRow.ets`
    - demo: `entry/src/main/ets/ui/tg_ui/demos/TgChatRowDemo.ets`
    - includes 10+ states + jump probe + failed states (`failed only`, `failed+unread`)
  - Step 6 integration (feature flag):
    - `ChatListPage` now supports tg_ui row path behind feature flag:
      - `entry/src/main/ets/ui/tg_ui/TgUiFeatureFlags.ets`
      - `entry/src/main/ets/ui/pages/chatlist/ChatListPage.ets`
    - default stays legacy (`USE_TG_CHATLIST_V2 = false`)
    - tg_ui path uses internal `TgChatRow` separator and disables `List.divider` to avoid double lines
  - Phase B gate hardening (real store fields in tg_ui chat row mapping):
    - chat model now carries:
      - `peerUserId`
      - `muteForSeconds`
      - `lastReadOutboxMessageId` / `lastReadInboxMessageId`
    - normalizer handles `updateChatNotificationSettings` (`mute_for`), reducers persist it
    - tg_ui row mapping now uses real values from store:
      - `isMuted` from chat notification settings
      - `sendStatus` derived from message state + read markers
      - avatar image path from chat/user photos
      - avatar online from user status for private chats
  - List update granularity hardening:
    - `ChatListDataSource` now has `applyDiff(...)` and prefers incremental notifications
      (`onDataChange` / `onDataAdd` / `onDataDelete`) for stable-order updates.
    - Full `onDataReloaded()` kept as fallback for reorder-heavy cases.
    - `ChatListPage.rebuildList()` switched from `reload(...)` to `applyDiff(...)`.
  - iOS references captured from:
    - `submodules/ChatListUI/Sources/Node/ChatListItem.swift`
    - `submodules/ChatListUI/Sources/Node/ChatListStatusNode.swift`
    - `submodules/TelegramPresentationData/Sources/Resources/PresentationResourcesChatList.swift`
  - Phase C Step 0 (`TgMessageTextRules`) completed (SPEC + DEMO + TOKENS):
    - spec: `entry/src/main/ets/ui/tg_ui/spec/TgMessageTextRules.md`
    - demo: `entry/src/main/ets/ui/tg_ui/demos/TgMessageTextRulesDemo.ets`
    - tokens: message text/bubble baseline added in `TgUiTokens` (`MSG_TEXT_*`, `MSG_LINK_*`, `BUBBLE_*`)
    - iOS mapping references:
      - `submodules/TelegramUI/Components/Chat/ChatMessageTextBubbleContentNode/Sources/ChatMessageTextBubbleContentNode.swift`
      - `submodules/TelegramUI/Components/Chat/ChatMessageItemCommon/Sources/ChatMessageItemCommon.swift`
      - `submodules/TelegramPresentationData/Sources/ChatPresentationData.swift`
    - demo matrix includes newline/emoji/link/torture URL + narrow/wide + side-by-side width comparison
  - Phase C Step 1 (`TgMessageBubbleBase`) completed (SPEC + DEMO + ATOM):
    - spec: `entry/src/main/ets/ui/tg_ui/spec/TgMessageBubbleBase.md`
    - atom: `entry/src/main/ets/ui/tg_ui/atoms/TgMessageBubbleBase.ets`
    - demo: `entry/src/main/ets/ui/tg_ui/demos/TgMessageBubbleDemo.ets`
    - bubble geometry contract:
      - incoming/outgoing alignment
      - tokenized radius/padding/max-width
      - long URL anti-overflow mode (`forceBreakAll`) + demo-only helper with `\u200B`
      - emoji-only (1/3) baseline checks
  - Phase C Step 2 (`TgMessageMeta`) completed (SPEC + DEMO + ATOM):
    - spec: `entry/src/main/ets/ui/tg_ui/spec/TgMessageMeta.md`
    - atom: `entry/src/main/ets/ui/tg_ui/atoms/TgMessageMeta.ets`
    - demo: `entry/src/main/ets/ui/tg_ui/demos/TgMessageMetaDemo.ets`
    - anti-jump implementation:
      - `constraintSize(minWidth)` + right alignment
      - optional invisible placeholders for time/status slots
    - status matrix in demo: `none/sending/sent/read/failed` + no-time variants + jump probe
  - Phase C Step 3 (`TgReplySnippet`) completed (SPEC + DEMO + ATOM):
    - spec: `entry/src/main/ets/ui/tg_ui/spec/TgReplySnippet.md`
    - atom: `entry/src/main/ets/ui/tg_ui/atoms/TgReplySnippet.ets`
    - demo: `entry/src/main/ets/ui/tg_ui/demos/TgReplySnippetDemo.ets`
    - iOS mapping anchored to `ChatMessageReplyInfoNode.swift`
    - implemented states:
      - incoming/outgoing
      - long author/preview ellipsis
      - quote mode line limits
      - optional thumbnail
      - narrow/wide container checks
  - Phase C Step 4 (`TgDateSeparator` + `TgUnreadMarker`) completed (SPEC + DEMO + ATOM):
    - spec: `entry/src/main/ets/ui/tg_ui/spec/TgDateSeparator.md`
    - atom(s): `entry/src/main/ets/ui/tg_ui/atoms/TgDateSeparator.ets`
    - demo: `entry/src/main/ets/ui/tg_ui/demos/TgDateSeparatorDemo.ets`
    - iOS mapping:
      - `ChatMessageDateHeader.swift`
      - `ChatUnreadItem.swift`
    - tokenized contracts:
      - centered date capsule
      - centered unread bar
      - narrow/wide width constraints + ellipsis coverage
  - Phase C Step 5 (`TgComposerInput`) completed (SPEC + DEMO + ATOM):
    - spec: `entry/src/main/ets/ui/tg_ui/spec/TgComposerInput.md`
    - atom: `entry/src/main/ets/ui/tg_ui/atoms/TgComposerInput.ets`
    - demo: `entry/src/main/ets/ui/tg_ui/demos/TgComposerInputDemo.ets`
    - tokenized composer contracts:
      - top separator + panel paddings
      - rounded input capsule min/max height
      - attach/emoji/mic/send icon slots
      - optional reply snippet above input row
  - Phase C Step 6 integration baseline added (feature-flagged):
    - `entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets`
    - `entry/src/main/ets/ui/pages/chat/ChatTimelineVO.ets`
    - `entry/src/main/ets/ui/pages/chat/ChatTimelineDataSource.ets`
    - `MainTabsPage` chat `Navigation` now has `navDestination` for `TgChatScreenPage`
    - `ChatListPage` row click opens chat only when `TgUiFeatureFlags.USE_TG_CHAT_V2 = true`
    - AppStorage bridge keys for active chat context:
      - `StorageKeys.ACTIVE_CHAT_ID`
      - `StorageKeys.ACTIVE_CHAT_TITLE`
    - integration passport:
      - `entry/src/main/ets/ui/tg_ui/spec/TgChatScreenIntegration.md`
- Build validation automation added:
  - `scripts/smoke-ui-phase0.ps1`
  - `scripts/smoke-build.ps1`
  - `.github/workflows/smoke.yml` (static checks always, hvigor build optional via repo var + self-hosted runner)
- Phase C.1 progress started:
  - C.1-0 model expansion completed for media fields in message pipeline:
    - `AppState.MessageContent` now includes photo/video/document/audio/voice/sticker/animation/videoNote fields
    - `MessageDto.parseMessageContent(...)` parses TDLib media payloads and captions
    - `messagesReducer.contentFromDto(...)` now maps all media fields into store state
  - C.1-1 `TgPhotoBubble` completed (SPEC + DEMO + ATOM):
    - spec: `entry/src/main/ets/ui/tg_ui/spec/TgPhotoBubble.md`
    - atom: `entry/src/main/ets/ui/tg_ui/atoms/TgPhotoBubble.ets`
    - demo: `entry/src/main/ets/ui/tg_ui/demos/TgPhotoBubbleDemo.ets`
    - iOS constants mapped from `ChatMessageItemCommon.swift` (`radius 16`, `min 170x74`, `max 300x380`)
  - C.1-2 `TgVideoBubble` completed (SPEC + DEMO + ATOM):
    - spec: `entry/src/main/ets/ui/tg_ui/spec/TgVideoBubble.md`
    - atom: `entry/src/main/ets/ui/tg_ui/atoms/TgVideoBubble.ets`
    - demo: `entry/src/main/ets/ui/tg_ui/demos/TgVideoBubbleDemo.ets`
    - includes centered play overlay + bottom-right duration badge + optional caption
  - C.1-3 `TgDocumentRow` completed (SPEC + DEMO + ATOM):
    - spec: `entry/src/main/ets/ui/tg_ui/spec/TgDocumentRow.md`
    - atom: `entry/src/main/ets/ui/tg_ui/atoms/TgDocumentRow.ets`
    - demo: `entry/src/main/ets/ui/tg_ui/demos/TgDocumentRowDemo.ets`
    - includes file icon slot + filename/meta row + optional linear download progress
  - C.1-4 `TgVoiceBubble` completed (SPEC + DEMO + ATOM):
    - spec: `entry/src/main/ets/ui/tg_ui/spec/TgVoiceBubble.md`
    - atom: `entry/src/main/ets/ui/tg_ui/atoms/TgVoiceBubble.ets`
    - demo: `entry/src/main/ets/ui/tg_ui/demos/TgVoiceBubbleDemo.ets`
    - includes play/pause control + generated waveform bars + duration + progress coloring
  - C.1-5 `TgStickerView` completed (SPEC + DEMO + ATOM):
    - spec: `entry/src/main/ets/ui/tg_ui/spec/TgStickerView.md`
    - atom: `entry/src/main/ets/ui/tg_ui/atoms/TgStickerView.ets`
    - demo: `entry/src/main/ets/ui/tg_ui/demos/TgStickerViewDemo.ets`
    - sticker contract: no bubble background, transparent render, fixed-size envelope with aspect-fit

## 4) Current repository state snapshot
- Working tree is not clean (many modified + untracked files).
- Approx pending markers in UI/domain: ~19 TODO in `entry/src/main/ets`.
- This is expected during active refactor; do not assume stable release state.

## 5) Canonical references

### iOS reference (local files)
- Tab bar core:
  - `submodules/TabBarUI/Sources/TabBarController.swift`
  - `submodules/TabBarUI/Sources/TabBarNode.swift`
- Root shell:
  - `submodules/TelegramUI/Sources/TelegramRootController.swift`
- Chat list top bar/header:
  - `submodules/TelegramUI/Components/ChatListHeaderComponent/Sources/ChatListNavigationBar.swift`
- Navigation primitives:
  - `submodules/Display/Source/NavigationBar.swift`
  - `submodules/Display/Source/Navigation/NavigationController.swift`
- Theme/icons mapping:
  - `submodules/TelegramPresentationData/Sources/Resources/PresentationResourcesRootController.swift`

### HarmonyOS official docs
- ArkUI overview (Stage model, component architecture):
  - https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkui-overview/index
- Tabs/navigation patterns:
  - https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-navigation-tabs
- Command line build (hvigor):
  - https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-command-line-building-app
- Node-API callback/threading notes:
  - https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/napi-faq-about-common-basic

## 6) Multi-AI collaboration protocol
1. Before editing, read:
   - `docs/ai/AI_MEMORY.md`
   - `docs/ai/UI_MIGRATION_PLAN.md`
2. Do not change business logic unless task explicitly requires it.
3. UI phases should prioritize:
   - consistency tokens (`ui/theme`)
   - shell components reuse
   - minimal regressions.
4. Every session should append/update:
   - what changed
   - what is blocked
   - next concrete step.

## 7) Next steps (2026-02-26)
- Atom roadmap documented: `docs/ai/ATOM_ROADMAP.md`
- Next phase: **C.1 — Media Bubbles** (active)
  - C.1-0: completed (model/DTO/store mapping)
  - C.1-1: completed (`TgPhotoBubble`)
  - C.1-2: completed (`TgVideoBubble`)
  - C.1-3: completed (`TgDocumentRow`)
  - C.1-4: completed (`TgVoiceBubble`)
  - C.1-5: completed (`TgStickerView`)
  - C.1-6: TgMessageRouter (content-type → bubble atom routing)
  - C.1-7: integration into TgChatScreenPage
- Historical shell polish note: custom `TgTabBar`/top-bar blur work was later superseded by API23 `HdsTabs` for root tabs and shared `TgTopChromeBackground`/`TgTopBar`/`TgChatTopBar` primitives for upper chrome.
- MainTabsPage modified: removed Stack wrapper, using built-in Tabs blur; `.hideToolBar(true)` added to all Navigation blocks
- glass_tab_bg alpha reduced to 70% (light: `#B3F2F2F7`, dark: `#B32C2C2E`)

## 8) Open risks
- Real hvigor build validation still requires DevEco/self-hosted runner environment (`hvigorw` not found in generic PATH here).
- Large active refactor branch: high merge/conflict risk.
- iOS parity must be adapted, not blindly copied (Harmony patterns + safe area + component constraints).

# UI Migration Plan (iOS Reference → HarmonyOS)

Last updated: 2026-05-18

## Canonical contract
- Source of truth: `docs/ai/MASTER_PLAN_TELEGRAM_UI.md`
- If this file conflicts with the master plan, follow the master plan.

## Status sync (2026-03-22)
- Current live Chats runtime path is API23 `HdsTabs`/`HdsNavigation` + `TgChatListNavigationBar` + `TgChatRow` + `TgChatTopBar` + `TgMessageRouter`; the old custom `TgTabBar` is historical.
- `TgTopBar` remains active on secondary tabs (`ContactsPage`, `CallsPage`, `SettingsPage`).
- `TgSearchBar` is no longer an active standalone atom/demo/spec; the live Chats shell uses stock ArkUI `Search` inside `TgChatListNavigationBar`.
- Current runtime gate is `TgUiFeatureFlags.USE_TG_CHAT_V2`; older mentions of `USE_TG_CHATLIST_V2`, `ChatListItem`, `AppTopBar`, or `AppTabBarItem` below should be treated as historical notes.
- `scripts/smoke-ui-phase0.*` validate the active shell path (`ChatListPage` + `TgChatListNavigationBar` + `Search`) rather than removed legacy shell files.
- For post-Phase-E/media-gallery reality, prefer `STATUS.md` + `PROJECT_ANALYSIS.md`; this file remains a migration-plan/history document.
- Per user confirmation on 2026-03-22, the historical device/runtime verification checklists from earlier migration phases should be treated as passed for the current branch state.

## Goal
Bring the app UI to a mature Telegram-like quality level using iOS as reference, while preserving current architecture and staged delivery.

## Scope rules
- **In scope:** visual system, shell/navigation UI, list screen layouts, component consistency.
- **Out of scope (initial phases):** deep domain refactor, TDLib protocol logic rewrites.

---

## Block decomposition (source map)

### A. Design System / Tokens
- iOS refs:
  - `TelegramPresentationData/.../PresentationResourcesRootController.swift`
- Harmony target:
  - `entry/src/main/ets/ui/theme/*`
  - resources: `entry/src/main/resources/base|dark/element/*`

### B. App Shell (Root + Tabs + Top Bar)
- iOS refs:
  - `TabBarUI/Sources/TabBarController.swift`
  - `TabBarUI/Sources/TabBarNode.swift`
  - `TelegramUI/Sources/TelegramRootController.swift`
  - `Display/Source/NavigationBar.swift`
- Harmony target:
  - `entry/src/main/ets/ui/pages/MainTabsPage.ets`
  - reusable shell atoms in `entry/src/main/ets/ui/tg_ui/atoms/*`

### C. Chat List Surface
- iOS refs:
  - `ChatListUI/Sources/*`
  - `TelegramUI/.../ChatListNavigationBar.swift`
- Harmony target:
  - `entry/src/main/ets/ui/pages/chatlist/*`

### D. Contacts / Settings / Calls
- iOS refs:
  - `ContactListUI/Sources/*`
  - `SettingsUI/Sources/*`
  - `CallListUI/Sources/*`
- Harmony target:
  - `entry/src/main/ets/ui/pages/contacts/*`
  - `entry/src/main/ets/ui/pages/settings/*`
  - calls page module (to be added or integrated in tabs)

### E. Auth UI consistency pass
- iOS refs:
  - `AuthorizationUI/Sources/*`
- Harmony target:
  - `entry/src/main/ets/ui/pages/login/*`
  - `entry/src/main/ets/ui/components/login/*`

### F. Chat Screen (later)
- iOS refs:
  - `TelegramUI/Sources/ChatController*.swift`
- Harmony target:
  - `entry/src/main/ets/ui/pages/chat/*` (`TgChatScreenPage` integrated for current MVP path)

---

## Phases (execution order)

## Phase 0 — Foundations (mandatory)
Deliverables:
1. Lock token palette (colors, typography, spacing, radius, icon sizes).
2. Define reusable primitives:
   - `AppTopBar`
   - `AppTabBarItem`
   - `AppListRow` skeleton
3. Add visual QA checklist (density, spacing, contrast, safe area).
   - file: `docs/ai/VISUAL_QA_CHECKLIST.md`

Done when:
- No ad-hoc magic colors/sizes in main tabs and chat list.

Status update (2026-02-25):
- `MainTabsPage` + chat list shell now rely on shared tokens/resources (hex color hardcode removed from Phase 0 files).
- `TgChatRow` is now `@ComponentV2`, and `ChatListPage` still uses `reuseId(...)` for the live chat-list row path.
- Added smoke checks:
  - `scripts/smoke-ui-phase0.ps1`
  - `scripts/smoke-build.ps1`
  - `.github/workflows/smoke.yml` (static always, hvigor build optional via self-hosted runner).
- Remaining blocker: run real hvigor smoke build in DevEco/CI environment where `hvigorw` is available.

## Phase 1 — Shell first (Tabs + TopBar)
Deliverables:
1. Rebuild `MainTabsPage` to strict iOS-like density.
2. Introduce unified top bar component (title + actions + optional search trigger).
3. Ensure safe area behavior top/bottom on phone + tablet.

Done when:
- Tabs and top bar look consistent and production-like.

Status update (2026-02-25):
- Bottom tab bar switched to fixed layout and wrapped with floating glass island backdrop.
- Chats icon resource updated to dedicated chat glyph; tab item badge overlay adjusted to avoid icon drift.
- Unified top bar now applies dynamic status-bar inset (window avoid area), removing header overlap under system status area on main tabs.
- Main shell tabs expanded to iOS-like 4-tab structure (`Contacts`, `Calls`, `Chats`, `Settings`) with `Chats` as default selected tab.
- Top bar and tab bar now use translucent blur treatment (glass background + blur style), replacing fully transparent look.
- Refined translucency pass: lighter blur/alpha and overlay composition so chat list content is visible under top bar while preserving safe interactive areas near floating tab bar.

## Phase 2 — Chat list
Deliverables:
1. Rework chat row visual hierarchy.
2. Unread badge/counters alignment.
3. Loading/empty states with same design language.

Done when:
- Chat list feels visually aligned with shell and no prototype look remains.

Status update (2026-02-25):
- Started strict atom pipeline for chat list (`SPEC → DEMO → ATOM → INTEGRATION`).
- Completed kickoff steps:
  - `TgTokens`: `entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets`
  - `TgIcon`:
    - spec: `entry/src/main/ets/ui/tg_ui/spec/TgIcon.md`
    - atom: `entry/src/main/ets/ui/tg_ui/atoms/TgIcon.ets`
    - demo: `entry/src/main/ets/ui/tg_ui/demos/TgIconDemo.ets`
  - `TgAvatar`:
    - spec: `entry/src/main/ets/ui/tg_ui/spec/TgAvatar.md`
    - atom: `entry/src/main/ets/ui/tg_ui/atoms/TgAvatar.ets`
    - demo: `entry/src/main/ets/ui/tg_ui/demos/TgAvatarDemo.ets`
  - `TgUnreadBadge`:
    - historical standalone spec/atom/demo later removed
    - active unread rendering lives inline in `TgChatMeta` with Telegram iOS compact `K/M` formatting
  - `TgChatMeta`:
    - spec: `entry/src/main/ets/ui/tg_ui/spec/TgChatMeta.md`
    - atom: `entry/src/main/ets/ui/tg_ui/atoms/TgChatMeta.ets`
    - demo: `entry/src/main/ets/ui/tg_ui/demos/TgChatMetaDemo.ets`
    - anti-jump constraints: right-cluster min-width + fixed bottom-row geometry
  - `TgChatRow`:
    - spec: `entry/src/main/ets/ui/tg_ui/spec/TgChatRow.md`
    - atom: `entry/src/main/ets/ui/tg_ui/atoms/TgChatRow.ets`
    - demo: `entry/src/main/ets/ui/tg_ui/demos/TgChatRowDemo.ets`
    - quality extras:
      - jump probe sequence with identical left content and varying right meta states
      - failed-state checks (`failed only` and `failed + unread`)
      - separator strategy set to internal row separator for tg_ui path
  - Integration step:
    - `ChatListPage` now drives tg_ui row path by default; chat-screen navigation is gated by `USE_TG_CHAT_V2`
  - Phase B gate prep:
    - real store-driven row mapping wired:
      - `isMuted` from `updateChatNotificationSettings` (`mute_for`)
      - `sendStatus` from messages + read markers
      - avatar image/online from chat + user state
    - list refresh path improved:
      - `ChatListDataSource.applyDiff(...)` uses granular data change notifications for stable-order updates
      - fallback `onDataReloaded()` only for reorder-heavy diffs

## Phase 3 — Contacts + Settings (+ Calls if enabled)
Deliverables:
1. Apply same list/tokens/top bar system.
2. Remove visual divergence across tabs.

Done when:
- All root tabs share one UI language.

## Phase 4 — Auth consistency pass
Deliverables:
1. Keep auth behavior unchanged.
2. Align fonts, spacing, buttons, color accents with final system.

Done when:
- Auth no longer looks like separate app style.

## Phase 5 — Chat screen (separate track)
Deliverables:
1. Define message list and composer architecture.
2. Implement minimal production chat surface.

Done when:
- End-to-end chat UI is consistent with shell + list design system.

Status update (2026-02-25):
- Phase C / Step 0 completed for text contract before bubble atom:
  - spec added: `entry/src/main/ets/ui/tg_ui/spec/TgMessageTextRules.md`
  - demo added: `entry/src/main/ets/ui/tg_ui/demos/TgMessageTextRulesDemo.ets`
  - message text tokens added in `entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets`:
    - typography (`MSG_TEXT_*`, `MSG_EMOJI_ONLY_*`)
    - colors (`MSG_TEXT_*`, `MSG_LINK_*`)
    - layout (`BUBBLE_MAX_WIDTH_RATIO`, `BUBBLE_PADDING_*`)
  - iOS references locked for this step:
    - `ChatMessageTextBubbleContentNode.swift`
    - `ChatMessageItemCommon.swift`
    - `ChatPresentationData.swift`
- Phase C / Step 1 completed for bubble geometry atom:
  - spec added: `entry/src/main/ets/ui/tg_ui/spec/TgMessageBubbleBase.md`
  - atom added: `entry/src/main/ets/ui/tg_ui/atoms/TgMessageBubbleBase.ets`
  - demo added: `entry/src/main/ets/ui/tg_ui/demos/TgMessageBubbleDemo.ets`
  - token extensions in `TgUiTokens`:
    - `BUBBLE_RADIUS_INCOMING`
    - `BUBBLE_RADIUS_OUTGOING`
    - `MSG_DEMO_WRAP_INJECT_EVERY`
  - demo includes long URL torture (native `BREAK_ALL`) + helper `\u200B` variant
- Phase C / Step 2 completed for message meta cluster:
  - spec added: `entry/src/main/ets/ui/tg_ui/spec/TgMessageMeta.md`
  - atom added: `entry/src/main/ets/ui/tg_ui/atoms/TgMessageMeta.ets`
  - demo added: `entry/src/main/ets/ui/tg_ui/demos/TgMessageMetaDemo.ets`
  - token extensions in `TgUiTokens`:
    - `MSG_META_TEXT_INCOMING`, `MSG_META_TEXT_OUTGOING`
    - `MSG_META_STATUS_PENDING/SENT/READ/FAILED`
    - `MSG_META_MIN_WIDTH`, `MSG_META_ROW_HEIGHT`, `MSG_META_ICON_*`
    - `MSG_META_TIME_PLACEHOLDER_WIDTH`, `MSG_META_STATUS_PLACEHOLDER_WIDTH`
  - anti-jump strategy:
    - fixed min-width right cluster
    - placeholder reserve for hidden time/status slots
- Phase C / Step 3 completed for reply snippet atom:
  - spec added: `entry/src/main/ets/ui/tg_ui/spec/TgReplySnippet.md`
  - atom added: `entry/src/main/ets/ui/tg_ui/atoms/TgReplySnippet.ets`
  - demo added: `entry/src/main/ets/ui/tg_ui/demos/TgReplySnippetDemo.ets`
  - token extensions in `TgUiTokens` for reply block:
    - line geometry, snippet paddings, title/preview typography
    - quote max-lines contract
    - optional thumbnail size/radius
  - iOS reference baseline:
    - `ChatMessageReplyInfoNode.swift`
- Phase C / Step 4 completed for timeline separators:
  - spec added: `entry/src/main/ets/ui/tg_ui/spec/TgDateSeparator.md`
  - atom added: `entry/src/main/ets/ui/tg_ui/atoms/TgDateSeparator.ets`
  - demo added: `entry/src/main/ets/ui/tg_ui/demos/TgDateSeparatorDemo.ets`
  - token extensions in `TgUiTokens`:
    - `DATE_SEPARATOR_*`
    - `UNREAD_MARKER_*`
  - iOS reference baseline:
    - `ChatMessageDateHeader.swift`
    - `ChatUnreadItem.swift`
- Phase C / Step 5 completed for composer atom:
  - spec added: `entry/src/main/ets/ui/tg_ui/spec/TgComposerInput.md`
  - atom added: `entry/src/main/ets/ui/tg_ui/atoms/TgComposerInput.ets`
  - demo added: `entry/src/main/ets/ui/tg_ui/demos/TgComposerInputDemo.ets`
  - token extensions in `TgUiTokens`:
    - `COMPOSER_*` geometry/typography/colors
    - composer icon resources (`attach/send/mic/emoji`)
  - iOS reference baseline:
    - `ChatTextInputPanelNode.swift`
    - `ChatTextInputPanelComponent.swift`
- Phase C / Step 6 integration completed for current real chat route:
  - new chat screen page: `entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets`
  - timeline VO builder: `entry/src/main/ets/ui/pages/chat/ChatTimelineVO.ets`
  - timeline datasource: `entry/src/main/ets/ui/pages/chat/ChatTimelineDataSource.ets`
  - chat list navigation wiring:
    - `MainTabsPage` chat `navDestination` map now exposes `TgChatScreenPage`
    - `ChatListPage` row click opens chat via `NavPathStack.pushPathByName('TgChatScreenPage')` when `USE_TG_CHAT_V2 = true`
  - active chat context keys added:
    - `StorageKeys.ACTIVE_CHAT_ID`
    - `StorageKeys.ACTIVE_CHAT_TITLE`
  - integration spec added:
    - `entry/src/main/ets/ui/tg_ui/spec/TgChatScreenIntegration.md`

---

## Implementation constraints for all contributors
1. Keep refactor incremental (small PR/commit chunks).
2. No direct style constants in pages when token exists.
3. Preserve current store/domain contracts.
4. Update this plan and `AI_MEMORY.md` after each significant session.
5. Follow root `AGENTS.md` atom workflow (`iOS source mapping → passport/spec → demo states → small patch`).

Process assets added (2026-02-25):
- `AGENTS.md` (root protocol for AI/agent UI porting).
- `entry/src/main/ets/ui/tg_ui/` scaffold:
  - `tokens/`, `atoms/`, `molecules/`, `demos/`, `spec/`
- Initial spec templates:
  - `entry/src/main/ets/ui/tg_ui/spec/COMPONENT_PASSPORT_TEMPLATE.md`
  - `entry/src/main/ets/ui/tg_ui/spec/TgChatRow.md`

---

## Build/validation checklist per phase
- DevEco build passes.
- Optional CLI (where available):
  - `hvigorw clean --no-daemon`
  - `hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon`
  - `hvigorw assembleApp --mode project -p product=default -p buildMode=debug --no-daemon`

Reference:
- https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-command-line-building-app

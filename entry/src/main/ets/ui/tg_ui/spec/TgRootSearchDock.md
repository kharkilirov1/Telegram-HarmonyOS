# TgRootSearchDock passport

## Purpose

Add the current Telegram iOS bottom Search dock beside the native root tab
island without replacing HarmonyOS `HdsTabs` or the existing collapsible
ChatList header Search.

## Reference provenance

- Shipped visual truth:
  - `.codex/ui-audit/2026-07-10/iphone16promax-runtime/01-chatlist-dark.jpg`
- Telegram iOS source:
  - `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Components/TabBarComponent/Sources/TabBarComponent.swift:651-669`
    - the idle Search reserves one `barHeight` plus an `8pt` gap;
  - `.../TabBarComponent.swift:891-929`
    - idle Search is a separate square dock; active Search expands to the
      available width and uses a `48pt` height;
  - `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Components/ChatListHeaderComponent/Sources/ChatListNavigationBar.swift:293-381`
    - the upper collapsible Search remains a separate ChatList control.
- HarmonyOS platform source:
  - official `HdsTabs` documentation, `UI Design Kit`, API 23;
  - installed SDK declaration
    `@hms.hds.hdsBaseComponent.d.ets:5185-5276,5337-5430,5760-5807`:
    `HdsTabsFloatingStyle.miniBar`, `HdsTabsMiniBar.miniBarBuilder`, and
    `HdsTabsController.applyMiniBarStyle`.

## Inputs

- `value: string` — shared ChatList query owned by `MainTabsPage`.
- `placeholder: string` — localized Search label.
- `closeText: string` — localized close accessibility label.
- `active: boolean` — collapsed native Search lens or expanded input state.
- `closing: boolean` — keeps the expanded content mounted but disables focus
  and hit-testing during the native reverse transition.
- `focusRequestRevision: number` — one-shot request after native HDS expansion.

Events: `onActivate`, `onChange`, `onSubmit`, `onClose`.

## State matrix

| State | HDS mini bar | Content | Keyboard |
| --- | --- | --- | --- |
| idle | `COLLAPSE` | mounted native Search, visually reduced to its icon | hidden |
| expanding | native HDS transition | icon + clipped input | pending focus |
| active empty | `EXPAND` | icon, placeholder, close | visible |
| active query | `EXPAND` | query, clear/close | visible |
| closing | native reverse transition | query cleared, input inert | focus clear deferred until pointer dispatch ends |
| another tab/chat detail | absent/hidden with root bar | none | unchanged |

## Layout contract

- The material surface and expand/collapse motion belong to native `HdsTabs`.
- The idle dock uses the native root-bar height relationship; it does not add a
  second custom glass background.
- Telegram iOS reserves a `64pt` idle-side delta: a `56pt` square Search lens
  plus an `8pt` gap. On the API23 native HDS runtime the mini surface resolves
  to `48vp`, so this adapter reserves `48vp + 16vp`; the combined delta remains
  `64vp`, while the actual material edge and gap stay owned by HDS.
- In the active state the selected tab lens collapses to `48vp`, matching the
  iOS active Search geometry and releasing the Search field's hit area.
- The native ArkUI `Search` remains mounted in both states. The idle tap
  therefore starts the real input session directly; `onFocus` activates the
  HDS expansion instead of forwarding through a custom imitation control.
- Because keyboard avoidance is window-wide and other surfaces may change it,
  every Search touch-down restores `KeyboardAvoidMode.RESIZE` before focus.
- Native tab content is transparent while Search is active/closing, preventing
  compressed tab labels from bleeding through the expanded HDS material.
- The combined floating group is capped at `500vp`, matching iOS.
- The upper `54vp` collapsible Search lane and filter rail remain intact.
- While this bottom Search owns the IME, the HDS container stays visible so the
  expanded mini bar can sit above the resized content; ordinary keyboard paths
  keep the existing root-bar hiding behavior.

## Accessibility contract

- The native ArkUI `Search` owns both idle and editable-field semantics; no
  duplicate custom Search action may override its value or caret announcement.
- The custom Close lens is one grouped action with an explicit `BUTTON` role
  and localized Close label.
- During the reverse transition the complete dock subtree uses
  `no-hide-descendants`, matching its disabled hit-testing state.
- The custom Chats tab builder publishes a localized label including the live
  unread count. It does not force a second selected/focusable descendant because
  native HDS owns tab selection and focus order.
- Accessibility metadata must not change HDS material, bounds, hit regions or
  expand/collapse timing.

## Token mapping

- geometry: `RootTabBarGeometry.ets` `ROOT_SEARCH_DOCK_*` constants;
- foreground/icon/font: existing `TgUiTokens` Search and chat-control tokens;
- material: `HdsTabs.barFloatingStyle.systemMaterialEffect` only.

## Acceptance

- Idle mini bar is a separate native HDS surface beside the tab island.
- Tap focuses the already-mounted native ArkUI `Search`; its `onFocus` expands
  through `applyMiniBarStyle(HdsBarStyle.EXPAND)` and the system IME follows the
  native input session.
- Query filters the current ChatList and is shared with the upper Search.
- Focusing the upper Search transfers focus ownership by collapsing the lower
  dock without clearing the shared query or dismissing the IME.
- Close clears the query, makes the expanded subtree inert and reverses through
  `COLLAPSE`; focus clears on the next task so the resize cannot make the same
  pointer event fall through into an underlying chat row.
- Switching tabs or opening a chat deterministically resets the dock.
- Historical API23 dark runtime passed query filtering and upper-Search focus
  transfer. A fresh light API24 HAP then passed the complete repeated sequence
  `idle -> active -> close -> active -> close`: both activations focused
  `Search [73,1526][1079,1694]`, resized the app root to
  `[0,137][1320,1799]`, and raised the system keyboard; both closes restored
  the idle `Search [1085,2583][1247,2751]` and full root height without opening
  the row underneath. The WindowManager accessibility dump exposes the active
  Close action as grouped, level `yes`, custom role `button`, and localized
  `Закрыть поиск`. Evidence:
  `.codex/ui-audit/2026-07-19/root-search-dock/api24-repeat-resize-final/`.
- Remaining acceptance gate: a human screen-reader narration pass. Property
  dumps verify metadata but do not prove spoken output.

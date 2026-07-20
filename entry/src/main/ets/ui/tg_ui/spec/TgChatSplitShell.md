# TgChatSplitShell

## Scope

Responsive root shell for the Telegram chat list and chat detail. Native ArkUI owns column adaptation, safe layout and the split separator; custom `tg_ui` continues to own rows, wallpaper, top bars, timeline and composer.

## Reference provenance

- Current Telegram iOS source: `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Sources\TelegramRootController.swift`
  - root navigation uses `NavigationControllerMode.automaticMasterDetail`;
  - the root `TabBarController` is marked as `.master`;
  - regular-width empty detail renders the Telegram wallpaper and `ChatList_StartMessaging` service capsule.
- Current Telegram iOS layout: `C:\Refs\Telegram\Telegram-iOS-current\submodules\Display\Source\Navigation\NavigationLayout.swift`
  - compact width is flat;
  - regular width splits `.master` controllers from detail controllers.
- Current Telegram iOS geometry: `C:\Refs\Telegram\Telegram-iOS-current\submodules\Display\Source\Navigation\NavigationSplitContainer.swift`
  - master width is `min(max(320, floor(width / 3)), floor(width / 2))`;
  - detail owns the remaining width with a one-pixel separator.
- HarmonyOS official docs:
  - `NavigationMode.Auto` switches between stack and split from component width;
  - `navBarWidthRange` and `minContentWidth` protect both columns;
  - `onNavigationModeChange` reports the effective `Stack` / `Split` mode.

## Inputs and ownership

- `MainTabsPage` owns the outer detail `NavPathStack`, effective navigation mode and measured component width.
- Native `HdsTabs` stays inside the outer navigation's master builder so the floating tab island cannot drift into the detail column.
- The Chats tab owns an independent inner stack for master-side routes such as Archive.
- `ChatListPage.chatDetailStack` is the explicit seam used only for opening a chat in the outer detail column.

## State matrix

| Width / state | Master column | Detail column | Root HDS tab island |
| --- | --- | --- | --- |
| Compact, no chat | selected root tab | not rendered | visible |
| Compact, chat open | underlying root tabs | pushed chat fills screen | hidden |
| Split, no chat | selected root tab at iOS-derived width | wallpaper + Start Messaging capsule | visible inside master |
| Split, chat open | chat list remains interactive | chat / profile stack | visible inside master |
| Split, ChatList Search IME | chat list + system IME | unchanged | hidden to clear IME |

## Layout contract

- Minimum master width: `320vp` from current Telegram iOS.
- Preferred master width: one third of the measured component.
- Maximum master width: half of the measured component.
- Minimum detail width: `360vp`, matching the native Navigation viability contract.
- No custom-painted split divider or replacement tab bar.

## Acceptance

- Portrait remains the existing single-column navigation path.
- At an effective wide width, list and chat coexist without overlap.
- Opening Archive stays in the master-side stack; opening a chat uses the detail stack.
- Back from chat returns to the wallpaper placeholder in split and to ChatList in compact.
- Rotation or resize does not lose the active chat or move the HDS island over the detail column.
- `ChatListPage` does not add another `expandSafeArea(TOP)`, but its custom chrome still consumes the platform top inset because the surrounding HDS shell is layout-full-screen. Since `TYPE_SYSTEM` can transiently return zero after split → stack rotation, the page preserves the last real portrait inset across component recreation and resolves it against fresh `windowSizeChange` geometry.
- When the list is already at its start boundary, a top-inset change re-aligns item `0` after the next layout tick; a genuinely scrolled list is not reset. Initial portrait and landscape → chat → portrait → back must have identical title, Search, first-row and HDS island bounds.

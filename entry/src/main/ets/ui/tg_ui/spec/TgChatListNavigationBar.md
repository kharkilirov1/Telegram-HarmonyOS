# TgChatListNavigationBar Component Passport

## 1) Scope
- Atom: `TgChatListNavigationBar`
- Target layer: `atoms`
- Status: `runtime-polish`

## 2) iOS source mapping
- `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\ChatListHeaderComponent\Sources\ChatListNavigationBar.swift`
  - integrated search lane and exact collapse distance (`searchScrollHeight = 54.0`)
  - `searchOffsetFraction` drives Search expansion while filter tabs remain attached below it
- `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\ChatListHeaderComponent\Sources\ChatListHeaderComponent.swift`
  - independent 44pt `GlassContextExtractableContainer` islands for left/right controls
  - collapsed `StoryPeerListComponent` previews live beside the centered title
- `C:\Refs\Telegram\Telegram-iOS-current\submodules\ChatListUI\Sources\ChatListController.swift`
  - left Edit, right Add Story + Compose action ordering
- `C:\Refs\Telegram\Telegram-iOS-current\submodules\ChatListUI\Sources\ChatListControllerNode.swift`
  - list top inset tied to navigation-bar search/header height
- `C:\Refs\Telegram\Telegram-iOS-current\submodules\Display\Source\NavigationBar.swift`
  - translucent navigation background ownership
- `tdlib/td/generate/scheme/td_api.tl`
  - `loadActiveStories(storyListMain)` delivers peers through `updateChatActiveStories`
  - peers are ordered by `(order, story_poster_chat_id)` descending; story ids inside a peer are chronological

## 3) Props / inputs
- `title: string`
- `searchValue: string`
- `searchPlaceholder: string`
- `showEditAction: boolean`
- `editText: string`
- `showComposeAction: boolean`
- `showStoryAction: boolean`
- `storyActionInteractive: boolean` (disabled until the posting controller exists)
- `storyPreviews: TgChatListStoryPreview[]` with real `chatId`, latest `storyId`, avatar, unread and close-friends state
- `storyStripInteractive: boolean` (disabled until the real viewer route exists)
- `searchCollapseProgress: number` (`0...1`)
- `selectedFilterIndex`, localized filter labels, `unreadFilterCount`
- `glassMode: string`
- callbacks:
  - `onEditPress`
  - `onStoryPress`
  - `onComposePress`
  - `onStoryStripPress`
  - `onFilterChange`
  - `onSearchChange`
  - `onSearchSubmit`

## 4) State matrix
- title only
- title + edit
- title + compose
- title + edit + compose
- empty search
- active search text
- Search expanded + filter rail below
- Search fully collapsed + filter rail attached to the title row
- All / Unread / Personal local list filters
- zero / one / three real story previews (never fabricate story peers)
- read / unread / close-friends story rings
- long localized title
- blur / fallback glass mode

## 5) Layout rules
- top safe-area inset is included inside the atom.
- left Edit and right Add Story + Compose reuse the in-chat compact control contract: 38vp visuals, 19vp radius, 20vp icons and a preserved 44vp response region; side insets remain 20vp.
- title stays visually centered; up to three real story previews overlap beside it. Unread peers use the qualified Telegram gradient, read peers use `story_seen`, and close-friends unread peers use the semantic green ring.
- `ChatListPage` requests the real TDLib main story list only after the connection is ready, stores updates immutably, hydrates missing poster chats with `getChat`, and derives avatars through the same `ChatItemVO` identity path as rows.
- preview hit testing and Add Story semantics are disabled while viewer/posting routing is absent, so the UI does not expose no-op controls.
- Search is a centered 40vp capsule inside the exact iOS 54vp collapse lane.
- The centered idle placeholder is a dedicated activation layer: it requests focus for the stable `tg_chat_list_search_input` id, then disappears on native `Search.onFocus` so caret/selection remain fully native. This avoids the API23 full-screen `Refresh` sibling retaining focus.
- At full collapse the invisible Search row switches to `HitTestMode.None`, so it cannot intercept the filter rail occupying the same vertical lane.
- `ChatListPage` observes the documented `TYPE_KEYBOARD` avoid area and asks the root shell to collapse the native HDS bar only after the IME is visible. This keeps focus/IME native and prevents the floating tab island from riding above the resized keyboard viewport; the accepted HDS tuple restores when the keyboard closes.
- The chat-list header owns a dedicated pinned/navy surface and Search owns a lighter chat-list Search surface; these colors are scoped to ChatList instead of changing the global application background. The header surface shrinks by the same 54vp collapse progress as Search, so it never leaves an opaque empty plate over scrolled rows.
- the compact 32vp filter capsule preserves the previous smaller-than-actions ratio and remains visible while Search collapses by 54vp.
- title remains centered independently from left/right action widths.
- Edit and right-side glyphs use the navigation primary foreground, matching the shipped dark iOS glass controls instead of Telegram accent blue.
- no full-width glass plate is rendered behind the islands.
- page offsets list content under the expanded header; normal list scrolling consumes the same 54vp that collapses Search, so messages are not covered.

## 6) Token mapping
- `TOP_BAR_*`
- `SEARCH_BAR_*`
- `CHAT_LIST_PINNED_SURFACE_BG`
- `CHAT_LIST_SEARCH_SURFACE_BG`
- `CHAT_LIST_NAV_SEARCH_AREA_HEIGHT`
- `CHAT_LIST_NAV_FILTER_*`
- `CHAT_LIST_NAV_TOTAL_HEIGHT`
- `TgChatListFilterBar`
- `ICON_RES_SEARCH`
- `ic_chatlist_add_story`
- `ic_chatlist_compose`
- API26 `ImmersiveMaterial(THIN)` / API23 adaptive blur fallback

## 7) Acceptance checklist
- [x] expanded/collapsed hierarchy matches the two supplied iOS runtime screenshots
- [x] title stays centered with compact localized Edit
- [x] Story + Compose share one right glass island
- [x] All / Unread / Personal filters change the real local data set
- [x] Search collapse follows cumulative List scroll offset
- [x] Search tap focuses the native input, raises IME and filters the real chat list on API23
- [x] fully collapsed Search does not intercept filter-rail taps
- [x] API26 native material and API23 fallback are explicit
- [x] story previews use real TDLib active-story state; no fake peers are shown
- [ ] Story viewer and posting actions are wired to real controllers before enabling their hit targets

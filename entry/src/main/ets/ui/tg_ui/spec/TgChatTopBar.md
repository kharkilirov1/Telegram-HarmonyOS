# TgChatTopBar Component Passport

## Scope
- Atom: `TgChatTopBar`
- Target: Telegram iOS current navigation composition on HarmonyOS API 26, with an API 23 runtime fallback.
- UI only: page-owned navigation, profile and search callbacks remain outside the atom.

## Shipped visual truth
- User-provided Telegram iOS captures from iPhone 16 Pro Max, 2026-07-10.
- Private/bot chat: circular back glass, centered title/status glass pill, circular search glass.
- Group chat: circular back glass, centered title/member-count glass pill, circular avatar glass.

## iOS source mapping
- `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\ChatTitleView\Sources\ChatTitleView.swift`
- `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\Chat\ChatNavigationButton\Sources\ChatNavigationButton.swift`
- `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Sources\ChatController.swift`
- `ChatTitleView` owns a `GlassBackgroundView`.
- Current source uses title font 17pt semibold and subtitle font 13pt.
- `updateLayout` builds a 44.0pt glass background, expands its content frame by 12.0pt horizontally and uses half-height corner radius.
- Status/activity transitions use 0.2s ease-in-out and spring motion depending on state.

## Inputs
- `title`, `subtitle`, `subtitleMode`, `showSubtitleSpinner`
- `avatarInitials`, `avatarColorIndex`, `avatarImageSrc`, `isOnline`
- `trailingAction: Search | Avatar | None`
- `glassMode`, `isSearchMode`, `searchQuery`, `topInset`
- Existing back/title/avatar/search/query/close callbacks.

## State matrix
- Private/bot: search trailing action; title tap still opens profile.
- Bot subtitle is the localized bot role and never inherits the ordinary user's online accent.
- Group/channel: avatar trailing action; avatar/title taps open profile.
- Search: center pill is replaced by the existing controlled search field.
- Secondary, online, activity and connection-spinner subtitle states.
- Page-owned presence, activity, member/subscriber and zero-count group/channel copy comes from app-language resources; the atom receives already localized text.
- Image avatar and initials fallback.
- Long title/subtitle ellipsis.
- API 26 native immersive material and API 23 realtime-blur/fallback paths.

## Layout contract
- The chat wallpaper/timeline remains visible between and below the independent capsules; the atom must not render a full-width upper-chrome panel.
- Side controls are compact 38vp circles with a preserved 44vp response region.
- Back, Search and search-mode Close use the theme foreground (`text_primary`: white in dark, black in light), matching the supplied shipped iOS glass controls rather than the Telegram accent used for stateful actions.
- Center glass is 40vp high, explicitly uses `LayoutPolicy.wrapContent`, keeps a 144vp content minimum (164vp including the two 10vp side insets) for short names, and receives 10vp horizontal content padding.
- Long titles grow up to the available center slot and then ellipsize; the inner content must not use `width('100%')`, because that forces every short title to the maximum slot width.
- Equal-size side slots keep the title optically centered.
- Only one trailing control is visible: search for private chats, avatar for groups/channels.
- Secondary full-screen surfaces may request `None`; an inert equal-width side slot is retained so the center capsule does not shift horizontally.
- Title/search state changes use the shared asymmetric opacity/scale transition.

## Material contract
- API 26: `uiMaterial.ImmersiveMaterial`; `THIN` for interactive side controls and `REGULAR` for title/search surfaces.
- API 23-25: adaptive `backgroundBlurStyle` plus a chat-only translucent tint that keeps fast-scrolling message text subordinate inside each capsule; disabled realtime glass uses the opaque fallback token.
- No naked search icon, no flat transparent back/title/avatar surface, and no shared panel behind the capsule cluster.

## Acceptance
- [x] iOS source constants recorded.
- [x] shipped private/group hierarchy represented.
- [x] geometry and colors tokenized.
- [x] search mode and existing callbacks retained.
- [x] API 26 and API 23 rendering paths exist.
- [x] Bot/presence/activity/group/channel subtitle semantics are resource-localized in production.
- [x] API 23 Russian witness shows `zai: бот` and the no-count broadcast label `канал` instead of English `online` / `channel`.
- [ ] API 26 device visual witness (device image is not available locally).
- [ ] user visual acceptance.

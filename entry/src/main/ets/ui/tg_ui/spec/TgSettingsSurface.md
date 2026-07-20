# TgSettingsSurface integration passport

## Reference
- Current iOS settings hierarchy: `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\PeerInfo\PeerInfoScreen\Sources\PeerInfoSettingsItems.swift`.
- Row atom/layout: `TgSettingsRow.md`.

## Data and state
- Profile name, phone and avatar remain sourced from the authenticated `AppState` user.
- Interface language label comes from the active Harmony resource locale rather than a hardcoded English value.
- Current iOS shortcut order is preserved: Saved Messages, Recent Calls, Devices, Chat Folders.
- Current iOS advanced order includes Power Saving before Language; support includes Support, FAQ and Telegram Tips.

## Layout
- HDS owns the native large title and safe-area material.
- Custom Telegram grouped rows retain 44vp compact geometry, 10vp section corners and the native floating-tab bottom inset.
- Recent Calls is the first settings shortcut with a live route and switches to the existing Calls root tab.

## Acceptance
- [x] Profile data and localized language label render from the live account/resources.
- [x] Shortcut/advanced/support rows match the current iOS reference order without clipping.
- [x] Recent Calls switches to the Calls tab.
- [x] Scrolled bottom content stays clear of the floating tab island.

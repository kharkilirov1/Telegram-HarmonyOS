# TgGlassPolicy Runtime Contract

## Scope
- Utility policy (not visual atom): `TgGlassPolicy`
- Purpose: centralize blur quality mode and fallback decisions for glass surfaces.

## Storage key
- `StorageKeys.GLASS_MODE`
  - `auto` (default)
  - `high`
  - `fallback`

## Rules
1. Components do **not** decide blur quality themselves.
2. Glass components read policy and switch:
   - realtime glass in `auto/high`: **in-app surfaces** use `backdropBlur(radius)` +
     visible translucent tint (LESSON 121 — `backgroundBlurStyle` renders an opaque
     plate on emulator GPU paths); **native material paths** (API 26 real device only)
     use `systemMaterial(ImmersiveMaterial)` behind `supportsNativeMaterial()`
   - blur off in `fallback` (opaque/semi-opaque fallback backgrounds)
3. Never combine `renderGroup(true)` with a backdropBlur node (isolates the backdrop layer).
4. Glass atoms use `@StorageLink(StorageKeys.GLASS_MODE)` so downgrade is reactive at runtime without restart.

## Current integrations
- `TgTopBar`
- `TgChatTopBar`
- `TgChatListNavigationBar`
- `TgTopChromeBackground`
- `TgComposerInput`
- `TgComposerEmojiPanel`

Historical: old custom `TgTabBar` integration was superseded by the API23 `HdsTabs` root shell.

## Runtime downgrade trigger
- `EntryAbility.onMemoryLevel` sets `StorageKeys.GLASS_MODE = 'fallback'` on moderate/low/critical memory pressure.

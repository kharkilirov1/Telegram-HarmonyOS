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
   - blur on (`BlurStyle.Thin`) in `auto/high`
   - blur off (`BlurStyle.NONE`) in `fallback`
3. In fallback mode, components must use opaque/semi-opaque fallback backgrounds.
4. Glass atoms use `@StorageLink(StorageKeys.GLASS_MODE)` so downgrade is reactive at runtime without restart.

## Current integrations
- `AppTopBar`
- `TgTopBar`
- `TgTabBar`
- `TgCountryTopOverlay`
- `TgCountryBottomSearchOverlay`

## Runtime downgrade trigger
- `EntryAbility.onMemoryLevel` sets `StorageKeys.GLASS_MODE = 'fallback'` on moderate/low/critical memory pressure.

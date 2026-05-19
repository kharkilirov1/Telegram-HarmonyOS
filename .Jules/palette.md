
## 2024-05-30 - Interactive Icon Wrappers
**Learning:** Icon-only buttons (using TgIcon) in navigation bars frequently omit screen reader context, rendering them silent.
**Action:** Always add `.accessibilityGroup(true)` and `.accessibilityDescription('...')` to the interactive wrapper (`Row` or `Column`) containing the icon.

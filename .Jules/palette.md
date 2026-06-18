## 2024-06-18 - Touch Targets for Icon-Only Buttons in ArkUI
**Learning:** Applying `onClick` directly to `TgIcon` or other inner atoms shrinks the interactive area to the exact icon bounds, making them harder to tap.
**Action:** Always wrap interactive icons in a `Row` or `Column`, apply `onClick` and margins to the wrapper, and attach `.accessibilityGroup(true)` and `.accessibilityDescription()` there.

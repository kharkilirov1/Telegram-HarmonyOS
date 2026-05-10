## 2024-05-24 - ArkUI Icon-Only Button Accessibility Pattern
**Learning:** In HarmonyOS/ArkUI, `TgIcon` components used as interactive buttons (e.g., in top bars) lack semantic meaning for screen readers. Applying `onClick` directly to them or relying on generic descriptions causes poor screen reader experiences.
**Action:** Wrap interactive `TgIcon`s in a `Row` or `Column`, move the `onClick` and margins to the wrapper, and use `.accessibilityGroup(true)` with a clear, hardcoded `.accessibilityDescription()` (e.g., 'Compose', 'Clear search') on the wrapper.

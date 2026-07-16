
## 2024-05-24 - Interactive Component Accessibility in ArkUI
**Learning:** When making icon-only or custom components interactive in ArkUI, applying `.accessibilityGroup(true)` and `.accessibilityDescription()` to the parent wrapper (along with the `onClick` handler) ensures correct screen reader announcements. Wrapping small icons in sized layout containers (like `Row`) maintains the minimum touch target size without visually distorting the icon.
**Action:** Always wrap small interactive icons in `Row` or `Column` sized to at least 44x44vp, move `onClick` handlers to the wrapper, and apply `.clickEffect` and accessibility modifiers to that wrapper.

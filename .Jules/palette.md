## 2024-05-24 - ArkUI Icon Button Accessibility Pattern
**Learning:** In ArkUI, applying interactive handlers and accessibility attributes directly to `TgIcon` causes fragmentation or missing ARIA support.
**Action:** Always wrap interactive icon-only components in a `Row` or `Column`, move the `onClick` handler and margins to the wrapper, and apply `.accessibilityGroup(true)` and `.accessibilityDescription()` to the wrapper.

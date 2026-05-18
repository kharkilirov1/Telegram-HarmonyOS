## 2026-05-18 - Interactive Icon Accessibility in ArkUI
**Learning:** In ArkUI, applying click handlers and accessibility descriptions directly to icon components like `TgIcon` causes redundant screen reader announcements.
**Action:** Always wrap interactive icon-only components in a `Row` or `Column`, move the `onClick` handler and margins to the wrapper, and apply `.accessibilityGroup(true)` and `.accessibilityDescription()` ONLY to the wrapper.

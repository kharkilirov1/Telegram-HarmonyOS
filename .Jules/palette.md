## 2024-06-13 - Icon-only Accessibility Wrappers
**Learning:** In ArkUI, applying click handlers and accessibility modifiers directly to icon-only components (`TgIcon`) inside complex containers can shrink their touch target and cause redundant screen reader announcements.
**Action:** Always wrap interactive icon-only components in a `Row` or `Column`, move the `onClick` and margins to the wrapper, and apply `.accessibilityGroup(true)` and `.accessibilityDescription()` to the wrapper.

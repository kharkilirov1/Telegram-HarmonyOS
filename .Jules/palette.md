## 2024-06-18 - TgChatTopBar Accessibility
**Learning:** Interactive iOS-style capsule navigations built using custom `Row`/`Column` containers shrink touch targets or read poorly in screen readers if accessibility isn't explicitly configured.
**Action:** Ensure `.accessibilityGroup(true)` and `.accessibilityDescription()` are applied to the root interactive component (the capsule container itself, not the inner elements).

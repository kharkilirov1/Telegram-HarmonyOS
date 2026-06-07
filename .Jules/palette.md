## 2024-06-07 - Wrapping Icon-Only Components for Accessibility
**Learning:** In ArkUI, applying click handlers and accessibility modifiers directly to icon-only components (like `TgIcon`) can cause redundant screen reader announcements.
**Action:** Always wrap interactive icon-only components in a layout container (e.g., `Row` or `Column`), move the `onClick` handler and margins to this wrapper, and explicitly apply `.accessibilityGroup(true)` and `.accessibilityDescription('...')` on the wrapper.

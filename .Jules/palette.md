## 2024-06-05 - Missing ARIA Labels on Navigation Elements
**Learning:** Custom interactive ArkUI components using standard layouts (like `Row()` with `onClick`) don't have default accessibility semantics. This leaves screen reader users stranded without navigation cues.
**Action:** Always apply `.accessibilityGroup(true)` and `.accessibilityDescription(...)` to the wrapping interactive component for custom back buttons and navigation items.

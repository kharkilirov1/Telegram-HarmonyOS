## 2024-05-14 - ArkUI Icon-Only Button Accessibility Wrapper
**Learning:** In ArkUI, assigning `.onClick` and accessibility modifiers directly to icon-only components (like `TgIcon`) can cause screen reader redundancy and layout issues.
**Action:** Always wrap icon-only interactive elements in a layout container (like `Row` or `Column`), and move the `.onClick` handler, layout margins, and `.accessibilityGroup(true)` + `.accessibilityDescription()` to the parent wrapper.

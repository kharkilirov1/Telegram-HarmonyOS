## 2024-05-31 - ArkUI Icon-Only Button Accessibility Pattern
**Learning:** When adding accessibility to standalone icon components (like `TgIcon`) that need to be interactive, applying `onClick` and accessibility descriptions directly to the icon fragments the screen reader experience and risks shrinking the touch target.
**Action:** Always wrap interactive icon-only components in a container (like `Row` or `Column`), move the `onClick` and margins to the wrapper, and apply `.accessibilityGroup(true)` and `.accessibilityDescription()` to the wrapper instead.

## 2026-05-16 - Interactive Glass Capsules Accessibility
**Learning:** In ArkUI, complex list items or interactive multi-layered containers (like top bar capsules) cause screen readers to fragment text components. Wrapping them in interactive parent components and applying accessibility properties prevents this.
**Action:** Use `.accessibilityGroup(true)` and `.accessibilityDescription()` directly on the interactive parent wrapper (e.g., Row/Column) for iOS-style capsule layouts.

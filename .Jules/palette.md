## 2024-05-21 - Dynamic Accessibility Descriptions in ArkUI Composer
**Learning:** Icon-only buttons within complex ArkUI components (like the Composer input) require explicit screen reader handling. Furthermore, buttons with dynamic visual states (like switching between Send and Mic based on input) must dynamically compute `.accessibilityDescription()` to accurately announce their current capability to screen readers.
**Action:** Apply `.accessibilityGroup(true)` to interactive wrappers and use ternary operators for `.accessibilityDescription()` on dynamic buttons.

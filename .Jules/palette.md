## 2024-05-24 - Dynamic Accessibility Descriptions in ArkUI
**Learning:** In ArkUI components with dynamic states (like dual-purpose send/mic buttons), screen readers need the `.accessibilityDescription()` to update dynamically based on the current capability.
**Action:** Always use a ternary operator or state-dependent expression for the accessibility description of multi-purpose interactive elements to ensure the announced action matches the visual state.

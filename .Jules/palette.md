
## 2026-06-28 - Dynamic Accessibility for ArkUI Button States
**Learning:** In ArkUI components with dynamic visual states (like a button switching to a loading spinner or checkmark), screen readers will not automatically announce the state change if the text is removed.
**Action:** Dynamically compute `.accessibilityDescription()` (e.g., using a ternary operator) based on the component's state to guarantee screen readers correctly announce the current status/capability.

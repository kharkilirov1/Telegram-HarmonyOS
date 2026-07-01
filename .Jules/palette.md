
## 2026-07-01 - Dynamic Accessibility for Multi-state Buttons
**Learning:** In ArkUI components with dynamic visual states (like loading spinners or dual-purpose buttons), it's important to dynamically compute `.accessibilityDescription()` based on the component's state to guarantee screen readers correctly announce the current status.
**Action:** Apply state-dependent expressions to accessibility modifiers for components handling async states.

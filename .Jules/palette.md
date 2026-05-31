## 2024-05-31 - Dynamic button states require dynamic accessibility descriptions
**Learning:** In ArkUI components with dynamic visual states (like SolidRoundedButton's 'progress' and 'success' states), screen readers will not automatically announce the state change unless `accessibilityDescription` is dynamically computed.
**Action:** Always compute `.accessibilityDescription()` via a ternary operator or state-dependent expression based on the component's state to guarantee screen readers correctly announce the current status/capability.

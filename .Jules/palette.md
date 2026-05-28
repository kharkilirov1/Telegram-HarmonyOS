## 2024-05-28 - Dynamic Accessibility for Dual-Purpose Buttons
**Learning:** In ArkUI components where a single icon button changes its function based on state (like the Composer's Send/Mic button), screen readers will not announce the state change unless the accessibility description is dynamically computed.
**Action:** Always bind the `.accessibilityDescription()` modifier to the same conditional logic that drives the icon visual state to guarantee users relying on screen readers understand the current capability.

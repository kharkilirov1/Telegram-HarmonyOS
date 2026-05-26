## 2024-05-24 - Dynamic Accessibility for Dual-Purpose Buttons
**Learning:** In ArkUI, dual-purpose interactive components (like a send/mic button that changes function based on input state) need dynamically computed accessibility descriptions rather than static ones, otherwise screen readers will announce outdated capabilities.
**Action:** Always compute `.accessibilityDescription(condition ? 'Action A' : 'Action B')` reactively alongside visual state changes for multi-state ArkUI buttons.

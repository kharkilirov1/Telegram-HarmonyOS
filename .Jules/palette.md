## 2024-05-20 - Dynamic Accessibility for Dual-Purpose Buttons
**Learning:** In ArkUI, dual-purpose interactive components (like a combined Send/Mic button that switches based on input text) need their accessibility descriptions to update reactively alongside their visual state so screen readers do not announce stale capabilities.
**Action:** Use ternary operators or state-dependent expressions directly in `.accessibilityDescription()` to keep the screen reader announcement perfectly in sync with the component's current function.

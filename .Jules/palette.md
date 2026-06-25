
## 2024-10-15 - Dynamic Accessibility for Dual-Purpose Buttons
**Learning:** In ArkUI, dual-purpose interactive components (like the composer input that switches between sending messages and recording voice notes) need their accessibility descriptions to dynamically update along with their visual state so screen readers don't announce incorrect capabilities.
**Action:** Use ternary operators or state-dependent expressions in the `.accessibilityDescription()` modifier on the interactive parent wrapper to accurately reflect the current UI state.

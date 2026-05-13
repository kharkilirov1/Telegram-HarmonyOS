## 2024-05-24 - Dynamic Accessibility for Dual-State Buttons
**Learning:** In ArkUI, dual-state buttons (like Send/Mic in the composer) don't automatically update their accessibility tree when their visual state changes. Screen readers will stay silent or announce the wrong state. Furthermore, icon-only buttons need proper accessibility labels.
**Action:** Always compute `.accessibilityDescription()` dynamically based on the same state variables (e.g., `this.canSend()`) used for visual rendering. Apply it alongside `.accessibilityGroup(true)` directly on the interactive parent container.

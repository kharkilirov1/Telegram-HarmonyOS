
## 2024-05-20 - Dynamic Accessibility in Multi-State Buttons
**Learning:** Buttons with dynamic states (like Send vs. Mic in a chat composer) require their `.accessibilityDescription()` to be computed dynamically based on the current state to ensure screen readers announce the correct capability.
**Action:** Apply `.accessibilityGroup(true)` to the interactive wrapper and use a ternary or state-dependent expression for `.accessibilityDescription()` when a component serves dual purposes.

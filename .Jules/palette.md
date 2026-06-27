## 2024-06-27 - Dynamic Accessibility Labels in Dual-Purpose Buttons
**Learning:** Dual-purpose ArkUI buttons (like the Composer input's Send/Mic button) lose accessibility context if the label isn't dynamically updated when the visual state changes. Screen readers need an accurate description of the *current* capability.
**Action:** Use ternary operators or state-dependent expressions in `.accessibilityDescription()` (e.g., `this.canSend() ? 'Send message' : 'Record voice message'`) to guarantee the screen reader correctly announces the active state.

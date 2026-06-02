## 2024-06-02 - Dynamic Accessibility for Dual-Purpose Components
**Learning:** In ArkUI, when a single interactive component swaps its visual identity based on state (like the Composer's Send/Mic button), screen readers will announce outdated information if the accessibility description isn't dynamically bound to the same state condition as the visual icon.
**Action:** Always use state-dependent expressions (e.g., ternary operators) for `.accessibilityDescription()` on multi-purpose controls to guarantee the announced capability matches the current visual state.

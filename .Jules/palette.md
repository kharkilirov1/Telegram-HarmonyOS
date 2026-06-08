## 2024-05-18 - Dynamic Accessibility in Dual-Purpose Buttons
**Learning:** ArkUI components with dynamic visual states (like a dual-purpose Send/Mic button) require their accessibility descriptions to be dynamically computed based on state, otherwise screen readers announce incorrect static capabilities.
**Action:** Used ternary expressions in `.accessibilityDescription()` (e.g., `this.canSend() ? 'Send' : 'Record voice message'`) to guarantee accurate screen reader announcements matching the current visual state.

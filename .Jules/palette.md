## 2024-05-24 - Dynamic Accessibility for Dual-Purpose Buttons
**Learning:** Dual-purpose buttons (like Send/Mic) must have their accessibility descriptions dynamically computed based on the same state condition used for their visual icons to avoid confusing screen readers.
**Action:** Always use a ternary operator or state-dependent expression for `.accessibilityDescription()` when a component's functionality toggles (e.g., `this.canSend() ? 'Send message' : 'Record voice message'`).

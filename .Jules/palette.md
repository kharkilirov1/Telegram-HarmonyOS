## 2024-05-22 - Dynamic Accessibility for Dual-purpose Buttons
**Learning:** In ArkUI components where a single icon button changes purpose based on state (like a mic becoming a send button), screen readers can fail to communicate its current action.
**Action:** Always compute `.accessibilityDescription()` dynamically based on the component's state variables (e.g., `this.canSend() ? 'Send message' : 'Record voice message'`) to guarantee accurate capabilities are announced.

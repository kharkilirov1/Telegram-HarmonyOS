## 2024-06-17 - Dynamic Accessibility for Dual-Purpose Buttons
**Learning:** In ArkUI, when a single interactive component changes its visual state and functionality (like a microphone button changing to a send button), screen readers won't automatically update if the accessibility description is missing.
**Action:** Always use a dynamic expression (e.g., `this.canSend() ? 'Send message' : 'Record voice message'`) for `.accessibilityDescription()` on dual-purpose buttons to ensure screen reader announcements match the current capability.

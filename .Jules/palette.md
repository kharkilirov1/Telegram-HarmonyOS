## 2026-05-17 - Dynamic Accessibility for Dual-Purpose Buttons
**Learning:** In ArkUI, dual-purpose buttons (like Send/Mic) fail to communicate their current capability to screen readers if static descriptions are used.
**Action:** Use dynamic conditionals (e.g., `this.canSend() ? 'Send message' : 'Record voice message'`) inside `.accessibilityDescription()` to ensure accurate announcements.

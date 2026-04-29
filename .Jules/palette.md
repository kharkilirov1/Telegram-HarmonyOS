## 2024-04-29 - Dynamic Accessibility for Dual-Purpose Buttons
**Learning:** In ArkUI, buttons that change their visual state and function dynamically (like a Send/Mic button in a composer) require dynamically evaluated screen reader labels to remain accessible.
**Action:** Use conditional expressions (e.g., `this.canSend() ? 'Send' : 'Record'`) within the `.accessibilityDescription()` modifier on the interactive wrapper to guarantee accurate screen reader announcements reflecting the current capability.

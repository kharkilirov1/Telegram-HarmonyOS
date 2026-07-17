## 2024-05-24 - Dynamic Accessibility Descriptions
**Learning:** Dual-purpose interactive components (like a button that switches between 'Send' and 'Voice Record' based on input state) need dynamic `accessibilityDescription` values to ensure screen readers announce the correct action.
**Action:** Dynamically compute `.accessibilityDescription()` (e.g., via a ternary operator `this.canSend() ? 'Send' : 'Record'`) based on the component's state.

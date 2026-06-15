
## 2024-06-15 - Dynamic Accessibility for Dual-Purpose Components
**Learning:** Dual-purpose interactive elements (like a send/mic button) require dynamic `.accessibilityDescription()` bindings rather than static text, ensuring screen readers accurately announce the current capability (e.g., 'Send message' vs 'Record voice message') as the component state changes.
**Action:** Always compute `.accessibilityDescription()` dynamically for buttons that change their primary function based on user input or state.

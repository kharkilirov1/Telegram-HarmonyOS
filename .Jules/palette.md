## 2026-05-20 - Dynamic Accessibility in ArkUI
**Learning:** In ArkUI, accessibility descriptions must dynamically match the interactive state of the component (e.g., a button that switches between 'Send message' and 'Record voice message'), otherwise screen readers provide incorrect capabilities to users.
**Action:** Always compute `.accessibilityDescription()` using the same conditional logic that drives the visual icon/state (e.g., `this.canSend() ? 'Send' : 'Record'`).

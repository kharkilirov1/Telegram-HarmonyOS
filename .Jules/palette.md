## 2023-10-25 - Dynamic Accessibility Descriptions for Dual-Purpose Buttons
**Learning:** In ArkUI components with dynamic visual states (like dual-purpose Send/Mic buttons), dynamically compute `.accessibilityDescription()` via a ternary operator based on the component's state to guarantee screen readers correctly announce the current status/capability.
**Action:** Applied dynamic `accessibilityDescription` for the Send/Mic button in `TgComposerInput.ets`.

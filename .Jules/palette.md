## 2024-05-30 - Dynamic Accessibility for Dual-State Buttons
**Learning:** In ArkUI, dual-purpose buttons (like Send/Mic) must have their accessibility descriptions dynamically updated based on state. Otherwise, screen readers will announce outdated functionality.
**Action:** Use a ternary operator on `.accessibilityDescription()` to reflect the current action, ensuring the user always knows what the button will do.

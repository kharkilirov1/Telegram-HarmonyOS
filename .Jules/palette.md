## 2024-05-20 - Dynamic Accessibility for Multi-state Buttons
**Learning:** ArkUI components with dynamic visual states (like buttons changing to loading spinners) will lose context for screen readers if the text is replaced by a spinner or icon without an explicit accessibility description.
**Action:** Dynamically compute and apply `.accessibilityDescription()` based on the component's state to guarantee screen readers correctly announce current status and capabilities.

## 2024-07-10 - Dynamic Accessibility Descriptions for Multi-State Buttons
**Learning:** ArkUI components that dynamically change visual states (like replacing text with a loading spinner or success icon) do not automatically announce these state changes to screen readers.
**Action:** Use a dynamic ternary expression in `.accessibilityDescription()` (e.g., `this.buttonState === 'progress' ? 'Loading' : ...`) to ensure screen readers correctly announce the current visual status or capability of the component.

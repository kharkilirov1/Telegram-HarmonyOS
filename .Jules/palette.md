## 2024-10-27 - Dynamic Accessibility Descriptions in ArkUI
**Learning:** When dealing with dynamic button states (like a mic icon turning into a send icon based on text input), ArkUI accessibility descriptions must be bound to the state dynamically (e.g., `.accessibilityDescription(this.canSend() ? 'Send message' : 'Record voice message')`) to ensure the screen reader announces the correct action.
**Action:** Use conditional statements for accessibility descriptions on components with dynamic states.

## 2024-03-24 - Composer Input Accessibility
**Learning:** Icon-only buttons in complex input components need explicit ARIA/accessibility labels. In ArkUI, wrapping interactive components with `.accessibilityGroup(true)` and `.accessibilityDescription()` is required for screen readers. Dynamic descriptions should be used when button roles change based on state.
**Action:** Always add accessibility groupings and descriptions to interactive custom components, particularly icon-only buttons like those in TgComposerInput.

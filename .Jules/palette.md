## 2024-06-14 - Interactive Touch Targets
**Learning:** In ArkUI, accessibility descriptors must be attached to the outermost interactive element (`Row`/`Column` with `.onClick`) that dictates the touch target size, not deeply nested graphical elements.
**Action:** When making custom containers accessible, explicitly apply `.accessibilityGroup(true)` and `.accessibilityDescription()` to the interactive wrapper.

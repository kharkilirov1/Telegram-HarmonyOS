## 2024-05-24 - ArkUI Accessibility Descriptions
**Learning:** In HarmonyOS/ArkUI, screen reader accessibility for interactive components is achieved using `.accessibilityGroup(true)` and `.accessibilityDescription()` on the interactive parent container (like `Row` or `Column`). Dynamic descriptions (e.g., changing between 'Send' and 'Record') work flawlessly when bound to component state.
**Action:** Always apply accessibility modifiers to the outer container that holds the `onClick` handler to ensure screen readers announce the entire touch target correctly, avoiding fragmentation.

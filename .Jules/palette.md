## 2026-05-15 - ArkUI Accessibility
**Learning:** In ArkUI, accessibility modifiers (.accessibilityGroup and .accessibilityDescription) can be applied to interactive layout wrappers (e.g., Row/Column capsules) representing UI regions to give a cohesive screen reader experience and prevent fragmentation.
**Action:** When creating grouped UI components like navigation headers, wrap logical tap targets and apply top-level accessibility attributes instead of decorating the internal atomic visuals.

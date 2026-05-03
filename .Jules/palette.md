## 2026-05-03 - [Accessible ArkUI Icon Buttons]
**Learning:** [In ArkUI, icon-only components that act as buttons must be wrapped in an interactive container (like a Row or Column) to properly accept `.accessibilityGroup(true)` and `.accessibilityDescription()` modifiers without causing screen reader fragmentation or omitting labels.]
**Action:** [Always ensure icon buttons in top bars and navigations have explicit accessibility wrappers rather than attaching interactions directly to the image primitive.]

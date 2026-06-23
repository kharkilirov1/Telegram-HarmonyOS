## 2024-06-23 - Interactive UI Capsules Need Accessibility Grouping
**Learning:** For interactive multi-layered containers like the chat top bar capsules (Back, Title, Avatar), screen readers fragment each text component separately and may not clearly announce the button's purpose without grouping.
**Action:** Always apply `.accessibilityGroup(true)` and `.accessibilityDescription()` to the root interactive container (Row/Column) of interactive capsules to ensure a unified and coherent screen reader announcement.

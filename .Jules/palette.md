## 2024-05-24 - ArkUI List Item Accessibility
**Learning:** By default, screen readers in ArkUI read each text component in a list item separately, which creates a fragmented experience for complex items like chat rows (title, preview, time, etc.).
**Action:** Always group complex UI components by applying `.accessibilityGroup(true)` to the root container and setting a unified, context-rich description using `.accessibilityDescription()`.

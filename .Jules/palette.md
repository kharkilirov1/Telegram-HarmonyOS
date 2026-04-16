## 2024-05-24 - Screen Reader Fragmentation in ArkUI
**Learning:** In ArkUI, complex list items (like chat rows with avatars, text, badges) are read as fragmented, separate elements by screen readers.
**Action:** Apply `.accessibilityGroup(true)` to the root container of complex items and provide a unified `.accessibilityDescription()` to summarize the content concisely for screen reader users.

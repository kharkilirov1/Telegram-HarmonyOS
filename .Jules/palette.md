## 2024-05-24 - ArkUI Accessibility for Complex Lists
**Learning:** In ArkUI, complex list items (like `TgChatRow` with avatars, titles, badges, and previews) cause screen readers to read each internal text node as a separate, fragmented focus element by default. This makes scanning lists very slow.
**Action:** Always apply `.accessibilityGroup(true)` to the root container of complex custom list items to unify them into a single focusable node, and provide a single, well-formatted `.accessibilityDescription(...)` summarizing all vital information (e.g., Title, unread count, and preview text).

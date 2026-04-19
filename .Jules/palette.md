## 2024-05-24 - Screen Reader Fragmentation in ArkUI
**Learning:** By default, ArkUI screen readers can fragment complex list items like `TgChatRow`, reading each text component separately rather than providing a cohesive context.
**Action:** Always apply `.accessibilityGroup(true)` to the root container of complex list rows and use `.accessibilityDescription()` to dynamically compute and supply a meaningful summary (e.g., chat title, unread count, mute status) so the screen reader announces the item as a single, comprehensible unit.

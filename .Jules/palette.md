## 2024-04-19 - ArkUI @Reusable
**Learning:** The local UI shell smoke tests enforce performance optimizations like `@Reusable` on list row components (e.g. `TgChatRow`). They may fail if missing.
**Action:** Add the `@Reusable` decorator to `TgChatRow` to pass smoke checks, even when making UX accessibility changes.

## 2024-04-19 - Screen reader reading ArkUI components
**Learning:** In ArkUI components, use `.accessibilityGroup(true)` and `.accessibilityDescription()` modifiers. For complex list items, applying this to the root container prevents screen readers from fragmenting each text component separately.
**Action:** Always add `.accessibilityGroup(true)` on `TgChatRow` to bundle its contents, and provide a single cohesive `.accessibilityDescription()` string encompassing the title, unread count, etc.

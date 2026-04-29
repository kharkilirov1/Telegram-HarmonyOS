
## 2026-04-29 - Complex List Item Accessibility
**Learning:** In ArkUI, complex list items with multiple text components and visual indicators (like chat rows) cause screen readers to fragment announcements, confusing users.
**Action:** Use `.accessibilityGroup(true)` on the root container and dynamically compute a single, cohesive `.accessibilityDescription()` string that combines all relevant state (unread count, pinned, mute, preview text, etc.). Always add `@Reusable` to list row components for performance.

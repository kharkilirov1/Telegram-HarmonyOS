## 2024-07-04 - ArkUI TgIcon Touch Target Accessibility
**Learning:** When making `TgIcon` interactive (like the search clear button in `TgChatTopBar`), applying `onClick` directly to the icon creates a tiny 18x18vp touch target which is hard to tap.
**Action:** Always wrap interactive `TgIcon` elements in a `Row` or `Column` with padding to expand the touch target area, and apply `.accessibilityGroup(true)` to that wrapper instead of the icon to ensure screen readers announce it as a single interactive element.

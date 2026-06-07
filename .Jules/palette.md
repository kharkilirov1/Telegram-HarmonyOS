## 2025-01-20 - TgChatTopBar Accessibility
**Learning:** Added accessibility attributes directly to capsule wrappers (Row/Column) because wrapping icons causes the touch target to shrink.
**Action:** Always apply accessibility descriptors directly to the element with the padding/margin/click handlers, rather than inner children.

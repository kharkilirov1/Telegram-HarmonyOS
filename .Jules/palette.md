## 2024-05-24 - Dynamic Action Button Accessibility
**Learning:** Dual-purpose buttons (like Send vs Mic based on text input) need dynamic `.accessibilityDescription()` to accurately announce their current capability to screen readers.
**Action:** Always compute the accessibility description using the same state or logic that drives the visual icon change.

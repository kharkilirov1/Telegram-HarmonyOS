## 2024-05-24 - Dynamic Accessibility for Dual-Purpose Actions
**Learning:** When a button toggles functionally based on input state (e.g., swapping a Mic icon for a Send icon when text is entered), static accessibility descriptions become inaccurate and disorienting for screen readers.
**Action:** Always dynamically compute `.accessibilityDescription()` based on the same state variables that govern the visual presentation of dual-purpose buttons to guarantee correct announcements.

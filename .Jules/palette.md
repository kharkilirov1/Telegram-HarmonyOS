## 2024-06-19 - Dynamic Button Accessibility
**Learning:** Dynamic buttons like Send/Mic must use state-dependent expressions in their accessibility descriptions to ensure accurate screen reader announcements.
**Action:** Always verify if a button's visual icon changes based on state, and if so, compute its `accessibilityDescription` dynamically using a ternary or state-dependent expression.

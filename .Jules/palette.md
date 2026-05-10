## 2024-05-24 - Dual-Purpose Button Accessibility
**Learning:** Dual-purpose buttons (like Send/Mic) fail to convey their current function to screen readers if the accessibility description is static or missing. In ArkUI, the accessibility description must be dynamically computed based on the same state variable that drives the visual icon.
**Action:** When creating dual-purpose interactive components, always bind the `.accessibilityDescription()` to a ternary or computed property that reflects the current icon's meaning.

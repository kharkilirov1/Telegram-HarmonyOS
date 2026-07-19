
## 2024-07-19 - Screen reader accessibility in Top Bar actions
**Learning:** The ArkUI custom top bar implementations containing isolated interactive components for back navigation, search, and profile needed explicit accessibility metadata since they don't use standard system top bar elements. Without this, screen readers provide no context when focusing on these touch targets.
**Action:** Apply `.accessibilityGroup(true)` and `.accessibilityDescription()` to all interactive action targets within custom navigation bars.

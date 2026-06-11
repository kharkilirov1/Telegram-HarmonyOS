
## 2024-06-11 - Grouping Interactive Containers in ArkUI
**Learning:** Applying accessibility attributes to nested icon wrappers shrinks touch targets if not properly managed. For complex containers (like top bar capsules), adding `.accessibilityGroup(true)` on the root interactive element prevents screen reader fragmentation.
**Action:** Always wrap standalone icons in `Row`/`Column` and move click handlers/margins to the wrapper. Use dynamic state for `.accessibilityDescription()` to accurately reflect the element's status.

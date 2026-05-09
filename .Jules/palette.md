## 2024-05-09 - Accessible Icon Buttons
**Learning:** Interactive icon-only components without parent layouts cause fragmented or missing screen reader announcements.
**Action:** Always wrap interactive icon-only components in a layout container (like Row), move click handlers and margins to the wrapper, and apply .accessibilityGroup(true) and .accessibilityDescription() to the wrapper.

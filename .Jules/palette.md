## 2024-05-18 - Component Action Containers Accessibility
**Learning:** Generic, highly-reusable UI components (like top bar slots) without dynamic descriptions can result in unhelpful screen reader announcements. Interactive wrapper containers for icon-only components must handle their own touch target sizing and accessibility to prevent fragmentation.
**Action:** Explicitly apply `.accessibilityGroup(true)` and `.accessibilityDescription()` to the interactive parent wrapper (e.g., Row/Column) for complex UI interactions.


## 2024-05-24 - Grouping multi-layered interactive containers for screen readers
**Learning:** Complex interactive layout containers (like top bar capsules containing titles and subtitles) fragment screen reader announcements if not grouped.
**Action:** Always apply `.accessibilityGroup(true)` to the root interactive container (e.g., Row/Column) and provide a comprehensive `.accessibilityDescription()` (e.g., combining title and subtitle) to ensure cohesive screen reader announcements.

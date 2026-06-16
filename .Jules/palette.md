## 2026-06-16 - Accessible Interactive Top Bar Capsules
**Learning:** In ArkUI, complex multi-layered capsules (like top bars) need `.accessibilityGroup(true)` on their root wrapper to prevent fragmented screen reader announcements, and icons acting as buttons should be wrapped in interactive Rows to avoid shrinking touch targets.
**Action:** Always apply accessibility descriptors directly to the parent interactive container (like Row/Column) for ArkUI capsules and icon buttons.

## 2026-06-27 - Accessible Interactive Capsules
**Learning:** When building interactive, custom capsule components in ArkUI (like those in `TgChatTopBar`), screen readers may not announce them correctly without explicit accessibility attributes.
**Action:** Always apply `.accessibilityGroup(true)` and a descriptive `.accessibilityDescription()` directly to the interactive wrapper (e.g., the `Row` or `Column` with the `onClick` handler) to ensure proper screen reader support.

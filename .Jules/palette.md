## 2024-06-17 - Added Accessibility to Chat Top Bar Capsules
**Learning:** To ensure screen readers announce interactive components correctly in HarmonyOS without fragmenting child texts or shrinking the touch target, `.accessibilityGroup(true)` and `.accessibilityDescription()` must be applied to the outer interactive container (like `Row` or `Column`), not inner `Text` or `TgIcon` components.
**Action:** Applied this pattern to all interactive capsules in `TgChatTopBar.ets`.

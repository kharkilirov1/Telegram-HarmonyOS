## YYYY-MM-DD - [Accessibility in Glass Components]
**Learning:** Custom interactive ArkUI components built with complex multi-layered wrappers (like iOS-style glass capsules) need explicit `accessibilityGroup(true)` and `accessibilityDescription()` on the root interactive container. Relying on inner elements like `Text` or `TgIcon` results in fragmented or missing screen reader announcements.
**Action:** Always apply `.accessibilityGroup(true)` and a computed `.accessibilityDescription()` to the outermost `Row` or `Column` that handles the `onClick` event in custom interactive components.

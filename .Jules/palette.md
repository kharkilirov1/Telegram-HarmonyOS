## 2024-07-09 - Accessibility for Top Bar Actions
**Learning:** Interactive navigation bar slots (like Edit and Compose) must explicitly define accessibility groups and descriptions on their touch-target wrappers (Row/Column) to ensure screen readers announce their function clearly, as icon-only or generic text elements alone aren't always descriptive enough for context.
**Action:** Added `.accessibilityGroup(true)` and `.accessibilityDescription()` to the 'Edit' and 'Compose' actions in `TgChatListNavigationBar` to ensure accessible navigation.

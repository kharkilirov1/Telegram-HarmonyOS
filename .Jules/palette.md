
## 2024-05-18 - Interactive Element Accessibility
**Learning:** In complex top bar layouts (like `TgChatTopBar`), `.accessibilityGroup(true)` and `.accessibilityDescription()` must be explicitly applied to the interactive parent wrappers (like `Row` or `Column`), NOT just on the inner visual elements like icons or text. For icon-only actions inside rows, the wrapper needs the margin and onClick handlers alongside the accessibility decorators to avoid redundant announcements.
**Action:** Always verify that interactive custom containers aggregate accessibility focus so screen readers announce the action properly instead of splitting inner visual descriptions.

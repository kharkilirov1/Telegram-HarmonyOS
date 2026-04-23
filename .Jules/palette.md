## 2024-05-18 - TgIcon Accessibility
**Learning:** In ArkUI, explicitly add `.accessibilityGroup(true)` and `.accessibilityDescription()` directly to icon-only buttons (e.g., `TgIcon`) within custom interactive containers. Relying solely on the encompassing container's accessibility grouping will cause the child icons to be skipped by screen readers.
**Action:** When adding icon-only controls, always ensure they are accessible. For reusable components like `TgIcon`, allow passing an optional accessibility description.

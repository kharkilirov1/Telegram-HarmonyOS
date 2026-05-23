## 2024-05-24 - Accessible Icon Buttons in ArkUI
**Learning:** Icon-only buttons (like `TgIcon` with `onClick`) are often skipped or read generically by screen readers in ArkUI if not grouped.
**Action:** Always wrap interactive icon-only components in a `Row` or `Column`, move the `onClick` and margins to this wrapper, and apply `.accessibilityGroup(true)` and `.accessibilityDescription('...')` to the wrapper to provide a clear ARIA-equivalent label for screen readers.

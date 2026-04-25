
## 2024-05-24 - Accessibility Grouping for Top Navigation Bars in ArkUI
**Learning:** Top navigation bars in ArkUI frequently use small nested structures (e.g. `Row > TgIcon` or `Stack > TextInput`). By default, screen readers may miss these or fail to provide adequate contextual descriptions for icon-only navigation controls (like "Back", "More options", "Compose") unless grouped.
**Action:** Always apply `.accessibilityGroup(true)` along with `.accessibilityDescription('Label')` to the outermost interactive wrapper (e.g., the `Row` or `Column` handling the `.onClick()`) rather than the inner visual components (`TgIcon`/`Image`). This ensures the full touch target acts as a single, clearly-labeled element for screen readers.

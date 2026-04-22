## 2024-10-24 - Accessibility Grouping for Top Bar Capsules
**Learning:** In complex interactive multi-layered containers like top bar capsules in ArkUI, applying `.accessibilityGroup(true)` to the root container prevents screen readers from fragmenting child text components. For icon-only buttons (like `TgIcon`), `.accessibilityDescription()` must be explicitly added to ensure they aren't skipped.
**Action:** Always add `.accessibilityGroup(true)` to the root container of capsules to group text, and explicitly apply `.accessibilityDescription()` to any child icon-only components.

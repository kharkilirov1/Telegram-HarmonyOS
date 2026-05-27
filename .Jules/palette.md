## 2024-05-18 - Interactive Top Bar Accessibility
**Learning:** In ArkUI, complex multi-layered components (like top bar capsules) need `.accessibilityGroup(true)` and `.accessibilityDescription()` on their outermost interactive parent (the one with the `onClick` handler) to prevent screen readers from fragmenting inner texts or missing icon intents entirely.
**Action:** Always add ARIA-equivalent modifiers to `Row` / `Column` wrappers when they handle the `onClick` event in custom navigation components.

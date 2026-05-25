## 2024-05-25 - ArkUI Screen Reader Fragmenting
**Learning:** ArkUI screen readers can fragment multiple text components or complex layers inside interactive containers if not explicitly grouped.
**Action:** Always apply `.accessibilityGroup(true)` and a specific `.accessibilityDescription(...)` to the outermost interactive wrapper (e.g., Row or Column) for custom top bar navigation actions, instead of letting the screen reader try to parse inner components.

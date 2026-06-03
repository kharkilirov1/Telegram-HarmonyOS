## 2024-06-03 - Accessible custom touch areas
**Learning:** In ArkUI, when making custom container components interactive, `.accessibilityGroup(true)` and `.accessibilityDescription()` must be explicitly applied to the parent interactive wrapper (e.g. Row or Column) so that screen readers don't fragmented read inner components, and so the whole container is properly announced.
**Action:** Always apply `.accessibilityGroup(true)` to interactive Row/Column wrappers representing icon buttons or capsules.

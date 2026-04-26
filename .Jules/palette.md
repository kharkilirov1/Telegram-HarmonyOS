## 2024-10-24 - ArkUI List Item Accessibility Fragmenting
**Learning:** In ArkUI, complex list items (like chat rows) cause screen readers to fragment each internal text component and read them separately, leading to a disjointed and confusing experience.
**Action:** Always apply `.accessibilityGroup(true)` and a dynamically computed `.accessibilityDescription()` to the root container of complex interactive items to synthesize the item's state into a single cohesive announcement.

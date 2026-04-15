## 2026-04-15 - Prevent Screen Reader Fragmentation in ArkUI List Items
**Learning:** In ArkUI, complex list items (like chat rows with avatars, titles, previews, badges) will be read out loud as fragmented individual text components by screen readers, creating a disjointed user experience.
**Action:** Use `.accessibilityGroup(true)` on the root container of the list item and synthesize a cohesive `.accessibilityDescription()` to ensure the screen reader announces the entire item meaningfully as a single unit.

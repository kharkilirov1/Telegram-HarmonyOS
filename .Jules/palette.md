## 2026-04-17 - ArkUI Complex List Item Accessibility
**Learning:** In ArkUI, complex list items (like `TgChatRow` which has many distinct Text, Image, and Icon components) will be read out disjointedly by the screen reader if left alone.
**Action:** Use `.accessibilityGroup(true)` on the root container of the component, and supply a dynamically computed, combined `.accessibilityDescription(...)` so the user hears a single, coherent summary of the item.

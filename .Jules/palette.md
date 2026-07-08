## 2024-05-18 - Accessible Top Bar Capsules in ArkUI
**Learning:** Applying accessibility attributes (.accessibilityGroup and .accessibilityDescription) to the parent interactive container (like a Row or Column capsule) is critical in ArkUI. It ensures the screen reader announces the entire button's context and purpose as a single interaction, preventing fragmentation of text and icons.
**Action:** Always apply accessibility modifiers to the root container of custom interactive elements, especially icon-only and complex text layouts.


## 2024-06-12 - Dynamic Accessibility for Dual-Purpose Inputs
**Learning:** In ArkUI, when an icon button serves dual purposes based on state (like a composer's send/mic button), its accessibility description must be dynamically computed to reflect its current capability, preventing screen reader confusion.
**Action:** Use ternary operators within `.accessibilityDescription()` on the interactive parent container to ensure the announced label perfectly matches the current visual state.

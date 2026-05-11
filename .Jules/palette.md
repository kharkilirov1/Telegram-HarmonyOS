## 2024-05-11 - Add accessibility to composer action buttons
**Learning:** In ArkUI components, when an icon-only button is implemented as a generic `Row` containing a `TgIcon`, screen readers cannot announce its function without explicit accessibility metadata. If the button has dynamic states (like Send vs Mic), the accessibility description must compute dynamically.
**Action:** Apply `.accessibilityGroup(true)` and a computed `.accessibilityDescription()` to the interactive wrapper container (e.g., `Row`) of icon-only controls.

## 2024-05-24 - Dynamic Accessibility for Dual-Purpose Actions
**Learning:** Found that dual-purpose buttons like the Composer's Send/Mic button in this app lack dynamic accessibility descriptions. Screen readers may misinterpret the button's action if the description doesn't update alongside the visual state.
**Action:** Always use state-dependent expressions (like ternary operators) for `.accessibilityDescription()` on buttons that change their primary function based on user input.


## 2024-05-24 - Screen Reader A11y and Touch Targets in App Bars
**Learning:** Icon-only interactive elements in top bars, such as search or back buttons, often lack adequate touch target sizes (e.g., 44x44vp) and screen reader support out of the box in ArkUI. Direct clicks on `Image` components can be frustrating to tap and offer no audible context for accessibility tools.
**Action:** Always wrap small interactive icons in appropriately sized layout containers (like `Row`) with `clickEffect`. Apply `.accessibilityGroup(true)` and `.accessibilityDescription('...')` to this wrapper so the touch target is easily tappable and properly announced by screen readers.

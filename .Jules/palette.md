## 2024-05-24 - Initial Memory

## 2024-05-24 - Screen Reader optimization for Capsule Navigation and Icon Buttons
**Learning:** When making icon-only components interactive, screen readers announce them poorly. Additionally, custom interactive container components (like top bar capsules) fragment text reading if not grouped.
**Action:** Always wrap interactive icon-only components in a `Row`/`Column`, moving the `onClick` and margins to the wrapper. Apply `.accessibilityGroup(true)` and a hardcoded `.accessibilityDescription()` to the interactive wrapper.

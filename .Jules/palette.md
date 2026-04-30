## 2026-04-30 - ArkUI Icon Accessibility
**Learning:** In ArkUI, when making icon-only custom components interactive, the onClick handler and margins must be moved to a parent container (like Row/Column). Applying accessibility attributes directly to the icon can cause issues or redundant announcements; they must be placed on the interactive parent wrapper.
**Action:** Always wrap interactive icon-only components in a layout container, move onClick handlers/margins to the wrapper, and apply `.accessibilityGroup(true)` and `.accessibilityDescription()` to that wrapper.

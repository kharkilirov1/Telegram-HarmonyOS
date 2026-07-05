
## 2024-07-05 - Accessibility modifiers for interactive top bar capsules
**Learning:** In ArkUI, when making custom container components interactive, apply accessibility attributes to the interactive parent wrapper (e.g., Row/Column). If an icon-only component needs to be interactive, wrap it in a container, move the onClick handler and margins to the wrapper, and apply accessibility attributes there to avoid redundant screen reader announcements and prevent the touch target from shrinking.
**Action:** Always wrap interactive icon-only components in a container (Row/Column), move margins and onClick handlers to the container, and add `.accessibilityGroup(true)` and `.accessibilityDescription(...)` to ensure correct screen reader behavior and preserve touch target sizes.

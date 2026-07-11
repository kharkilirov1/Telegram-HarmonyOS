
## 2024-05-24 - Touch Targets and Accessibility in ArkUI
**Learning:** In ArkUI, applying `onClick` directly to an `Image` or small component often shrinks its touch target area to the component's boundaries.
**Action:** When adding interactivity and accessibility to icon-only components, always wrap them in an appropriately sized layout container (like `Row` or `Column`, typically 44x44), move the `onClick` handler and any margins to the wrapper, and apply `.accessibilityGroup(true)` and `.accessibilityDescription()` to the wrapper.

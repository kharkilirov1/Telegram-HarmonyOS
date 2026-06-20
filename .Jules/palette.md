## 2024-06-20 - Adding Accessibility Groups to Interactive UI Components
**Learning:** When making complex UI containers like top bars interactive, applying `.accessibilityGroup(true)` and `.accessibilityDescription()` to the touch target (the interactive wrapper) ensures screen readers do not fragment the child components while keeping the touch target size optimal.
**Action:** Always apply accessibility descriptors directly to the element with the `onClick` handler, especially for icon buttons or interactive rows.

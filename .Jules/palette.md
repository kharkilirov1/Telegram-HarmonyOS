## 2024-06-05 - ArkUI Component Accessibility Properties
**Learning:** ArkUI interactive top bar elements (capsules, icons) need explicit `.accessibilityGroup(true)` and `.accessibilityDescription(...)` wrappers, especially when they act as icon-only buttons or interactive groups, to ensure screen readers announce them properly instead of ignoring them.
**Action:** Always wrap interactive `TgIcon`s in a `Row` to handle `onClick` and apply accessibility properties to the `Row`. Apply accessibility properties directly to custom interactive containers.

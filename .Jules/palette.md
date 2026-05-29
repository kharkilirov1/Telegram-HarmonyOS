## 2024-05-29 - Accessible Icon Buttons in ArkUI
**Learning:** When making icon-only components (like TgIcon) interactive, applying onClick and accessibility modifiers directly to the icon can cause redundant screen reader announcements and shrink the touch target.
**Action:** Wrap the icon in a layout container (like Row or Column), move the onClick handler and margins to the wrapper, and apply .accessibilityGroup(true) and .accessibilityDescription() to the wrapper.

## 2024-05-11 - ArkUI Icon-Only Button Accessibility
**Learning:** When adding accessibility to interactive, icon-only ArkUI components (`TgIcon`), applying `.accessibilityGroup(true)` and `.accessibilityDescription()` directly to the icon can sometimes result in poor screen reader announcements or touch target issues.
**Action:** Explicitly wrap the icon in a parent container (like `Row` or `Column`), move the `onClick` handler and relevant margins to this wrapper, and apply the accessibility attributes to the wrapper instead.

## 2024-05-24 - Screen Reader Labels for Icon Buttons
**Learning:** Icon-only buttons (like attach, emoji, mic/send, back) in ArkUI do not provide inherent meaning to screen readers unless explicitly annotated. Using `.accessibilityGroup(true)` combined with `.accessibilityDescription()` ensures these critical interactive elements are usable by visually impaired users.
**Action:** Always add `.accessibilityGroup(true)` and `.accessibilityDescription($r("..."))` to icon-only buttons or interactive `Row`/`Stack` components that act as buttons.

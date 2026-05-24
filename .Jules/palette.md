## 2024-05-24 - Accessibility Modifiers in ArkUI
**Learning:** Adding accessibility descriptors to interactive ArkUI custom components is necessary for screen readers. Using `.accessibilityGroup(true)` and `.accessibilityDescription()` on the outer interactive container prevents screen readers from separately announcing nested elements (e.g., text, icon).
**Action:** Apply accessibility attributes to the clickable container in `TgChatTopBar.ets`.

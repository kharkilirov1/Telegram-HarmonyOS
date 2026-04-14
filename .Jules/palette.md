## 2026-04-14 - Accessible ArkUI List Items
**Learning:** For complex list items in ArkUI (like TgChatRow), applying `.accessibilityGroup(true)` and dynamically computing `.accessibilityDescription()` on the root container prevents screen readers from fragmenting the item into multiple disjointed elements.
**Action:** Always wrap complex list items with an accessibility group and a comprehensive description.

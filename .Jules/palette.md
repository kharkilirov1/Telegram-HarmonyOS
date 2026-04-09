## 2024-04-09 - Top Bar Actions Missing Screen Reader Feedback
**Learning:** Icon-only actions in custom top bars (`TgTopBar`) lack inherent accessibility descriptions, making navigation difficult for screen reader users. The application strings for standard accessibility hints like `accessibility_back` and `accessibility_more` exist in the resources but are sometimes unused.
**Action:** Always add `.accessibilityGroup(true)` and `.accessibilityDescription(...)` to icon-only interactive rows or containers, reusing existing `app.string.accessibility_*` tokens when available.

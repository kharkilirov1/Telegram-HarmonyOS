
## 2024-05-30 - Interactive Icon Touch Targets & Accessibility in ArkUI
**Learning:** Adding `.onClick` and accessibility descriptions directly to small icon components (like `Image` or `TgIcon`) without wrappers results in poor touch targets (<44vp) and can cause redundant announcements.
**Action:** Always wrap interactive icon-only elements in a layout container (e.g., `Row` with 44x44 size), move margins/click handlers to the wrapper, and apply `.accessibilityGroup(true)` and `.accessibilityDescription()` to the wrapper.

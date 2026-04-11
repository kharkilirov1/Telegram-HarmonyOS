## 2025-04-10 - Accessibility for Icon-only Interactive Elements in ArkUI
**Learning:** Icon-only interactive elements (like custom capsules acting as buttons using `.onClick()`) in ArkUI do not implicitly inherit screen-reader friendly descriptions based on child content like icons, which makes them inaccessible.
**Action:** Always wrap these elements, or attach directly to them, `.accessibilityGroup(true)` to merge focus boundaries and provide `.accessibilityDescription($r('app.string...'))` using localized resources for correct screen-reader announcements.

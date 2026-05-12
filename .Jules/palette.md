## 2026-05-12 - Accessibility Modifiers in ArkUI Top Bars
**Learning:** Screen readers announce ArkUI text components individually inside complex containers (like the top bar capsule) unless explicitly grouped. The search icon and input field also require proper accessibility labels for non-visual navigation.
**Action:** Add `.accessibilityGroup(true)` and a dynamic `.accessibilityDescription()` to the title capsule. Add accessibility attributes to the search close button and text input.

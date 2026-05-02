## 2026-05-02 - Adding accessibility tags to Icon Buttons
**Learning:** In ArkUI, screen readers fragment isolated components. Interactive icon-only buttons need standard accessibility modifiers.
**Action:** Apply .accessibilityGroup(true) and .accessibilityDescription() to wrapper components that handle interaction, rather than individual icons.

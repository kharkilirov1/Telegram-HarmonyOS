## 2026-06-10 - Interactive Container Accessibility
**Learning:** When creating custom interactive container components (like top bar capsules) in ArkUI, applying .onClick() without accessibility descriptors leaves screen readers unable to identify their purpose or boundaries.
**Action:** Always apply .accessibilityGroup(true) and a dynamic .accessibilityDescription() to the outermost interactive container rather than its inner components.

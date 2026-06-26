
## 2026-06-26 - Accessibility for Top Bar Capsules
**Learning:** In ArkUI, complex interactive containers (like top bar capsules) need explicit accessibility groups on their wrapper to prevent screen readers from missing their purpose or fragmenting content, especially when they act as icon-only buttons.
**Action:** Always add `.accessibilityGroup(true)` and a hardcoded `.accessibilityDescription` (to avoid compilation risks) on interactive parent wrappers that don't have visible text labels.

## 2024-06-21 - Dynamic Accessibility Descriptions in UI Elements
**Learning:** In ArkUI components, components with dynamic visual states or user-specific data (like user names/titles in avatars) require computed/dynamic accessibility descriptions (e.g., using ternary operators or variables) instead of hardcoded generic ones.
**Action:** Always compute `.accessibilityDescription()` dynamically based on the component's state or provided properties (like title/subtitle strings) to guarantee screen readers correctly announce the contextual meaning.

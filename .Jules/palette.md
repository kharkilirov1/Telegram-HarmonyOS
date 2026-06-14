## 2024-06-14 - Adding accessibility to custom interactive capsules
**Learning:** In ArkUI, complex custom interactive components (like capsules holding icons/avatars) are not automatically announced by screen readers. Applying accessibilityGroup and accessibilityDescription directly to the clickable container prevents fragmented readouts and properly communicates the interaction purpose.
**Action:** Always verify that custom icon or container buttons have explicit accessibility descriptors applied to their root clickable node.

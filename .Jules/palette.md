
## 2024-07-16 - Increased Touch Target and A11y for Top Bar Icons
**Learning:** Raw Image components in ArkUI used for interactive icons lack adequate touch target size (44x44) and standard interaction feedback (`clickEffect`), leading to poor tap reliability and missing screen reader announcements.
**Action:** Wrap interactive icon-only components in layout containers (like `Row`) with minimum 44x44 dimensions, move the `onClick` handler and margins to the wrapper, apply `.clickEffect()`, `.accessibilityGroup(true)`, and hardcoded string literals for `.accessibilityDescription()`.

## 2024-07-10 - Touch Targets for Icon-Only Components
**Learning:** Applying `onClick` directly to small `Image` or `TgIcon` components reduces the interactive touch area, causing UX regressions and making the UI harder to interact with.
**Action:** Always wrap interactive icon-only components in layout containers (like `Row` or `Column`) sized to a minimum of 44x44vp. Move `onClick`, margins, and accessibility modifiers to this wrapper container to ensure adequate touch targets and avoid redundant screen reader announcements.

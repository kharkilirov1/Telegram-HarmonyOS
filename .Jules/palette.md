## 2024-05-24 - Grouping Interactive Glass Capsules
**Learning:** In complex interactive containers (like iOS-style glass capsules in `TgChatTopBar`), applying click handlers without `.accessibilityGroup(true)` on the parent wrapper causes screen readers to fragment each inner text or icon component, creating a disjointed experience.
**Action:** Always apply `.accessibilityGroup(true)` to the interactive parent wrapper (e.g., Row/Column) of multi-layered custom UI controls to consolidate focus and announcements.

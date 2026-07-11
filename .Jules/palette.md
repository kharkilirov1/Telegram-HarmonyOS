## 2024-07-11 - Expanded touch targets for icon-only actions
**Learning:** Applying onClick directly to small Image or TgIcon components creates inaccessible touch targets.
**Action:** Wrap icon-only interactive elements in a Row or Column with minimum 44x44vp size, moving onClick, margins, and .accessibilityDescription() to the wrapper.

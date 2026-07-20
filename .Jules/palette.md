
## 2024-07-20 - Top Bar Action Accessibility Pattern
**Learning:** Generic top bar action containers (like right slots) should not use hardcoded accessibility descriptions like 'Action' as it creates confusing screen reader announcements. Interactive icon-only elements also need appropriate 44x44vp layout wrappers to ensure proper touch targets rather than applying clicks directly to the icons.
**Action:** When making highly-reusable UI slots interactive, pass accessibility descriptions dynamically. Ensure all standalone interactive icons are wrapped in Row/Column containers (≥44vp) with click effects and accessibility modifiers applied to the wrapper.

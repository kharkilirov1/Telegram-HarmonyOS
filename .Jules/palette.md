
## 2026-07-18 - Making interactive icons accessible in ArkUI
**Learning:** Applying onClick handlers directly to bare Image or TgIcon components in ArkUI creates undersized touch targets (e.g., 22x22vp) and makes it difficult to apply standard click effects and screen reader labels.
**Action:** When making custom icon-only components interactive, always wrap them in appropriately sized layout containers (like Row or Column to hit a minimum of 44x44vp), move the onClick handler and margins to this new parent wrapper, and apply `.accessibilityGroup(true)` and `.accessibilityDescription()` to the wrapper to ensure screen readers correctly announce the capability and touch target size is adequate.

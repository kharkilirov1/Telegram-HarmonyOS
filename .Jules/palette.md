## 2024-05-20 - Ensure minimum touch target and feedback for bare Image icons
**Learning:** In ArkUI, attaching `onClick` directly to bare `Image` icons leads to missing standard touch feedback (`clickEffect`) and often insufficient touch target sizes if not padded correctly.
**Action:** Always wrap interactive icon-only components in layout containers (like `Row`), set an explicit minimum target size (e.g., 44x44), and apply `.clickEffect` and `.accessibilityDescription` on the wrapper.

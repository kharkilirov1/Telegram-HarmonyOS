## 2024-07-02 - Dynamic Accessibility in ArkUI Dual-Purpose Buttons
**Learning:** ArkUI components with dynamic visual states (like Send/Mic toggles) don't automatically announce their capability changes to screen readers when state shifts. Standard static descriptions fail here.
**Action:** Always compute `.accessibilityDescription()` dynamically (e.g., via ternary operators) matching the component's internal state conditions (like `this.canSend()`) to guarantee accurate announcements.

## 2024-06-23 - Interactive UI Capsules Accessibility
**Learning:** In the HarmonyOS application, custom capsule-like navigation controls (e.g. TgChatTopBar's back button and avatar) are built using interactive Row wrappers. Because they only contain graphical elements and lack text nodes, screen readers fail to announce their purpose.
**Action:** Always apply .accessibilityGroup(true) and .accessibilityDescription('...') to the interactive Row or Column wrapper of icon-only navigation components to ensure proper screen reader announcements.

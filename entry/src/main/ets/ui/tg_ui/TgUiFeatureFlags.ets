export class TgUiFeatureFlags {
  // Keep legacy/no-chat-screen as default until tg_ui chat screen integration is accepted.
  static readonly USE_TG_CHAT_V2: boolean = true;

  // When tg_ui chat row is enabled, use internal separator and disable List.divider.
  static readonly USE_INTERNAL_CHAT_ROW_SEPARATOR: boolean = true;

  // API 23 HdsTabs miniBar adds the current-iOS bottom Search dock without
  // replacing either the native root tabs or the collapsible header Search.
  static readonly USE_HDS_ROOT_SEARCH_MINIBAR: boolean = true;

  // API 26+ may render the custom Telegram composer with native immersive
  // material. API 23-25 stay on the accepted adaptive-blur fallback.
  static readonly USE_NATIVE_IMMERSIVE_COMPOSER_MATERIAL: boolean = true;

  // Root island auto-hides while the chat list scrolls down and returns on
  // scroll up. Planned to become a user-facing Settings toggle once real
  // settings storage exists (user decision 2026-07-21).
  static readonly USE_ROOT_BAR_AUTO_HIDE_ON_SCROLL: boolean = true;
}

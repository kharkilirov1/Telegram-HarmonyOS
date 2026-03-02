export class TgUiFeatureFlags {
  // Keep legacy/no-chat-screen as default until tg_ui chat screen integration is accepted.
  static readonly USE_TG_CHAT_V2: boolean = true;

  // When tg_ui chat row is enabled, use internal separator and disable List.divider.
  static readonly USE_INTERNAL_CHAT_ROW_SEPARATOR: boolean = true;
}

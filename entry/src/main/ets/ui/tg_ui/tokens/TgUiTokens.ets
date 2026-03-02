// TgUiTokens — Telegram-style UI token source for tg_ui pipeline.
// Rule: component code must consume tokens from this file (no magic constants in atoms).

export class TgUiTokens {
  // ── Colors ──
  static readonly COLOR_BG_PRIMARY: Resource = $r('app.color.background_primary');
  static readonly COLOR_BG_SECONDARY: Resource = $r('app.color.background_secondary');
  static readonly COLOR_SEPARATOR: Resource = $r('app.color.chatlist_separator');

  static readonly COLOR_TEXT_TITLE: Resource = $r('app.color.text_primary');
  static readonly COLOR_TEXT_PREVIEW: Resource = $r('app.color.text_secondary');
  static readonly COLOR_TEXT_META: Resource = $r('app.color.text_secondary');
  static readonly COLOR_TEXT_ERROR: Resource = $r('app.color.error_red');
  static readonly COLOR_OVERLAY_DIM: Resource = $r('app.color.overlay_dark');

  static readonly COLOR_ICON_PRIMARY: Resource = $r('app.color.telegram_blue');
  static readonly COLOR_ICON_SECONDARY: Resource = $r('app.color.text_secondary');
  static readonly COLOR_ICON_MUTED: Resource = $r('app.color.text_secondary');
  static readonly COLOR_ICON_DISABLED: Resource = $r('app.color.text_secondary');
  static readonly COLOR_STATUS_PENDING: Resource = $r('app.color.text_secondary');
  static readonly COLOR_STATUS_SENT: Resource = $r('app.color.telegram_blue');
  static readonly COLOR_STATUS_READ: Resource = $r('app.color.telegram_blue');
  static readonly COLOR_STATUS_FAILED: Resource = $r('app.color.error_red');

  static readonly COLOR_UNREAD_BG: Resource = $r('app.color.unread_badge');
  static readonly COLOR_UNREAD_TEXT: Resource = $r('app.color.unread_text');
  static readonly COLOR_UNREAD_BG_MUTED: Resource = $r('app.color.text_secondary');
  static readonly COLOR_ONLINE_DOT: Resource = $r('app.color.online_indicator');
  static readonly COLOR_AVATAR_PLACEHOLDER_BG: Resource = $r('app.color.placeholder_bg');
  static readonly COLOR_AVATAR_PLACEHOLDER_TEXT: Resource = $r('app.color.icon_on_primary');
  static readonly COLOR_CHAT_ROW_PINNED_BG: Resource = $r('app.color.chatlist_pinned_item_bg');
  static readonly COLOR_MSG_BUBBLE_INCOMING_BG: Resource = $r('app.color.chat_bubble_incoming');
  static readonly COLOR_MSG_BUBBLE_OUTGOING_BG: Resource = $r('app.color.chat_bubble_outgoing');
  static readonly TOP_BAR_GLASS_BG: Resource = $r('app.color.glass_nav_bg');
  static readonly TOP_BAR_GLASS_FALLBACK_BG: Resource = $r('app.color.background_secondary');
  static readonly TOP_BAR_SEPARATOR: Resource = $r('app.color.separator');
  static readonly MSG_TEXT_INCOMING: Resource = $r('app.color.text_primary');
  static readonly MSG_TEXT_OUTGOING: Resource = $r('app.color.text_primary');
  static readonly MSG_LINK_INCOMING: Resource = $r('app.color.telegram_blue');
  static readonly MSG_LINK_OUTGOING: Resource = $r('app.color.telegram_blue');
  static readonly MSG_META_TEXT_INCOMING: Resource = $r('app.color.text_secondary');
  static readonly MSG_META_TEXT_OUTGOING: Resource = $r('app.color.text_secondary');
  static readonly MSG_META_STATUS_PENDING: Resource = $r('app.color.text_secondary');
  static readonly MSG_META_STATUS_SENT: Resource = $r('app.color.text_secondary');
  static readonly MSG_META_STATUS_READ: Resource = $r('app.color.telegram_blue');
  static readonly MSG_META_STATUS_FAILED: Resource = $r('app.color.error_red');
  static readonly PHOTO_BUBBLE_PLACEHOLDER_BG: Resource = $r('app.color.placeholder_bg');
  static readonly PHOTO_BUBBLE_PLACEHOLDER_ICON: Resource = $r('app.color.text_secondary');
  static readonly PHOTO_BUBBLE_CAPTION_TEXT_INCOMING: Resource = $r('app.color.text_primary');
  static readonly PHOTO_BUBBLE_CAPTION_TEXT_OUTGOING: Resource = $r('app.color.text_primary');
  static readonly VIDEO_BUBBLE_PLACEHOLDER_BG: Resource = $r('app.color.placeholder_bg');
  static readonly VIDEO_BUBBLE_PLACEHOLDER_ICON: Resource = $r('app.color.text_secondary');
  static readonly VIDEO_BUBBLE_PLAY_BG: Resource = $r('app.color.date_separator_bg');
  static readonly VIDEO_BUBBLE_PLAY_ICON: Resource = $r('app.color.unread_text');
  static readonly VIDEO_BUBBLE_DURATION_BG: Resource = $r('app.color.date_separator_bg');
  static readonly VIDEO_BUBBLE_DURATION_TEXT: Resource = $r('app.color.unread_text');
  static readonly VIDEO_BUBBLE_CAPTION_TEXT_INCOMING: Resource = $r('app.color.text_primary');
  static readonly VIDEO_BUBBLE_CAPTION_TEXT_OUTGOING: Resource = $r('app.color.text_primary');
  static readonly DOCUMENT_ROW_ICON_BG: Resource = $r('app.color.background_secondary');
  static readonly DOCUMENT_ROW_ICON_TINT: Resource = $r('app.color.telegram_blue');
  static readonly DOCUMENT_ROW_TITLE_INCOMING: Resource = $r('app.color.text_primary');
  static readonly DOCUMENT_ROW_TITLE_OUTGOING: Resource = $r('app.color.text_primary');
  static readonly DOCUMENT_ROW_META_INCOMING: Resource = $r('app.color.text_secondary');
  static readonly DOCUMENT_ROW_META_OUTGOING: Resource = $r('app.color.text_secondary');
  static readonly DOCUMENT_ROW_PROGRESS_BG: Resource = $r('app.color.separator');
  static readonly DOCUMENT_ROW_PROGRESS_FILL: Resource = $r('app.color.telegram_blue');
  static readonly VOICE_BUBBLE_BUTTON_BG: Resource = $r('app.color.telegram_blue');
  static readonly VOICE_BUBBLE_BUTTON_ICON: Resource = $r('app.color.unread_text');
  static readonly VOICE_BUBBLE_WAVE_ACTIVE: Resource = $r('app.color.telegram_blue');
  static readonly VOICE_BUBBLE_WAVE_ACTIVE_OUTGOING: Resource = $r('app.color.online_indicator');
  static readonly VOICE_BUBBLE_WAVE_INACTIVE: Resource = $r('app.color.text_secondary');
  static readonly VOICE_BUBBLE_DURATION_INCOMING: Resource = $r('app.color.text_secondary');
  static readonly VOICE_BUBBLE_DURATION_OUTGOING: Resource = $r('app.color.text_secondary');
  static readonly STICKER_VIEW_PLACEHOLDER_BG: Resource = $r('app.color.placeholder_bg');
  static readonly STICKER_VIEW_PLACEHOLDER_ICON: Resource = $r('app.color.text_secondary');
  static readonly STICKER_VIEW_EMOJI_TEXT: Resource = $r('app.color.text_secondary');

  // ── Typography ──
  static readonly FONT_TITLE_SIZE: number = 17;
  static readonly FONT_PREVIEW_SIZE: number = 15;
  static readonly FONT_META_SIZE: number = 13;
  static readonly FONT_BADGE_SIZE: number = 13;
  static readonly FONT_AVATAR_INITIALS_SIZE_SM: number = 16;
  static readonly FONT_AVATAR_INITIALS_SIZE_MD: number = 20;
  static readonly FONT_AVATAR_INITIALS_SIZE_LG: number = 24;
  static readonly TOP_BAR_TITLE_SIZE: number = 17;
  static readonly MSG_TEXT_SIZE: number = 17;
  static readonly MSG_TEXT_WEIGHT = FontWeight.Regular;
  static readonly MSG_TEXT_LINE_HEIGHT: number = 22;
  static readonly MSG_TEXT_LETTER_SPACING: number = 0;
  static readonly MSG_EMOJI_ONLY_SIZE: number = 40;
  static readonly MSG_EMOJI_ONLY_LINE_HEIGHT: number = 44;
  static readonly MSG_META_SIZE: number = 12;
  static readonly TEXT_MAX_LINES: number = 0;

  // ── Spacing ──
  static readonly SPACE_2: number = 2;
  static readonly SPACE_4: number = 4;
  static readonly SPACE_6: number = 6;
  static readonly SPACE_8: number = 8;
  static readonly SPACE_10: number = 10;
  static readonly SPACE_12: number = 12;
  static readonly SPACE_16: number = 16;

  // ── Radius ──
  static readonly RADIUS_6: number = 6;
  static readonly RADIUS_8: number = 8;
  static readonly RADIUS_10: number = 10;
  static readonly RADIUS_12: number = 12;
  static readonly RADIUS_ROUND_MAX: number = 999;

  // ── Icons ──
  static readonly ICON_SIZE_XS: number = 12;
  static readonly ICON_SIZE_SM: number = 16;
  static readonly ICON_SIZE_MD: number = 20;
  static readonly ICON_SIZE_LG: number = 24;
  static readonly ICON_SIZE_XL: number = 28;
  static readonly ICON_DISABLED_OPACITY: number = 0.38;

  // ── Top bar ──
  static readonly TOP_BAR_HEIGHT: number = 44;
  static readonly TOP_BAR_SIDE_PADDING: number = 12;
  static readonly TOP_BAR_ACTION_TOUCH: number = 44;
  static readonly TOP_BAR_ACTION_ICON_SIZE: number = 22;
  static readonly TOP_BAR_SEPARATOR_STROKE: number = 1;

  // NOTE:
  // ArkUI Image.fillColor applies to SVG drawables when SVG elements define fill (fill != none).
  // Keep source SVG paths tint-friendly to ensure deterministic icon color.
  static readonly SVG_TINT_REQUIRES_FILL_PATH: boolean = true;

  // ── Avatar ──
  static readonly AVATAR_SIZE_SM: number = 40;
  static readonly AVATAR_SIZE_MD: number = 54;
  static readonly AVATAR_SIZE_DEFAULT: number = 60;
  static readonly AVATAR_ONLINE_DOT_SIZE: number = 14;
  static readonly AVATAR_ONLINE_DOT_BORDER: number = 2;
  static readonly AVATAR_ONLINE_DOT_OFFSET_X: number = -2;
  static readonly AVATAR_ONLINE_DOT_OFFSET_Y: number = -2;

  // ── Badge ──
  static readonly UNREAD_BADGE_MAX_VISIBLE_COUNT: number = 99;
  static readonly UNREAD_BADGE_HEIGHT: number = 20;
  static readonly UNREAD_BADGE_MIN_WIDTH: number = 20;
  static readonly UNREAD_BADGE_MAX_WIDTH: number = 34;
  static readonly UNREAD_BADGE_DISABLED_OPACITY: number = 0.45;

  // legacy aliases (keep while atoms are landing incrementally)
  static readonly UNREAD_BADGE_MIN_SIZE: number = 20;
  static readonly UNREAD_BADGE_H_PADDING: number = 6;
  static readonly UNREAD_BADGE_RADIUS: number = 10;

  // ── Chat row baseline metrics ──
  static readonly CHAT_ROW_HEIGHT: number = 72;
  static readonly CHAT_ROW_SIDE_INSET: number = 16;
  static readonly CHAT_ROW_AVATAR_TEXT_GAP: number = 12;
  static readonly CHAT_ROW_TEXT_META_GAP: number = 8;
  static readonly CHAT_ROW_TITLE_PREVIEW_GAP: number = 4;
  static readonly CHAT_ROW_TITLE_MUTE_GAP: number = 4;
  static readonly CHAT_ROW_MUTE_ICON_SIZE: number = TgUiTokens.ICON_SIZE_XS;
  static readonly CHAT_ROW_SEPARATOR_STROKE: number = 1;
  static readonly CHAT_ROW_META_FIXED_WIDTH: number = 76;
  static readonly CHAT_META_MIN_WIDTH: number = 76;
  static readonly CHAT_META_TOP_ROW_HEIGHT: number = 18;
  static readonly CHAT_META_BOTTOM_ROW_HEIGHT: number = 20;
  static readonly CHAT_META_ROW_GAP: number = 2;
  static readonly CHAT_META_STATUS_ICON_SIZE: number = TgUiTokens.ICON_SIZE_XS;
  static readonly CHAT_META_STATUS_GAP: number = 4;
  static readonly CHAT_META_BOTTOM_PLACEHOLDER_WIDTH: number = TgUiTokens.UNREAD_BADGE_MAX_WIDTH;
  static readonly CHAT_META_BOTTOM_PLACEHOLDER_HEIGHT: number = TgUiTokens.UNREAD_BADGE_HEIGHT;
  static readonly CHAT_ROW_SEPARATOR_INSET: number =
    TgUiTokens.CHAT_ROW_SIDE_INSET + TgUiTokens.AVATAR_SIZE_DEFAULT + TgUiTokens.CHAT_ROW_AVATAR_TEXT_GAP;

  // ── Message text / bubble groundwork (Phase C Step 0) ──
  static readonly BUBBLE_MAX_WIDTH_RATIO: number = 0.8;
  static readonly BUBBLE_PADDING_H: number = 12;
  static readonly BUBBLE_PADDING_V: number = 8;
  static readonly BUBBLE_RADIUS_INCOMING: number = 18;
  static readonly BUBBLE_RADIUS_OUTGOING: number = 18;
  static readonly MSG_BUBBLE_RADIUS: number = 18;
  static readonly MSG_DEMO_BASE_CONTAINER_WIDTH: number = 360;
  static readonly MSG_DEMO_NARROW_CONTAINER_WIDTH: number = 220;
  static readonly MSG_DEMO_WIDE_CONTAINER_WIDTH: number = 340;
  static readonly MSG_DEMO_SIDE_NARROW_CONTAINER_WIDTH: number = 136;
  static readonly MSG_DEMO_SIDE_WIDE_CONTAINER_WIDTH: number = 164;
  static readonly MSG_DEMO_WRAP_INJECT_EVERY: number = 10;
  static readonly MSG_META_ROW_HEIGHT: number = 18;
  static readonly MSG_META_MIN_WIDTH: number = 56;
  static readonly MSG_META_ICON_SIZE: number = TgUiTokens.ICON_SIZE_XS;
  static readonly MSG_META_ICON_GAP: number = 4;
  static readonly MSG_META_TIME_PLACEHOLDER_WIDTH: number = 32;
  static readonly MSG_META_STATUS_PLACEHOLDER_WIDTH: number = 12;

  // ── Photo bubble (Phase C.1-1) ──
  static readonly PHOTO_BUBBLE_RADIUS: number = 16;
  static readonly PHOTO_BUBBLE_IMAGE_INSET: number = 2;
  static readonly PHOTO_BUBBLE_MIN_WIDTH: number = 170;
  static readonly PHOTO_BUBBLE_MIN_HEIGHT: number = 74;
  static readonly PHOTO_BUBBLE_MAX_WIDTH: number = 300;
  static readonly PHOTO_BUBBLE_MAX_HEIGHT: number = 380;
  static readonly PHOTO_BUBBLE_CAPTION_TOP_GAP: number = 6;
  static readonly PHOTO_BUBBLE_CAPTION_PADDING_H: number = 10;
  static readonly PHOTO_BUBBLE_CAPTION_PADDING_BOTTOM: number = 8;
  static readonly PHOTO_BUBBLE_CAPTION_SIZE: number = 17;
  static readonly PHOTO_BUBBLE_CAPTION_LINE_HEIGHT: number = 22;
  static readonly PHOTO_BUBBLE_CAPTION_MAX_LINES: number = 6;

  // ── Video bubble (Phase C.1-2) ──
  static readonly VIDEO_BUBBLE_RADIUS: number = 16;
  static readonly VIDEO_BUBBLE_IMAGE_INSET: number = 2;
  static readonly VIDEO_BUBBLE_MIN_WIDTH: number = 170;
  static readonly VIDEO_BUBBLE_MIN_HEIGHT: number = 74;
  static readonly VIDEO_BUBBLE_MAX_WIDTH: number = 300;
  static readonly VIDEO_BUBBLE_MAX_HEIGHT: number = 380;
  static readonly VIDEO_BUBBLE_PLAY_BG_SIZE: number = 38;
  static readonly VIDEO_BUBBLE_PLAY_ICON_SIZE: number = 20;
  static readonly VIDEO_BUBBLE_DURATION_FONT_SIZE: number = 12;
  static readonly VIDEO_BUBBLE_DURATION_LINE_HEIGHT: number = 14;
  static readonly VIDEO_BUBBLE_DURATION_RADIUS: number = 10;
  static readonly VIDEO_BUBBLE_DURATION_PADDING_H: number = 8;
  static readonly VIDEO_BUBBLE_DURATION_PADDING_V: number = 3;
  static readonly VIDEO_BUBBLE_DURATION_MARGIN: number = 8;
  static readonly VIDEO_BUBBLE_CAPTION_TOP_GAP: number = 6;
  static readonly VIDEO_BUBBLE_CAPTION_PADDING_H: number = 10;
  static readonly VIDEO_BUBBLE_CAPTION_PADDING_BOTTOM: number = 8;
  static readonly VIDEO_BUBBLE_CAPTION_SIZE: number = 17;
  static readonly VIDEO_BUBBLE_CAPTION_LINE_HEIGHT: number = 22;
  static readonly VIDEO_BUBBLE_CAPTION_MAX_LINES: number = 6;

  // ── Document row (Phase C.1-3) ──
  static readonly DOCUMENT_ROW_RADIUS: number = 18;
  static readonly DOCUMENT_ROW_MIN_WIDTH: number = 170;
  static readonly DOCUMENT_ROW_MAX_WIDTH: number = 300;
  static readonly DOCUMENT_ROW_PADDING_H: number = 12;
  static readonly DOCUMENT_ROW_PADDING_V: number = 10;
  static readonly DOCUMENT_ROW_ICON_BOX_SIZE: number = 44;
  static readonly DOCUMENT_ROW_ICON_SIZE: number = 22;
  static readonly DOCUMENT_ROW_ICON_RADIUS: number = 10;
  static readonly DOCUMENT_ROW_CONTENT_GAP: number = 8;
  static readonly DOCUMENT_ROW_TEXT_GAP: number = 2;
  static readonly DOCUMENT_ROW_TITLE_SIZE: number = 16;
  static readonly DOCUMENT_ROW_TITLE_LINE_HEIGHT: number = 20;
  static readonly DOCUMENT_ROW_META_SIZE: number = 13;
  static readonly DOCUMENT_ROW_META_LINE_HEIGHT: number = 16;
  static readonly DOCUMENT_ROW_PROGRESS_HEIGHT: number = 3;
  static readonly DOCUMENT_ROW_PROGRESS_RADIUS: number = 2;
  static readonly DOCUMENT_ROW_PROGRESS_TOP_GAP: number = 6;
  static readonly DOCUMENT_ROW_PROGRESS_MIN_VISIBLE_PERCENT: number = 2;

  // ── Voice bubble (Phase C.1-4) ──
  static readonly VOICE_BUBBLE_RADIUS: number = 18;
  static readonly VOICE_BUBBLE_MIN_WIDTH: number = 170;
  static readonly VOICE_BUBBLE_MAX_WIDTH: number = 300;
  static readonly VOICE_BUBBLE_PADDING_H: number = 10;
  static readonly VOICE_BUBBLE_PADDING_V: number = 8;
  static readonly VOICE_BUBBLE_CONTENT_GAP: number = 8;
  static readonly VOICE_BUBBLE_BUTTON_SIZE: number = 36;
  static readonly VOICE_BUBBLE_BUTTON_ICON_SIZE: number = 18;
  static readonly VOICE_BUBBLE_WAVE_BARS_COUNT: number = 28;
  static readonly VOICE_BUBBLE_WAVE_BAR_WIDTH: number = 2;
  static readonly VOICE_BUBBLE_WAVE_BAR_GAP: number = 2;
  static readonly VOICE_BUBBLE_WAVE_MIN_HEIGHT: number = 4;
  static readonly VOICE_BUBBLE_WAVE_MAX_HEIGHT: number = 16;
  static readonly VOICE_BUBBLE_WAVE_AREA_HEIGHT: number = 20;
  static readonly VOICE_BUBBLE_DURATION_SIZE: number = 12;
  static readonly VOICE_BUBBLE_DURATION_LINE_HEIGHT: number = 14;

  // ── Sticker view (Phase C.1-5) ──
  static readonly STICKER_VIEW_MAX_SIZE: number = 184;
  static readonly STICKER_VIEW_ANIMATED_MAX_SIZE: number = 240;
  static readonly STICKER_VIEW_MIN_SIZE: number = 72;
  static readonly STICKER_VIEW_PLACEHOLDER_SIZE: number = 56;
  static readonly STICKER_VIEW_EMOJI_SIZE: number = 14;
  static readonly STICKER_VIEW_EMOJI_LINE_HEIGHT: number = 16;
  static readonly STICKER_VIEW_EMOJI_TOP_GAP: number = 4;

  // ── Reply snippet (Phase C Step 3) ──
  static readonly REPLY_SNIPPET_MIN_HEIGHT: number = 38;
  static readonly REPLY_SNIPPET_PADDING_H: number = 8;
  static readonly REPLY_SNIPPET_PADDING_V: number = 6;
  static readonly REPLY_SNIPPET_BAR_WIDTH: number = 2;
  static readonly REPLY_SNIPPET_BAR_RADIUS: number = 2;
  static readonly REPLY_SNIPPET_BAR_GAP: number = 8;
  static readonly REPLY_SNIPPET_TEXT_GAP: number = 2;
  static readonly REPLY_SNIPPET_TITLE_SIZE: number = 13;
  static readonly REPLY_SNIPPET_TITLE_WEIGHT = FontWeight.Medium;
  static readonly REPLY_SNIPPET_TITLE_LINE_HEIGHT: number = 16;
  static readonly REPLY_SNIPPET_PREVIEW_SIZE: number = 13;
  static readonly REPLY_SNIPPET_PREVIEW_WEIGHT = FontWeight.Regular;
  static readonly REPLY_SNIPPET_PREVIEW_LINE_HEIGHT: number = 16;
  static readonly REPLY_SNIPPET_TITLE_INCOMING: Resource = $r('app.color.telegram_blue');
  static readonly REPLY_SNIPPET_TITLE_OUTGOING: Resource = $r('app.color.telegram_blue');
  static readonly REPLY_SNIPPET_PREVIEW_INCOMING: Resource = $r('app.color.text_primary');
  static readonly REPLY_SNIPPET_PREVIEW_OUTGOING: Resource = $r('app.color.text_primary');
  static readonly REPLY_SNIPPET_BAR_INCOMING: Resource = $r('app.color.telegram_blue');
  static readonly REPLY_SNIPPET_BAR_OUTGOING: Resource = $r('app.color.telegram_blue');
  static readonly REPLY_SNIPPET_THUMB_SIZE: number = 28;
  static readonly REPLY_SNIPPET_THUMB_RADIUS: number = 6;
  static readonly REPLY_SNIPPET_THUMB_GAP: number = 8;
  static readonly REPLY_SNIPPET_MAX_TITLE_LINES: number = 1;
  static readonly REPLY_SNIPPET_MAX_PREVIEW_LINES: number = 1;
  static readonly REPLY_SNIPPET_QUOTE_MAX_TITLE_LINES: number = 2;
  static readonly REPLY_SNIPPET_QUOTE_MAX_PREVIEW_LINES: number = 5;

  // ── Date separator + unread marker (Phase C Step 4) ──
  static readonly DATE_SEPARATOR_BG: Resource = $r('app.color.date_separator_bg');
  static readonly DATE_SEPARATOR_TEXT: Resource = $r('app.color.text_on_overlay');
  static readonly DATE_SEPARATOR_FONT_SIZE: number = 13;
  static readonly DATE_SEPARATOR_FONT_WEIGHT = FontWeight.Medium;
  static readonly DATE_SEPARATOR_LINE_HEIGHT: number = 16;
  static readonly DATE_SEPARATOR_PADDING_H: number = 10;
  static readonly DATE_SEPARATOR_PADDING_V: number = 4;
  static readonly DATE_SEPARATOR_RADIUS: number = 12;
  static readonly DATE_SEPARATOR_MIN_HEIGHT: number = 24;
  static readonly DATE_SEPARATOR_SIDE_INSET: number = 16;
  static readonly DATE_SEPARATOR_MAX_WIDTH_RATIO: number = 0.72;

  static readonly UNREAD_MARKER_BG: Resource = $r('app.color.telegram_blue');
  static readonly UNREAD_MARKER_TEXT: Resource = $r('app.color.unread_text');
  static readonly UNREAD_MARKER_FONT_SIZE: number = 13;
  static readonly UNREAD_MARKER_FONT_WEIGHT = FontWeight.Medium;
  static readonly UNREAD_MARKER_LINE_HEIGHT: number = 16;
  static readonly UNREAD_MARKER_HEIGHT: number = 25;
  static readonly UNREAD_MARKER_RADIUS: number = 8;
  static readonly UNREAD_MARKER_SIDE_INSET: number = 0;
  static readonly UNREAD_MARKER_MAX_WIDTH_RATIO: number = 1.0;

  // ── Composer input (Phase C Step 5) ──
  static readonly COMPOSER_BG: Resource = $r('app.color.background_primary');
  static readonly COMPOSER_TOP_SEPARATOR: Resource = $r('app.color.separator');
  static readonly COMPOSER_INPUT_BG: Resource = $r('app.color.glass_input_bg');
  static readonly COMPOSER_TEXT: Resource = $r('app.color.text_primary');
  static readonly COMPOSER_PLACEHOLDER: Resource = $r('app.color.text_secondary');
  static readonly COMPOSER_ACTION_ACTIVE: Resource = $r('app.color.telegram_blue');
  static readonly COMPOSER_ACTION_INACTIVE: Resource = $r('app.color.text_secondary');
  static readonly COMPOSER_DISABLED_OPACITY: number = 0.55;

  static readonly COMPOSER_MIN_HEIGHT: number = 52;
  static readonly COMPOSER_MAX_HEIGHT: number = 120;
  static readonly COMPOSER_SIDE_INSET: number = 8;
  static readonly COMPOSER_VERTICAL_INSET: number = 6;
  static readonly COMPOSER_ROW_GAP: number = 6;
  static readonly COMPOSER_INPUT_RADIUS: number = 20;
  static readonly COMPOSER_INPUT_PADDING_H: number = 12;
  static readonly COMPOSER_INPUT_PADDING_V: number = 8;
  static readonly COMPOSER_BUTTON_SIZE: number = 34;
  static readonly COMPOSER_ICON_SIZE: number = 22;

  static readonly COMPOSER_TEXT_SIZE: number = 17;
  static readonly COMPOSER_TEXT_WEIGHT = FontWeight.Regular;
  static readonly COMPOSER_TEXT_LINE_HEIGHT: number = 21;
  static readonly COMPOSER_MAX_LINES: number = 4;
  static readonly COMPOSER_REPLY_GAP: number = 6;

  // ── Tab bar island (Phase D-1) ──
  static readonly TAB_BAR_ISLAND_HEIGHT: number = 50;
  static readonly TAB_BAR_ISLAND_RADIUS: number = 999;
  static readonly TAB_BAR_ISLAND_SIDE_INSET: number = 20;
  static readonly TAB_BAR_ISLAND_BOTTOM_MARGIN: number = 10;
  static readonly TAB_BAR_ISLAND_MAX_WIDTH: number = 560;
  static readonly TAB_BAR_ISLAND_BG: Resource = $r('app.color.glass_tab_bg');
  static readonly TAB_BAR_ISLAND_FALLBACK_BG: Resource = $r('app.color.background_secondary');
  static readonly TAB_BAR_ISLAND_BORDER_WIDTH: number = 0.5;
  static readonly TAB_BAR_ISLAND_BORDER_COLOR: Resource = $r('app.color.separator');
  static readonly TAB_BAR_ISLAND_SHADOW_COLOR: Resource = $r('app.color.glass_card_shadow');
  static readonly TAB_BAR_ISLAND_SHADOW_RADIUS: number = 20;
  static readonly TAB_BAR_ISLAND_SHADOW_OFFSET_Y: number = 8;
  static readonly TAB_BAR_ICON_SIZE: number = 23;
  static readonly TAB_BAR_TEXT_SIZE: number = 10;
  static readonly TAB_BAR_BADGE_HEIGHT: number = 18;
  static readonly TAB_BAR_BADGE_MIN_WIDTH: number = 18;
  static readonly TAB_BAR_BADGE_RADIUS: number = 9;
  static readonly TAB_BAR_BADGE_FONT_SIZE: number = 11;
  static readonly TAB_BAR_BADGE_PADDING_H: number = 5;
  static readonly TAB_BAR_CONTENT_SAFE_BOTTOM: number = 74;

  // ── Filter bar (Phase G) ──
  static readonly FILTER_BAR_HEIGHT: number = 44;
  static readonly FILTER_BAR_RADIUS: number = 22;
  static readonly FILTER_BAR_SIDE_INSET: number = 16;
  static readonly FILTER_BAR_INNER_PADDING: number = 14;
  static readonly FILTER_BAR_MAX_WIDTH: number = 560;
  static readonly FILTER_BAR_BG: Resource = $r('app.color.glass_tab_bg');
  static readonly FILTER_BAR_FALLBACK_BG: Resource = $r('app.color.background_secondary');
  static readonly FILTER_BAR_BORDER_WIDTH: number = 0.5;
  static readonly FILTER_BAR_BORDER_COLOR: Resource = $r('app.color.separator');
  static readonly FILTER_BAR_SHADOW_COLOR: Resource = $r('app.color.glass_card_shadow');
  static readonly FILTER_BAR_SHADOW_RADIUS: number = 20;
  static readonly FILTER_BAR_SHADOW_OFFSET_Y: number = 8;
  static readonly FILTER_BAR_TAB_FONT_SIZE: number = 14;
  static readonly FILTER_BAR_TAB_TEXT_COLOR: Resource = $r('app.color.text_primary');
  static readonly FILTER_BAR_TAB_MIN_SPACING: number = 26;
  static readonly FILTER_BAR_TAB_VERTICAL_INSET: number = 4;
  static readonly FILTER_BAR_HIGHLIGHT_HEIGHT: number = 36;
  static readonly FILTER_BAR_HIGHLIGHT_PADDING_H: number = 10;
  static readonly FILTER_BAR_HIGHLIGHT_RADIUS: number = 18;
  static readonly FILTER_BAR_HIGHLIGHT_BG: Resource = $r('app.color.filter_highlight_bg');
  static readonly FILTER_BAR_HIGHLIGHT_ANIM_DURATION: number = 250;
  static readonly FILTER_BAR_BADGE_SIZE: number = 18;
  static readonly FILTER_BAR_BADGE_FONT_SIZE: number = 14;
  static readonly FILTER_BAR_BADGE_PADDING_H: number = 4;
  static readonly FILTER_BAR_BADGE_TEXT_OFFSET: number = 4;
  static readonly FILTER_BAR_BADGE_ACTIVE_BG: Resource = $r('app.color.telegram_blue');
  static readonly FILTER_BAR_BADGE_INACTIVE_BG: Resource = $r('app.color.filter_badge_inactive_bg');
  static readonly FILTER_BAR_BADGE_TEXT_COLOR: Resource = $r('app.color.unread_text');

  // ── Search bar (Phase D-2) ──
  static readonly SEARCH_BAR_HEIGHT: number = 36;
  static readonly SEARCH_BAR_RADIUS: number = 10;
  static readonly SEARCH_BAR_SIDE_INSET: number = 16;
  static readonly SEARCH_BAR_VERTICAL_INSET: number = 8;
  static readonly SEARCH_BAR_FONT_SIZE: number = 15;
  static readonly SEARCH_BAR_ICON_SIZE: number = 16;
  static readonly SEARCH_BAR_BG: Resource = $r('app.color.search_bar_bg');
  static readonly SEARCH_BAR_TEXT_COLOR: Resource = $r('app.color.text_primary');
  static readonly SEARCH_BAR_PLACEHOLDER_COLOR: Resource = $r('app.color.text_secondary');
  static readonly SEARCH_BAR_ICON_COLOR: Resource = $r('app.color.text_secondary');

  // ── Country selection atoms ──
  static readonly COUNTRY_SECTION_HEADER_HEIGHT: number = 24;
  static readonly COUNTRY_SECTION_HEADER_TEXT_SIZE: number = 14;
  static readonly COUNTRY_SECTION_HEADER_SIDE_INSET: number = 16;
  static readonly COUNTRY_SECTION_HEADER_BG: Resource = $r('app.color.background_secondary');
  static readonly COUNTRY_SECTION_HEADER_TEXT_COLOR: Resource = $r('app.color.text_secondary');

  static readonly COUNTRY_ROW_HEIGHT: number = 50;
  static readonly COUNTRY_ROW_SIDE_INSET: number = 16;
  static readonly COUNTRY_ROW_FLAG_SIZE: number = 24;
  static readonly COUNTRY_ROW_FLAG_NAME_GAP: number = 16;
  static readonly COUNTRY_ROW_DIAL_CODE_END_INSET: number = 32;
  static readonly COUNTRY_ROW_NAME_SIZE: number = 17;
  static readonly COUNTRY_ROW_DIAL_CODE_SIZE: number = 17;
  static readonly COUNTRY_ROW_SEPARATOR_STROKE: number = 0.5;
  static readonly COUNTRY_ROW_SEPARATOR_INSET: number = 56;

  static readonly COUNTRY_SHEET_SEARCH_HEIGHT: number = 36;
  static readonly COUNTRY_SHEET_SEARCH_SIDE_INSET: number = 16;

  // ── Shared glass highlight colors ──
  static readonly GLASS_SPECULAR_TOP: string = '#22FFFFFF';
  static readonly GLASS_SPECULAR_MID: string = '#08FFFFFF';
  static readonly GLASS_SPECULAR_BOTTOM: string = '#00FFFFFF';

  // ── Contact row (Phase E-1) ──
  static readonly CONTACT_ROW_HEIGHT: number = 56;
  static readonly CONTACT_ROW_AVATAR_SIZE: number = 40;
  static readonly CONTACT_ROW_PADDING_H: number = 16;
  static readonly CONTACT_ROW_GAP: number = 12;
  static readonly CONTACT_ROW_NAME_SIZE: number = 17;
  static readonly CONTACT_ROW_STATUS_SIZE: number = 14;
  static readonly CONTACT_ROW_SEPARATOR_STROKE: number = 0.5;
  static readonly CONTACT_ROW_SEPARATOR_INSET: number = 68; // padding + avatar + gap

  // ── Settings section (Phase E-2) ──
  static readonly SETTINGS_SECTION_RADIUS: number = 10;
  static readonly SETTINGS_SECTION_HEADER_SIZE: number = 13;
  static readonly SETTINGS_SECTION_FOOTER_SIZE: number = 13;
  static readonly SETTINGS_SECTION_HEADER_COLOR: Resource = $r('app.color.text_secondary');
  static readonly SETTINGS_SECTION_FOOTER_COLOR: Resource = $r('app.color.text_secondary');
  static readonly SETTINGS_SECTION_SIDE_INSET: number = 16;
  static readonly SETTINGS_SECTION_TOP_GAP: number = 24;
  static readonly SETTINGS_SECTION_HEADER_BOTTOM_GAP: number = 6;
  static readonly SETTINGS_SECTION_BG: Resource = $r('app.color.settings_section_bg');

  // ── Settings row (Phase E-3) ──
  static readonly SETTINGS_ROW_HEIGHT: number = 44;
  static readonly SETTINGS_ROW_PADDING_H: number = 16;
  static readonly SETTINGS_ROW_GAP: number = 12;
  static readonly SETTINGS_ROW_ICON_BOX_SIZE: number = 29;
  static readonly SETTINGS_ROW_ICON_SIZE: number = 17;
  static readonly SETTINGS_ROW_ICON_RADIUS: number = 7;
  static readonly SETTINGS_ROW_TITLE_SIZE: number = 17;
  static readonly SETTINGS_ROW_TRAILING_SIZE: number = 17;
  static readonly SETTINGS_ROW_TRAILING_COLOR: Resource = $r('app.color.text_secondary');
  static readonly SETTINGS_ROW_ARROW_SIZE: number = 14;
  static readonly SETTINGS_ROW_ARROW_COLOR: Resource = $r('app.color.text_secondary');
  static readonly SETTINGS_ROW_SEPARATOR_STROKE: number = 0.5;
  static readonly SETTINGS_ROW_SEPARATOR_INSET: number = 57; // paddingH + iconBox + gap

  // ── Call row (Phase E-4) ──
  static readonly CALL_ROW_HEIGHT: number = 56;
  static readonly CALL_ROW_AVATAR_SIZE: number = 40;
  static readonly CALL_ROW_PADDING_H: number = 16;
  static readonly CALL_ROW_GAP: number = 12;
  static readonly CALL_ROW_NAME_SIZE: number = 17;
  static readonly CALL_ROW_DATE_SIZE: number = 14;
  static readonly CALL_ROW_TYPE_ICON_SIZE: number = 16;
  static readonly CALL_ROW_MISSED_COLOR: Resource = $r('app.color.error_red');
  static readonly CALL_ROW_SEPARATOR_STROKE: number = 0.5;
  static readonly CALL_ROW_SEPARATOR_INSET: number = 68;

  // ── Login flow (Phase F) ──
  // Colors
  static readonly LOGIN_BG: Resource = $r('app.color.background_primary');
  static readonly LOGIN_TITLE_COLOR: Resource = $r('app.color.text_primary');
  static readonly LOGIN_SUBTITLE_COLOR: Resource = $r('app.color.text_primary');
  static readonly LOGIN_LINK_COLOR: Resource = $r('app.color.telegram_blue');
  static readonly LOGIN_ERROR_COLOR: Resource = $r('app.color.error_red');
  static readonly LOGIN_INPUT_TEXT_COLOR: Resource = $r('app.color.text_primary');
  static readonly LOGIN_INPUT_PLACEHOLDER_COLOR: Resource = $r('app.color.text_secondary');
  static readonly LOGIN_SEPARATOR_COLOR: Resource = $r('app.color.separator');
  // Button
  static readonly LOGIN_BUTTON_BG: Resource = $r('app.color.telegram_blue');
  static readonly LOGIN_BUTTON_DISABLED_BG: Resource = $r('app.color.separator');
  static readonly LOGIN_BUTTON_TEXT_COLOR: Resource = $r('app.color.icon_on_primary');
  static readonly LOGIN_BUTTON_DISABLED_TEXT_COLOR: Resource = $r('app.color.text_secondary');
  static readonly LOGIN_BUTTON_SPINNER_COLOR: Resource = $r('app.color.icon_on_primary');
  // Code cells
  static readonly LOGIN_CODE_CELL_BG: Resource = $r('app.color.background_secondary');
  static readonly LOGIN_CODE_CELL_TEXT_COLOR: Resource = $r('app.color.text_primary');
  static readonly LOGIN_CODE_CELL_BORDER_ACTIVE: Resource = $r('app.color.telegram_blue');
  static readonly LOGIN_CODE_CELL_BORDER_INACTIVE: Resource = $r('app.color.separator');
  // Typography
  static readonly LOGIN_TITLE_SIZE: number = 28;
  static readonly LOGIN_SUBTITLE_SIZE: number = 17;
  static readonly LOGIN_INPUT_FONT_SIZE: number = 17;
  static readonly LOGIN_LINK_SIZE: number = 15;
  static readonly LOGIN_ERROR_SIZE: number = 14;
  static readonly LOGIN_BUTTON_TEXT_SIZE: number = 17;
  static readonly LOGIN_CODE_CELL_FONT_SIZE: number = 24;
  // Layout
  static readonly LOGIN_SIDE_INSET: number = 16;
  static readonly LOGIN_MAX_WIDTH: number = 430;
  static readonly LOGIN_MONKEY_SIZE: number = 100;
  static readonly LOGIN_BUTTON_HEIGHT: number = 48;
  static readonly LOGIN_BUTTON_RADIUS: number = 24;
  static readonly LOGIN_INPUT_ROW_HEIGHT: number = 57;
  static readonly LOGIN_COUNTRY_CODE_WIDTH: number = 71;
  // Code cells size
  static readonly LOGIN_CODE_CELL_WIDTH: number = 42;
  static readonly LOGIN_CODE_CELL_HEIGHT: number = 48;
  static readonly LOGIN_CODE_CELL_RADIUS: number = 8;
  static readonly LOGIN_CODE_CELL_GAP: number = 12;
  static readonly LOGIN_CODE_CELL_BORDER_ACTIVE_WIDTH: number = 2;
  static readonly LOGIN_CODE_CELL_BORDER_INACTIVE_WIDTH: number = 1;

  // ── Chatlist status (Phase F) ──
  static readonly CHATLIST_STATUS_ICON_SIZE: number = 16;
  static readonly CHATLIST_STATUS_TEXT_SIZE: number = 13;
  static readonly CHATLIST_STATUS_GAP: number = 8;
  static readonly CHATLIST_LOADING_SIZE: number = 24;

  // ── Settings icon colors (Phase F-extra) ──
  static readonly SETTINGS_ICON_COLOR_BLUE: Resource = $r('app.color.settings_icon_blue');
  static readonly SETTINGS_ICON_COLOR_GREEN: Resource = $r('app.color.settings_icon_green');
  static readonly SETTINGS_ICON_COLOR_RED: Resource = $r('app.color.settings_icon_red');
  static readonly SETTINGS_ICON_COLOR_ORANGE: Resource = $r('app.color.settings_icon_orange');
  static readonly SETTINGS_ICON_COLOR_PURPLE: Resource = $r('app.color.settings_icon_purple');
  static readonly SETTINGS_ROW_ICON_TINT: Resource = $r('app.color.icon_on_primary');
  static readonly SETTINGS_PROFILE_NAME_SIZE: number = 20;

  // ── Tab bar badge offset (Phase F-extra) ──
  static readonly TAB_BAR_BADGE_OFFSET_X: number = 10;
  static readonly TAB_BAR_BADGE_OFFSET_Y: number = -7;

  // ── Country indexer (Phase F-extra) ──
  static readonly COUNTRY_INDEXER_FONT_SIZE: number = 11;
  static readonly COUNTRY_INDEXER_ITEM_SIZE: number = 16;
  static readonly COUNTRY_INDEXER_POPUP_FONT_SIZE: number = 30;
  static readonly COUNTRY_INDEXER_MARGIN_RIGHT: number = 4;
  static readonly COUNTRY_SHEET_LOADING_SIZE: number = 32;

  // ── Login layout extras (Phase F-extra) ──
  static readonly LOGIN_COUNTRY_NAME_SIZE: number = 20;
  static readonly LOGIN_SEPARATOR_STROKE: number = 0.5;
  static readonly LOGIN_VERTICAL_SEP_HEIGHT: number = 32;
  static readonly LOGIN_COUNTRY_CODE_PADDING_START: number = 18;
  static readonly LOGIN_PHONE_SEP_GAP_END: number = 16;
  static readonly LOGIN_SPACING_MONKEY_TOP: number = 10;
  static readonly LOGIN_SPACING_TITLE_TOP: number = 18;
  static readonly LOGIN_SPACING_COUNTRY_TOP: number = 30;
  static readonly LOGIN_SPACING_ERROR_TOP: number = 12;
  static readonly COMPOSER_SEPARATOR_STROKE: number = 1;
  static readonly LOGIN_TEXT_INPUT_HEIGHT: number = 44;
  static readonly LOGIN_PASSWORD_FIELD_TOP: number = 32;
  static readonly LOGIN_FORGOT_LINK_TOP: number = 48;
  static readonly LOGIN_FORGOT_LINK_SIZE: number = 16;
  static readonly LOGIN_RESEND_LINK_TOP: number = 24;
  static readonly LOGIN_EYE_ICON_MARGIN_H: number = 10;

  // ── Avatar color palette (Phase F-extra) ──
  static readonly AVATAR_COLOR_1: Resource = $r('app.color.sender_color_1');
  static readonly AVATAR_COLOR_2: Resource = $r('app.color.sender_color_2');
  static readonly AVATAR_COLOR_3: Resource = $r('app.color.sender_color_3');
  static readonly AVATAR_COLOR_4: Resource = $r('app.color.sender_color_4');
  static readonly AVATAR_COLOR_5: Resource = $r('app.color.sender_color_5');
  static readonly AVATAR_COLOR_6: Resource = $r('app.color.sender_color_6');
  static readonly AVATAR_COLOR_7: Resource = $r('app.color.sender_color_7');
  static readonly AVATAR_COLOR_8: Resource = $r('app.color.sender_color_8');

  // ── Shared icon resources for chat pipeline ──
  static readonly ICON_RES_CHECK: Resource = $r('app.media.ic_check');
  static readonly ICON_RES_EYE: Resource = $r('app.media.ic_eye');
  static readonly ICON_RES_EYE_OFF: Resource = $r('app.media.ic_eye_off');
  static readonly ICON_RES_CHAT: Resource = $r('app.media.ic_chat');
  static readonly ICON_RES_BACK: Resource = $r('app.media.ic_back');
  static readonly ICON_RES_MORE: Resource = $r('app.media.ic_more');
  static readonly ICON_RES_MUTE: Resource = $r('app.media.ic_mute');
  static readonly ICON_RES_PIN: Resource = $r('app.media.ic_pin');
  static readonly ICON_RES_CLOCK: Resource = $r('app.media.ic_clock');
  static readonly ICON_RES_CHECK_SINGLE: Resource = $r('app.media.ic_check_single');
  static readonly ICON_RES_CHECK_DOUBLE: Resource = $r('app.media.ic_check_double');
  static readonly ICON_RES_FAILED: Resource = $r('app.media.ic_warning');
  static readonly ICON_RES_ATTACH: Resource = $r('app.media.ic_attach');
  static readonly ICON_RES_SEND: Resource = $r('app.media.ic_send');
  static readonly ICON_RES_MIC: Resource = $r('app.media.ic_mic');
  static readonly ICON_RES_EMOJI: Resource = $r('app.media.ic_emoji');
  static readonly ICON_RES_DOCUMENT: Resource = $r('app.media.ic_document');
  static readonly ICON_RES_DOWNLOAD: Resource = $r('app.media.ic_download');
  static readonly ICON_RES_STICKER: Resource = $r('app.media.ic_sticker');
  static readonly ICON_RES_PHOTO: Resource = $r('app.media.ic_photo');
  static readonly ICON_RES_VIDEO: Resource = $r('app.media.ic_video');
  static readonly ICON_RES_PLAY: Resource = $r('app.media.ic_play');
  static readonly ICON_RES_PAUSE: Resource = $r('app.media.ic_pause');
  static readonly ICON_RES_SEARCH: Resource = $r('app.media.ic_search');
  static readonly ICON_RES_CONTACT: Resource = $r('app.media.ic_contact');
  static readonly ICON_RES_CONTACT_ADD: Resource = $r('app.media.ic_contact_add');
  static readonly ICON_RES_PHONE_CALL: Resource = $r('app.media.ic_phone_call');
  static readonly ICON_RES_CALL_INCOMING: Resource = $r('app.media.ic_call_incoming');
  static readonly ICON_RES_CALL_OUTGOING: Resource = $r('app.media.ic_call_outgoing');
  static readonly ICON_RES_SETTINGS: Resource = $r('app.media.ic_settings');
  static readonly ICON_RES_ARROW_RIGHT: Resource = $r('app.media.ic_arrow_right');
}

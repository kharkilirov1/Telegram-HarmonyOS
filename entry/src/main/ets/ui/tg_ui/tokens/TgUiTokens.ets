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
  static readonly COLOR_UNREAD_BG_MUTED: Resource = $r('app.color.unread_badge_muted');
  static readonly COLOR_ONLINE_DOT: Resource = $r('app.color.online_indicator');
  static readonly COLOR_AUTHOR_NAME: Resource = $r('app.color.author_name');
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
  static readonly MSG_QUOTE_BAR_INCOMING: Resource = $r('app.color.telegram_blue');
  static readonly MSG_QUOTE_BAR_OUTGOING: Resource = $r('app.color.telegram_blue');
  static readonly MSG_QUOTE_TEXT_INCOMING: Resource = $r('app.color.text_primary');
  static readonly MSG_QUOTE_TEXT_OUTGOING: Resource = $r('app.color.text_primary');
  static readonly MSG_QUOTE_BG_INCOMING: string = 'rgba(51, 144, 236, 0.12)';
  static readonly MSG_QUOTE_BG_OUTGOING: string = 'rgba(51, 144, 236, 0.10)';
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
  static readonly DOCUMENT_ROW_ACTION_BG: Resource = $r('app.color.telegram_blue');
  static readonly DOCUMENT_ROW_ACTION_ICON: Resource = $r('app.color.unread_text');
  static readonly AUDIO_BUBBLE_SEEK_BG: Resource = $r('app.color.separator');
  static readonly AUDIO_BUBBLE_SEEK_FILL: Resource = $r('app.color.telegram_blue');
  static readonly AUDIO_BUBBLE_ART_ICON: Resource = $r('app.color.unread_text');
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
  static readonly FONT_TITLE_SIZE: number = 16;
  static readonly FONT_PREVIEW_SIZE: number = 15;
  static readonly FONT_META_SIZE: number = 13;
  static readonly FONT_BADGE_SIZE: number = 13;
  static readonly FONT_AVATAR_INITIALS_SIZE_SM: number = 16;
  static readonly FONT_AVATAR_INITIALS_SIZE_MD: number = 20;
  static readonly FONT_AVATAR_INITIALS_SIZE_LG: number = 24;
  static readonly TOP_BAR_TITLE_SIZE: number = 17;
  static readonly MSG_TEXT_SIZE: number = 15;
  static readonly MSG_TEXT_WEIGHT = FontWeight.Regular;
  static readonly MSG_TEXT_LINE_HEIGHT: number = 16;
  static readonly MSG_TEXT_LETTER_SPACING: number = 0;
  static readonly MSG_EMOJI_ONLY_SIZE: number = 40;
  static readonly MSG_EMOJI_ONLY_LINE_HEIGHT: number = 44;
  static readonly MSG_META_SIZE: number = 11;
  static readonly MSG_QUOTE_TEXT_SIZE: number = 14;
  static readonly MSG_QUOTE_TEXT_LINE_HEIGHT: number = 16;
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
  static readonly TOP_BAR_BOTTOM_PADDING: number = 6;
  static readonly TOP_BAR_SIDE_PADDING: number = 12;
  static readonly TOP_BAR_ACTION_TOUCH: number = 44;
  static readonly TOP_BAR_ACTION_ICON_SIZE: number = 22;
  static readonly TOP_BAR_SEPARATOR_STROKE: number = 1;
  static readonly CHAT_TOP_BAR_CAPSULE_SIZE: number = 44;
  static readonly CHAT_TOP_BAR_CAPSULE_RADIUS: number = 22;
  static readonly CHAT_TOP_BAR_AVATAR_INNER: number = 38;
  static readonly CHAT_TOP_BAR_CAPSULE_GAP: number = 6;
  static readonly CHAT_TOP_BAR_TITLE_PADDING_H: number = 12;
  static readonly CHAT_TOP_BAR_TITLE_MIN_WIDTH: number = 136;
  static readonly CHAT_TOP_BAR_TITLE_SIZE: number = 17;
  static readonly CHAT_TOP_BAR_TITLE_WEIGHT = FontWeight.Medium;
  static readonly CHAT_TOP_BAR_SUBTITLE_SIZE: number = 13;
  static readonly CHAT_TOP_BAR_SUBTITLE_ACCENT: Resource = $r('app.color.telegram_blue');
  static readonly CHAT_TOP_BAR_BORDER_WIDTH: number = 0.5;
  static readonly CHAT_LIST_NAV_TITLE_WEIGHT = FontWeight.Medium;
  static readonly CHAT_LIST_NAV_SEARCH_AREA_HEIGHT: number = 54;
  static readonly CHAT_LIST_NAV_TOTAL_HEIGHT: number =
    TgUiTokens.TOP_BAR_HEIGHT + TgUiTokens.CHAT_LIST_NAV_SEARCH_AREA_HEIGHT;
  static readonly TOP_CHROME_EDGE_HEIGHT: number = 54;
  static readonly TOP_CHROME_EDGE_TOP: string = '#18FFFFFF';
  static readonly TOP_CHROME_EDGE_BOTTOM: string = '#00FFFFFF';

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
  static readonly UNREAD_BADGE_HEIGHT: number = 20;
  static readonly UNREAD_BADGE_MIN_WIDTH: number = 20;
  static readonly UNREAD_BADGE_MAX_WIDTH: number = 52;
  static readonly UNREAD_BADGE_DISABLED_OPACITY: number = 0.45;

  // legacy aliases (keep while atoms are landing incrementally)
  static readonly UNREAD_BADGE_MIN_SIZE: number = 20;
  static readonly UNREAD_BADGE_H_PADDING: number = 5;
  static readonly UNREAD_BADGE_RADIUS: number = 10;
  static readonly UNREAD_BADGE_MAX_VISIBLE_COUNT: number = 99;

  // ── Chat row baseline metrics ──
  static readonly CHAT_ROW_HEIGHT: number = 76;
  static readonly CHAT_ROW_SIDE_INSET: number = 10;
  static readonly CHAT_ROW_AVATAR_TEXT_GAP: number = 8;
  static readonly CHAT_ROW_TEXT_META_GAP: number = 8;
  static readonly CHAT_ROW_TITLE_PREVIEW_GAP: number = 0;
  static readonly CHAT_ROW_TITLE_FONT_SIZE: number = 16;
  static readonly CHAT_ROW_PREVIEW_FONT_SIZE: number = 15;
  static readonly CHAT_ROW_TITLE_VERIFIED_GAP: number = 4;
  static readonly CHAT_ROW_TITLE_MUTE_GAP: number = 4;
  static readonly CHAT_ROW_PREVIEW_PREFIX_GAP: number = 4;
  static readonly CHAT_ROW_MUTE_ICON_SIZE: number = TgUiTokens.ICON_SIZE_XS;
  static readonly CHAT_ROW_VERIFIED_BADGE_SIZE: number = 16;
  static readonly CHAT_ROW_VERIFIED_ICON_SIZE: number = 10;
  static readonly CHAT_ROW_VERIFIED_BADGE_BG: Resource = $r('app.color.telegram_blue');
  static readonly CHAT_ROW_VERIFIED_ICON_TINT: Resource = $r('app.color.unread_text');
  static readonly CHAT_ROW_SEPARATOR_STROKE: number = 0.5;
  static readonly CHAT_ROW_META_FIXED_WIDTH: number = 76;
  static readonly CHAT_META_MIN_WIDTH: number = 76;
  static readonly CHAT_META_TOP_ROW_HEIGHT: number = 18;
  static readonly CHAT_META_BOTTOM_ROW_HEIGHT: number = 20;
  static readonly CHAT_META_ROW_GAP: number = 2;
  static readonly CHAT_META_TIME_FONT_SIZE: number = 14;
  static readonly CHAT_META_BADGE_FONT_SIZE: number = 14;
  static readonly CHAT_META_STATUS_ICON_SIZE: number = 14;
  static readonly CHAT_META_STATUS_GAP: number = 4;
  static readonly CHAT_META_PIN_ICON_SIZE: number = 12;
  static readonly CHAT_META_BOTTOM_PLACEHOLDER_WIDTH: number = TgUiTokens.UNREAD_BADGE_MAX_WIDTH;
  static readonly CHAT_META_BOTTOM_PLACEHOLDER_HEIGHT: number = TgUiTokens.UNREAD_BADGE_HEIGHT;
  static readonly CHAT_ROW_SEPARATOR_INSET: number = 80;
  static readonly CHAT_ROW_PREVIEW_MAX_LINES: number = 2;

  // ── Message text / bubble groundwork (Phase C Step 0) ──
  // iOS: 0.85 compact, 0.65 regular; Android: ~screenWidth - 80dp
  static readonly BUBBLE_COMPACT_WIDTH_BOUNDARY: number = 500;
  static readonly BUBBLE_MAX_WIDTH_RATIO: number = 0.75;
  static readonly BUBBLE_MAX_WIDTH_RATIO_REGULAR: number = 0.65;
  // iOS: 10-11pt; Android: 9-12dp
  static readonly BUBBLE_PADDING_H: number = 11;
  // iOS: ~6pt; Android: 8dp
  static readonly BUBBLE_PADDING_V: number = 6;
  // iOS: 16pt; Android: 17dp (configurable default)
  static readonly BUBBLE_RADIUS_INCOMING: number = 17;
  static readonly BUBBLE_RADIUS_OUTGOING: number = 17;
  static readonly MSG_BUBBLE_RADIUS: number = 17;
  static readonly MSG_DEMO_BASE_CONTAINER_WIDTH: number = 360;
  static readonly MSG_DEMO_NARROW_CONTAINER_WIDTH: number = 220;
  static readonly MSG_DEMO_WIDE_CONTAINER_WIDTH: number = 340;
  static readonly MSG_DEMO_SIDE_NARROW_CONTAINER_WIDTH: number = 136;
  static readonly MSG_DEMO_SIDE_WIDE_CONTAINER_WIDTH: number = 164;
  static readonly MSG_DEMO_WRAP_INJECT_EVERY: number = 10;
  // ── Sender name in bubbles (iOS: 14pt Semibold) ──
  static readonly MSG_SENDER_NAME_SIZE: number = 14;
  static readonly MSG_SENDER_LINE_HEIGHT: number = 18;
  static readonly MSG_META_INLINE_PAD: number = 8;
  static readonly MSG_SENDER_NAME_WEIGHT = FontWeight.Bold;

  // ── Message avatar (iOS: 34pt, group chats incoming) ──
  static readonly MSG_AVATAR_SIZE: number = 34;
  static readonly MSG_AVATAR_GAP: number = 4;
  static readonly MSG_AVATAR_FONT_SIZE: number = 14;

  // ── Message spacing (iOS: defaultSpacing=2.33, mergedSpacing=0) ──
  static readonly MSG_SPACING_SAME_SENDER: number = 2;
  static readonly MSG_SPACING_DIFF_SENDER: number = 8;

  static readonly MSG_META_ROW_HEIGHT: number = 18;
  static readonly MSG_META_MIN_WIDTH: number = 56;
  static readonly MSG_META_ICON_SIZE: number = TgUiTokens.ICON_SIZE_XS;
  static readonly MSG_META_ICON_GAP: number = 4;
  static readonly MSG_META_TIME_PLACEHOLDER_WIDTH: number = 32;
  static readonly MSG_META_STATUS_PLACEHOLDER_WIDTH: number = 12;
  static readonly MSG_MEDIA_META_OVERLAY_PADDING_H: number = 6;
  static readonly MSG_MEDIA_META_OVERLAY_PADDING_V: number = 3;
  static readonly MSG_MEDIA_META_OVERLAY_RADIUS: number = 10;
  static readonly MSG_MEDIA_META_OVERLAY_MARGIN: number = 6;
  static readonly MSG_MEDIA_META_OVERLAY_BG: string = 'rgba(0,0,0,0.4)';

  // ── Photo bubble (Phase C.1-1) ──
  static readonly PHOTO_BUBBLE_RADIUS: number = 16;
  static readonly PHOTO_BUBBLE_IMAGE_INSET: number = 2;
  static readonly PHOTO_BUBBLE_MIN_WIDTH: number = 170;
  static readonly PHOTO_BUBBLE_MIN_HEIGHT: number = 74;
  static readonly PHOTO_BUBBLE_MAX_WIDTH: number = 300;
  static readonly PHOTO_BUBBLE_MAX_HEIGHT: number = 380;
  static readonly PHOTO_BUBBLE_MAX_WIDTH_REGULAR: number = 440;
  static readonly PHOTO_BUBBLE_MAX_HEIGHT_REGULAR: number = 440;
  static readonly PHOTO_BUBBLE_CAPTION_TOP_GAP: number = 6;
  static readonly PHOTO_BUBBLE_CAPTION_PADDING_H: number = 10;
  static readonly PHOTO_BUBBLE_CAPTION_PADDING_BOTTOM: number = 8;
  static readonly PHOTO_BUBBLE_CAPTION_SIZE: number = 16;
  static readonly PHOTO_BUBBLE_CAPTION_LINE_HEIGHT: number = 21;
  static readonly PHOTO_BUBBLE_CAPTION_MAX_LINES: number = 6;
  static readonly PHOTO_ALBUM_RADIUS: number = 16;
  static readonly PHOTO_ALBUM_GAP: number = 2;
  static readonly PHOTO_ALBUM_MAX_WIDTH: number = 300;
  static readonly PHOTO_ALBUM_MAX_WIDTH_REGULAR: number = 440;
  static readonly PHOTO_ALBUM_MAX_HEIGHT: number = 380;
  static readonly PHOTO_ALBUM_MAX_HEIGHT_REGULAR: number = 440;
  static readonly PHOTO_ALBUM_TWO_HEIGHT_RATIO: number = 0.74;
  static readonly PHOTO_ALBUM_THREE_HEIGHT_RATIO: number = 0.92;
  static readonly PHOTO_ALBUM_THREE_PRIMARY_WIDTH_RATIO: number = 0.58;
  static readonly PHOTO_ALBUM_OVERLAY_TEXT_SIZE: number = 22;
  static readonly PHOTO_ALBUM_OVERLAY_BG: string = 'rgba(0,0,0,0.34)';

  // ── Video bubble (Phase C.1-2) ──
  static readonly VIDEO_BUBBLE_RADIUS: number = 16;
  static readonly VIDEO_BUBBLE_IMAGE_INSET: number = 2;
  static readonly VIDEO_BUBBLE_MIN_WIDTH: number = 170;
  static readonly VIDEO_BUBBLE_MIN_HEIGHT: number = 74;
  static readonly VIDEO_BUBBLE_MAX_WIDTH: number = 300;
  static readonly VIDEO_BUBBLE_MAX_HEIGHT: number = 380;
  static readonly VIDEO_BUBBLE_MAX_WIDTH_REGULAR: number = 440;
  static readonly VIDEO_BUBBLE_MAX_HEIGHT_REGULAR: number = 440;
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
  static readonly VIDEO_BUBBLE_CAPTION_SIZE: number = 16;
  static readonly VIDEO_BUBBLE_CAPTION_LINE_HEIGHT: number = 21;
  static readonly VIDEO_BUBBLE_CAPTION_MAX_LINES: number = 6;

  // ── Instant video / video note bubble ──
  static readonly INSTANT_VIDEO_BUBBLE_SIZE: number = 212;
  static readonly INSTANT_VIDEO_BUBBLE_SIZE_REGULAR: number = 240;
  static readonly INSTANT_VIDEO_BUBBLE_MIN_SIZE: number = 160;
  static readonly INSTANT_VIDEO_BUBBLE_PLAY_BG_SIZE: number = 38;
  static readonly INSTANT_VIDEO_BUBBLE_PLAY_ICON_SIZE: number = 18;
  static readonly INSTANT_VIDEO_BUBBLE_DURATION_FONT_SIZE: number = 12;
  static readonly INSTANT_VIDEO_BUBBLE_DURATION_LINE_HEIGHT: number = 14;
  static readonly INSTANT_VIDEO_BUBBLE_DURATION_RADIUS: number = 10;
  static readonly INSTANT_VIDEO_BUBBLE_DURATION_PADDING_H: number = 8;
  static readonly INSTANT_VIDEO_BUBBLE_DURATION_PADDING_V: number = 3;
  static readonly INSTANT_VIDEO_BUBBLE_DURATION_MARGIN: number = 8;

  // ── Audio / music bubble ──
  static readonly AUDIO_BUBBLE_MIN_WIDTH: number = 180;
  static readonly AUDIO_BUBBLE_MAX_WIDTH: number = 320;
  static readonly AUDIO_BUBBLE_MAX_WIDTH_REGULAR: number = 360;
  static readonly AUDIO_BUBBLE_RADIUS: number = 18;
  static readonly AUDIO_BUBBLE_PADDING_H: number = 8;
  static readonly AUDIO_BUBBLE_PADDING_V: number = 8;
  static readonly AUDIO_BUBBLE_CONTENT_GAP: number = 8;
  static readonly AUDIO_BUBBLE_BUTTON_SIZE: number = 44;
  static readonly AUDIO_BUBBLE_BUTTON_ICON_SIZE: number = 20;
  static readonly AUDIO_BUBBLE_BUTTON_RING_STROKE: number = 3;
  static readonly AUDIO_BUBBLE_ART_SIZE: number = 44;
  static readonly AUDIO_BUBBLE_ART_RADIUS: number = 22;
  static readonly AUDIO_BUBBLE_ART_ICON_SIZE: number = 18;
  static readonly AUDIO_BUBBLE_ACTION_SIZE: number = 24;
  static readonly AUDIO_BUBBLE_ACTION_ICON_SIZE: number = 12;
  static readonly AUDIO_BUBBLE_ACTION_OFFSET: number = 2;
  static readonly AUDIO_BUBBLE_TITLE_SIZE: number = 16;
  static readonly AUDIO_BUBBLE_TITLE_LINE_HEIGHT: number = 20;
  static readonly AUDIO_BUBBLE_META_SIZE: number = 13;
  static readonly AUDIO_BUBBLE_META_LINE_HEIGHT: number = 16;
  static readonly AUDIO_BUBBLE_BOTTOM_META_SIZE: number = 11;
  static readonly AUDIO_BUBBLE_BOTTOM_META_LINE_HEIGHT: number = 13;
  static readonly AUDIO_BUBBLE_SEEK_HEIGHT: number = 4;
  static readonly AUDIO_BUBBLE_SEEK_RADIUS: number = 2;
  static readonly AUDIO_BUBBLE_SEEK_TOP_GAP: number = 6;
  static readonly AUDIO_BUBBLE_ART_GRADIENT_START: string = '#51b4ff';
  static readonly AUDIO_BUBBLE_ART_GRADIENT_END: string = '#2b88d4';

  // ── Document row (Phase C.1-3) ──
  static readonly DOCUMENT_ROW_RADIUS: number = 18;
  static readonly DOCUMENT_ROW_MIN_WIDTH: number = 170;
  static readonly DOCUMENT_ROW_MAX_WIDTH: number = 300;
  static readonly DOCUMENT_ROW_PADDING_H: number = 12;
  static readonly DOCUMENT_ROW_PADDING_V: number = 15;
  static readonly DOCUMENT_ROW_ICON_BOX_SIZE: number = 48;
  static readonly DOCUMENT_ROW_ICON_SIZE: number = 22;
  static readonly DOCUMENT_ROW_ICON_RADIUS: number = 12;
  static readonly DOCUMENT_ROW_CONTENT_GAP: number = 10;
  static readonly DOCUMENT_ROW_TEXT_GAP: number = 2;
  static readonly DOCUMENT_ROW_EXTENSION_SIZE: number = 14;
  static readonly DOCUMENT_ROW_EXTENSION_LINE_HEIGHT: number = 16;
  static readonly DOCUMENT_ROW_EXTENSION_MAX_LEN: number = 4;
  static readonly DOCUMENT_ROW_TITLE_SIZE: number = 16;
  static readonly DOCUMENT_ROW_TITLE_LINE_HEIGHT: number = 20;
  static readonly DOCUMENT_ROW_META_SIZE: number = 13;
  static readonly DOCUMENT_ROW_META_LINE_HEIGHT: number = 16;
  static readonly DOCUMENT_ROW_PROGRESS_HEIGHT: number = 3;
  static readonly DOCUMENT_ROW_PROGRESS_RADIUS: number = 2;
  static readonly DOCUMENT_ROW_PROGRESS_TOP_GAP: number = 6;
  static readonly DOCUMENT_ROW_PROGRESS_MIN_VISIBLE_PERCENT: number = 2;
  static readonly DOCUMENT_ROW_PROGRESS_RING_STROKE: number = 3;
  static readonly DOCUMENT_ROW_ACTION_SIZE: number = 22;
  static readonly DOCUMENT_ROW_ACTION_ICON_SIZE: number = 12;
  static readonly DOCUMENT_ROW_ACTION_OFFSET: number = 3;

  // ── Voice bubble (Phase C.1-4) ──
  static readonly VOICE_BUBBLE_RADIUS: number = 18;
  static readonly VOICE_BUBBLE_MIN_WIDTH: number = 120;
  static readonly VOICE_BUBBLE_MAX_WIDTH: number = 300;
  static readonly VOICE_BUBBLE_MAX_WIDTH_REGULAR: number = 360;
  static readonly VOICE_BUBBLE_PADDING_H: number = 10;
  static readonly VOICE_BUBBLE_PADDING_V: number = 8;
  static readonly VOICE_BUBBLE_CONTENT_GAP: number = 8;
  static readonly VOICE_BUBBLE_BUTTON_SIZE: number = 40;
  static readonly VOICE_BUBBLE_BUTTON_ICON_SIZE: number = 18;
  static readonly VOICE_BUBBLE_DURATION_MIN_SEC: number = 2;
  static readonly VOICE_BUBBLE_DURATION_MAX_SEC: number = 30;
  static readonly VOICE_BUBBLE_MIN_WAVEFORM_WIDTH: number = 52;
  static readonly VOICE_BUBBLE_WAVE_BARS_COUNT: number = 28;
  static readonly VOICE_BUBBLE_WAVE_BAR_WIDTH: number = 2;
  static readonly VOICE_BUBBLE_WAVE_BAR_GAP: number = 2;
  static readonly VOICE_BUBBLE_WAVE_MIN_HEIGHT: number = 3;
  static readonly VOICE_BUBBLE_WAVE_MAX_HEIGHT: number = 20;
  static readonly VOICE_BUBBLE_WAVE_AREA_HEIGHT: number = 24;
  static readonly VOICE_BUBBLE_DURATION_SIZE: number = 12;
  static readonly VOICE_BUBBLE_DURATION_LINE_HEIGHT: number = 14;
  static readonly VOICE_BUBBLE_DURATION_MIN_WIDTH: number = 34;

  // ── Sticker view (Phase C.1-5) ──
  static readonly STICKER_VIEW_MAX_SIZE: number = 184;
  static readonly STICKER_VIEW_ANIMATED_MAX_SIZE: number = 240;
  static readonly STICKER_VIEW_MIN_SIZE: number = 72;
  static readonly STICKER_VIEW_PLACEHOLDER_SIZE: number = 56;
  static readonly STICKER_VIEW_EMOJI_SIZE: number = 14;
  static readonly STICKER_VIEW_EMOJI_LINE_HEIGHT: number = 16;
  static readonly STICKER_VIEW_EMOJI_TOP_GAP: number = 4;

  // ── Reply snippet (Phase C Step 3) ──
  static readonly MSG_QUOTE_RADIUS: number = 4;
  static readonly MSG_QUOTE_PADDING_H: number = 8;
  static readonly MSG_QUOTE_PADDING_V: number = 4;
  static readonly MSG_QUOTE_BAR_WIDTH: number = 3;
  static readonly MSG_QUOTE_BAR_RADIUS: number = 2;
  static readonly MSG_QUOTE_BAR_GAP: number = 6;
  static readonly MSG_QUOTE_SEGMENT_GAP: number = 2;
  static readonly MSG_QUOTE_COLLAPSED_OPACITY: number = 0.9;

  static readonly REPLY_SNIPPET_MIN_HEIGHT: number = 32;
  static readonly REPLY_SNIPPET_PADDING_H: number = TgUiTokens.MSG_QUOTE_PADDING_H;
  static readonly REPLY_SNIPPET_PADDING_V: number = 3;
  static readonly REPLY_SNIPPET_BAR_WIDTH: number = TgUiTokens.MSG_QUOTE_BAR_WIDTH;
  static readonly REPLY_SNIPPET_BAR_RADIUS: number = TgUiTokens.MSG_QUOTE_BAR_RADIUS;
  static readonly REPLY_SNIPPET_BAR_GAP: number = TgUiTokens.MSG_QUOTE_BAR_GAP;
  static readonly REPLY_SNIPPET_TEXT_GAP: number = 0;
  static readonly REPLY_SNIPPET_TITLE_SIZE: number = 14;
  static readonly REPLY_SNIPPET_TITLE_WEIGHT = FontWeight.Bold;
  static readonly REPLY_SNIPPET_TITLE_LINE_HEIGHT: number = 15;
  static readonly REPLY_SNIPPET_PREVIEW_SIZE: number = 14;
  static readonly REPLY_SNIPPET_PREVIEW_WEIGHT = FontWeight.Regular;
  static readonly REPLY_SNIPPET_PREVIEW_LINE_HEIGHT: number = 15;
  static readonly REPLY_SNIPPET_TITLE_INCOMING: Resource = $r('app.color.telegram_blue');
  static readonly REPLY_SNIPPET_TITLE_OUTGOING: Resource = $r('app.color.telegram_blue');
  static readonly REPLY_SNIPPET_PREVIEW_INCOMING: Resource = $r('app.color.text_primary');
  static readonly REPLY_SNIPPET_PREVIEW_OUTGOING: Resource = $r('app.color.text_primary');
  static readonly REPLY_SNIPPET_BAR_INCOMING: Resource = $r('app.color.telegram_blue');
  static readonly REPLY_SNIPPET_BAR_OUTGOING: Resource = $r('app.color.telegram_blue');
  static readonly REPLY_SNIPPET_BG_INCOMING: string = TgUiTokens.MSG_QUOTE_BG_INCOMING;
  static readonly REPLY_SNIPPET_BG_OUTGOING: string = TgUiTokens.MSG_QUOTE_BG_OUTGOING;
  static readonly REPLY_SNIPPET_BG_RADIUS: number = TgUiTokens.MSG_QUOTE_RADIUS;
  static readonly REPLY_SNIPPET_THUMB_SIZE: number = 24;
  static readonly REPLY_SNIPPET_THUMB_RADIUS: number = 6;
  static readonly REPLY_SNIPPET_THUMB_GAP: number = 6;
  static readonly REPLY_SNIPPET_QUOTE_MARK_SIZE: number = 10;
  static readonly REPLY_SNIPPET_QUOTE_MARK_LINE_HEIGHT: number = 10;
  static readonly REPLY_SNIPPET_QUOTE_MARK_TOP: number = 3;
  static readonly REPLY_SNIPPET_QUOTE_MARK_RIGHT: number = 3;
  static readonly REPLY_SNIPPET_MAX_TITLE_LINES: number = 1;
  static readonly REPLY_SNIPPET_MAX_PREVIEW_LINES: number = 1;
  static readonly REPLY_SNIPPET_QUOTE_MAX_TITLE_LINES: number = 2;
  static readonly REPLY_SNIPPET_QUOTE_MAX_PREVIEW_LINES: number = 3;

  static isRegularMessageWidth(containerWidth: number): boolean {
    return containerWidth >= TgUiTokens.BUBBLE_COMPACT_WIDTH_BOUNDARY;
  }

  static resolveBubbleMaxWidthRatio(containerWidth: number, requestedRatio: number = TgUiTokens.BUBBLE_MAX_WIDTH_RATIO): number {
    if (Math.abs(requestedRatio - TgUiTokens.BUBBLE_MAX_WIDTH_RATIO) < 0.001) {
      return TgUiTokens.isRegularMessageWidth(containerWidth)
        ? TgUiTokens.BUBBLE_MAX_WIDTH_RATIO_REGULAR
        : TgUiTokens.BUBBLE_MAX_WIDTH_RATIO;
    }
    return requestedRatio;
  }

  static resolveBubbleMaxWidth(containerWidth: number, requestedRatio: number = TgUiTokens.BUBBLE_MAX_WIDTH_RATIO): number {
    const effectiveRatio = TgUiTokens.resolveBubbleMaxWidthRatio(containerWidth, requestedRatio);
    return Math.max(1, Math.floor(containerWidth * effectiveRatio));
  }

  static resolvePhotoBubbleMaxWidth(containerWidth: number): number {
    return TgUiTokens.isRegularMessageWidth(containerWidth)
      ? TgUiTokens.PHOTO_BUBBLE_MAX_WIDTH_REGULAR
      : TgUiTokens.PHOTO_BUBBLE_MAX_WIDTH;
  }

  static resolvePhotoBubbleMaxHeight(containerWidth: number): number {
    return TgUiTokens.isRegularMessageWidth(containerWidth)
      ? TgUiTokens.PHOTO_BUBBLE_MAX_HEIGHT_REGULAR
      : TgUiTokens.PHOTO_BUBBLE_MAX_HEIGHT;
  }

  static resolveVideoBubbleMaxWidth(containerWidth: number): number {
    return TgUiTokens.isRegularMessageWidth(containerWidth)
      ? TgUiTokens.VIDEO_BUBBLE_MAX_WIDTH_REGULAR
      : TgUiTokens.VIDEO_BUBBLE_MAX_WIDTH;
  }

  static resolveVideoBubbleMaxHeight(containerWidth: number): number {
    return TgUiTokens.isRegularMessageWidth(containerWidth)
      ? TgUiTokens.VIDEO_BUBBLE_MAX_HEIGHT_REGULAR
      : TgUiTokens.VIDEO_BUBBLE_MAX_HEIGHT;
  }

  static resolveInstantVideoBubbleSize(containerWidth: number): number {
    const target = TgUiTokens.isRegularMessageWidth(containerWidth)
      ? TgUiTokens.INSTANT_VIDEO_BUBBLE_SIZE_REGULAR
      : TgUiTokens.INSTANT_VIDEO_BUBBLE_SIZE;
    return Math.max(TgUiTokens.INSTANT_VIDEO_BUBBLE_MIN_SIZE, Math.min(Math.floor(containerWidth), target));
  }

  static resolveAudioBubbleWidth(containerWidth: number, maxWidthRatio: number): number {
    const byRatio = TgUiTokens.resolveBubbleMaxWidth(containerWidth, maxWidthRatio);
    const maxAllowed = TgUiTokens.isRegularMessageWidth(containerWidth)
      ? TgUiTokens.AUDIO_BUBBLE_MAX_WIDTH_REGULAR
      : TgUiTokens.AUDIO_BUBBLE_MAX_WIDTH;
    const minAllowed = Math.min(TgUiTokens.AUDIO_BUBBLE_MIN_WIDTH, Math.max(1, Math.floor(containerWidth)));
    return Math.max(minAllowed, Math.min(byRatio, maxAllowed));
  }

  static resolvePhotoAlbumMaxWidth(containerWidth: number): number {
    return TgUiTokens.isRegularMessageWidth(containerWidth)
      ? TgUiTokens.PHOTO_ALBUM_MAX_WIDTH_REGULAR
      : TgUiTokens.PHOTO_ALBUM_MAX_WIDTH;
  }

  static resolvePhotoAlbumMaxHeight(containerWidth: number): number {
    return TgUiTokens.isRegularMessageWidth(containerWidth)
      ? TgUiTokens.PHOTO_ALBUM_MAX_HEIGHT_REGULAR
      : TgUiTokens.PHOTO_ALBUM_MAX_HEIGHT;
  }

  static resolveVoiceBubbleMaxWidth(containerWidth: number): number {
    return TgUiTokens.isRegularMessageWidth(containerWidth)
      ? TgUiTokens.VOICE_BUBBLE_MAX_WIDTH_REGULAR
      : TgUiTokens.VOICE_BUBBLE_MAX_WIDTH;
  }

  static resolveVoiceBubbleWidth(containerWidth: number, maxWidthRatio: number, durationSec: number): number {
    const byRatio = TgUiTokens.resolveBubbleMaxWidth(containerWidth, maxWidthRatio);
    const maxAllowed = Math.min(byRatio, TgUiTokens.resolveVoiceBubbleMaxWidth(containerWidth));
    const minAllowed = Math.min(TgUiTokens.VOICE_BUBBLE_MIN_WIDTH, Math.max(1, Math.floor(containerWidth)));
    const clampedDuration = Math.max(TgUiTokens.VOICE_BUBBLE_DURATION_MIN_SEC,
      Math.min(TgUiTokens.VOICE_BUBBLE_DURATION_MAX_SEC, durationSec));
    const scaledWidth = minAllowed + (maxAllowed - minAllowed) *
      (clampedDuration - TgUiTokens.VOICE_BUBBLE_DURATION_MIN_SEC) /
      (TgUiTokens.VOICE_BUBBLE_DURATION_MAX_SEC - TgUiTokens.VOICE_BUBBLE_DURATION_MIN_SEC);
    const contentMinWidth = TgUiTokens.VOICE_BUBBLE_PADDING_H * 2 +
      TgUiTokens.VOICE_BUBBLE_BUTTON_SIZE +
      TgUiTokens.VOICE_BUBBLE_CONTENT_GAP +
      TgUiTokens.VOICE_BUBBLE_MIN_WAVEFORM_WIDTH +
      TgUiTokens.VOICE_BUBBLE_CONTENT_GAP +
      TgUiTokens.VOICE_BUBBLE_DURATION_MIN_WIDTH;
    return Math.max(minAllowed, Math.min(maxAllowed, Math.max(contentMinWidth, Math.floor(scaledWidth))));
  }

  // ── Date separator + unread marker (Phase C Step 4) ──
  static readonly DATE_SEPARATOR_BG: Resource = $r('app.color.date_separator_bg');
  static readonly DATE_SEPARATOR_TEXT: Resource = $r('app.color.text_on_overlay');
  static readonly DATE_SEPARATOR_FONT_SIZE: number = 13;
  static readonly DATE_SEPARATOR_FONT_WEIGHT = FontWeight.Medium;
  static readonly DATE_SEPARATOR_LINE_HEIGHT: number = 16;
  static readonly DATE_SEPARATOR_PADDING_H: number = 6;
  static readonly DATE_SEPARATOR_PADDING_V: number = 4;
  static readonly DATE_SEPARATOR_RADIUS: number = 12;
  static readonly DATE_SEPARATOR_MIN_HEIGHT: number = 34;
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

  // ── Composer input (iOS-aligned) ──
  static readonly COMPOSER_BUTTON_SIZE: number = 36;
  static readonly COMPOSER_ICON_SIZE: number = 22;
  static readonly COMPOSER_TEXT_SIZE: number = 17;
  static readonly COMPOSER_TEXT_WEIGHT = FontWeight.Regular;
  static readonly COMPOSER_MAX_LINES: number = 12;
  static readonly COMPOSER_MIN_CAPSULE_HEIGHT: number = 38;
  static readonly COMPOSER_CAPSULE_RADIUS: number = 19;
  static readonly COMPOSER_TEXT_PADDING_TOP: number = 5;
  static readonly COMPOSER_TEXT_PADDING_BOTTOM: number = 4;
  static readonly COMPOSER_TEXT_PADDING_LEFT: number = 12;
  static readonly COMPOSER_TEXT_PADDING_RIGHT: number = 0;
  static readonly COMPOSER_SIDE_INSET: number = 8;
  static readonly COMPOSER_VERTICAL_INSET: number = 5;
  static readonly COMPOSER_REPLY_GAP: number = 4;
  static readonly COMPOSER_REPLY_CLOSE_SIZE: number = 20;
  static readonly COMPOSER_REPLY_CLOSE_GAP: number = 4;
  static readonly COMPOSER_BORDER_WIDTH: number = 0.75;
  static readonly COMPOSER_ATTACH_LEFT_INSET: number = 4;
  static readonly COMPOSER_ELEMENT_GAP: number = 6;
  static readonly COMPOSER_CAPSULE_BG: Resource = $r('app.color.glass_nav_bg');
  static readonly COMPOSER_CAPSULE_FALLBACK_BG: Resource = $r('app.color.comp_background_tertiary');
  static readonly COMPOSER_CAPSULE_BORDER: Resource = $r('app.color.glass_edge_highlight');
  static readonly COMPOSER_TEXT: Resource = $r('app.color.text_primary');
  static readonly COMPOSER_PLACEHOLDER: Resource = $r('app.color.text_secondary');
  static readonly COMPOSER_ACTION_ACTIVE: Resource = $r('app.color.telegram_blue');
  static readonly COMPOSER_ACTION_INACTIVE: Resource = $r('app.color.text_secondary');
  static readonly COMPOSER_DISABLED_OPACITY: number = 0.55;

  // ── Tab bar capsule (iOS-aligned) ──
  static readonly TAB_BAR_ISLAND_HEIGHT: number = 57;
  static readonly TAB_BAR_ISLAND_RADIUS: number = 999;
  static readonly TAB_BAR_ISLAND_BOTTOM_MARGIN: number = 10;
  static readonly TAB_BAR_ISLAND_MAX_WIDTH: number = 328;
  static readonly TAB_BAR_ISLAND_BG: Resource = $r('app.color.tab_bar_glass_bg');
  static readonly TAB_BAR_ISLAND_FALLBACK_BG: Resource = $r('app.color.background_secondary');
  static readonly TAB_BAR_ISLAND_BORDER_WIDTH: number = 0.75;
  static readonly TAB_BAR_ISLAND_BORDER_COLOR: Resource = $r('app.color.tab_bar_edge_highlight');
  static readonly TAB_BAR_ISLAND_SHADOW_COLOR: Resource = $r('app.color.glass_card_shadow');
  static readonly TAB_BAR_ISLAND_SHADOW_RADIUS: number = 24;
  static readonly TAB_BAR_ISLAND_SHADOW_OFFSET_Y: number = 10;
  static readonly TAB_BAR_ISLAND_INNER_PADDING: number = 5;
  static readonly TAB_BAR_ICON_SIZE: number = 24;
  static readonly TAB_BAR_TEXT_SIZE: number = 12;
  static readonly TAB_BAR_PILL_BG: Resource = $r('app.color.tab_pill_bg');
  static readonly TAB_BAR_PILL_BORDER_WIDTH: number = 0.5;
  static readonly TAB_BAR_PILL_ANIM_DURATION: number = 320;
  static readonly TAB_BAR_PILL_UNSELECTED_SCALE: number = 0.7;
  static readonly TAB_BAR_ITEM_SELECTED_CONTENT_SCALE: number = 1.0;
  static readonly TAB_BAR_ITEM_UNSELECTED_CONTENT_SCALE: number = 0.94;
  static readonly TAB_BAR_ITEM_SELECTED_CONTENT_OPACITY: number = 1.0;
  static readonly TAB_BAR_ITEM_UNSELECTED_CONTENT_OPACITY: number = 0.9;
  static readonly TAB_BAR_BADGE_HEIGHT: number = 18;
  static readonly TAB_BAR_BADGE_MIN_WIDTH: number = 18;
  static readonly TAB_BAR_BADGE_RADIUS: number = 9;
  static readonly TAB_BAR_BADGE_FONT_SIZE: number = 11;
  static readonly TAB_BAR_BADGE_PADDING_H: number = 4;
  static readonly TAB_BAR_CONTENT_SAFE_BOTTOM: number = 82;

  // ── Filter bar (Phase G) ──
  static readonly FILTER_BAR_HEIGHT: number = 44;
  static readonly FILTER_BAR_RADIUS: number = 22;
  static readonly FILTER_BAR_SIDE_INSET: number = 16;
  static readonly FILTER_BAR_INNER_PADDING: number = 14;
  static readonly FILTER_BAR_MAX_WIDTH: number = 560;
  static readonly FILTER_BAR_BG: Resource = $r('app.color.glass_tab_bg');
  static readonly FILTER_BAR_FALLBACK_BG: Resource = $r('app.color.background_secondary');
  static readonly FILTER_BAR_BORDER_WIDTH: number = 0.75;
  static readonly FILTER_BAR_BORDER_COLOR: Resource = $r('app.color.glass_edge_highlight');
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

  // ── Swipe action colors (iOS: constructive/neutral2/destructive) ──
  static readonly SWIPE_ACTION_PIN: Resource = $r('app.color.swipe_action_green');
  static readonly SWIPE_ACTION_MUTE: Resource = $r('app.color.settings_icon_orange');
  static readonly SWIPE_ACTION_DELETE: Resource = $r('app.color.settings_icon_red');

  // ── Tab bar badge offset (Phase F-extra) ──
  static readonly TAB_BAR_BADGE_OFFSET_X: number = 12;
  static readonly TAB_BAR_BADGE_OFFSET_Y: number = -6;

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

  // ── Chat top bar capsules ──
  // ── Chat top bar (glass capsules) ──
  // Sizing constants are local to TgChatTopBar; only color/resource tokens here.
  static readonly CHAT_TOP_BAR_CAPSULE_BG: Resource = $r('app.color.glass_nav_bg');
  static readonly CHAT_TOP_BAR_CAPSULE_FALLBACK_BG: Resource = $r('app.color.comp_background_tertiary');
  static readonly CHAT_TOP_BAR_CAPSULE_BORDER: Resource = $r('app.color.glass_edge_highlight');

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
  static readonly ICON_RES_CLOSE: Resource = $r('app.media.ic_close');
  static readonly ICON_RES_DOCUMENT: Resource = $r('app.media.ic_document');
  static readonly ICON_RES_DOWNLOAD: Resource = $r('app.media.ic_download');
  static readonly ICON_RES_STICKER: Resource = $r('app.media.ic_sticker');
  static readonly ICON_RES_PHOTO: Resource = $r('app.media.ic_photo');
  static readonly ICON_RES_VIDEO: Resource = $r('app.media.ic_video');
  static readonly ICON_RES_PLAY: Resource = $r('app.media.ic_play');
  static readonly ICON_RES_PAUSE: Resource = $r('app.media.ic_pause');
  static readonly ICON_RES_VOICE: Resource = $r('app.media.ic_voice');
  static readonly ICON_RES_SEARCH: Resource = $r('app.media.ic_search');
  static readonly ICON_RES_EDIT: Resource = $r('app.media.ic_edit');
  static readonly ICON_RES_CONTACT: Resource = $r('app.media.ic_contact');
  static readonly ICON_RES_CONTACT_ADD: Resource = $r('app.media.ic_contact_add');
  static readonly ICON_RES_PHONE_CALL: Resource = $r('app.media.ic_phone_call');
  static readonly ICON_RES_CALL_INCOMING: Resource = $r('app.media.ic_call_incoming');
  static readonly ICON_RES_CALL_OUTGOING: Resource = $r('app.media.ic_call_outgoing');
  static readonly ICON_RES_SETTINGS: Resource = $r('app.media.ic_settings');
  static readonly ICON_RES_ARROW_RIGHT: Resource = $r('app.media.ic_arrow_right');
  static readonly ICON_RES_MUSIC: Resource = $r('app.media.ic_music');
}

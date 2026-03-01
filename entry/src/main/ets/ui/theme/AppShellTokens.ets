// AppShellTokens — shared visual constants for root shell components
// (tabs, top bar, list row skeleton). Phase 0 foundation.

export class AppShellTokens {
  // ── Colors ──
  static readonly ACCENT: Resource = $r('app.color.telegram_blue');
  static readonly TEXT_PRIMARY: Resource = $r('app.color.text_primary');
  static readonly TEXT_SECONDARY: Resource = $r('app.color.text_secondary');
  static readonly BACKGROUND: Resource = $r('app.color.background_primary');
  static readonly BACKGROUND_SECONDARY: Resource = $r('app.color.background_secondary');
  static readonly SEPARATOR: Resource = $r('app.color.separator');
  static readonly CHATLIST_SEPARATOR: Resource = $r('app.color.chatlist_separator');
  static readonly CHATLIST_PINNED_ITEM_BG: Resource = $r('app.color.chatlist_pinned_item_bg');
  static readonly ICON_ON_PRIMARY: Resource = $r('app.color.icon_on_primary');
  static readonly PLACEHOLDER_BG: Resource = $r('app.color.placeholder_bg');
  static readonly BADGE_BG: Resource = $r('app.color.unread_badge');
  static readonly BADGE_TEXT: Resource = $r('app.color.unread_text');
  static readonly TOP_BAR_GLASS_BG: Resource = $r('app.color.glass_nav_bg');
  static readonly TOP_BAR_GLASS_FALLBACK_BG: Resource = $r('app.color.background_secondary');

  // ── Tabs ──
  static readonly TAB_BAR_HEIGHT: number = 50;
  static readonly TAB_ITEM_HEIGHT: number = 50;
  static readonly TAB_ICON_SIZE: number = 23;
  static readonly TAB_TEXT_SIZE: number = 10;
  static readonly TAB_BADGE_HEIGHT: number = 18;
  static readonly TAB_BADGE_RADIUS: number = 9;
  static readonly TAB_BADGE_MIN_WIDTH: number = 18;
  static readonly TAB_BAR_ISLAND_BG: Resource = $r('app.color.glass_tab_bg');
  static readonly TAB_BAR_ISLAND_FALLBACK_BG: Resource = $r('app.color.background_secondary');
  static readonly TAB_BAR_ISLAND_RADIUS: number = 999;
  static readonly TAB_BAR_ISLAND_SIDE_INSET: number = 20;
  static readonly TAB_BAR_ISLAND_BORDER_WIDTH: number = 1;
  static readonly TAB_BAR_ISLAND_MAX_WIDTH: number = 560;
  static readonly TAB_BAR_ISLAND_BOTTOM_MARGIN: number = 10;
  static readonly TAB_BAR_CONTENT_SAFE_PADDING: number = 74;

  // ── Top bar ──
  static readonly TOP_BAR_HEIGHT: number = 44;
  static readonly TOP_BAR_TITLE_SIZE: number = 17;
  static readonly TOP_BAR_SIDE_PADDING: number = 12;
  static readonly TOP_BAR_ACTION_SIZE: number = 24;
  static readonly TOP_BAR_ACTION_TOUCH: number = 44;
  static readonly GLASS_SPECULAR_TOP: string = '#22FFFFFF';
  static readonly GLASS_SPECULAR_MID: string = '#08FFFFFF';
  static readonly GLASS_SPECULAR_BOTTOM: string = '#00FFFFFF';

  // ── List row skeleton ──
  static readonly LIST_ROW_HEIGHT: number = 76;
  static readonly LIST_ROW_HORIZONTAL_PADDING: number = 16;
  static readonly LIST_ROW_GAP: number = 12;
  static readonly LIST_ROW_AVATAR_SIZE: number = 54;
  static readonly LIST_ROW_LEADING_TEXT_SIZE: number = 18;
  static readonly LIST_ROW_INITIALS_SIZE: number = 20;
  static readonly LIST_ROW_TITLE_SIZE: number = 16;
  static readonly LIST_ROW_TIME_SIZE: number = 14;
  static readonly LIST_ROW_MESSAGE_SIZE: number = 15;
  static readonly LIST_ROW_SUBTITLE_SIZE: number = 15;
  static readonly LIST_ROW_SUBTITLE_TOP_MARGIN: number = 4;
  static readonly LIST_ROW_BADGE_TEXT_SIZE: number = 14;
  static readonly LIST_ROW_BADGE_HEIGHT: number = 20;
  static readonly LIST_ROW_BADGE_MIN_WIDTH: number = 20;
  static readonly LIST_ROW_BADGE_RADIUS: number = 10;
  static readonly LIST_ROW_BADGE_SIDE_PADDING: number = 6;
  static readonly LIST_ROW_SIDE_GAP_SMALL: number = 4;
  static readonly LIST_ROW_SIDE_GAP_MEDIUM: number = 6;
  static readonly LIST_ROW_STATUS_TEXT_SIZE: number = 13;
  static readonly LIST_ROW_STATUS_ICON_SIZE: number = 16;
  static readonly LIST_ROW_STATUS_TEXT_GAP: number = 8;
  static readonly LIST_ROW_STATUS_LEFT_PADDING: number = 16;
  static readonly LIST_ROW_STATUS_TOP_PADDING: number = 8;
  static readonly LIST_ROW_STATUS_BOTTOM_PADDING: number = 4;
  static readonly LIST_ROW_LOADING_ICON_SIZE: number = 24;
  static readonly PLACEHOLDER_TEXT_TOP_MARGIN: number = 16;
  static readonly LIST_ROW_SEPARATOR_STROKE: number = 0.5;
  static readonly LIST_ROW_CONTENT_START: number =
    AppShellTokens.LIST_ROW_HORIZONTAL_PADDING + AppShellTokens.LIST_ROW_AVATAR_SIZE + AppShellTokens.LIST_ROW_GAP;
}

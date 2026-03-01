// TelegramTheme — HarmonyOS Guidelines compliant theme
// Использует $r() ресурсы для автоматической поддержки light/dark mode
//
// Документация: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/resource-categories-and-access

// ─── Color Resources ───
// Используем Resource type для автоматического переключения тем
export class TgColorRes {
  // Основные цвета из resources/base/element/color.json
  static readonly PRIMARY: Resource = $r('app.color.text_primary');
  static readonly SECONDARY: Resource = $r('app.color.text_secondary');
  static readonly ACCENT: Resource = $r('app.color.telegram_blue');
  static readonly BACKGROUND: Resource = $r('app.color.background_primary');
  static readonly BACKGROUND_SECONDARY: Resource = $r('app.color.background_secondary');
  static readonly SEPARATOR: Resource = $r('app.color.separator');
  static readonly ERROR: Resource = $r('app.color.error_red');
  
  // Дополнительные цвета 
  static readonly PLACEHOLDER: Resource = $r('app.color.placeholder_bg');
  static readonly OVERLAY_DIM: Resource = $r('app.color.overlay_dark');
  static readonly TEXT_ON_OVERLAY: Resource = $r('app.color.text_on_overlay');
  
  // Button colors
  static readonly BUTTON_BG: Resource = $r('app.color.telegram_blue');
  static readonly BUTTON_DISABLED_BG: Resource = $r('app.color.separator');
}

// ─── Size Resources ───
// Используем Resource для размеров из resources/base/element/float.json
export class TgSizeRes {
  static readonly TITLE_FONT: Resource = $r('app.float.font_size_title_large');
  static readonly SUBTITLE_FONT: Resource = $r('app.float.font_size_headline');
  static readonly INPUT_FONT: Resource = $r('app.float.font_size_body');
  static readonly BUTTON_HEIGHT: Resource = $r('app.float.button_height');
  static readonly SPACING_XL: Resource = $r('app.float.spacing_xl');
  static readonly SPACING_XXL: Resource = $r('app.float.spacing_xxl');
}

// ─── Legacy Static Values ───
// Для совместимости с существующим кодом (будут постепенно заменены на Resource)
export class TgColor {
  // Основные цвета (fallback для мест где Resource не поддерживается)
  static readonly PRIMARY: string = '#000000';
  static readonly SECONDARY: string = '#8E8E93';
  static readonly ACCENT: string = '#0088CC';
  static readonly BACKGROUND: string = '#FFFFFF';
  static readonly SEPARATOR: string = '#E5E5EA';
  static readonly PLACEHOLDER: string = '#C7C7CC';
  static readonly ERROR: string = '#FF3B30';
  static readonly DESTRUCTIVE: string = '#FF3B30';
  static readonly HINT: string = '#8E8E93';

  // Кнопка Continue
  static readonly BUTTON_BG: string = '#0088CC';
  static readonly BUTTON_TEXT: string = '#FFFFFF';
  static readonly BUTTON_DISABLED_BG: string = '#E5E5EA';
  static readonly BUTTON_DISABLED_TEXT: string = '#AEAEB2';

  // Overlay
  static readonly OVERLAY_DIM: string = '#00000066';
  static readonly CARD_BG: string = '#FFFFFF';
}

export class TgSize {
  // Анимация обезьянки
  static readonly MONKEY_SIZE: number = 100;

  // Кнопка Continue (HarmonyOS: используем 48vp как стандарт)
  static readonly BUTTON_HEIGHT: number = 48;
  static readonly BUTTON_RADIUS: number = 24;

  // Шрифты (в fp для accessibility)
  static readonly INPUT_FONT: number = 17;
  static readonly TITLE_FONT: number = 28;
  static readonly SUBTITLE_FONT: number = 17;

  // Отступы
  static readonly SIDE_INSET: number = 16;
  static readonly MAX_WIDTH: number = 430;

  // PhoneConfirmation
  static readonly CONFIRM_CORNER: number = 42;
  static readonly CONFIRM_SIDE_INSET: number = 8;
  static readonly CONFIRM_INNER_INSET: number = 18;
}

// ─── Icon Resources ───
// Иконки из resources/base/media/
export class TgIcon {
  static readonly CHECK: Resource = $r('app.media.ic_check');
  static readonly ARROW_RIGHT: Resource = $r('app.media.ic_arrow_right');
  static readonly ARROW_DOWN: Resource = $r('app.media.ic_arrow_down');
  static readonly CLOSE: Resource = $r('app.media.ic_close');
  static readonly BACK: Resource = $r('app.media.ic_back');
  static readonly EYE: Resource = $r('app.media.ic_eye');
  static readonly EYE_OFF: Resource = $r('app.media.ic_eye_off');
}

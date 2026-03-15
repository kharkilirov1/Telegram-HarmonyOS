import { StorageKeys } from '../../../app/bridge/AppStoreBridge';

export type TgGlassMode = 'auto' | 'high' | 'fallback';

// TgGlassPolicy centralizes runtime quality fallback for blur-heavy UI.
// Policy is driven by AppStorage key StorageKeys.GLASS_MODE.
export class TgGlassPolicy {
  static readonly MODE_AUTO: TgGlassMode = 'auto';
  static readonly MODE_HIGH: TgGlassMode = 'high';
  static readonly MODE_FALLBACK: TgGlassMode = 'fallback';

  static normalizeMode(modeValue?: string): TgGlassMode {
    if (modeValue === TgGlassPolicy.MODE_HIGH) {
      return TgGlassPolicy.MODE_HIGH;
    }
    if (modeValue === TgGlassPolicy.MODE_FALLBACK) {
      return TgGlassPolicy.MODE_FALLBACK;
    }
    return TgGlassPolicy.MODE_AUTO;
  }

  static getMode(): TgGlassMode {
    return TgGlassPolicy.normalizeMode(AppStorage.get<string>(StorageKeys.GLASS_MODE));
  }

  static setMode(mode: TgGlassMode): void {
    AppStorage.setOrCreate<string>(StorageKeys.GLASS_MODE, mode);
  }

  static shouldUseRealtimeBlurForMode(modeValue?: string): boolean {
    const mode = TgGlassPolicy.normalizeMode(modeValue);
    return mode === TgGlassPolicy.MODE_AUTO || mode === TgGlassPolicy.MODE_HIGH;
  }

  static shouldUseRealtimeBlur(): boolean {
    return TgGlassPolicy.shouldUseRealtimeBlurForMode(TgGlassPolicy.getMode());
  }

  static topBarBlurStyle(): BlurStyle {
    return TgGlassPolicy.shouldUseRealtimeBlur() ? BlurStyle.COMPONENT_ULTRA_THIN : BlurStyle.NONE;
  }

  static tabBarBlurStyle(): BlurStyle {
    return TgGlassPolicy.shouldUseRealtimeBlur() ? BlurStyle.COMPONENT_ULTRA_THIN : BlurStyle.NONE;
  }

  static filterBarBlurStyle(): BlurStyle {
    return TgGlassPolicy.shouldUseRealtimeBlur() ? BlurStyle.COMPONENT_ULTRA_THIN : BlurStyle.NONE;
  }

  static composerBlurStyle(): BlurStyle {
    return TgGlassPolicy.shouldUseRealtimeBlur() ? BlurStyle.COMPONENT_ULTRA_THIN : BlurStyle.NONE;
  }

  static searchBlurStyle(): BlurStyle {
    return TgGlassPolicy.shouldUseRealtimeBlur() ? BlurStyle.COMPONENT_ULTRA_THIN : BlurStyle.NONE;
  }

  // Adaptive glass options — blur picks up background content colors (like iOS)
  static glassOptions(): BackgroundBlurStyleOptions {
    return {
      adaptiveColor: AdaptiveColor.AVERAGE,
      scale: 1.0
    };
  }

  static edgeBlurRadius(defaultRadius: number): number {
    return TgGlassPolicy.shouldUseRealtimeBlur() ? defaultRadius : 0;
  }
}

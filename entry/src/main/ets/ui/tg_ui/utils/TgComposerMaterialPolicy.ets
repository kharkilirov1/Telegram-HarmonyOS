export type TgComposerMaterialMode = 'nativeImmersive' | 'realtimeBlur' | 'fallback';

export function resolveComposerMaterialMode(
  nativeApiAvailable: boolean,
  nativeEnabled: boolean,
  realtimeBlurEnabled: boolean
): TgComposerMaterialMode {
  if (!realtimeBlurEnabled) {
    return 'fallback';
  }
  if (nativeEnabled && nativeApiAvailable) {
    return 'nativeImmersive';
  }
  return 'realtimeBlur';
}

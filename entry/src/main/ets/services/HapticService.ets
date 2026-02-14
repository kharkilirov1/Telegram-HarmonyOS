// Lightweight haptic feedback helper using @kit.SensorServiceKit vibrator API.
// HarmonyOS NEXT requires 'ohos.permission.VIBRATE' in module.json5.

import { vibrator } from '@kit.SensorServiceKit';

export class HapticService {
  private static instance: HapticService;

  static getInstance(): HapticService {
    if (!HapticService.instance) {
      HapticService.instance = new HapticService();
    }
    return HapticService.instance;
  }

  /** Light tap — send button, tab switch, toggle */
  light(): void {
    this.vibrate(30);
  }

  /** Medium tap — long-press actions, swipe reply, FAB tap */
  medium(): void {
    this.vibrate(50);
  }

  /** Heavy tap — destructive actions (delete), selection mode */
  heavy(): void {
    this.vibrate(80);
  }

  private vibrate(duration: number): void {
    try {
      vibrator.startVibration({
        type: 'time',
        duration: duration
      }, {
        id: 0,
        usage: 'touch'
      });
    } catch (_e) {
      // Silently ignore — device may not support vibration
    }
  }
}

// H9: power saving. iOS lowers autoplay and animation work when the device reports Low Power Mode; the
// platform exposes the mode but no change subscription, so the value is sampled when the app becomes
// visible and cached for the animation policy to read.

import { power } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x00E9;
const TAG = 'PowerModeMonitor';

class PowerModeState {
  powerSaving: boolean = false;
  // Sampled at least once; before that the app keeps the normal defaults.
  sampled: boolean = false;
}

const state: PowerModeState = new PowerModeState();

// MODE_POWER_SAVE / MODE_EXTREME_POWER_SAVE / MODE_CUSTOM_POWER_SAVE all mean "reduce work".
export function isPowerSavingMode(mode: number): boolean {
  if (!Number.isFinite(mode)) {
    return false;
  }
  return mode === power.DevicePowerMode.MODE_POWER_SAVE ||
    mode === power.DevicePowerMode.MODE_EXTREME_POWER_SAVE ||
    mode === power.DevicePowerMode.MODE_CUSTOM_POWER_SAVE;
}

export function refreshPowerMode(): boolean {
  try {
    const mode = power.getPowerMode();
    const powerSaving = isPowerSavingMode(mode);
    state.sampled = true;
    state.powerSaving = powerSaving;
    return powerSaving;
  } catch (error) {
    // Unsupported device or permission: keep the previous value rather than flipping the policy.
    hilog.warn(DOMAIN, TAG, 'Reading the power mode failed: %{public}s', String(error));
    return state.powerSaving;
  }
}

export function isPowerSaving(): boolean {
  return state.powerSaving;
}

export function hasSampledPowerMode(): boolean {
  return state.sampled;
}

// Test seam: EntryAbility and the animation policy both read the cached value.
export function setPowerSavingForTest(value: boolean): void {
  state.sampled = true;
  state.powerSaving = value;
}

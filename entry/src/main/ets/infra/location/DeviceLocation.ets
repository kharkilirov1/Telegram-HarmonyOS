// D25: one-shot device location for the "send location" attachment. Coarse accuracy is enough for a pin,
// and the caller owns the permission prompt so this module stays free of UI concerns.

import { geoLocationManager } from '@kit.LocationKit';
import { Permissions } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x00D25;
const TAG = 'DeviceLocation';

export const LOCATION_PERMISSIONS: Permissions[] = [
  'ohos.permission.APPROXIMATELY_LOCATION',
  'ohos.permission.LOCATION'
];

export class DeviceLocationPoint {
  latitude: number = 0;
  longitude: number = 0;
  accuracy: number = 0;
}

// Resolves undefined when the platform refuses or times out; the caller shows one toast and stops.
export async function getDeviceLocationOnce(): Promise<DeviceLocationPoint | undefined> {
  try {
    const request: geoLocationManager.CurrentLocationRequest = {
      priority: geoLocationManager.LocationRequestPriority.FIRST_FIX,
      scenario: geoLocationManager.LocationRequestScenario.UNSET,
      maxAccuracy: 0,
      timeoutMs: 10000
    };
    const location = await geoLocationManager.getCurrentLocation(request);
    const point = new DeviceLocationPoint();
    point.latitude = location.latitude;
    point.longitude = location.longitude;
    point.accuracy = location.accuracy > 0 ? location.accuracy : 0;
    return point;
  } catch (error) {
    hilog.info(DOMAIN, TAG, 'Location request failed: %{public}s', String(error));
    return undefined;
  }
}

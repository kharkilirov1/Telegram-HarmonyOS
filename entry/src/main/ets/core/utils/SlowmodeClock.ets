import { systemDateTime } from '@kit.BasicServicesKit';

// TDLib's relative expiry already uses server time. STARTUP includes deep
// sleep and is independent of device wall-clock/time-zone adjustments.
export function getSlowmodeElapsedMs(): number {
  return systemDateTime.getUptime(systemDateTime.TimeType.STARTUP, false);
}

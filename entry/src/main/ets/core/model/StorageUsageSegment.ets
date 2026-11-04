// Storage usage segments for the H4c chart.
// Pure helpers so percentages are testable without ArkUI: a segment list plus a scale (the configured
// limit when set, otherwise the total) yields integer percentages that never exceed the whole bar.

export class StorageUsageSegment {
  label: string = '';
  bytes: number = 0;
  // Index into the chart palette; the component maps it, the model stays UI-agnostic.
  colorIndex: number = 0;

  constructor(label: string = '', bytes: number = 0, colorIndex: number = 0) {
    this.label = label;
    this.bytes = bytes;
    this.colorIndex = colorIndex;
  }
}

export function storageChartScale(totalBytes: number, limitBytes: number): number {
  if (Number.isSafeInteger(limitBytes) && limitBytes > 0) {
    return limitBytes;
  }
  return Number.isSafeInteger(totalBytes) && totalBytes > 0 ? totalBytes : 0;
}

// Percent of the bar for one segment; a missing or non-positive scale yields zero.
export function storageSegmentPercent(bytes: number, scaleBytes: number): number {
  if (!Number.isSafeInteger(bytes) || bytes <= 0) {
    return 0;
  }
  if (!Number.isSafeInteger(scaleBytes) || scaleBytes <= 0) {
    return 0;
  }
  const percent: number = (bytes * 100) / scaleBytes;
  return percent > 100 ? 100 : percent;
}

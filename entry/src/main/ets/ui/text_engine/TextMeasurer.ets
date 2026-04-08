// TextMeasurer — Segment width measurement via HarmonyOS MeasureUtils.
// All results cached per (segment, styleKey) pair.

import { TextStyleKey, buildStyleKey } from './TextTypes'

// Segment width cache: Map<styleKey, Map<segmentText, widthVp>>
const widthCache: Map<string, Map<string, number>> = new Map()
const MAX_CACHE_PER_STYLE: number = 8000

export function measureSegmentWidth(uiContext: UIContext, segment: string, style: TextStyleKey): number {
  if (segment.length === 0) return 0

  const key: string = buildStyleKey(style)

  let styleMap: Map<string, number> | undefined = widthCache.get(key)
  if (styleMap !== undefined) {
    const cached: number | undefined = styleMap.get(segment)
    if (cached !== undefined) return cached
  }

  // getMeasureUtils() returns MeasureUtils, measureText() accepts MeasureOptions
  // Types are inferred — not importable as standalone names in ArkTS
  const measureUtils = uiContext.getMeasureUtils()
  const resultPx: number = measureUtils.measureText({
    textContent: segment,
    fontSize: `${style.fontSize}fp`,
    fontWeight: style.fontWeight,
    fontFamily: style.fontFamily ?? 'HarmonyOS Sans',
    letterSpacing: style.letterSpacing ?? 0,
  })

  const widthVp: number = uiContext.px2vp(resultPx)

  if (styleMap === undefined) {
    styleMap = new Map()
    widthCache.set(key, styleMap)
  }
  if (styleMap.size >= MAX_CACHE_PER_STYLE) {
    const entries: string[] = Array.from<string>(styleMap.keys())
    const evictCount: number = Math.floor(entries.length / 4)
    for (let i = 0; i < evictCount; i++) {
      styleMap.delete(entries[i])
    }
  }
  styleMap.set(segment, widthVp)

  return widthVp
}

export class TextSizeResult {
  width: number = 0
  height: number = 0
}

export function measureTextSize(
  uiContext: UIContext,
  text: string,
  style: TextStyleKey,
  maxWidthVp: number
): TextSizeResult {
  const measureUtils = uiContext.getMeasureUtils()
  const sizeResult: SizeOptions = measureUtils.measureTextSize({
    textContent: text,
    fontSize: `${style.fontSize}fp`,
    fontWeight: style.fontWeight,
    fontFamily: style.fontFamily ?? 'HarmonyOS Sans',
    letterSpacing: style.letterSpacing ?? 0,
    lineHeight: `${style.lineHeight}fp`,
    constraintWidth: `${maxWidthVp}vp`,
  })

  const w: number = sizeResult.width as number
  const h: number = sizeResult.height as number

  const result: TextSizeResult = new TextSizeResult()
  result.width = uiContext.px2vp(w)
  result.height = uiContext.px2vp(h)
  return result
}

export function measureSegments(
  uiContext: UIContext,
  segments: string[],
  style: TextStyleKey
): number[] {
  const widths: number[] = new Array<number>(segments.length)
  for (let i = 0; i < segments.length; i++) {
    widths[i] = measureSegmentWidth(uiContext, segments[i], style)
  }
  return widths
}

export function clearMeasureCache(): void {
  widthCache.clear()
}

export class MeasureCacheStats {
  styles: number = 0
  totalSegments: number = 0
}

export function getMeasureCacheStats(): MeasureCacheStats {
  let total: number = 0
  widthCache.forEach((m: Map<string, number>) => { total += m.size })
  const stats: MeasureCacheStats = new MeasureCacheStats()
  stats.styles = widthCache.size
  stats.totalSegments = total
  return stats
}

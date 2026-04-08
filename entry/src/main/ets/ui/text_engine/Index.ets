// Text Engine — barrel export
// Usage: import { TgTextLayout, TextStyleKey } from '../text_engine/Index'

export { TgTextLayout } from './TgTextLayout'
export type { TextStyleKey, PreparedText, LayoutResult, LayoutLine, SegmentBreakKind } from './TextTypes'
export { clearLayoutCaches, getLayoutCacheStats } from './LayoutCache'
export { clearMeasureCache, getMeasureCacheStats } from './TextMeasurer'

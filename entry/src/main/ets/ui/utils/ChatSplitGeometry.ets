export interface ChatSplitGeometry {
  navBarWidth: number;
  maxNavBarWidth: number;
}

// During adaptive Navigation rotation TYPE_SYSTEM can transiently report a
// zero top inset. Preserve the last real portrait value, while landscape uses
// zero unless the platform explicitly reports a positive top avoid area.
export function resolveChatHostTopInset(
  measuredTopInset: number,
  windowWidth: number,
  windowHeight: number,
  portraitFallback: number
): number {
  const safeMeasuredInset = Number.isFinite(measuredTopInset)
    ? Math.max(0, measuredTopInset)
    : 0;
  if (safeMeasuredInset > 0) {
    return safeMeasuredInset;
  }
  const isPortrait = !Number.isFinite(windowWidth) || !Number.isFinite(windowHeight)
    ? true
    : windowHeight >= windowWidth;
  const safePortraitFallback = Number.isFinite(portraitFallback)
    ? Math.max(0, portraitFallback)
    : 0;
  return isPortrait ? safePortraitFallback : 0;
}

// Telegram iOS NavigationSplitContainer:
// min(max(minMasterWidth, floor(width / 3)), floor(width / 2)).
export function resolveChatSplitGeometry(
  componentWidth: number,
  minNavBarWidth: number
): ChatSplitGeometry {
  const safeMinWidth = Math.max(1, Math.floor(minNavBarWidth));
  const safeComponentWidth = Number.isFinite(componentWidth)
    ? Math.max(0, Math.floor(componentWidth))
    : 0;
  const maxNavBarWidth = Math.max(safeMinWidth, Math.floor(safeComponentWidth / 2));
  const preferredNavBarWidth = Math.max(safeMinWidth, Math.floor(safeComponentWidth / 3));
  return {
    navBarWidth: Math.min(preferredNavBarWidth, maxNavBarWidth),
    maxNavBarWidth
  };
}

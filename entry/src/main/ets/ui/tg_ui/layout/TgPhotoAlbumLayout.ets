// Pure grouped-photo mosaic geometry, ported from Telegram iOS MosaicLayout.
// No ArkUI dependencies: the caller owns tokens, rendering and interaction.

const IOS_WIDE_ASPECT_RATIO = 1.2
const IOS_NARROW_ASPECT_RATIO = 0.8
const IOS_FORCE_GENERIC_ASPECT_RATIO = 2.0
const IOS_GENERIC_WIDE_AVERAGE = 1.1
const IOS_GENERIC_NARROW_AVERAGE = 0.85
const IOS_CROPPED_RATIO_MIN = 0.66667
const IOS_CROPPED_RATIO_MAX = 1.7
const IOS_MIN_ITEM_WIDTH = 68
const IOS_MIN_ITEM_HEIGHT = 81
const IOS_MAX_ITEMS_PER_ROW = 3
const IOS_MAX_ROWS = 4
const IOS_TARGET_HEIGHT_RATIO = 4 / 3
const TELEGRAM_ALBUM_MAX_ITEMS = 10

export enum TgPhotoAlbumPosition {
  None = 0,
  Top = 1,
  Bottom = 2,
  Left = 4,
  Right = 8,
  Inside = 16,
}

export interface TgPhotoAlbumItemSize {
  width: number
  height: number
}

export interface TgPhotoAlbumFrame {
  index: number
  x: number
  y: number
  width: number
  height: number
  position: number
}

export interface TgPhotoAlbumLayoutResult {
  frames: TgPhotoAlbumFrame[]
  width: number
  height: number
}

interface MutableAlbumItem {
  index: number
  aspectRatio: number
  frame: TgPhotoAlbumFrame
}

interface MosaicLayoutAttempt {
  lineCounts: number[]
  heights: number[]
}

function positiveDimension(value: number): number {
  return Number.isFinite(value) && value > 0 ? value : 1
}

function nonNegativeDimension(value: number): number {
  return Number.isFinite(value) && value > 0 ? value : 0
}

function makeFrame(index: number): TgPhotoAlbumFrame {
  return {
    index: index,
    x: 0,
    y: 0,
    width: 0,
    height: 0,
    position: TgPhotoAlbumPosition.None,
  }
}

function setFrame(item: MutableAlbumItem, x: number, y: number, width: number, height: number,
  position: number): void {
  item.frame.x = x
  item.frame.y = y
  item.frame.width = Math.max(0, width)
  item.frame.height = Math.max(0, height)
  item.frame.position = position
}

function multiHeight(ratios: number[], start: number, end: number, containerWidth: number,
  spacing: number): number {
  let ratioSum = 0
  for (let index = start; index < end; index++) {
    ratioSum += ratios[index]
  }
  const itemCount = end - start
  const availableWidth = containerWidth - Math.max(0, itemCount - 1) * spacing
  return Math.max(1, availableWidth) / Math.max(0.0001, ratioSum)
}

function buildAttempt(lineCounts: number[], ratios: number[], containerWidth: number,
  spacing: number): MosaicLayoutAttempt {
  const heights: number[] = []
  let start = 0
  for (let index = 0; index < lineCounts.length; index++) {
    const end = start + lineCounts[index]
    heights.push(multiHeight(ratios, start, end, containerWidth, spacing))
    start = end
  }
  return {
    lineCounts: lineCounts,
    heights: heights,
  }
}

function positionForRow(row: number, rowCount: number, column: number, columnCount: number): number {
  // Telegram iOS marks every cell in a middle row as inside, even the row's
  // first and last cells. Those cells must not acquire outer corner radii.
  if (row > 0 && row < rowCount - 1) {
    return TgPhotoAlbumPosition.Inside
  }
  let position = TgPhotoAlbumPosition.None
  if (row === 0) {
    position |= TgPhotoAlbumPosition.Top
  }
  if (row === rowCount - 1) {
    position |= TgPhotoAlbumPosition.Bottom
  }
  if (column === 0) {
    position |= TgPhotoAlbumPosition.Left
  }
  if (column === columnCount - 1) {
    position |= TgPhotoAlbumPosition.Right
  }
  return position
}

function layoutGeneric(items: MutableAlbumItem[], averageAspectRatio: number, containerWidth: number,
  spacing: number): void {
  const croppedRatios: number[] = []
  for (let index = 0; index < items.length; index++) {
    const aspectRatio = items[index].aspectRatio
    const directionalRatio = averageAspectRatio > IOS_GENERIC_WIDE_AVERAGE
      ? Math.max(1, aspectRatio)
      : Math.min(1, aspectRatio)
    croppedRatios.push(Math.max(IOS_CROPPED_RATIO_MIN, Math.min(IOS_CROPPED_RATIO_MAX, directionalRatio)))
  }

  const attempts: MosaicLayoutAttempt[] = []

  for (let firstLine = 1; firstLine < croppedRatios.length; firstLine++) {
    const secondLine = croppedRatios.length - firstLine
    if (firstLine <= IOS_MAX_ITEMS_PER_ROW && secondLine <= IOS_MAX_ITEMS_PER_ROW) {
      attempts.push(buildAttempt([firstLine, secondLine], croppedRatios, containerWidth, spacing))
    }
  }

  for (let firstLine = 1; firstLine < croppedRatios.length - 1; firstLine++) {
    for (let secondLine = 1; secondLine < croppedRatios.length - firstLine; secondLine++) {
      const thirdLine = croppedRatios.length - firstLine - secondLine
      const secondLineLimit = averageAspectRatio < IOS_GENERIC_NARROW_AVERAGE ? 4 : IOS_MAX_ITEMS_PER_ROW
      if (firstLine <= IOS_MAX_ITEMS_PER_ROW && secondLine <= secondLineLimit &&
        thirdLine <= IOS_MAX_ITEMS_PER_ROW) {
        attempts.push(buildAttempt([firstLine, secondLine, thirdLine], croppedRatios, containerWidth, spacing))
      }
    }
  }

  if (croppedRatios.length >= IOS_MAX_ROWS) {
    for (let firstLine = 1; firstLine < croppedRatios.length - 2; firstLine++) {
      for (let secondLine = 1; secondLine < croppedRatios.length - firstLine - 1; secondLine++) {
        for (let thirdLine = 1; thirdLine < croppedRatios.length - firstLine - secondLine; thirdLine++) {
          const fourthLine = croppedRatios.length - firstLine - secondLine - thirdLine
          if (firstLine <= IOS_MAX_ITEMS_PER_ROW && secondLine <= IOS_MAX_ITEMS_PER_ROW &&
            thirdLine <= IOS_MAX_ITEMS_PER_ROW && fourthLine <= IOS_MAX_ITEMS_PER_ROW) {
            attempts.push(buildAttempt([firstLine, secondLine, thirdLine, fourthLine], croppedRatios,
              containerWidth, spacing))
          }
        }
      }
    }
  }

  let optimal: MosaicLayoutAttempt | null = null
  let optimalDiff = 0
  const targetHeight = Math.floor(containerWidth * IOS_TARGET_HEIGHT_RATIO)
  for (let attemptIndex = 0; attemptIndex < attempts.length; attemptIndex++) {
    const attempt = attempts[attemptIndex]
    let totalHeight = spacing * Math.max(0, attempt.heights.length - 1)
    let minLineHeight = Number.MAX_VALUE
    for (let row = 0; row < attempt.heights.length; row++) {
      const lineHeight = Math.floor(attempt.heights[row])
      totalHeight += lineHeight
      minLineHeight = Math.min(minLineHeight, lineHeight)
    }

    let diff = Math.abs(totalHeight - targetHeight)
    for (let row = 0; row < attempt.lineCounts.length - 1; row++) {
      if (attempt.lineCounts[row] > attempt.lineCounts[row + 1]) {
        diff *= 1.5
        break
      }
    }
    if (minLineHeight < IOS_MIN_ITEM_WIDTH) {
      diff *= 1.5
    }

    if (optimal === null || diff < optimalDiff) {
      optimal = attempt
      optimalDiff = diff
    }
  }

  if (optimal === null) {
    return
  }

  let itemIndex = 0
  let y = 0
  for (let row = 0; row < optimal.lineCounts.length; row++) {
    const columnCount = optimal.lineCounts[row]
    const lineHeight = Math.ceil(optimal.heights[row])
    let x = 0
    for (let column = 0; column < columnCount; column++) {
      const width = Math.ceil(croppedRatios[itemIndex] * lineHeight)
      setFrame(items[itemIndex], x, y, width, lineHeight,
        positionForRow(row, optimal.lineCounts.length, column, columnCount))
      x += width + spacing
      itemIndex++
    }
    y += lineHeight + spacing
  }

  // Ceil rounding can leave rows a few pixels apart. Telegram fixes only each row's
  // trailing cell so every row reaches the same right edge without moving earlier cells.
  let maximumRowWidth = 0
  itemIndex = 0
  for (let row = 0; row < optimal.lineCounts.length; row++) {
    const columnCount = optimal.lineCounts[row]
    for (let column = 0; column < columnCount; column++) {
      const frame = items[itemIndex].frame
      if (column === columnCount - 1) {
        maximumRowWidth = Math.max(maximumRowWidth, frame.x + frame.width)
      }
      itemIndex++
    }
  }

  itemIndex = 0
  for (let row = 0; row < optimal.lineCounts.length; row++) {
    const columnCount = optimal.lineCounts[row]
    for (let column = 0; column < columnCount; column++) {
      const frame = items[itemIndex].frame
      if (column === columnCount - 1) {
        frame.width = Math.max(frame.width, maximumRowWidth - frame.x)
      }
      itemIndex++
    }
  }
}

/**
 * Computes Telegram-style grouped-photo frames for albums of 2–10 items.
 *
 * `containerWidth`, `maxHeight` and `spacing` are explicit so the rendering atom
 * can pass the active tg_ui tokens instead of duplicating them in this engine.
 * Dimensions are in the caller's coordinate unit (vp in the ArkUI consumer).
 */
export function computeTgPhotoAlbumLayout(itemSizes: TgPhotoAlbumItemSize[], containerWidth: number,
  maxHeight: number, spacing: number, fillWidth: boolean = false): TgPhotoAlbumLayoutResult {
  const safeWidth = positiveDimension(containerWidth)
  const safeMaxHeight = positiveDimension(maxHeight)
  const safeSpacing = Math.min(nonNegativeDimension(spacing), safeWidth)
  const itemCount = Math.min(itemSizes.length, TELEGRAM_ALBUM_MAX_ITEMS)
  if (itemCount === 0 || containerWidth <= 0 || !Number.isFinite(containerWidth)) {
    return {
      frames: [],
      width: 0,
      height: 0,
    }
  }

  let proportions = ''
  let averageAspectRatio = 1
  let forceGeneric = false
  const items: MutableAlbumItem[] = []
  for (let index = 0; index < itemCount; index++) {
    const width = positiveDimension(itemSizes[index].width)
    const height = positiveDimension(itemSizes[index].height)
    const aspectRatio = width / height
    if (aspectRatio > IOS_WIDE_ASPECT_RATIO) {
      proportions += 'w'
    } else if (aspectRatio < IOS_NARROW_ASPECT_RATIO) {
      proportions += 'n'
    } else {
      proportions += 'q'
    }
    if (aspectRatio > IOS_FORCE_GENERIC_ASPECT_RATIO) {
      forceGeneric = true
    }
    averageAspectRatio += aspectRatio
    items.push({
      index: index,
      aspectRatio: aspectRatio,
      frame: makeFrame(index),
    })
  }
  averageAspectRatio /= itemCount

  if (itemCount === 1) {
    const height = Math.floor(Math.min(safeMaxHeight, safeWidth / items[0].aspectRatio))
    setFrame(items[0], 0, 0, safeWidth, height,
      TgPhotoAlbumPosition.Top | TgPhotoAlbumPosition.Bottom |
      TgPhotoAlbumPosition.Left | TgPhotoAlbumPosition.Right)
  } else if (!forceGeneric && itemCount === 2) {
    if (proportions === 'ww' && averageAspectRatio > 1.4 * (safeWidth / safeMaxHeight) &&
      items[1].aspectRatio - items[0].aspectRatio < 0.2) {
      const height = Math.floor(Math.min(safeWidth / items[0].aspectRatio,
        Math.min(safeWidth / items[1].aspectRatio, (safeMaxHeight - safeSpacing) / 2)))
      setFrame(items[0], 0, 0, safeWidth, height,
        TgPhotoAlbumPosition.Top | TgPhotoAlbumPosition.Left | TgPhotoAlbumPosition.Right)
      setFrame(items[1], 0, height + safeSpacing, safeWidth, height,
        TgPhotoAlbumPosition.Bottom | TgPhotoAlbumPosition.Left | TgPhotoAlbumPosition.Right)
    } else if (proportions === 'ww' || proportions === 'qq') {
      const width = (safeWidth - safeSpacing) / 2
      const height = Math.floor(Math.min(width / items[0].aspectRatio,
        Math.min(width / items[1].aspectRatio, safeMaxHeight)))
      setFrame(items[0], 0, 0, width, height,
        TgPhotoAlbumPosition.Top | TgPhotoAlbumPosition.Left | TgPhotoAlbumPosition.Bottom)
      setFrame(items[1], width + safeSpacing, 0, width, height,
        TgPhotoAlbumPosition.Top | TgPhotoAlbumPosition.Right | TgPhotoAlbumPosition.Bottom)
    } else {
      const secondWidth = Math.floor(Math.min(0.5 * (safeWidth - safeSpacing),
        Math.round((safeWidth - safeSpacing) / items[0].aspectRatio /
          (1 / items[0].aspectRatio + 1 / items[1].aspectRatio))))
      const firstWidth = safeWidth - secondWidth - safeSpacing
      const height = Math.floor(Math.min(safeMaxHeight,
        Math.round(Math.min(firstWidth / items[0].aspectRatio, secondWidth / items[1].aspectRatio))))
      setFrame(items[0], 0, 0, firstWidth, height,
        TgPhotoAlbumPosition.Top | TgPhotoAlbumPosition.Left | TgPhotoAlbumPosition.Bottom)
      setFrame(items[1], firstWidth + safeSpacing, 0, secondWidth, height,
        TgPhotoAlbumPosition.Top | TgPhotoAlbumPosition.Right | TgPhotoAlbumPosition.Bottom)
    }
  } else if (!forceGeneric && itemCount === 3) {
    if (proportions.startsWith('n')) {
      const firstHeight = safeMaxHeight
      const thirdHeight = Math.min((safeMaxHeight - safeSpacing) * 0.5,
        Math.round(items[1].aspectRatio * (safeWidth - safeSpacing) /
          (items[2].aspectRatio + items[1].aspectRatio)))
      const secondHeight = safeMaxHeight - thirdHeight - safeSpacing
      let rightWidth = Math.max(IOS_MIN_ITEM_WIDTH, Math.min((safeWidth - safeSpacing) * 0.5,
        Math.round(Math.min(thirdHeight * items[2].aspectRatio, secondHeight * items[1].aspectRatio))))
      if (fillWidth) {
        rightWidth = Math.floor(safeWidth / 2)
      }
      let leftWidth = Math.round(Math.min(firstHeight * items[0].aspectRatio,
        safeWidth - safeSpacing - rightWidth))
      if (fillWidth) {
        leftWidth = safeWidth - safeSpacing - rightWidth
      }
      setFrame(items[0], 0, 0, leftWidth, firstHeight,
        TgPhotoAlbumPosition.Top | TgPhotoAlbumPosition.Left | TgPhotoAlbumPosition.Bottom)
      setFrame(items[1], leftWidth + safeSpacing, 0, rightWidth, secondHeight,
        TgPhotoAlbumPosition.Right | TgPhotoAlbumPosition.Top)
      setFrame(items[2], leftWidth + safeSpacing, secondHeight + safeSpacing, rightWidth, thirdHeight,
        TgPhotoAlbumPosition.Right | TgPhotoAlbumPosition.Bottom)
    } else {
      const firstHeight = Math.floor(Math.min(safeWidth / items[0].aspectRatio,
        (safeMaxHeight - safeSpacing) * 0.66))
      setFrame(items[0], 0, 0, safeWidth, firstHeight,
        TgPhotoAlbumPosition.Top | TgPhotoAlbumPosition.Left | TgPhotoAlbumPosition.Right)
      const width = (safeWidth - safeSpacing) / 2
      const secondHeight = Math.min(safeMaxHeight - firstHeight - safeSpacing,
        Math.round(Math.min(width / items[1].aspectRatio, width / items[2].aspectRatio)))
      setFrame(items[1], 0, firstHeight + safeSpacing, width, secondHeight,
        TgPhotoAlbumPosition.Left | TgPhotoAlbumPosition.Bottom)
      setFrame(items[2], width + safeSpacing, firstHeight + safeSpacing, width, secondHeight,
        TgPhotoAlbumPosition.Right | TgPhotoAlbumPosition.Bottom)
    }
  } else if (!forceGeneric && itemCount === 4) {
    if (proportions === 'wwww' || proportions.startsWith('w')) {
      const firstHeight = Math.round(Math.min(safeWidth / items[0].aspectRatio,
        (safeMaxHeight - safeSpacing) * 0.66))
      setFrame(items[0], 0, 0, safeWidth, firstHeight,
        TgPhotoAlbumPosition.Top | TgPhotoAlbumPosition.Left | TgPhotoAlbumPosition.Right)
      let rowHeight = Math.round((safeWidth - 2 * safeSpacing) /
        (items[1].aspectRatio + items[2].aspectRatio + items[3].aspectRatio))
      const firstWidth = Math.max(IOS_MIN_ITEM_WIDTH,
        Math.min((safeWidth - 2 * safeSpacing) * 0.4, rowHeight * items[1].aspectRatio))
      const thirdWidth = Math.max(Math.max(IOS_MIN_ITEM_WIDTH, (safeWidth - 2 * safeSpacing) * 0.33),
        rowHeight * items[3].aspectRatio)
      const secondWidth = safeWidth - firstWidth - thirdWidth - 2 * safeSpacing
      rowHeight = Math.max(IOS_MIN_ITEM_HEIGHT,
        Math.min(safeMaxHeight - firstHeight - safeSpacing, rowHeight))
      setFrame(items[1], 0, firstHeight + safeSpacing, firstWidth, rowHeight,
        TgPhotoAlbumPosition.Left | TgPhotoAlbumPosition.Bottom)
      setFrame(items[2], firstWidth + safeSpacing, firstHeight + safeSpacing, secondWidth, rowHeight,
        TgPhotoAlbumPosition.Bottom)
      setFrame(items[3], firstWidth + secondWidth + 2 * safeSpacing, firstHeight + safeSpacing,
        thirdWidth, rowHeight, TgPhotoAlbumPosition.Right | TgPhotoAlbumPosition.Bottom)
    } else {
      const firstWidth = Math.round(Math.min(safeMaxHeight * items[0].aspectRatio,
        (safeWidth - safeSpacing) * 0.6))
      setFrame(items[0], 0, 0, firstWidth, safeMaxHeight,
        TgPhotoAlbumPosition.Top | TgPhotoAlbumPosition.Left | TgPhotoAlbumPosition.Bottom)
      let columnWidth = Math.round((safeMaxHeight - 2 * safeSpacing) /
        (1 / items[1].aspectRatio + 1 / items[2].aspectRatio + 1 / items[3].aspectRatio))
      const firstHeight = Math.floor(columnWidth / items[1].aspectRatio)
      const secondHeight = Math.floor(columnWidth / items[2].aspectRatio)
      const thirdHeight = safeMaxHeight - firstHeight - secondHeight - 2 * safeSpacing
      columnWidth = Math.max(IOS_MIN_ITEM_WIDTH, Math.min(safeWidth - firstWidth - safeSpacing, columnWidth))
      setFrame(items[1], firstWidth + safeSpacing, 0, columnWidth, firstHeight,
        TgPhotoAlbumPosition.Right | TgPhotoAlbumPosition.Top)
      setFrame(items[2], firstWidth + safeSpacing, firstHeight + safeSpacing, columnWidth, secondHeight,
        TgPhotoAlbumPosition.Right)
      setFrame(items[3], firstWidth + safeSpacing, firstHeight + secondHeight + 2 * safeSpacing,
        columnWidth, thirdHeight, TgPhotoAlbumPosition.Right | TgPhotoAlbumPosition.Bottom)
    }
  } else {
    layoutGeneric(items, averageAspectRatio, safeWidth, safeSpacing)
  }

  let resultWidth = 0
  let resultHeight = 0
  const frames: TgPhotoAlbumFrame[] = []
  for (let index = 0; index < items.length; index++) {
    const frame = items[index].frame
    // The iOS ceil-to-screen-pixel pass can overshoot maxSize.width by a few
    // pixels and lets its bubble grow with that result. The Harmony shell owns
    // a strict measured lane width, so keep the same row geometry but absorb
    // the rounding remainder in the trailing cell instead of clipping it.
    frame.x = Math.min(frame.x, Math.max(0, safeWidth - 1))
    frame.width = Math.min(frame.width, Math.max(1, safeWidth - frame.x))
    resultWidth = Math.max(resultWidth, Math.round(frame.x + frame.width))
    resultHeight = Math.max(resultHeight, Math.round(frame.y + frame.height))
    frames.push(frame)
  }
  return {
    frames: frames,
    width: resultWidth,
    height: resultHeight,
  }
}

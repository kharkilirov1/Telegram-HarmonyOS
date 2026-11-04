// TgStorageUsageChart — segmented storage usage bar with a legend (H4c).
// iOS counterpart: StorageUsageScreen's category chart. The bar is scaled to the configured limit when
// one is set, otherwise to the total, so a full bar always means "at capacity".

import { StorageUsageSegment, storageSegmentPercent } from '../../../core/model/StorageUsageSegment';
import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgStorageUsageChart {
  @Param segments: StorageUsageSegment[] = [];
  @Param scaleBytes: number = 0;
  @Param caption: string = '';

  private segmentColor(index: number): Resource {
    if (index === 1) {
      return TgUiTokens.STORAGE_CHART_DATABASE;
    }
    if (index === 2) {
      return TgUiTokens.STORAGE_CHART_LANGUAGE_PACKS;
    }
    if (index === 3) {
      return TgUiTokens.STORAGE_CHART_LOGS;
    }
    return TgUiTokens.STORAGE_CHART_MEDIA;
  }

  build() {
    Column() {
      Row() {
        Text(this.caption)
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_META)
          .layoutWeight(1)
      }
      .width('100%')

      // Stacked segments: each one owns its share of the bar; the track behind shows free space.
      Row() {
        ForEach(this.segments, (segment: StorageUsageSegment) => {
          if (storageSegmentPercent(segment.bytes, this.scaleBytes) > 0) {
            Row()
              .width(storageSegmentPercent(segment.bytes, this.scaleBytes).toString() + '%')
              .height(8)
              .backgroundColor(this.segmentColor(segment.colorIndex))
          }
        }, (segment: StorageUsageSegment) => segment.label + segment.colorIndex.toString())
      }
      .width('100%')
      .height(8)
      .borderRadius(4)
      .clip(true)
      .backgroundColor(TgUiTokens.COLOR_SEPARATOR)
      .margin({ top: TgUiTokens.SPACE_8 })

      Column() {
        ForEach(this.segments, (segment: StorageUsageSegment) => {
          Row() {
            Row()
              .width(8)
              .height(8)
              .borderRadius(4)
              .backgroundColor(this.segmentColor(segment.colorIndex))
            Text(segment.label)
              .fontSize(TgUiTokens.FONT_META_SIZE)
              .fontColor(TgUiTokens.COLOR_TEXT_META)
              .margin({ left: TgUiTokens.SPACE_8 })
              .layoutWeight(1)
          }
          .width('100%')
          .margin({ top: TgUiTokens.SPACE_4 })
        }, (segment: StorageUsageSegment) => 'legend:' + segment.label)
      }
      .width('100%')
      .margin({ top: TgUiTokens.SPACE_8 })
    }
    .width('100%')
    .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_8,
      bottom: TgUiTokens.SPACE_8 })
  }
}

import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgGroupedPhotoBubble } from '../atoms/TgGroupedPhotoBubble';

const DEMO_WIDTHS: number[] = [1600, 700, 1200, 900, 1800, 800, 1400, 900, 1100, 720];
const DEMO_HEIGHTS: number[] = [900, 1400, 1200, 900, 1000, 1200, 900, 1500, 1100, 1280];

@Preview({ title: 'TgGroupedPhotoBubble' })
@ComponentV2
export struct TgGroupedPhotoBubbleDemo {
  private localFlags(count: number, remoteIndex: number): boolean[] {
    const result: boolean[] = [];
    for (let index = 0; index < count; index++) {
      result.push(index !== remoteIndex);
    }
    return result;
  }

  private downloadingFlags(count: number, downloadingIndex: number): boolean[] {
    const result: boolean[] = [];
    for (let index = 0; index < count; index++) {
      result.push(index === downloadingIndex);
    }
    return result;
  }

  private failedFlags(count: number, failedIndex: number): boolean[] {
    const result: boolean[] = [];
    for (let index = 0; index < count; index++) {
      result.push(index === failedIndex);
    }
    return result;
  }

  private progressValues(count: number, downloadingIndex: number): number[] {
    const result: number[] = [];
    for (let index = 0; index < count; index++) {
      result.push(index === downloadingIndex ? 0.58 : -1);
    }
    return result;
  }

  @Builder
  private caseBlock(label: string, isOutgoing: boolean, count: number,
    containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH,
    remoteIndex: number = -1, downloadingIndex: number = -1, failedIndex: number = -1) {
    Column({ space: TgUiTokens.SPACE_6 }) {
      Text(label)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .width('100%')

      TgGroupedPhotoBubble({
        photoPaths: new Array<string>(count).fill($r('app.media.app_icon') as string),
        photoMinithumbs: new Array<string>(count).fill(''),
        photoFileIds: new Array<number>(count).fill(1),
        photoHasLocal: this.localFlags(count, remoteIndex),
        photoDownloading: this.downloadingFlags(count, downloadingIndex),
        photoDownloadFailed: this.failedFlags(count, failedIndex),
        photoDownloadProgress: this.progressValues(count, downloadingIndex),
        photoWidths: DEMO_WIDTHS.slice(0, count),
        photoHeights: DEMO_HEIGHTS.slice(0, count),
        isOutgoing: isOutgoing,
        containerWidth: containerWidth
      })
    }
    .width('100%')
    .padding({
      left: TgUiTokens.SPACE_16,
      right: TgUiTokens.SPACE_16,
      top: TgUiTokens.SPACE_6,
      bottom: TgUiTokens.SPACE_6
    })
  }

  build() {
    Scroll() {
      Column() {
        Text('TgGroupedPhotoBubble Demo')
          .fontSize(TgUiTokens.FONT_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            top: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        this.caseBlock('01 incoming mixed pair', false, 2)
        this.caseBlock('02 outgoing portrait-leading trio', true, 3)
        this.caseBlock('03 incoming mixed four', false, 4)
        this.caseBlock('04 outgoing five-item mosaic', true, 5)
        this.caseBlock('05 incoming ten-item mosaic', false, 10)
        this.caseBlock('06 per-cell 58% download', true, 5, TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, 2, 2)
        this.caseBlock('07 failed remote cell / narrow lane', false, 5, 220, 3, -1, 3)
      }
      .width('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
  }
}

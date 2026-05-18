import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgVoiceBubble } from '../atoms/TgVoiceBubble';

@Preview({ title: 'TgVoiceBubble' })
@ComponentV2
export struct TgVoiceBubbleDemo {
  private sampleWaveformA: string = 'A1B2C3D4E5F6G7H8I9J0';
  private sampleWaveformB: string = 'ZXCVBNMASDFGHJKLQWERTY';

  @Builder
  private caseBlock(label: string, isOutgoing: boolean, durationSec: number, waveform: string,
    isPlaying: boolean, progress: number, isListened: boolean,
    containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, useConstrainedContainer: boolean = false,
    hasLocalFile: boolean = true, isDownloading: boolean = false, downloadProgress: number = -1) {
    Column({ space: TgUiTokens.SPACE_6 }) {
      Text(label)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .width('100%')

      if (useConstrainedContainer) {
        Row() {
          TgVoiceBubble({
            durationSec: durationSec,
            waveform: waveform,
            isOutgoing: isOutgoing,
            isPlaying: isPlaying,
            playbackProgress: progress,
            isListened: isListened,
            hasLocalFile: hasLocalFile,
            isDownloading: isDownloading,
            downloadProgress: downloadProgress,
            containerWidth: containerWidth
          })
          .width(containerWidth)
        }
        .width('100%')
      } else {
        TgVoiceBubble({
          durationSec: durationSec,
          waveform: waveform,
          isOutgoing: isOutgoing,
          isPlaying: isPlaying,
          playbackProgress: progress,
          isListened: isListened,
          hasLocalFile: hasLocalFile,
          isDownloading: isDownloading,
          downloadProgress: downloadProgress,
          containerWidth: containerWidth
        })
      }
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
        Text('TgVoiceBubble Demo')
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

        Text('Phase C.1 / Step 4: voice note bubble with play/pause, waveform, duration')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        this.caseBlock('01 incoming fresh (not listened)', false, 14, this.sampleWaveformA, false, 0, false)
        this.caseBlock('02 incoming playing 35%', false, 42, this.sampleWaveformA, true, 0.35, false)
        this.caseBlock('03 incoming listened complete', false, 58, this.sampleWaveformA, false, 1, true)
        this.caseBlock('04 outgoing paused', true, 19, this.sampleWaveformB, false, 0, true)
        this.caseBlock('05 outgoing playing 72%', true, 126, this.sampleWaveformB, true, 0.72, true)
        this.caseBlock('06 outgoing fallback waveform', true, 9, '', false, 0.2, true)
        this.caseBlock('07 narrow container stress', false, 84, this.sampleWaveformB, true, 0.55, false,
          TgUiTokens.MSG_DEMO_NARROW_CONTAINER_WIDTH, true)
        this.caseBlock('08 remote voice — download icon', false, 21, this.sampleWaveformA, false, 0, false,
          TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, false, false)
        this.caseBlock('09 determinate transfer from progress only', false, 33, this.sampleWaveformA, false, 0, false,
          TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, false, false, false, 0.46)
        this.caseBlock('10 indeterminate transfer — cancel affordance', true, 27, this.sampleWaveformB, false, 0, true,
          TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, false, false, true, -1)
      }
      .width('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
  }
}

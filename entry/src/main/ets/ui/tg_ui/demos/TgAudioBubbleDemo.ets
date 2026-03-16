import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgAudioBubble } from '../atoms/TgAudioBubble';

@ComponentV2
export struct TgAudioBubbleDemo {
  @Builder
  private caseBlock(label: string, title: string, performer: string, durationSec: number,
    isOutgoing: boolean = false, audioPath: string = '', isDownloading: boolean = false,
    downloadProgress: number = -1, isPlaying: boolean = false, playbackProgress: number = 0) {
    Column({ space: TgUiTokens.SPACE_6 }) {
      Text(label)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .width('100%')

      TgAudioBubble({
        title: title,
        performer: performer,
        durationSec: durationSec,
        fileSize: 5 * 1024 * 1024,
        mimeType: 'audio/mpeg',
        audioPath: audioPath,
        isDownloading: isDownloading,
        downloadProgress: downloadProgress,
        isOutgoing: isOutgoing,
        isPlaying: isPlaying,
        playbackProgress: playbackProgress,
        containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
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
        Text('TgAudioBubble Demo')
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

        this.caseBlock('01 incoming — idle (music note)', 'Nightcall', 'Kavinsky', 256)
        this.caseBlock('02 incoming — downloaded (play)', 'Nightcall', 'Kavinsky', 256, false, 'file://demo/audio.mp3')
        this.caseBlock('03 incoming — playing 35%', 'Nightcall', 'Kavinsky', 256, false, 'file://demo/audio.mp3', false, -1, true, 0.35)
        this.caseBlock('04 outgoing — downloaded', 'After Dark', 'Mr.Kitty', 284, true, 'file://demo/audio.mp3')
        this.caseBlock('05 outgoing — playing 72%', 'After Dark', 'Mr.Kitty', 284, true, 'file://demo/audio.mp3', false, -1, true, 0.72)
        this.caseBlock('06 downloading 41%', 'Roads', 'Portishead', 305, false, '', true, 0.41)
        this.caseBlock('07 downloading indeterminate', 'Unreleased Demo', '', 0, true, '', true, -1)
        this.caseBlock('08 long title ellipsis', 'Very Long Track Title That Should Definitely Ellipsize On Two Lines', 'Unknown Artist With A Very Long Name Too', 421)
      }
      .width('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
  }
}

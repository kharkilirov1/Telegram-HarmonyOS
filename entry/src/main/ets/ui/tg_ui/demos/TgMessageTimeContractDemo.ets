import { TgMessageRouter } from '../molecules/TgMessageRouter'
import { TgUiTokens } from '../tokens/TgUiTokens'
import { TgMessageSendStatus } from '../atoms/TgMessageMeta'
import { TgPollOptionVO } from '../atoms/TgPollBubble'

@Preview({ title: 'TgMessageTimeContract' })
@ComponentV2
export struct TgMessageTimeContractDemo {
  private buildPollOptions(): TgPollOptionVO[] {
    const first = new TgPollOptionVO()
    first.text = 'Option one'
    first.voterCount = 18
    first.votePercentage = 60
    first.isChosen = true

    const second = new TgPollOptionVO()
    second.text = 'Option two'
    second.voterCount = 12
    second.votePercentage = 40
    second.isChosen = false

    return [first, second]
  }

  @Builder
  private caseBlock(label: string, builder: () => void) {
    Column({ space: TgUiTokens.SPACE_6 }) {
      Text(label)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .width('100%')

      builder()
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
        Text('TgMessage Time Contract Demo')
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

        Text('Focused regression/demo surface for time/status placement across message families.')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        this.caseBlock('01 text bubble — inline meta', () => {
          TgMessageRouter({
            contentType: 'text',
            text: 'Engine text bubble with inline time.',
            timeText: '09:41',
            containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
          })
        })

        this.caseBlock('02 sticker — overlay meta on sticker surface', () => {
          TgMessageRouter({
            contentType: 'sticker',
            stickerPath: '',
            stickerWidth: 160,
            stickerHeight: 160,
            timeText: '09:44',
            isOutgoing: true,
            sendStatus: TgMessageSendStatus.Read,
            containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
          })
        })

        this.caseBlock('03 location without venue — overlay meta on map', () => {
          TgMessageRouter({
            contentType: 'location',
            locationLatitude: 43.2389,
            locationLongitude: 76.8897,
            timeText: '09:48',
            containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
          })
        })

        this.caseBlock('04 venue card — footer meta inside bubble', () => {
          TgMessageRouter({
            contentType: 'location',
            locationLatitude: 43.2389,
            locationLongitude: 76.8897,
            locationVenueTitle: 'Coffee Point',
            locationVenueAddress: 'Main Street 12',
            timeText: '09:52',
            isOutgoing: true,
            sendStatus: TgMessageSendStatus.Sent,
            containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
          })
        })

        this.caseBlock('05 contact — trailing footer meta', () => {
          TgMessageRouter({
            contentType: 'contact',
            contactFirstName: 'Alex',
            contactLastName: 'Johnson',
            contactPhoneNumber: '+1 202 555 0188',
            timeText: '10:01',
            containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
          })
        })

        this.caseBlock('06 poll — trailing footer meta', () => {
          TgMessageRouter({
            contentType: 'poll',
            pollQuestion: 'Which layout contract is closer to Telegram?',
            pollOptions: this.buildPollOptions(),
            pollTotalVoterCount: 30,
            pollIsClosed: false,
            pollIsAnonymous: true,
            timeText: '10:07',
            isOutgoing: true,
            sendStatus: TgMessageSendStatus.Read,
            containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
          })
        })

        this.caseBlock('07 document — trailing footer meta', () => {
          TgMessageRouter({
            contentType: 'document',
            fileName: 'Telegram-Layout-Spec.pdf',
            fileSize: 3_450_000,
            mimeType: 'application/pdf',
            timeText: '10:11',
            containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
          })
        })

        this.caseBlock('08 voice — explicit width meta contract', () => {
          TgMessageRouter({
            contentType: 'voice',
            voiceDuration: 18,
            voiceWaveform: '6,9,11,14,10,7,13,16,12,8',
            timeText: '10:15',
            isOutgoing: true,
            sendStatus: TgMessageSendStatus.Read,
            containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
          })
        })

        this.caseBlock('09 audio — explicit width meta contract', () => {
          TgMessageRouter({
            contentType: 'audio',
            audioTitle: 'Motion of Light',
            audioPerformer: 'Telegram Ensemble',
            audioDuration: 247,
            fileSize: 8_300_000,
            mimeType: 'audio/mpeg',
            timeText: '10:18',
            containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
          })
        })

        this.caseBlock('10 videoNote — overlay meta on round surface', () => {
          TgMessageRouter({
            contentType: 'videoNote',
            videoDuration: 22,
            videoThumbPath: '',
            timeText: '10:22',
            isOutgoing: true,
            sendStatus: TgMessageSendStatus.Sent,
            containerWidth: TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH
          })
        })
      }
      .width('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
  }
}

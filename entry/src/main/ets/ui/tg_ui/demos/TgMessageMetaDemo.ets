import { TgMessageMeta, TgMessageSendStatus } from '../atoms/TgMessageMeta';
import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgMessageMetaDemo {
  @Builder
  private caseBlock(label: string, timeText: string, sendStatus: TgMessageSendStatus, isOutgoing: boolean = true,
    reserveTimeSlot: boolean = true, reserveStatusSlot: boolean = true) {
    Column({ space: TgUiTokens.SPACE_6 }) {
      Text(label)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .width('100%')

      Row() {
        TgMessageMeta({
          timeText: timeText,
          sendStatus: sendStatus,
          isOutgoing: isOutgoing,
          reserveTimeSlot: reserveTimeSlot,
          reserveStatusSlot: reserveStatusSlot
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .padding({
        left: TgUiTokens.SPACE_12,
        right: TgUiTokens.SPACE_12,
        top: TgUiTokens.SPACE_8,
        bottom: TgUiTokens.SPACE_8
      })
      .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
      .borderRadius(TgUiTokens.RADIUS_8)
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
        Text('TgMessageMeta Demo')
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

        Text('Phase C / Step 2: time + status checks cluster (anti-jump with minWidth + placeholders)')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        this.caseBlock('01 outgoing time only', '12:34', TgMessageSendStatus.None, true)
        this.caseBlock('02 outgoing sending', '12:34', TgMessageSendStatus.Sending, true)
        this.caseBlock('03 outgoing sent (single check)', '12:34', TgMessageSendStatus.Sent, true)
        this.caseBlock('04 outgoing read (double check)', '12:34', TgMessageSendStatus.Read, true)
        this.caseBlock('05 outgoing failed', '12:34', TgMessageSendStatus.Failed, true)
        this.caseBlock('06 incoming time only', '12:34', TgMessageSendStatus.None, false, true, false)
        this.caseBlock('07 outgoing no-time + sending', '', TgMessageSendStatus.Sending, true)
        this.caseBlock('08 outgoing no-time + none (placeholder)', '', TgMessageSendStatus.None, true)
        this.caseBlock('09 outgoing long time text', 'Yesterday', TgMessageSendStatus.Read, true)
        this.caseBlock('10 no reserve slots (expected jump baseline)', '12:34', TgMessageSendStatus.None, true, false, false)

        Text('Jump probe: identical container, status toggles only')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            top: TgUiTokens.SPACE_8,
            bottom: TgUiTokens.SPACE_6
          })

        this.caseBlock('11 probe A', '18:20', TgMessageSendStatus.None, true)
        this.caseBlock('12 probe B', '18:20', TgMessageSendStatus.Sending, true)
        this.caseBlock('13 probe C', '18:20', TgMessageSendStatus.Sent, true)
        this.caseBlock('14 probe D', '18:20', TgMessageSendStatus.Read, true)
        this.caseBlock('15 probe E', '18:20', TgMessageSendStatus.Failed, true)
      }
      .width('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
  }
}

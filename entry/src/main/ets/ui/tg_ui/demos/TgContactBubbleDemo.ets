import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgContactBubble } from '../atoms/TgContactBubble';

@Preview({ title: 'TgContactBubble' })
@ComponentV2
export struct TgContactBubbleDemo {
  private longFirstName: string = 'Alexandria-Cassandra';
  private longLastName: string = 'Von Telegramovich Superlong-Surname';

  @Builder
  private caseBlock(label: string, description: string, firstName: string, lastName: string, phoneNumber: string,
    contactUserId: number, isOutgoing: boolean,
    bubbleWidth: number = TgUiTokens.MSG_DEMO_WIDE_CONTAINER_WIDTH) {
    Column({ space: TgUiTokens.SPACE_6 }) {
      Text(label)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .width('100%')

      Text(description)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        .width('100%')

      Row() {
        Column() {
          TgContactBubble({
            firstName: firstName,
            lastName: lastName,
            phoneNumber: phoneNumber,
            contactUserId: contactUserId,
            isOutgoing: isOutgoing
          })
        }
        .width(bubbleWidth)
        .backgroundColor(isOutgoing ? TgUiTokens.COLOR_MSG_BUBBLE_OUTGOING_BG : TgUiTokens.COLOR_MSG_BUBBLE_INCOMING_BG)
        .borderRadius(TgUiTokens.MSG_BUBBLE_RADIUS)
      }
      .width('100%')
      .justifyContent(isOutgoing ? FlexAlign.End : FlexAlign.Start)
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
        Text('TgContactBubble Demo')
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

        Text('Static state coverage for contact message body. Parent shell simulates router-owned bubble background; action labels are visual-only.')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        this.caseBlock('01 incoming full name + phone', 'Base contact card with two-line identity and visual Message/Add Contact row.',
          'Alice', 'Johnson', '+1 555 0100', 0, false)
        this.caseBlock('02 outgoing registered contact', 'Outgoing parent shell plus contactUserId > 0; atom currently has no visual branch.',
          'Mikhail', 'Ivanov', '+7 707 555 0101', 42001, true)
        this.caseBlock('03 first name only', 'Display name comes from firstName; avatar initials use the available first letter.',
          'Nina', '', '+44 20 7946 0018', 0, false)
        this.caseBlock('04 last name only', 'Display name comes from lastName when firstName is empty.',
          '', 'Kowalski', '+48 22 555 0132', 0, false)
        this.caseBlock('05 phone-only fallback', 'No names: title falls back to phoneNumber and avatar initials are empty.',
          '', '', '+49 30 555 0144', 0, false)
        this.caseBlock('06 long name narrow width', 'One-line title ellipsis stress inside the parent-owned bubble shell.',
          this.longFirstName, this.longLastName, '+1 212 555 0199', 0, false,
          TgUiTokens.MSG_DEMO_NARROW_CONTAINER_WIDTH)
        this.caseBlock('07 hidden phone line', 'Empty phoneNumber hides the secondary line but keeps the action row.',
          'Ava', 'NoPhone', '', 0, false)
        this.caseBlock('08 outgoing phone-only registered user', 'Direction + contactUserId state with phone fallback; behavior remains visual-only in this demo.',
          '', '', '+81 3 5550 0188', 88008, true,
          TgUiTokens.MSG_DEMO_NARROW_CONTAINER_WIDTH)
      }
      .width('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
  }
}

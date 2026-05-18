import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgLocationBubble } from '../atoms/TgLocationBubble';

@Preview({ title: 'TgLocationBubble' })
@ComponentV2
export struct TgLocationBubbleDemo {
  private longVenueTitle: string = 'Very Long Venue Name For Telegram Map Bubble Width And Two-Line Ellipsis Stress';
  private longVenueAddress: string = '12345 Extremely Long Address Line, Building With A Long Name, District, City, Country, Postal Code 000000';

  @Builder
  private caseBlock(label: string, description: string, latitude: number, longitude: number, venueTitle: string,
    venueAddress: string, isOutgoing: boolean,
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
          TgLocationBubble({
            latitude: latitude,
            longitude: longitude,
            venueTitle: venueTitle,
            venueAddress: venueAddress,
            isOutgoing: isOutgoing
          })
            .width('100%')
        }
        .width(bubbleWidth)
        .backgroundColor(isOutgoing ? TgUiTokens.COLOR_MSG_BUBBLE_OUTGOING_BG : TgUiTokens.COLOR_MSG_BUBBLE_INCOMING_BG)
        .borderRadius(TgUiTokens.MSG_BUBBLE_RADIUS)
        .padding({
          left: TgUiTokens.BUBBLE_PADDING_H,
          right: TgUiTokens.BUBBLE_PADDING_H,
          top: TgUiTokens.BUBBLE_PADDING_V,
          bottom: TgUiTokens.BUBBLE_PADDING_V
        })
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
        Text('TgLocationBubble Demo')
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

        Text('Static state coverage for location and venue message bodies. Parent shell simulates router-owned background/meta boundaries; map opening is not implemented here.')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        this.caseBlock('01 incoming plain location', 'Map-only state; router owns overlay meta pill in live integration.',
          37.7749, -122.4194, '', '', false)
        this.caseBlock('02 outgoing plain location', 'Outgoing parent shell; atom internals currently do not branch on isOutgoing.',
          51.5074, -0.1278, '', '', true)
        this.caseBlock('03 venue title and address', 'Venue body appears below the map with title + secondary address.',
          48.8584, 2.2945, 'Eiffel Tower', 'Champ de Mars, 5 Av. Anatole France, Paris', false)
        this.caseBlock('04 venue title only', 'Address is empty and should be hidden while the title remains below the map.',
          40.7580, -73.9855, 'Times Square', '', false)
        this.caseBlock('05 long venue title', 'Two-line title ellipsis/wrapping stress with a short address.',
          35.6895, 139.6917, this.longVenueTitle, 'Tokyo', false)
        this.caseBlock('06 long venue address', 'Secondary address line should clamp to two lines with ellipsis.',
          25.2048, 55.2708, 'Museum of the Future', this.longVenueAddress, false)
        this.caseBlock('07 zero coordinates fallback', 'Deterministic placeholder state for unknown coordinates.',
          0, 0, '', '', false)
        this.caseBlock('08 narrow outgoing venue', 'Narrow parent width stress for map aspect ratio, title, and address.',
          41.0082, 28.9784, 'Hagia Sophia Grand Mosque', 'Sultan Ahmet, Istanbul', true,
          TgUiTokens.MSG_DEMO_NARROW_CONTAINER_WIDTH)
      }
      .width('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
  }
}

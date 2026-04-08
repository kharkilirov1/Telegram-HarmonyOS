// TgLocationBubble — location/venue message bubble (iOS ref: ChatMessageMapBubbleContentNode)
// Layout: Map placeholder (2:1 aspect) + optional venue title/address

import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgLocationBubble {
  @Param latitude: number = 0;
  @Param longitude: number = 0;
  @Param venueTitle: string = '';
  @Param venueAddress: string = '';
  @Param isOutgoing: boolean = false;

  private hasVenue(): boolean {
    return this.venueTitle.length > 0;
  }

  private coordsText(): string {
    const lat = this.latitude.toFixed(4);
    const lon = this.longitude.toFixed(4);
    return `${lat}, ${lon}`;
  }

  build() {
    Column() {
      // Map placeholder (iOS: static MapSnapshot, aspect 2:1)
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#E8E8ED')

        Column() {
          // Pin icon placeholder
          Text('\uD83D\uDCCD')
            .fontSize(32)

          Text(this.coordsText())
            .fontSize(11)
            .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .aspectRatio(2)
      .borderRadius({ topLeft: TgUiTokens.MSG_BUBBLE_RADIUS, topRight: TgUiTokens.MSG_BUBBLE_RADIUS })
      .clip(true)

      // Venue info (if available)
      if (this.hasVenue()) {
        Column() {
          Text(this.venueTitle)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (this.venueAddress.length > 0) {
            Text(this.venueAddress)
              .fontSize(14)
              .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 2 })
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ top: 6, bottom: 6, left: TgUiTokens.BUBBLE_PADDING_H, right: TgUiTokens.BUBBLE_PADDING_H })
      }
    }
    .constraintSize({ minWidth: 200 })
  }
}

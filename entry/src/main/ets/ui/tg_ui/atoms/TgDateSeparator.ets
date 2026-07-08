import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgDateSeparator {
  @Param text: string = '';
  @Param containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
  @Param maxWidthRatio: number = TgUiTokens.DATE_SEPARATOR_MAX_WIDTH_RATIO;
  // Service (chat-event) lines reuse this capsule with multi-line text
  @Param maxLines: number = 1;

  private safeText(): string {
    return this.text.length > 0 ? this.text : ' ';
  }

  private maxCapsuleWidth(): number {
    return Math.max(1, Math.floor(this.containerWidth * this.maxWidthRatio));
  }

  build() {
    Row() {
      Row() {
        Text(this.safeText())
          .fontSize(TgUiTokens.DATE_SEPARATOR_FONT_SIZE)
          .fontWeight(TgUiTokens.DATE_SEPARATOR_FONT_WEIGHT)
          .lineHeight(TgUiTokens.DATE_SEPARATOR_LINE_HEIGHT)
          .fontColor(TgUiTokens.DATE_SEPARATOR_TEXT)
          .maxLines(this.maxLines)
          .textAlign(TextAlign.Center)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .padding({
        left: TgUiTokens.DATE_SEPARATOR_PADDING_H,
        right: TgUiTokens.DATE_SEPARATOR_PADDING_H,
        top: TgUiTokens.DATE_SEPARATOR_PADDING_V,
        bottom: TgUiTokens.DATE_SEPARATOR_PADDING_V
      })
      .constraintSize({
        minHeight: TgUiTokens.DATE_SEPARATOR_MIN_HEIGHT,
        maxWidth: this.maxCapsuleWidth()
      })
      .backgroundColor(TgUiTokens.DATE_SEPARATOR_BG)
      .borderRadius(TgUiTokens.DATE_SEPARATOR_RADIUS)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({
      left: TgUiTokens.DATE_SEPARATOR_SIDE_INSET,
      right: TgUiTokens.DATE_SEPARATOR_SIDE_INSET
    })
  }
}

@ComponentV2
export struct TgUnreadMarker {
  @Param text: string = 'Unread messages';
  @Param containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
  @Param maxWidthRatio: number = TgUiTokens.UNREAD_MARKER_MAX_WIDTH_RATIO;

  private safeText(): string {
    return this.text.length > 0 ? this.text : ' ';
  }

  private maxMarkerWidth(): number {
    return Math.max(1, Math.floor(this.containerWidth * this.maxWidthRatio));
  }

  build() {
    Row() {
      Row() {
        Text(this.safeText())
          .fontSize(TgUiTokens.UNREAD_MARKER_FONT_SIZE)
          .fontWeight(TgUiTokens.UNREAD_MARKER_FONT_WEIGHT)
          .lineHeight(TgUiTokens.UNREAD_MARKER_LINE_HEIGHT)
          .fontColor(TgUiTokens.UNREAD_MARKER_TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height(TgUiTokens.UNREAD_MARKER_HEIGHT)
      .padding({
        left: TgUiTokens.SPACE_12,
        right: TgUiTokens.SPACE_12
      })
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(TgUiTokens.UNREAD_MARKER_BG)
      .borderRadius(TgUiTokens.UNREAD_MARKER_RADIUS)
      .constraintSize({ maxWidth: this.maxMarkerWidth() })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({
      left: TgUiTokens.UNREAD_MARKER_SIDE_INSET,
      right: TgUiTokens.UNREAD_MARKER_SIDE_INSET
    })
  }
}

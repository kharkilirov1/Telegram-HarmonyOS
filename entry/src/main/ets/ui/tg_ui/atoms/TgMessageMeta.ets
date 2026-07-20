import { TgIcon } from './TgIcon';
import { TgUiTokens } from '../tokens/TgUiTokens';
import { composeMessageMetaText } from '../utils/TgMessageMetaText';

export enum TgMessageSendStatus {
  None = 0,
  Sending = 1,
  Sent = 2,
  Read = 3,
  Failed = 4
}

@ComponentV2
export struct TgMessageMeta {
  @Param timeText: string = '';
  @Param editedText: string = '';
  @Param sendStatus: TgMessageSendStatus = TgMessageSendStatus.None;
  @Param isOutgoing: boolean = true;

  @Param minWidth: number = TgUiTokens.MSG_META_MIN_WIDTH;
  @Param rowHeight: number = TgUiTokens.MSG_META_ROW_HEIGHT;
  @Param reserveTimeSlot: boolean = true;
  @Param reserveStatusSlot: boolean = true;
  @Param overlayMode: boolean = false; // white text on dark overlay (for media)

  private hasTimeText(): boolean {
    return this.metaText().length > 0;
  }

  private metaText(): string {
    return composeMessageMetaText(this.editedText, this.timeText);
  }

  private hasStatusIcon(): boolean {
    return this.isOutgoing && this.sendStatus !== TgMessageSendStatus.None;
  }

  private statusIconResource(): Resource {
    switch (this.sendStatus) {
      case TgMessageSendStatus.Sending:
        return TgUiTokens.ICON_RES_CLOCK;
      case TgMessageSendStatus.Sent:
        return TgUiTokens.ICON_RES_CHECK_SINGLE;
      case TgMessageSendStatus.Read:
        return TgUiTokens.ICON_RES_CHECK_DOUBLE;
      case TgMessageSendStatus.Failed:
        return TgUiTokens.ICON_RES_FAILED;
      default:
        return TgUiTokens.ICON_RES_CLOCK;
    }
  }

  private statusIconColor(): ResourceColor {
    if (this.overlayMode) {
      return this.sendStatus === TgMessageSendStatus.Failed ? TgUiTokens.MSG_META_STATUS_FAILED : Color.White;
    }
    switch (this.sendStatus) {
      case TgMessageSendStatus.Sending:
        return TgUiTokens.MSG_META_STATUS_PENDING;
      case TgMessageSendStatus.Sent:
        return TgUiTokens.MSG_META_STATUS_SENT;
      case TgMessageSendStatus.Read:
        return TgUiTokens.MSG_META_STATUS_READ;
      case TgMessageSendStatus.Failed:
        return TgUiTokens.MSG_META_STATUS_FAILED;
      default:
        return TgUiTokens.MSG_META_STATUS_PENDING;
    }
  }

  private timeColor(): ResourceColor {
    if (this.overlayMode) return Color.White;
    return this.isOutgoing ? TgUiTokens.MSG_META_TEXT_OUTGOING : TgUiTokens.MSG_META_TEXT_INCOMING;
  }

  @Builder
  private buildTimeSlot() {
    if (this.hasTimeText()) {
      Text(this.metaText())
        .fontSize(TgUiTokens.MSG_META_SIZE)
        .fontColor(this.timeColor())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Clip })
    } else if (this.reserveTimeSlot) {
      Row()
        .width(TgUiTokens.MSG_META_TIME_PLACEHOLDER_WIDTH)
        .height(this.rowHeight)
        .opacity(0)
    }
  }

  @Builder
  private buildStatusSlot() {
    if (this.hasStatusIcon()) {
      TgIcon({
        src: this.statusIconResource(),
        iconSize: TgUiTokens.MSG_META_ICON_SIZE,
        tintColor: this.statusIconColor()
      })
        .margin({
          left: this.hasTimeText() || this.reserveTimeSlot ? TgUiTokens.MSG_META_ICON_GAP : 0
        })
    } else if (this.reserveStatusSlot) {
      Row()
        .width(TgUiTokens.MSG_META_STATUS_PLACEHOLDER_WIDTH)
        .height(this.rowHeight)
        .margin({
          left: this.hasTimeText() || this.reserveTimeSlot ? TgUiTokens.MSG_META_ICON_GAP : 0
        })
        .opacity(0)
    }
  }

  build() {
    Row() {
      this.buildTimeSlot()
      this.buildStatusSlot()
    }
    .height(this.rowHeight)
    .constraintSize({ minWidth: this.minWidth })
    .justifyContent(FlexAlign.End)
    .alignItems(VerticalAlign.Center)
  }
}

import { Message, MessageContentType } from '../../models/Message';
import { AudioBubble } from './AudioBubble';
import { CallBubble } from './CallBubble';
import { ContactBubble } from './ContactBubble';
import { DiceBubble } from './DiceBubble';
import { FileBubble } from './FileBubble';
import { LocationBubble } from './LocationBubble';
import { MediaBubble } from './MediaBubble';
import { PollBubble } from './PollBubble';
import { ReactionBar } from './ReactionBar';
import { ReplyPreview } from './ReplyPreview';
import { ServiceBubble } from './ServiceBubble';
import { TextBubble } from './TextBubble';
import { getSenderColor } from './MessageUtils';

@ComponentV2
export struct MessageBubble {
  @Param message: Message = new Message();
  @Param isFirstInGroup: boolean = true;
  @Param isLastInGroup: boolean = true;
  @Param showSenderName: boolean = false;
  @Event onReply: (message: Message) => void = () => {};
  @Event onForward: (message: Message) => void = () => {};
  @Event onCopy: (message: Message) => void = () => {};
  @Event onDelete: (message: Message) => void = () => {};
  @Event onEdit: (message: Message) => void = () => {};
  @Event onMediaTap: (url: string, messageId: number, chatId: number) => void = () => {};
  @Event onVideoPlay: (url: string, duration: number) => void = () => {};
  @Event onReactionTap: (message: Message, emoji: string) => void = () => {};
  @Event onPollVote: (message: Message, optionIndex: number) => void = () => {};
  @Param isSelectionMode: boolean = false;
  @Param isSelected: boolean = false;
  @Event onSelect: (message: Message) => void = () => {};

  @Local swipeOffsetX: number = 0;

  build() {
    Column() {
      Row() {
        if (this.isSelectionMode) {
          Checkbox()
            .select(this.isSelected)
            .selectedColor($r('app.color.telegram_blue'))
            .width(22).height(22)
            .margin({ right: 8 })
            .onChange((_value: boolean) => { this.onSelect(this.message); })
        }

        if (!this.message.isOutgoing) {
          if (this.isLastInGroup && this.showSenderName) {
            Text(this.getInitial())
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .width(34)
              .height(34)
              .borderRadius(17)
              .backgroundColor(getSenderColor(this.message.senderId))
              .textAlign(TextAlign.Center)
              .margin({ right: 6 })
              .alignSelf(ItemAlign.End)
          } else {
            Blank().width(40)
          }
        }

        Column() {
          ReplyPreview({ message: this.message })

          ServiceBubble({
            message: this.message,
            showSenderName: this.showSenderName,
            isFirstInGroup: this.isFirstInGroup
          })

          if (this.message.contentType === MessageContentType.POLL) {
            PollBubble({
              message: this.message,
              onVote: (msg: Message, optionIndex: number) => { this.onPollVote(msg, optionIndex); }
            })
          } else if (this.message.contentType === MessageContentType.DOCUMENT) {
            FileBubble({ message: this.message })
          } else if (this.message.contentType === MessageContentType.CONTACT) {
            ContactBubble({ message: this.message })
          } else if (this.message.contentType === MessageContentType.LOCATION
            || this.message.contentType === MessageContentType.LIVE_LOCATION
            || this.message.contentType === MessageContentType.VENUE) {
            LocationBubble({ message: this.message })
          } else if (this.message.contentType === MessageContentType.AUDIO) {
            AudioBubble({ message: this.message })
          } else if (this.message.contentType === MessageContentType.CALL) {
            CallBubble({ message: this.message })
          } else if (this.message.contentType === MessageContentType.DICE) {
            DiceBubble({ message: this.message })
          } else if (this.isMediaContent()) {
            MediaBubble({
              message: this.message,
              onMediaTap: (url: string, messageId: number, chatId: number) => {
                this.onMediaTap(url, messageId, chatId);
              },
              onVideoPlay: (url: string, duration: number) => { this.onVideoPlay(url, duration); }
            })
          } else {
            TextBubble({ message: this.message })
          }
        }
        .padding(this.message.contentType === MessageContentType.STICKER ? 0 :
          this.message.contentType === MessageContentType.PHOTO ? 2 :
            this.message.contentType === MessageContentType.VIDEO_NOTE ? 0 :
              this.message.contentType === MessageContentType.LOCATION ? 0 :
                this.message.contentType === MessageContentType.LIVE_LOCATION
                  ? { left: 0, right: 0, top: 0, bottom: 4 } :
                  this.message.contentType === MessageContentType.VENUE
                    ? { left: 0, right: 0, top: 0, bottom: 4 } :
                    this.message.contentType === MessageContentType.DICE
                      ? { left: 6, right: 6, top: 4, bottom: 4 } :
                      { left: 10, right: 10, top: 6, bottom: 6 })
        .borderRadius(this.getBubbleRadii())
        .backgroundColor(this.getBubbleColor())
        .constraintSize({ maxWidth: '75%' })
        .gesture(
          GestureGroup(GestureMode.Exclusive,
            LongPressGesture()
              .onAction(() => {
                if (this.isSelectionMode) {
                  this.onSelect(this.message);
                } else {
                  this.showMessageActions();
                }
              }),
            PanGesture({ direction: PanDirection.Left, distance: 20 })
              .onActionUpdate((event: GestureEvent) => {
                const offsetX = event.offsetX;
                if (offsetX < 0) {
                  this.swipeOffsetX = Math.max(offsetX, -80);
                }
              })
              .onActionEnd(() => {
                if (this.swipeOffsetX < -50) {
                  this.onReply(this.message);
                }
                this.swipeOffsetX = 0;
              })
          )
        )
        .translate({ x: this.swipeOffsetX })
      }
      .width('100%')
      .justifyContent(this.message.isOutgoing ? FlexAlign.End : FlexAlign.Start)
      .padding({ left: 8, right: 8 })

      if (this.swipeOffsetX < -20) {
        Row() {
          Blank()
          Image($r('app.media.ic_reply'))
            .width(20).height(20)
            .fillColor($r('app.color.telegram_blue'))
            .opacity(Math.min(1, Math.abs(this.swipeOffsetX) / 50))
        }
        .width('100%')
        .padding({ right: 16 })
        .position({ y: 0 })
      }

      if (this.message.reactions.length > 0) {
        ReactionBar({
          reactions: this.message.reactions,
          isOutgoing: this.message.isOutgoing,
          onReactionTap: (emoji: string) => {
            this.onReactionTap(this.message, emoji);
          },
          onAddReaction: () => {
            this.onReactionTap(this.message, '');
          }
        })
      }
    }
    .width('100%')
    .margin({
      top: this.isFirstInGroup ? 6 : 1,
      bottom: this.isLastInGroup ? 6 : 1
    })
  }

  private showMessageActions(): void {
    const buttons: Array<AlertDialogButtonOptions> = [
      {
        value: $r('app.string.reply'),
        action: () => { this.onReply(this.message); }
      },
      {
        value: $r('app.string.forward'),
        action: () => { this.onForward(this.message); }
      },
      {
        value: $r('app.string.copy'),
        action: () => { this.onCopy(this.message); }
      }
    ];

    if (this.message.isOutgoing && this.message.contentType === MessageContentType.TEXT) {
      buttons.push({
        value: $r('app.string.edit'),
        action: () => { this.onEdit(this.message); }
      });
    }

    buttons.push({
      value: $r('app.string.delete'),
      fontColor: $r('app.color.error_red'),
      action: () => { this.onDelete(this.message); }
    });

    AlertDialog.show({
      title: undefined,
      message: undefined,
      buttons: buttons
    });
  }

  private getBubbleRadii(): BorderRadiuses {
    const r = 17;
    const tailR = 4;
    if (this.message.contentType === MessageContentType.STICKER) {
      return { topLeft: 0, topRight: 0, bottomLeft: 0, bottomRight: 0 };
    }
    if (!this.isLastInGroup) {
      return { topLeft: r, topRight: r, bottomLeft: r, bottomRight: r };
    }
    if (this.message.isOutgoing) {
      return { topLeft: r, topRight: r, bottomLeft: r, bottomRight: tailR };
    }
    return { topLeft: r, topRight: r, bottomLeft: tailR, bottomRight: r };
  }

  private getBubbleColor(): ResourceColor {
    if (this.message.contentType === MessageContentType.STICKER) {
      return Color.Transparent;
    }
    return this.message.isOutgoing
      ? $r('app.color.chat_bubble_outgoing')
      : $r('app.color.chat_bubble_incoming');
  }

  private isMediaContent(): boolean {
    if (this.message.isViewOnce) return true;
    return this.message.contentType === MessageContentType.STICKER
      || this.message.contentType === MessageContentType.PHOTO
      || this.message.contentType === MessageContentType.VOICE
      || this.message.contentType === MessageContentType.ANIMATION
      || this.message.contentType === MessageContentType.VIDEO
      || this.message.contentType === MessageContentType.VIDEO_NOTE;
  }

  private getInitial(): string {
    return this.message.senderName.length > 0
      ? this.message.senderName.charAt(0)
      : '?';
  }
}

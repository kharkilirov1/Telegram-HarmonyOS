// Message reaction bar — quick emoji reactions below a message bubble
// Reference: Telegram iOS MessageReactionListView, Android ReactionsContainerLayout

import { MessageReaction } from '../../models/Message';

@ComponentV2
export struct ReactionBar {
  @Param reactions: MessageReaction[] = [];
  @Param onReactionTap: (emoji: string) => void = () => {};
  @Param onAddReaction: () => void = () => {};
  @Param isOutgoing: boolean = false;

  build() {
    Row({ space: 4 }) {
      ForEach(this.reactions, (reaction: MessageReaction) => {
        this.reactionChip(reaction)
      }, (reaction: MessageReaction) => reaction.emoji)

      // Add reaction button
      Column() {
        Image($r('app.media.ic_emoji'))
          .width(14).height(14)
          .fillColor($r('app.color.text_secondary'))
          .accessibilityText($r('app.string.accessibility_add_reaction'))
      }
      .width(28).height(24)
      .borderRadius(12)
      .backgroundColor($r('app.color.glass_card_bg'))
      .justifyContent(FlexAlign.Center)
      .onClick(() => { this.onAddReaction(); })
    }
    .justifyContent(this.isOutgoing ? FlexAlign.End : FlexAlign.Start)
    .width('100%')
    .padding({ left: this.isOutgoing ? 40 : 48, right: this.isOutgoing ? 8 : 40 })
    .margin({ top: 2, bottom: 2 })
  }

  @Builder
  reactionChip(reaction: MessageReaction) {
    Row({ space: 3 }) {
      Text(reaction.emoji)
        .fontSize(14)

      if (reaction.count > 1) {
        Text(reaction.count.toString())
          .fontSize(12)
          .fontColor(reaction.isMine
            ? $r('app.color.telegram_blue')
            : $r('app.color.text_primary'))
      }
    }
    .padding({ left: 6, right: 6, top: 3, bottom: 3 })
    .borderRadius(12)
    .backgroundColor(reaction.isMine
      ? '#1A3390EC'
      : $r('app.color.glass_card_bg'))
    .borderWidth(reaction.isMine ? 1 : 0)
    .borderColor(reaction.isMine ? $r('app.color.telegram_blue') : Color.Transparent)
    .onClick(() => {
      this.onReactionTap(reaction.emoji);
    })
  }
}

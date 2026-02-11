// Poll bubble component — displays a Telegram poll with voting and results
// Reference: Telegram iOS PollBubbleNode, Android PollCell

import { Message, PollOption } from '../../models/Message';

@ComponentV2
export struct PollBubble {
  @Param message: Message = new Message();
  @Event onVote: (message: Message, optionIndex: number) => void = () => {};

  @Local selectedIndex: number = -1;

  private get hasVoted(): boolean {
    return this.message.pollOptions.some((option: PollOption) => option.isChosen);
  }

  private get showResults(): boolean {
    return this.hasVoted || this.message.pollIsClosed;
  }

  private get pollTypeLabel(): ResourceStr {
    if (this.message.pollType === 'quiz') {
      return $r('app.string.quiz_type_label');
    }
    return this.message.pollIsAnonymous ? $r('app.string.anonymous_poll') : $r('app.string.poll');
  }

  private get statusLabel(): ResourceStr {
    if (this.message.pollIsClosed) {
      return $r('app.string.final_results');
    }
    const count = this.message.pollTotalVoterCount;
    if (count === 0) {
      return $r('app.string.no_votes_yet');
    }
    if (count === 1) {
      return $r('app.string.one_vote');
    }
    return `${count} votes`;
  }

  build() {
    Column() {
      // Poll type indicator
      Text(this.pollTypeLabel)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ bottom: 4 })
        .alignSelf(ItemAlign.Start)

      // Poll question
      Text(this.message.pollQuestion)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .lineHeight(22)
        .width('100%')
        .margin({ bottom: 12 })
        .textAlign(TextAlign.Start)

      // Poll options
      ForEach(this.message.pollOptions, (option: PollOption, index: number) => {
        if (this.showResults) {
          this.buildResultOption(option, index)
        } else {
          this.buildVotableOption(option, index)
        }
      }, (option: PollOption, index: number) => `${index}_${option.text}`)

      // Separator
      Divider()
        .strokeWidth(0.5)
        .color($r('app.color.separator'))
        .width('100%')
        .margin({ top: 8, bottom: 8 })

      // Status row: vote count + closed indicator
      Row() {
        Text(this.statusLabel)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))

        Blank().layoutWeight(1)

        if (this.message.pollIsClosed) {
          Text($r('app.string.closed_label'))
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .fontWeight(FontWeight.Medium)
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildVotableOption(option: PollOption, index: number) {
    Row() {
      // Radio-style circle indicator
      Column() {
        if (this.selectedIndex === index) {
          Circle()
            .width(8)
            .height(8)
            .fill($r('app.color.telegram_blue'))
        }
      }
      .width(20)
      .height(20)
      .borderRadius(10)
      .borderWidth(2)
      .borderColor(this.selectedIndex === index
        ? $r('app.color.telegram_blue')
        : $r('app.color.text_secondary'))
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      // Option text
      Text(option.text)
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .margin({ left: 12 })
        .layoutWeight(1)
        .textAlign(TextAlign.Start)
    }
    .width('100%')
    .height(44)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 4, right: 4 })
    .borderRadius(10)
    .backgroundColor(this.selectedIndex === index
      ? $r('app.color.background_secondary')
      : Color.Transparent)
    .enabled(!this.message.pollIsClosed)
    .onClick(() => {
      this.selectedIndex = index;
      this.onVote(this.message, index);
    })
  }

  @Builder
  buildResultOption(option: PollOption, index: number) {
    Column() {
      // Top row: option text + percentage
      Row() {
        // Checkmark if this was the chosen option
        if (option.isChosen) {
          Image($r('app.media.ic_check_single'))
            .width(16)
            .height(16)
            .fillColor($r('app.color.telegram_blue'))
            .margin({ right: 6 })
        }

        Text(option.text)
          .fontSize(15)
          .fontColor($r('app.color.text_primary'))
          .fontWeight(option.isChosen ? FontWeight.Medium : FontWeight.Normal)
          .layoutWeight(1)
          .textAlign(TextAlign.Start)

        Text(`${option.votePercentage}%`)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(option.isChosen
            ? $r('app.color.telegram_blue')
            : $r('app.color.text_primary'))
          .margin({ left: 8 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // Progress bar for vote percentage
      Stack({ alignContent: Alignment.Start }) {
        // Background track
        Column()
          .width('100%')
          .height(4)
          .borderRadius(2)
          .backgroundColor($r('app.color.background_secondary'))

        // Filled portion
        Column()
          .width(`${Math.max(option.votePercentage, 1)}%`)
          .height(4)
          .borderRadius(2)
          .backgroundColor(option.isChosen
            ? $r('app.color.telegram_blue')
            : $r('app.color.text_secondary'))
      }
      .width('100%')
      .height(4)
      .margin({ top: 6 })
    }
    .width('100%')
    .padding({ left: 4, right: 4, top: 6, bottom: 6 })
  }
}

// TgPollBubble — poll message bubble (iOS ref: ChatMessagePollBubbleContentNode)
// Layout: Question + type badge + option rows with radio/bar + vote count

import { TgUiTokens } from '../tokens/TgUiTokens';

export class TgPollOptionVO {
  text: string = '';
  voterCount: number = 0;
  votePercentage: number = 0;
  isChosen: boolean = false;
}

@ComponentV2
export struct TgPollBubble {
  @Param question: string = '';
  @Param options: TgPollOptionVO[] = [];
  @Param totalVoterCount: number = 0;
  @Param isClosed: boolean = false;
  @Param isAnonymous: boolean = true;
  @Param pollType: string = 'regular';
  @Param isOutgoing: boolean = false;

  private hasVoted(): boolean {
    for (const opt of this.options) {
      if (opt.isChosen) return true;
    }
    return false;
  }

  private showResults(): boolean {
    return this.hasVoted() || this.isClosed;
  }

  private typeBadgeText(): string {
    if (this.isClosed) return 'Closed';
    if (this.pollType === 'quiz') return this.isAnonymous ? 'Anonymous Quiz' : 'Quiz';
    return this.isAnonymous ? 'Anonymous Poll' : 'Poll';
  }

  private voterText(): string {
    if (this.totalVoterCount === 0) return 'No votes yet';
    if (this.totalVoterCount === 1) return '1 vote';
    return `${this.totalVoterCount} votes`;
  }

  @Builder
  private buildOptionRow(opt: TgPollOptionVO, _index: number) {
    Column() {
      Row() {
        if (!this.showResults()) {
          // Radio circle (not voted state)
          Row()
            .width(22)
            .height(22)
            .borderRadius(11)
            .border({ width: 1.5, color: TgUiTokens.COLOR_TEXT_PREVIEW })
            .margin({ right: 10 })
        }

        Text(opt.text)
          .fontSize(15)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .layoutWeight(1)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.showResults()) {
          Text(`${opt.votePercentage}%`)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
            .width(42)
            .textAlign(TextAlign.End)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ top: 8, bottom: this.showResults() ? 2 : 8 })

      // Percentage bar (results state)
      if (this.showResults()) {
        Row() {
          Row()
            .height(6)
            .borderRadius(3)
            .backgroundColor(opt.isChosen ? TgUiTokens.CHAT_TOP_BAR_SUBTITLE_ACCENT : TgUiTokens.COLOR_TEXT_PREVIEW)
            .width(`${Math.max(opt.votePercentage, 3)}%`)
        }
        .width('100%')
        .padding({ bottom: 8, left: 0, right: 42 })
      }

      // Separator between options
      Row()
        .width('100%')
        .height(0.5)
        .backgroundColor(TgUiTokens.COLOR_SEPARATOR)
    }
    .width('100%')
  }

  build() {
    Column() {
      // Question
      Text(this.question)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .width('100%')
        .padding({ top: TgUiTokens.BUBBLE_PADDING_V, left: TgUiTokens.BUBBLE_PADDING_H, right: TgUiTokens.BUBBLE_PADDING_H })

      // Type badge
      Text(this.typeBadgeText())
        .fontSize(14)
        .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        .padding({ left: TgUiTokens.BUBBLE_PADDING_H, right: TgUiTokens.BUBBLE_PADDING_H, top: 2, bottom: 4 })

      // Options
      Column() {
        ForEach(this.options, (opt: TgPollOptionVO, index: number) => {
          this.buildOptionRow(opt, index)
        }, (opt: TgPollOptionVO, index: number) => `poll_opt_${index}_${opt.text}`)
      }
      .width('100%')
      .padding({ left: TgUiTokens.BUBBLE_PADDING_H, right: TgUiTokens.BUBBLE_PADDING_H })

      // Vote count
      Text(this.voterText())
        .fontSize(14)
        .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        .padding({ left: TgUiTokens.BUBBLE_PADDING_H, right: TgUiTokens.BUBBLE_PADDING_H, top: 6, bottom: TgUiTokens.BUBBLE_PADDING_V })
    }
    .constraintSize({ minWidth: 240 })
  }
}

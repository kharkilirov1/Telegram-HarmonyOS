// TgPollBubble — poll message bubble (iOS ref: ChatMessagePollBubbleContentNode)
// Layout: Question + type badge + option rows with radio/bar + vote count

import { TgUiTokens } from '../tokens/TgUiTokens';
import { localized } from '../../../core/utils/AppResource';

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
  @Param availableWidth: number = TgUiTokens.POLL_BUBBLE_PREFERRED_MIN_WIDTH;

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
    if (this.isClosed) {
      return localized($r('app.string.closed_label').id, 'Closed');
    }
    if (this.pollType === 'quiz') {
      return this.isAnonymous
        ? localized($r('app.string.anonymous_quiz').id, 'Anonymous quiz')
        : localized($r('app.string.quiz_type_label').id, 'Quiz');
    }
    return this.isAnonymous
      ? localized($r('app.string.anonymous_poll').id, 'Anonymous poll')
      : localized($r('app.string.poll').id, 'Poll');
  }

  private voterText(): string {
    if (this.totalVoterCount === 0) {
      return localized($r('app.string.no_votes_yet').id, 'No votes yet');
    }
    if (this.totalVoterCount === 1) {
      return localized($r('app.string.one_vote').id, '1 vote');
    }
    const mod10 = this.totalVoterCount % 10;
    const mod100 = this.totalVoterCount % 100;
    const key = mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)
      ? localized($r('app.string.few_votes').id, '{count} votes')
      : localized($r('app.string.many_votes').id, '{count} votes');
    return key.replace('{count}', `${this.totalVoterCount}`);
  }

  @Builder
  private buildOptionRow(opt: TgPollOptionVO, _index: number) {
    Column() {
      Row() {
        if (!this.showResults()) {
          // Radio circle (not voted state)
          Row()
            .width(TgUiTokens.POLL_OPTION_RADIO_SIZE)
            .height(TgUiTokens.POLL_OPTION_RADIO_SIZE)
            .borderRadius(TgUiTokens.POLL_OPTION_RADIO_RADIUS)
            .border({ width: TgUiTokens.POLL_OPTION_RADIO_STROKE, color: TgUiTokens.COLOR_TEXT_PREVIEW })
            .margin({ right: TgUiTokens.POLL_OPTION_RADIO_GAP })
        } else {
          Text(`${opt.votePercentage}%`)
            .fontSize(TgUiTokens.POLL_PERCENT_FONT_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
            .width(TgUiTokens.POLL_OPTION_PERCENT_WIDTH)
            .textAlign(TextAlign.End)
            .margin({ right: TgUiTokens.POLL_OPTION_PERCENT_GAP })
        }

        Text(opt.text)
          .fontSize(TgUiTokens.POLL_OPTION_FONT_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .layoutWeight(1)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: TgUiTokens.POLL_OPTION_SIDE_INSET, right: TgUiTokens.POLL_OPTION_RIGHT_INSET,
        top: TgUiTokens.POLL_OPTION_ROW_PADDING_TOP,
        bottom: this.showResults() ? TgUiTokens.POLL_OPTION_RESULT_ROW_PADDING_BOTTOM :
          TgUiTokens.POLL_OPTION_ROW_PADDING_BOTTOM })

      // Percentage bar (results state)
      if (this.showResults()) {
        Row() {
          Row()
            .height(TgUiTokens.POLL_OPTION_RESULT_BAR_HEIGHT)
            .borderRadius(TgUiTokens.POLL_OPTION_RESULT_BAR_RADIUS)
            .backgroundColor(opt.isChosen ? TgUiTokens.CHAT_TOP_BAR_SUBTITLE_ACCENT : TgUiTokens.COLOR_TEXT_PREVIEW)
            .width(`${Math.max(opt.votePercentage, TgUiTokens.POLL_OPTION_RESULT_MIN_PERCENT)}%`)
        }
        .width('100%')
        .padding({ left: TgUiTokens.POLL_OPTION_TEXT_INSET, right: TgUiTokens.POLL_OPTION_RIGHT_INSET,
          bottom: TgUiTokens.POLL_OPTION_RESULT_BAR_BOTTOM })
      }

      // Separator between options
      Row() {
        Row()
          .width('100%')
          .height(TgUiTokens.POLL_OPTION_SEPARATOR_HEIGHT)
          .backgroundColor(TgUiTokens.COLOR_SEPARATOR)
      }
        .width('100%')
        .padding({ left: TgUiTokens.POLL_OPTION_TEXT_INSET, right: TgUiTokens.POLL_OPTION_RIGHT_INSET })
    }
    .width('100%')
  }

  build() {
    Column() {
      // Question
      Text(this.question)
        .fontSize(TgUiTokens.POLL_QUESTION_FONT_SIZE)
        .fontWeight(FontWeight.Bold)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .width('100%')
        .padding({ top: TgUiTokens.BUBBLE_PADDING_V, left: TgUiTokens.BUBBLE_PADDING_H, right: TgUiTokens.BUBBLE_PADDING_H })

      // Type badge
      Text(this.typeBadgeText())
        .fontSize(TgUiTokens.POLL_LABEL_FONT_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        .padding({ left: TgUiTokens.BUBBLE_PADDING_H, right: TgUiTokens.BUBBLE_PADDING_H,
          top: TgUiTokens.POLL_TYPE_TOP_INSET, bottom: TgUiTokens.POLL_TYPE_BOTTOM_INSET })

      // Options
      Column() {
        ForEach(this.options, (opt: TgPollOptionVO, index: number) => {
          this.buildOptionRow(opt, index)
        }, (opt: TgPollOptionVO, index: number) => `poll_opt_${index}_${opt.text}`)
      }
      .width('100%')

      // Vote count
      Text(this.voterText())
        .fontSize(TgUiTokens.POLL_LABEL_FONT_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ left: TgUiTokens.BUBBLE_PADDING_H, right: TgUiTokens.BUBBLE_PADDING_H,
          top: TgUiTokens.POLL_FOOTER_TOP_INSET, bottom: TgUiTokens.BUBBLE_PADDING_V })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .constraintSize({
      minWidth: TgUiTokens.resolvePollBubbleMinWidth(this.availableWidth),
      maxWidth: this.availableWidth
    })
  }
}

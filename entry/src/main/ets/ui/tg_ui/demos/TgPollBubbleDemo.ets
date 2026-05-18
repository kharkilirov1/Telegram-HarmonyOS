import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgPollBubble, TgPollOptionVO } from '../atoms/TgPollBubble';

@Preview({ title: 'TgPollBubble' })
@ComponentV2
export struct TgPollBubbleDemo {
  private longQuestion: string = 'Which Telegram-style poll layout keeps option text, percentages, and the footer stable when the question is intentionally long?';
  private longOption: string = 'A very long answer option that should clamp to two lines and keep the result percentage aligned on the trailing edge';

  private option(text: string, voterCount: number = 0, votePercentage: number = 0, isChosen: boolean = false): TgPollOptionVO {
    const option = new TgPollOptionVO();
    option.text = text;
    option.voterCount = voterCount;
    option.votePercentage = votePercentage;
    option.isChosen = isChosen;
    return option;
  }

  private openAnonymousOptions(): TgPollOptionVO[] {
    return [
      this.option('Telegram iOS hierarchy'),
      this.option('Generic Harmony card'),
      this.option('Minimal text-only row')
    ];
  }

  private openPublicOptions(): TgPollOptionVO[] {
    return [
      this.option('Public result poll'),
      this.option('Anonymous poll'),
      this.option('Quiz')
    ];
  }

  private votedRegularOptions(): TgPollOptionVO[] {
    return [
      this.option('Message atoms first', 38, 63, true),
      this.option('Screens first', 14, 23),
      this.option('No migration plan', 8, 14)
    ];
  }

  private closedRegularOptions(): TgPollOptionVO[] {
    return [
      this.option('Keep router shell separate', 18, 45),
      this.option('Move meta into atom', 12, 30),
      this.option('Decide later', 10, 25)
    ];
  }

  private quizChosenOptions(): TgPollOptionVO[] {
    return [
      this.option('Poll option result bar', 6, 24),
      this.option('Quiz solution button', 16, 64, true),
      this.option('Footer voter text', 3, 12)
    ];
  }

  private closedQuizOptions(): TgPollOptionVO[] {
    return [
      this.option('Correct answer', 21, 70, true),
      this.option('Distractor answer', 6, 20),
      this.option('Another distractor', 3, 10)
    ];
  }

  private longTextOptions(): TgPollOptionVO[] {
    return [
      this.option(this.longOption, 17, 57, true),
      this.option('Short answer keeps alignment stable', 8, 27),
      this.option('Another long-ish option for multi-line pressure inside the current atom width', 5, 16)
    ];
  }

  private zeroVoterOptions(): TgPollOptionVO[] {
    return [
      this.option('No votes A', 0, 0),
      this.option('No votes B', 0, 0)
    ];
  }

  private unevenOptions(): TgPollOptionVO[] {
    return [
      this.option('Dominant option', 97, 97, true),
      this.option('Tiny option', 2, 2),
      this.option('One percent option', 1, 1)
    ];
  }

  @Builder
  private caseBlock(label: string, description: string, question: string, options: TgPollOptionVO[],
    totalVoterCount: number, isClosed: boolean, isAnonymous: boolean, pollType: string, isOutgoing: boolean,
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
          TgPollBubble({
            question: question,
            options: options,
            totalVoterCount: totalVoterCount,
            isClosed: isClosed,
            isAnonymous: isAnonymous,
            pollType: pollType,
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
        Text('TgPollBubble Demo')
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

        Text('Static state coverage for poll message body. Parent shell simulates router-owned bubble background/meta boundaries; vote selection and view-results behavior are not implemented here.')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        this.caseBlock('01 open anonymous regular poll', 'Unanswered state: radio circles visible, no result percentages or bars.',
          'Which layout contract is closer to Telegram?', this.openAnonymousOptions(), 0, false, true, 'regular', false)
        this.caseBlock('02 open public outgoing poll', 'Non-anonymous label and outgoing parent shell; atom internals remain static.',
          'Should results be public?', this.openPublicOptions(), 1, false, false, 'regular', true)
        this.caseBlock('03 voted regular poll', 'Chosen option forces result display with percentages and result bars.',
          'What should be migrated first?', this.votedRegularOptions(), 60, false, true, 'regular', false)
        this.caseBlock('04 closed regular poll', 'Closed state shows results even without a chosen option.',
          'Where should message meta live?', this.closedRegularOptions(), 40, true, true, 'regular', true)
        this.caseBlock('05 quiz with chosen answer', 'Quiz label plus chosen result bar; solution/correctness behavior is not part of this atom yet.',
          'Which iOS poll affordance is missing?', this.quizChosenOptions(), 25, false, true, 'quiz', false)
        this.caseBlock('06 closed quiz results', 'Closed quiz result state with percentages; correct-answer rendering remains future work.',
          'Pick the correct answer', this.closedQuizOptions(), 30, true, false, 'quiz', true)
        this.caseBlock('07 long question and options', 'Long text wrapping/ellipsis stress while percentage alignment stays trailing.',
          this.longQuestion, this.longTextOptions(), 30, false, true, 'regular', false,
          TgUiTokens.MSG_DEMO_NARROW_CONTAINER_WIDTH + TgUiTokens.SPACE_16 + TgUiTokens.SPACE_16)
        this.caseBlock('08 closed zero-voter results', 'Closed zero-vote edge case keeps deterministic 0% labels and minimal bars.',
          'Zero voter edge case?', this.zeroVoterOptions(), 0, true, true, 'regular', false)
        this.caseBlock('09 uneven percentage stress', 'Uneven percentages show the current minimum bar-width behavior for tiny options.',
          'How skewed are the results?', this.unevenOptions(), 100, false, true, 'regular', true)
      }
      .width('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
  }
}

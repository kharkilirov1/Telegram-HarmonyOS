import { TgMessageBubbleBase, TgMessageTextKind } from '../atoms/TgMessageBubbleBase';
import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgMessageBubbleDemo {
  private incomingShortText: string = 'Incoming short bubble.';
  private outgoingShortText: string = 'Outgoing short bubble.';
  private incomingLongText: string = 'Это длинный входящий текст для проверки bubble-геометрии: ширины, внутренних отступов, радиуса и переносов на нескольких строках.';
  private outgoingLongText: string = 'Outgoing long text validates the same constraints on the right side and should keep stable Telegram-like density.';
  private urlTortureText: string = 'https://telegram.org/veryveryveryveryveryveryveryveryveryverylongurlwithoutbreaks0123456789';
  private newlineText: string = 'Первый абзац.\n\nВторой абзац после пустой строки.\nТретий абзац для проверки стабильной высоты.';
  private emojiOneText: string = '🙂';
  private emojiThreeText: string = '🔥🙂🎯';
  private styleText: string = 'Стилизованный кейс: https://telegram.org @telegram #harmony';
  private sameText: string = 'Same message in two width constraints for side-by-side check.';

  private insertZeroWidthBreaks(source: string, every: number): string {
    if (every <= 0 || source.length <= every) {
      return source;
    }
    let result: string = '';
    for (let i = 0; i < source.length; i++) {
      result += source[i];
      if ((i + 1) % every === 0 && i + 1 < source.length) {
        result += '\u200B';
      }
    }
    return result;
  }

  private urlWithHelperBreaks(): string {
    return this.insertZeroWidthBreaks(this.urlTortureText, TgUiTokens.MSG_DEMO_WRAP_INJECT_EVERY);
  }

  @Builder
  private caseBlock(label: string, text: string, isOutgoing: boolean, kind: TgMessageTextKind = TgMessageTextKind.Plain,
    isEmojiOnly: boolean = false, containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH,
    useConstrainedContainer: boolean = false, forceBreakAll: boolean = false) {
    Column({ space: TgUiTokens.SPACE_6 }) {
      Text(label)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .width('100%')

      if (useConstrainedContainer) {
        Row() {
          TgMessageBubbleBase({
            text: text,
            isOutgoing: isOutgoing,
            isEmojiOnly: isEmojiOnly,
            kind: kind,
            containerWidth: containerWidth,
            forceBreakAll: forceBreakAll
          })
          .width(containerWidth)
        }
        .width('100%')
      } else {
        TgMessageBubbleBase({
          text: text,
          isOutgoing: isOutgoing,
          isEmojiOnly: isEmojiOnly,
          kind: kind,
          containerWidth: containerWidth,
          forceBreakAll: forceBreakAll
        })
      }
    }
    .width('100%')
    .padding({
      left: TgUiTokens.SPACE_16,
      right: TgUiTokens.SPACE_16,
      top: TgUiTokens.SPACE_6,
      bottom: TgUiTokens.SPACE_6
    })
  }

  @Builder
  private sideBySideColumn(label: string, width: number) {
    Column({ space: TgUiTokens.SPACE_6 }) {
      Text(label)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .width(width)

      TgMessageBubbleBase({
        text: this.sameText,
        isOutgoing: false,
        kind: TgMessageTextKind.Plain,
        containerWidth: width,
        forceBreakAll: true
      })
      .width(width)
    }
    .width(width)
  }

  build() {
    Scroll() {
      Column() {
        Text('TgMessageBubbleBase Demo')
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

        Text('Phase C / Step 1: bubble geometry only (alignment, radius, padding, width constraints)')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        this.caseBlock('01 incoming short', this.incomingShortText, false)
        this.caseBlock('02 outgoing short', this.outgoingShortText, true)
        this.caseBlock('03 incoming long paragraph', this.incomingLongText, false)
        this.caseBlock('04 outgoing long paragraph', this.outgoingLongText, true)
        this.caseBlock('05 incoming URL torture (BREAK_ALL)', this.urlTortureText, false, TgMessageTextKind.Link, false,
          TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, false, true)
        this.caseBlock('06 incoming URL torture (+demo helper \\u200B)', this.urlWithHelperBreaks(), false, TgMessageTextKind.Link, false,
          TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, false, false)
        this.caseBlock('07 incoming newline paragraphs', this.newlineText, false)
        this.caseBlock('08 outgoing emoji-only (1)', this.emojiOneText, true, TgMessageTextKind.Plain, true)
        this.caseBlock('09 outgoing emoji-only (3)', this.emojiThreeText, true, TgMessageTextKind.Plain, true)
        this.caseBlock('10 styled link/mention/hashtag', this.styleText, false, TgMessageTextKind.Link)
        this.caseBlock('11 narrow container', this.incomingLongText, false, TgMessageTextKind.Plain, false,
          TgUiTokens.MSG_DEMO_NARROW_CONTAINER_WIDTH, true)
        this.caseBlock('12 wide container', this.incomingLongText, false, TgMessageTextKind.Plain, false,
          TgUiTokens.MSG_DEMO_WIDE_CONTAINER_WIDTH, true)

        Text('Side-by-side same text with different width constraints')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            top: TgUiTokens.SPACE_8,
            bottom: TgUiTokens.SPACE_6
          })

        Row({ space: TgUiTokens.SPACE_12 }) {
          this.sideBySideColumn('Narrow', TgUiTokens.MSG_DEMO_SIDE_NARROW_CONTAINER_WIDTH)
          this.sideBySideColumn('Wide', TgUiTokens.MSG_DEMO_SIDE_WIDE_CONTAINER_WIDTH)
        }
        .width('100%')
        .padding({
          left: TgUiTokens.SPACE_16,
          right: TgUiTokens.SPACE_16,
          bottom: TgUiTokens.SPACE_16
        })
      }
      .width('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
  }
}

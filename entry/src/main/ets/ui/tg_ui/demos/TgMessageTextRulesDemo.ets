import { TgUiTokens } from '../tokens/TgUiTokens';

enum TgMessageTextKind {
  Plain = 0,
  Link = 1,
  Mention = 2,
  Hashtag = 3
}

@ComponentV2
export struct TgMessageTextRulesDemo {
  private incomingShortText: string = 'Привет! Контракт текста для пузыря зафиксирован.';
  private incomingLongText: string = 'Это длинный входящий текст для проверки lineHeight, мягких переносов и общего ритма набора. Он должен занимать несколько строк и оставаться визуально читаемым.';
  private outgoingLongText: string = 'Отправленный текст тоже должен выглядеть стабильно: переносы предсказуемые, ширина пузыря ограничена токеном, а геометрия не прыгает.';
  private urlTortureText: string = 'https://telegram.org/veryveryveryveryveryveryveryveryveryverylongurlwithoutbreaks0123456789';
  private newlineText: string = 'Первый абзац сообщения.\n\nВторой абзац после пустой строки.\nТретий абзац — проверка \\n.';
  private emojiOneText: string = '🙂';
  private emojiThreeText: string = '🔥🙂🎯';
  private linkStyleText: string = 'Открой https://telegram.org и проверь @telegram #harmony';
  private sideBySideText: string = 'Same text for side-by-side width comparison in one row.';

  private resolveBubbleColor(isOutgoing: boolean): ResourceColor {
    return isOutgoing ? TgUiTokens.COLOR_MSG_BUBBLE_OUTGOING_BG : TgUiTokens.COLOR_MSG_BUBBLE_INCOMING_BG;
  }

  private resolveTextColor(isOutgoing: boolean, kind: TgMessageTextKind): ResourceColor {
    if (kind === TgMessageTextKind.Plain) {
      return isOutgoing ? TgUiTokens.MSG_TEXT_OUTGOING : TgUiTokens.MSG_TEXT_INCOMING;
    }
    return isOutgoing ? TgUiTokens.MSG_LINK_OUTGOING : TgUiTokens.MSG_LINK_INCOMING;
  }

  private resolveWordBreak(forceBreakAll: boolean): WordBreak {
    return forceBreakAll ? WordBreak.BREAK_ALL : WordBreak.BREAK_WORD;
  }

  private bubbleMaxWidth(containerWidth: number): number {
    return Math.floor(containerWidth * TgUiTokens.BUBBLE_MAX_WIDTH_RATIO);
  }

  @Builder
  private renderMessageText(text: string, isOutgoing: boolean, kind: TgMessageTextKind, isEmojiOnly: boolean = false,
    forceBreakAll: boolean = false) {
    if (TgUiTokens.TEXT_MAX_LINES > 0) {
      Text(text)
        .fontSize(isEmojiOnly ? TgUiTokens.MSG_EMOJI_ONLY_SIZE : TgUiTokens.MSG_TEXT_SIZE)
        .fontWeight(TgUiTokens.MSG_TEXT_WEIGHT)
        .lineHeight(isEmojiOnly ? TgUiTokens.MSG_EMOJI_ONLY_LINE_HEIGHT : TgUiTokens.MSG_TEXT_LINE_HEIGHT)
        .fontColor(this.resolveTextColor(isOutgoing, kind))
        .wordBreak(this.resolveWordBreak(forceBreakAll))
        .maxLines(TgUiTokens.TEXT_MAX_LINES)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    } else {
      Text(text)
        .fontSize(isEmojiOnly ? TgUiTokens.MSG_EMOJI_ONLY_SIZE : TgUiTokens.MSG_TEXT_SIZE)
        .fontWeight(TgUiTokens.MSG_TEXT_WEIGHT)
        .lineHeight(isEmojiOnly ? TgUiTokens.MSG_EMOJI_ONLY_LINE_HEIGHT : TgUiTokens.MSG_TEXT_LINE_HEIGHT)
        .fontColor(this.resolveTextColor(isOutgoing, kind))
        .wordBreak(this.resolveWordBreak(forceBreakAll))
    }
  }

  @Builder
  private bubbleContent(text: string, isOutgoing: boolean, kind: TgMessageTextKind, containerWidth: number,
    isEmojiOnly: boolean = false, forceBreakAll: boolean = false) {
    Row() {
      this.renderMessageText(text, isOutgoing, kind, isEmojiOnly, forceBreakAll)
    }
    .padding({
      left: TgUiTokens.BUBBLE_PADDING_H,
      right: TgUiTokens.BUBBLE_PADDING_H,
      top: TgUiTokens.BUBBLE_PADDING_V,
      bottom: TgUiTokens.BUBBLE_PADDING_V
    })
    .backgroundColor(this.resolveBubbleColor(isOutgoing))
    .borderRadius(TgUiTokens.MSG_BUBBLE_RADIUS)
    .constraintSize({
      maxWidth: this.bubbleMaxWidth(containerWidth)
    })
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
          Row() {
            this.bubbleContent(text, isOutgoing, kind, containerWidth, isEmojiOnly, forceBreakAll)
          }
          .width(containerWidth)
          .justifyContent(isOutgoing ? FlexAlign.End : FlexAlign.Start)
        }
        .width('100%')
      } else {
        Row() {
          this.bubbleContent(text, isOutgoing, kind, containerWidth, isEmojiOnly, forceBreakAll)
        }
        .width('100%')
        .justifyContent(isOutgoing ? FlexAlign.End : FlexAlign.Start)
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
  private sideBySideColumn(title: string, widthToken: number) {
    Column({ space: TgUiTokens.SPACE_6 }) {
      Text(title)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .width(widthToken)
      Row() {
        this.bubbleContent(this.sideBySideText, false, TgMessageTextKind.Plain, widthToken, false, true)
      }
      .width(widthToken)
      .justifyContent(FlexAlign.Start)
    }
    .width(widthToken)
  }

  build() {
    Scroll() {
      Column() {
        Text('TgMessageTextRules Demo')
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

        Text('Phase C / Step 0: text wrapping + lineHeight + max bubble width contract')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        this.caseBlock('01 Incoming: short 1-line', this.incomingShortText, false)
        this.caseBlock('02 Incoming: long 4-6 lines', this.incomingLongText, false)
        this.caseBlock('03 Outgoing: long 4-6 lines', this.outgoingLongText, true)
        this.caseBlock('04 Incoming: long URL / unbroken token', this.urlTortureText, false, TgMessageTextKind.Link, false,
          TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, false, true)
        this.caseBlock('05 Incoming: text with \\n\\n', this.newlineText, false)
        this.caseBlock('06 Outgoing: emoji-only (1 emoji)', this.emojiOneText, true, TgMessageTextKind.Plain, true)
        this.caseBlock('07 Outgoing: emoji-only (3 emoji)', this.emojiThreeText, true, TgMessageTextKind.Plain, true)
        this.caseBlock('08 Incoming: link/mention/hashtag style', this.linkStyleText, false, TgMessageTextKind.Link)
        this.caseBlock('09 Narrow layout container', this.incomingLongText, false, TgMessageTextKind.Plain, false,
          TgUiTokens.MSG_DEMO_NARROW_CONTAINER_WIDTH, true)
        this.caseBlock('10 Wide layout container', this.incomingLongText, false, TgMessageTextKind.Plain, false,
          TgUiTokens.MSG_DEMO_WIDE_CONTAINER_WIDTH, true)

        Text('Side-by-side: same text, different width constraints')
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

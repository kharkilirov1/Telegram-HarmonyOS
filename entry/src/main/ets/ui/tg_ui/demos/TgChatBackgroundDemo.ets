import { TgChatBackground } from '../atoms/TgChatBackground';
import { TgUiTokens } from '../tokens/TgUiTokens';

@Preview({ title: 'TgChatBackground' })
@ComponentV2
export struct TgChatBackgroundDemo {
  @Builder
  private caseBlock(label: string, showPattern: boolean, height: number,
    outgoing: boolean, service: boolean) {
    Stack({ alignContent: Alignment.TopStart }) {
      TgChatBackground({ showPattern })

      Column({ space: TgUiTokens.SPACE_8 }) {
        Text(label)
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)

        if (service) {
          Text('Today')
            .fontSize(TgUiTokens.FONT_META_SIZE)
            .fontColor(TgUiTokens.DATE_SEPARATOR_TEXT)
            .padding({ left: TgUiTokens.SPACE_8, right: TgUiTokens.SPACE_8,
              top: TgUiTokens.SPACE_4, bottom: TgUiTokens.SPACE_4 })
            .backgroundColor(TgUiTokens.DATE_SEPARATOR_BG)
            .borderRadius(TgUiTokens.DATE_SEPARATOR_RADIUS)
        } else {
          Text(outgoing ? 'Outgoing message contrast' : 'Incoming message contrast')
            .fontSize(TgUiTokens.MSG_TEXT_SIZE)
            .fontColor(outgoing ? TgUiTokens.MSG_TEXT_OUTGOING : TgUiTokens.MSG_TEXT_INCOMING)
            .padding({ left: TgUiTokens.BUBBLE_PADDING_H,
              right: TgUiTokens.BUBBLE_PADDING_H,
              top: TgUiTokens.BUBBLE_PADDING_V,
              bottom: TgUiTokens.BUBBLE_PADDING_V })
            .backgroundColor(outgoing ? TgUiTokens.COLOR_MSG_BUBBLE_OUTGOING_BG :
              TgUiTokens.COLOR_MSG_BUBBLE_INCOMING_BG)
            .borderRadius(outgoing ? TgUiTokens.BUBBLE_RADIUS_OUTGOING :
              TgUiTokens.BUBBLE_RADIUS_INCOMING)
        }
      }
      .width('100%')
      .padding(TgUiTokens.SPACE_12)
    }
    .width('100%')
    .height(height)
  }

  build() {
    Scroll() {
      Column({ space: TgUiTokens.SPACE_12 }) {
        this.caseBlock('01 patterned incoming', true, 160, false, false)
        this.caseBlock('02 patterned outgoing', true, 160, true, false)
        this.caseBlock('03 patterned service', true, 160, false, true)
        this.caseBlock('04 solid fallback', false, 160, false, false)
        this.caseBlock('05 narrow patterned', true, 120, true, false)
        this.caseBlock('06 tall patterned', true, 240, false, false)
      }
      .width('100%')
      .padding(TgUiTokens.SPACE_12)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
  }
}

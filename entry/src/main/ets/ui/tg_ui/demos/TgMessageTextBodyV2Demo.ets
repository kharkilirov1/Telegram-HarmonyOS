import { TgMessageTextBodyV2 } from '../atoms/TgMessageTextBodyV2';
import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgMessageTextBodyV2Demo {
  build() {
    Scroll() {
      Column({ space: TgUiTokens.SPACE_12 }) {
        Text('TgMessageTextBodyV2 Demo')
          .fontSize(TgUiTokens.FONT_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .width('100%')

        Column({ space: TgUiTokens.SPACE_6 }) {
          Text('Incoming quote block')
            .fontSize(TgUiTokens.FONT_META_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_META)
            .width('100%')

          TgMessageTextBodyV2({
            text: 'Before quote\nQuoted fragment with multiple lines and stronger visual emphasis.\nAfter quote.',
            quoteOffsets: [13],
            quoteLengths: [61]
          })
        }
        .width('100%')
        .padding(TgUiTokens.SPACE_16)
        .backgroundColor(TgUiTokens.COLOR_MSG_BUBBLE_INCOMING_BG)
        .borderRadius(TgUiTokens.BUBBLE_RADIUS_INCOMING)

        Column({ space: TgUiTokens.SPACE_6 }) {
          Text('Outgoing collapsed quote block')
            .fontSize(TgUiTokens.FONT_META_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_META)
            .width('100%')

          TgMessageTextBodyV2({
            text: 'Ответ с цитатой внутри bubble.',
            isOutgoing: true,
            quoteOffsets: [0],
            quoteLengths: [21],
            quoteCollapsedFlags: [true]
          })
        }
        .width('100%')
        .padding(TgUiTokens.SPACE_16)
        .backgroundColor(TgUiTokens.COLOR_MSG_BUBBLE_OUTGOING_BG)
        .borderRadius(TgUiTokens.BUBBLE_RADIUS_OUTGOING)
      }
      .width('100%')
      .padding(TgUiTokens.SPACE_16)
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
  }
}

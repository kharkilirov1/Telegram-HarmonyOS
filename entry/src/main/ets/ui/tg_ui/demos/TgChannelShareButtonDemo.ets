import { TgChannelShareButton } from '../atoms/TgChannelShareButton';
import { TgChatBackground } from '../atoms/TgChatBackground';
import { TgUiTokens } from '../tokens/TgUiTokens';

@Preview({ title: 'TgChannelShareButton' })
@ComponentV2
export struct TgChannelShareButtonDemo {
  build() {
    Stack({ alignContent: Alignment.Center }) {
      TgChatBackground()

      Row() {
        Column() {
          Text('Broadcast post')
            .fontSize(TgUiTokens.MSG_TEXT_SIZE)
            .fontColor(TgUiTokens.MSG_TEXT_INCOMING)
        }
        .width(260)
        .height(84)
        .padding(TgUiTokens.BUBBLE_PADDING_H)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor(TgUiTokens.COLOR_MSG_BUBBLE_INCOMING_BG)
        .borderRadius(TgUiTokens.BUBBLE_RADIUS_INCOMING)

        TgChannelShareButton({})
          .margin({
            left: TgUiTokens.CHANNEL_SHARE_BUTTON_GAP,
            bottom: TgUiTokens.CHANNEL_SHARE_BUTTON_BOTTOM_INSET
          })
      }
      .alignItems(VerticalAlign.Bottom)
    }
    .width('100%')
    .height('100%')
  }
}

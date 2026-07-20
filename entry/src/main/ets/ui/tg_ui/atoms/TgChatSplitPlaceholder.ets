import { localized } from '../../../core/utils/AppResource';
import { TgChatBackground } from './TgChatBackground';
import { TgDateSeparator } from './TgDateSeparator';
import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgChatSplitPlaceholder {
  build() {
    Stack({ alignContent: Alignment.Center }) {
      TgChatBackground()

      TgDateSeparator({
        text: localized($r('app.string.chat_split_start_messaging').id, 'Start Messaging'),
        containerWidth: TgUiTokens.CHAT_SPLIT_MIN_CONTENT_WIDTH
      })
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
  }
}

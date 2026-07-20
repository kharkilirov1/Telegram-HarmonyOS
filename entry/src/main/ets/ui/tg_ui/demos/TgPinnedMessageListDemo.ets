import { TgChatBackground } from '../atoms/TgChatBackground';
import { TgPinnedMessageList, TgPinnedMessageListItem } from '../atoms/TgPinnedMessageList';
import { TgUiTokens } from '../tokens/TgUiTokens';

@Preview({ title: 'TgPinnedMessageList' })
@ComponentV2
export struct TgPinnedMessageListDemo {
  private item(id: string, title: string, preview: string, index: number): TgPinnedMessageListItem {
    const item = new TgPinnedMessageListItem();
    item.messageId = id;
    item.title = title;
    item.preview = preview;
    item.stripeIndex = index;
    item.totalCount = 4;
    return item;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      TgChatBackground()
      TgPinnedMessageList({
        items: [
          this.item('4', 'Pinned Message', 'Newest pinned message', 3),
          this.item('3', 'Pinned Message #3', 'A media caption or preview', 2),
          this.item('2', 'Pinned Message #2', 'An older pinned message', 1),
          this.item('1', 'Pinned Message #1', 'The first pinned message', 0)
        ],
        contentStartOffset: TgUiTokens.TOP_BAR_HEIGHT,
        bottomInset: TgUiTokens.SPACE_16
      })
    }
    .width('100%')
    .height('100%')
  }
}

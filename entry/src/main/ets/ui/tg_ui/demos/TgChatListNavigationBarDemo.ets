import { TgChatListNavigationBar } from '../atoms/TgChatListNavigationBar';
import { TgUiTokens } from '../tokens/TgUiTokens';

@Preview({ title: 'TgChatListNavigationBar' })
@ComponentV2
export struct TgChatListNavigationBarDemo {
  build() {
    Column({ space: TgUiTokens.SPACE_12 }) {
      TgChatListNavigationBar({
        title: 'Chats',
        searchValue: '',
        searchPlaceholder: 'Search',
        editText: 'Edit'
      })

      TgChatListNavigationBar({
        title: 'Very long localized chat-list title that should still remain centered',
        searchValue: 'war',
        searchPlaceholder: 'Search',
        editText: 'Редактировать'
      })

      Blank()
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
  }
}

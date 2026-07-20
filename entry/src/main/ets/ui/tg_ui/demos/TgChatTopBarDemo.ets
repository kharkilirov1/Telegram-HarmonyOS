import { TgChatTopBar, TgChatTopBarTrailingAction } from '../atoms/TgChatTopBar';
import { TgChatBackground } from '../atoms/TgChatBackground';
import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgGlassPolicy } from '../tokens/TgGlassPolicy';

@Preview({ title: 'TgChatTopBar' })
@ComponentV2
export struct TgChatTopBarDemo {
  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      TgChatBackground({ showPattern: true })

      Scroll() {
        Column({ space: TgUiTokens.SPACE_12 }) {
          TgChatTopBar({
            topInset: 0,
            title: 'Alice',
            subtitle: 'online',
            avatarInitials: 'AL',
            avatarColorIndex: 0,
            isOnline: true,
            trailingAction: TgChatTopBarTrailingAction.Search
          })

          TgChatTopBar({
            topInset: 0,
            title: 'zai',
            subtitle: 'bot',
            avatarInitials: 'Z',
            avatarColorIndex: 2,
            isOnline: false,
            trailingAction: TgChatTopBarTrailingAction.Search
          })

          TgChatTopBar({
            topInset: 0,
            title: 'Engineering',
            subtitle: '124 members, 8 online',
            avatarInitials: 'EN',
            avatarColorIndex: 3,
            isOnline: false,
            trailingAction: TgChatTopBarTrailingAction.Avatar
          })

          TgChatTopBar({
            topInset: 0,
            title: 'Very long chat title that should ellipsize inside center capsule',
            subtitle: 'Last seen recently with equally long subtitle text',
            avatarInitials: 'VL',
            avatarColorIndex: 7,
            isOnline: false,
            trailingAction: TgChatTopBarTrailingAction.Search
          })

          TgChatTopBar({
            topInset: 0,
            title: 'Fallback glass mode',
            subtitle: 'blur disabled',
            avatarInitials: 'FG',
            avatarColorIndex: 5,
            isOnline: false,
            trailingAction: TgChatTopBarTrailingAction.Avatar,
            glassMode: TgGlassPolicy.MODE_FALLBACK
          })

          TgChatTopBar({
            topInset: 0,
            title: 'Search mode',
            subtitle: 'title capsule replaced by search',
            avatarInitials: 'S',
            isSearchMode: true,
            searchQuery: 'glass'
          })
        }
        .width('100%')
        .padding({ top: TgUiTokens.SPACE_12, bottom: TgUiTokens.SPACE_12 })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}

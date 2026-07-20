import {
  TgChatListNavigationBar,
  TgChatListStoryPreview
} from '../atoms/TgChatListNavigationBar';
import { TgUiTokens } from '../tokens/TgUiTokens';

function storyPreview(initials: string, color: ResourceColor): TgChatListStoryPreview {
  const value = new TgChatListStoryPreview();
  value.initials = initials;
  value.backgroundColor = color;
  return value;
}

@Preview({ title: 'TgChatListNavigationBar' })
@ComponentV2
export struct TgChatListNavigationBarDemo {
  private storyPreviews: TgChatListStoryPreview[] = [
    storyPreview('A', TgUiTokens.AVATAR_COLOR_1),
    storyPreview('K', TgUiTokens.AVATAR_COLOR_4),
    storyPreview('M', TgUiTokens.AVATAR_COLOR_7)
  ];

  build() {
    Column({ space: TgUiTokens.SPACE_12 }) {
      TgChatListNavigationBar({
        title: 'Chats',
        searchValue: '',
        searchPlaceholder: 'Search',
        editText: 'Edit',
        storyPreviews: this.storyPreviews,
        unreadFilterCount: 66,
        searchCollapseProgress: 0
      })

      TgChatListNavigationBar({
        title: 'Chats',
        searchValue: '',
        searchPlaceholder: 'Search',
        editText: 'Изм.',
        storyPreviews: this.storyPreviews,
        unreadFilterCount: 66,
        searchCollapseProgress: 1
      })

      Blank()
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
  }
}

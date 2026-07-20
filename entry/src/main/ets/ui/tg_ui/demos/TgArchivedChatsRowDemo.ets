import { TgArchivedChatsRow } from '../atoms/TgArchivedChatsRow';
import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgArchivedChatsRowDemo {
  build() {
    Column() {
      TgArchivedChatsRow({
        title: 'Archived Chats',
        preview: 'Family, Work, News',
        chatCount: 29,
        unreadCount: 0
      })
      TgArchivedChatsRow({
        title: 'Archived Chats',
        preview: 'Design Team, Telegram, Travel',
        chatCount: 84,
        unreadCount: 12
      })
      TgArchivedChatsRow({
        title: 'Archived Chats',
        preview: '',
        chatCount: 1,
        unreadCount: 1
      })
      TgArchivedChatsRow({
        title: 'Архив чатов',
        preview: 'Очень длинное название рабочего чата, Новости, Семья',
        chatCount: 1200,
        unreadCount: 813
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
  }
}

import { TgContactRow } from '../atoms/TgContactRow';
import { TgContactSectionHeader } from '../atoms/TgContactSectionHeader';
import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgContactRowDemo {
  build() {
    Column() {
      TgContactSectionHeader({ title: 'A' })
      TgContactRow({ name: 'Alice', initials: 'A', statusText: 'online', isOnline: true })
      TgContactRow({ name: 'Alex Morgan', initials: 'AM', statusText: 'last seen recently' })
      TgContactRow({ name: 'A very long contact name that must ellipsize', initials: 'AL', statusText: 'offline' })
      TgContactSectionHeader({ title: 'Б' })
      TgContactRow({ name: 'Борис', initials: 'Б', statusText: 'online', isOnline: true })
      TgContactRow({ name: 'Бэлла', initials: 'Б', statusText: 'last seen within a week' })
      TgContactSectionHeader({ title: '#' })
      TgContactRow({ name: '~Omar', initials: '~', statusText: 'offline', showSeparator: false })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
  }
}

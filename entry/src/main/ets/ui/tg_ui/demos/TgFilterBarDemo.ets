// TgFilterBarDemo — 4 demo cases for TgFilterBar (Phase G).

import { TgFilterBar, TgFilterBarItem } from '../atoms/TgFilterBar';
import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgFilterBarDemo {
  @Local selectedTypical: string = 'all';
  @Local selectedMinimal: string = 'chats';
  @Local selectedScroll: string = 'f1';
  @Local selectedGlass: string = 'all';

  private typicalItems: TgFilterBarItem[] = [
    { id: 'all', title: 'All', badgeCount: 23 },
    { id: 'unread', title: 'Unread', badgeCount: 5 },
    { id: 'personal', title: 'Personal', badgeCount: 0 },
    { id: 'groups', title: 'Groups', badgeCount: 1 },
    { id: 'channels', title: 'Channels', badgeCount: 12 },
    { id: 'bots', title: 'Bots', badgeCount: 0 }
  ];

  private minimalItems: TgFilterBarItem[] = [
    { id: 'chats', title: 'Chats', badgeCount: 0 },
    { id: 'archive', title: 'Archive', badgeCount: 0 }
  ];

  private scrollItems: TgFilterBarItem[] = [
    { id: 'f1', title: 'All', badgeCount: 42 },
    { id: 'f2', title: 'Unread', badgeCount: 7 },
    { id: 'f3', title: 'Personal', badgeCount: 0 },
    { id: 'f4', title: 'Groups', badgeCount: 3 },
    { id: 'f5', title: 'Channels', badgeCount: 15 },
    { id: 'f6', title: 'Bots', badgeCount: 0 },
    { id: 'f7', title: 'Work', badgeCount: 2 },
    { id: 'f8', title: 'News', badgeCount: 9 },
    { id: 'f9', title: 'Crypto', badgeCount: 0 },
    { id: 'f10', title: 'Design', badgeCount: 1 },
    { id: 'f11', title: 'Dev', badgeCount: 4 },
    { id: 'f12', title: 'Travel', badgeCount: 0 }
  ];

  @Builder
  private buildSectionTitle(title: string) {
    Text(title)
      .fontSize(TgUiTokens.FONT_META_SIZE)
      .fontColor(TgUiTokens.COLOR_TEXT_META)
      .padding({ left: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_16, bottom: TgUiTokens.SPACE_4 })
  }

  build() {
    Scroll() {
      Column() {
        // Case 1: Typical (6 filters with badges)
        this.buildSectionTitle('Typical — 6 filters')
        TgFilterBar({
          items: this.typicalItems,
          selectedId: this.selectedTypical,
          onFilterSelect: (id: string): void => { this.selectedTypical = id; }
        })

        // Case 2: Minimal (2 filters, no badges)
        this.buildSectionTitle('Minimal — 2 filters')
        TgFilterBar({
          items: this.minimalItems,
          selectedId: this.selectedMinimal,
          onFilterSelect: (id: string): void => { this.selectedMinimal = id; }
        })

        // Case 3: Scroll (12 filters, horizontal scroll)
        this.buildSectionTitle('Scroll — 12 filters')
        TgFilterBar({
          items: this.scrollItems,
          selectedId: this.selectedScroll,
          onFilterSelect: (id: string): void => { this.selectedScroll = id; }
        })

        // Case 4: Glass (background image for blur demo)
        this.buildSectionTitle('Glass — blur over image')
        Stack() {
          Image($r('app.media.app_icon'))
            .width('100%')
            .height(120)
            .objectFit(ImageFit.Cover)

          Column() {
            TgFilterBar({
              items: this.typicalItems,
              selectedId: this.selectedGlass,
              onFilterSelect: (id: string): void => { this.selectedGlass = id; }
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .height(120)
        }
        .width('100%')
        .height(120)
        .clip(true)
        .borderRadius(TgUiTokens.RADIUS_12)
        .margin({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16 })
      }
      .width('100%')
      .padding({ bottom: TgUiTokens.SPACE_16 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
  }
}

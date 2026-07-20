import { TgRootSearchDock } from '../atoms/TgRootSearchDock';
import { TgUiTokens } from '../tokens/TgUiTokens';
import { ROOT_SEARCH_DOCK_IDLE_WIDTH } from '../../utils/RootTabBarGeometry';

@Entry
@ComponentV2
export struct TgRootSearchDockDemo {
  @Local private query: string = '';
  @Local private active: boolean = false;
  @Local private focusRevision: number = 0;

  build() {
    Column({ space: TgUiTokens.SPACE_16 }) {
      Text('Collapsed')
        .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
      Row() {
        TgRootSearchDock({
          value: '',
          placeholder: 'Search',
          active: false
        })
      }
      .width(ROOT_SEARCH_DOCK_IDLE_WIDTH)
      .height(ROOT_SEARCH_DOCK_IDLE_WIDTH)
      .borderRadius(ROOT_SEARCH_DOCK_IDLE_WIDTH / 2)
      .backgroundColor(TgUiTokens.CHAT_TOP_BAR_CAPSULE_FALLBACK_BG)

      Text('Interactive expanded')
        .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
      Row() {
        TgRootSearchDock({
          value: this.query,
          placeholder: 'Search chats',
          closeText: 'Close',
          active: this.active,
          focusRequestRevision: this.focusRevision,
          onActivate: (): void => {
            this.active = true;
            this.focusRevision += 1;
          },
          onChange: (value: string): void => {
            this.query = value;
          },
          onClose: (): void => {
            this.query = '';
            this.active = false;
          }
        })
      }
      .width('100%')
      .height(ROOT_SEARCH_DOCK_IDLE_WIDTH)
      .borderRadius(ROOT_SEARCH_DOCK_IDLE_WIDTH / 2)
      .backgroundColor(TgUiTokens.CHAT_TOP_BAR_CAPSULE_FALLBACK_BG)

      Text('Expanded query')
        .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
      Row() {
        TgRootSearchDock({
          value: 'telegram',
          placeholder: 'Search chats',
          active: true
        })
      }
      .width('100%')
      .height(ROOT_SEARCH_DOCK_IDLE_WIDTH)
      .borderRadius(ROOT_SEARCH_DOCK_IDLE_WIDTH / 2)
      .backgroundColor(TgUiTokens.CHAT_TOP_BAR_CAPSULE_FALLBACK_BG)
    }
    .width('100%')
    .height('100%')
    .padding(TgUiTokens.SPACE_24)
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
  }
}

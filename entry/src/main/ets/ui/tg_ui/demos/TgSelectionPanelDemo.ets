// TgSelectionPanelDemo — state matrix for the message-selection bar (C9).

import { TgSelectionPanel } from '../molecules/TgSelectionPanel';
import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgSelectionPanelDemo {
  @Local lastAction: string = '—';

  build() {
    Scroll() {
      Column() {
        Text('TgSelectionPanel')
          .fontSize(TgUiTokens.FONT_TITLE_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .margin({ bottom: TgUiTokens.SPACE_8 })

        Text('one message')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_META)
        TgSelectionPanel({
          title: '1 selected',
          onClose: (): void => {
            this.lastAction = 'close';
          },
          onCopy: (): void => {
            this.lastAction = 'copy';
          },
          onForward: (): void => {
            this.lastAction = 'forward';
          },
          onDelete: (): void => {
            this.lastAction = 'delete';
          }
        })

        Text('many messages')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_META)
          .margin({ top: TgUiTokens.SPACE_8 })
        TgSelectionPanel({
          title: '7 selected',
          onClose: (): void => {
            this.lastAction = 'close';
          },
          onCopy: (): void => {
            this.lastAction = 'copy';
          },
          onForward: (): void => {
            this.lastAction = 'forward';
          },
          onDelete: (): void => {
            this.lastAction = 'delete';
          }
        })

        Text('copy unavailable (selection has no text)')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_META)
          .margin({ top: TgUiTokens.SPACE_8 })
        TgSelectionPanel({
          title: '2 selected',
          canCopy: false,
          onClose: (): void => {
            this.lastAction = 'close';
          },
          onCopy: (): void => {
            this.lastAction = 'copy';
          },
          onForward: (): void => {
            this.lastAction = 'forward';
          },
          onDelete: (): void => {
            this.lastAction = 'delete';
          }
        })

        Text('last action: ' + this.lastAction)
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_META)
          .margin({ top: TgUiTokens.SPACE_8 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(TgUiTokens.SPACE_8)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
  }
}

// Extracted from TgChatScreenPage; layout and callback semantics are preserved.

import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { ChatMessageActionItem } from './ChatMessageActionsController';
import { ChatTimelineViewState } from './ChatTimelineViewState';
import { ChatMessageActionsPopupPort } from './ChatScreenViewPorts';

@ComponentV2
export struct TgChatMessageActionsPopup {
  @Require @Param timeline: ChatTimelineViewState;
  @Require @Param bindings: ChatMessageActionsPopupPort;

  build() {
    List() {
      ForEach(this.bindings.messageActionItems(this.timeline.messageActionsForwardState), (item: ChatMessageActionItem, index: number) => {
        ListItem() {
          Column() {
            Row() {
              Text(item.title)
                .fontSize(TgUiTokens.COMPOSER_BOT_POPUP_PRIMARY_TEXT_SIZE)
                .fontWeight(FontWeight.Regular)
                .fontColor(!item.enabled ? TgUiTokens.COLOR_TEXT_PREVIEW :
                  item.destructive ? TgUiTokens.COLOR_TEXT_ERROR : TgUiTokens.COLOR_TEXT_TITLE)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            }
            .width('100%')
            .height(TgUiTokens.COMPOSER_BOT_POPUP_ROW_HEIGHT -
              TgUiTokens.COMPOSER_BOT_POPUP_SEPARATOR_WIDTH)
            .padding({
              left: TgUiTokens.COMPOSER_BOT_POPUP_PADDING_H,
              right: TgUiTokens.COMPOSER_BOT_POPUP_PADDING_H
            })
            .alignItems(VerticalAlign.Center)

            Divider()
              .height(TgUiTokens.COMPOSER_BOT_POPUP_SEPARATOR_WIDTH)
              .color(index < this.bindings.messageActionItems(this.timeline.messageActionsForwardState).length - 1
                ? TgUiTokens.COLOR_SEPARATOR
                : Color.Transparent)
              .margin({ left: TgUiTokens.COMPOSER_BOT_POPUP_PADDING_H })
          }
          .width('100%')
          .height(TgUiTokens.COMPOSER_BOT_POPUP_ROW_HEIGHT)
          .onClick(() => {
            this.bindings.handleMessageActionPress(item);
          })
          .enabled(item.enabled)
        }
      }, (item: ChatMessageActionItem) =>
        `${item.contextToken}:${item.sourceMessageId}:${item.id}:${item.enabled}:${item.title}`)
    }
    .width(this.bindings.messageActionsPopupWidth())
    .height(this.bindings.messageActionsPopupHeight(this.timeline.messageActionsForwardState))
    .scrollBar(BarState.Off)
  }
}

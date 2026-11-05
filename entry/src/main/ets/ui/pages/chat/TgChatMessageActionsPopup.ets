// Extracted from TgChatScreenPage; layout and callback semantics are preserved.

import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { ChatMessageActionItem } from './ChatMessageActionsController';
import { ChatTimelineViewState } from './ChatTimelineViewState';
import { ChatMessageActionsPopupPort } from './ChatScreenViewPorts';
import { TgReactionPicker } from '../../tg_ui/atoms/TgReactionPicker';
import { localized } from '../../../core/utils/AppResource';

@ComponentV2
export struct TgChatMessageActionsPopup {
  @Require @Param timeline: ChatTimelineViewState;
  @Require @Param bindings: ChatMessageActionsPopupPort;

  // D24: the current translation target, expandable into the supported list.
  @Local private translationLanguagesOpen: boolean = false;

  @Builder
  private buildTranslationLanguageRow() {
    Column() {
      Row() {
        Text(localized($r('app.string.action_translate_to').id, 'Translate to') + ' ' +
          this.bindings.messageActionTranslationLanguage())
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.translationLanguagesOpen ? '⌃' : '⌄')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
      }
      .width('100%')
      .height(TgUiTokens.COMPOSER_BOT_POPUP_ROW_HEIGHT - TgUiTokens.COMPOSER_BOT_POPUP_SEPARATOR_WIDTH)
      .padding({
        left: TgUiTokens.COMPOSER_BOT_POPUP_PADDING_H,
        right: TgUiTokens.COMPOSER_BOT_POPUP_PADDING_H
      })
      .alignItems(VerticalAlign.Center)
      .onClick((): void => {
        this.translationLanguagesOpen = !this.translationLanguagesOpen;
      })

      if (this.translationLanguagesOpen) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.bindings.messageActionTranslationLanguages(), (code: string) => {
            Text(code.toUpperCase())
              .fontSize(TgUiTokens.FONT_META_SIZE)
              .fontColor(code === this.bindings.messageActionTranslationLanguage()
                ? TgUiTokens.MSG_LINK_INCOMING
                : TgUiTokens.COLOR_TEXT_TITLE)
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .margin({ right: TgUiTokens.SPACE_4, bottom: TgUiTokens.SPACE_4 })
              .borderRadius(TgUiTokens.RADIUS_8)
              .backgroundColor(TgUiTokens.REACTION_CHIP_BG)
              .onClick((): void => {
                this.translationLanguagesOpen = false;
                this.bindings.handleMessageActionTranslationLanguage(code);
              })
          }, (code: string) => code)
        }
        .width('100%')
        .padding({
          left: TgUiTokens.COMPOSER_BOT_POPUP_PADDING_H,
          right: TgUiTokens.COMPOSER_BOT_POPUP_PADDING_H,
          bottom: TgUiTokens.SPACE_8
        })
      }
    }
    .width('100%')
  }

  build() {
    Column() {
      if (this.bindings.messageActionReactionKeys().length > 0) {
        TgReactionPicker({
          keys: this.bindings.messageActionReactionKeys(),
          onReactionPress: (key: string): void => {
            this.bindings.handleMessageActionReaction(key);
          }
        })
        Divider()
          .height(TgUiTokens.COMPOSER_BOT_POPUP_SEPARATOR_WIDTH)
          .color(TgUiTokens.COLOR_SEPARATOR)
      }

      if (this.bindings.messageActionTranslationLanguages().length > 0 &&
        this.bindings.messageActionTranslationLanguage().length > 0) {
        this.buildTranslationLanguageRow()
        Divider()
          .height(TgUiTokens.COMPOSER_BOT_POPUP_SEPARATOR_WIDTH)
          .color(TgUiTokens.COLOR_SEPARATOR)
      }

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
    .width(this.bindings.messageActionsPopupWidth())
    .alignItems(HorizontalAlign.Start)
  }
}

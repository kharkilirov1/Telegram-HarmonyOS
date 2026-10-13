// Extracted from TgChatScreenPage; layout and callback semantics are preserved.

import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { TgChatTopBar, TgChatTopBarTrailingAction } from '../../tg_ui/atoms/TgChatTopBar';
import { TgChatBackground } from '../../tg_ui/atoms/TgChatBackground';
import { TgPinnedMessageList } from '../../tg_ui/atoms/TgPinnedMessageList';
import { localized } from '../../../core/utils/AppResource';
import { curves } from '@kit.ArkUI';
import { ChatChromeState } from './ChatChromeState';
import { ChatPinnedSearchState } from './ChatPinnedSearchState';
import { ChatPinnedOverlayPort } from './ChatScreenViewPorts';

@ComponentV2
export struct TgChatPinnedOverlay {
  @Require @Param chrome: ChatChromeState;
  @Require @Param pinnedSearch: ChatPinnedSearchState;
  @Require @Param bindings: ChatPinnedOverlayPort;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      TgChatBackground()

      TgPinnedMessageList({
        items: this.bindings.pinnedMessageListItems(),
        contentStartOffset: this.chrome.topBarTotalHeight,
        bottomInset: this.chrome.bottomOverlayInset,
        isLoading: this.pinnedSearch.pinnedMessagesListLoading,
        emptyText: localized($r('app.string.no_pinned_messages').id, 'No pinned messages'),
        onItemPress: (index: number): void => {
          this.bindings.handlePinnedListItemPress(index);
        },
        onLoadMore: (): void => {
          this.bindings.loadMorePinnedMessages();
        }
      })

      TgChatTopBar({
        topInset: this.bindings.chatTopInset(),
        title: localized($r('app.string.notifications_pinned_messages').id, 'Pinned Messages'),
        subtitle: `${this.pinnedSearch.pinnedMessageTotalCount}`,
        trailingAction: TgChatTopBarTrailingAction.None,
        onBackPress: (): void => {
          this.bindings.setPinnedMessagesListVisible(false);
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    .transition(
      TransitionEffect.move(TransitionEdge.END).animation({
        curve: curves.responsiveSpringMotion(
          TgUiTokens.PINNED_LIST_MOTION_RESPONSE,
          TgUiTokens.PINNED_LIST_MOTION_DAMPING,
          TgUiTokens.PINNED_LIST_MOTION_OVERLAP
        )
      })
    )
  }
}

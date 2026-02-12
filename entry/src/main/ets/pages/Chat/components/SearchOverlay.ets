import { ChatSearchBar } from '../../../components/Chat/ChatSearchBar';

@ComponentV2
export struct SearchOverlay {
  @Param isSearchMode: boolean = false;
  @Param chatId: number = 0;
  @Event onClose: () => void = () => {};
  @Event onScrollToMessage: (messageId: number) => void = () => {};

  build() {
    if (this.isSearchMode) {
      ChatSearchBar({
        chatId: this.chatId,
        onClose: () => { this.onClose(); },
        onScrollToMessage: (messageId: number) => { this.onScrollToMessage(messageId); }
      })
        .transition(
          TransitionEffect.move(TransitionEdge.TOP)
            .combine(TransitionEffect.OPACITY)
            .animation({ duration: 250, curve: Curve.EaseOut })
        )
    }
  }
}

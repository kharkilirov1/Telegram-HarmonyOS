import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { TgChatTopBarSubtitleMode, TgChatTopBarTrailingAction } from '../../tg_ui/atoms/TgChatTopBar';

// Page-owned presentation state. Keep this instance stable for its route lifetime.
@ObservedV2
export class ChatChromeState {
  @Trace pageStack: NavPathStack = new NavPathStack();
  @Trace activeChatId: number = 0;
  @Trace activeChatTitle: string = '';
  @Trace activeChatIsChannel: boolean = false;
  @Trace routeChatId: number = 0;
  @Trace routeChatTitle: string = '';
  @Trace title: string = 'Chat';
  @Trace chatSubtitle: string = '';
  @Trace chatSubtitleMode: TgChatTopBarSubtitleMode = TgChatTopBarSubtitleMode.Secondary;
  @Trace chatSubtitleSpinner: boolean = false;
  @Trace chatAvatarInitials: string = '';
  @Trace chatAvatarColorIndex: number = 0;
  @Trace chatAvatarImageSrc: string = '';
  @Trace chatIsOnline: boolean = false;
  @Trace chatTopBarTrailingAction: TgChatTopBarTrailingAction = TgChatTopBarTrailingAction.Search;
  @Trace timelineContainerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;
  @Trace topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @Trace bottomOverlayInset: number = TgUiTokens.SPACE_8;
  @Trace composerTotalHeight: number = TgUiTokens.COMPOSER_MIN_CAPSULE_HEIGHT +
    TgUiTokens.COMPOSER_VERTICAL_INSET * 2 + TgUiTokens.SPACE_8;
  @Trace chatBottomBarAction: 'none' | 'mute' | 'unmute' | 'join' | 'retry' = 'none';
  @Trace chatBottomBarRestricted: boolean = false;
  @Trace chatBottomBarReason: 'restricted' | 'banned' | 'unknown' | '' = '';
  @Trace composerAllowedKinds: string[] = [];
  @Trace composerSlowmodeSeconds: number = 0;
  @Trace composerAccessRetryVisible: boolean = false;
  @Trace chatAccessUnavailable: boolean = false;
}

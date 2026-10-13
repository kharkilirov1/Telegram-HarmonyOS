import { AppStore } from '../../../core/store/AppStore';
import { TdGatewayPort } from '../../../domain/ports/TdGatewayPort';
import { TgAttachmentRecentItem } from '../../tg_ui/atoms/TgAttachmentSheet';
import { CustomEmojiCellVO, CustomEmojiPackTabVO } from '../../tg_ui/atoms/TgComposerEmojiPanel';
import { StickerCellVO, StickerSetTabVO } from '../../tg_ui/atoms/TgComposerStickerPanel';
import { TgChatTopBarSubtitleMode, TgChatTopBarTrailingAction } from '../../tg_ui/atoms/TgChatTopBar';
import { ChatTimelineDataSource } from './ChatTimelineDataSource';
import { ChatTimelineEntryVO } from './ChatTimelineVO';
import { MediaPlaybackPageHandle } from './GlobalMediaPlayback';
import { ChatMediaDownloadController } from './ChatMediaDownloadController';
import { ChatAccessController } from './ChatAccessController';
import { ChatSlowmodeController } from './ChatSlowmodeController';
import { PendingMediaOpenIntent } from './PendingMediaOpenIntent';
import { ChatScreenRouteParams } from './ChatScreenRouteParams';
import { ChatComposerController } from './ChatComposerController';
import { ChatVoiceRecordingController } from './ChatVoiceRecordingController';
import { TgVoiceRecordingState } from '../../tg_ui/utils/TgVoiceRecordingPolicy';
import { ChatMessageActionsController } from './ChatMessageActionsController';
import { ChatForwardSourceController } from './ChatForwardSourceController';
import { ChatSearchController } from './ChatSearchController';
import { ChatStickerSearchController } from './ChatStickerSearchController';
import { PendingSharedMediaAction } from './PendingSharedMediaActionSignal';
import { SendMessageUseCase } from '../../../domain/usecases/sendMessage';
import { StickerPanelUseCase } from '../../../domain/usecases/stickerPanel';
import { SendMediaMessageUseCase } from '../../../domain/usecases/sendMediaMessage';
import { EditMessageUseCase } from '../../../domain/usecases/editMessage';
import { DeleteMessagesUseCase } from '../../../domain/usecases/deleteMessages';
import { ForwardMessagesUseCase } from '../../../domain/usecases/forwardMessages';
import { SetChatMuteUseCase } from '../../../domain/usecases/setChatMute';
import { JoinChatUseCase } from '../../../domain/usecases/joinChat';
import { SearchChatMessagesUseCase } from '../../../domain/usecases/searchChatMessages';
import { PinChatMessageUseCase } from '../../../domain/usecases/pinChatMessage';
import { LoadChatHistoryUseCase, LoadChatHistoryParams } from '../../../domain/usecases/loadChatHistory';
import { MarkChatReadUseCase } from '../../../domain/usecases/markChatRead';
import { BotMenuCommandEntry } from '../../../domain/usecases/loadBotMenu';
import { PinnedMessageInfo } from '../../../domain/usecases/loadPinnedMessage';
import { LoadRepliedMessageUseCase } from '../../../domain/usecases/loadRepliedMessage';
import { ReplyHydrationCoordinator } from './ReplyHydrationCoordinator';
import { CustomEmojiTextEntity } from '../../../core/model/AppCommand';
import { MediaGalleryItem } from '../../../models/MediaGalleryItem';
import { uiObserver, window } from '@kit.ArkUI';
import { ChatScreenViewState } from './ChatScreenViewState';

// One context per page/route. Operational resources stay outside reactive presentation state.
export class ChatScreenContext {
  readonly view: ChatScreenViewState;
  private readonly uiContextCallback: () => UIContext;
  private readonly queryNavigationInfoCallback: () => uiObserver.NavigationInfo | undefined;

  botMenuUrl: string = '';
  botMenuCommands: BotMenuCommandEntry[] = [];
  botMenuPeerUserId: number = 0;
  botMenuLoadingUserId: number = 0;
  messageActionsGeneration: number = 0;
  messageActionsSourceChatId: number = 0;
  messageActionsLifecycle: number = 0;
  messageActionsUseCase?: ForwardMessagesUseCase;
  messageActionsEntry: ChatTimelineEntryVO | undefined = undefined;
  memberCountHydratedChatId: number = 0;
  dataSource: ChatTimelineDataSource = new ChatTimelineDataSource();
  listScroller: Scroller = new Scroller();
  unsubscribe?: () => void;
  rebuildScheduled: boolean = false;
  rebuildTimerId: number = -1;
  pageLifecycleToken: number = 0;
  sendingMessageOperation: number = 0;
  // Monotonic input revision protects newly edited/ABA-restored composer input.
  composerInputRevision: number = 0;
  pinnedMessageRequestId: number = 0;
  pinnedMessagesListRequestId: number = 0;
  pinnedMessageDismissedId: string = '0';
  isClosing: boolean = false;
  transientTimerIds: Set<number> = new Set<number>();
  draftDebounceTimerId: number = -1;
  mainWindow?: window.Window;
  windowSizeListener?: () => void;
  sendUseCase?: SendMessageUseCase;
  sendMediaUseCase?: SendMediaMessageUseCase;
  editUseCase?: EditMessageUseCase;
  deleteUseCase?: DeleteMessagesUseCase;
  forwardUseCase?: ForwardMessagesUseCase;
  chatMuteUseCase?: SetChatMuteUseCase;
  chatJoinUseCase?: JoinChatUseCase;
  accountStore?: AppStore;
  routeAccountStore?: AppStore;
  chatGateway?: TdGatewayPort;
  routeContext?: ChatScreenRouteParams;
  routeActivated: boolean = false;
  routeDataStarted: boolean = false;
  initialHistoryParams?: LoadChatHistoryParams;
  initialHistoryFallbackRequested: boolean = false;
  chatAccessController?: ChatAccessController;
  slowmodeController: ChatSlowmodeController = new ChatSlowmodeController();
  searchUseCase?: SearchChatMessagesUseCase;
  pinUseCase?: PinChatMessageUseCase;
  stickerPanelUseCase?: StickerPanelUseCase;
  stickerPanelLoadedOnce: boolean = false;
  premiumStickerHomeLoaded: boolean = false;
  premiumStickerHomeLoading: boolean = false;
  favoriteStickerHomeLoaded: boolean = false;
  favoriteStickerHomeLoading: boolean = false;
  groupedStickerPreviewRequests: Set<number> = new Set<number>();
  customEmojiPanelLoadedOnce: boolean = false;
  attachmentRecentLoadToken: number = 0;
  stickerSetCache: Map<string, StickerCellVO[]> = new Map<string, StickerCellVO[]>();
  customEmojiSetCache: Map<string, CustomEmojiCellVO[]> = new Map<string, CustomEmojiCellVO[]>();
  private draftEmojiEntities: CustomEmojiTextEntity[] = [];
  get customEmojiDraftEntities(): CustomEmojiTextEntity[] { return this.draftEmojiEntities; }
  set customEmojiDraftEntities(value: CustomEmojiTextEntity[]) {
    if (this.draftEmojiEntities !== value) this.composerInputRevision++;
    this.draftEmojiEntities = value;
  }
  expectedProgrammaticCustomEmojiText: string = '';
  emojiSearchQuery: string = '';
  emojiSearchRequestId: number = 0;
  emojiSearchDebounceTimerId: number = -1;
  gifSearchQuery: string = '';
  gifSearchNextOffset: string = '';
  gifSearchRequestId: number = 0;
  gifSearchDebounceTimerId: number = -1;
  loadChatHistoryUseCase?: LoadChatHistoryUseCase;
  loadRepliedMessageUseCase?: LoadRepliedMessageUseCase;
  replyHydrationCoordinator: ReplyHydrationCoordinator = new ReplyHydrationCoordinator();
  markChatReadUseCase?: MarkChatReadUseCase;
  get isSending(): boolean { return this.view.composer.isSending; }
  set isSending(value: boolean) { this.view.composer.isSending = value; }
  searchFlashTimerId: number = -1;
  searchFlashMessageId: string = '';
  pendingJumpMessageId: string = '';
  pendingJumpAttempts: number = 0;
  jumpRequestToken: number = 0;
  pendingSharedMediaAction: PendingSharedMediaAction | undefined = undefined;
  isLoadingOlder: boolean = false;
  isLoadingNewer: boolean = false;
  isMarkingChatRead: boolean = false;
  historyFallbackTimerId: number = -1;
  lastVisibleStartIndex: number = -1;
  lastVisibleEndIndex: number = -1;
  composerResizeKeepsBottomAligned: boolean = false;
  chatViewportHeight: number = 0;
  previousDataCount: number = 0;
  needsScrollRestore: boolean = true;
  currentScrollChatId: number = 0;
  suppressLoadOlderUntil: number = 0;
  unreadRestoreIndex: number = -1;
  stickyLastReadMessageId: string = '';
  hasRestoredUnreadBoundary: boolean = false;
  lastMarkReadRequestKey: string = '';
  blockAutoPaginationUntilUserScroll: boolean = false;
  timelineTouchStartY: number = -1;
  isApplyingTimelineDiff: boolean = false;
  paginationRecheckTimerId: number = -1;
  mediaPlaybackHandle?: MediaPlaybackPageHandle;
  mediaPlaybackUnsubscribe?: () => void;
  mediaPlaybackIsCurrent?: () => boolean;
  locallyListenedVoiceIds: Set<string> = new Set<string>();
  mediaDownloadCtrl: ChatMediaDownloadController = new ChatMediaDownloadController();
  pendingMediaOpenIntent: PendingMediaOpenIntent = new PendingMediaOpenIntent();
  composerCtrl: ChatComposerController = new ChatComposerController();
  voiceRecordingCtrl: ChatVoiceRecordingController = new ChatVoiceRecordingController();
  messageActionsCtrl: ChatMessageActionsController = new ChatMessageActionsController();
  forwardSourceCtrl: ChatForwardSourceController = new ChatForwardSourceController();
  searchCtrl: ChatSearchController = new ChatSearchController();
  stickerSearchCtrl: ChatStickerSearchController = new ChatStickerSearchController();

  constructor(
    view: ChatScreenViewState,
    uiContextCallback: () => UIContext,
    queryNavigationInfoCallback: () => uiObserver.NavigationInfo | undefined
  ) {
    this.view = view;
    this.uiContextCallback = uiContextCallback;
    this.queryNavigationInfoCallback = queryNavigationInfoCallback;
  }

  getUIContext(): UIContext { return this.uiContextCallback(); }
  queryNavigationInfo(): uiObserver.NavigationInfo | undefined { return this.queryNavigationInfoCallback(); }

  // Compatibility aliases write directly to the sole observed backing field.
  get pageStack(): NavPathStack { return this.view.chrome.pageStack; }
  set pageStack(value: NavPathStack) { this.view.chrome.pageStack = value; }
  get activeChatId(): number { return this.view.chrome.activeChatId; }
  set activeChatId(value: number) { this.view.chrome.activeChatId = value; }
  get activeChatTitle(): string { return this.view.chrome.activeChatTitle; }
  set activeChatTitle(value: string) { this.view.chrome.activeChatTitle = value; }
  get activeChatIsChannel(): boolean { return this.view.chrome.activeChatIsChannel; }
  set activeChatIsChannel(value: boolean) { this.view.chrome.activeChatIsChannel = value; }
  get routeChatId(): number { return this.view.chrome.routeChatId; }
  set routeChatId(value: number) { this.view.chrome.routeChatId = value; }
  get routeChatTitle(): string { return this.view.chrome.routeChatTitle; }
  set routeChatTitle(value: string) { this.view.chrome.routeChatTitle = value; }
  get title(): string { return this.view.chrome.title; }
  set title(value: string) { this.view.chrome.title = value; }
  get chatSubtitle(): string { return this.view.chrome.chatSubtitle; }
  set chatSubtitle(value: string) { this.view.chrome.chatSubtitle = value; }
  get chatSubtitleMode(): TgChatTopBarSubtitleMode { return this.view.chrome.chatSubtitleMode; }
  set chatSubtitleMode(value: TgChatTopBarSubtitleMode) { this.view.chrome.chatSubtitleMode = value; }
  get chatSubtitleSpinner(): boolean { return this.view.chrome.chatSubtitleSpinner; }
  set chatSubtitleSpinner(value: boolean) { this.view.chrome.chatSubtitleSpinner = value; }
  get chatAvatarInitials(): string { return this.view.chrome.chatAvatarInitials; }
  set chatAvatarInitials(value: string) { this.view.chrome.chatAvatarInitials = value; }
  get chatAvatarColorIndex(): number { return this.view.chrome.chatAvatarColorIndex; }
  set chatAvatarColorIndex(value: number) { this.view.chrome.chatAvatarColorIndex = value; }
  get chatAvatarImageSrc(): string { return this.view.chrome.chatAvatarImageSrc; }
  set chatAvatarImageSrc(value: string) { this.view.chrome.chatAvatarImageSrc = value; }
  get chatIsOnline(): boolean { return this.view.chrome.chatIsOnline; }
  set chatIsOnline(value: boolean) { this.view.chrome.chatIsOnline = value; }
  get chatTopBarTrailingAction(): TgChatTopBarTrailingAction { return this.view.chrome.chatTopBarTrailingAction; }
  set chatTopBarTrailingAction(value: TgChatTopBarTrailingAction) { this.view.chrome.chatTopBarTrailingAction = value; }
  get pinnedMessageVisible(): boolean { return this.view.pinnedSearch.pinnedMessageVisible; }
  set pinnedMessageVisible(value: boolean) { this.view.pinnedSearch.pinnedMessageVisible = value; }
  get pinnedMessageId(): string { return this.view.pinnedSearch.pinnedMessageId; }
  set pinnedMessageId(value: string) { this.view.pinnedSearch.pinnedMessageId = value; }
  get pinnedMessagePreview(): string { return this.view.pinnedSearch.pinnedMessagePreview; }
  set pinnedMessagePreview(value: string) { this.view.pinnedSearch.pinnedMessagePreview = value; }
  get pinnedMessageHasThumbnail(): boolean { return this.view.pinnedSearch.pinnedMessageHasThumbnail; }
  set pinnedMessageHasThumbnail(value: boolean) { this.view.pinnedSearch.pinnedMessageHasThumbnail = value; }
  get pinnedMessageThumbnailPath(): string { return this.view.pinnedSearch.pinnedMessageThumbnailPath; }
  set pinnedMessageThumbnailPath(value: string) { this.view.pinnedSearch.pinnedMessageThumbnailPath = value; }
  get pinnedMessageIndex(): number { return this.view.pinnedSearch.pinnedMessageIndex; }
  set pinnedMessageIndex(value: number) { this.view.pinnedSearch.pinnedMessageIndex = value; }
  get pinnedMessageTotalCount(): number { return this.view.pinnedSearch.pinnedMessageTotalCount; }
  set pinnedMessageTotalCount(value: number) { this.view.pinnedSearch.pinnedMessageTotalCount = value; }
  get pinnedMessages(): PinnedMessageInfo[] { return this.view.pinnedSearch.pinnedMessages; }
  set pinnedMessages(value: PinnedMessageInfo[]) { this.view.pinnedSearch.pinnedMessages = value; }
  get pinnedMessagesNextFromMessageId(): string { return this.view.pinnedSearch.pinnedMessagesNextFromMessageId; }
  set pinnedMessagesNextFromMessageId(value: string) { this.view.pinnedSearch.pinnedMessagesNextFromMessageId = value; }
  get pinnedMessagesListVisible(): boolean { return this.view.pinnedSearch.pinnedMessagesListVisible; }
  set pinnedMessagesListVisible(value: boolean) { this.view.pinnedSearch.pinnedMessagesListVisible = value; }
  get pinnedMessagesListLoading(): boolean { return this.view.pinnedSearch.pinnedMessagesListLoading; }
  set pinnedMessagesListLoading(value: boolean) { this.view.pinnedSearch.pinnedMessagesListLoading = value; }
  get timelineContainerWidth(): number { return this.view.chrome.timelineContainerWidth; }
  set timelineContainerWidth(value: number) { this.view.chrome.timelineContainerWidth = value; }
  get topBarTotalHeight(): number { return this.view.chrome.topBarTotalHeight; }
  set topBarTotalHeight(value: number) { this.view.chrome.topBarTotalHeight = value; }
  get bottomOverlayInset(): number { return this.view.chrome.bottomOverlayInset; }
  set bottomOverlayInset(value: number) { this.view.chrome.bottomOverlayInset = value; }
  get composerTotalHeight(): number { return this.view.chrome.composerTotalHeight; }
  set composerTotalHeight(value: number) { this.view.chrome.composerTotalHeight = value; }
  get composerDraftText(): string { return this.view.composer.composerDraftText; }
  set composerDraftText(value: string) { if (this.view.composer.composerDraftText !== value) this.composerInputRevision++; this.view.composer.composerDraftText = value; }
  get chatBottomBarAction(): 'none' | 'mute' | 'unmute' | 'join' | 'retry' { return this.view.chrome.chatBottomBarAction; }
  set chatBottomBarAction(value: 'none' | 'mute' | 'unmute' | 'join' | 'retry') { this.view.chrome.chatBottomBarAction = value; }
  get chatBottomBarRestricted(): boolean { return this.view.chrome.chatBottomBarRestricted; }
  set chatBottomBarRestricted(value: boolean) { this.view.chrome.chatBottomBarRestricted = value; }
  get chatBottomBarReason(): 'restricted' | 'banned' | 'unknown' | '' { return this.view.chrome.chatBottomBarReason; }
  set chatBottomBarReason(value: 'restricted' | 'banned' | 'unknown' | '') { this.view.chrome.chatBottomBarReason = value; }
  get composerAllowedKinds(): string[] { return this.view.chrome.composerAllowedKinds; }
  set composerAllowedKinds(value: string[]) { this.view.chrome.composerAllowedKinds = value; }
  get composerSlowmodeSeconds(): number { return this.view.chrome.composerSlowmodeSeconds; }
  set composerSlowmodeSeconds(value: number) { this.view.chrome.composerSlowmodeSeconds = value; }
  get composerAccessRetryVisible(): boolean { return this.view.chrome.composerAccessRetryVisible; }
  set composerAccessRetryVisible(value: boolean) { this.view.chrome.composerAccessRetryVisible = value; }
  get chatAccessUnavailable(): boolean { return this.view.chrome.chatAccessUnavailable; }
  set chatAccessUnavailable(value: boolean) { this.view.chrome.chatAccessUnavailable = value; }
  get composerSelectionStart(): number { return this.view.composer.composerSelectionStart; }
  set composerSelectionStart(value: number) { this.view.composer.composerSelectionStart = value; }
  get composerSelectionEnd(): number { return this.view.composer.composerSelectionEnd; }
  set composerSelectionEnd(value: number) { this.view.composer.composerSelectionEnd = value; }
  get composerCaretRequestRevision(): number { return this.view.composer.composerCaretRequestRevision; }
  set composerCaretRequestRevision(value: number) { this.view.composer.composerCaretRequestRevision = value; }
  get showComposerEmojiPanel(): boolean { return this.view.panels.showComposerEmojiPanel; }
  set showComposerEmojiPanel(value: boolean) { this.view.panels.showComposerEmojiPanel = value; }
  get showComposerStickerPanel(): boolean { return this.view.panels.showComposerStickerPanel; }
  set showComposerStickerPanel(value: boolean) { this.view.panels.showComposerStickerPanel = value; }
  get stickerSettingsOpen(): boolean { return this.view.panels.stickerSettingsOpen; }
  set stickerSettingsOpen(value: boolean) { this.view.panels.stickerSettingsOpen = value; }
  get attachmentRecentItems(): TgAttachmentRecentItem[] { return this.view.panels.attachmentRecentItems; }
  set attachmentRecentItems(value: TgAttachmentRecentItem[]) { this.view.panels.attachmentRecentItems = value; }
  get attachmentRecentLoading(): boolean { return this.view.panels.attachmentRecentLoading; }
  set attachmentRecentLoading(value: boolean) { this.view.panels.attachmentRecentLoading = value; }
  get stickerPanelItems(): StickerCellVO[] { return this.view.panels.stickerPanelItems; }
  set stickerPanelItems(value: StickerCellVO[]) { this.view.panels.stickerPanelItems = value; }
  get premiumStickerItems(): StickerCellVO[] { return this.view.panels.premiumStickerItems; }
  set premiumStickerItems(value: StickerCellVO[]) { this.view.panels.premiumStickerItems = value; }
  get favoriteStickerItems(): StickerCellVO[] { return this.view.panels.favoriteStickerItems; }
  set favoriteStickerItems(value: StickerCellVO[]) { this.view.panels.favoriteStickerItems = value; }
  get stickerPanelLoading(): boolean { return this.view.panels.stickerPanelLoading; }
  set stickerPanelLoading(value: boolean) { this.view.panels.stickerPanelLoading = value; }
  get stickerSearchItems(): StickerCellVO[] { return this.view.panels.stickerSearchItems; }
  set stickerSearchItems(value: StickerCellVO[]) { this.view.panels.stickerSearchItems = value; }
  get stickerSearchLoading(): boolean { return this.view.panels.stickerSearchLoading; }
  set stickerSearchLoading(value: boolean) { this.view.panels.stickerSearchLoading = value; }
  get gifSearchItems(): StickerCellVO[] { return this.view.panels.gifSearchItems; }
  set gifSearchItems(value: StickerCellVO[]) { this.view.panels.gifSearchItems = value; }
  get gifSearchLoading(): boolean { return this.view.panels.gifSearchLoading; }
  set gifSearchLoading(value: boolean) { this.view.panels.gifSearchLoading = value; }
  get gifSearchHasMore(): boolean { return this.view.panels.gifSearchHasMore; }
  set gifSearchHasMore(value: boolean) { this.view.panels.gifSearchHasMore = value; }
  get gifSearchPageLoading(): boolean { return this.view.panels.gifSearchPageLoading; }
  set gifSearchPageLoading(value: boolean) { this.view.panels.gifSearchPageLoading = value; }
  get stickerSetTabs(): StickerSetTabVO[] { return this.view.panels.stickerSetTabs; }
  set stickerSetTabs(value: StickerSetTabVO[]) { this.view.panels.stickerSetTabs = value; }
  get activeStickerTabId(): string { return this.view.panels.activeStickerTabId; }
  set activeStickerTabId(value: string) { this.view.panels.activeStickerTabId = value; }
  get customEmojiPanelItems(): CustomEmojiCellVO[] { return this.view.panels.customEmojiPanelItems; }
  set customEmojiPanelItems(value: CustomEmojiCellVO[]) { this.view.panels.customEmojiPanelItems = value; }
  get customEmojiPanelLoading(): boolean { return this.view.panels.customEmojiPanelLoading; }
  set customEmojiPanelLoading(value: boolean) { this.view.panels.customEmojiPanelLoading = value; }
  get customEmojiPackTabs(): CustomEmojiPackTabVO[] { return this.view.panels.customEmojiPackTabs; }
  set customEmojiPackTabs(value: CustomEmojiPackTabVO[]) { this.view.panels.customEmojiPackTabs = value; }
  get activeCustomEmojiPackId(): string { return this.view.panels.activeCustomEmojiPackId; }
  set activeCustomEmojiPackId(value: string) { this.view.panels.activeCustomEmojiPackId = value; }
  get emojiSearchUnicodeResults(): string[] { return this.view.panels.emojiSearchUnicodeResults; }
  set emojiSearchUnicodeResults(value: string[]) { this.view.panels.emojiSearchUnicodeResults = value; }
  get emojiSearchCustomItems(): CustomEmojiCellVO[] { return this.view.panels.emojiSearchCustomItems; }
  set emojiSearchCustomItems(value: CustomEmojiCellVO[]) { this.view.panels.emojiSearchCustomItems = value; }
  get emojiSearchLoading(): boolean { return this.view.panels.emojiSearchLoading; }
  set emojiSearchLoading(value: boolean) { this.view.panels.emojiSearchLoading = value; }
  get pendingAttachmentKind(): string { return this.view.composer.pendingAttachmentKind; }
  set pendingAttachmentKind(value: string) { if (this.view.composer.pendingAttachmentKind !== value) this.composerInputRevision++; this.view.composer.pendingAttachmentKind = value; }
  get pendingAttachmentTitle(): string { return this.view.composer.pendingAttachmentTitle; }
  set pendingAttachmentTitle(value: string) { this.view.composer.pendingAttachmentTitle = value; }
  get pendingAttachmentPreview(): string { return this.view.composer.pendingAttachmentPreview; }
  set pendingAttachmentPreview(value: string) { this.view.composer.pendingAttachmentPreview = value; }
  get pendingAttachmentUris(): string[] { return this.view.composer.pendingAttachmentUris; }
  set pendingAttachmentUris(value: string[]) { if (this.view.composer.pendingAttachmentUris !== value) this.composerInputRevision++; this.view.composer.pendingAttachmentUris = value; }
  get voiceRecordingState(): TgVoiceRecordingState { return this.view.composer.voiceRecordingState; }
  set voiceRecordingState(value: TgVoiceRecordingState) { this.view.composer.voiceRecordingState = value; }
  get voiceRecordingDurationMs(): number { return this.view.composer.voiceRecordingDurationMs; }
  set voiceRecordingDurationMs(value: number) { this.view.composer.voiceRecordingDurationMs = value; }
  get showBotMenu(): boolean { return this.view.composer.showBotMenu; }
  set showBotMenu(value: boolean) { this.view.composer.showBotMenu = value; }
  get botMenuOpen(): boolean { return this.view.composer.botMenuOpen; }
  set botMenuOpen(value: boolean) { this.view.composer.botMenuOpen = value; }
  get botMenuTitle(): string { return this.view.composer.botMenuTitle; }
  set botMenuTitle(value: string) { this.view.composer.botMenuTitle = value; }
  get messageActionsOpenId(): string { return this.view.timeline.messageActionsOpenId; }
  set messageActionsOpenId(value: string) { this.view.timeline.messageActionsOpenId = value; }
  get messageActionsForwardState(): string { return this.view.timeline.messageActionsForwardState; }
  set messageActionsForwardState(value: string) { this.view.timeline.messageActionsForwardState = value; }
  get awaitingInitialTimeline(): boolean { return this.view.timeline.awaitingInitialTimeline; }
  set awaitingInitialTimeline(value: boolean) { this.view.timeline.awaitingInitialTimeline = value; }
  get prependScrollMask(): boolean { return this.view.timeline.prependScrollMask; }
  set prependScrollMask(value: boolean) { this.view.timeline.prependScrollMask = value; }
  get listInitialIndex(): number { return this.view.timeline.listInitialIndex; }
  set listInitialIndex(value: number) { this.view.timeline.listInitialIndex = value; }
  get replyToMessageId(): string { return this.view.composer.replyToMessageId; }
  set replyToMessageId(value: string) { if (this.view.composer.replyToMessageId !== value) this.composerInputRevision++; this.view.composer.replyToMessageId = value; }
  get replyToAuthor(): string { return this.view.composer.replyToAuthor; }
  set replyToAuthor(value: string) { this.view.composer.replyToAuthor = value; }
  get replyToPreview(): string { return this.view.composer.replyToPreview; }
  set replyToPreview(value: string) { this.view.composer.replyToPreview = value; }
  get replyToIsQuote(): boolean { return this.view.composer.replyToIsQuote; }
  set replyToIsQuote(value: boolean) { this.view.composer.replyToIsQuote = value; }
  get isForwardingMessages(): boolean { return this.view.composer.isForwardingMessages; }
  set isForwardingMessages(value: boolean) {
    if (this.view.composer.isForwardingMessages !== value) this.composerInputRevision++;
    this.view.composer.isForwardingMessages = value;
  }
  get forwardingMessageIds(): string[] { return this.view.composer.forwardingMessageIds; }
  set forwardingMessageIds(value: string[]) { this.view.composer.forwardingMessageIds = value; }
  get forwardSourceChatId(): number { return this.view.composer.forwardSourceChatId; }
  set forwardSourceChatId(value: number) { this.view.composer.forwardSourceChatId = value; }
  get forwardTitle(): string { return this.view.composer.forwardTitle; }
  set forwardTitle(value: string) { this.view.composer.forwardTitle = value; }
  get forwardPreview(): string { return this.view.composer.forwardPreview; }
  set forwardPreview(value: string) { this.view.composer.forwardPreview = value; }
  get activeVoiceMessageId(): string { return this.view.media.activeVoiceMessageId; }
  set activeVoiceMessageId(value: string) { this.view.media.activeVoiceMessageId = value; }
  get activeVoiceProgress(): number { return this.view.media.activeVoiceProgress; }
  set activeVoiceProgress(value: number) { this.view.media.activeVoiceProgress = value; }
  get activeVoicePlaying(): boolean { return this.view.media.activeVoicePlaying; }
  set activeVoicePlaying(value: boolean) { this.view.media.activeVoicePlaying = value; }
  get activeAudioMessageId(): string { return this.view.media.activeAudioMessageId; }
  set activeAudioMessageId(value: string) { this.view.media.activeAudioMessageId = value; }
  get activeAudioProgress(): number { return this.view.media.activeAudioProgress; }
  set activeAudioProgress(value: number) { this.view.media.activeAudioProgress = value; }
  get activeAudioPlaying(): boolean { return this.view.media.activeAudioPlaying; }
  set activeAudioPlaying(value: boolean) { this.view.media.activeAudioPlaying = value; }
  get pendingMediaDownloadVersion(): number { return this.view.media.pendingMediaDownloadVersion; }
  set pendingMediaDownloadVersion(value: number) { this.view.media.pendingMediaDownloadVersion = value; }
  get showMediaGallery(): boolean { return this.view.media.showMediaGallery; }
  set showMediaGallery(value: boolean) { this.view.media.showMediaGallery = value; }
  get galleryItems(): MediaGalleryItem[] { return this.view.media.galleryItems; }
  set galleryItems(value: MediaGalleryItem[]) { this.view.media.galleryItems = value; }
  get galleryInitialIndex(): number { return this.view.media.galleryInitialIndex; }
  set galleryInitialIndex(value: number) { this.view.media.galleryInitialIndex = value; }
  get galleryCurrentIndex(): number { return this.view.media.galleryCurrentIndex; }
  set galleryCurrentIndex(value: number) { this.view.media.galleryCurrentIndex = value; }
  get gallerySourceMessageId(): string { return this.view.media.gallerySourceMessageId; }
  set gallerySourceMessageId(value: string) { this.view.media.gallerySourceMessageId = value; }
  get isEditingMessage(): boolean { return this.view.composer.isEditingMessage; }
  set isEditingMessage(value: boolean) { this.view.composer.isEditingMessage = value; }
  get editingMessageId(): string { return this.view.composer.editingMessageId; }
  set editingMessageId(value: string) { this.view.composer.editingMessageId = value; }
  get editingOriginalText(): string { return this.view.composer.editingOriginalText; }
  set editingOriginalText(value: string) { this.view.composer.editingOriginalText = value; }
  get editingAllowsEmpty(): boolean { return this.view.composer.editingAllowsEmpty; }
  set editingAllowsEmpty(value: boolean) { this.view.composer.editingAllowsEmpty = value; }
  get isSearchMode(): boolean { return this.view.pinnedSearch.isSearchMode; }
  set isSearchMode(value: boolean) { this.view.pinnedSearch.isSearchMode = value; }
  get searchQuery(): string { return this.view.pinnedSearch.searchQuery; }
  set searchQuery(value: string) { this.view.pinnedSearch.searchQuery = value; }
  get searchResultPos(): number { return this.view.pinnedSearch.searchResultPos; }
  set searchResultPos(value: number) { this.view.pinnedSearch.searchResultPos = value; }
  get searchResultTotal(): number { return this.view.pinnedSearch.searchResultTotal; }
  set searchResultTotal(value: number) { this.view.pinnedSearch.searchResultTotal = value; }
  get searchResultLoaded(): number { return this.view.pinnedSearch.searchResultLoaded; }
  set searchResultLoaded(value: number) { this.view.pinnedSearch.searchResultLoaded = value; }
  get searchLoading(): boolean { return this.view.pinnedSearch.searchLoading; }
  set searchLoading(value: boolean) { this.view.pinnedSearch.searchLoading = value; }
  get searchError(): boolean { return this.view.pinnedSearch.searchError; }
  set searchError(value: boolean) { this.view.pinnedSearch.searchError = value; }
  get showScrollToBottom(): boolean { return this.view.timeline.showScrollToBottom; }
  set showScrollToBottom(value: boolean) { this.view.timeline.showScrollToBottom = value; }
  get scrollToBottomUnreadCount(): number { return this.view.timeline.scrollToBottomUnreadCount; }
  set scrollToBottomUnreadCount(value: number) { this.view.timeline.scrollToBottomUnreadCount = value; }
}

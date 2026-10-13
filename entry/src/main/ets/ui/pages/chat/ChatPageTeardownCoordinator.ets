// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
import { navigationUIState } from '../../../core/model/UIStateModels';
import { AppStore } from '../../../core/store/AppStore';
import { TdGatewayPort } from '../../../domain/ports/TdGatewayPort';
import { ChatMediaDownloadController } from './ChatMediaDownloadController';
import { ChatAccessController } from './ChatAccessController';
import { ChatSlowmodeController } from './ChatSlowmodeController';
import { ChatScreenRouteParams } from './ChatScreenRouteParams';
import { ChatVoiceRecordingController } from './ChatVoiceRecordingController';
import { TgVoiceRecordingState } from '../../tg_ui/utils/TgVoiceRecordingPolicy';
import { ChatSearchController } from './ChatSearchController';
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
import { LoadRepliedMessageUseCase } from '../../../domain/usecases/loadRepliedMessage';
import { ReplyHydrationCoordinator } from './ReplyHydrationCoordinator';
import { removeWindowSizeListener } from '../../utils/SafeAreaUtils';
import { window } from '@kit.ArkUI';

export interface ChatPageTeardownCoordinatorPort {
  accountStore?: AppStore;
  awaitingInitialTimeline: boolean;
  blockAutoPaginationUntilUserScroll: boolean;
  chatAccessController?: ChatAccessController;
  slowmodeController: ChatSlowmodeController;
  composerSlowmodeSeconds: number;
  chatGateway?: TdGatewayPort;
  chatJoinUseCase?: JoinChatUseCase;
  chatMuteUseCase?: SetChatMuteUseCase;
  deleteUseCase?: DeleteMessagesUseCase;
  draftDebounceTimerId: number;
  editUseCase?: EditMessageUseCase;
  forwardUseCase?: ForwardMessagesUseCase;
  hasRestoredUnreadBoundary: boolean;
  historyFallbackTimerId: number;
  initialHistoryFallbackRequested: boolean;
  initialHistoryParams?: LoadChatHistoryParams;
  isApplyingTimelineDiff: boolean;
  isClosing: boolean;
  isLoadingNewer: boolean;
  isLoadingOlder: boolean;
  isMarkingChatRead: boolean;
  lastMarkReadRequestKey: string;
  loadChatHistoryUseCase?: LoadChatHistoryUseCase;
  loadRepliedMessageUseCase?: LoadRepliedMessageUseCase;
  mainWindow?: window.Window;
  markChatReadUseCase?: MarkChatReadUseCase;
  mediaDownloadCtrl: ChatMediaDownloadController;
  pageLifecycleToken: number;
  paginationRecheckTimerId: number;
  pendingSharedMediaAction: PendingSharedMediaAction | undefined;
  pinUseCase?: PinChatMessageUseCase;
  pinnedMessageRequestId: number;
  rebuildScheduled: boolean;
  rebuildTimerId: number;
  replyHydrationCoordinator: ReplyHydrationCoordinator;
  routeActivated: boolean;
  routeContext?: ChatScreenRouteParams;
  routeDataStarted: boolean;
  scrollToBottomUnreadCount: number;
  searchCtrl: ChatSearchController;
  searchUseCase?: SearchChatMessagesUseCase;
  sendMediaUseCase?: SendMediaMessageUseCase;
  sendUseCase?: SendMessageUseCase;
  stickerPanelUseCase?: StickerPanelUseCase;
  stickyLastReadMessageId: string;
  suppressLoadOlderUntil: number;
  transientTimerIds: Set<number>;
  unreadRestoreIndex: number;
  unsubscribe?: () => void;
  voiceRecordingCtrl: ChatVoiceRecordingController;
  voiceRecordingDurationMs: number;
  voiceRecordingState: TgVoiceRecordingState;
  windowSizeListener?: () => void;
  clearOwnedChatContext(): void;
  clearPendingMediaDownloads(): void;
  clearSearchFlash(): void;
  clearTransientTimers(): void;
  closeMessageActions(): void;
  ownsNavigationContext(): boolean;
  persistDraft(chatId: number): void;
  resetBotMenuState(): void;
  resetEmojiSearchState(): void;
  resetGifSearchState(): void;
  resetPaginationState(): void;
  resetPinnedMessageState(): void;
  resetStickerSearchState(): void;
  saveScrollPosition(): void;
  setSendingMessage(value: boolean): void;
  teardownMediaPlaybackController(preserveListened?: boolean): void;
}

export function aboutToDisappear(host: ChatPageTeardownCoordinatorPort): void {
    host.clearSearchFlash();
    host.closeMessageActions();
    host.isClosing = false;
    host.pendingSharedMediaAction = undefined;
    host.voiceRecordingCtrl.dispose();
    host.voiceRecordingState = 'idle';
    host.voiceRecordingDurationMs = 0;
    host.resetBotMenuState();
    host.resetEmojiSearchState();
    host.resetStickerSearchState();
    host.resetGifSearchState();
    host.pinnedMessageRequestId++;
    host.resetPinnedMessageState();
    host.pageLifecycleToken++;
    const route = host.routeContext;
    const closingChatId = host.routeActivated && route !== undefined ? route.chatId : 0;
    if (host.draftDebounceTimerId >= 0) {
      clearTimeout(host.draftDebounceTimerId);
      host.draftDebounceTimerId = -1;
    }
    if (closingChatId !== 0) {
      host.persistDraft(closingChatId);
    }

    host.saveScrollPosition();
    // Nav lock is set by handleBackPress — do not re-extend in aboutToDisappear
    if (host.ownsNavigationContext()) {
      navigationUIState.chatScreenVisible = false;
      AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, false);
    }
    host.clearOwnedChatContext();
    host.routeActivated = false;
    host.routeDataStarted = false;
    host.initialHistoryParams = undefined;
    host.initialHistoryFallbackRequested = false;
    // The lease owns the pending acknowledgement and release-once cleanup;
    // assigning a chat id is not proof that this page acquired an open.
    if (route !== undefined) void route.openLease.release();
    if (host.historyFallbackTimerId >= 0) {
      clearTimeout(host.historyFallbackTimerId);
      host.historyFallbackTimerId = -1;
    }
    if (host.rebuildTimerId >= 0) {
      clearTimeout(host.rebuildTimerId);
      host.rebuildTimerId = -1;
    }
    host.searchCtrl.clearPendingTimer();
    host.clearTransientTimers();
    host.rebuildScheduled = false;
    host.isLoadingOlder = false;
    host.isLoadingNewer = false;
    host.isMarkingChatRead = false;
    host.setSendingMessage(false);
    host.suppressLoadOlderUntil = 0;
    host.unreadRestoreIndex = -1;
    host.stickyLastReadMessageId = '';
    host.hasRestoredUnreadBoundary = false;
    host.scrollToBottomUnreadCount = 0;
    host.lastMarkReadRequestKey = '';
    host.blockAutoPaginationUntilUserScroll = false;
    host.isApplyingTimelineDiff = false;

    host.clearPendingMediaDownloads();
    host.mediaDownloadCtrl.setChangeListener(undefined);
    if (host.paginationRecheckTimerId >= 0) {
      clearTimeout(host.paginationRecheckTimerId);
      host.paginationRecheckTimerId = -1;
    }
    host.resetPaginationState();
    host.awaitingInitialTimeline = false;
    host.sendUseCase = undefined;
    host.sendMediaUseCase = undefined;
    host.stickerPanelUseCase = undefined;
    host.editUseCase = undefined;
    host.deleteUseCase = undefined;
    host.forwardUseCase = undefined;
    host.chatMuteUseCase = undefined;
    host.chatJoinUseCase = undefined;
    host.chatAccessController?.dispose();
    host.chatAccessController = undefined;
    host.slowmodeController.dispose();
    host.composerSlowmodeSeconds = 0;
    host.accountStore = undefined;
    host.chatGateway = undefined;
    host.searchUseCase = undefined;
    host.pinUseCase = undefined;
    host.loadChatHistoryUseCase = undefined;
    host.loadRepliedMessageUseCase = undefined;
    host.replyHydrationCoordinator.reset();
    host.markChatReadUseCase = undefined;
    if (host.unsubscribe !== undefined) {
      host.unsubscribe();
      host.unsubscribe = undefined;
    }
    removeWindowSizeListener(host.windowSizeListener);
    host.windowSizeListener = undefined;
    host.mainWindow = undefined;
    host.teardownMediaPlaybackController();
  }

export function clearTransientTimers(host: ChatPageTeardownCoordinatorPort): void {
    host.transientTimerIds.forEach((timerId: number): void => {
      clearTimeout(timerId);
    });
    host.transientTimerIds.clear();
  }

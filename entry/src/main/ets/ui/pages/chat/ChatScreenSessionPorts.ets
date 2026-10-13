import { ChatComposerHostAdaptersPort } from './ChatComposerHostAdapters';
import { ChatMessageActionHostAdaptersPort } from './ChatMessageActionHostAdapters';
import { ChatPermissionCoordinatorPort } from './ChatPermissionCoordinator';
import { ChatMessageJumpCoordinatorPort } from './ChatMessageJumpCoordinator';
import { ChatSharedMediaActionCoordinatorPort } from './ChatSharedMediaActionCoordinator';
import { ChatSearchPresentationCoordinatorPort } from './ChatSearchPresentationCoordinator';
import { ChatRouteActivationCoordinatorPort } from './ChatRouteActivationCoordinator';
import { ChatRouteOwnershipCoordinatorPort } from './ChatRouteOwnershipCoordinator';
import { ChatPageTeardownCoordinatorPort } from './ChatPageTeardownCoordinator';
import { ChatWindowGeometryCoordinatorPort } from './ChatWindowGeometryCoordinator';
import { ChatPinnedMessagesCoordinatorPort } from './ChatPinnedMessagesCoordinator';
import { ChatPlaybackCoordinatorPort } from './ChatPlaybackCoordinator';
import { ChatTopBarCoordinatorPort } from './ChatTopBarCoordinator';
import { ChatBotMenuCoordinatorPort } from './ChatBotMenuCoordinator';
import { ChatTimelineTransactionCoordinatorPort } from './ChatTimelineTransactionCoordinator';
import { ChatReplyHydrationCoordinatorPort } from './ChatReplyHydrationCoordinator';
import { ChatTimelineViewportCoordinatorPort } from './ChatTimelineViewportCoordinator';
import { ChatTimelinePaginationCoordinatorPort } from './ChatTimelinePaginationCoordinator';
import { ChatMediaDownloadCoordinatorPort } from './ChatMediaDownloadCoordinator';
import { ChatMediaOpenCoordinatorPort } from './ChatMediaOpenCoordinator';
import { ChatMediaGalleryCoordinatorPort } from './ChatMediaGalleryCoordinator';
import { ChatMessagePopupCoordinatorPort } from './ChatMessagePopupCoordinator';
import { ChatComposerActionBindingsPort } from './ChatComposerActionBindings';
import { ChatCustomEmojiCatalogCoordinatorPort } from './ChatCustomEmojiCatalogCoordinator';
import { ChatEmojiSearchCoordinatorPort } from './ChatEmojiSearchCoordinator';
import { ChatStickerCatalogCoordinatorPort } from './ChatStickerCatalogCoordinator';
import { ChatStickerSearchBindingsPort } from './ChatStickerSearchBindings';
import { ChatGroupedStickerPreviewCoordinatorPort } from './ChatGroupedStickerPreviewCoordinator';
import { ChatGifSearchCoordinatorPort } from './ChatGifSearchCoordinator';
import { ChatDraftCoordinatorPort } from './ChatDraftCoordinator';
import { ChatPageNavigationCoordinatorPort } from './ChatPageNavigationCoordinator';
import { ChatInitialHistoryCoordinatorPort } from './ChatInitialHistoryCoordinator';
import { HandleTimelineScrollIndexPort, HandleComposerTextChangePort, HandleComposerAreaChangePort, HandleGalleryIndexChangePort, HandleNavReadyPort, HandleNavShownPort, HandleNavBackPressedPort } from './ChatScreenViewEventHandlers';

// Composition-only nominal contract. Features and UI accept their own narrower ports.
export interface ChatScreenSessionPorts extends
  ChatComposerHostAdaptersPort, ChatMessageActionHostAdaptersPort, ChatPermissionCoordinatorPort, ChatMessageJumpCoordinatorPort,
  ChatSharedMediaActionCoordinatorPort, ChatSearchPresentationCoordinatorPort, ChatRouteActivationCoordinatorPort, ChatRouteOwnershipCoordinatorPort,
  ChatPageTeardownCoordinatorPort, ChatWindowGeometryCoordinatorPort, ChatPinnedMessagesCoordinatorPort, ChatPlaybackCoordinatorPort,
  ChatTopBarCoordinatorPort, ChatBotMenuCoordinatorPort, ChatTimelineTransactionCoordinatorPort, ChatReplyHydrationCoordinatorPort,
  ChatTimelineViewportCoordinatorPort, ChatTimelinePaginationCoordinatorPort, ChatMediaDownloadCoordinatorPort, ChatMediaOpenCoordinatorPort,
  ChatMediaGalleryCoordinatorPort, ChatMessagePopupCoordinatorPort, ChatComposerActionBindingsPort, ChatCustomEmojiCatalogCoordinatorPort,
  ChatEmojiSearchCoordinatorPort, ChatStickerCatalogCoordinatorPort, ChatStickerSearchBindingsPort, ChatGroupedStickerPreviewCoordinatorPort,
  ChatGifSearchCoordinatorPort, ChatDraftCoordinatorPort, ChatPageNavigationCoordinatorPort, ChatInitialHistoryCoordinatorPort,
  HandleTimelineScrollIndexPort, HandleComposerTextChangePort, HandleComposerAreaChangePort, HandleGalleryIndexChangePort,
  HandleNavReadyPort, HandleNavShownPort, HandleNavBackPressedPort {
}

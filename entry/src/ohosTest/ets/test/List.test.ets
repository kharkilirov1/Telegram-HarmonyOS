// Test suite registry — imports and runs all test modules.
// Old service-layer tests (MessagesController, PreferencesService, etc.) removed —
// those modules no longer exist in the current architecture.

import { beforeEachIt } from '@ohos/hypium';
import messagesReducerTest from './MessagesReducer.test';
import messageDtoParserTest from './MessageDtoParser.test';
import stateCloneTest from './StateClone.test';
import chatTimelineVOTest from './ChatTimelineVO.test';
import textEngineTest from './TextEngine.test';
import appStateModelsTest from './AppStateModels.test';
import appErrorTest from './AppError.test';
import gatewayErrorPropagationTest from './GatewayErrorPropagation.test';
import writePathErrorsTest from './WritePathErrors.test';
import writeResendDialogTest from './WriteResendDialog.test';
import sequentialMediaSendTest from './SequentialMediaSend.test';
import sequentialMediaDialogTest from './SequentialMediaDialog.test';
import slowmodeTest from './Slowmode.test';
import slowmodePolicyTest from './SlowmodePolicy.test';
import slowmodeNativeTest from './SlowmodeNative.test';
import authSideEffectTest from './AuthSideEffect.test';
import loadCallsTest from './LoadCalls.test';
import chatCommandsTest from './ChatCommands.test';
import commandSerializerTest from './CommandSerializer.test';
import useCasesTest from './UseCases.test';
import downloadMessageMediaTest from './DownloadMessageMedia.test';
import userDtoTest from './UserDto.test';
import filePipelineTest from './FilePipeline.test';
import tdGatewayTest from './TdGateway.test';
import nativeReceiveFlowTest from './NativeReceiveFlow.test';
import eventNormalizerTest from './EventNormalizer.test';
import rootTabBarGeometryTest from './RootTabBarGeometry.test';
import tgComposerMaterialPolicyTest from './TgComposerMaterialPolicy.test';
import tgVoiceRecordingPolicyTest from './TgVoiceRecordingPolicy.test';
import loadBotMenuTest from './LoadBotMenu.test';
import loadPinnedMessageTest from './LoadPinnedMessage.test';
import pinnedMessageOwnershipTest from './PinnedMessageOwnership.test';
import emojiKeyboardSearchTest from './EmojiKeyboardSearch.test';
import stickerSearchTest from './StickerSearch.test';
import gifInlineSearchTest from './GifInlineSearch.test';
import chatArchiveStateTest from './ChatArchiveState.test';
import searchChatMessagesTest from './SearchChatMessages.test';
import tgCustomEmojiDraftPolicyTest from './TgCustomEmojiDraftPolicy.test';
import chatDraftEntitiesTest from './ChatDraftEntities.test';
import chatListUnreadBadgeTest from './ChatListUnreadBadge.test';
import mediaGalleryGeometryTransitionTest from './MediaGalleryGeometryTransition.test';
import mediaGalleryStateTest from './MediaGalleryState.test';
import tgPhotoAlbumLayoutTest from './TgPhotoAlbumLayout.test';
import tgUnicodeEmojiCatalogTest from './TgUnicodeEmojiCatalog.test';
import sharedMediaThumbnailCoordinatorTest from './SharedMediaThumbnailCoordinator.test';
import pendingSharedMediaActionSignalTest from './PendingSharedMediaActionSignal.test';
import chatMembersTest from './ChatMembers.test';
import chatPreviewTextTest from './ChatPreviewText.test';
import chatItemVOTest from './ChatItemVO.test';
import tgMediaGalleryPolicyTest from './TgMediaGalleryPolicy.test';
import replyHydrationCoordinatorTest from './ReplyHydrationCoordinator.test';
import loadRepliedMessageTest from './LoadRepliedMessage.test';
import activeStoriesStateTest from './ActiveStoriesState.test';
import loadActiveStoriesTest from './LoadActiveStories.test';
import createPrivateChatTest from './CreatePrivateChat.test';
import composeContactModelTest from './ComposeContactModel.test';
import searchComposeUsersTest from './SearchComposeUsers.test';
import importContactTest from './ImportContact.test';
import createBasicGroupChatTest from './CreateBasicGroupChat.test';
import createChannelChatTest from './CreateChannelChat.test';
import composeCreationModelTest from './ComposeCreationModel.test';
import eventPipelineTest from './EventPipeline.test';
import chatMediaDownloadControllerTest from './ChatMediaDownloadController.test';
import appStoreSessionTest from './AppStoreSession.test';
import liveChatPermissionsTest from './LiveChatPermissions.test';
import groupPermissionPayloadTest from './GroupPermissionPayload.test';
import forwardSendOwnershipTest from './ForwardSendOwnership.test';
import forwardMessagesContractTest from './ForwardMessagesContract.test';
import forwardEligibilityTest from './ForwardEligibility.test';
import forwardSourceActionsTest from './ForwardSourceActions.test';
import deleteMessagesSafetyTest from './DeleteMessagesSafety.test';
import editMessagesSafetyTest from './EditMessagesSafety.test';
import chatOpenLeaseTest from './ChatOpenLease.test';
import basicGroupAccessTest from './BasicGroupAccess.test';
import basicGroupMediaTest from './BasicGroupMedia.test';
import supergroupBoostsTest from './SupergroupBoosts.test';

import sendMediaAlbumTest from './SendMediaAlbum.test';
import photoAlbumDialogTest from './PhotoAlbumDialog.test';
import photoAttachmentFileIOTest from './PhotoAttachmentFileIO.test';
import photoSelectionPreviewTest from './PhotoSelectionPreview.test';
import chatScreenDecompositionTest from './ChatScreenDecomposition.test';
import timelineUpdateDataSourceTest from './TimelineUpdateDataSource.test';
import timelineUpdateOwnershipTest from './TimelineUpdateOwnership.test';
import timelineUpdateNativeTest from './TimelineUpdateNative.test';
import stabilizationMessagesTest from './StabilizationMessages.test';
import stabilizationNativeTest from './StabilizationNative.test';

export default function testsuite() {
  // Hypium inherits beforeEachIt into nested suites. A positive timeout lets
  // the platform event handler run between cases; zero-delay timers can keep
  // running inside one uv_timer_task and starve the application watchdog.
  beforeEachIt(async () => {
    await new Promise<void>((resolve) => { setTimeout(resolve, 16); });
  });

  // Core state management
  messagesReducerTest();
  stateCloneTest();
  appStateModelsTest();
  appErrorTest();
  gatewayErrorPropagationTest();
  writePathErrorsTest();
  writeResendDialogTest();
  sequentialMediaSendTest();
  sequentialMediaDialogTest();
  slowmodeTest();
  slowmodePolicyTest();
  slowmodeNativeTest();
  stabilizationMessagesTest();
  stabilizationNativeTest();
  authSideEffectTest();
  chatCommandsTest();
  chatArchiveStateTest();
  activeStoriesStateTest();
  commandSerializerTest();
  filePipelineTest();
  chatMediaDownloadControllerTest();
  appStoreSessionTest();
  liveChatPermissionsTest();
  groupPermissionPayloadTest();
  forwardSendOwnershipTest();
  forwardMessagesContractTest();
  forwardEligibilityTest();
  forwardSourceActionsTest();
  deleteMessagesSafetyTest();
  editMessagesSafetyTest();
  chatOpenLeaseTest();
  basicGroupAccessTest();
  basicGroupMediaTest();
  supergroupBoostsTest();

  // Infrastructure
  tdGatewayTest();
  nativeReceiveFlowTest();
  eventNormalizerTest();
  eventPipelineTest();

  // Feature use cases
  loadCallsTest();
  loadActiveStoriesTest();
  createPrivateChatTest();
  searchComposeUsersTest();
  importContactTest();
  createBasicGroupChatTest();
  createChannelChatTest();
  useCasesTest();
  downloadMessageMediaTest();

  // DTO / parsing layer
  messageDtoParserTest();
  userDtoTest();

  // UI view models
  chatTimelineVOTest();
  rootTabBarGeometryTest();
  tgComposerMaterialPolicyTest();
  tgVoiceRecordingPolicyTest();
  loadBotMenuTest();
  loadPinnedMessageTest();
  pinnedMessageOwnershipTest();
  emojiKeyboardSearchTest();
  stickerSearchTest();
  gifInlineSearchTest();
  searchChatMessagesTest();
  tgCustomEmojiDraftPolicyTest();
  chatDraftEntitiesTest();
  chatListUnreadBadgeTest();
  mediaGalleryGeometryTransitionTest();
  mediaGalleryStateTest();
  tgPhotoAlbumLayoutTest();
  tgUnicodeEmojiCatalogTest();
  sharedMediaThumbnailCoordinatorTest();
  pendingSharedMediaActionSignalTest();
  chatMembersTest();
  chatPreviewTextTest();
  chatItemVOTest();
  composeContactModelTest();
  composeCreationModelTest();
  tgMediaGalleryPolicyTest();
  replyHydrationCoordinatorTest();
  loadRepliedMessageTest();

  // Text engine
  textEngineTest();

  // Real device V2/session ownership and test-only chat composition fixture
  chatScreenDecompositionTest();
  sendMediaAlbumTest();
  photoAlbumDialogTest();
  photoAttachmentFileIOTest();
  photoSelectionPreviewTest();
  timelineUpdateDataSourceTest();
  timelineUpdateOwnershipTest();
  timelineUpdateNativeTest();
}

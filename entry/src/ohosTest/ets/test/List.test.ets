// Test suite registry — imports and runs all test modules.
// Old service-layer tests (MessagesController, PreferencesService, etc.) removed —
// those modules no longer exist in the current architecture.

import messagesReducerTest from './MessagesReducer.test';
import messageDtoParserTest from './MessageDtoParser.test';
import stateCloneTest from './StateClone.test';
import chatTimelineVOTest from './ChatTimelineVO.test';
import textEngineTest from './TextEngine.test';
import appStateModelsTest from './AppStateModels.test';
import appErrorTest from './AppError.test';
import authSideEffectTest from './AuthSideEffect.test';
import loadCallsTest from './LoadCalls.test';
import chatCommandsTest from './ChatCommands.test';
import commandSerializerTest from './CommandSerializer.test';
import useCasesTest from './UseCases.test';
import downloadMessageMediaTest from './DownloadMessageMedia.test';
import userDtoTest from './UserDto.test';
import filePipelineTest from './FilePipeline.test';
import tdGatewayTest from './TdGateway.test';
import eventNormalizerTest from './EventNormalizer.test';
import rootTabBarGeometryTest from './RootTabBarGeometry.test';
import tgComposerMaterialPolicyTest from './TgComposerMaterialPolicy.test';
import tgVoiceRecordingPolicyTest from './TgVoiceRecordingPolicy.test';
import loadBotMenuTest from './LoadBotMenu.test';
import loadPinnedMessageTest from './LoadPinnedMessage.test';
import emojiKeyboardSearchTest from './EmojiKeyboardSearch.test';
import stickerSearchTest from './StickerSearch.test';
import gifInlineSearchTest from './GifInlineSearch.test';
import chatArchiveStateTest from './ChatArchiveState.test';
import searchChatMessagesTest from './SearchChatMessages.test';
import tgCustomEmojiDraftPolicyTest from './TgCustomEmojiDraftPolicy.test';
import chatDraftEntitiesTest from './ChatDraftEntities.test';
import chatListUnreadBadgeTest from './ChatListUnreadBadge.test';
import mediaGalleryGeometryTransitionTest from './MediaGalleryGeometryTransition.test';
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

export default function testsuite() {
  // Core state management
  messagesReducerTest();
  stateCloneTest();
  appStateModelsTest();
  appErrorTest();
  authSideEffectTest();
  chatCommandsTest();
  chatArchiveStateTest();
  activeStoriesStateTest();
  commandSerializerTest();
  filePipelineTest();

  // Infrastructure
  tdGatewayTest();
  eventNormalizerTest();

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
  emojiKeyboardSearchTest();
  stickerSearchTest();
  gifInlineSearchTest();
  searchChatMessagesTest();
  tgCustomEmojiDraftPolicyTest();
  chatDraftEntitiesTest();
  chatListUnreadBadgeTest();
  mediaGalleryGeometryTransitionTest();
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
}

// TDLib types - main entry point (refactored into modules)
// Re-exports from modular structure

// Common utilities
export {
  TdObject,
  TdValueType,
  TdValueContainer,
  TdFormattedText,
  tdType,
  isTdError,
  getTdErrorCode,
  getTdErrorMessage,
  safeNumber,
  safeString,
  safeBool,
  asRecord,
  tdGetProperty
} from './td/common';

// Media types
export {
  TdFile,
  TdLocalFile,
  TdPhoto,
  TdPhotoSize,
  TdThumbnail,
  TdWebPage,
  TdContact,
  TdLocation,
  TdVenue,
  TdAudioNote,
  TdCallDiscardReason,
  TdCall,
  TdVideo,
  TdAnimation,
  TdDocument,
  TdVoiceNote,
  TdVideoNote,
  TdSticker
} from './td/media';

// Message types
export {
  TdMessageSender,
  TdMessageContent,
  TdMessage,
  TdDraftMessage,
  TdInputMessageText,
  TdReplyTo,
  TdForwardInfo,
  TdMessageOrigin,
  TdSchedulingState,
  TdSelfDestructType,
  TdPollOptionDisplay,
  TdPollOption,
  TdPollType,
  TdPoll,
  TdDice,
  TdMessages
} from './td/messages';

// Chat types
export {
  TdChatPosition,
  TdChatType,
  TdNotificationSettings,
  TdChatAction,
  TdChatPhoto,
  TdChat,
  TdChats,
  TdChatPermissions,
  TdNearbyChat,
  TdChatsNearby,
  TdChatInviteLink,
  TdChatInviteLinks
} from './td/chats';

// User types
export {
  TdUserStatus,
  TdProfilePhoto,
  TdUsernames,
  TdUserType,
  TdUser,
  TdUserFullInfo,
  TdSupergroup,
  TdSupergroupFullInfo,
  TdSupergroupMember,
  TdSupergroupMembers
} from './td/users';

// Update types
export {
  TdUpdateNewChat,
  TdUpdateChatLastMessage,
  TdUpdateChatPosition,
  TdUpdateNewMessage,
  TdUpdateMessageContent,
  TdUpdateChatReadInbox,
  TdUpdateChatNotificationSettings,
  TdUpdateChatAction
} from './td/updates';

// System types
export {
  TdSecretChat,
  TdAutoDownloadSettings,
  TdAutoDownloadSettingsPresets,
  TdPassportAuthorizationForm,
  TdSession,
  TdSessions,
  TdProxyType,
  TdProxy,
  TdProxies,
  TdOk
} from './td/system';
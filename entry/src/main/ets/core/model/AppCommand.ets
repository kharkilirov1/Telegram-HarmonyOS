// Application commands - typed commands to send to TDLib
// These are domain-specific commands that usecases produce

import { ChatId, UserId, MessageId } from './EntityId';

// Base command class
export class AppCommand {
  type: string = '';
}

// Payload classes
export class SetPhoneNumberPayload {
  phoneNumber: string = '';
}

export class CheckAuthCodePayload {
  code: string = '';
}

export class CheckAuthPasswordPayload {
  password: string = '';
}

export class LoadChatsPayload {
  limit: number = 20;
  chatList: 'main' | 'archive' | 'folder' = 'main';
  // Only meaningful for chatList = 'folder' (chatListFolder / chat_folder_id).
  folderId: number = 0;
}

export class OpenChatPayload {
  chatId: ChatId = 0;
}

export class SetTdlibOnlinePayload {
  online: boolean = true;
}

export class CustomEmojiTextEntity {
  offset: number = 0;
  length: number = 0;
  customEmojiId: string = '0'; // TDLib int64 — kept as string to avoid precision loss

  constructor(offset: number = 0, length: number = 0, customEmojiId: string = '0') {
    this.offset = offset;
    this.length = length;
    this.customEmojiId = customEmojiId;
  }
}

export class SendMessagePayload {
  chatId: ChatId = 0;
  text: string = '';
  replyToMessageId: MessageId = '0';
  customEmojiEntities: CustomEmojiTextEntity[] = [];
  // 0 sends immediately; otherwise the scheduled send date in seconds.
  scheduledDateSeconds: number = 0;
}

export class SendMediaMessagePayload {
  chatId: ChatId = 0;
  mediaKind: string = 'document';
  localPath: string = '';
  caption: string = '';
  replyToMessageId: MessageId = '0';
  durationSeconds: number = 0;
  waveformBase64: string = '';
}

export class SendMediaAlbumPayload {
  chatId: ChatId = 0;
  localPaths: string[] = [];
  caption: string = '';
  replyToMessageId: MessageId = '0';
}

export class ViewMessagesPayload {
  chatId: ChatId = 0;
  messageIds: MessageId[] = [];
}

export class GetChatHistoryPayload {
  chatId: ChatId = 0;
  fromMessageId: MessageId = '0';
  offset: number = 0;
  limit: number = 50;
  onlyLocal: boolean = false;
}

export class GetUserPayload {
  userId: UserId = 0;
}

export class CreatePrivateChatPayload {
  userId: UserId = 0;
  force: boolean = false;
}

export class ImportedContactInput {
  phoneNumber: string = '';
  firstName: string = '';
  lastName: string = '';

  constructor(phoneNumber: string = '', firstName: string = '', lastName: string = '') {
    this.phoneNumber = phoneNumber;
    this.firstName = firstName;
    this.lastName = lastName;
  }
}

export class ImportContactsPayload {
  contacts: ImportedContactInput[] = [];
}

export class CreateNewBasicGroupChatPayload {
  userIds: UserId[] = [];
  title: string = '';
  messageAutoDeleteTime: number = 0;
}

export class CreateNewSupergroupChatPayload {
  title: string = '';
  isForum: boolean = false;
  isChannel: boolean = false;
  description: string = '';
  messageAutoDeleteTime: number = 0;
  forImport: boolean = false;
}

export class SearchContactsPayload {
  query: string = '';
  limit: number = 20;
}

export class SearchChatsOnServerPayload {
  query: string = '';
  limit: number = 20;
}

export class SearchPublicChatsPayload {
  query: string = '';
}

export class SearchCallMessagesPayload {
  offset: string = '';
  limit: number = 50;
  onlyMissed: boolean = false;
}

export class GetChatPayload {
  chatId: ChatId = 0;
}

export class GetChatPinnedMessagePayload {
  chatId: ChatId = 0;
}

export class GetRepliedMessagePayload {
  chatId: ChatId = 0;
  messageId: MessageId = '0';
}

export class GetMessagePayload {
  chatId: ChatId = 0;
  messageId: MessageId = '0';
}

export class GetMessagePropertiesPayload {
  chatId: ChatId = 0;
  messageId: MessageId = '0';
}

export class CloseChatPayload {
  chatId: ChatId = 0;
}

export class GetUserFullInfoPayload {
  userId: UserId = 0;
}

export class GetSupergroupFullInfoPayload {
  supergroupId: number = 0;
}

export class GetSupergroupPayload {
  supergroupId: number = 0;
}

export class GetBasicGroupPayload {
  basicGroupId: number = 0;
}

export class GetBasicGroupFullInfoPayload {
  basicGroupId: number = 0;
}

export type ChatMembersFilterKind = 'all' | 'members' | 'administrators';

export class SearchChatMembersPayload {
  chatId: ChatId = 0;
  query: string = '';
  limit: number = 200;
  filterKind: ChatMembersFilterKind = 'all';
}

export class GetSupergroupMembersPayload {
  supergroupId: number = 0;
  offset: number = 0;
  limit: number = 100;
  filterKind: ChatMembersFilterKind = 'all';
}

export class EditMessageEntity {
  offset: number = 0;
  length: number = 0;
  typeJson: string = '';

  constructor(offset: number = 0, length: number = 0, typeJson: string = '') {
    this.offset = offset;
    this.length = length;
    this.typeJson = typeJson;
  }
}

export class EditMessageLinkPreviewOptions {
  isDisabled: boolean = false;
  url: string = '';
  forceSmallMedia: boolean = false;
  forceLargeMedia: boolean = false;
  showAboveText: boolean = false;

  constructor(
    isDisabled: boolean = false,
    url: string = '',
    forceSmallMedia: boolean = false,
    forceLargeMedia: boolean = false,
    showAboveText: boolean = false
  ) {
    this.isDisabled = isDisabled;
    this.url = url;
    this.forceSmallMedia = forceSmallMedia;
    this.forceLargeMedia = forceLargeMedia;
    this.showAboveText = showAboveText;
  }
}

export class EditMessageTextPayload {
  chatId: ChatId = 0;
  messageId: MessageId = '0';
  text: string = '';
  entities: EditMessageEntity[] = [];
  linkPreviewOptions?: EditMessageLinkPreviewOptions;
}

export class EditMessageCaptionPayload {
  chatId: ChatId = 0;
  messageId: MessageId = '0';
  caption: string = '';
  showCaptionAboveMedia: boolean = false;
  entities: EditMessageEntity[] = [];
}

export class DeleteMessagesPayload {
  chatId: ChatId = 0;
  messageIds: MessageId[] = [];
  revoke: boolean = false;
}

export class ForwardMessagesPayload {
  chatId: ChatId = 0;
  fromChatId: ChatId = 0;
  messageIds: MessageId[] = [];
  sendCopy: boolean = false;
  removeCaption: boolean = false;
}

export class SetChatMutePayload {
  chatId: ChatId = 0;
  muteForSeconds: number = 0; // 0 = unmute, >0 = mute duration
}

// setMessageReactions chat_id message_id reaction_types:vector<ReactionType> is_big = Ok
// Reaction types are chip keys ('emoji:👍' / 'custom:<id>') so one string list survives the layer
// boundary; the serializer expands them into the td_api objects.
export class SetMessageReactionsPayload {
  chatId: ChatId = 0;
  messageId: MessageId = '0';
  reactionKeys: string[] = [];
  isBig: boolean = false;
}

export class ToggleChatPinnedPayload {
  chatId: ChatId = 0;
  isPinned: boolean = false;
  chatList: 'main' | 'archive' = 'main';
}

export class AddChatToListPayload {
  chatId: ChatId = 0;
  chatList: 'main' | 'archive' | 'folder' = 'main';
  // Only meaningful for chatList = 'folder' (chatListFolder / chat_folder_id).
  folderId: number = 0;
}

// Folder CRUD (td_api.tl:12054/12057/12060). The chat selection model of iOS is not implemented
// yet: create/edit send the name and the include/exclude flags with empty id vectors.
export class GetChatFolderPayload {
  folderId: number = 0;
}

export class ChatFolderInviteLinkPayload {
  folderId: number = 0;
  inviteLink: string = '';
  name: string = '';
  // Empty means "all chats of the folder"; TDLib reads an empty chat_ids that way.
  chatIds: number[] = [];
}

export class ChatFolderDraftPayload {
  title: string = '';
  excludeMuted: boolean = false;
  excludeRead: boolean = false;
  excludeArchived: boolean = false;
  includeContacts: boolean = false;
  includeNonContacts: boolean = false;
  includeBots: boolean = false;
  includeGroups: boolean = false;
  includeChannels: boolean = false;
  includedChatIds: number[] = [];
}

export class EditChatFolderPayload {
  folderId: number = 0;
  draft: ChatFolderDraftPayload = new ChatFolderDraftPayload();
}

export class DeleteChatFolderPayload {
  folderId: number = 0;
}

export type AutoDownloadNetworkType = 'mobile' | 'mobileRoaming' | 'wifi' | 'other' | 'none';

export class SetAutoDownloadSettingsPayload {
  networkType: AutoDownloadNetworkType = 'wifi';
  isAutoDownloadEnabled: boolean = true;
  maxPhotoFileSize: number = 0;
  maxVideoFileSize: number = 0;
  maxOtherFileSize: number = 0;
  videoUploadBitrate: number = 0;
  preloadLargeVideos: boolean = false;
  preloadNextAudio: boolean = false;
  preloadStories: boolean = false;
  useLessDataForCalls: boolean = false;
}

export class GetStorageStatisticsPayload {
  // Number of chats whose per-chat usage is included (TDLib chat_limit, default 20).
  chatLimit: number = 20;
}

export type BlockListKind = 'main' | 'stories';

export class GetBlockedMessageSendersPayload {
  blockList: BlockListKind = 'main';
  offset: number = 0;
  limit: number = 100;
}

export class SetMessageSenderBlockListPayload {
  senderType: 'user' | 'chat' = 'user';
  // int53 sender id (user_id or chat_id), safe to carry as a number.
  senderId: number = 0;
  // true -> blockListMain, false -> null (unblock).
  blocked: boolean = false;
}

export class TerminateSessionPayload {
  // TDLib session.id is int64: carried as a decimal string to avoid JS precision loss.
  sessionId: string = '0';
}

export class PinChatMessagePayload {
  chatId: ChatId = 0;
  messageId: MessageId = '0';
  disableNotification: boolean = false;
  onlyForSelf: boolean = false;
}

export class UnpinChatMessagePayload {
  chatId: ChatId = 0;
  messageId: MessageId = '0';
}

export class DeleteChatHistoryPayload {
  chatId: ChatId = 0;
  removeFromChatList: boolean = true;
  revoke: boolean = false; // true = delete for everyone (if allowed)
}

export class ToggleChatIsMarkedAsUnreadPayload {
  chatId: ChatId = 0;
  isMarkedAsUnread: boolean = false;
}

export class SearchChatMessagesPayload {
  chatId: ChatId = 0;
  query: string = '';
  fromMessageId: MessageId = '0';
  offset: number = 0;
  limit: number = 100;
  // '' = no filter; else a SearchMessagesFilter suffix like 'PhotoAndVideo'
  filterType: string = '';
}

export class DownloadFilePayload {
  fileId: number = 0;
  priority: number = 1;
  synchronous: boolean = false;
}

export class CancelDownloadFilePayload {
  fileId: number = 0;
  onlyIfPending: boolean = false;
}

export class GetRecentStickersPayload {
  isAttached: boolean = false;
}

export class GetPremiumStickersPayload {
  limit: number = 16;
}

export class GetStickerSetPayload {
  setId: string = '0'; // TDLib int64 — kept as string to avoid precision loss
}

export class GetTrendingCustomEmojiSetsPayload {
  offset: number = 0;
  limit: number = 12;
}

export class SearchEmojisPayload {
  text: string = '';
  inputLanguageCodes: string[] = [];
}

export class SearchCustomEmojiStickersPayload {
  emojis: string = '';
  query: string = '';
  inputLanguageCodes: string[] = [];
  offset: number = 0;
  limit: number = 64;
}

export class SearchRegularStickersPayload {
  emojis: string = '';
  query: string = '';
  inputLanguageCodes: string[] = [];
  offset: number = 0;
  limit: number = 64;
}

export class GetOptionPayload {
  name: string = '';
}

export class SearchPublicChatPayload {
  username: string = '';
}

export class GetInlineQueryResultsPayload {
  botUserId: number = 0;
  chatId: ChatId = 0;
  query: string = '';
  offset: string = '';
}

export class SendInlineQueryResultPayload {
  chatId: ChatId = 0;
  queryId: string = '0'; // TDLib int64 — string avoids JS precision loss
  resultId: string = '';
  hideViaBot: boolean = true;
}

export class SendStickerPayload {
  chatId: ChatId = 0;
  remoteFileId: string = ''; // sticker.file.remote.id → inputFileRemote
  width: number = 0;
  height: number = 0;
  emoji: string = '';
}

export class SendAnimationPayload {
  chatId: ChatId = 0;
  remoteFileId: string = ''; // animation.file.remote.id → inputFileRemote
  duration: number = 0;
  width: number = 0;
  height: number = 0;
}

// Command classes
export class SetPhoneNumberCommand extends AppCommand {
  type: string = 'setPhoneNumber';
  payload: SetPhoneNumberPayload = new SetPhoneNumberPayload();
}

export class CheckAuthCodeCommand extends AppCommand {
  type: string = 'checkAuthCode';
  payload: CheckAuthCodePayload = new CheckAuthCodePayload();
}

export class CheckAuthPasswordCommand extends AppCommand {
  type: string = 'checkAuthPassword';
  payload: CheckAuthPasswordPayload = new CheckAuthPasswordPayload();
}

export class RequestPasswordRecoveryCommand extends AppCommand {
  type: string = 'requestPasswordRecovery';
}

export class ResendAuthCodeCommand extends AppCommand {
  type: string = 'resendAuthCode';
}

export class LoadChatsCommand extends AppCommand {
  type: string = 'loadChats';
  payload: LoadChatsPayload = new LoadChatsPayload();
}

export class LoadActiveStoriesCommand extends AppCommand {
  type: string = 'loadActiveStories';
}

export class OpenChatCommand extends AppCommand {
  type: string = 'openChat';
  payload: OpenChatPayload = new OpenChatPayload();
}

// Telegram delivers volatile updates (typing actions, user statuses) only to
// sessions that declared themselves online via the TDLib 'online' option
export class SetTdlibOnlineCommand extends AppCommand {
  type: string = 'setTdlibOnline';
  payload: SetTdlibOnlinePayload = new SetTdlibOnlinePayload();
}

export class SendMessageCommand extends AppCommand {
  type: string = 'sendMessage';
  payload: SendMessagePayload = new SendMessagePayload();
}

export class SendMediaMessageCommand extends AppCommand {
  type: string = 'sendMediaMessage';
  payload: SendMediaMessagePayload = new SendMediaMessagePayload();
}

export class SendMediaAlbumCommand extends AppCommand {
  type: string = 'sendMediaAlbum';
  payload: SendMediaAlbumPayload = new SendMediaAlbumPayload();
}

export class ViewMessagesCommand extends AppCommand {
  type: string = 'viewMessages';
  payload: ViewMessagesPayload = new ViewMessagesPayload();
}

export class GetChatHistoryCommand extends AppCommand {
  type: string = 'getChatHistory';
  payload: GetChatHistoryPayload = new GetChatHistoryPayload();
}

export class GetUserCommand extends AppCommand {
  type: string = 'getUser';
  payload: GetUserPayload = new GetUserPayload();
}

export class CreatePrivateChatCommand extends AppCommand {
  type: string = 'createPrivateChat';
  payload: CreatePrivateChatPayload = new CreatePrivateChatPayload();
}

export class ImportContactsCommand extends AppCommand {
  type: string = 'importContacts';
  payload: ImportContactsPayload = new ImportContactsPayload();
}

export class CreateNewBasicGroupChatCommand extends AppCommand {
  type: string = 'createNewBasicGroupChat';
  payload: CreateNewBasicGroupChatPayload = new CreateNewBasicGroupChatPayload();
}

export class CreateNewSupergroupChatCommand extends AppCommand {
  type: string = 'createNewSupergroupChat';
  payload: CreateNewSupergroupChatPayload = new CreateNewSupergroupChatPayload();
}

export class SearchContactsCommand extends AppCommand {
  type: string = 'searchContacts';
  payload: SearchContactsPayload = new SearchContactsPayload();
}

export class SearchChatsOnServerCommand extends AppCommand {
  type: string = 'searchChatsOnServer';
  payload: SearchChatsOnServerPayload = new SearchChatsOnServerPayload();
}

export class SearchPublicChatsCommand extends AppCommand {
  type: string = 'searchPublicChats';
  payload: SearchPublicChatsPayload = new SearchPublicChatsPayload();
}

export class SearchCallMessagesCommand extends AppCommand {
  type: string = 'searchCallMessages';
  payload: SearchCallMessagesPayload = new SearchCallMessagesPayload();
}

export class GetChatCommand extends AppCommand {
  type: string = 'getChat';
  payload: GetChatPayload = new GetChatPayload();
}

export class GetChatPinnedMessageCommand extends AppCommand {
  type: string = 'getChatPinnedMessage';
  payload: GetChatPinnedMessagePayload = new GetChatPinnedMessagePayload();
}

export class GetMessageCommand extends AppCommand {
  type: string = 'getMessage';
  payload: GetMessagePayload = new GetMessagePayload();
}

export class GetMessagePropertiesCommand extends AppCommand {
  type: string = 'getMessageProperties';
  payload: GetMessagePropertiesPayload = new GetMessagePropertiesPayload();
}

export class GetRepliedMessageCommand extends AppCommand {
  type: string = 'getRepliedMessage';
  payload: GetRepliedMessagePayload = new GetRepliedMessagePayload();
}

export class CloseChatCommand extends AppCommand {
  type: string = 'closeChat';
  payload: CloseChatPayload = new CloseChatPayload();
}

export class GetUserFullInfoCommand extends AppCommand {
  type: string = 'getUserFullInfo';
  payload: GetUserFullInfoPayload = new GetUserFullInfoPayload();
}

export class GetSupergroupFullInfoCommand extends AppCommand {
  type: string = 'getSupergroupFullInfo';
  payload: GetSupergroupFullInfoPayload = new GetSupergroupFullInfoPayload();
}

export class GetSupergroupCommand extends AppCommand {
  type: string = 'getSupergroup';
  payload: GetSupergroupPayload = new GetSupergroupPayload();
}

export class GetBasicGroupCommand extends AppCommand {
  type: string = 'getBasicGroup';
  payload: GetBasicGroupPayload = new GetBasicGroupPayload();
}

export class GetBasicGroupFullInfoCommand extends AppCommand {
  type: string = 'getBasicGroupFullInfo';
  payload: GetBasicGroupFullInfoPayload = new GetBasicGroupFullInfoPayload();
}

export class SearchChatMembersCommand extends AppCommand {
  type: string = 'searchChatMembers';
  payload: SearchChatMembersPayload = new SearchChatMembersPayload();
}

export class GetSupergroupMembersCommand extends AppCommand {
  type: string = 'getSupergroupMembers';
  payload: GetSupergroupMembersPayload = new GetSupergroupMembersPayload();
}

export class EditMessageTextCommand extends AppCommand {
  type: string = 'editMessageText';
  payload: EditMessageTextPayload = new EditMessageTextPayload();
}

export class EditMessageCaptionCommand extends AppCommand {
  type: string = 'editMessageCaption';
  payload: EditMessageCaptionPayload = new EditMessageCaptionPayload();
}

export class DeleteMessagesCommand extends AppCommand {
  type: string = 'deleteMessages';
  payload: DeleteMessagesPayload = new DeleteMessagesPayload();
}

export class ForwardMessagesCommand extends AppCommand {
  type: string = 'forwardMessages';
  payload: ForwardMessagesPayload = new ForwardMessagesPayload();
}

export class SetChatMuteCommand extends AppCommand {
  type: string = 'setChatMute';
  payload: SetChatMutePayload = new SetChatMutePayload();
}

// getMessageAvailableReactions chat_id:int53 message_id:int53 row_size:int32 = AvailableReactions
// (td_api.tl:11597) — the per-message picker list, refreshed by updateActiveEmojiReactions etc.
export class GetMessageAvailableReactionsPayload {
  chatId: ChatId = 0;
  messageId: MessageId = '0';
  rowSize: number = 12;
}

export class GetMessageAvailableReactionsCommand extends AppCommand {
  type: string = 'getMessageAvailableReactions';
  payload: GetMessageAvailableReactionsPayload = new GetMessageAvailableReactionsPayload();
}

export class SetMessageReactionsCommand extends AppCommand {
  type: string = 'setMessageReactions';
  payload: SetMessageReactionsPayload = new SetMessageReactionsPayload();
}

export class ReportChatPayload {
  chatId: ChatId = 0;
  // Base64 option id returned by TDLib; empty for the first (option list) request.
  optionId: string = '';
  text: string = '';
  // Messages selected for a report whose reason requires them (td_api.tl:14338).
  messageIds: number[] = [];
}

export class LeaveChatPayload {
  chatId: ChatId = 0;
}

export class ShareContactPayload {
  chatId: ChatId = 0;
  phoneNumber: string = '';
  firstName: string = '';
  lastName: string = '';
  userId: number = 0;
}

export class JoinChatPayload {
  chatId: ChatId = 0; // TDLib joinChat takes the chat id (chat_id:int53)
}

export class ReportChatCommand extends AppCommand {
  type: string = 'reportChat';
  payload: ReportChatPayload = new ReportChatPayload();
}

export class LeaveChatCommand extends AppCommand {
  type: string = 'leaveChat';
  payload: LeaveChatPayload = new LeaveChatPayload();
}

export class ShareContactCommand extends AppCommand {
  type: string = 'sendContactMessage';
  payload: ShareContactPayload = new ShareContactPayload();
}

export class JoinChatCommand extends AppCommand {
  type: string = 'joinChat';
  payload: JoinChatPayload = new JoinChatPayload();
}

export class ToggleChatPinnedCommand extends AppCommand {
  type: string = 'toggleChatIsPinned';
  payload: ToggleChatPinnedPayload = new ToggleChatPinnedPayload();
}

export class AddChatToListCommand extends AppCommand {
  type: string = 'addChatToList';
  payload: AddChatToListPayload = new AddChatToListPayload();
}

export class ChatFolderInviteLinkRequestPayload {
  inviteLink: string = '';
  chatIds: number[] = [];
}

export class GetChatScheduledMessagesPayload {
  chatId: ChatId = 0;
}

export class GetChatScheduledMessagesCommand extends AppCommand {
  type: string = 'getChatScheduledMessages';
  payload: GetChatScheduledMessagesPayload = new GetChatScheduledMessagesPayload();
}

export class EditMessageSchedulingStatePayload {
  chatId: ChatId = 0;
  messageId: MessageId = '0';
  // 0 sends the message immediately; otherwise the scheduled send date.
  scheduledDateSeconds: number = 0;
}

export class EditMessageSchedulingStateCommand extends AppCommand {
  type: string = 'editMessageSchedulingState';
  payload: EditMessageSchedulingStatePayload = new EditMessageSchedulingStatePayload();
}

export class SetChatMessageAutoDeleteTimePayload {
  chatId: ChatId = 0;
  // Seconds; 0 disables the timer. TDLib validates the upper bound itself.
  seconds: number = 0;
}

export class SetChatMessageAutoDeleteTimeCommand extends AppCommand {
  type: string = 'setChatMessageAutoDeleteTime';
  payload: SetChatMessageAutoDeleteTimePayload = new SetChatMessageAutoDeleteTimePayload();
}

export class SetChatPermissionsPayload {
  chatId: ChatId = 0;
  // The full chatPermissions object; the screen edits single bits but writes the whole object back.
  permissionsJson: string = '';
}

export class SetChatPermissionsCommand extends AppCommand {
  type: string = 'setChatPermissions';
  payload: SetChatPermissionsPayload = new SetChatPermissionsPayload();
}

export class GetChatAdministratorsPayload {
  chatId: ChatId = 0;
}

export class GetChatAdministratorsCommand extends AppCommand {
  type: string = 'getChatAdministrators';
  payload: GetChatAdministratorsPayload = new GetChatAdministratorsPayload();
}

export class CreateChatInviteLinkPayload {
  chatId: ChatId = 0;
  name: string = '';
  expirationDate: number = 0;
  memberLimit: number = 0;
  createsJoinRequest: boolean = false;
}

export class CreateChatInviteLinkCommand extends AppCommand {
  type: string = 'createChatInviteLink';
  payload: CreateChatInviteLinkPayload = new CreateChatInviteLinkPayload();
}

export class RevokeChatInviteLinkPayload {
  chatId: ChatId = 0;
  inviteLink: string = '';
}

export class RevokeChatInviteLinkCommand extends AppCommand {
  type: string = 'revokeChatInviteLink';
  payload: RevokeChatInviteLinkPayload = new RevokeChatInviteLinkPayload();
}

export class GetChatInviteLinksPayload {
  chatId: ChatId = 0;
  // 0 = links created by anyone (the primary link included), otherwise only that creator's.
  creatorUserId: number = 0;
  isRevoked: boolean = false;
  offsetDate: number = 0;
  offsetInviteLink: string = '';
  limit: number = 50;
}

export class GetChatInviteLinksCommand extends AppCommand {
  type: string = 'getChatInviteLinks';
  payload: GetChatInviteLinksPayload = new GetChatInviteLinksPayload();
}

export class GetChatMemberPayload {
  chatId: ChatId = 0;
  userId: UserId = 0;
}

export class GetChatMemberCommand extends AppCommand {
  type: string = 'getChatMember';
  payload: GetChatMemberPayload = new GetChatMemberPayload();
}

export class ChatInviteLinkRequestPayload {
  inviteLink: string = '';
}

export class CheckChatInviteLinkCommand extends AppCommand {
  type: string = 'checkChatInviteLink';
  payload: ChatInviteLinkRequestPayload = new ChatInviteLinkRequestPayload();
}

export class JoinChatByInviteLinkCommand extends AppCommand {
  type: string = 'joinChatByInviteLink';
  payload: ChatInviteLinkRequestPayload = new ChatInviteLinkRequestPayload();
}

export class CheckChatFolderInviteLinkCommand extends AppCommand {
  type: string = 'checkChatFolderInviteLink';
  payload: ChatFolderInviteLinkRequestPayload = new ChatFolderInviteLinkRequestPayload();
}

export class AddChatFolderByInviteLinkCommand extends AppCommand {
  type: string = 'addChatFolderByInviteLink';
  payload: ChatFolderInviteLinkRequestPayload = new ChatFolderInviteLinkRequestPayload();
}

export class GetRecommendedChatFoldersCommand extends AppCommand {
  type: string = 'getRecommendedChatFolders';
}

export class GetChatFolderInviteLinksCommand extends AppCommand {
  type: string = 'getChatFolderInviteLinks';
  payload: ChatFolderInviteLinkPayload = new ChatFolderInviteLinkPayload();
}

export class CreateChatFolderInviteLinkCommand extends AppCommand {
  type: string = 'createChatFolderInviteLink';
  payload: ChatFolderInviteLinkPayload = new ChatFolderInviteLinkPayload();
}

export class EditChatFolderInviteLinkCommand extends AppCommand {
  type: string = 'editChatFolderInviteLink';
  payload: ChatFolderInviteLinkPayload = new ChatFolderInviteLinkPayload();
}

export class DeleteChatFolderInviteLinkCommand extends AppCommand {
  type: string = 'deleteChatFolderInviteLink';
  payload: ChatFolderInviteLinkPayload = new ChatFolderInviteLinkPayload();
}

export class GetChatFolderCommand extends AppCommand {
  type: string = 'getChatFolder';
  payload: GetChatFolderPayload = new GetChatFolderPayload();
}

export class CreateChatFolderCommand extends AppCommand {
  type: string = 'createChatFolder';
  payload: ChatFolderDraftPayload = new ChatFolderDraftPayload();
}

export class EditChatFolderCommand extends AppCommand {
  type: string = 'editChatFolder';
  payload: EditChatFolderPayload = new EditChatFolderPayload();
}

export class DeleteChatFolderCommand extends AppCommand {
  type: string = 'deleteChatFolder';
  payload: DeleteChatFolderPayload = new DeleteChatFolderPayload();
}

export class GetAutoDownloadSettingsPresetsCommand extends AppCommand {
  type: string = 'getAutoDownloadSettingsPresets';
}

export class SetAutoDownloadSettingsCommand extends AppCommand {
  type: string = 'setAutoDownloadSettings';
  payload: SetAutoDownloadSettingsPayload = new SetAutoDownloadSettingsPayload();
}

export class GetStorageStatisticsCommand extends AppCommand {
  type: string = 'getStorageStatistics';
  payload: GetStorageStatisticsPayload = new GetStorageStatisticsPayload();
}

export class GetStorageStatisticsFastCommand extends AppCommand {
  type: string = 'getStorageStatisticsFast';
}

export class OptimizeStoragePayload {
  // -1 means "use the TDLib default" for each limit; 0 for the clear-cache case.
  size: number = 0;
  ttl: number = 0;
  count: number = 0;
  immunityDelay: number = 0;
}

export class OptimizeStorageCommand extends AppCommand {
  // "Clear cache": size/ttl/count 0 means remove every cache file TDLib is allowed to drop.
  type: string = 'optimizeStorage';
  payload: OptimizeStoragePayload = new OptimizeStoragePayload();
}

export class GetBlockedMessageSendersCommand extends AppCommand {
  type: string = 'getBlockedMessageSenders';
  payload: GetBlockedMessageSendersPayload = new GetBlockedMessageSendersPayload();
}

export class SetMessageSenderBlockListCommand extends AppCommand {
  type: string = 'setMessageSenderBlockList';
  payload: SetMessageSenderBlockListPayload = new SetMessageSenderBlockListPayload();
}

export class GetActiveSessionsCommand extends AppCommand {
  type: string = 'getActiveSessions';
}

export class TerminateAllOtherSessionsCommand extends AppCommand {
  type: string = 'terminateAllOtherSessions';
}

export class TerminateSessionCommand extends AppCommand {
  type: string = 'terminateSession';
  payload: TerminateSessionPayload = new TerminateSessionPayload();
}

export class PinChatMessageCommand extends AppCommand {
  type: string = 'pinChatMessage';
  payload: PinChatMessagePayload = new PinChatMessagePayload();
}

export class UnpinChatMessageCommand extends AppCommand {
  type: string = 'unpinChatMessage';
  payload: UnpinChatMessagePayload = new UnpinChatMessagePayload();
}

export class DeleteChatHistoryCommand extends AppCommand {
  type: string = 'deleteChatHistory';
  payload: DeleteChatHistoryPayload = new DeleteChatHistoryPayload();
}

export class ToggleChatIsMarkedAsUnreadCommand extends AppCommand {
  type: string = 'toggleChatIsMarkedAsUnread';
  payload: ToggleChatIsMarkedAsUnreadPayload = new ToggleChatIsMarkedAsUnreadPayload();
}

export class SearchChatMessagesCommand extends AppCommand {
  type: string = 'searchChatMessages';
  payload: SearchChatMessagesPayload = new SearchChatMessagesPayload();
}

export class SetChatDraftPayload {
  chatId: ChatId = 0;
  text: string = '';
  replyToMessageId: MessageId = '0';
  customEmojiEntities: CustomEmojiTextEntity[] = [];
}

export class SetChatDraftCommand extends AppCommand {
  type: string = 'setChatDraft';
  payload: SetChatDraftPayload = new SetChatDraftPayload();
}

export class DownloadFileCommand extends AppCommand {
  type: string = 'downloadFile';
  payload: DownloadFilePayload = new DownloadFilePayload();
}

export class CancelDownloadFileCommand extends AppCommand {
  type: string = 'cancelDownloadFile';
  payload: CancelDownloadFilePayload = new CancelDownloadFilePayload();
}

export class GetRecentStickersCommand extends AppCommand {
  type: string = 'getRecentStickers';
  payload: GetRecentStickersPayload = new GetRecentStickersPayload();
}

export class GetFavoriteStickersCommand extends AppCommand {
  type: string = 'getFavoriteStickers';
}

export class GetPremiumStickersCommand extends AppCommand {
  type: string = 'getPremiumStickers';
  payload: GetPremiumStickersPayload = new GetPremiumStickersPayload();
}

export class GetInstalledStickerSetsCommand extends AppCommand {
  type: string = 'getInstalledStickerSets';
}

export class GetInstalledCustomEmojiSetsCommand extends AppCommand {
  type: string = 'getInstalledCustomEmojiSets';
}

export class GetTrendingCustomEmojiSetsCommand extends AppCommand {
  type: string = 'getTrendingCustomEmojiSets';
  payload: GetTrendingCustomEmojiSetsPayload = new GetTrendingCustomEmojiSetsPayload();
}

export class SearchEmojisCommand extends AppCommand {
  type: string = 'searchEmojis';
  payload: SearchEmojisPayload = new SearchEmojisPayload();
}

export class SearchCustomEmojiStickersCommand extends AppCommand {
  type: string = 'searchCustomEmojiStickers';
  payload: SearchCustomEmojiStickersPayload = new SearchCustomEmojiStickersPayload();
}

export class SearchRegularStickersCommand extends AppCommand {
  type: string = 'searchRegularStickers';
  payload: SearchRegularStickersPayload = new SearchRegularStickersPayload();
}

export class GetOptionCommand extends AppCommand {
  type: string = 'getOption';
  payload: GetOptionPayload = new GetOptionPayload();
}

export class SearchPublicChatCommand extends AppCommand {
  type: string = 'searchPublicChat';
  payload: SearchPublicChatPayload = new SearchPublicChatPayload();
}

export class GetInlineQueryResultsCommand extends AppCommand {
  type: string = 'getInlineQueryResults';
  payload: GetInlineQueryResultsPayload = new GetInlineQueryResultsPayload();
}

export class SendInlineQueryResultCommand extends AppCommand {
  type: string = 'sendInlineQueryResult';
  payload: SendInlineQueryResultPayload = new SendInlineQueryResultPayload();
}

export class GetStickerSetCommand extends AppCommand {
  type: string = 'getStickerSet';
  payload: GetStickerSetPayload = new GetStickerSetPayload();
}

export class SendStickerCommand extends AppCommand {
  type: string = 'sendSticker';
  payload: SendStickerPayload = new SendStickerPayload();
}

export class GetSavedAnimationsCommand extends AppCommand {
  type: string = 'getSavedAnimations';
}

export class SendAnimationCommand extends AppCommand {
  type: string = 'sendAnimation';
  payload: SendAnimationPayload = new SendAnimationPayload();
}

export class RequestQrCodeAuthCommand extends AppCommand {
  type: string = 'requestQrCodeAuth';
}

export class LogoutCommand extends AppCommand {
  type: string = 'logout';
}

// Unified type for all commands
export type AnyAppCommand =
  | SetPhoneNumberCommand
  | CheckAuthCodeCommand
  | CheckAuthPasswordCommand
  | RequestPasswordRecoveryCommand
  | ResendAuthCodeCommand
  | LoadChatsCommand
  | LoadActiveStoriesCommand
  | OpenChatCommand
  | SetTdlibOnlineCommand
  | SendMessageCommand
  | SendMediaMessageCommand
  | SendMediaAlbumCommand
  | ViewMessagesCommand
  | GetChatHistoryCommand
  | GetUserCommand
  | CreatePrivateChatCommand
  | ImportContactsCommand
  | CreateNewBasicGroupChatCommand
  | CreateNewSupergroupChatCommand
  | SearchContactsCommand
  | SearchChatsOnServerCommand
  | SearchPublicChatsCommand
  | SearchCallMessagesCommand
  | GetChatCommand
  | GetMessageCommand
  | GetMessagePropertiesCommand
  | GetChatPinnedMessageCommand
  | GetRepliedMessageCommand
  | CloseChatCommand
  | GetUserFullInfoCommand
  | GetSupergroupCommand
  | GetBasicGroupCommand
  | GetSupergroupFullInfoCommand
  | GetBasicGroupFullInfoCommand
  | SearchChatMembersCommand
  | GetSupergroupMembersCommand
  | EditMessageTextCommand
  | EditMessageCaptionCommand
  | DeleteMessagesCommand
  | ForwardMessagesCommand
  | SetChatMuteCommand
  | GetMessageAvailableReactionsCommand
  | SetMessageReactionsCommand
  | ReportChatCommand
  | LeaveChatCommand
  | ShareContactCommand
  | JoinChatCommand
  | ToggleChatPinnedCommand
  | AddChatToListCommand
  | CheckChatInviteLinkCommand
  | JoinChatByInviteLinkCommand
  | CheckChatFolderInviteLinkCommand
  | AddChatFolderByInviteLinkCommand
  | SetChatMessageAutoDeleteTimeCommand
  | GetChatScheduledMessagesCommand
  | EditMessageSchedulingStateCommand
  | SetChatPermissionsCommand
  | GetChatAdministratorsCommand
  | CreateChatInviteLinkCommand
  | RevokeChatInviteLinkCommand
  | GetChatInviteLinksCommand
  | GetChatMemberCommand
  | GetRecommendedChatFoldersCommand
  | GetChatFolderInviteLinksCommand
  | CreateChatFolderInviteLinkCommand
  | EditChatFolderInviteLinkCommand
  | DeleteChatFolderInviteLinkCommand
  | GetChatFolderCommand
  | CreateChatFolderCommand
  | EditChatFolderCommand
  | DeleteChatFolderCommand
  | GetAutoDownloadSettingsPresetsCommand
  | SetAutoDownloadSettingsCommand
  | GetStorageStatisticsCommand
  | GetStorageStatisticsFastCommand
  | OptimizeStorageCommand
  | GetBlockedMessageSendersCommand
  | SetMessageSenderBlockListCommand
  | GetActiveSessionsCommand
  | TerminateAllOtherSessionsCommand
  | TerminateSessionCommand
  | PinChatMessageCommand
  | UnpinChatMessageCommand
  | DeleteChatHistoryCommand
  | ToggleChatIsMarkedAsUnreadCommand
  | SearchChatMessagesCommand
  | SetChatDraftCommand
  | DownloadFileCommand
  | CancelDownloadFileCommand
  | GetRecentStickersCommand
  | GetFavoriteStickersCommand
  | GetPremiumStickersCommand
  | GetInstalledStickerSetsCommand
  | GetInstalledCustomEmojiSetsCommand
  | GetTrendingCustomEmojiSetsCommand
  | SearchEmojisCommand
  | SearchCustomEmojiStickersCommand
  | SearchRegularStickersCommand
  | GetOptionCommand
  | SearchPublicChatCommand
  | GetInlineQueryResultsCommand
  | SendInlineQueryResultCommand
  | GetStickerSetCommand
  | SendStickerCommand
  | GetSavedAnimationsCommand
  | SendAnimationCommand
  | RequestQrCodeAuthCommand
  | LogoutCommand;

// Helper functions to create commands
export function createSetPhoneNumberCommand(phoneNumber: string): SetPhoneNumberCommand {
  const cmd = new SetPhoneNumberCommand();
  cmd.payload.phoneNumber = phoneNumber;
  return cmd;
}

export function createCheckAuthCodeCommand(code: string): CheckAuthCodeCommand {
  const cmd = new CheckAuthCodeCommand();
  cmd.payload.code = code;
  return cmd;
}

export function createCheckAuthPasswordCommand(password: string): CheckAuthPasswordCommand {
  const cmd = new CheckAuthPasswordCommand();
  cmd.payload.password = password;
  return cmd;
}

export function createRequestPasswordRecoveryCommand(): RequestPasswordRecoveryCommand {
  return new RequestPasswordRecoveryCommand();
}

export function createResendAuthCodeCommand(): ResendAuthCodeCommand {
  return new ResendAuthCodeCommand();
}

export function createLoadChatsCommand(
  limit: number = 20,
  chatList: 'main' | 'archive' | 'folder' = 'main',
  folderId: number = 0
): LoadChatsCommand {
  const cmd = new LoadChatsCommand();
  cmd.payload.limit = limit;
  cmd.payload.chatList = chatList;
  cmd.payload.folderId = folderId;
  return cmd;
}

export function createLoadActiveStoriesCommand(): LoadActiveStoriesCommand {
  return new LoadActiveStoriesCommand();
}

export function createOpenChatCommand(chatId: ChatId): OpenChatCommand {
  const cmd = new OpenChatCommand();
  cmd.payload.chatId = chatId;
  return cmd;
}

export function createSetTdlibOnlineCommand(online: boolean): SetTdlibOnlineCommand {
  const cmd = new SetTdlibOnlineCommand();
  cmd.payload.online = online;
  return cmd;
}

export function createSendMessageCommand(
  chatId: ChatId,
  text: string,
  replyToMessageId?: MessageId,
  customEmojiEntities: CustomEmojiTextEntity[] = []
): SendMessageCommand {
  const cmd = new SendMessageCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.text = text;
  cmd.payload.replyToMessageId = replyToMessageId || '0';
  cmd.payload.customEmojiEntities = customEmojiEntities;
  return cmd;
}

export function createSendMediaMessageCommand(
  chatId: ChatId,
  mediaKind: string,
  localPath: string,
  caption: string = '',
  replyToMessageId?: MessageId,
  durationSeconds: number = 0,
  waveformBase64: string = ''
): SendMediaMessageCommand {
  const cmd = new SendMediaMessageCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.mediaKind = mediaKind;
  cmd.payload.localPath = localPath;
  cmd.payload.caption = caption;
  cmd.payload.replyToMessageId = replyToMessageId || '0';
  cmd.payload.durationSeconds = durationSeconds;
  cmd.payload.waveformBase64 = waveformBase64;
  return cmd;
}

export function createSendMediaAlbumCommand(
  chatId: ChatId,
  localPaths: string[],
  caption: string = '',
  replyToMessageId: MessageId = '0'
): SendMediaAlbumCommand {
  const cmd = new SendMediaAlbumCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.localPaths = localPaths.slice();
  cmd.payload.caption = caption;
  cmd.payload.replyToMessageId = replyToMessageId;
  return cmd;
}

export function createViewMessagesCommand(chatId: ChatId, messageIds: MessageId[]): ViewMessagesCommand {
  const cmd = new ViewMessagesCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.messageIds = messageIds;
  return cmd;
}

export function createGetChatHistoryCommand(
  chatId: ChatId,
  fromMessageId: MessageId = '0',
  offset: number = 0,
  limit: number = 50,
  onlyLocal: boolean = false
): GetChatHistoryCommand {
  const cmd = new GetChatHistoryCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.fromMessageId = fromMessageId;
  cmd.payload.offset = offset;
  cmd.payload.limit = limit;
  cmd.payload.onlyLocal = onlyLocal;
  return cmd;
}

export function createGetUserCommand(userId: UserId): GetUserCommand {
  const cmd = new GetUserCommand();
  cmd.payload.userId = userId;
  return cmd;
}

export function createPrivateChatCommand(
  userId: UserId,
  force: boolean = false
): CreatePrivateChatCommand {
  const cmd = new CreatePrivateChatCommand();
  cmd.payload.userId = userId;
  cmd.payload.force = force;
  return cmd;
}

export function createImportContactsCommand(contacts: ImportedContactInput[]): ImportContactsCommand {
  const cmd = new ImportContactsCommand();
  cmd.payload.contacts = contacts;
  return cmd;
}

export function createNewBasicGroupChatCommand(
  userIds: UserId[],
  title: string,
  messageAutoDeleteTime: number = 0
): CreateNewBasicGroupChatCommand {
  const cmd = new CreateNewBasicGroupChatCommand();
  cmd.payload.userIds = userIds;
  cmd.payload.title = title;
  cmd.payload.messageAutoDeleteTime = messageAutoDeleteTime;
  return cmd;
}

export function createNewSupergroupChatCommand(
  title: string,
  isForum: boolean,
  isChannel: boolean,
  description: string = '',
  messageAutoDeleteTime: number = 0,
  forImport: boolean = false
): CreateNewSupergroupChatCommand {
  const cmd = new CreateNewSupergroupChatCommand();
  cmd.payload.title = title;
  cmd.payload.isForum = isForum;
  cmd.payload.isChannel = isChannel;
  cmd.payload.description = description;
  cmd.payload.messageAutoDeleteTime = messageAutoDeleteTime;
  cmd.payload.forImport = forImport;
  return cmd;
}

export function createSearchContactsCommand(
  query: string,
  limit: number = 20
): SearchContactsCommand {
  const cmd = new SearchContactsCommand();
  cmd.payload.query = query;
  cmd.payload.limit = limit;
  return cmd;
}

export function createSearchChatsOnServerCommand(
  query: string,
  limit: number = 20
): SearchChatsOnServerCommand {
  const cmd = new SearchChatsOnServerCommand();
  cmd.payload.query = query;
  cmd.payload.limit = limit;
  return cmd;
}

export function createSearchPublicChatsCommand(query: string): SearchPublicChatsCommand {
  const cmd = new SearchPublicChatsCommand();
  cmd.payload.query = query;
  return cmd;
}

export function createSearchCallMessagesCommand(
  offset: string = '',
  limit: number = 50,
  onlyMissed: boolean = false
): SearchCallMessagesCommand {
  const cmd = new SearchCallMessagesCommand();
  cmd.payload.offset = offset;
  cmd.payload.limit = limit;
  cmd.payload.onlyMissed = onlyMissed;
  return cmd;
}

export function createGetChatCommand(chatId: ChatId): GetChatCommand {
  const cmd = new GetChatCommand();
  cmd.payload.chatId = chatId;
  return cmd;
}

export function createGetMessageCommand(chatId: ChatId, messageId: MessageId): GetMessageCommand {
  const cmd = new GetMessageCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.messageId = messageId;
  return cmd;
}

export function createGetMessagePropertiesCommand(chatId: ChatId, messageId: MessageId): GetMessagePropertiesCommand {
  const cmd = new GetMessagePropertiesCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.messageId = messageId;
  return cmd;
}

export function createGetChatPinnedMessageCommand(chatId: ChatId): GetChatPinnedMessageCommand {
  const cmd = new GetChatPinnedMessageCommand();
  cmd.payload.chatId = chatId;
  return cmd;
}

export function createGetRepliedMessageCommand(
  chatId: ChatId,
  messageId: MessageId
): GetRepliedMessageCommand {
  const cmd = new GetRepliedMessageCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.messageId = messageId;
  return cmd;
}

export function createCloseChatCommand(chatId: ChatId): CloseChatCommand {
  const cmd = new CloseChatCommand();
  cmd.payload.chatId = chatId;
  return cmd;
}

export function createGetUserFullInfoCommand(userId: UserId): GetUserFullInfoCommand {
  const cmd = new GetUserFullInfoCommand();
  cmd.payload.userId = userId;
  return cmd;
}

export function createGetSupergroupFullInfoCommand(supergroupId: number): GetSupergroupFullInfoCommand {
  const cmd = new GetSupergroupFullInfoCommand();
  cmd.payload.supergroupId = supergroupId;
  return cmd;
}

export function createGetSupergroupCommand(supergroupId: number): GetSupergroupCommand {
  const cmd = new GetSupergroupCommand();
  cmd.payload.supergroupId = supergroupId;
  return cmd;
}

export function createGetBasicGroupCommand(basicGroupId: number): GetBasicGroupCommand {
  const cmd = new GetBasicGroupCommand();
  cmd.payload.basicGroupId = basicGroupId;
  return cmd;
}

export function createGetBasicGroupFullInfoCommand(basicGroupId: number): GetBasicGroupFullInfoCommand {
  const cmd = new GetBasicGroupFullInfoCommand();
  cmd.payload.basicGroupId = basicGroupId;
  return cmd;
}

export function createSearchChatMembersCommand(
  chatId: ChatId,
  query: string = '',
  limit: number = 200,
  filterKind: ChatMembersFilterKind = 'all'
): SearchChatMembersCommand {
  const cmd = new SearchChatMembersCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.query = query;
  cmd.payload.limit = Math.max(1, Math.min(limit, 200));
  cmd.payload.filterKind = filterKind;
  return cmd;
}

export function createGetSupergroupMembersCommand(
  supergroupId: number,
  offset: number = 0,
  limit: number = 100,
  filterKind: ChatMembersFilterKind = 'all'
): GetSupergroupMembersCommand {
  const cmd = new GetSupergroupMembersCommand();
  cmd.payload.supergroupId = supergroupId;
  cmd.payload.offset = Math.max(0, offset);
  cmd.payload.limit = Math.max(1, Math.min(limit, 200));
  cmd.payload.filterKind = filterKind;
  return cmd;
}

export function createEditMessageTextCommand(
  chatId: ChatId,
  messageId: MessageId,
  text: string,
  entities: EditMessageEntity[] = [],
  linkPreviewOptions?: EditMessageLinkPreviewOptions
): EditMessageTextCommand {
  const cmd = new EditMessageTextCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.messageId = messageId;
  cmd.payload.text = text;
  cmd.payload.entities = entities.map((entity: EditMessageEntity) =>
    new EditMessageEntity(entity.offset, entity.length, entity.typeJson));
  if (linkPreviewOptions !== undefined) {
    cmd.payload.linkPreviewOptions = new EditMessageLinkPreviewOptions(
      linkPreviewOptions.isDisabled, linkPreviewOptions.url, linkPreviewOptions.forceSmallMedia,
      linkPreviewOptions.forceLargeMedia, linkPreviewOptions.showAboveText
    );
  }
  return cmd;
}

export function createEditMessageCaptionCommand(
  chatId: ChatId,
  messageId: MessageId,
  caption: string,
  showCaptionAboveMedia: boolean,
  entities: EditMessageEntity[] = []
): EditMessageCaptionCommand {
  const cmd = new EditMessageCaptionCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.messageId = messageId;
  cmd.payload.caption = caption;
  cmd.payload.showCaptionAboveMedia = showCaptionAboveMedia;
  cmd.payload.entities = entities.map((entity: EditMessageEntity) =>
    new EditMessageEntity(entity.offset, entity.length, entity.typeJson));
  return cmd;
}

export function createDeleteMessagesCommand(
  chatId: ChatId,
  messageIds: MessageId[],
  revoke: boolean = false
): DeleteMessagesCommand {
  const cmd = new DeleteMessagesCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.messageIds = messageIds;
  cmd.payload.revoke = revoke;
  return cmd;
}

export function createForwardMessagesCommand(
  chatId: ChatId,
  fromChatId: ChatId,
  messageIds: MessageId[],
  sendCopy: boolean = false,
  removeCaption: boolean = false
): ForwardMessagesCommand {
  const cmd = new ForwardMessagesCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.fromChatId = fromChatId;
  cmd.payload.messageIds = messageIds;
  cmd.payload.sendCopy = sendCopy;
  cmd.payload.removeCaption = removeCaption;
  return cmd;
}

export function createSetChatMuteCommand(chatId: ChatId, muteForSeconds: number): SetChatMuteCommand {
  const cmd = new SetChatMuteCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.muteForSeconds = muteForSeconds;
  return cmd;
}

export function createGetMessageAvailableReactionsCommand(chatId: ChatId, messageId: MessageId,
  rowSize: number): GetMessageAvailableReactionsCommand {
  const cmd = new GetMessageAvailableReactionsCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.messageId = messageId;
  cmd.payload.rowSize = rowSize;
  return cmd;
}

export function createSetMessageReactionsCommand(chatId: ChatId, messageId: MessageId,
  reactionKeys: string[]): SetMessageReactionsCommand {
  const cmd = new SetMessageReactionsCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.messageId = messageId;
  cmd.payload.reactionKeys = reactionKeys.slice();
  return cmd;
}

export function createReportChatCommand(payload: ReportChatPayload): ReportChatCommand {
  const cmd = new ReportChatCommand();
  cmd.payload = payload;
  return cmd;
}

export function createLeaveChatCommand(chatId: ChatId): LeaveChatCommand {
  const cmd = new LeaveChatCommand();
  cmd.payload.chatId = chatId;
  return cmd;
}

export function createShareContactCommand(payload: ShareContactPayload): ShareContactCommand {
  const cmd = new ShareContactCommand();
  cmd.payload = payload;
  return cmd;
}

export function createJoinChatCommand(chatId: ChatId): JoinChatCommand {
  const cmd = new JoinChatCommand();
  cmd.payload.chatId = chatId;
  return cmd;
}

export function createToggleChatPinnedCommand(
  chatId: ChatId,
  isPinned: boolean,
  chatList: 'main' | 'archive' = 'main'
): ToggleChatPinnedCommand {
  const cmd = new ToggleChatPinnedCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.isPinned = isPinned;
  cmd.payload.chatList = chatList;
  return cmd;
}

export function createAddChatToListCommand(
  chatId: ChatId,
  chatList: 'main' | 'archive' | 'folder',
  folderId: number = 0
): AddChatToListCommand {
  const cmd = new AddChatToListCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.chatList = chatList;
  cmd.payload.folderId = folderId;
  return cmd;
}

export function createCheckChatInviteLinkCommand(inviteLink: string): CheckChatInviteLinkCommand {
  const cmd = new CheckChatInviteLinkCommand();
  cmd.payload.inviteLink = inviteLink;
  return cmd;
}

export function createJoinChatByInviteLinkCommand(inviteLink: string): JoinChatByInviteLinkCommand {
  const cmd = new JoinChatByInviteLinkCommand();
  cmd.payload.inviteLink = inviteLink;
  return cmd;
}

export function createCheckChatFolderInviteLinkCommand(inviteLink: string): CheckChatFolderInviteLinkCommand {
  const cmd = new CheckChatFolderInviteLinkCommand();
  cmd.payload.inviteLink = inviteLink;
  return cmd;
}

export function createAddChatFolderByInviteLinkCommand(
  inviteLink: string,
  chatIds: number[]
): AddChatFolderByInviteLinkCommand {
  const cmd = new AddChatFolderByInviteLinkCommand();
  cmd.payload.inviteLink = inviteLink;
  cmd.payload.chatIds = chatIds;
  return cmd;
}

export function createGetChatScheduledMessagesCommand(chatId: ChatId): GetChatScheduledMessagesCommand {
  const cmd = new GetChatScheduledMessagesCommand();
  cmd.payload.chatId = chatId;
  return cmd;
}

export function createEditMessageSchedulingStateCommand(chatId: ChatId, messageId: MessageId,
  scheduledDateSeconds: number): EditMessageSchedulingStateCommand {
  const cmd = new EditMessageSchedulingStateCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.messageId = messageId;
  cmd.payload.scheduledDateSeconds = scheduledDateSeconds;
  return cmd;
}

export function createSetChatMessageAutoDeleteTimeCommand(chatId: ChatId,
  seconds: number): SetChatMessageAutoDeleteTimeCommand {
  const cmd = new SetChatMessageAutoDeleteTimeCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.seconds = seconds;
  return cmd;
}

export function createSetChatPermissionsCommand(chatId: ChatId,
  permissionsJson: string): SetChatPermissionsCommand {
  const cmd = new SetChatPermissionsCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.permissionsJson = permissionsJson;
  return cmd;
}

export function createGetChatAdministratorsCommand(chatId: ChatId): GetChatAdministratorsCommand {
  const cmd = new GetChatAdministratorsCommand();
  cmd.payload.chatId = chatId;
  return cmd;
}

export function createCreateChatInviteLinkCommand(chatId: ChatId, name: string): CreateChatInviteLinkCommand {
  const cmd = new CreateChatInviteLinkCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.name = name;
  return cmd;
}

export function createRevokeChatInviteLinkCommand(chatId: ChatId,
  inviteLink: string): RevokeChatInviteLinkCommand {
  const cmd = new RevokeChatInviteLinkCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.inviteLink = inviteLink;
  return cmd;
}

export function createGetChatInviteLinksCommand(chatId: ChatId): GetChatInviteLinksCommand {
  const cmd = new GetChatInviteLinksCommand();
  cmd.payload.chatId = chatId;
  return cmd;
}

export function createGetChatMemberCommand(chatId: ChatId, userId: UserId): GetChatMemberCommand {
  const cmd = new GetChatMemberCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.userId = userId;
  return cmd;
}

export function createGetRecommendedChatFoldersCommand(): GetRecommendedChatFoldersCommand {
  return new GetRecommendedChatFoldersCommand();
}

export function createGetChatFolderInviteLinksCommand(folderId: number): GetChatFolderInviteLinksCommand {
  const cmd = new GetChatFolderInviteLinksCommand();
  cmd.payload.folderId = folderId;
  return cmd;
}

export function createCreateChatFolderInviteLinkCommand(
  folderId: number,
  name: string,
  chatIds: number[] = []
): CreateChatFolderInviteLinkCommand {
  const cmd = new CreateChatFolderInviteLinkCommand();
  cmd.payload.folderId = folderId;
  cmd.payload.name = name;
  cmd.payload.chatIds = chatIds;
  return cmd;
}

export function createEditChatFolderInviteLinkCommand(
  folderId: number,
  inviteLink: string,
  name: string,
  chatIds: number[] = []
): EditChatFolderInviteLinkCommand {
  const cmd = new EditChatFolderInviteLinkCommand();
  cmd.payload.folderId = folderId;
  cmd.payload.inviteLink = inviteLink;
  cmd.payload.name = name;
  cmd.payload.chatIds = chatIds;
  return cmd;
}

export function createDeleteChatFolderInviteLinkCommand(
  folderId: number,
  inviteLink: string
): DeleteChatFolderInviteLinkCommand {
  const cmd = new DeleteChatFolderInviteLinkCommand();
  cmd.payload.folderId = folderId;
  cmd.payload.inviteLink = inviteLink;
  return cmd;
}

export function createGetChatFolderCommand(folderId: number): GetChatFolderCommand {
  const cmd = new GetChatFolderCommand();
  cmd.payload.folderId = folderId;
  return cmd;
}

export function createChatFolderCommand(draft: ChatFolderDraftPayload): CreateChatFolderCommand {
  const cmd = new CreateChatFolderCommand();
  cmd.payload = draft;
  return cmd;
}

export function createEditChatFolderCommand(
  folderId: number,
  draft: ChatFolderDraftPayload
): EditChatFolderCommand {
  const cmd = new EditChatFolderCommand();
  cmd.payload.folderId = folderId;
  cmd.payload.draft = draft;
  return cmd;
}

export function createDeleteChatFolderCommand(folderId: number): DeleteChatFolderCommand {
  const cmd = new DeleteChatFolderCommand();
  cmd.payload.folderId = folderId;
  return cmd;
}

export function createGetAutoDownloadSettingsPresetsCommand(): GetAutoDownloadSettingsPresetsCommand {
  return new GetAutoDownloadSettingsPresetsCommand();
}

export function createSetAutoDownloadSettingsCommand(
  payload: SetAutoDownloadSettingsPayload
): SetAutoDownloadSettingsCommand {
  const cmd = new SetAutoDownloadSettingsCommand();
  cmd.payload = payload;
  return cmd;
}

export function createGetStorageStatisticsCommand(chatLimit: number = 20): GetStorageStatisticsCommand {
  const cmd = new GetStorageStatisticsCommand();
  cmd.payload.chatLimit = chatLimit;
  return cmd;
}

export function createGetStorageStatisticsFastCommand(): GetStorageStatisticsFastCommand {
  return new GetStorageStatisticsFastCommand();
}

export function createOptimizeStorageCommand(payload?: OptimizeStoragePayload): OptimizeStorageCommand {
  const cmd = new OptimizeStorageCommand();
  if (payload !== undefined) {
    cmd.payload = payload;
  }
  return cmd;
}

export function createGetBlockedMessageSendersCommand(
  blockList: BlockListKind = 'main',
  offset: number = 0,
  limit: number = 100
): GetBlockedMessageSendersCommand {
  const cmd = new GetBlockedMessageSendersCommand();
  cmd.payload.blockList = blockList;
  cmd.payload.offset = offset;
  cmd.payload.limit = limit;
  return cmd;
}

export function createSetMessageSenderBlockListCommand(
  senderType: 'user' | 'chat',
  senderId: number,
  blocked: boolean
): SetMessageSenderBlockListCommand {
  const cmd = new SetMessageSenderBlockListCommand();
  cmd.payload.senderType = senderType;
  cmd.payload.senderId = senderId;
  cmd.payload.blocked = blocked;
  return cmd;
}

export function createGetActiveSessionsCommand(): GetActiveSessionsCommand {
  return new GetActiveSessionsCommand();
}

export function createTerminateAllOtherSessionsCommand(): TerminateAllOtherSessionsCommand {
  return new TerminateAllOtherSessionsCommand();
}

export function createTerminateSessionCommand(sessionId: string): TerminateSessionCommand {
  const cmd = new TerminateSessionCommand();
  cmd.payload.sessionId = sessionId;
  return cmd;
}

export function createPinChatMessageCommand(
  chatId: ChatId, messageId: MessageId,
  disableNotification: boolean = false, onlyForSelf: boolean = false
): PinChatMessageCommand {
  const cmd = new PinChatMessageCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.messageId = messageId;
  cmd.payload.disableNotification = disableNotification;
  cmd.payload.onlyForSelf = onlyForSelf;
  return cmd;
}

export function createUnpinChatMessageCommand(chatId: ChatId, messageId: MessageId): UnpinChatMessageCommand {
  const cmd = new UnpinChatMessageCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.messageId = messageId;
  return cmd;
}

export function createDeleteChatHistoryCommand(
  chatId: ChatId, removeFromChatList: boolean = true, revoke: boolean = false
): DeleteChatHistoryCommand {
  const cmd = new DeleteChatHistoryCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.removeFromChatList = removeFromChatList;
  cmd.payload.revoke = revoke;
  return cmd;
}

export function createToggleChatIsMarkedAsUnreadCommand(
  chatId: ChatId, isMarkedAsUnread: boolean
): ToggleChatIsMarkedAsUnreadCommand {
  const cmd = new ToggleChatIsMarkedAsUnreadCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.isMarkedAsUnread = isMarkedAsUnread;
  return cmd;
}

export function createSearchChatMessagesCommand(
  chatId: ChatId,
  query: string,
  fromMessageId: MessageId = '0',
  offset: number = 0,
  limit: number = 100
): SearchChatMessagesCommand {
  const cmd = new SearchChatMessagesCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.query = query;
  cmd.payload.fromMessageId = fromMessageId;
  cmd.payload.offset = offset;
  cmd.payload.limit = limit;
  return cmd;
}

export function createSetChatDraftCommand(
  chatId: ChatId,
  text: string,
  replyToMessageId: MessageId = '0',
  customEmojiEntities: CustomEmojiTextEntity[] = []
): SetChatDraftCommand {
  const cmd = new SetChatDraftCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.text = text;
  cmd.payload.replyToMessageId = replyToMessageId;
  cmd.payload.customEmojiEntities = customEmojiEntities;
  return cmd;
}

export function createDownloadFileCommand(
  fileId: number,
  priority: number = 1,
  synchronous: boolean = false
): DownloadFileCommand {
  const cmd = new DownloadFileCommand();
  cmd.payload.fileId = fileId;
  cmd.payload.priority = priority;
  cmd.payload.synchronous = synchronous;
  return cmd;
}

export function createCancelDownloadFileCommand(
  fileId: number,
  onlyIfPending: boolean = false
): CancelDownloadFileCommand {
  const cmd = new CancelDownloadFileCommand();
  cmd.payload.fileId = fileId;
  cmd.payload.onlyIfPending = onlyIfPending;
  return cmd;
}

export function createLogoutCommand(): LogoutCommand {
  return new LogoutCommand();
}

export function createGetRecentStickersCommand(isAttached: boolean = false): GetRecentStickersCommand {
  const cmd = new GetRecentStickersCommand();
  cmd.payload.isAttached = isAttached;
  return cmd;
}

export function createGetFavoriteStickersCommand(): GetFavoriteStickersCommand {
  return new GetFavoriteStickersCommand();
}

export function createGetPremiumStickersCommand(limit: number = 16): GetPremiumStickersCommand {
  const cmd = new GetPremiumStickersCommand();
  cmd.payload.limit = limit;
  return cmd;
}

export function createGetInstalledCustomEmojiSetsCommand(): GetInstalledCustomEmojiSetsCommand {
  return new GetInstalledCustomEmojiSetsCommand();
}

export function createGetTrendingCustomEmojiSetsCommand(
  offset: number = 0,
  limit: number = 12
): GetTrendingCustomEmojiSetsCommand {
  const cmd = new GetTrendingCustomEmojiSetsCommand();
  cmd.payload.offset = offset;
  cmd.payload.limit = limit;
  return cmd;
}

export function createSearchEmojisCommand(
  text: string,
  inputLanguageCodes: string[] = []
): SearchEmojisCommand {
  const cmd = new SearchEmojisCommand();
  cmd.payload.text = text;
  cmd.payload.inputLanguageCodes = inputLanguageCodes;
  return cmd;
}

export function createSearchCustomEmojiStickersCommand(
  query: string,
  inputLanguageCodes: string[] = [],
  emojis: string = '',
  offset: number = 0,
  limit: number = 64
): SearchCustomEmojiStickersCommand {
  const cmd = new SearchCustomEmojiStickersCommand();
  cmd.payload.emojis = emojis;
  cmd.payload.query = query;
  cmd.payload.inputLanguageCodes = inputLanguageCodes;
  cmd.payload.offset = offset;
  cmd.payload.limit = limit;
  return cmd;
}

export function createSearchRegularStickersCommand(
  query: string,
  inputLanguageCodes: string[] = [],
  emojis: string = '',
  offset: number = 0,
  limit: number = 64
): SearchRegularStickersCommand {
  const cmd = new SearchRegularStickersCommand();
  cmd.payload.emojis = emojis;
  cmd.payload.query = query;
  cmd.payload.inputLanguageCodes = inputLanguageCodes;
  cmd.payload.offset = offset;
  cmd.payload.limit = limit;
  return cmd;
}

export function createGetOptionCommand(name: string): GetOptionCommand {
  const cmd = new GetOptionCommand();
  cmd.payload.name = name;
  return cmd;
}

export function createSearchPublicChatCommand(username: string): SearchPublicChatCommand {
  const cmd = new SearchPublicChatCommand();
  cmd.payload.username = username;
  return cmd;
}

export function createGetInlineQueryResultsCommand(
  botUserId: number,
  chatId: ChatId,
  query: string,
  offset: string = ''
): GetInlineQueryResultsCommand {
  const cmd = new GetInlineQueryResultsCommand();
  cmd.payload.botUserId = botUserId;
  cmd.payload.chatId = chatId;
  cmd.payload.query = query;
  cmd.payload.offset = offset;
  return cmd;
}

export function createSendInlineQueryResultCommand(
  chatId: ChatId,
  queryId: string,
  resultId: string,
  hideViaBot: boolean = true
): SendInlineQueryResultCommand {
  const cmd = new SendInlineQueryResultCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.queryId = queryId;
  cmd.payload.resultId = resultId;
  cmd.payload.hideViaBot = hideViaBot;
  return cmd;
}

export function createGetStickerSetCommand(setId: string): GetStickerSetCommand {
  const cmd = new GetStickerSetCommand();
  cmd.payload.setId = setId;
  return cmd;
}

export function createSendStickerCommand(
  chatId: ChatId,
  remoteFileId: string,
  width: number,
  height: number,
  emoji: string
): SendStickerCommand {
  const cmd = new SendStickerCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.remoteFileId = remoteFileId;
  cmd.payload.width = width;
  cmd.payload.height = height;
  cmd.payload.emoji = emoji;
  return cmd;
}

export function createSendAnimationCommand(
  chatId: ChatId,
  remoteFileId: string,
  duration: number,
  width: number,
  height: number
): SendAnimationCommand {
  const cmd = new SendAnimationCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.remoteFileId = remoteFileId;
  cmd.payload.duration = duration;
  cmd.payload.width = width;
  cmd.payload.height = height;
  return cmd;
}

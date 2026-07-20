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
  chatList: 'main' | 'archive' = 'main';
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

export class CloseChatPayload {
  chatId: ChatId = 0;
}

export class GetUserFullInfoPayload {
  userId: UserId = 0;
}

export class GetSupergroupFullInfoPayload {
  supergroupId: number = 0;
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

export class EditMessageTextPayload {
  chatId: ChatId = 0;
  messageId: MessageId = '0';
  text: string = '';
}

export class DeleteMessagesPayload {
  chatId: ChatId = 0;
  messageIds: MessageId[] = [];
  revoke: boolean = true;
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

export class ToggleChatPinnedPayload {
  chatId: ChatId = 0;
  isPinned: boolean = false;
  chatList: 'main' | 'archive' = 'main';
}

export class AddChatToListPayload {
  chatId: ChatId = 0;
  chatList: 'main' | 'archive' = 'main';
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

export class ToggleChatPinnedCommand extends AppCommand {
  type: string = 'toggleChatIsPinned';
  payload: ToggleChatPinnedPayload = new ToggleChatPinnedPayload();
}

export class AddChatToListCommand extends AppCommand {
  type: string = 'addChatToList';
  payload: AddChatToListPayload = new AddChatToListPayload();
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
  | GetChatPinnedMessageCommand
  | GetRepliedMessageCommand
  | CloseChatCommand
  | GetUserFullInfoCommand
  | GetSupergroupFullInfoCommand
  | SearchChatMembersCommand
  | GetSupergroupMembersCommand
  | EditMessageTextCommand
  | DeleteMessagesCommand
  | ForwardMessagesCommand
  | SetChatMuteCommand
  | ToggleChatPinnedCommand
  | AddChatToListCommand
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
  chatList: 'main' | 'archive' = 'main'
): LoadChatsCommand {
  const cmd = new LoadChatsCommand();
  cmd.payload.limit = limit;
  cmd.payload.chatList = chatList;
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
  text: string
): EditMessageTextCommand {
  const cmd = new EditMessageTextCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.messageId = messageId;
  cmd.payload.text = text;
  return cmd;
}

export function createDeleteMessagesCommand(
  chatId: ChatId,
  messageIds: MessageId[],
  revoke: boolean = true
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
  chatList: 'main' | 'archive'
): AddChatToListCommand {
  const cmd = new AddChatToListCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.chatList = chatList;
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

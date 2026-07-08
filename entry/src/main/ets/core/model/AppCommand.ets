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
}

export class OpenChatPayload {
  chatId: ChatId = 0;
}

export class SendMessagePayload {
  chatId: ChatId = 0;
  text: string = '';
  replyToMessageId: MessageId = '0';
}

export class SendMediaMessagePayload {
  chatId: ChatId = 0;
  mediaKind: string = 'document';
  localPath: string = '';
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

export class SearchCallMessagesPayload {
  offset: string = '';
  limit: number = 50;
  onlyMissed: boolean = false;
}

export class GetChatPayload {
  chatId: ChatId = 0;
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

export class GetStickerSetPayload {
  setId: string = '0'; // TDLib int64 — kept as string to avoid precision loss
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

export class OpenChatCommand extends AppCommand {
  type: string = 'openChat';
  payload: OpenChatPayload = new OpenChatPayload();
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

export class SearchCallMessagesCommand extends AppCommand {
  type: string = 'searchCallMessages';
  payload: SearchCallMessagesPayload = new SearchCallMessagesPayload();
}

export class GetChatCommand extends AppCommand {
  type: string = 'getChat';
  payload: GetChatPayload = new GetChatPayload();
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

export class GetInstalledStickerSetsCommand extends AppCommand {
  type: string = 'getInstalledStickerSets';
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
  | OpenChatCommand
  | SendMessageCommand
  | SendMediaMessageCommand
  | ViewMessagesCommand
  | GetChatHistoryCommand
  | GetUserCommand
  | SearchCallMessagesCommand
  | GetChatCommand
  | CloseChatCommand
  | GetUserFullInfoCommand
  | GetSupergroupFullInfoCommand
  | EditMessageTextCommand
  | DeleteMessagesCommand
  | ForwardMessagesCommand
  | SetChatMuteCommand
  | ToggleChatPinnedCommand
  | PinChatMessageCommand
  | UnpinChatMessageCommand
  | DeleteChatHistoryCommand
  | ToggleChatIsMarkedAsUnreadCommand
  | SearchChatMessagesCommand
  | DownloadFileCommand
  | CancelDownloadFileCommand
  | GetRecentStickersCommand
  | GetInstalledStickerSetsCommand
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

export function createLoadChatsCommand(limit: number = 20): LoadChatsCommand {
  const cmd = new LoadChatsCommand();
  cmd.payload.limit = limit;
  return cmd;
}

export function createOpenChatCommand(chatId: ChatId): OpenChatCommand {
  const cmd = new OpenChatCommand();
  cmd.payload.chatId = chatId;
  return cmd;
}

export function createSendMessageCommand(
  chatId: ChatId,
  text: string,
  replyToMessageId?: MessageId
): SendMessageCommand {
  const cmd = new SendMessageCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.text = text;
  cmd.payload.replyToMessageId = replyToMessageId || '0';
  return cmd;
}

export function createSendMediaMessageCommand(
  chatId: ChatId,
  mediaKind: string,
  localPath: string,
  caption: string = '',
  replyToMessageId?: MessageId
): SendMediaMessageCommand {
  const cmd = new SendMediaMessageCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.mediaKind = mediaKind;
  cmd.payload.localPath = localPath;
  cmd.payload.caption = caption;
  cmd.payload.replyToMessageId = replyToMessageId || '0';
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

export function createToggleChatPinnedCommand(chatId: ChatId, isPinned: boolean): ToggleChatPinnedCommand {
  const cmd = new ToggleChatPinnedCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.isPinned = isPinned;
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

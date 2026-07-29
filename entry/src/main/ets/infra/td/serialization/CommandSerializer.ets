// CommandSerializer — преобразует AnyAppCommand → TdObject для TdGateway.send()
//
// Возвращает объект с method (строка) и params (TdObject).
// TdGateway.send(method, params) отправляет запрос в TDLib.

import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  AnyAppCommand,
  SetPhoneNumberCommand,
  CheckAuthCodeCommand,
  CheckAuthPasswordCommand,
  LoadChatsCommand,
  LoadActiveStoriesCommand,
  OpenChatCommand,
  SendMessageCommand,
  SendMediaMessageCommand,
  EditMessageTextCommand,
  DeleteMessagesCommand,
  ForwardMessagesCommand,
  SetChatMuteCommand,
  ToggleChatPinnedCommand,
  AddChatToListCommand,
  PinChatMessageCommand,
  UnpinChatMessageCommand,
  DeleteChatHistoryCommand,
  ToggleChatIsMarkedAsUnreadCommand,
  SearchChatMessagesCommand,
  SetChatDraftCommand,
  ViewMessagesCommand,
  GetChatHistoryCommand,
  GetUserCommand,
  CreatePrivateChatCommand,
  ImportContactsCommand,
  ImportedContactInput,
  CreateNewBasicGroupChatCommand,
  CreateNewSupergroupChatCommand,
  SearchContactsCommand,
  SearchChatsOnServerCommand,
  SearchPublicChatsCommand,
  SearchCallMessagesCommand,
  GetChatCommand,
  GetChatPinnedMessageCommand,
  GetRepliedMessageCommand,
  CloseChatCommand,
  SetTdlibOnlineCommand,
  GetUserFullInfoCommand,
  GetSupergroupFullInfoCommand,
  GetBasicGroupFullInfoCommand,
  SearchChatMembersCommand,
  GetSupergroupMembersCommand,
  DownloadFileCommand,
  CancelDownloadFileCommand,
  GetRecentStickersCommand,
  GetPremiumStickersCommand,
  GetTrendingCustomEmojiSetsCommand,
  CustomEmojiTextEntity,
  SearchEmojisCommand,
  SearchCustomEmojiStickersCommand,
  SearchRegularStickersCommand,
  GetOptionCommand,
  SearchPublicChatCommand,
  GetInlineQueryResultsCommand,
  SendInlineQueryResultCommand,
  GetStickerSetCommand,
  SendStickerCommand,
  SendAnimationCommand
} from '../../../core/model/AppCommand';
import { TdObject } from '../../../models/TdTypes';

const TAG = 'CommandSerializer';
const DOMAIN = 0x000C;

type CommandSerializationHandler = (command: AnyAppCommand, result: SerializedCommand) => void;

/**
 * Результат сериализации команды.
 */
export class SerializedCommand {
  method: string = '';
  params: TdObject = new TdObject();
}

const COMMAND_SERIALIZATION_HANDLERS: Map<string, CommandSerializationHandler> = new Map<string, CommandSerializationHandler>();
COMMAND_SERIALIZATION_HANDLERS.set('setPhoneNumber', serializeSetPhoneNumber);
COMMAND_SERIALIZATION_HANDLERS.set('checkAuthCode', serializeCheckAuthCode);
COMMAND_SERIALIZATION_HANDLERS.set('checkAuthPassword', serializeCheckAuthPassword);
COMMAND_SERIALIZATION_HANDLERS.set('requestPasswordRecovery', serializeRequestPasswordRecovery);
COMMAND_SERIALIZATION_HANDLERS.set('resendAuthCode', serializeResendAuthCode);
COMMAND_SERIALIZATION_HANDLERS.set('loadChats', serializeLoadChats);
COMMAND_SERIALIZATION_HANDLERS.set('loadActiveStories', serializeLoadActiveStories);
COMMAND_SERIALIZATION_HANDLERS.set('openChat', serializeOpenChat);
COMMAND_SERIALIZATION_HANDLERS.set('sendMessage', serializeSendMessage);
COMMAND_SERIALIZATION_HANDLERS.set('sendMediaMessage', serializeSendMediaMessage);
COMMAND_SERIALIZATION_HANDLERS.set('editMessageText', serializeEditMessageText);
COMMAND_SERIALIZATION_HANDLERS.set('deleteMessages', serializeDeleteMessages);
COMMAND_SERIALIZATION_HANDLERS.set('forwardMessages', serializeForwardMessages);
COMMAND_SERIALIZATION_HANDLERS.set('setChatMute', serializeSetChatMute);
COMMAND_SERIALIZATION_HANDLERS.set('toggleChatIsPinned', serializeToggleChatIsPinned);
COMMAND_SERIALIZATION_HANDLERS.set('addChatToList', serializeAddChatToList);
COMMAND_SERIALIZATION_HANDLERS.set('pinChatMessage', serializePinChatMessage);
COMMAND_SERIALIZATION_HANDLERS.set('unpinChatMessage', serializeUnpinChatMessage);
COMMAND_SERIALIZATION_HANDLERS.set('deleteChatHistory', serializeDeleteChatHistory);
COMMAND_SERIALIZATION_HANDLERS.set('toggleChatIsMarkedAsUnread', serializeToggleChatIsMarkedAsUnread);
COMMAND_SERIALIZATION_HANDLERS.set('searchChatMessages', serializeSearchChatMessages);
COMMAND_SERIALIZATION_HANDLERS.set('setChatDraft', serializeSetChatDraft);
COMMAND_SERIALIZATION_HANDLERS.set('viewMessages', serializeViewMessages);
COMMAND_SERIALIZATION_HANDLERS.set('getChatHistory', serializeGetChatHistory);
COMMAND_SERIALIZATION_HANDLERS.set('getUser', serializeGetUser);
COMMAND_SERIALIZATION_HANDLERS.set('createPrivateChat', serializeCreatePrivateChat);
COMMAND_SERIALIZATION_HANDLERS.set('importContacts', serializeImportContacts);
COMMAND_SERIALIZATION_HANDLERS.set('createNewBasicGroupChat', serializeCreateNewBasicGroupChat);
COMMAND_SERIALIZATION_HANDLERS.set('createNewSupergroupChat', serializeCreateNewSupergroupChat);
COMMAND_SERIALIZATION_HANDLERS.set('searchContacts', serializeSearchContacts);
COMMAND_SERIALIZATION_HANDLERS.set('searchChatsOnServer', serializeSearchChatsOnServer);
COMMAND_SERIALIZATION_HANDLERS.set('searchPublicChats', serializeSearchPublicChats);
COMMAND_SERIALIZATION_HANDLERS.set('searchCallMessages', serializeSearchCallMessages);
COMMAND_SERIALIZATION_HANDLERS.set('getChat', serializeGetChat);
COMMAND_SERIALIZATION_HANDLERS.set('getChatPinnedMessage', serializeGetChatPinnedMessage);
COMMAND_SERIALIZATION_HANDLERS.set('getRepliedMessage', serializeGetRepliedMessage);
COMMAND_SERIALIZATION_HANDLERS.set('closeChat', serializeCloseChat);
COMMAND_SERIALIZATION_HANDLERS.set('setTdlibOnline', serializeSetTdlibOnline);
COMMAND_SERIALIZATION_HANDLERS.set('getUserFullInfo', serializeGetUserFullInfo);
COMMAND_SERIALIZATION_HANDLERS.set('getSupergroupFullInfo', serializeGetSupergroupFullInfo);
COMMAND_SERIALIZATION_HANDLERS.set('getBasicGroupFullInfo', serializeGetBasicGroupFullInfo);
COMMAND_SERIALIZATION_HANDLERS.set('searchChatMembers', serializeSearchChatMembers);
COMMAND_SERIALIZATION_HANDLERS.set('getSupergroupMembers', serializeGetSupergroupMembers);
COMMAND_SERIALIZATION_HANDLERS.set('downloadFile', serializeDownloadFile);
COMMAND_SERIALIZATION_HANDLERS.set('cancelDownloadFile', serializeCancelDownloadFile);
COMMAND_SERIALIZATION_HANDLERS.set('getRecentStickers', serializeGetRecentStickers);
COMMAND_SERIALIZATION_HANDLERS.set('getFavoriteStickers', serializeGetFavoriteStickers);
COMMAND_SERIALIZATION_HANDLERS.set('getPremiumStickers', serializeGetPremiumStickers);
COMMAND_SERIALIZATION_HANDLERS.set('getInstalledStickerSets', serializeGetInstalledStickerSets);
COMMAND_SERIALIZATION_HANDLERS.set('getInstalledCustomEmojiSets', serializeGetInstalledCustomEmojiSets);
COMMAND_SERIALIZATION_HANDLERS.set('getTrendingCustomEmojiSets', serializeGetTrendingCustomEmojiSets);
COMMAND_SERIALIZATION_HANDLERS.set('searchEmojis', serializeSearchEmojis);
COMMAND_SERIALIZATION_HANDLERS.set('searchCustomEmojiStickers', serializeSearchCustomEmojiStickers);
COMMAND_SERIALIZATION_HANDLERS.set('searchRegularStickers', serializeSearchRegularStickers);
COMMAND_SERIALIZATION_HANDLERS.set('getOption', serializeGetOption);
COMMAND_SERIALIZATION_HANDLERS.set('searchPublicChat', serializeSearchPublicChat);
COMMAND_SERIALIZATION_HANDLERS.set('getInlineQueryResults', serializeGetInlineQueryResults);
COMMAND_SERIALIZATION_HANDLERS.set('sendInlineQueryResult', serializeSendInlineQueryResult);
COMMAND_SERIALIZATION_HANDLERS.set('getStickerSet', serializeGetStickerSet);
COMMAND_SERIALIZATION_HANDLERS.set('sendSticker', serializeSendSticker);
COMMAND_SERIALIZATION_HANDLERS.set('getSavedAnimations', serializeGetSavedAnimations);
COMMAND_SERIALIZATION_HANDLERS.set('sendAnimation', serializeSendAnimation);
COMMAND_SERIALIZATION_HANDLERS.set('requestQrCodeAuth', serializeRequestQrCodeAuth);
COMMAND_SERIALIZATION_HANDLERS.set('logout', serializeLogout);

/**
 * Сериализует AnyAppCommand в TDLib запрос.
 *
 * @param command - команда из use case
 * @returns SerializedCommand с method и params
 */
export function serializeCommand(command: AnyAppCommand): SerializedCommand {
  const result = new SerializedCommand();
  const handler = COMMAND_SERIALIZATION_HANDLERS.get(command.type);
  if (handler === undefined) {
    hilog.warn(DOMAIN, TAG, 'Unknown command type: %{public}s', command.type);
    return result;
  }

  handler(command, result);
  return result;
}

function serializeSetPhoneNumber(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as SetPhoneNumberCommand;
  result.method = 'setAuthenticationPhoneNumber';
  result.params.setString('phone_number', cmd.payload.phoneNumber);
  // TelegramX reference: PhoneNumberAuthenticationSettings (via _*_json pattern)
  const settingsJson = '{"@type":"phoneNumberAuthenticationSettings",'
    + '"allow_flash_call":false,'
    + '"allow_missed_call":true,'
    + '"is_current_phone_number":false,'
    + '"allow_sms_retriever_api":false,'
    + '"has_unknown_phone_number":false}';
  result.params.setString('_settings_json', settingsJson);
}

function serializeCheckAuthCode(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as CheckAuthCodeCommand;
  result.method = 'checkAuthenticationCode';
  result.params.setString('code', cmd.payload.code);
}

function serializeCheckAuthPassword(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as CheckAuthPasswordCommand;
  result.method = 'checkAuthenticationPassword';
  result.params.setString('password', cmd.payload.password);
}

function serializeRequestPasswordRecovery(_command: AnyAppCommand, result: SerializedCommand): void {
  result.method = 'requestAuthenticationPasswordRecovery';
}

function serializeResendAuthCode(_command: AnyAppCommand, result: SerializedCommand): void {
  result.method = 'resendAuthenticationCode';
}

function serializeLoadChats(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as LoadChatsCommand;
  result.method = 'loadChats';
  // TDLib 1.8+: loadChats(chat_list, limit) — загружает чаты, шлёт updateNewChat
  result.params.setString('_chat_list_json', cmd.payload.chatList === 'archive'
    ? '{"@type":"chatListArchive"}'
    : '{"@type":"chatListMain"}');
  result.params.setNumber('limit', cmd.payload.limit);
}

function serializeLoadActiveStories(_command: AnyAppCommand, result: SerializedCommand): void {
  result.method = 'loadActiveStories';
  result.params.setString('_story_list_json', '{"@type":"storyListMain"}');
}

function serializeOpenChat(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as OpenChatCommand;
  result.method = 'openChat';
  result.params.setNumber('chat_id', cmd.payload.chatId);
}

function serializeSendMessage(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as SendMessageCommand;
  result.method = 'sendMessage';
  result.params.setNumber('chat_id', cmd.payload.chatId);

  const text = escapeForJson(cmd.payload.text);
  const entities = buildCustomEmojiEntitiesJson(cmd.payload.customEmojiEntities);
  const inputContentJson = `{"@type":"inputMessageText","text":{"@type":"formattedText","text":"${text}","entities":${entities}},"clear_draft":true}`;
  result.params.setString('_input_message_content_json', inputContentJson);
  setReplyToJsonIfNeeded(result.params, cmd.payload.replyToMessageId);
}

function serializeSendMediaMessage(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as SendMediaMessageCommand;
  result.method = 'sendMessage';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setString('_input_message_content_json',
    buildMediaInputContentJson(cmd.payload.mediaKind, cmd.payload.localPath, cmd.payload.caption,
      cmd.payload.durationSeconds, cmd.payload.waveformBase64));
  setReplyToJsonIfNeeded(result.params, cmd.payload.replyToMessageId);
}

function serializeEditMessageText(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as EditMessageTextCommand;
  result.method = 'editMessageText';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setString('_message_id_json', cmd.payload.messageId);
  const text = escapeForJson(cmd.payload.text);
  const inputContentJson = `{"@type":"inputMessageText","text":{"@type":"formattedText","text":"${text}","entities":[]},"clear_draft":true}`;
  result.params.setString('_input_message_content_json', inputContentJson);
}

function serializeDeleteMessages(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as DeleteMessagesCommand;
  result.method = 'deleteMessages';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setString('_message_ids_json', '[' + cmd.payload.messageIds.join(',') + ']');
  result.params.setBool('revoke', cmd.payload.revoke);
}

function serializeForwardMessages(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as ForwardMessagesCommand;
  result.method = 'forwardMessages';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setNumber('from_chat_id', cmd.payload.fromChatId);
  result.params.setString('_message_ids_json', '[' + cmd.payload.messageIds.join(',') + ']');
  result.params.setBool('send_copy', cmd.payload.sendCopy);
  result.params.setBool('remove_caption', cmd.payload.removeCaption);
}

function serializeSetChatMute(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as SetChatMuteCommand;
  result.method = 'setChatNotificationSettings';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  const settingsJson = `{"@type":"chatNotificationSettings","use_default_mute_for":false,"mute_for":${cmd.payload.muteForSeconds}}`;
  result.params.setString('_notification_settings_json', settingsJson);
}

function serializeToggleChatIsPinned(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as ToggleChatPinnedCommand;
  result.method = 'toggleChatIsPinned';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setBool('is_pinned', cmd.payload.isPinned);
  result.params.setString('_chat_list_json', cmd.payload.chatList === 'archive'
    ? '{"@type":"chatListArchive"}'
    : '{"@type":"chatListMain"}');
}

function serializeAddChatToList(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as AddChatToListCommand;
  result.method = 'addChatToList';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  const chatListJson = cmd.payload.chatList === 'archive'
    ? '{"@type":"chatListArchive"}'
    : '{"@type":"chatListMain"}';
  result.params.setString('_chat_list_json', chatListJson);
}

function serializePinChatMessage(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as PinChatMessageCommand;
  result.method = 'pinChatMessage';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setString('_message_id_json', cmd.payload.messageId);
  result.params.setBool('disable_notification', cmd.payload.disableNotification);
  result.params.setBool('only_for_self', cmd.payload.onlyForSelf);
}

function serializeUnpinChatMessage(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as UnpinChatMessageCommand;
  result.method = 'unpinChatMessage';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setString('_message_id_json', cmd.payload.messageId);
}

function serializeDeleteChatHistory(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as DeleteChatHistoryCommand;
  result.method = 'deleteChatHistory';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setBool('remove_from_chat_list', cmd.payload.removeFromChatList);
  result.params.setBool('revoke', cmd.payload.revoke);
}

function serializeToggleChatIsMarkedAsUnread(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as ToggleChatIsMarkedAsUnreadCommand;
  result.method = 'toggleChatIsMarkedAsUnread';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setBool('is_marked_as_unread', cmd.payload.isMarkedAsUnread);
}

function serializeSetChatDraft(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as SetChatDraftCommand;
  result.method = 'setChatDraftMessage';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  if (cmd.payload.text.trim().length === 0) {
    // Clearing: draft_message must be an explicit null
    result.params.setString('_draft_message_json', 'null');
    return;
  }
  const text = escapeForJson(cmd.payload.text);
  let draftJson = '{"@type":"draftMessage"';
  if (cmd.payload.replyToMessageId !== '0') {
    // draftMessage.reply_to takes an InputMessageReplyTo object (td_api.tl 2997)
    draftJson += ',"reply_to":{"@type":"inputMessageReplyToMessage","message_id":'
      + cmd.payload.replyToMessageId + '}';
  }
  const entities = buildCustomEmojiEntitiesJson(cmd.payload.customEmojiEntities);
  draftJson += ',"input_message_text":{"@type":"inputMessageText","text":{"@type":"formattedText","text":"'
    + text + '","entities":' + entities + '}}}';
  result.params.setString('_draft_message_json', draftJson);
}

function serializeSearchChatMessages(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as SearchChatMessagesCommand;
  result.method = 'searchChatMessages';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setString('query', cmd.payload.query);
  result.params.setString('_from_message_id_json', cmd.payload.fromMessageId);
  result.params.setNumber('offset', cmd.payload.offset);
  result.params.setNumber('limit', cmd.payload.limit);
  if (cmd.payload.filterType.length > 0) {
    result.params.setString('_filter_json', '{"@type":"searchMessagesFilter' + cmd.payload.filterType + '"}');
  }
}

function serializeViewMessages(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as ViewMessagesCommand;
  result.method = 'viewMessages';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setString('_message_ids_json', '[' + cmd.payload.messageIds.join(',') + ']');
  result.params.setBool('force_read', true);
}

function serializeGetChatHistory(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetChatHistoryCommand;
  result.method = 'getChatHistory';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  // int64 must be kept as raw json number to avoid precision loss in JS number.
  result.params.setString('_from_message_id_json', cmd.payload.fromMessageId);
  result.params.setNumber('offset', cmd.payload.offset);
  result.params.setNumber('limit', cmd.payload.limit);
  result.params.setBool('only_local', cmd.payload.onlyLocal);
}

function serializeGetUser(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetUserCommand;
  result.method = 'getUser';
  result.params.setNumber('user_id', cmd.payload.userId);
}

function serializeCreatePrivateChat(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as CreatePrivateChatCommand;
  result.method = 'createPrivateChat';
  result.params.setNumber('user_id', cmd.payload.userId);
  result.params.setBool('force', cmd.payload.force);
}

function serializeImportContacts(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as ImportContactsCommand;
  result.method = 'importContacts';
  result.params.setString('_contacts_json', buildImportedContactsJson(cmd.payload.contacts));
}

function serializeCreateNewBasicGroupChat(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as CreateNewBasicGroupChatCommand;
  result.method = 'createNewBasicGroupChat';
  result.params.setString('_user_ids_json', '[' + cmd.payload.userIds.join(',') + ']');
  result.params.setString('title', cmd.payload.title);
  result.params.setNumber('message_auto_delete_time', Math.max(0, Math.floor(cmd.payload.messageAutoDeleteTime)));
}

function serializeCreateNewSupergroupChat(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as CreateNewSupergroupChatCommand;
  result.method = 'createNewSupergroupChat';
  result.params.setString('title', cmd.payload.title);
  result.params.setBool('is_forum', cmd.payload.isForum);
  result.params.setBool('is_channel', cmd.payload.isChannel);
  result.params.setString('description', cmd.payload.description);
  result.params.setString('_location_json', 'null');
  result.params.setNumber('message_auto_delete_time', Math.max(0, Math.floor(cmd.payload.messageAutoDeleteTime)));
  result.params.setBool('for_import', cmd.payload.forImport);
}

function serializeSearchContacts(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as SearchContactsCommand;
  result.method = 'searchContacts';
  result.params.setString('query', cmd.payload.query);
  result.params.setNumber('limit', cmd.payload.limit);
}

function serializeSearchChatsOnServer(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as SearchChatsOnServerCommand;
  result.method = 'searchChatsOnServer';
  result.params.setString('query', cmd.payload.query);
  result.params.setNumber('limit', cmd.payload.limit);
}

function serializeSearchPublicChats(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as SearchPublicChatsCommand;
  result.method = 'searchPublicChats';
  result.params.setString('query', cmd.payload.query);
}

function serializeSearchCallMessages(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as SearchCallMessagesCommand;
  result.method = 'searchCallMessages';
  result.params.setString('offset', cmd.payload.offset);
  result.params.setNumber('limit', cmd.payload.limit);
  result.params.setBool('only_missed', cmd.payload.onlyMissed);
}

function serializeGetChat(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetChatCommand;
  result.method = 'getChat';
  result.params.setNumber('chat_id', cmd.payload.chatId);
}

function serializeGetChatPinnedMessage(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetChatPinnedMessageCommand;
  result.method = 'getChatPinnedMessage';
  result.params.setNumber('chat_id', cmd.payload.chatId);
}

function serializeGetRepliedMessage(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetRepliedMessageCommand;
  result.method = 'getRepliedMessage';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setString('_message_id_json', cmd.payload.messageId);
}

function serializeCloseChat(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as CloseChatCommand;
  result.method = 'closeChat';
  result.params.setNumber('chat_id', cmd.payload.chatId);
}

function serializeSetTdlibOnline(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as SetTdlibOnlineCommand;
  result.method = 'setOption';
  result.params.setString('name', 'online');
  result.params.setString('_value_json',
    '{"@type":"optionValueBoolean","value":' + (cmd.payload.online ? 'true' : 'false') + '}');
}

function serializeGetUserFullInfo(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetUserFullInfoCommand;
  result.method = 'getUserFullInfo';
  result.params.setNumber('user_id', cmd.payload.userId);
}

function serializeGetSupergroupFullInfo(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetSupergroupFullInfoCommand;
  result.method = 'getSupergroupFullInfo';
  result.params.setNumber('supergroup_id', cmd.payload.supergroupId);
}

function serializeGetBasicGroupFullInfo(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetBasicGroupFullInfoCommand;
  result.method = 'getBasicGroupFullInfo';
  result.params.setNumber('basic_group_id', cmd.payload.basicGroupId);
}

function chatMembersFilterJson(filterKind: string): string {
  if (filterKind === 'members') {
    return '{"@type":"chatMembersFilterMembers"}';
  }
  if (filterKind === 'administrators') {
    return '{"@type":"chatMembersFilterAdministrators"}';
  }
  return 'null';
}

function supergroupMembersFilterJson(filterKind: string): string {
  if (filterKind === 'administrators') {
    return '{"@type":"supergroupMembersFilterAdministrators"}';
  }
  return '{"@type":"supergroupMembersFilterRecent"}';
}

function serializeSearchChatMembers(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as SearchChatMembersCommand;
  result.method = 'searchChatMembers';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setString('query', cmd.payload.query);
  result.params.setNumber('limit', cmd.payload.limit);
  result.params.setString('_filter_json', chatMembersFilterJson(cmd.payload.filterKind));
}

function serializeGetSupergroupMembers(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetSupergroupMembersCommand;
  result.method = 'getSupergroupMembers';
  result.params.setNumber('supergroup_id', cmd.payload.supergroupId);
  result.params.setString('_filter_json', supergroupMembersFilterJson(cmd.payload.filterKind));
  result.params.setNumber('offset', cmd.payload.offset);
  result.params.setNumber('limit', cmd.payload.limit);
}

function serializeDownloadFile(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as DownloadFileCommand;
  result.method = 'downloadFile';
  result.params.setNumber('file_id', cmd.payload.fileId);
  result.params.setNumber('priority', cmd.payload.priority);
  result.params.setBool('synchronous', cmd.payload.synchronous);
}

function serializeCancelDownloadFile(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as CancelDownloadFileCommand;
  result.method = 'cancelDownloadFile';
  result.params.setNumber('file_id', cmd.payload.fileId);
  result.params.setBool('only_if_pending', cmd.payload.onlyIfPending);
}

function serializeGetRecentStickers(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetRecentStickersCommand;
  result.method = 'getRecentStickers';
  result.params.setBool('is_attached', cmd.payload.isAttached);
}

function serializeGetFavoriteStickers(_command: AnyAppCommand, result: SerializedCommand): void {
  result.method = 'getFavoriteStickers';
}

function serializeGetPremiumStickers(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetPremiumStickersCommand;
  result.method = 'getPremiumStickers';
  result.params.setNumber('limit', Math.max(0, Math.min(100, Math.floor(cmd.payload.limit))));
}

function serializeGetInstalledStickerSets(_command: AnyAppCommand, result: SerializedCommand): void {
  result.method = 'getInstalledStickerSets';
  result.params.setString('_sticker_type_json', '{"@type":"stickerTypeRegular"}');
}

function serializeGetInstalledCustomEmojiSets(_command: AnyAppCommand, result: SerializedCommand): void {
  result.method = 'getInstalledStickerSets';
  result.params.setString('_sticker_type_json', '{"@type":"stickerTypeCustomEmoji"}');
}

function serializeGetTrendingCustomEmojiSets(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetTrendingCustomEmojiSetsCommand;
  result.method = 'getTrendingStickerSets';
  result.params.setString('_sticker_type_json', '{"@type":"stickerTypeCustomEmoji"}');
  result.params.setNumber('offset', Math.max(0, Math.floor(cmd.payload.offset)));
  result.params.setNumber('limit', Math.max(0, Math.min(100, Math.floor(cmd.payload.limit))));
}

function serializeSearchEmojis(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as SearchEmojisCommand;
  result.method = 'searchEmojis';
  result.params.setString('text', cmd.payload.text);
  result.params.setString('_input_language_codes_json',
    buildStringArrayJson(cmd.payload.inputLanguageCodes));
}

function serializeSearchCustomEmojiStickers(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as SearchCustomEmojiStickersCommand;
  result.method = 'searchStickers';
  result.params.setString('_sticker_type_json', '{"@type":"stickerTypeCustomEmoji"}');
  result.params.setString('emojis', cmd.payload.emojis);
  result.params.setString('query', cmd.payload.query);
  result.params.setString('_input_language_codes_json',
    buildStringArrayJson(cmd.payload.inputLanguageCodes));
  result.params.setNumber('offset', Math.max(0, Math.floor(cmd.payload.offset)));
  result.params.setNumber('limit', Math.max(0, Math.min(100, Math.floor(cmd.payload.limit))));
}

function serializeSearchRegularStickers(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as SearchRegularStickersCommand;
  result.method = 'searchStickers';
  result.params.setString('_sticker_type_json', '{"@type":"stickerTypeRegular"}');
  result.params.setString('emojis', cmd.payload.emojis);
  result.params.setString('query', cmd.payload.query);
  result.params.setString('_input_language_codes_json',
    buildStringArrayJson(cmd.payload.inputLanguageCodes));
  result.params.setNumber('offset', Math.max(0, Math.floor(cmd.payload.offset)));
  result.params.setNumber('limit', Math.max(0, Math.min(100, Math.floor(cmd.payload.limit))));
}

function serializeGetOption(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetOptionCommand;
  result.method = 'getOption';
  result.params.setString('name', cmd.payload.name);
}

function serializeSearchPublicChat(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as SearchPublicChatCommand;
  result.method = 'searchPublicChat';
  result.params.setString('username', cmd.payload.username);
}

function serializeGetInlineQueryResults(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetInlineQueryResultsCommand;
  result.method = 'getInlineQueryResults';
  result.params.setNumber('bot_user_id', cmd.payload.botUserId);
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setString('_user_location_json', 'null');
  result.params.setString('query', cmd.payload.query);
  result.params.setString('offset', cmd.payload.offset);
}

function serializeSendInlineQueryResult(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as SendInlineQueryResultCommand;
  result.method = 'sendInlineQueryResultMessage';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setString('_topic_id_json', 'null');
  result.params.setString('_reply_to_json', 'null');
  result.params.setString('_options_json', 'null');
  result.params.setString('_query_id_json', /^-?[0-9]+$/.test(cmd.payload.queryId)
    ? cmd.payload.queryId : '0');
  result.params.setString('result_id', cmd.payload.resultId);
  result.params.setBool('hide_via_bot', cmd.payload.hideViaBot);
}

function serializeGetStickerSet(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetStickerSetCommand;
  result.method = 'getStickerSet';
  // int64 as raw JSON number — setNumber would round-trip through double
  result.params.setString('_set_id_json', cmd.payload.setId);
}

function serializeSendSticker(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as SendStickerCommand;
  result.method = 'sendMessage';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  const remoteId = escapeForJson(cmd.payload.remoteFileId);
  const emoji = escapeForJson(cmd.payload.emoji);
  const contentJson = `{"@type":"inputMessageSticker",`
    + `"sticker":{"@type":"inputFileRemote","id":"${remoteId}"},`
    + `"width":${Math.max(0, Math.floor(cmd.payload.width))},`
    + `"height":${Math.max(0, Math.floor(cmd.payload.height))},`
    + `"emoji":"${emoji}"}`;
  result.params.setString('_input_message_content_json', contentJson);
}

function serializeGetSavedAnimations(_command: AnyAppCommand, result: SerializedCommand): void {
  result.method = 'getSavedAnimations';
}

function serializeSendAnimation(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as SendAnimationCommand;
  result.method = 'sendMessage';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  const remoteId = escapeForJson(cmd.payload.remoteFileId);
  const contentJson = `{"@type":"inputMessageAnimation",`
    + `"animation":{"@type":"inputFileRemote","id":"${remoteId}"},`
    + `"added_sticker_file_ids":[],`
    + `"duration":${Math.max(0, Math.floor(cmd.payload.duration))},`
    + `"width":${Math.max(0, Math.floor(cmd.payload.width))},`
    + `"height":${Math.max(0, Math.floor(cmd.payload.height))},`
    + `"caption":{"@type":"formattedText","text":"","entities":[]},`
    + `"show_caption_above_media":false,`
    + `"has_spoiler":false}`;
  result.params.setString('_input_message_content_json', contentJson);
}

function serializeRequestQrCodeAuth(_command: AnyAppCommand, result: SerializedCommand): void {
  result.method = 'requestQrCodeAuthentication';
}

function serializeLogout(_command: AnyAppCommand, result: SerializedCommand): void {
  // Сброс auth state на сервере — аналог auth.cancelCode в raw MTProto (Android TL_auth_cancelCode).
  // TDLib после logOut автоматически присылает updateAuthorizationState: waitPhoneNumber.
  result.method = 'logOut';
}

function setReplyToJsonIfNeeded(params: TdObject, replyToId: string): void {
  if (replyToId && replyToId !== '0') {
    params.setString('_reply_to_json', `{"@type":"inputMessageReplyToMessage","message_id":${replyToId}}`);
  }
}

/**
 * Собирает финальный JSON для отправки в TDLib.
 * Учитывает специальные поля _*_json для вложенных объектов.
 */
export function buildTdlibRequestJson(method: string, params: TdObject): string {
  const parts: string[] = [];
  parts.push(`"@type":"${method}"`);

  // Получаем все ключи из cache
  const keys = params.getCache().keys();

  for (let i = 0; i < keys.length; i++) {
    const key = keys[i];

    // Специальные поля для вложенных JSON: _field_json -> "field": <raw json>
    if (key.startsWith('_') && key.endsWith('_json')) {
      const realKey = key.substring(1, key.length - 5);
      const value = params.getString(key);
      parts.push(`"${realKey}":${value}`);
      continue;
    }

    // Обычные поля
    const value = params.get(key);
    if (typeof value === 'string') {
      parts.push(`"${key}":"${escapeForJson(value)}"`);
    } else if (typeof value === 'number') {
      parts.push(`"${key}":${value}`);
    } else if (typeof value === 'boolean') {
      parts.push(`"${key}":${value ? 'true' : 'false'}`);
    }
  }

  return '{' + parts.join(',') + '}';
}

/**
 * Экранирование строки для JSON.
 */
function escapeForJson(str: string): string {
  return str
    .replace(/\\/g, '\\\\')
    .replace(/"/g, '\\"')
    .replace(/\n/g, '\\n')
    .replace(/\r/g, '\\r')
    .replace(/\t/g, '\\t');
}

function buildImportedContactsJson(contacts: ImportedContactInput[]): string {
  const parts: string[] = [];
  for (const contact of contacts) {
    parts.push('{"@type":"importedContact",'
      + '"phone_number":"' + escapeForJson(contact.phoneNumber) + '",'
      + '"first_name":"' + escapeForJson(contact.firstName) + '",'
      + '"last_name":"' + escapeForJson(contact.lastName) + '",'
      + '"note":null}');
  }
  return '[' + parts.join(',') + ']';
}

function buildCustomEmojiEntitiesJson(entities: CustomEmojiTextEntity[]): string {
  const parts: string[] = [];
  for (const entity of entities) {
    const offset = Math.max(0, Math.floor(entity.offset));
    const length = Math.max(0, Math.floor(entity.length));
    if (length === 0 || !/^[0-9]+$/.test(entity.customEmojiId) || entity.customEmojiId === '0') {
      continue;
    }
    parts.push('{"@type":"textEntity","offset":' + offset
      + ',"length":' + length
      + ',"type":{"@type":"textEntityTypeCustomEmoji","custom_emoji_id":'
      + entity.customEmojiId + '}}');
  }
  return '[' + parts.join(',') + ']';
}

function buildStringArrayJson(values: string[]): string {
  const parts: string[] = [];
  for (const value of values) {
    const normalized = value.trim();
    if (normalized.length > 0) {
      parts.push('"' + escapeForJson(normalized) + '"');
    }
  }
  return '[' + parts.join(',') + ']';
}

function buildFormattedTextJson(text: string): string {
  const escapedText = escapeForJson(text);
  return `{"@type":"formattedText","text":"${escapedText}","entities":[]}`;
}

function buildInputFileLocalJson(localPath: string): string {
  const escapedPath = escapeForJson(localPath);
  return `{"@type":"inputFileLocal","path":"${escapedPath}"}`;
}

function buildMediaInputContentJson(
  mediaKind: string,
  localPath: string,
  caption: string,
  durationSeconds: number,
  waveformBase64: string
): string {
  const fileJson = buildInputFileLocalJson(localPath);
  const captionJson = buildFormattedTextJson(caption);

  switch (mediaKind) {
    case 'voice':
      return `{"@type":"inputMessageVoiceNote","voice_note":${fileJson},` +
        `"duration":${Math.max(1, Math.floor(durationSeconds))},` +
        `"waveform":"${escapeForJson(waveformBase64)}","caption":${captionJson},` +
        `"self_destruct_type":null}`;
    case 'photo':
      return `{"@type":"inputMessagePhoto","photo":${fileJson},"thumbnail":null,` +
        `"added_sticker_file_ids":[],"width":0,"height":0,"caption":${captionJson},` +
        `"show_caption_above_media":false,"self_destruct_type":null,"has_spoiler":false}`;
    case 'video':
      return `{"@type":"inputMessageVideo","video":${fileJson},"thumbnail":null,"cover":null,` +
        `"start_timestamp":0,"added_sticker_file_ids":[],"duration":0,"width":0,"height":0,` +
        `"supports_streaming":true,"caption":${captionJson},"show_caption_above_media":false,` +
        `"self_destruct_type":null,"has_spoiler":false}`;
    default:
      return `{"@type":"inputMessageDocument","document":${fileJson},"thumbnail":null,` +
        `"disable_content_type_detection":false,"caption":${captionJson}}`;
  }
}

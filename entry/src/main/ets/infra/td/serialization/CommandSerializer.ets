// CommandSerializer — преобразует AnyAppCommand → TdObject для TdGateway.send()
//
// Возвращает объект с method (строка) и params (TdObject).
// TdGateway.send(method, params) отправляет запрос в TDLib.

import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  AnyAppCommand,
  ChatFolderDraftPayload,
  CreateChatFolderInviteLinkCommand, DeleteChatFolderInviteLinkCommand, EditChatFolderInviteLinkCommand,
  GetChatFolderCommand, GetChatFolderInviteLinksCommand, GetRecommendedChatFoldersCommand,
  CheckChatFolderInviteLinkCommand, AddChatFolderByInviteLinkCommand,
  CheckChatInviteLinkCommand, JoinChatByInviteLinkCommand, GetChatMemberCommand,
  CreateChatInviteLinkCommand, RevokeChatInviteLinkCommand, GetChatInviteLinksCommand,
  GetChatAdministratorsCommand, SetChatPermissionsCommand, SetChatMessageAutoDeleteTimeCommand,
  SetChatMemberStatusCommand, ChatAdminRightsPayload,
  GetChatScheduledMessagesCommand, EditMessageSchedulingStateCommand,
  CreateChatFolderCommand, DeleteChatFolderCommand, EditChatFolderCommand, LeaveChatCommand,
  ReportChatCommand, ShareContactCommand,
  GetBlockedMessageSendersCommand, SetMessageSenderBlockListCommand,
  GetStorageStatisticsCommand,
  SetAutoDownloadSettingsCommand,
  OptimizeStorageCommand,
  TerminateAllOtherSessionsCommand,
  TerminateSessionCommand,
  SetPhoneNumberCommand,
  CheckAuthCodeCommand,
  CheckAuthPasswordCommand,
  LoadChatsCommand,
  LoadActiveStoriesCommand,
  OpenChatCommand,
  SendMessageCommand,
  SendMediaMessageCommand,
  SendMediaAlbumCommand,
  EditMessageTextCommand,
  EditMessageCaptionCommand,
  EditMessageEntity,
  EditMessageLinkPreviewOptions,
  DeleteMessagesCommand,
  ForwardMessagesCommand,
  SetChatMuteCommand,
  GetMessageAvailableReactionsCommand,
  SetMessageReactionsCommand,
  JoinChatCommand,
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
  GetMessageCommand,
  GetMessagePropertiesCommand,
  GetChatPinnedMessageCommand,
  GetRepliedMessageCommand, GetMessageThreadCommand, GetMessageThreadHistoryCommand, TranslateTextCommand,
  CloseChatCommand,
  SetTdlibOnlineCommand,
  GetUserFullInfoCommand,
  GetSupergroupCommand,
  GetBasicGroupCommand,
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
  GetStickerSetCommand, ChangeStickerSetCommand,
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
COMMAND_SERIALIZATION_HANDLERS.set('sendMediaAlbum', serializeSendMediaAlbum);
COMMAND_SERIALIZATION_HANDLERS.set('editMessageText', serializeEditMessageText);
COMMAND_SERIALIZATION_HANDLERS.set('editMessageCaption', serializeEditMessageCaption);
COMMAND_SERIALIZATION_HANDLERS.set('deleteMessages', serializeDeleteMessages);
COMMAND_SERIALIZATION_HANDLERS.set('forwardMessages', serializeForwardMessages);
COMMAND_SERIALIZATION_HANDLERS.set('setChatMute', serializeSetChatMute);
COMMAND_SERIALIZATION_HANDLERS.set('setMessageReactions', serializeSetMessageReactions);
COMMAND_SERIALIZATION_HANDLERS.set('getMessageAvailableReactions', serializeGetMessageAvailableReactions);
COMMAND_SERIALIZATION_HANDLERS.set('reportChat', serializeReportChat);
COMMAND_SERIALIZATION_HANDLERS.set('leaveChat', serializeLeaveChat);
COMMAND_SERIALIZATION_HANDLERS.set('sendContactMessage', serializeSendContactMessage);
COMMAND_SERIALIZATION_HANDLERS.set('joinChat', serializeJoinChat);
COMMAND_SERIALIZATION_HANDLERS.set('toggleChatIsPinned', serializeToggleChatIsPinned);
COMMAND_SERIALIZATION_HANDLERS.set('checkChatInviteLink', serializeCheckChatInviteLink);
COMMAND_SERIALIZATION_HANDLERS.set('getChatMember', serializeGetChatMember);
COMMAND_SERIALIZATION_HANDLERS.set('createChatInviteLink', serializeCreateChatInviteLink);
COMMAND_SERIALIZATION_HANDLERS.set('revokeChatInviteLink', serializeRevokeChatInviteLink);
COMMAND_SERIALIZATION_HANDLERS.set('getChatInviteLinks', serializeGetChatInviteLinks);
COMMAND_SERIALIZATION_HANDLERS.set('getChatAdministrators', serializeGetChatAdministrators);
COMMAND_SERIALIZATION_HANDLERS.set('setChatPermissions', serializeSetChatPermissions);
COMMAND_SERIALIZATION_HANDLERS.set('setChatMemberStatus', serializeSetChatMemberStatus);
COMMAND_SERIALIZATION_HANDLERS.set('setChatMessageAutoDeleteTime', serializeSetChatMessageAutoDeleteTime);
COMMAND_SERIALIZATION_HANDLERS.set('getChatScheduledMessages', serializeGetChatScheduledMessages);
COMMAND_SERIALIZATION_HANDLERS.set('editMessageSchedulingState', serializeEditMessageSchedulingState);
COMMAND_SERIALIZATION_HANDLERS.set('joinChatByInviteLink', serializeJoinChatByInviteLink);
COMMAND_SERIALIZATION_HANDLERS.set('checkChatFolderInviteLink', serializeCheckChatFolderInviteLink);
COMMAND_SERIALIZATION_HANDLERS.set('addChatFolderByInviteLink', serializeAddChatFolderByInviteLink);
COMMAND_SERIALIZATION_HANDLERS.set('getRecommendedChatFolders', serializeGetRecommendedChatFolders);
COMMAND_SERIALIZATION_HANDLERS.set('getChatFolderInviteLinks', serializeGetChatFolderInviteLinks);
COMMAND_SERIALIZATION_HANDLERS.set('createChatFolderInviteLink', serializeCreateChatFolderInviteLink);
COMMAND_SERIALIZATION_HANDLERS.set('editChatFolderInviteLink', serializeEditChatFolderInviteLink);
COMMAND_SERIALIZATION_HANDLERS.set('deleteChatFolderInviteLink', serializeDeleteChatFolderInviteLink);
COMMAND_SERIALIZATION_HANDLERS.set('getChatFolder', serializeGetChatFolder);
COMMAND_SERIALIZATION_HANDLERS.set('createChatFolder', serializeCreateChatFolder);
COMMAND_SERIALIZATION_HANDLERS.set('editChatFolder', serializeEditChatFolder);
COMMAND_SERIALIZATION_HANDLERS.set('deleteChatFolder', serializeDeleteChatFolder);
COMMAND_SERIALIZATION_HANDLERS.set('getAutoDownloadSettingsPresets', serializeGetAutoDownloadSettingsPresets);
COMMAND_SERIALIZATION_HANDLERS.set('setAutoDownloadSettings', serializeSetAutoDownloadSettings);
COMMAND_SERIALIZATION_HANDLERS.set('getStorageStatistics', serializeGetStorageStatistics);
COMMAND_SERIALIZATION_HANDLERS.set('getStorageStatisticsFast', serializeGetStorageStatisticsFast);
COMMAND_SERIALIZATION_HANDLERS.set('optimizeStorage', serializeOptimizeStorage);
COMMAND_SERIALIZATION_HANDLERS.set('getBlockedMessageSenders', serializeGetBlockedMessageSenders);
COMMAND_SERIALIZATION_HANDLERS.set('setMessageSenderBlockList', serializeSetMessageSenderBlockList);
COMMAND_SERIALIZATION_HANDLERS.set('getActiveSessions', serializeGetActiveSessions);
COMMAND_SERIALIZATION_HANDLERS.set('terminateSession', serializeTerminateSession);
COMMAND_SERIALIZATION_HANDLERS.set('terminateAllOtherSessions', serializeTerminateAllOtherSessions);
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
COMMAND_SERIALIZATION_HANDLERS.set('getMessage', serializeGetMessage);
COMMAND_SERIALIZATION_HANDLERS.set('getMessageThread', serializeGetMessageThread);
COMMAND_SERIALIZATION_HANDLERS.set('translateText', serializeTranslateText);
COMMAND_SERIALIZATION_HANDLERS.set('getMessageThreadHistory', serializeGetMessageThreadHistory);
COMMAND_SERIALIZATION_HANDLERS.set('getMessageProperties', serializeGetMessageProperties);
COMMAND_SERIALIZATION_HANDLERS.set('getChatPinnedMessage', serializeGetChatPinnedMessage);
COMMAND_SERIALIZATION_HANDLERS.set('getRepliedMessage', serializeGetRepliedMessage);
COMMAND_SERIALIZATION_HANDLERS.set('closeChat', serializeCloseChat);
COMMAND_SERIALIZATION_HANDLERS.set('setTdlibOnline', serializeSetTdlibOnline);
COMMAND_SERIALIZATION_HANDLERS.set('getUserFullInfo', serializeGetUserFullInfo);
COMMAND_SERIALIZATION_HANDLERS.set('getSupergroup', serializeGetSupergroup);
COMMAND_SERIALIZATION_HANDLERS.set('getBasicGroup', serializeGetBasicGroup);
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
COMMAND_SERIALIZATION_HANDLERS.set('changeStickerSet', serializeChangeStickerSet);
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
  const chatListJson: string = cmd.payload.chatList === 'archive'
    ? '{"@type":"chatListArchive"}'
    : (cmd.payload.chatList === 'folder'
      ? '{"@type":"chatListFolder","chat_folder_id":' + cmd.payload.folderId.toString() + '}'
      : '{"@type":"chatListMain"}');
  result.params.setString('_chat_list_json', chatListJson);
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
  setTopicIdJsonIfNeeded(result.params, cmd.payload.topicThreadId);
  if (cmd.payload.scheduledDateSeconds > 0) {
    result.params.setString('_scheduling_state_json',
      '{"@type":"messageSchedulingStateSendAtDate","send_date":' +
      cmd.payload.scheduledDateSeconds.toString() + ',"repeat_period":0}');
  }
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

function serializeSendMediaAlbum(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as SendMediaAlbumCommand;
  result.method = 'sendMessageAlbum';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  const contents: string[] = [];
  for (let index = 0; index < cmd.payload.localPaths.length; index++) {
    contents.push(buildMediaInputContentJson('photo', cmd.payload.localPaths[index],
      index === 0 ? cmd.payload.caption : '', 0, ''));
  }
  result.params.setString('_input_message_contents_json', '[' + contents.join(',') + ']');
  result.params.setString('_topic_id_json', 'null');
  result.params.setString('_options_json', 'null');
  result.params.setString('_reply_to_json', 'null');
  setReplyToJsonIfNeeded(result.params, cmd.payload.replyToMessageId);
}

function serializeEditMessageText(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as EditMessageTextCommand;
  result.method = 'editMessageText';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setString('_message_id_json', cmd.payload.messageId);
  const textJson = buildEditFormattedTextJson(cmd.payload.text, cmd.payload.entities);
  const previewJson = cmd.payload.linkPreviewOptions === undefined ? ''
    : ',"link_preview_options":' + buildEditLinkPreviewOptionsJson(cmd.payload.linkPreviewOptions);
  const inputContentJson = `{"@type":"inputMessageText","text":${textJson}${previewJson},"clear_draft":true}`;
  result.params.setString('_input_message_content_json', inputContentJson);
}

function serializeEditMessageCaption(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as EditMessageCaptionCommand;
  result.method = 'editMessageCaption';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setString('_message_id_json', cmd.payload.messageId);
  result.params.setString('_caption_json', buildEditFormattedTextJson(cmd.payload.caption, cmd.payload.entities));
  result.params.setBool('show_caption_above_media', cmd.payload.showCaptionAboveMedia);
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

// setMessageReactions chat_id:int53 message_id:int53 reaction_types:vector<ReactionType> is_big
// (td_api.tl:11643). Chip keys are expanded here so the command layer never knows td_api shapes.
function buildReactionTypesJson(reactionKeys: string[]): string {
  const parts: string[] = [];
  for (const key of reactionKeys) {
    if (key.startsWith('emoji:')) {
      const emoji = key.substring('emoji:'.length);
      if (emoji.length === 0) {
        throw new Error('Invalid reaction emoji key');
      }
      parts.push(`{"@type":"reactionTypeEmoji","emoji":${JSON.stringify(emoji)}}`);
      continue;
    }
    if (key.startsWith('custom:')) {
      const customEmojiId = key.substring('custom:'.length);
      // TDLib encodes int64 as a decimal string; reject anything that could round.
      if (!/^-?[1-9][0-9]{0,18}$/.test(customEmojiId)) {
        throw new Error('Invalid custom reaction id');
      }
      parts.push(`{"@type":"reactionTypeCustomEmoji","custom_emoji_id":${JSON.stringify(customEmojiId)}}`);
      continue;
    }
    throw new Error('Unsupported reaction key');
  }
  return '[' + parts.join(',') + ']';
}

function serializeGetMessageAvailableReactions(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetMessageAvailableReactionsCommand;
  result.method = 'getMessageAvailableReactions';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setString('_message_id_json', JSON.stringify(cmd.payload.messageId));
  result.params.setNumber('row_size', cmd.payload.rowSize);
}

function serializeSetMessageReactions(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as SetMessageReactionsCommand;
  result.method = 'setMessageReactions';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  // TDLib JSON expects int64 as a decimal string; a bare value would be emitted as a JSON number and
  // lose precision for large ids.
  result.params.setString('_message_id_json', JSON.stringify(cmd.payload.messageId));
  result.params.setString('_reaction_types_json', buildReactionTypesJson(cmd.payload.reactionKeys));
  result.params.setBool('is_big', cmd.payload.isBig);
}

function serializeReportChat(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as ReportChatCommand;
  result.method = 'reportChat';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  // bytes are base64 strings in the JSON bridge; the first request sends empty bytes.
  result.params.setString('_option_id_json', JSON.stringify(cmd.payload.optionId));
  result.params.setString('_message_ids_json', buildChatIdArrayJson(cmd.payload.messageIds));
  result.params.setString('text', cmd.payload.text);
}

function serializeLeaveChat(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as LeaveChatCommand;
  result.method = 'leaveChat';
  result.params.setNumber('chat_id', cmd.payload.chatId);
}

function serializeSendContactMessage(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as ShareContactCommand;
  result.method = 'sendMessage';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setString('_input_message_content_json',
    '{"@type":"inputMessageContact","contact":{"@type":"contact"' +
    ',"phone_number":"' + escapeForJson(cmd.payload.phoneNumber) + '"' +
    ',"first_name":"' + escapeForJson(cmd.payload.firstName) + '"' +
    ',"last_name":"' + escapeForJson(cmd.payload.lastName) + '"' +
    ',"vcard":""' +
    ',"user_id":' + cmd.payload.userId.toString() + '}}');
}

function serializeJoinChat(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as JoinChatCommand;
  // TDLib: joinChat chat_id:int53 = Ok — channel/supergroup join
  result.method = 'joinChat';
  result.params.setNumber('chat_id', cmd.payload.chatId);
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

function buildChatIdArrayJson(chatIds: number[]): string {
  const parts: string[] = [];
  for (const chatId of chatIds) {
    if (Number.isSafeInteger(chatId) && chatId > 0) {
      parts.push(chatId.toString());
    }
  }
  return '[' + parts.join(',') + ']';
}

function buildChatFolderJson(draft: ChatFolderDraftPayload): string {
  return '{"@type":"chatFolder"' +
    ',"name":{"@type":"chatFolderName","text":{"@type":"formattedText","text":"' +
    escapeForJson(draft.title) + '","entities":[]},"animate_custom_emoji":false}' +
    ',"icon":{"@type":"chatFolderIcon","name":""}' +
    ',"color_id":0' +
    ',"is_shareable":false' +
    ',"pinned_chat_ids":[]' +
    ',"included_chat_ids":' + buildChatIdArrayJson(draft.includedChatIds) + '' +
    ',"excluded_chat_ids":[]' +
    ',"exclude_muted":' + (draft.excludeMuted ? 'true' : 'false') +
    ',"exclude_read":' + (draft.excludeRead ? 'true' : 'false') +
    ',"exclude_archived":' + (draft.excludeArchived ? 'true' : 'false') +
    ',"include_contacts":' + (draft.includeContacts ? 'true' : 'false') +
    ',"include_non_contacts":' + (draft.includeNonContacts ? 'true' : 'false') +
    ',"include_bots":' + (draft.includeBots ? 'true' : 'false') +
    ',"include_groups":' + (draft.includeGroups ? 'true' : 'false') +
    ',"include_channels":' + (draft.includeChannels ? 'true' : 'false') + '}';
}

function serializeGetChatScheduledMessages(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetChatScheduledMessagesCommand;
  result.method = 'getChatScheduledMessages';
  result.params.setNumber('chat_id', cmd.payload.chatId);
}

// null sends the message immediately, which is the "send now" action on the scheduled list.
function serializeEditMessageSchedulingState(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as EditMessageSchedulingStateCommand;
  result.method = 'editMessageSchedulingState';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setString('_message_id_json', JSON.stringify(cmd.payload.messageId));
  result.params.setString('_scheduling_state_json', cmd.payload.scheduledDateSeconds > 0
    ? '{"@type":"messageSchedulingStateSendAtDate","send_date":' +
      cmd.payload.scheduledDateSeconds.toString() + ',"repeat_period":0}'
    : 'null');
}

function serializeSetChatMessageAutoDeleteTime(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as SetChatMessageAutoDeleteTimeCommand;
  result.method = 'setChatMessageAutoDeleteTime';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setNumber('message_auto_delete_time', cmd.payload.seconds);
}

// statusKind maps to the TDLib status object; a restricted member keeps zero permissions by design.
function buildAdminRightsJson(rights: ChatAdminRightsPayload): string {
  return '{"@type":"chatAdministratorRights"' +
    ',"can_manage_chat":' + rights.canManageChat.toString() +
    ',"can_change_info":' + rights.canChangeInfo.toString() +
    ',"can_post_messages":' + rights.canPostMessages.toString() +
    ',"can_edit_messages":' + rights.canEditMessages.toString() +
    ',"can_delete_messages":' + rights.canDeleteMessages.toString() +
    ',"can_invite_users":' + rights.canInviteUsers.toString() +
    ',"can_restrict_members":' + rights.canRestrictMembers.toString() +
    ',"can_pin_messages":' + rights.canPinMessages.toString() +
    ',"can_manage_topics":' + rights.canManageTopics.toString() +
    ',"can_promote_members":' + rights.canPromoteMembers.toString() +
    ',"can_manage_video_chats":' + rights.canManageVideoChats.toString() +
    ',"can_post_stories":' + rights.canPostStories.toString() +
    ',"can_edit_stories":' + rights.canEditStories.toString() +
    ',"can_delete_stories":' + rights.canDeleteStories.toString() +
    ',"can_manage_direct_messages":' + rights.canManageDirectMessages.toString() +
    ',"is_anonymous":' + rights.isAnonymous.toString() + '}';
}

function buildMemberStatusJson(statusKind: string, untilDate: number,
  rights: ChatAdminRightsPayload, permissionsJson: string): string {
  if (statusKind === 'banned') {
    return '{"@type":"chatMemberStatusBanned","banned_until_date":' + untilDate.toString() + '}';
  }
  if (statusKind === 'administrator') {
    return '{"@type":"chatMemberStatusAdministrator","custom_title":"","can_be_edited":false,' +
      '"rights":' + buildAdminRightsJson(rights) + '}';
  }
  if (statusKind === 'restricted') {
    // A caller may pass the whole chatPermissions object; otherwise every right stays denied.
    const permissions: string = permissionsJson.length > 0
      ? permissionsJson
      : '{"@type":"chatPermissions"' +
        ',"can_send_basic_messages":false,"can_send_audios":false,"can_send_documents":false' +
        ',"can_send_photos":false,"can_send_videos":false,"can_send_video_notes":false' +
        ',"can_send_voice_notes":false,"can_send_polls":false,"can_send_other_messages":false' +
        ',"can_add_link_previews":false,"can_change_info":false,"can_invite_users":false' +
        ',"can_pin_messages":false,"can_create_topics":false}';
    return '{"@type":"chatMemberStatusRestricted","is_member":true,"restricted_until_date":' +
      untilDate.toString() + ',"permissions":' + permissions + '}';
  }
  return '{"@type":"chatMemberStatusMember","member_until_date":0}';
}

function serializeSetChatMemberStatus(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as SetChatMemberStatusCommand;
  result.method = 'setChatMemberStatus';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setString('_member_id_json',
    '{"@type":"messageSenderUser","user_id":' + cmd.payload.userId.toString() + '}');
  result.params.setString('_status_json', buildMemberStatusJson(cmd.payload.statusKind,
    cmd.payload.untilDate, cmd.payload.rights, cmd.payload.permissionsJson));
}

function serializeSetChatPermissions(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as SetChatPermissionsCommand;
  result.method = 'setChatPermissions';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setString('_permissions_json', cmd.payload.permissionsJson);
}

function serializeGetChatAdministrators(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetChatAdministratorsCommand;
  result.method = 'getChatAdministrators';
  result.params.setNumber('chat_id', cmd.payload.chatId);
}

function serializeCreateChatInviteLink(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as CreateChatInviteLinkCommand;
  result.method = 'createChatInviteLink';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setString('name', cmd.payload.name);
  result.params.setNumber('expiration_date', cmd.payload.expirationDate);
  result.params.setNumber('member_limit', cmd.payload.memberLimit);
  result.params.setBool('creates_join_request', cmd.payload.createsJoinRequest);
}

function serializeRevokeChatInviteLink(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as RevokeChatInviteLinkCommand;
  result.method = 'revokeChatInviteLink';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setString('invite_link', cmd.payload.inviteLink);
}

function serializeGetChatInviteLinks(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetChatInviteLinksCommand;
  result.method = 'getChatInviteLinks';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setNumber('creator_user_id', cmd.payload.creatorUserId);
  result.params.setBool('is_revoked', cmd.payload.isRevoked);
  result.params.setNumber('offset_date', cmd.payload.offsetDate);
  result.params.setString('offset_invite_link', cmd.payload.offsetInviteLink);
  result.params.setNumber('limit', cmd.payload.limit);
}

function serializeGetChatMember(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetChatMemberCommand;
  result.method = 'getChatMember';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  // messageSenderUser is a small fixed JSON body; the user id is a validated safe integer.
  result.params.setString('_member_id_json',
    '{"@type":"messageSenderUser","user_id":' + cmd.payload.userId.toString() + '}');
}

function serializeCheckChatInviteLink(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as CheckChatInviteLinkCommand;
  result.method = 'checkChatInviteLink';
  result.params.setString('invite_link', cmd.payload.inviteLink);
}

function serializeJoinChatByInviteLink(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as JoinChatByInviteLinkCommand;
  result.method = 'joinChatByInviteLink';
  result.params.setString('invite_link', cmd.payload.inviteLink);
}

function serializeCheckChatFolderInviteLink(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as CheckChatFolderInviteLinkCommand;
  result.method = 'checkChatFolderInviteLink';
  result.params.setString('invite_link', cmd.payload.inviteLink);
}

function serializeAddChatFolderByInviteLink(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as AddChatFolderByInviteLinkCommand;
  result.method = 'addChatFolderByInviteLink';
  result.params.setString('invite_link', cmd.payload.inviteLink);
  result.params.setString('_chat_ids_json', buildChatIdArrayJson(cmd.payload.chatIds));
}

function serializeGetRecommendedChatFolders(_command: AnyAppCommand, result: SerializedCommand): void {
  result.method = 'getRecommendedChatFolders';
}

function serializeGetChatFolderInviteLinks(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetChatFolderInviteLinksCommand;
  result.method = 'getChatFolderInviteLinks';
  result.params.setNumber('chat_folder_id', cmd.payload.folderId);
}

function serializeCreateChatFolderInviteLink(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as CreateChatFolderInviteLinkCommand;
  result.method = 'createChatFolderInviteLink';
  result.params.setNumber('chat_folder_id', cmd.payload.folderId);
  result.params.setString('name', cmd.payload.name);
  result.params.setString('_chat_ids_json', buildChatIdArrayJson(cmd.payload.chatIds));
}

function serializeEditChatFolderInviteLink(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as EditChatFolderInviteLinkCommand;
  result.method = 'editChatFolderInviteLink';
  result.params.setNumber('chat_folder_id', cmd.payload.folderId);
  result.params.setString('invite_link', cmd.payload.inviteLink);
  result.params.setString('name', cmd.payload.name);
  result.params.setString('_chat_ids_json', buildChatIdArrayJson(cmd.payload.chatIds));
}

function serializeDeleteChatFolderInviteLink(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as DeleteChatFolderInviteLinkCommand;
  result.method = 'deleteChatFolderInviteLink';
  result.params.setNumber('chat_folder_id', cmd.payload.folderId);
  result.params.setString('invite_link', cmd.payload.inviteLink);
}

function serializeGetChatFolder(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetChatFolderCommand;
  result.method = 'getChatFolder';
  result.params.setNumber('chat_folder_id', cmd.payload.folderId);
}

function serializeCreateChatFolder(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as CreateChatFolderCommand;
  result.method = 'createChatFolder';
  result.params.setString('_folder_json', buildChatFolderJson(cmd.payload));
}

function serializeEditChatFolder(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as EditChatFolderCommand;
  result.method = 'editChatFolder';
  result.params.setNumber('chat_folder_id', cmd.payload.folderId);
  result.params.setString('_folder_json', buildChatFolderJson(cmd.payload.draft));
}

function serializeDeleteChatFolder(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as DeleteChatFolderCommand;
  result.method = 'deleteChatFolder';
  result.params.setNumber('chat_folder_id', cmd.payload.folderId);
  result.params.setString('_leave_chat_ids_json', '[]');
}

function serializeGetAutoDownloadSettingsPresets(_command: AnyAppCommand, result: SerializedCommand): void {
  result.method = 'getAutoDownloadSettingsPresets';
}

const AUTO_DOWNLOAD_NETWORK_TYPES: Map<string, string> = new Map<string, string>([
  ['mobile', 'networkTypeMobile'],
  ['mobileRoaming', 'networkTypeMobileRoaming'],
  ['wifi', 'networkTypeWiFi'],
  ['other', 'networkTypeOther'],
  ['none', 'networkTypeNone']
]);

function serializeSetAutoDownloadSettings(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as SetAutoDownloadSettingsCommand;
  const payload = cmd.payload;
  result.method = 'setAutoDownloadSettings';
  const networkType: string = AUTO_DOWNLOAD_NETWORK_TYPES.get(payload.networkType) ?? 'networkTypeWiFi';
  result.params.setString('_type_json', '{"@type":"' + networkType + '"}');
  result.params.setString('_settings_json',
    '{"@type":"autoDownloadSettings"' +
    ',"is_auto_download_enabled":' + (payload.isAutoDownloadEnabled ? 'true' : 'false') +
    ',"max_photo_file_size":' + payload.maxPhotoFileSize.toString() +
    ',"max_video_file_size":' + payload.maxVideoFileSize.toString() +
    ',"max_other_file_size":' + payload.maxOtherFileSize.toString() +
    ',"video_upload_bitrate":' + payload.videoUploadBitrate.toString() +
    ',"preload_large_videos":' + (payload.preloadLargeVideos ? 'true' : 'false') +
    ',"preload_next_audio":' + (payload.preloadNextAudio ? 'true' : 'false') +
    ',"preload_stories":' + (payload.preloadStories ? 'true' : 'false') +
    ',"use_less_data_for_calls":' + (payload.useLessDataForCalls ? 'true' : 'false') + '}');
}

function serializeGetStorageStatistics(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetStorageStatisticsCommand;
  result.method = 'getStorageStatistics';
  result.params.setNumber('chat_limit', cmd.payload.chatLimit);
}

function serializeGetStorageStatisticsFast(_command: AnyAppCommand, result: SerializedCommand): void {
  result.method = 'getStorageStatisticsFast';
}

function serializeOptimizeStorage(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as OptimizeStorageCommand;
  result.method = 'optimizeStorage';
  // size/ttl/count zero = release every droppable cache file (td_api.tl:14444); -1 keeps a TDLib
  // default, which is what the max-cache-size limit uses for ttl/count.
  result.params.setNumber('size', cmd.payload.size);
  result.params.setNumber('ttl', cmd.payload.ttl);
  result.params.setNumber('count', cmd.payload.count);
  result.params.setNumber('immunity_delay', cmd.payload.immunityDelay);
  result.params.setString('_file_types_json', '[]');
  result.params.setString('_chat_ids_json', '[]');
  result.params.setString('_exclude_chat_ids_json', '[]');
  result.params.setBool('return_deleted_file_statistics', false);
  result.params.setNumber('chat_limit', 0);
}

function serializeGetBlockedMessageSenders(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetBlockedMessageSendersCommand;
  result.method = 'getBlockedMessageSenders';
  result.params.setString('_block_list_json', cmd.payload.blockList === 'stories'
    ? '{"@type":"blockListStories"}' : '{"@type":"blockListMain"}');
  result.params.setNumber('offset', cmd.payload.offset);
  result.params.setNumber('limit', cmd.payload.limit);
}

function serializeSetMessageSenderBlockList(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as SetMessageSenderBlockListCommand;
  result.method = 'setMessageSenderBlockList';
  result.params.setString('_sender_id_json', cmd.payload.senderType === 'chat'
    ? '{"@type":"messageSenderChat","chat_id":' + cmd.payload.senderId.toString() + '}'
    : '{"@type":"messageSenderUser","user_id":' + cmd.payload.senderId.toString() + '}');
  // TDLib unblocks with a null block list (td_api.tl:13175); blockListMain blocks.
  result.params.setString('_block_list_json', cmd.payload.blocked ? '{"@type":"blockListMain"}' : 'null');
}

function serializeGetActiveSessions(_command: AnyAppCommand, result: SerializedCommand): void {
  result.method = 'getActiveSessions';
}

function serializeTerminateAllOtherSessions(_command: AnyAppCommand, result: SerializedCommand): void {
  result.method = 'terminateAllOtherSessions';
}

function serializeTerminateSession(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as TerminateSessionCommand;
  result.method = 'terminateSession';
  // int64 must stay a raw JSON number (decimal string) to avoid precision loss.
  result.params.setString('_session_id_json', cmd.payload.sessionId);
}

function serializeAddChatToList(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as AddChatToListCommand;
  result.method = 'addChatToList';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  const chatListJson: string = cmd.payload.chatList === 'archive'
    ? '{"@type":"chatListArchive"}'
    : (cmd.payload.chatList === 'folder'
      ? '{"@type":"chatListFolder","chat_folder_id":' + cmd.payload.folderId.toString() + '}'
      : '{"@type":"chatListMain"}');
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

function serializeTranslateText(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as TranslateTextCommand;
  result.method = 'translateText';
  result.params.setString('_text_json',
    '{"@type":"formattedText","text":"' + escapeForJson(cmd.payload.text) + '","entities":[]}');
  result.params.setString('to_language_code', cmd.payload.toLanguageCode);
}

function serializeGetMessageThread(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetMessageThreadCommand;
  result.method = 'getMessageThread';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setString('_message_id_json', cmd.payload.messageId);
}

function serializeGetMessageThreadHistory(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetMessageThreadHistoryCommand;
  result.method = 'getMessageThreadHistory';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setString('_message_id_json', cmd.payload.messageId);
  result.params.setString('_from_message_id_json', cmd.payload.fromMessageId);
  result.params.setNumber('offset', cmd.payload.offset);
  result.params.setNumber('limit', cmd.payload.limit);
}

function serializeGetMessage(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetMessageCommand;
  result.method = 'getMessage';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setString('_message_id_json', cmd.payload.messageId);
}

function serializeGetMessageProperties(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetMessagePropertiesCommand;
  result.method = 'getMessageProperties';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setString('_message_id_json', cmd.payload.messageId);
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

function serializeGetSupergroup(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetSupergroupCommand;
  result.method = 'getSupergroup';
  result.params.setNumber('supergroup_id', cmd.payload.supergroupId);
}

function serializeGetBasicGroup(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetBasicGroupCommand;
  result.method = 'getBasicGroup';
  result.params.setNumber('basic_group_id', cmd.payload.basicGroupId);
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

function serializeChangeStickerSet(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as ChangeStickerSetCommand;
  result.method = 'changeStickerSet';
  // The set id is int64: a quoted decimal string keeps every digit.
  result.params.setString('_set_id_json', JSON.stringify(cmd.payload.setId));
  result.params.setBool('is_installed', cmd.payload.isInstalled);
  result.params.setBool('is_archived', cmd.payload.isArchived);
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

// D11: comments are sent into the post's message thread (messageTopicThread).
function setTopicIdJsonIfNeeded(params: TdObject, topicThreadId: string): void {
  if (topicThreadId === undefined || topicThreadId === '' || topicThreadId === '0') {
    params.setString('_topic_id_json', 'null');
    return;
  }
  params.setString('_topic_id_json',
    '{"@type":"messageTopicThread","message_thread_id":' + topicThreadId + '}');
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
  // Callers add the surrounding quotes; keep JSON's full string escaping.
  const quoted = JSON.stringify(str);
  return quoted.substring(1, quoted.length - 1);
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

function buildEditFormattedTextJson(text: string, entities: EditMessageEntity[]): string {
  const parts: string[] = [];
  for (const entity of entities) {
    // textEntity ranges use UTF-16 code units (td_api.tl:109), as does string.length.
    if (!Number.isSafeInteger(entity.offset) || !Number.isSafeInteger(entity.length)
      || entity.offset < 0 || entity.length <= 0 || entity.offset > text.length - entity.length) {
      throw new Error('Invalid edit message entity range');
    }
    const type = TdObject.fromJSON(entity.typeJson);
    const typeName = type.getTopLevelStringStrict('@type');
    if (typeName === undefined || !/^textEntityType[A-Z][A-Za-z0-9]*$/.test(typeName)) {
      throw new Error('Invalid edit message entity type');
    }
    // TDLib's JSON contract encodes int64 as strings. Reject numeric custom emoji
    // IDs rather than silently rounding them through JSON.parse (td_json_client.h:19).
    if (typeName === 'textEntityTypeCustomEmoji') {
      const customEmojiId = type.getTopLevelStringStrict('custom_emoji_id');
      if (customEmojiId === undefined || !/^-?[1-9][0-9]{0,18}$/.test(customEmojiId)) {
        throw new Error('Invalid edit message entity type');
      }
      // CustomEmojiId::is_valid accepts every nonzero signed int64, including negative IDs.
      const magnitude = customEmojiId.startsWith('-') ? customEmojiId.substring(1) : customEmojiId;
      const maximum = customEmojiId.startsWith('-') ? '9223372036854775808' : '9223372036854775807';
      if (magnitude.length === 19 && magnitude > maximum) {
        throw new Error('Invalid edit message entity type');
      }
    }
    // Canonicalize the validated object, not raw string interpolation. toJSON()
    // on a parsed TdObject would serialize only its cache and lose type payloads.
    const typeJson = JSON.stringify(JSON.parse(entity.typeJson) as Object);
    parts.push(`{"@type":"textEntity","offset":${entity.offset},"length":${entity.length},"type":${typeJson}}`);
  }
  return `{"@type":"formattedText","text":${JSON.stringify(text)},"entities":[${parts.join(',')}]}`;
}

function buildEditLinkPreviewOptionsJson(options: EditMessageLinkPreviewOptions): string {
  return '{"@type":"linkPreviewOptions","is_disabled":' + JSON.stringify(options.isDisabled)
    + ',"url":' + JSON.stringify(options.url)
    + ',"force_small_media":' + JSON.stringify(options.forceSmallMedia)
    + ',"force_large_media":' + JSON.stringify(options.forceLargeMedia)
    + ',"show_above_text":' + JSON.stringify(options.showAboveText) + '}';
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

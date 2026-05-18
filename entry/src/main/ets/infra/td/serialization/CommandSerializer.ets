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
  OpenChatCommand,
  SendMessageCommand,
  SendMediaMessageCommand,
  EditMessageTextCommand,
  DeleteMessagesCommand,
  ForwardMessagesCommand,
  SetChatMuteCommand,
  PinChatMessageCommand,
  UnpinChatMessageCommand,
  DeleteChatHistoryCommand,
  ToggleChatIsMarkedAsUnreadCommand,
  SearchChatMessagesCommand,
  ViewMessagesCommand,
  GetChatHistoryCommand,
  GetUserCommand,
  SearchCallMessagesCommand,
  GetChatCommand,
  CloseChatCommand,
  GetUserFullInfoCommand,
  GetSupergroupFullInfoCommand,
  DownloadFileCommand,
  CancelDownloadFileCommand
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
COMMAND_SERIALIZATION_HANDLERS.set('openChat', serializeOpenChat);
COMMAND_SERIALIZATION_HANDLERS.set('sendMessage', serializeSendMessage);
COMMAND_SERIALIZATION_HANDLERS.set('sendMediaMessage', serializeSendMediaMessage);
COMMAND_SERIALIZATION_HANDLERS.set('editMessageText', serializeEditMessageText);
COMMAND_SERIALIZATION_HANDLERS.set('deleteMessages', serializeDeleteMessages);
COMMAND_SERIALIZATION_HANDLERS.set('forwardMessages', serializeForwardMessages);
COMMAND_SERIALIZATION_HANDLERS.set('setChatMute', serializeSetChatMute);
COMMAND_SERIALIZATION_HANDLERS.set('pinChatMessage', serializePinChatMessage);
COMMAND_SERIALIZATION_HANDLERS.set('unpinChatMessage', serializeUnpinChatMessage);
COMMAND_SERIALIZATION_HANDLERS.set('deleteChatHistory', serializeDeleteChatHistory);
COMMAND_SERIALIZATION_HANDLERS.set('toggleChatIsMarkedAsUnread', serializeToggleChatIsMarkedAsUnread);
COMMAND_SERIALIZATION_HANDLERS.set('searchChatMessages', serializeSearchChatMessages);
COMMAND_SERIALIZATION_HANDLERS.set('viewMessages', serializeViewMessages);
COMMAND_SERIALIZATION_HANDLERS.set('getChatHistory', serializeGetChatHistory);
COMMAND_SERIALIZATION_HANDLERS.set('getUser', serializeGetUser);
COMMAND_SERIALIZATION_HANDLERS.set('searchCallMessages', serializeSearchCallMessages);
COMMAND_SERIALIZATION_HANDLERS.set('getChat', serializeGetChat);
COMMAND_SERIALIZATION_HANDLERS.set('closeChat', serializeCloseChat);
COMMAND_SERIALIZATION_HANDLERS.set('getUserFullInfo', serializeGetUserFullInfo);
COMMAND_SERIALIZATION_HANDLERS.set('getSupergroupFullInfo', serializeGetSupergroupFullInfo);
COMMAND_SERIALIZATION_HANDLERS.set('downloadFile', serializeDownloadFile);
COMMAND_SERIALIZATION_HANDLERS.set('cancelDownloadFile', serializeCancelDownloadFile);
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
  result.params.setString('_chat_list_json', '{"@type":"chatListMain"}');
  result.params.setNumber('limit', cmd.payload.limit);
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
  const inputContentJson = `{"@type":"inputMessageText","text":{"@type":"formattedText","text":"${text}","entities":[]},"clear_draft":true}`;
  result.params.setString('_input_message_content_json', inputContentJson);
  setReplyToJsonIfNeeded(result.params, cmd.payload.replyToMessageId);
}

function serializeSendMediaMessage(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as SendMediaMessageCommand;
  result.method = 'sendMessage';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setString('_input_message_content_json',
    buildMediaInputContentJson(cmd.payload.mediaKind, cmd.payload.localPath, cmd.payload.caption));
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

function serializeSearchChatMessages(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as SearchChatMessagesCommand;
  result.method = 'searchChatMessages';
  result.params.setNumber('chat_id', cmd.payload.chatId);
  result.params.setString('query', cmd.payload.query);
  result.params.setString('_from_message_id_json', cmd.payload.fromMessageId);
  result.params.setNumber('offset', cmd.payload.offset);
  result.params.setNumber('limit', cmd.payload.limit);
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

function serializeSearchCallMessages(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as SearchCallMessagesCommand;
  result.method = 'searchCallMessages';
  result.params.setString('_from_message_id_json', cmd.payload.fromMessageId);
  result.params.setNumber('limit', cmd.payload.limit);
  result.params.setBool('only_missed', cmd.payload.onlyMissed);
}

function serializeGetChat(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as GetChatCommand;
  result.method = 'getChat';
  result.params.setNumber('chat_id', cmd.payload.chatId);
}

function serializeCloseChat(command: AnyAppCommand, result: SerializedCommand): void {
  const cmd = command as CloseChatCommand;
  result.method = 'closeChat';
  result.params.setNumber('chat_id', cmd.payload.chatId);
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

function buildFormattedTextJson(text: string): string {
  const escapedText = escapeForJson(text);
  return `{"@type":"formattedText","text":"${escapedText}","entities":[]}`;
}

function buildInputFileLocalJson(localPath: string): string {
  const escapedPath = escapeForJson(localPath);
  return `{"@type":"inputFileLocal","path":"${escapedPath}"}`;
}

function buildMediaInputContentJson(mediaKind: string, localPath: string, caption: string): string {
  const fileJson = buildInputFileLocalJson(localPath);
  const captionJson = buildFormattedTextJson(caption);

  switch (mediaKind) {
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

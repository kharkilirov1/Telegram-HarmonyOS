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
  RequestQrCodeAuthCommand
} from '../../../core/model/AppCommand';
import { TdObject } from '../../../models/TdTypes';

const TAG = 'CommandSerializer';
const DOMAIN = 0x000C;

/**
 * Результат сериализации команды.
 */
export class SerializedCommand {
  method: string = '';
  params: TdObject = new TdObject();
}

/**
 * Сериализует AnyAppCommand в TDLib запрос.
 *
 * @param command - команда из use case
 * @returns SerializedCommand с method и params
 */
export function serializeCommand(command: AnyAppCommand): SerializedCommand {
  const result = new SerializedCommand();

  switch (command.type) {
    case 'setPhoneNumber': {
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
      break;
    }

    case 'checkAuthCode': {
      const cmd = command as CheckAuthCodeCommand;
      result.method = 'checkAuthenticationCode';
      result.params.setString('code', cmd.payload.code);
      break;
    }

    case 'checkAuthPassword': {
      const cmd = command as CheckAuthPasswordCommand;
      result.method = 'checkAuthenticationPassword';
      result.params.setString('password', cmd.payload.password);
      break;
    }

    case 'requestPasswordRecovery': {
      result.method = 'requestAuthenticationPasswordRecovery';
      break;
    }

    case 'resendAuthCode': {
      result.method = 'resendAuthenticationCode';
      break;
    }

    case 'loadChats': {
      const cmd = command as LoadChatsCommand;
      result.method = 'loadChats';
      // TDLib 1.8+: loadChats(chat_list, limit) — загружает чаты, шлёт updateNewChat
      result.params.setString('_chat_list_json', '{"@type":"chatListMain"}');
      result.params.setNumber('limit', cmd.payload.limit);
      break;
    }

    case 'openChat': {
      const cmd = command as OpenChatCommand;
      result.method = 'openChat';
      result.params.setNumber('chat_id', cmd.payload.chatId);
      break;
    }

    case 'sendMessage': {
      const cmd = command as SendMessageCommand;
      result.method = 'sendMessage';
      result.params.setNumber('chat_id', cmd.payload.chatId);

      // input_message_content — вложенный объект
      // Для ArkTS compliance создаём как отдельную строку JSON
      // и добавляем в rawJson (workaround для вложенных объектов)
      const text = escapeForJson(cmd.payload.text);
      const inputContentJson = `{"@type":"inputMessageText","text":{"@type":"formattedText","text":"${text}","entities":[]},"clear_draft":true}`;

      // Добавляем как raw для toJSON
      result.params.setString('_input_message_content_json', inputContentJson);

      // reply_to если указан
      const replyToId = cmd.payload.replyToMessageId;
      if (replyToId && replyToId !== '0') {
        const replyJson = `{"@type":"inputMessageReplyToMessage","message_id":${replyToId}}`;
        result.params.setString('_reply_to_json', replyJson);
      }
      break;
    }

    case 'editMessageText': {
      const cmd = command as EditMessageTextCommand;
      result.method = 'editMessageText';
      result.params.setNumber('chat_id', cmd.payload.chatId);
      result.params.setString('_message_id_json', cmd.payload.messageId);
      const text = escapeForJson(cmd.payload.text);
      const inputContentJson = `{"@type":"inputMessageText","text":{"@type":"formattedText","text":"${text}","entities":[]},"clear_draft":true}`;
      result.params.setString('_input_message_content_json', inputContentJson);
      break;
    }

    case 'deleteMessages': {
      const cmd = command as DeleteMessagesCommand;
      result.method = 'deleteMessages';
      result.params.setNumber('chat_id', cmd.payload.chatId);
      const idsJson = '[' + cmd.payload.messageIds.join(',') + ']';
      result.params.setString('_message_ids_json', idsJson);
      result.params.setBool('revoke', cmd.payload.revoke);
      break;
    }

    case 'forwardMessages': {
      const cmd = command as ForwardMessagesCommand;
      result.method = 'forwardMessages';
      result.params.setNumber('chat_id', cmd.payload.chatId);
      result.params.setNumber('from_chat_id', cmd.payload.fromChatId);
      const idsJson = '[' + cmd.payload.messageIds.join(',') + ']';
      result.params.setString('_message_ids_json', idsJson);
      result.params.setBool('send_copy', cmd.payload.sendCopy);
      result.params.setBool('remove_caption', cmd.payload.removeCaption);
      break;
    }

    case 'setChatMute': {
      const cmd = command as SetChatMuteCommand;
      result.method = 'setChatNotificationSettings';
      result.params.setNumber('chat_id', cmd.payload.chatId);
      const settingsJson = `{"@type":"chatNotificationSettings","use_default_mute_for":false,"mute_for":${cmd.payload.muteForSeconds}}`;
      result.params.setString('_notification_settings_json', settingsJson);
      break;
    }

    case 'pinChatMessage': {
      const cmd = command as PinChatMessageCommand;
      result.method = 'pinChatMessage';
      result.params.setNumber('chat_id', cmd.payload.chatId);
      result.params.setString('_message_id_json', cmd.payload.messageId);
      result.params.setBool('disable_notification', cmd.payload.disableNotification);
      result.params.setBool('only_for_self', cmd.payload.onlyForSelf);
      break;
    }

    case 'unpinChatMessage': {
      const cmd = command as UnpinChatMessageCommand;
      result.method = 'unpinChatMessage';
      result.params.setNumber('chat_id', cmd.payload.chatId);
      result.params.setString('_message_id_json', cmd.payload.messageId);
      break;
    }

    case 'deleteChatHistory': {
      const cmd = command as DeleteChatHistoryCommand;
      result.method = 'deleteChatHistory';
      result.params.setNumber('chat_id', cmd.payload.chatId);
      result.params.setBool('remove_from_chat_list', cmd.payload.removeFromChatList);
      result.params.setBool('revoke', cmd.payload.revoke);
      break;
    }

    case 'toggleChatIsMarkedAsUnread': {
      const cmd = command as ToggleChatIsMarkedAsUnreadCommand;
      result.method = 'toggleChatIsMarkedAsUnread';
      result.params.setNumber('chat_id', cmd.payload.chatId);
      result.params.setBool('is_marked_as_unread', cmd.payload.isMarkedAsUnread);
      break;
    }

    case 'searchChatMessages': {
      const cmd = command as SearchChatMessagesCommand;
      result.method = 'searchChatMessages';
      result.params.setNumber('chat_id', cmd.payload.chatId);
      result.params.setString('query', cmd.payload.query);
      result.params.setString('_from_message_id_json', cmd.payload.fromMessageId);
      result.params.setNumber('offset', cmd.payload.offset);
      result.params.setNumber('limit', cmd.payload.limit);
      break;
    }

    case 'viewMessages': {
      const cmd = command as ViewMessagesCommand;
      result.method = 'viewMessages';
      result.params.setNumber('chat_id', cmd.payload.chatId);
      // message_ids — массив int64
      const idsJson = '[' + cmd.payload.messageIds.join(',') + ']';
      result.params.setString('_message_ids_json', idsJson);
      result.params.setBool('force_read', true);
      break;
    }

    case 'getChatHistory': {
      const cmd = command as GetChatHistoryCommand;
      result.method = 'getChatHistory';
      result.params.setNumber('chat_id', cmd.payload.chatId);
      // int64 must be kept as raw json number to avoid precision loss in JS number.
      result.params.setString('_from_message_id_json', cmd.payload.fromMessageId);
      result.params.setNumber('offset', cmd.payload.offset);
      result.params.setNumber('limit', cmd.payload.limit);
      result.params.setBool('only_local', cmd.payload.onlyLocal);
      break;
    }

    case 'getUser': {
      const cmd = command as GetUserCommand;
      result.method = 'getUser';
      result.params.setNumber('user_id', cmd.payload.userId);
      break;
    }

    case 'searchCallMessages': {
      const cmd = command as SearchCallMessagesCommand;
      result.method = 'searchCallMessages';
      result.params.setString('_from_message_id_json', cmd.payload.fromMessageId);
      result.params.setNumber('limit', cmd.payload.limit);
      result.params.setBool('only_missed', cmd.payload.onlyMissed);
      break;
    }

    case 'getChat': {
      const cmd = command as GetChatCommand;
      result.method = 'getChat';
      result.params.setNumber('chat_id', cmd.payload.chatId);
      break;
    }

    case 'closeChat': {
      const cmd = command as CloseChatCommand;
      result.method = 'closeChat';
      result.params.setNumber('chat_id', cmd.payload.chatId);
      break;
    }

    case 'getUserFullInfo': {
      const cmd = command as GetUserFullInfoCommand;
      result.method = 'getUserFullInfo';
      result.params.setNumber('user_id', cmd.payload.userId);
      break;
    }

    case 'getSupergroupFullInfo': {
      const cmd = command as GetSupergroupFullInfoCommand;
      result.method = 'getSupergroupFullInfo';
      result.params.setNumber('supergroup_id', cmd.payload.supergroupId);
      break;
    }

    case 'downloadFile': {
      const cmd = command as DownloadFileCommand;
      result.method = 'downloadFile';
      result.params.setNumber('file_id', cmd.payload.fileId);
      result.params.setNumber('priority', cmd.payload.priority);
      result.params.setBool('synchronous', cmd.payload.synchronous);
      break;
    }

    case 'requestQrCodeAuth': {
      result.method = 'requestQrCodeAuthentication';
      break;
    }

    // Сброс auth state на сервере — аналог auth.cancelCode в raw MTProto (Android TL_auth_cancelCode).
    // TDLib после logOut автоматически присылает updateAuthorizationState: waitPhoneNumber.
    case 'logout': {
      result.method = 'logOut';
      break;
    }

    default:
      hilog.warn(DOMAIN, TAG, 'Unknown command type: %{public}s', command.type);
      result.method = '';
      break;
  }

  return result;
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

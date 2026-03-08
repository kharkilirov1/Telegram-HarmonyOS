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
  ViewMessagesCommand,
  GetChatHistoryCommand,
  GetUserCommand,
  SearchCallMessagesCommand,
  GetChatCommand,
  CloseChatCommand
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

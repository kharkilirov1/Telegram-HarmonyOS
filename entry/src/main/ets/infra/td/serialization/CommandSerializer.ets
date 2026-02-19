// CommandSerializer — маппинг AnyAppCommand → TDLib JSON
//
// Каждая команда из core/model/AppCommand преобразуется в JSON-объект,
// который TdGateway.send() отправляет в нативный TDLib.
//
// Референс TDLib API: https://core.telegram.org/tdlib/docs/

import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  AnyAppCommand,
  SetPhoneNumberCommand,
  CheckAuthCodeCommand,
  CheckAuthPasswordCommand,
  LoadChatsCommand,
  OpenChatCommand,
  SendMessageCommand,
  ViewMessagesCommand
} from '../../../core/model/AppCommand';

const TAG = 'CommandSerializer';
const DOMAIN = 0x000C;

// Явные интерфейсы для параметров команд (согласно рекомендациям Huawei)
interface SendMessageParams {
  chat_id: number;
  input_message_content: InputMessageContent;
  reply_to?: ReplyToMessage;
}

interface InputMessageContent {
  '@type': string;
  text: FormattedText;
  clear_draft: boolean;
}

interface FormattedText {
  '@type': string;
  text: string;
  entities: unknown[];
}

interface ReplyToMessage {
  '@type': string;
  message_id: string;
}

export class SerializedCommand {
  method: string = '';
  chat_id: number = 0;
  input_message_content?: InputMessageContent;
  reply_to?: ReplyToMessage;
}

export function serializeCommand(command: AnyAppCommand): SerializedCommand {
  const result = new SerializedCommand();

  switch (command.type) {
    case 'setPhoneNumber': {
      const cmd = command as SetPhoneNumberCommand;
      result.method = 'setAuthenticationPhoneNumber';
      result.chat_id = 0;
      // inline settings - не требует отдельного интерфейса
      break;
    }

    case 'checkAuthCode': {
      const cmd = command as CheckAuthCodeCommand;
      result.method = 'checkAuthenticationCode';
      result.chat_id = 0;
      break;
    }

    case 'checkAuthPassword': {
      const cmd = command as CheckAuthPasswordCommand;
      result.method = 'checkAuthenticationPassword';
      result.chat_id = 0;
      break;
    }

    case 'loadChats': {
      const cmd = command as LoadChatsCommand;
      result.method = 'getChats';
      result.chat_id = 0;
      break;
    }

    case 'openChat': {
      const cmd = command as OpenChatCommand;
      result.method = 'openChat';
      result.chat_id = cmd.payload.chatId;
      break;
    }

    case 'sendMessage': {
      const cmd = command as SendMessageCommand;
      result.method = 'sendMessage';
      result.chat_id = cmd.payload.chatId;
      
      const inputContent: InputMessageContent = {
        '@type': 'inputMessageText',
        text: {
          '@type': 'formattedText',
          text: cmd.payload.text,
          entities: []
        },
        clear_draft: true
      };
      result.input_message_content = inputContent;

      // Точечный доступ - согласно рекомендациям Huawei
      const replyToId = cmd.payload.replyToMessageId;
      if (replyToId && replyToId !== '0') {
        result.reply_to = {
          '@type': 'inputMessageReplyToMessage',
          message_id: replyToId
        };
      }
      break;
    }

    case 'viewMessages': {
      const cmd = command as ViewMessagesCommand;
      result.method = 'viewMessages';
      result.chat_id = cmd.payload.chatId;
      break;
    }

    default:
      hilog.warn(DOMAIN, TAG, 'Unknown command type: %{public}s', command.type);
      result.method = '';
      break;
  }

  return result;
}

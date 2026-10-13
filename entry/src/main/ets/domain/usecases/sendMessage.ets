// SendMessage use case - sends text message via TDLib
// TDLib handles optimistic updates: updateNewMessage (pending) → updateMessageSendSucceeded

import { hilog } from '@kit.PerformanceAnalysisKit';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { ChatId, MessageId } from '../../core/model/EntityId';
import { createSendMessageCommand, CustomEmojiTextEntity } from '../../core/model/AppCommand';
import { AppError, AppErrorKind, asWriteRequestError, isSilentTdlibError } from '../../core/model/AppError';
import { TdObject } from '../../core/utils/tdAccessors';

const TAG = 'SendMessage';
const DOMAIN = 0x0007;

// Huawei Best Practice: константы для валидации
const MAX_MESSAGE_LENGTH = 4096;  // Telegram limit
const MIN_MESSAGE_LENGTH = 1;

export class SendMessageParams {
  chatId: ChatId = 0;
  text: string = '';
  replyToMessageId: MessageId = '0';
  customEmojiEntities: CustomEmojiTextEntity[] = [];
}

/**
 * Результат валидации параметров.
 * Huawei Best Practice: явные типы вместо boolean | string.
 */
export class ValidationResult {
  isValid: boolean = true;
  errorMessage: string = '';
}

/**
 * Валидация параметров согласно ArkTS Best Practices.
 */
function validateSendMessageParams(params: SendMessageParams): ValidationResult {
  const result = new ValidationResult();

  // Проверка chatId
  if (!params.chatId || params.chatId === 0) {
    result.isValid = false;
    result.errorMessage = 'Invalid chatId: must be non-zero';
    return result;
  }

  // Проверка текста
  if (!params.text || params.text.length < MIN_MESSAGE_LENGTH) {
    result.isValid = false;
    result.errorMessage = 'Message text is empty';
    return result;
  }

  if (params.text.length > MAX_MESSAGE_LENGTH) {
    result.isValid = false;
    result.errorMessage = `Message too long: ${params.text.length} > ${MAX_MESSAGE_LENGTH}`;
    return result;
  }

  return result;
}

export class SendMessageUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  /**
   * Отправить текстовое сообщение.
   * TDLib сам пришлёт updateNewMessage (pending) → updateMessageSendSucceeded.
   * Optimistic update не нужен — TDLib возвращает сообщение сразу через update stream.
   */
  async execute(params: SendMessageParams): Promise<void> {
    // Валидация параметров
    const validation = validateSendMessageParams(params);
    if (!validation.isValid) {
      throw new AppError(
        AppErrorKind.TDLIB_ERROR,
        validation.errorMessage,
        'Input validation failed',
        400,
        false
      );
    }

    try {
      hilog.info(DOMAIN, TAG, 'Sending message to chat %{public}d', params.chatId);

      const command = createSendMessageCommand(
        params.chatId,
        params.text,
        params.replyToMessageId,
        params.customEmojiEntities
      );

      const response = await this.gateway.send(command);
      const id = response instanceof TdObject ? response.getTopLevelNumberStrict('id') : undefined;
      if (!(response instanceof TdObject) || response.getTopLevelStringStrict('@type') !== 'message' ||
        response.getTopLevelNumberStrict('chat_id') !== params.chatId || id === undefined ||
        !Number.isSafeInteger(id) || id <= 0) {
        throw new AppError(AppErrorKind.UNKNOWN, 'Sending result unknown', 'Invalid sendMessage acceptance response');
      }

      hilog.info(DOMAIN, TAG, 'Message sent successfully');
      // TDLib will send updateNewMessage + updateMessageSendSucceeded via event pipeline

    } catch (error) {
      const failure = asWriteRequestError(error, 'Could not send message');
      if (!isSilentTdlibError(failure)) {
        hilog.error(DOMAIN, TAG, 'Failed to send message: %{public}s', failure.message);
      }
      throw failure;
    }
  }

}

// Factory function
export function createSendMessageUseCase(
  gateway: TdGatewayPort
): SendMessageUseCase {
  return new SendMessageUseCase(gateway);
}

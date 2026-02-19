// SendMessage use case - handles sending messages with optimistic updates
// Business logic for message sending with error handling and retries

import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStore } from '../../core/store/AppStore';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { ChatId, MessageId } from '../../core/model/EntityId';
import { createSendMessageCommand } from '../../core/model/AppCommand';
import { createNewMessageEvent } from '../../core/model/AppEvent';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { MessageDto, MessageContentDto, MessageContentType } from '../../core/model/dto/MessageDto';

const TAG = 'SendMessage';
const DOMAIN = 0x0007;

// Huawei Best Practice: константы для валидации
const MAX_MESSAGE_LENGTH = 4096;  // Telegram limit
const MIN_MESSAGE_LENGTH = 1;

export interface SendMessageParams {
  chatId: ChatId;
  text: string;
  replyToMessageId?: MessageId;
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
  private store: AppStore;
  private gateway: TdGatewayPort;

  constructor(store: AppStore, gateway: TdGatewayPort) {
    this.store = store;
    this.gateway = gateway;
  }

  /**
   * Отправить сообщение с optimistic update.
   * Huawei Best Practice: валидация входных параметров перед операцией.
   */
  async execute(params: SendMessageParams): Promise<MessageId> {
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

      // 1. Generate temporary message ID for optimistic update
      const tempMessageId = this.generateTempMessageId();

      // 2. Create optimistic update in store
      const messageDto = new MessageDto();
      messageDto.id = tempMessageId;
      messageDto.chatId = params.chatId;
      messageDto.isOutgoing = true;
      messageDto.isPending = true;
      const contentDto = new MessageContentDto();
      contentDto.type = MessageContentType.TEXT;
      contentDto.text = params.text;
      messageDto.content = contentDto;
      await this.store.dispatch(createNewMessageEvent(
        params.chatId,
        tempMessageId,
        messageDto
      ));

      // 3. Send actual command to TDLib
      const command = createSendMessageCommand(
        params.chatId,
        params.text,
        params.replyToMessageId
      );

      const response = await this.gateway.send(command);

      hilog.info(DOMAIN, TAG, 'Message sent successfully');

      // 4. Handle response - update message status from pending to sent
      // This is handled by normalizer when we receive updateMessageSendSucceeded
      return tempMessageId;

    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Failed to send message: %{public}s', err.message);

      throw new AppError(
        AppErrorKind.UNKNOWN,
        `Failed to send message to chat ${params.chatId}`,
        err.message,
        0,
        true
      );
    }
  }

  /**
   * Генерирует временный ID для optimistic updates.
   * Huawei Best Practice: MessageId = string для int64 совместимости.
   * Формат: pending_{timestamp}_{random} — уникальный и типобезопасный.
   */
  private generateTempMessageId(): MessageId {
    const timestamp = Date.now();
    const random = Math.random().toString(36).slice(2, 9);
    return `pending_${timestamp}_${random}`;
  }

  /**
   * Повторить отправку неудавшегося сообщения.
   */
  async retryMessage(tempMessageId: MessageId, params: SendMessageParams): Promise<MessageId> {
    hilog.info(DOMAIN, TAG, 'Retrying message %{public}s', tempMessageId);
    return this.execute(params);
  }

  /**
   * Отменить pending сообщение.
   * TODO: Dispatch event to remove pending message from store
   */
  async cancelMessage(tempMessageId: MessageId, chatId: ChatId): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Cancelling message %{public}s in chat %{public}d', tempMessageId, chatId);
    // Реализация будет добавлена когда будет готов MessagesDeletedEvent для pending
  }
}

// Factory function for convenience
export function createSendMessageUseCase(
  store: AppStore,
  gateway: TdGatewayPort
): SendMessageUseCase {
  return new SendMessageUseCase(store, gateway);
}

// SendMediaMessage use case - sends local photo/video/document files via TDLib.
// Picker URI preparation stays UI/platform-owned; this use case accepts a TDLib-readable local path.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { ChatId, MessageId } from '../../core/model/EntityId';
import { createSendMediaMessageCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';

const TAG = 'SendMediaMessage';
const DOMAIN = 0x0007;
const MAX_CAPTION_LENGTH = 4096;

export class SendMediaMessageParams {
  chatId: ChatId = 0;
  mediaKind: string = 'document';
  localPath: string = '';
  caption: string = '';
  replyToMessageId: MessageId = '0';
}

class MediaValidationResult {
  isValid: boolean = true;
  errorMessage: string = '';
}

function validateSendMediaMessageParams(params: SendMediaMessageParams): MediaValidationResult {
  const result = new MediaValidationResult();

  if (!params.chatId || params.chatId === 0) {
    result.isValid = false;
    result.errorMessage = 'Invalid chatId: must be non-zero';
    return result;
  }

  if (!isSupportedMediaKind(params.mediaKind)) {
    result.isValid = false;
    result.errorMessage = `Unsupported media kind: ${params.mediaKind}`;
    return result;
  }

  if (!params.localPath || params.localPath.trim().length === 0) {
    result.isValid = false;
    result.errorMessage = 'Media local path is empty';
    return result;
  }

  if (params.caption.length > MAX_CAPTION_LENGTH) {
    result.isValid = false;
    result.errorMessage = `Caption too long: ${params.caption.length} > ${MAX_CAPTION_LENGTH}`;
    return result;
  }

  return result;
}

function isSupportedMediaKind(mediaKind: string): boolean {
  return mediaKind === 'photo' || mediaKind === 'video' || mediaKind === 'document';
}

export class SendMediaMessageUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async execute(params: SendMediaMessageParams): Promise<void> {
    const validation = validateSendMediaMessageParams(params);
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
      hilog.info(DOMAIN, TAG, 'Sending %{public}s media to chat %{public}d',
        params.mediaKind, params.chatId);

      const command = createSendMediaMessageCommand(
        params.chatId,
        params.mediaKind,
        params.localPath,
        params.caption,
        params.replyToMessageId
      );

      await this.gateway.send(command);

      hilog.info(DOMAIN, TAG, 'Media message send request completed');
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Failed to send media message: %{public}s', err.message);

      throw new AppError(
        AppErrorKind.UNKNOWN,
        `Failed to send media message to chat ${params.chatId}`,
        err.message,
        0,
        true
      );
    }
  }
}

export function createSendMediaMessageUseCase(
  gateway: TdGatewayPort
): SendMediaMessageUseCase {
  return new SendMediaMessageUseCase(gateway);
}

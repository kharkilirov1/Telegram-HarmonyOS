// D24: message translation. TDLib: translateText(formattedText, to_language_code) = FormattedText.
// iOS counterpart: ChatController translation action with a cached translated-text presentation.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { createTranslateTextCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { TdObject, tdGetArray, tdGetString } from '../../core/utils/tdAccessors';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x004D;
const TAG = 'TranslateMessage';
export const MAX_TRANSLATE_TEXT_LENGTH = 4096;

// BCP-47-ish codes TDLib accepts: "en", "de", "pt-BR".
export function isValidLanguageCode(code: string): boolean {
  return /^[a-z]{2,3}(-[A-Za-z0-9]{2,8})?$/.test(code);
}

export class TranslatedText {
  text: string = '';
  entityCount: number = 0;
}

// The response is a formattedText; the UI renders plain text and keeps the entity count for diagnostics.
export function createTranslatedTextFromTd(td: TdObject): TranslatedText | undefined {
  if (td.getTopLevelStringStrict('@type') !== 'formattedText') {
    return undefined;
  }
  const result = new TranslatedText();
  const text = tdGetString(td, 'text');
  result.text = text ?? '';
  const entities = tdGetArray(td, 'entities');
  result.entityCount = entities !== undefined ? entities.length : 0;
  return result;
}

export class TranslateMessageUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async translate(text: string, toLanguageCode: string): Promise<TranslatedText> {
    const trimmed = text.trim();
    if (trimmed.length === 0 || trimmed.length > MAX_TRANSLATE_TEXT_LENGTH) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Nothing to translate', 'Input validation failed',
        400, false);
    }
    if (!isValidLanguageCode(toLanguageCode)) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid target language', 'Input validation failed',
        400, false);
    }
    try {
      const command = createTranslateTextCommand(trimmed, toLanguageCode);
      const response = await this.gateway.send(command) as TdObject;
      const translated = createTranslatedTextFromTd(response);
      if (translated === undefined || translated.text.length === 0) {
        throw new AppError(AppErrorKind.UNKNOWN, 'Translation unavailable', 'Unsupported translate response',
          0, false);
      }
      return translated;
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'translateText failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to translate the message', err.message, 0, true);
    }
  }
}

export function createTranslateMessageUseCase(gateway: TdGatewayPort): TranslateMessageUseCase {
  return new TranslateMessageUseCase(gateway);
}

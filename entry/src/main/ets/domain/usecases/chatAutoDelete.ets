// Chat auto-delete timer use case (D20).
// TDLib: chat.message_auto_delete_time (int32, seconds) and setChatMessageAutoDeleteTime
// (td_api.tl). 0 disables the timer; the UI offers the iOS presets but accepts any non-negative value.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { ChatId } from '../../core/model/EntityId';
import { createGetChatCommand, createSetChatMessageAutoDeleteTimeCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { TdObject } from '../../models/TdTypes';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x0046;
const TAG = 'ChatAutoDelete';

// TDLib rejects absurd timers; a year is a safe inclusive upper bound for the local validation.
export const MAX_AUTO_DELETE_SECONDS: number = 366 * 24 * 60 * 60;

export const AUTO_DELETE_PRESETS: number[] = [0, 3600, 86400, 7 * 86400, 30 * 86400];

export function isValidAutoDeleteSeconds(seconds: number): boolean {
  return Number.isSafeInteger(seconds) && seconds >= 0 && seconds <= MAX_AUTO_DELETE_SECONDS;
}

export class ChatAutoDeleteUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async load(chatId: ChatId): Promise<number> {
    this.validateChatId(chatId);
    try {
      const response = await this.gateway.send(createGetChatCommand(chatId)) as TdObject;
      if (response.getTopLevelStringStrict('@type') !== 'chat') {
        throw new AppError(AppErrorKind.UNKNOWN, 'Unsupported chat response', 'Unexpected @type', 0,
          false);
      }
      const seconds = response.getTopLevelNumberStrict('message_auto_delete_time');
      if (typeof seconds !== 'number' || !isValidAutoDeleteSeconds(seconds)) {
        throw new AppError(AppErrorKind.UNKNOWN, 'Chat has no auto-delete timer',
          'Missing message_auto_delete_time', 0, false);
      }
      return seconds;
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Auto-delete load failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to load auto-delete timer', err.message, 0, true);
    }
  }

  async set(chatId: ChatId, seconds: number): Promise<void> {
    this.validateChatId(chatId);
    if (!isValidAutoDeleteSeconds(seconds)) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid auto-delete time', 'Input validation failed',
        400, false);
    }
    try {
      await this.gateway.send(createSetChatMessageAutoDeleteTimeCommand(chatId, seconds));
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Auto-delete save failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to save auto-delete timer', err.message, 0, true);
    }
  }

  private validateChatId(chatId: ChatId): void {
    if (!Number.isSafeInteger(chatId) || chatId <= 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400, false);
    }
  }
}

export function createChatAutoDeleteUseCase(gateway: TdGatewayPort): ChatAutoDeleteUseCase {
  return new ChatAutoDeleteUseCase(gateway);
}

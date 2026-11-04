// Scheduled messages use case (D21).
// TDLib: getChatScheduledMessages (td_api.tl:10973), editMessageSchedulingState (:11254) with a null
// state to send now, and deleteMessages to cancel a scheduled message (scheduled ids are int64 strings,
// which the serializer already emits as raw decimal numbers).

import { hilog } from '@kit.PerformanceAnalysisKit';
import { ChatId } from '../../core/model/EntityId';
import {
  createDeleteMessagesCommand,
  createEditMessageSchedulingStateCommand,
  createGetChatScheduledMessagesCommand
} from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import {
  ScheduledMessagesDto,
  createScheduledMessagesFromTd
} from '../../core/model/dto/ScheduledMessageDto';
import { TdObject } from '../../models/TdTypes';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x0047;
const TAG = 'ScheduledMessages';

// TDLib schedules at most ~367 days ahead; keep one day of slack for clock skew.
export const MAX_SCHEDULE_AHEAD_SECONDS: number = 367 * 24 * 60 * 60;

export function isValidScheduledId(messageId: string): boolean {
  return /^[1-9][0-9]{0,18}$/.test(messageId);
}

export function isValidScheduleDate(sendDate: number, nowSeconds: number): boolean {
  if (!Number.isSafeInteger(sendDate) || !Number.isSafeInteger(nowSeconds)) {
    return false;
  }
  return sendDate > nowSeconds && sendDate <= nowSeconds + MAX_SCHEDULE_AHEAD_SECONDS;
}

export class ScheduledMessagesUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async load(chatId: ChatId): Promise<ScheduledMessagesDto> {
    this.validateChatId(chatId);
    try {
      const command = createGetChatScheduledMessagesCommand(chatId);
      const response = await this.gateway.send(command) as TdObject;
      const parsed = createScheduledMessagesFromTd(response);
      if (parsed === undefined) {
        throw new AppError(AppErrorKind.UNKNOWN, 'Unsupported scheduled messages response',
          'Unexpected @type', 0, false);
      }
      return parsed;
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Scheduled messages load failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to load scheduled messages', err.message, 0,
        true);
    }
  }

  // null scheduling state = deliver immediately.
  async sendNow(chatId: ChatId, messageId: string): Promise<void> {
    this.validateChatId(chatId);
    if (!isValidScheduledId(messageId)) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid message id', 'Input validation failed',
        400, false);
    }
    await this.editState(chatId, messageId, 0);
  }

  async reschedule(chatId: ChatId, messageId: string, sendDate: number, nowSeconds: number):
    Promise<void> {
    this.validateChatId(chatId);
    if (!isValidScheduledId(messageId)) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid message id', 'Input validation failed',
        400, false);
    }
    if (!isValidScheduleDate(sendDate, nowSeconds)) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid schedule date', 'Input validation failed',
        400, false);
    }
    await this.editState(chatId, messageId, sendDate);
  }

  async cancel(chatId: ChatId, messageId: string): Promise<void> {
    this.validateChatId(chatId);
    if (!isValidScheduledId(messageId)) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid message id', 'Input validation failed',
        400, false);
    }
    try {
      await this.gateway.send(createDeleteMessagesCommand(chatId, [messageId], false));
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Scheduled message cancel failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to cancel the scheduled message', err.message,
        0, true);
    }
  }

  private async editState(chatId: ChatId, messageId: string, sendDate: number): Promise<void> {
    try {
      await this.gateway.send(createEditMessageSchedulingStateCommand(chatId, messageId, sendDate));
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Scheduling state edit failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to update the scheduled message', err.message,
        0, true);
    }
  }

  private validateChatId(chatId: ChatId): void {
    if (!Number.isSafeInteger(chatId) || chatId <= 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400,
        false);
    }
  }
}

export function createScheduledMessagesUseCase(gateway: TdGatewayPort): ScheduledMessagesUseCase {
  return new ScheduledMessagesUseCase(gateway);
}

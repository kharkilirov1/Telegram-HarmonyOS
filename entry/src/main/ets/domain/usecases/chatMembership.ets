// Chat membership actions — Leave Chat and Share My Contact (C10 remainder / S12c).
// TDLib: leaveChat (td_api.tl:12261), sendMessage with inputMessageContact (:5396), contact (:531).

import { hilog } from '@kit.PerformanceAnalysisKit';
import { ChatId } from '../../core/model/EntityId';
import {
  createLeaveChatCommand,
  createShareContactCommand,
  ShareContactPayload
} from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x003c;
const TAG = 'ChatMembership';

export class LeaveChatUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async leave(chatId: ChatId): Promise<void> {
    if (!Number.isSafeInteger(chatId) || chatId <= 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400, false);
    }
    try {
      hilog.info(DOMAIN, TAG, 'Leaving chat %{public}d', chatId);
      await this.gateway.send(createLeaveChatCommand(chatId));
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'leaveChat failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to leave the chat', err.message, 0, true);
    }
  }
}

export class ShareMyContactUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async share(chatId: ChatId, phoneNumber: string, firstName: string, lastName: string, userId: number): Promise<void> {
    if (!Number.isSafeInteger(chatId) || chatId <= 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400, false);
    }
    if (phoneNumber.trim().length === 0 || firstName.trim().length === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid contact', 'Phone number and name are required', 400, false);
    }
    if (!Number.isSafeInteger(userId) || userId <= 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid userId', 'Input validation failed', 400, false);
    }
    const payload = new ShareContactPayload();
    payload.chatId = chatId;
    payload.phoneNumber = phoneNumber.trim();
    payload.firstName = firstName.trim();
    payload.lastName = lastName.trim();
    payload.userId = userId;
    try {
      hilog.info(DOMAIN, TAG, 'Sharing own contact in chat %{public}d', chatId);
      await this.gateway.send(createShareContactCommand(payload));
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'send contact failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to share the contact', err.message, 0, true);
    }
  }
}

export function createLeaveChatUseCase(gateway: TdGatewayPort): LeaveChatUseCase {
  return new LeaveChatUseCase(gateway);
}

export function createShareMyContactUseCase(gateway: TdGatewayPort): ShareMyContactUseCase {
  return new ShareMyContactUseCase(gateway);
}

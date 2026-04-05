// SetChatMute use case — mute/unmute a chat via TDLib
// TDLib responds with updateChatNotificationSettings → ChatNormalizer → chatsReducer

import { hilog } from '@kit.PerformanceAnalysisKit';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { ChatId } from '../../core/model/EntityId';
import { createSetChatMuteCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';

const TAG = 'SetChatMute';
const DOMAIN = 0x0014;

// Common mute durations (seconds)
export const MUTE_FOREVER = 2147483647; // max int32 — TDLib convention for "forever"
export const MUTE_1_HOUR = 3600;
export const MUTE_8_HOURS = 28800;
export const MUTE_2_DAYS = 172800;

export class SetChatMuteUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async mute(chatId: ChatId, durationSeconds: number = MUTE_FOREVER): Promise<void> {
    if (!chatId || chatId === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400, false);
    }

    try {
      hilog.info(DOMAIN, TAG, 'Muting chat %{public}d for %{public}d seconds', chatId, durationSeconds);
      const command = createSetChatMuteCommand(chatId, durationSeconds);
      await this.gateway.send(command);
      hilog.info(DOMAIN, TAG, 'Chat muted');
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Mute failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to mute chat', err.message, 0, true);
    }
  }

  async unmute(chatId: ChatId): Promise<void> {
    if (!chatId || chatId === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400, false);
    }

    try {
      hilog.info(DOMAIN, TAG, 'Unmuting chat %{public}d', chatId);
      const command = createSetChatMuteCommand(chatId, 0);
      await this.gateway.send(command);
      hilog.info(DOMAIN, TAG, 'Chat unmuted');
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Unmute failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to unmute chat', err.message, 0, true);
    }
  }
}

export function createSetChatMuteUseCase(gateway: TdGatewayPort): SetChatMuteUseCase {
  return new SetChatMuteUseCase(gateway);
}

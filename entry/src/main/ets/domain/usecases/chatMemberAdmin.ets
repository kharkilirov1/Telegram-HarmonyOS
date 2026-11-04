// Per-member moderation actions (G6).
// TDLib: setChatMemberStatus (td_api.tl:12281) with chatMemberStatusMember / Banned / Restricted.
// A restricted member stays in the chat but loses every send permission; 0 untilDate means forever.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { ChatId, UserId } from '../../core/model/EntityId';
import { ChatAdminRightsPayload, createSetChatMemberStatusCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x0048;
const TAG = 'ChatMemberAdmin';

export type ChatMemberModerationAction = 'ban' | 'unban' | 'restrict' | 'promote' | 'demote';

export const MEMBER_ACTION_KINDS: string[] = ['member', 'banned', 'restricted', 'administrator'];

// iOS offers 1 hour / 1 day / 1 week / forever when restricting or banning; 0 means forever.
export const MODERATION_DURATION_SECONDS: number[] = [3600, 86400, 7 * 86400, 0];

export interface ModerationDurationOption {
  labelKey: string;
  fallback: string;
  seconds: number;
}

export const MODERATION_DURATION_OPTIONS: ModerationDurationOption[] = [
  { labelKey: 'moderation_duration_1h', fallback: '1 hour', seconds: 3600 },
  { labelKey: 'moderation_duration_1d', fallback: '1 day', seconds: 86400 },
  { labelKey: 'moderation_duration_1w', fallback: '1 week', seconds: 7 * 86400 },
  { labelKey: 'moderation_duration_forever', fallback: 'Forever', seconds: 0 }
];

// TDLib expects an absolute Unix timestamp; 0 is 'forever' for ban and restrict.
export function moderationUntilDate(nowSeconds: number, durationSeconds: number): number {
  if (!Number.isSafeInteger(nowSeconds) || nowSeconds < 0) {
    return 0;
  }
  if (!Number.isSafeInteger(durationSeconds) || durationSeconds <= 0) {
    return 0;
  }
  return nowSeconds + durationSeconds;
}

export function memberStatusKind(action: ChatMemberModerationAction): string {
  if (action === 'ban') {
    return 'banned';
  }
  if (action === 'restrict') {
    return 'restricted';
  }
  if (action === 'promote') {
    return 'administrator';
  }
  return 'member';
}

export class ChatMemberAdminUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async apply(chatId: ChatId, userId: UserId, action: ChatMemberModerationAction,
    untilDate: number = 0,
    rights: ChatAdminRightsPayload = new ChatAdminRightsPayload()): Promise<void> {
    this.validate(chatId, userId, untilDate);
    const statusKind: string = memberStatusKind(action);
    try {
      await this.gateway.send(createSetChatMemberStatusCommand(chatId, userId, statusKind, untilDate,
        rights));
      hilog.info(DOMAIN, TAG, 'Member status updated: %{public}s', statusKind);
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Member status update failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to update the member', err.message, 0, true);
    }
  }

  private validate(chatId: ChatId, userId: UserId, untilDate: number): void {
    if (!Number.isSafeInteger(chatId) || chatId <= 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400,
        false);
    }
    if (!Number.isSafeInteger(userId) || userId <= 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid userId', 'Input validation failed', 400,
        false);
    }
    if (!Number.isSafeInteger(untilDate) || untilDate < 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid until date', 'Input validation failed',
        400, false);
    }
  }
}

export function createChatMemberAdminUseCase(gateway: TdGatewayPort): ChatMemberAdminUseCase {
  return new ChatMemberAdminUseCase(gateway);
}

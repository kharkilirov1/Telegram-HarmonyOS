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

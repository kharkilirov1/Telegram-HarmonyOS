// Current user's membership role in a chat (S12g).
// TDLib: getChatMember (td_api.tl) returns chatMember; its status object decides which admin entries the
// chat menu may offer. Only group-like chats have a meaningful role here.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { ChatId, UserId } from '../../core/model/EntityId';
import { createGetChatMemberCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { TdObject as TdObjectType, TdObject } from '../../models/TdTypes';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x0042;
const TAG = 'ChatMemberRole';

export type ChatMemberRole = 'creator' | 'administrator' | 'member' | 'restricted' | 'left' | 'banned' |
  'unknown';

export function readChatMemberRole(td: TdObjectType): ChatMemberRole {
  if (td.getTopLevelStringStrict('@type') !== 'chatMember') {
    return 'unknown';
  }
  const status: TdObjectType | undefined = td.getTopLevelObjectStrict('status');
  if (status === undefined) {
    return 'unknown';
  }
  const statusType: string = status.getTopLevelStringStrict('@type') ?? '';
  if (statusType === 'chatMemberStatusCreator') {
    return 'creator';
  }
  if (statusType === 'chatMemberStatusAdministrator') {
    return 'administrator';
  }
  if (statusType === 'chatMemberStatusMember') {
    return 'member';
  }
  if (statusType === 'chatMemberStatusRestricted') {
    return 'restricted';
  }
  if (statusType === 'chatMemberStatusLeft') {
    return 'left';
  }
  if (statusType === 'chatMemberStatusBanned') {
    return 'banned';
  }
  return 'unknown';
}

export function canManageChat(role: ChatMemberRole): boolean {
  return role === 'creator' || role === 'administrator';
}

export class ChatMemberRoleUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async load(chatId: ChatId, userId: UserId): Promise<ChatMemberRole> {
    if (!Number.isSafeInteger(chatId) || chatId <= 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400, false);
    }
    if (!Number.isSafeInteger(userId) || userId <= 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid userId', 'Input validation failed', 400, false);
    }
    try {
      const response = await this.gateway.send(createGetChatMemberCommand(chatId, userId)) as TdObject;
      return readChatMemberRole(response);
    } catch (error) {
      const err = error as Error;
      hilog.warn(DOMAIN, TAG, 'getChatMember failed: %{public}s', err.message);
      // A missing role must not block the menu: fall back to the plain member set.
      return 'unknown';
    }
  }
}

export function createChatMemberRoleUseCase(gateway: TdGatewayPort): ChatMemberRoleUseCase {
  return new ChatMemberRoleUseCase(gateway);
}

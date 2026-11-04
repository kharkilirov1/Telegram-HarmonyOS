// Chat invite links (t.me/+hash, t.me/joinchat/hash) — preview and join (S14c).
// TDLib: checkChatInviteLink (td_api.tl:12846) returns ChatInviteLinkInfo; joinChatByInviteLink
// (:12849) returns the joined Chat.

import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  createCheckChatInviteLinkCommand,
  createJoinChatByInviteLinkCommand
} from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { ChatDto, createChatDtoFromTd } from '../../core/model/dto/ChatDto';
import {
  ChatInviteLinkInfoDto,
  createChatInviteLinkInfoFromTd
} from '../../core/model/dto/ChatInviteLinkInfoDto';
import { TdObject } from '../../models/TdTypes';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x0041;
const TAG = 'ChatInviteLink';
export const INVITE_LINK_MAX_LENGTH: number = 512;

export function isChatInviteLink(value: string): boolean {
  const trimmed = value.trim();
  if (trimmed.length === 0 || trimmed.length > INVITE_LINK_MAX_LENGTH) {
    return false;
  }
  const lower = trimmed.toLowerCase();
  const withoutScheme = lower.startsWith('https://') ? lower.slice(8)
    : (lower.startsWith('http://') ? lower.slice(7) : lower);
  if ((withoutScheme.startsWith('t.me/+') && withoutScheme.length > 't.me/+'.length) ||
    (withoutScheme.startsWith('telegram.me/+') && withoutScheme.length > 'telegram.me/+'.length)) {
    return true;
  }
  return (withoutScheme.startsWith('t.me/joinchat/') && withoutScheme.length > 't.me/joinchat/'.length) ||
    (withoutScheme.startsWith('telegram.me/joinchat/') &&
      withoutScheme.length > 'telegram.me/joinchat/'.length);
}

export class ChatInviteLinkUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async check(inviteLink: string): Promise<ChatInviteLinkInfoDto> {
    const link = this.validateLink(inviteLink);
    try {
      hilog.info(DOMAIN, TAG, 'Checking chat invite link');
      const response = await this.gateway.send(createCheckChatInviteLinkCommand(link)) as TdObject;
      const info = createChatInviteLinkInfoFromTd(response);
      if (info === undefined) {
        throw new AppError(AppErrorKind.UNKNOWN, 'Unsupported invite link response', 'Unexpected @type',
          0, false);
      }
      return info;
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'checkChatInviteLink failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to check the invite link', err.message, 0, true);
    }
  }

  async join(inviteLink: string): Promise<ChatDto> {
    const link = this.validateLink(inviteLink);
    try {
      hilog.info(DOMAIN, TAG, 'Joining chat by invite link');
      const response = await this.gateway.send(createJoinChatByInviteLinkCommand(link)) as TdObject;
      const chat = createChatDtoFromTd(response);
      if (chat === undefined || chat.id === 0) {
        throw new AppError(AppErrorKind.UNKNOWN, 'Invite link did not return a chat',
          'Unexpected TDLib response', 0, false);
      }
      return chat;
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'joinChatByInviteLink failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to join the chat', err.message, 0, true);
    }
  }

  private validateLink(inviteLink: string): string {
    const link = inviteLink.trim();
    if (!isChatInviteLink(link)) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid invite link',
        'Expected t.me/+... or t.me/joinchat/...', 400, false);
    }
    return link;
  }
}

export function createChatInviteLinkUseCase(gateway: TdGatewayPort): ChatInviteLinkUseCase {
  return new ChatInviteLinkUseCase(gateway);
}

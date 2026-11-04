// Chat invite links use case (S12h): list, create and revoke links for a group or channel.
// TDLib: getChatInviteLinks (td_api.tl:12821), createChatInviteLink (:12780), revokeChatInviteLink (:12835).

import { hilog } from '@kit.PerformanceAnalysisKit';
import { ChatId } from '../../core/model/EntityId';
import {
  createCreateChatInviteLinkCommand,
  createGetChatInviteLinksCommand,
  createRevokeChatInviteLinkCommand
} from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import {
  ChatInviteLinkDto,
  ChatInviteLinksDto,
  createChatInviteLinkFromTd,
  createChatInviteLinksFromTd
} from '../../core/model/dto/ChatInviteLinkDto';
import { TdObject } from '../../models/TdTypes';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x0043;
const TAG = 'ChatInviteLinks';
export const INVITE_LINK_PAGE_SIZE: number = 50;

export class ChatInviteLinksUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async load(chatId: ChatId, offsetDate: number = 0,
    offsetInviteLink: string = ''): Promise<ChatInviteLinksDto> {
    this.validateChatId(chatId);
    try {
      const command = createGetChatInviteLinksCommand(chatId);
      command.payload.offsetDate = offsetDate;
      command.payload.offsetInviteLink = offsetInviteLink;
      command.payload.limit = INVITE_LINK_PAGE_SIZE;
      const response = await this.gateway.send(command) as TdObject;
      const links = createChatInviteLinksFromTd(response);
      if (links === undefined) {
        throw new AppError(AppErrorKind.UNKNOWN, 'Unsupported invite links response', 'Unexpected @type',
          0, false);
      }
      return links;
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'getChatInviteLinks failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to load invite links', err.message, 0, true);
    }
  }

  // Defaults match Telegram: no name, no expiry, no member limit, no join request.
  async create(chatId: ChatId): Promise<ChatInviteLinkDto> {
    this.validateChatId(chatId);
    try {
      const response = await this.gateway.send(createCreateChatInviteLinkCommand(chatId, '')) as TdObject;
      const link = createChatInviteLinkFromTd(response);
      if (link === undefined || link.inviteLink.length === 0) {
        throw new AppError(AppErrorKind.UNKNOWN, 'Invite link was not created', 'Unexpected TDLib response',
          0, false);
      }
      return link;
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'createChatInviteLink failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to create an invite link', err.message, 0, true);
    }
  }

  async revoke(chatId: ChatId, inviteLink: string): Promise<ChatInviteLinksDto> {
    this.validateChatId(chatId);
    const link = inviteLink.trim();
    if (link.length === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid invite link', 'Input validation failed', 400,
        false);
    }
    try {
      const response = await this.gateway.send(
        createRevokeChatInviteLinkCommand(chatId, link)) as TdObject;
      const links = createChatInviteLinksFromTd(response);
      if (links === undefined) {
        throw new AppError(AppErrorKind.UNKNOWN, 'Unsupported revoke response', 'Unexpected @type', 0,
          false);
      }
      return links;
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'revokeChatInviteLink failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to revoke the invite link', err.message, 0, true);
    }
  }

  private validateChatId(chatId: ChatId): void {
    if (!Number.isSafeInteger(chatId) || chatId <= 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400, false);
    }
  }
}

export function createChatInviteLinksUseCase(gateway: TdGatewayPort): ChatInviteLinksUseCase {
  return new ChatInviteLinksUseCase(gateway);
}

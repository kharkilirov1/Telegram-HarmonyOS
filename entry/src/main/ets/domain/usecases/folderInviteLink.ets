// Folder invite link preview and join (B7 / S13j).
// TDLib: checkChatFolderInviteLink (td_api.tl:12105) returns the folder info plus the chats that are
// missing from it; addChatFolderByInviteLink (:12108) adds the folder, optionally restricted to the
// listed chat ids. Both take the link exactly as the user pasted it (https://t.me/addlist/...).

import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  createAddChatFolderByInviteLinkCommand,
  createCheckChatFolderInviteLinkCommand,
  AddChatFolderByInviteLinkCommand
} from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import {
  ChatFolderInviteLinkInfoDto,
  createChatFolderInviteLinkInfoFromTd
} from '../../core/model/dto/ChatFolderInviteLinkInfoDto';
import { TdObject } from '../../models/TdTypes';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x003f;
const TAG = 'FolderInviteLink';
// Telegram folder links are t.me/addlist/<slug> (optionally https:// and a trailing slash).
export const FOLDER_LINK_MAX_LENGTH: number = 512;

export function isFolderInviteLink(value: string): boolean {
  const link = value.trim().toLowerCase();
  if (link.length === 0 || link.length > FOLDER_LINK_MAX_LENGTH) {
    return false;
  }
  const withoutScheme = link.startsWith('https://') ? link.slice(8)
    : (link.startsWith('http://') ? link.slice(7) : link);
  return withoutScheme.startsWith('t.me/addlist/') && withoutScheme.length > 't.me/addlist/'.length ||
    withoutScheme.startsWith('telegram.me/addlist/') &&
    withoutScheme.length > 'telegram.me/addlist/'.length;
}

export class FolderInviteLinkUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async check(inviteLink: string): Promise<ChatFolderInviteLinkInfoDto> {
    const link = this.validateLink(inviteLink);
    try {
      hilog.info(DOMAIN, TAG, 'Checking folder invite link');
      const response = await this.gateway.send(createCheckChatFolderInviteLinkCommand(link)) as TdObject;
      const info = createChatFolderInviteLinkInfoFromTd(response);
      if (info === undefined) {
        throw new AppError(AppErrorKind.UNKNOWN, 'Unsupported folder link response', 'Unexpected @type',
          0, false);
      }
      return info;
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'checkChatFolderInviteLink failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to check the folder link', err.message, 0, true);
    }
  }

  async add(inviteLink: string, chatIds: number[]): Promise<void> {
    const link = this.validateLink(inviteLink);
    for (const chatId of chatIds) {
      if (!Number.isSafeInteger(chatId) || chatId <= 0) {
        throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chat id', 'Input validation failed', 400,
          false);
      }
    }
    try {
      hilog.info(DOMAIN, TAG, 'Adding folder by invite link with %{public}d chats', chatIds.length);
      await this.gateway.send(createAddChatFolderByInviteLinkCommand(link, chatIds));
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'addChatFolderByInviteLink failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to add the folder', err.message, 0, true);
    }
  }

  private validateLink(inviteLink: string): string {
    const link = inviteLink.trim();
    if (!isFolderInviteLink(link)) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid folder link',
        'Expected t.me/addlist/...', 400, false);
    }
    return link;
  }
}

export function createFolderInviteLinkUseCase(gateway: TdGatewayPort): FolderInviteLinkUseCase {
  return new FolderInviteLinkUseCase(gateway);
}

// Re-exported for callers that only need the command type in tests.
export { AddChatFolderByInviteLinkCommand };

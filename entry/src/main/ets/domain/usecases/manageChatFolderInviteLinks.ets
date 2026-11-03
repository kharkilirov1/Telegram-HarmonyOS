// Chat folder invite links — list, create and delete (B7 / S13e).
// TDLib: getChatFolderInviteLinks (td_api.tl:12090), createChatFolderInviteLink (:12087),
// deleteChatFolderInviteLink (:12102). Editing a link's name/chat set is not exposed yet.

import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  createCreateChatFolderInviteLinkCommand,
  createEditChatFolderInviteLinkCommand,
  createDeleteChatFolderInviteLinkCommand,
  createGetChatFolderInviteLinksCommand
} from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import {
  ChatFolderInviteLinkDto,
  createChatFolderInviteLinksFromTd
} from '../../core/model/dto/ChatFolderInviteLinkDto';
import { TdObject } from '../../models/TdTypes';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x003a;
const TAG = 'ChatFolderInviteLinks';
export const CHAT_FOLDER_INVITE_LINK_NAME_MAX_LENGTH: number = 32;

export class ManageChatFolderInviteLinksUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async listLinks(folderId: number): Promise<ChatFolderInviteLinkDto[]> {
    this.validateFolderId(folderId);
    try {
      const response = await this.gateway.send(
        createGetChatFolderInviteLinksCommand(folderId)) as TdObject;
      return createChatFolderInviteLinksFromTd(response).links;
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'getChatFolderInviteLinks failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to load invite links', err.message, 0, true);
    }
  }

  async createLink(folderId: number, name: string): Promise<void> {
    this.validateFolderId(folderId);
    const trimmed = name.trim();
    if (trimmed.length === 0 || trimmed.length > CHAT_FOLDER_INVITE_LINK_NAME_MAX_LENGTH) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid link name',
        'Expected 1..' + CHAT_FOLDER_INVITE_LINK_NAME_MAX_LENGTH + ' characters', 400, false);
    }
    try {
      hilog.info(DOMAIN, TAG, 'Creating invite link for folder %{public}d', folderId);
      await this.gateway.send(createCreateChatFolderInviteLinkCommand(folderId, trimmed));
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'createChatFolderInviteLink failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to create the invite link', err.message, 0, true);
    }
  }

  async editLink(folderId: number, inviteLink: string, name: string): Promise<void> {
    this.validateFolderId(folderId);
    if (inviteLink.trim().length === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid invite link', 'Input validation failed', 400, false);
    }
    const trimmed = name.trim();
    if (trimmed.length === 0 || trimmed.length > CHAT_FOLDER_INVITE_LINK_NAME_MAX_LENGTH) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid link name',
        'Expected 1..' + CHAT_FOLDER_INVITE_LINK_NAME_MAX_LENGTH + ' characters', 400, false);
    }
    try {
      hilog.info(DOMAIN, TAG, 'Editing invite link of folder %{public}d', folderId);
      await this.gateway.send(createEditChatFolderInviteLinkCommand(folderId, inviteLink, trimmed));
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'editChatFolderInviteLink failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to update the invite link', err.message, 0, true);
    }
  }

  async deleteLink(folderId: number, inviteLink: string): Promise<void> {
    this.validateFolderId(folderId);
    if (inviteLink.trim().length === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid invite link', 'Input validation failed', 400, false);
    }
    try {
      hilog.info(DOMAIN, TAG, 'Deleting invite link of folder %{public}d', folderId);
      await this.gateway.send(createDeleteChatFolderInviteLinkCommand(folderId, inviteLink));
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'deleteChatFolderInviteLink failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to delete the invite link', err.message, 0, true);
    }
  }

  private validateFolderId(folderId: number): void {
    if (!Number.isSafeInteger(folderId) || folderId <= 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid folderId', 'Input validation failed', 400, false);
    }
  }
}

export function createManageChatFolderInviteLinksUseCase(
  gateway: TdGatewayPort
): ManageChatFolderInviteLinksUseCase {
  return new ManageChatFolderInviteLinksUseCase(gateway);
}

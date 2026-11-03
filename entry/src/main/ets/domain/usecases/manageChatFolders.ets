// Chat folder management — Settings → Chat Folders (B7 / S7b.4).
// TDLib: createChatFolder (td_api.tl:12054), editChatFolder (:12057), deleteChatFolder (:12060).
// Folder list itself arrives through updateChatFolders, so the page refreshes from AppStore after
// every call instead of parsing the ChatFolderInfo response.

import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  ChatFolderDraftPayload,
  createChatFolderCommand,
  createDeleteChatFolderCommand,
  createEditChatFolderCommand
} from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x0039;
const TAG = 'ManageChatFolders';
export const CHAT_FOLDER_TITLE_MAX_LENGTH: number = 12;

export class ManageChatFoldersUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async createFolder(draft: ChatFolderDraftPayload): Promise<void> {
    this.validateDraft(draft);
    try {
      hilog.info(DOMAIN, TAG, 'Creating chat folder %{public}s', draft.title);
      await this.gateway.send(createChatFolderCommand(draft));
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'createChatFolder failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to create the folder', err.message, 0, true);
    }
  }

  async editFolder(folderId: number, draft: ChatFolderDraftPayload): Promise<void> {
    this.validateFolderId(folderId);
    this.validateDraft(draft);
    try {
      hilog.info(DOMAIN, TAG, 'Editing chat folder %{public}d', folderId);
      await this.gateway.send(createEditChatFolderCommand(folderId, draft));
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'editChatFolder failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to update the folder', err.message, 0, true);
    }
  }

  async deleteFolder(folderId: number): Promise<void> {
    this.validateFolderId(folderId);
    try {
      hilog.info(DOMAIN, TAG, 'Deleting chat folder %{public}d', folderId);
      await this.gateway.send(createDeleteChatFolderCommand(folderId));
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'deleteChatFolder failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to delete the folder', err.message, 0, true);
    }
  }

  private validateFolderId(folderId: number): void {
    if (!Number.isSafeInteger(folderId) || folderId <= 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid folderId', 'Input validation failed', 400, false);
    }
  }

  private validateDraft(draft: ChatFolderDraftPayload): void {
    const title = draft.title.trim();
    if (title.length === 0 || title.length > CHAT_FOLDER_TITLE_MAX_LENGTH) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid folder name',
        'Expected 1..' + CHAT_FOLDER_TITLE_MAX_LENGTH + ' characters', 400, false);
    }
    // The name is trimmed before sending so a padded title cannot pass validation.
    draft.title = title;
  }
}

export function createManageChatFoldersUseCase(gateway: TdGatewayPort): ManageChatFoldersUseCase {
  return new ManageChatFoldersUseCase(gateway);
}

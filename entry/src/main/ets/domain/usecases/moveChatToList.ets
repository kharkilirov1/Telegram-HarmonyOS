// Moves a chat between TDLib's main and archive lists. TDLib publishes the
// resulting main/archive positions through updateChatPosition.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { createAddChatToListCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { ChatId } from '../../core/model/EntityId';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x0014;
const TAG = 'MoveChatToList';

export class MoveChatToListUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  // TDLib exposes addChatToList for every list, so adding a chat to a folder is the same command
  // with chatListFolder. Removing a chat from a folder is not available in this TDLib version.
  async addToFolder(chatId: ChatId, folderId: number): Promise<void> {
    if (!chatId || chatId === 0 || !Number.isSafeInteger(folderId) || folderId <= 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId/folderId', 'Input validation failed', 400, false);
    }
    try {
      hilog.info(DOMAIN, TAG, 'Adding chat %{public}d to folder %{public}d', chatId, folderId);
      await this.gateway.send(createAddChatToListCommand(chatId, 'folder', folderId));
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Add to folder failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to add chat to folder', err.message, 0, true);
    }
  }

  async execute(chatId: ChatId, target: 'main' | 'archive'): Promise<void> {
    if (!chatId || chatId === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400, false);
    }
    try {
      hilog.info(DOMAIN, TAG, 'Moving chat %{public}d to %{public}s', chatId, target);
      await this.gateway.send(createAddChatToListCommand(chatId, target));
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Chat move failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to move chat', err.message, 0, true);
    }
  }
}

export function createMoveChatToListUseCase(gateway: TdGatewayPort): MoveChatToListUseCase {
  return new MoveChatToListUseCase(gateway);
}

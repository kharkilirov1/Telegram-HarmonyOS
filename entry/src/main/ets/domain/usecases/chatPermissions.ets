// Chat permissions use case (S12j): read the chat's default permissions and write them back whole.
// TDLib: getChat (renders chat.permissions) and setChatPermissions (td_api.tl:12160).

import { hilog } from '@kit.PerformanceAnalysisKit';
import { ChatId } from '../../core/model/EntityId';
import { createGetChatCommand, createSetChatPermissionsCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import {
  ChatPermissionsDto,
  chatPermissionsToJson,
  createChatPermissionsFromTd
} from '../../core/model/dto/ChatPermissionsDto';
import { TdObject } from '../../models/TdTypes';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x0045;
const TAG = 'ChatPermissions';

export class ChatPermissionsUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async load(chatId: ChatId): Promise<ChatPermissionsDto> {
    this.validateChatId(chatId);
    try {
      const response = await this.gateway.send(createGetChatCommand(chatId)) as TdObject;
      if (response.getTopLevelStringStrict('@type') !== 'chat') {
        throw new AppError(AppErrorKind.UNKNOWN, 'Unsupported chat response', 'Unexpected @type', 0,
          false);
      }
      const permissions = response.getTopLevelObjectStrict('permissions');
      if (permissions === undefined) {
        throw new AppError(AppErrorKind.UNKNOWN, 'Chat has no permissions', 'Missing permissions', 0,
          false);
      }
      const dto = createChatPermissionsFromTd(permissions);
      if (dto === undefined) {
        throw new AppError(AppErrorKind.UNKNOWN, 'Unsupported permissions response', 'Unexpected @type',
          0, false);
      }
      return dto;
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'getChat permissions failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to load permissions', err.message, 0, true);
    }
  }

  async save(chatId: ChatId, permissions: ChatPermissionsDto): Promise<void> {
    this.validateChatId(chatId);
    try {
      await this.gateway.send(
        createSetChatPermissionsCommand(chatId, chatPermissionsToJson(permissions)));
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'setChatPermissions failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to save permissions', err.message, 0, true);
    }
  }

  private validateChatId(chatId: ChatId): void {
    if (!Number.isSafeInteger(chatId) || chatId <= 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400, false);
    }
  }
}

export function createChatPermissionsUseCase(gateway: TdGatewayPort): ChatPermissionsUseCase {
  return new ChatPermissionsUseCase(gateway);
}

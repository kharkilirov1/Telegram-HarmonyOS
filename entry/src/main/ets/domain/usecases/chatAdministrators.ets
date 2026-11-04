// Chat administrators use case (S12i).
// TDLib: getChatAdministrators (td_api.tl:12315). Names are resolved by the screen from the users store.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { ChatId } from '../../core/model/EntityId';
import { createGetChatAdministratorsCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import {
  ChatAdministratorsDto,
  createChatAdministratorsFromTd
} from '../../core/model/dto/ChatAdministratorDto';
import { TdObject } from '../../models/TdTypes';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x0044;
const TAG = 'ChatAdministrators';

export class ChatAdministratorsUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async load(chatId: ChatId): Promise<ChatAdministratorsDto> {
    if (!Number.isSafeInteger(chatId) || chatId <= 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400, false);
    }
    try {
      const response = await this.gateway.send(createGetChatAdministratorsCommand(chatId)) as TdObject;
      const admins = createChatAdministratorsFromTd(response);
      if (admins === undefined) {
        throw new AppError(AppErrorKind.UNKNOWN, 'Unsupported administrators response', 'Unexpected @type',
          0, false);
      }
      return admins;
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'getChatAdministrators failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to load administrators', err.message, 0, true);
    }
  }
}

export function createChatAdministratorsUseCase(gateway: TdGatewayPort): ChatAdministratorsUseCase {
  return new ChatAdministratorsUseCase(gateway);
}

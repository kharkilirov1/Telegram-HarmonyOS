// Resolve a t.me/<username> link to a chat (S14b).
// TDLib: searchPublicChat (td_api.tl:10602) resolves a public username to Chat; the app then hydrates the
// chat into the store and opens the chat screen, matching the iOS behaviour for a username link.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { createSearchPublicChatCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { ChatDto, createChatDtoFromTd } from '../../core/model/dto/ChatDto';
import { TdObject } from '../../models/TdTypes';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x0040;
const TAG = 'ResolveUsername';
// Telegram usernames are 4..32 characters, start with a letter and contain letters, digits or "_".
const USERNAME_MIN_LENGTH: number = 4;

export function isValidUsername(username: string): boolean {
  const name = username.trim();
  if (name.length < USERNAME_MIN_LENGTH || name.length > 32) {
    return false;
  }
  const first = name.charAt(0);
  if (!((first >= 'a' && first <= 'z') || (first >= 'A' && first <= 'Z'))) {
    return false;
  }
  for (let index = 1; index < name.length; index += 1) {
    const ch = name.charAt(index);
    const isLower = ch >= 'a' && ch <= 'z';
    const isUpper = ch >= 'A' && ch <= 'Z';
    const isDigit = ch >= '0' && ch <= '9';
    if (!isLower && !isUpper && !isDigit && ch !== '_') {
      return false;
    }
  }
  return true;
}

export class ResolveUsernameUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async resolve(username: string): Promise<ChatDto> {
    const name = username.trim();
    if (!isValidUsername(name)) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid username', 'Input validation failed', 400,
        false);
    }
    try {
      hilog.info(DOMAIN, TAG, 'Resolving public chat by username');
      const response = await this.gateway.send(createSearchPublicChatCommand(name)) as TdObject;
      const chat = createChatDtoFromTd(response);
      if (chat === undefined || chat.id === 0) {
        throw new AppError(AppErrorKind.UNKNOWN, 'Username not found',
          'TDLib did not return a chat', 0, false);
      }
      return chat;
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'searchPublicChat failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to open the username', err.message, 0, true);
    }
  }
}

export function createResolveUsernameUseCase(gateway: TdGatewayPort): ResolveUsernameUseCase {
  return new ResolveUsernameUseCase(gateway);
}

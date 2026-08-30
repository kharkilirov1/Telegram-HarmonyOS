// JoinChat use case — join a public channel/supergroup via TDLib
// TDLib contract: joinChat chat_id:int53 = Ok (td_api.tl:12010)
// Membership arrives back as updateChatPosition (chatListMain) → chatsReducer,
// so the bottom action bar re-evaluates Join → Mute/Unmute from order !== '0'.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { ChatId } from '../../core/model/EntityId';
import { createJoinChatCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';

const TAG = 'JoinChat';
const DOMAIN = 0x0014;

export class JoinChatUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async join(chatId: ChatId): Promise<void> {
    if (!chatId || chatId === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400, false);
    }

    try {
      hilog.info(DOMAIN, TAG, 'Joining chat %{public}d', chatId);
      const command = createJoinChatCommand(chatId);
      await this.gateway.send(command);
      hilog.info(DOMAIN, TAG, 'Join request sent');
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Join failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to join chat', err.message, 0, true);
    }
  }
}

export function createJoinChatUseCase(gateway: TdGatewayPort): JoinChatUseCase {
  return new JoinChatUseCase(gateway);
}
